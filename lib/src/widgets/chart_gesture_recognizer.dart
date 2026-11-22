// Android shim: the touch delivery of android.view.View / ViewGroup to a chart (dispatchTouchEvent → onTouchEvent with
// MotionEvents, ACTION_CANCEL when a parent intercepts or the view is removed, requestDisallowInterceptTouchEvent) for
// MPAndroidChart v4.0.1 port
import 'package:flutter/gestures.dart';

import 'chart_render_box.dart';
import 'chart_touch_event.dart';

/// Hands the touches on a chart to its touch listener as Android's view system does, and takes part in Flutter's
/// gesture arena for them.
///
/// It folds the pointer events of every finger on the chart into [ChartTouchEvent]s shaped like Android's
/// `MotionEvent`s and passes each to [onTouch], normally `Chart.onTouchEvent`:
///
/// - the first finger down is [ChartTouchAction.down], each further finger down [ChartTouchAction.pointerDown] with
///   the new finger's index as `actionIndex`;
/// - a move of any finger is [ChartTouchAction.move] with the positions of all fingers;
/// - a finger that lifts while others stay down is [ChartTouchAction.pointerUp], whose `actionIndex` is that finger's
///   index and whose lists still hold it, as Android's `ACTION_POINTER_UP`; the last finger up is
///   [ChartTouchAction.up];
/// - a cancelled pointer, the loss of the gesture arena and [dispose] during a gesture are one
///   [ChartTouchAction.cancel], Android's `ACTION_CANCEL` when a parent intercepts the gesture or the view is removed.
///   Nothing more of that gesture reaches [onTouch].
///
/// The positions are in the chart's coordinates, in logical pixels, mapped with the chart's position at the finger's
/// down; the event time is the pointer event's `timeStamp` in milliseconds. Every event has lists of its own.
///
/// Arena: the recognizer enters the arena for every finger on the chart and claims nothing by itself. It wins at the
/// moment the chart's touch listener calls `Chart.disableScroll`, Android's `requestDisallowInterceptTouchEvent(true)`,
/// through [acceptNow]; fingers that go down later in the same gesture are its at once. Until then an enclosing
/// scrollable can win, and the chart gets a cancel. The recognizer itself looks at no direction or distance: which
/// gestures stay with the chart is the touch listener's decision, as on Android. A gesture nobody claimed is the
/// chart's when the arena is swept at the last up (the chart, the innermost, joined first), after the chart got that
/// up.
///
/// Order: after a finger's down the chart gets each event of that finger after the other recognizers that track it,
/// as Android's parent sees each `MotionEvent` in `onInterceptTouchEvent` before the chart. A scrollable that wins the
/// arena on a move cancels the chart's gesture before the chart sees that move.
///
/// A down that [onTouch] does not consume (returns false for) ends the gesture for the chart: the recognizer leaves
/// the arena and the chart gets no more events of it, as an Android view whose `onTouchEvent` returns false for
/// `ACTION_DOWN`.
///
/// Only presses of the primary button are taken (touch, stylus, the primary mouse button), as Flutter's drag
/// recognizers do. Trackpad pan and zoom gestures (`PointerPanZoomStartEvent` and the rest) are not handled.
class ChartGestureRecognizer extends OneSequenceGestureRecognizer
    implements ChartArenaRecognizer {
  /// Creates a recognizer that passes the touches on a chart to [onTouch].
  ///
  /// [supportedDevices] limits the kinds of device whose pointers it takes; null takes all.
  ChartGestureRecognizer({
    required this.onTouch,
    super.debugOwner,
    super.supportedDevices,
  }) : super(allowedButtonsFilter: _isPrimaryButton);

  /// Receives every touch event of the chart and returns whether it was consumed, `View.onTouchEvent`.
  ///
  /// Only the return value for a [ChartTouchAction.down] matters: when it is false, the gesture ends for the chart.
  final bool Function(ChartTouchEvent event) onTouch;

  static bool _isPrimaryButton(int buttons) => buttons == kPrimaryButton;

  /// The fingers of the current gesture in the order they went down, the pointers this recognizer tracks once their
  /// down was delivered. Empty when no gesture is in progress.
  final List<int> _pointerIds = [];

  /// The last position of each finger in [_pointerIds], in the chart's coordinates.
  final List<Offset> _positions = [];

  /// Whether [acceptNow] claimed the current gesture, so later fingers are claimed when they go down.
  bool _claimed = false;

  /// The time of the last pointer event, for a cancel that no pointer event brings.
  Duration _lastTimeStamp = Duration.zero;

  /// Wins the gesture arena for every finger of the current gesture, and for the fingers that go down later in it,
  /// `requestDisallowInterceptTouchEvent(true)`. Does nothing outside a gesture: Android resets the request at every
  /// `ACTION_DOWN`.
  @override
  void acceptNow() {
    if (_pointerIds.isEmpty) return;
    _claimed = true;
    resolve(GestureDisposition.accepted);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    // A parent that was asked not to intercept no longer intercepts any event of the gesture, later fingers included.
    if (_claimed) resolvePointer(event.pointer, GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    _lastTimeStamp = event.timeStamp;
    switch (event) {
      case PointerDownEvent():
        _handleDown(event);
      case PointerMoveEvent():
        _handleMove(event);
      case PointerUpEvent():
        _handleUp(event);
      case PointerCancelEvent():
        _cancel();
      default:
        // No other event of a tracked pointer is a touch.
        break;
    }
  }

  void _handleDown(PointerDownEvent event) {
    final index = _pointerIds.length;
    _pointerIds.add(event.pointer);
    _positions.add(event.localPosition);
    if (index == 0) {
      if (!onTouch(_event(ChartTouchAction.down, 0))) {
        // Android: a view whose onTouchEvent returns false for ACTION_DOWN gets no more events of the gesture.
        _pointerIds.clear();
        _positions.clear();
        _leaveGesture([event.pointer]);
        return;
      }
    } else {
      onTouch(_event(ChartTouchAction.pointerDown, index));
    }
    if (!_pointerIds.contains(event.pointer)) return;
    // Android's parent intercepts first: re-adding the route puts the chart after every recognizer that added one for
    // this finger at its down, because PointerRouter (package:flutter/src/gestures/pointer_router.dart) calls a
    // pointer's routes in the order they were added. Its `route` iterates a copy of that map, so the re-add during
    // dispatch is safe.
    final router = GestureBinding.instance.pointerRouter;
    router.removeRoute(event.pointer, handleEvent);
    router.addRoute(event.pointer, handleEvent, event.transform);
  }

  void _handleMove(PointerMoveEvent event) {
    final index = _pointerIds.indexOf(event.pointer);
    if (index < 0) return;
    _positions[index] = event.localPosition;
    onTouch(_event(ChartTouchAction.move, 0));
  }

  void _handleUp(PointerUpEvent event) {
    final index = _pointerIds.indexOf(event.pointer);
    if (index >= 0) {
      _positions[index] = event.localPosition;
      final ChartTouchEvent touch;
      if (_pointerIds.length > 1) {
        touch = _event(ChartTouchAction.pointerUp, index);
        _pointerIds.removeAt(index);
        _positions.removeAt(index);
      } else {
        touch = _event(ChartTouchAction.up, 0);
        _pointerIds.clear();
        _positions.clear();
      }
      onTouch(touch);
    }
    stopTrackingPointer(event.pointer);
  }

  /// Ends the current gesture with one [ChartTouchAction.cancel] to [onTouch], Android's `ACTION_CANCEL`, and leaves
  /// the arena for all of its fingers. Does nothing more than leave the arena when no gesture is in progress.
  void _cancel() {
    final pointers = List<int>.of(_pointerIds);
    if (pointers.isNotEmpty) {
      // The gesture is over before onTouch hears of it, so nothing it causes delivers a second cancel.
      final touch = _event(ChartTouchAction.cancel, 0);
      _pointerIds.clear();
      _positions.clear();
      onTouch(touch);
    }
    _leaveGesture(pointers);
  }

  /// Gives up the arenas this recognizer has not resolved yet and stops tracking [pointers].
  void _leaveGesture(List<int> pointers) {
    resolve(GestureDisposition.rejected);
    for (final pointer in pointers) {
      stopTrackingPointer(pointer);
    }
  }

  /// An event of [action] with the current fingers, in lists of its own.
  ChartTouchEvent _event(ChartTouchAction action, int actionIndex) =>
      ChartTouchEvent(
        action: action,
        actionIndex: actionIndex,
        pointerIds: List<int>.unmodifiable(_pointerIds),
        positions: List<Offset>.unmodifiable(_positions),
        eventTimeMillis: _lastTimeStamp.inMilliseconds,
      );

  /// Another recognizer won the arena for [pointer]: when it is a finger of the current gesture, the chart gets a
  /// cancel, Android's `ACTION_CANCEL` when a parent intercepts the gesture.
  @override
  void rejectGesture(int pointer) {
    if (_pointerIds.contains(pointer)) {
      _cancel();
    } else {
      stopTrackingPointer(pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    // Every way to stop tracking a finger ends the gesture first; this only guards against one that does not.
    if (_pointerIds.isNotEmpty) _cancel();
    _claimed = false;
  }

  /// Also cancels a gesture in progress, as Android's `ViewGroup` sends `ACTION_CANCEL` to a child view that is
  /// removed during a gesture.
  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  String get debugDescription => 'chart';
}
