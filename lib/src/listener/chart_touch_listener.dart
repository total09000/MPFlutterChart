// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/listener/ChartTouchListener.kt
//
// Android's GestureDetector and its SimpleOnGestureListener base class: the gesture callbacks the
// detector calls (onDown, onSingleTapUp, onLongPress, onScroll, onFling, onDoubleTap, onDoubleTapEvent) are members of
// ChartTouchListener with SimpleOnGestureListener's defaults, and _GestureState below is a port of the parts of
// android.view.GestureDetector that call them, with Flutter's kTouchSlop, kDoubleTapTimeout, kDoubleTapMinTime,
// kDoubleTapTouchSlop, kDoubleTapSlop and kLongPressTimeout as its ViewConfiguration values and Utils' fling velocities.
// Not ported, because no chart listener acts on them: onShowPress, onSingleTapConfirmed and onContextClick (and the
// SHOW_PRESS message; Android's TAP message only decides whether a down can be the second tap of a double tap, which
// is checked on the event times). Kotlin's `gestureDetector.onTouchEvent(event)` is [gestureDetectorOnTouchEvent].
import 'dart:async' show Timer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show internal, protected;
import 'package:flutter/gestures.dart'
    show
        kDoubleTapMinTime,
        kDoubleTapSlop,
        kDoubleTapTimeout,
        kDoubleTapTouchSlop,
        kLongPressTimeout,
        kTouchSlop;

import '../charts/chart.dart';
import '../highlight/highlight.dart';
import '../utils/utils.dart';
import '../widgets/chart_touch_event.dart';
import '../widgets/chart_velocity_tracker.dart';

/// The kind of gesture the user performed on the chart, reported to `OnChartGestureListener`.
///
/// [NONE] no gesture yet; [DRAG] single finger drag that pans the chart or moves the highlight;
/// [X_ZOOM] and [Y_ZOOM] two finger zoom along one axis; [PINCH_ZOOM] two finger zoom along both axes;
/// [ROTATE] single finger rotation of a pie or radar chart; [SINGLE_TAP], [DOUBLE_TAP], [LONG_PRESS] and
/// [FLING] the corresponding tap, press and swipe gestures.
///
/// Kotlin's `ChartTouchListener.ChartGesture`; a top-level enum because Dart has no nested types.
enum ChartGesture {
  NONE,
  DRAG,
  X_ZOOM,
  Y_ZOOM,
  PINCH_ZOOM,
  ROTATE,
  SINGLE_TAP,
  DOUBLE_TAP,
  LONG_PRESS,
  FLING,
}

/// Base class for the touch handling of a chart. Every chart creates one touch listener for itself:
/// `BarLineChartTouchListener` for bar, line, scatter, candle and bubble charts and
/// `PieRadarChartTouchListener` for pie and radar charts.
///
/// It detects taps, long presses and flings with a gesture detector, keeps the current touch mode and
/// forwards gesture events to the chart's `OnChartGestureListener`s.
abstract class ChartTouchListener<T extends Chart> {
  /// Creates the touch listener of [chart].
  ChartTouchListener(this.chart);

  /// The chart this listener handles touches for.
  @protected
  final T chart;

  ChartGesture _lastGesture = ChartGesture.NONE;

  /// The last gesture that was recognised, [ChartGesture.NONE] before any touch.
  ChartGesture get lastGesture => _lastGesture;

  @protected
  set lastGesture(ChartGesture value) => _lastGesture = value;

  int _touchMode = NONE;

  /// The touch state the listener is currently in, one of the constants such as [NONE], [DRAG] or [PINCH_ZOOM].
  int get touchMode => _touchMode;

  @protected
  set touchMode(int value) => _touchMode = value;

  /// The highlight selected by the last touch, null when nothing is selected by touch.
  Highlight? lastHighlighted;

  /// Detector that turns raw touch events into taps, long presses and flings. It is created on first use.
  late final _GestureState _gestureDetector = _GestureState(this);

  /// Passes [event] to the gesture detector, which calls [onDown], [onSingleTapUp], [onLongPress], [onScroll],
  /// [onFling], [onDoubleTap] and [onDoubleTapEvent] as the gesture develops. Returns true when one of the callbacks
  /// it called returned true. Kotlin's `gestureDetector.onTouchEvent(event)`.
  @protected
  bool gestureDetectorOnTouchEvent(ChartTouchEvent event) =>
      _gestureDetector.onTouchEvent(event);

  /// Cancels the gesture detector's pending long press, so [onLongPress] does not fire for the current touch.
  ///
  /// Not in Kotlin: the chart calls it when it leaves the screen, so that no timer outlives it, and
  /// `BarLineChartTouchListener` when a touch ends that the detector no longer saw. Internal API.
  @internal
  void cancelLongPress() {
    _gestureDetector.cancelLongPress();
  }

  /// Handles one touch event of [chart] and returns true if it was consumed, `View.OnTouchListener.onTouch`.
  bool onTouch(T chart, ChartTouchEvent event);

  /// Reports the start of a touch gesture to the chart's gesture listeners.
  void startAction(ChartTouchEvent me) {
    chart.notifyGesture((it) => it.onChartGestureStart(me, lastGesture));
  }

  /// Reports the end of a touch gesture to the chart's gesture listeners.
  void endAction(ChartTouchEvent me) {
    chart.notifyGesture((it) => it.onChartGestureEnd(me, lastGesture));
  }

  /// Applies [h] as the chart's highlight and remembers it in [lastHighlighted]. Tapping the already
  /// highlighted value, or passing null, clears the highlight instead. The chart's selection listeners are called.
  @protected
  void performHighlight(Highlight? h, ChartTouchEvent e) {
    if (h == null || h.equalTo(lastHighlighted)) {
      chart.highlightValueOf(null, callListener: true);
      lastHighlighted = null;
    } else {
      chart.highlightValueOf(h, callListener: true);
      lastHighlighted = h;
    }
  }

  // GestureDetector.SimpleOnGestureListener: the gesture detector's callbacks, which do nothing and return false
  // unless overridden.

  /// Called when a first finger touches, `onDown`. Returns whether the event was consumed; false by default.
  bool onDown(ChartTouchEvent e) => false;

  /// Called when a finger lifts after a touch that stayed within the touch slop and was no long press and no second
  /// tap of a double tap, `onSingleTapUp`. [e] is the up event. Returns whether the event was consumed; false by
  /// default.
  bool onSingleTapUp(ChartTouchEvent e) => false;

  /// Called when a finger rests within the touch slop for `kLongPressTimeout`, `onLongPress`. [e] is the down event.
  void onLongPress(ChartTouchEvent e) {}

  /// Called for each move after the finger left the touch slop, `onScroll`. [e1] is the down event, [e2] the move
  /// event, [distanceX] and [distanceY] the distance moved since the previous call (previous minus current position).
  /// Returns whether the event was consumed; false by default.
  bool onScroll(
    ChartTouchEvent? e1,
    ChartTouchEvent e2,
    double distanceX,
    double distanceY,
  ) => false;

  /// Called when a finger that left the touch slop lifts faster than `Utils.minimumFlingVelocity`, `onFling`. [e1] is
  /// the down event, [e2] the up event, [velocityX] and [velocityY] the velocities in pixels per second. Returns
  /// whether the event was consumed; false by default.
  bool onFling(
    ChartTouchEvent? e1,
    ChartTouchEvent e2,
    double velocityX,
    double velocityY,
  ) => false;

  /// Called when the second down of a double tap arrives, `onDoubleTap`. [e] is the down event of the first tap.
  /// Returns whether the event was consumed; false by default.
  bool onDoubleTap(ChartTouchEvent e) => false;

  /// Called for the down, moves and up of the second tap of a double tap, `onDoubleTapEvent`. Returns whether the
  /// event was consumed; false by default.
  bool onDoubleTapEvent(ChartTouchEvent e) => false;

  /// Touch mode: no gesture in progress.
  static const int NONE = 0;

  /// Touch mode: one finger is dragging.
  static const int DRAG = 1;

  /// Touch mode: two fingers are zooming the x axis.
  static const int X_ZOOM = 2;

  /// Touch mode: two fingers are zooming the y axis.
  static const int Y_ZOOM = 3;

  /// Touch mode: two fingers are zooming both axes.
  static const int PINCH_ZOOM = 4;

  /// Touch mode: a zoom just ended and one finger is still down; no drag is started from it.
  static const int POST_ZOOM = 5;

  /// Touch mode: one finger is rotating a pie or radar chart.
  static const int ROTATE = 6;

  /// Straight line distance in pixels between the points ([eventX], [eventY]) and ([startX], [startY]).
  static double distance(
    double eventX,
    double startX,
    double eventY,
    double startY,
  ) {
    final dx = eventX - startX;
    final dy = eventY - startY;
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// The state of Android's `GestureDetector` for one [ChartTouchListener]: from the touch events it is fed it reports
/// down, single tap up, long press, scroll, fling and double tap to the listener's callbacks, following
/// `GestureDetector.onTouchEvent` line by line.
///
/// Android's handler messages: LONG_PRESS is a [Timer] of `kLongPressTimeout` from the down; TAP (pending for
/// `kDoubleTapTimeout` after a first down, a second down while it is pending can be a double tap) is the event time
/// [_tapDeadline].
class _GestureState {
  _GestureState(this._listener);

  final ChartTouchListener _listener;

  static const double _touchSlopSquare = kTouchSlop * kTouchSlop;
  static const double _doubleTapTouchSlopSquare =
      kDoubleTapTouchSlop * kDoubleTapTouchSlop;
  static const double _doubleTapSlopSquare = kDoubleTapSlop * kDoubleTapSlop;

  static final int _doubleTapTimeout = kDoubleTapTimeout.inMilliseconds;
  static final int _doubleTapMinTime = kDoubleTapMinTime.inMilliseconds;

  ChartTouchEvent? _currentDownEvent;
  ChartTouchEvent? _previousUpEvent;

  /// Event time before which a down finds the TAP message pending, or null when it is not pending.
  int? _tapDeadline;

  /// The pending LONG_PRESS message.
  Timer? _longPressTimer;

  bool _inLongPress = false;
  bool _alwaysInTapRegion = false;
  bool _alwaysInBiggerTapRegion = false;
  bool _isDoubleTapping = false;

  double _lastFocusX = 0;
  double _lastFocusY = 0;
  double _downFocusX = 0;
  double _downFocusY = 0;

  /// Determines the velocity of the fling.
  ChartVelocityTracker? _velocityTracker;

  /// Analyzes [ev] and calls the listener's callbacks when a gesture is recognised. Returns true when a callback
  /// returned true.
  bool onTouchEvent(ChartTouchEvent ev) {
    final action = ev.action;

    final velocityTracker = _velocityTracker ??= ChartVelocityTracker();
    velocityTracker.addMovement(ev);

    final pointerUp = action == ChartTouchAction.pointerUp;
    final skipIndex = pointerUp ? ev.actionIndex : -1;

    // Determine focal point
    var sumX = 0.0;
    var sumY = 0.0;
    final count = ev.pointerCount;
    for (var i = 0; i < count; i++) {
      if (skipIndex == i) continue;
      sumX += ev.getX(i);
      sumY += ev.getY(i);
    }
    final div = pointerUp ? count - 1 : count;
    final focusX = sumX / div;
    final focusY = sumY / div;

    var handled = false;

    switch (action) {
      case ChartTouchAction.pointerDown:
        _downFocusX = _lastFocusX = focusX;
        _downFocusY = _lastFocusY = focusY;
        // Cancel long press and taps
        _cancelTaps();

      case ChartTouchAction.pointerUp:
        _downFocusX = _lastFocusX = focusX;
        _downFocusY = _lastFocusY = focusY;

        // Check the dot product of current velocities.
        // If the pointer that left was opposing another velocity vector, clear.
        ChartVelocityTracker.pointerUpCleanUpIfNecessary(ev, velocityTracker);

      case ChartTouchAction.down:
        final hadTapMessage = _hasTapMessage(ev);
        if (hadTapMessage) _tapDeadline = null;
        final currentDownEvent = _currentDownEvent;
        final previousUpEvent = _previousUpEvent;
        if (currentDownEvent != null &&
            previousUpEvent != null &&
            hadTapMessage &&
            _isConsideredDoubleTap(currentDownEvent, previousUpEvent, ev)) {
          // This is a second tap
          _isDoubleTapping = true;
          // Give a callback with the first tap of the double-tap
          handled |= _listener.onDoubleTap(currentDownEvent);
          // Give a callback with down event of the double-tap
          handled |= _listener.onDoubleTapEvent(ev);
        } else {
          // This is a first tap
          _tapDeadline = ev.eventTimeMillis + _doubleTapTimeout;
        }

        _downFocusX = _lastFocusX = focusX;
        _downFocusY = _lastFocusY = focusY;
        _currentDownEvent = ev;
        _alwaysInTapRegion = true;
        _alwaysInBiggerTapRegion = true;
        _inLongPress = false;

        _longPressTimer?.cancel();
        _longPressTimer = Timer(kLongPressTimeout, _dispatchLongPress);
        handled |= _listener.onDown(ev);

      case ChartTouchAction.move:
        if (_inLongPress) break;

        final scrollX = _lastFocusX - focusX;
        final scrollY = _lastFocusY - focusY;
        if (_isDoubleTapping) {
          // Give the move events of the double-tap
          handled |= _listener.onDoubleTapEvent(ev);
        } else if (_alwaysInTapRegion) {
          // Android truncates the deltas to whole pixels.
          final deltaX = (focusX - _downFocusX).truncateToDouble();
          final deltaY = (focusY - _downFocusY).truncateToDouble();
          final distance = (deltaX * deltaX) + (deltaY * deltaY);
          if (distance > _touchSlopSquare) {
            handled = _listener.onScroll(
              _currentDownEvent,
              ev,
              scrollX,
              scrollY,
            );
            _lastFocusX = focusX;
            _lastFocusY = focusY;
            _alwaysInTapRegion = false;
            _tapDeadline = null;
            cancelLongPress();
          }
          if (distance > _doubleTapTouchSlopSquare) {
            _alwaysInBiggerTapRegion = false;
          }
        } else if (scrollX.abs() >= 1 || scrollY.abs() >= 1) {
          handled = _listener.onScroll(_currentDownEvent, ev, scrollX, scrollY);
          _lastFocusX = focusX;
          _lastFocusY = focusY;
        }

      case ChartTouchAction.up:
        final currentUpEvent = ev;
        if (_isDoubleTapping) {
          // Finally, give the up event of the double-tap
          handled |= _listener.onDoubleTapEvent(ev);
        } else if (_inLongPress) {
          _tapDeadline = null;
          _inLongPress = false;
        } else if (_alwaysInTapRegion) {
          handled = _listener.onSingleTapUp(ev);
        } else {
          // A fling must travel the minimum tap distance
          final pointerId = ev.getPointerId(0);
          velocityTracker.computeCurrentVelocity(
            1000,
            Utils.maximumFlingVelocity.toDouble(),
          );
          final velocityY = velocityTracker.getYVelocity(pointerId);
          final velocityX = velocityTracker.getXVelocity(pointerId);

          if (velocityY.abs() > Utils.minimumFlingVelocity ||
              velocityX.abs() > Utils.minimumFlingVelocity) {
            handled = _listener.onFling(
              _currentDownEvent,
              ev,
              velocityX,
              velocityY,
            );
          }
        }
        _previousUpEvent = currentUpEvent;
        // This may have been cleared when we called out to the application above.
        _velocityTracker?.recycle();
        _velocityTracker = null;
        _isDoubleTapping = false;
        cancelLongPress();

      case ChartTouchAction.cancel:
        _cancel();
    }

    return handled;
  }

  /// Removes the pending LONG_PRESS message.
  void cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  /// Android's `hasMessages(TAP)` at the time of [down].
  bool _hasTapMessage(ChartTouchEvent down) {
    final deadline = _tapDeadline;
    return deadline != null && down.eventTimeMillis < deadline;
  }

  void _cancel() {
    cancelLongPress();
    _tapDeadline = null;
    _velocityTracker?.recycle();
    _velocityTracker = null;
    _isDoubleTapping = false;
    _alwaysInTapRegion = false;
    _alwaysInBiggerTapRegion = false;
    _inLongPress = false;
  }

  void _cancelTaps() {
    cancelLongPress();
    _tapDeadline = null;
    _isDoubleTapping = false;
    _alwaysInTapRegion = false;
    _alwaysInBiggerTapRegion = false;
    _inLongPress = false;
  }

  bool _isConsideredDoubleTap(
    ChartTouchEvent firstDown,
    ChartTouchEvent firstUp,
    ChartTouchEvent secondDown,
  ) {
    if (!_alwaysInBiggerTapRegion) return false;

    final deltaTime = secondDown.eventTimeMillis - firstUp.eventTimeMillis;
    if (deltaTime > _doubleTapTimeout || deltaTime < _doubleTapMinTime) {
      return false;
    }

    final deltaX =
        firstDown.x.truncateToDouble() - secondDown.x.truncateToDouble();
    final deltaY =
        firstDown.y.truncateToDouble() - secondDown.y.truncateToDouble();
    return deltaX * deltaX + deltaY * deltaY < _doubleTapSlopSquare;
  }

  void _dispatchLongPress() {
    _longPressTimer = null;
    _tapDeadline = null;
    _inLongPress = true;
    final down = _currentDownEvent;
    if (down != null) _listener.onLongPress(down);
  }
}
