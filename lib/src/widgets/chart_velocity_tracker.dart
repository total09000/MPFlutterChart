// Android shim: android.view.VelocityTracker (and Utils.velocityTrackerPointerUpCleanUpIfNecessary of
// MPChartLib/src/main/kotlin/com/github/mikephil/charting/utils/Utils.kt) for MPAndroidChart v4.0.1 port
import 'dart:ui' show Offset;

import 'package:flutter/gestures.dart' show PointerDeviceKind, VelocityTracker;

import '../utils/utils.dart';
import 'chart_touch_event.dart';

/// Measures the velocity of each pointer of a touch gesture, standing in for Android's `VelocityTracker`.
///
/// Feed it every [ChartTouchEvent] of the gesture with [addMovement], then call [computeCurrentVelocity] and read
/// [getXVelocity] / [getYVelocity] per pointer id. Each pointer is tracked by one of Flutter's [VelocityTracker]s
/// (least squares over the last 100 ms, like Android's default strategy).
///
/// Which events add a sample follows Android: a down clears every pointer, a pointer down starts the new pointer's
/// trace over, and moves add the position of every pointer. Ups and pointer ups add nothing, so the velocity of a
/// lifted pointer stays as it was, except that an up that comes more than 40 ms after the previous event clears
/// every pointer (the fingers had stopped). Cancels are ignored.
///
/// Flutter's tracker reads the gesture binding's sampling clock, which every Flutter app has; a test without a
/// widget calls `TestWidgetsFlutterBinding.ensureInitialized()` first.
class ChartVelocityTracker {
  /// Creates an empty tracker, `VelocityTracker.obtain()`.
  ChartVelocityTracker();

  /// Time without movement after which Android assumes the pointers stopped, `ASSUME_POINTER_STOPPED_TIME`.
  static const int _ASSUME_POINTER_STOPPED_MILLIS = 40;

  final Map<int, VelocityTracker> _trackers = {};
  final Map<int, Offset> _velocities = {};
  int? _lastEventTimeMillis;

  /// Adds the pointer positions of [event] to the tracked movement, `VelocityTracker.addMovement(MotionEvent)`.
  void addMovement(ChartTouchEvent event) {
    switch (event.action) {
      case ChartTouchAction.down:
        // Clear all pointers on down before adding the new movement.
        clear();
      case ChartTouchAction.pointerDown:
        // Start a new movement trace for the pointer that just went down; the others keep theirs.
        _trackers.remove(event.getPointerId(event.actionIndex));
      case ChartTouchAction.move:
        break;
      case ChartTouchAction.up:
      case ChartTouchAction.pointerUp:
        // An up reports the last known positions only, so it adds nothing and keeps the last velocity, unless the
        // pointers have not moved for too long.
        final last = _lastEventTimeMillis;
        if (last != null &&
            event.eventTimeMillis - last > _ASSUME_POINTER_STOPPED_MILLIS) {
          _trackers.clear();
        }
        return;
      case ChartTouchAction.cancel:
        return;
    }

    final time = Duration(milliseconds: event.eventTimeMillis);
    for (var i = 0; i < event.pointerCount; i++) {
      _trackers
          .putIfAbsent(
            event.getPointerId(i),
            () => VelocityTracker.withKind(PointerDeviceKind.touch),
          )
          .addPosition(time, event.positions[i]);
    }
    _lastEventTimeMillis = event.eventTimeMillis;
  }

  /// Computes the current velocity of every tracked pointer, `VelocityTracker.computeCurrentVelocity(units, max)`.
  ///
  /// [units] is the time unit of the result in milliseconds: 1 gives pixels per millisecond, 1000 pixels per second.
  /// [maxVelocity] is the largest magnitude each of the x and y velocities may have, in the same units; the two
  /// components are clamped separately, as on Android.
  void computeCurrentVelocity(
    int units, [
    double maxVelocity = double.maxFinite,
  ]) {
    _velocities.clear();
    _trackers.forEach((pointerId, tracker) {
      final perSecond =
          tracker.getVelocityEstimate()?.pixelsPerSecond ?? Offset.zero;
      final scale = units / 1000;
      _velocities[pointerId] = Offset(
        _clampMagnitude(perSecond.dx * scale, maxVelocity),
        _clampMagnitude(perSecond.dy * scale, maxVelocity),
      );
    });
  }

  /// The x velocity of the pointer with [pointerId] from the last [computeCurrentVelocity], 0 when it is not
  /// tracked, `VelocityTracker.getXVelocity(id)`.
  double getXVelocity(int pointerId) => _velocities[pointerId]?.dx ?? 0;

  /// The y velocity of the pointer with [pointerId] from the last [computeCurrentVelocity], 0 when it is not
  /// tracked, `VelocityTracker.getYVelocity(id)`.
  double getYVelocity(int pointerId) => _velocities[pointerId]?.dy ?? 0;

  /// Forgets all tracked movement and computed velocities, `VelocityTracker.clear()`.
  void clear() {
    _trackers.clear();
    _velocities.clear();
    _lastEventTimeMillis = null;
  }

  /// Releases the tracker, `VelocityTracker.recycle()`. Here the same as [clear]; there is no pool.
  void recycle() {
    clear();
  }

  /// Clears [tracker] when the pointer that was lifted in [ev] moved in the opposite direction of another pointer,
  /// so a pinch does not end in a fling. Kotlin's `Utils.velocityTrackerPointerUpCleanUpIfNecessary`.
  static void pointerUpCleanUpIfNecessary(
    ChartTouchEvent ev,
    ChartVelocityTracker tracker,
  ) {
    tracker.computeCurrentVelocity(1000, Utils.maximumFlingVelocity.toDouble());
    final upIndex = ev.actionIndex;
    final id1 = ev.getPointerId(upIndex);
    final x1 = tracker.getXVelocity(id1);
    final y1 = tracker.getYVelocity(id1);
    for (var i = 0; i < ev.pointerCount; i++) {
      if (i == upIndex) continue;
      final id2 = ev.getPointerId(i);
      final x = x1 * tracker.getXVelocity(id2);
      final y = y1 * tracker.getYVelocity(id2);
      if (x + y < 0) {
        tracker.clear();
        break;
      }
    }
  }

  /// Limits [value] to the range -[max] .. [max]; NaN stays NaN.
  static double _clampMagnitude(double value, double max) {
    if (value > max) return max;
    if (value < -max) return -max;
    return value;
  }
}
