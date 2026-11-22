// Android shim: android.view.MotionEvent (the parts the touch listeners read) for MPAndroidChart v4.0.1 port
import 'dart:ui' show Offset;

/// The kind of a [ChartTouchEvent], standing in for `MotionEvent.getActionMasked()`.
///
/// [down] is `ACTION_DOWN` (the first finger touches), [move] `ACTION_MOVE`, [up] `ACTION_UP` (the last finger
/// lifts), [cancel] `ACTION_CANCEL`, [pointerDown] `ACTION_POINTER_DOWN` (another finger touches) and [pointerUp]
/// `ACTION_POINTER_UP` (a finger lifts while others stay down).
enum ChartTouchAction { down, move, up, cancel, pointerDown, pointerUp }

/// One touch event as the chart touch listeners see it: the gesture recognizer folds Flutter's pointer events into
/// these, shaped like Android's `MotionEvent`, so the ported state machines read them unchanged.
///
/// Positions are in the chart's local coordinates, in logical pixels. The pointers are listed in the same order in
/// [pointerIds] and [positions]; for [ChartTouchAction.pointerDown] and [ChartTouchAction.pointerUp], [actionIndex]
/// is the index of the pointer that went down or up.
class ChartTouchEvent {
  /// Creates an event. [pointerIds] and [positions] must have the same length, at least 1.
  ChartTouchEvent({
    required this.action,
    this.actionIndex = 0,
    required this.pointerIds,
    required this.positions,
    required this.eventTimeMillis,
  }) : assert(pointerIds.length == positions.length),
       assert(positions.isNotEmpty);

  /// What happened, `MotionEvent.getActionMasked()`.
  final ChartTouchAction action;

  /// Index into [pointerIds] / [positions] of the pointer that went down or up, `MotionEvent.getActionIndex()`.
  final int actionIndex;

  /// The id of each pointer that is down, `MotionEvent.getPointerId(i)` for every index.
  final List<int> pointerIds;

  /// The position of each pointer that is down, `MotionEvent.getX(i)` / `getY(i)` for every index.
  final List<Offset> positions;

  /// When the event happened, in milliseconds, `MotionEvent.getEventTime()`.
  final int eventTimeMillis;

  /// The number of pointers in this event, `MotionEvent.getPointerCount()`.
  int get pointerCount => positions.length;

  /// The x position of the first pointer, `MotionEvent.getX()`.
  double get x => positions[0].dx;

  /// The y position of the first pointer, `MotionEvent.getY()`.
  double get y => positions[0].dy;

  /// The x position of the pointer at index [i], `MotionEvent.getX(i)`.
  double getX(int i) => positions[i].dx;

  /// The y position of the pointer at index [i], `MotionEvent.getY(i)`.
  double getY(int i) => positions[i].dy;

  /// The id of the pointer at index [i], `MotionEvent.getPointerId(i)`.
  int getPointerId(int i) => pointerIds[i];
}
