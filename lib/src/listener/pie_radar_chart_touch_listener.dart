// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/listener/PieRadarChartTouchListener.kt
//
// AnimationUtils.currentAnimationTimeMillis() is the [PieRadarChartTouchListener.clock].
// Utils.postInvalidateOnAnimation redraws the chart and keeps a Ticker from the host's vsync running that calls
// Chart.computeScroll on every frame until the deceleration stops, as in
// BarLineChartTouchListener; Android's view system called computeScroll from each draw. The `View v` parameter of
// onTouch is the chart. The private nested AngularVelocitySample is the private top-level _AngularVelocitySample.
// Not ported: the onSingleTapConfirmed override, since ChartTouchListener has no such callback.
// pointerDown / pointerUp events are not handled, as Kotlin's `when` has no branch for them.
//
// Deliberate deviation: the MOVE that starts a rotation also sends the gesture detector a
// cancel event. On Android the detector's touch slop is 8 dp, the same as the rotation threshold, so the move that
// starts a rotation has always left the tap region: the detector no longer reports a tap or a long press for that
// touch. Flutter's kTouchSlop is 18, so after a rotation of 8 to 18 px the detector would still report the up as a
// tap: onSingleTapUp would highlight a slice and return true, the UP branch would be skipped and the touch mode would
// stay ROTATE, so the next touch would rotate without the 8 dp threshold and without claiming the gesture. The cancel
// puts the detector where Android's is after its slop (no tap, long press or double tap candidate).
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/scheduler.dart' show Ticker;

import '../charts/pie_chart.dart';
import '../charts/pie_radar_chart_base.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';
import '../widgets/chart_touch_event.dart';
import 'chart_touch_listener.dart';

/// Touch handling for pie and radar charts: tap to highlight, long press and single finger rotation with optional
/// deceleration after the finger lifts.
///
/// Rotation starts once the finger moved more than 8 dp from where it touched down, and only when the chart has
/// rotation enabled and the touch started on the drawn chart. Angles are in degrees, clockwise from 3 o'clock.
///
/// The deceleration after a rotation runs on a ticker from the chart host's vsync. A chart without a host, or whose
/// host has no vsync, does not decelerate by itself: call `Chart.computeScroll` once per frame to run it.
class PieRadarChartTouchListener extends ChartTouchListener<PieRadarChartBase> {
  /// Creates the touch listener of [chart].
  PieRadarChartTouchListener(super.chart);

  final MPPointF _touchStartPoint = MPPointF.getInstance(0, 0);

  double _startAngle = 0;

  final List<_AngularVelocitySample> _velocitySamples = [];

  int _decelerationLastTime = 0;
  double _decelerationAngularVelocity = 0;

  bool _touchStartedOnChart = false;

  /// Calls [computeScroll] through `Chart.computeScroll` on every frame while a deceleration runs, or null.
  Ticker? _decelerationTicker;

  int Function() _clock = _currentTimeMillis;

  /// The time in milliseconds the velocity samples and the deceleration are measured with, Kotlin's
  /// `AnimationUtils.currentAnimationTimeMillis()`. By default `DateTime.now().millisecondsSinceEpoch`.
  int Function() get clock => _clock;

  /// Replaces the [clock], so that a test can advance the velocity and deceleration time deterministically.
  @visibleForTesting
  set clock(int Function() value) => _clock = value;

  static int _currentTimeMillis() => DateTime.now().millisecondsSinceEpoch;

  /// Handles one touch event of [chart] and returns true, as Kotlin does for every event.
  @override
  bool onTouch(PieRadarChartBase chart, ChartTouchEvent event) {
    if (gestureDetectorOnTouchEvent(event)) return true;

    if (chart.isRotationEnabled) {
      final x = event.x;
      final y = event.y;

      switch (event.action) {
        case ChartTouchAction.down:
          startAction(event);

          stopDeceleration();

          _resetVelocity();

          if (chart.isDragDecelerationEnabled) _sampleVelocity(x, y);

          setGestureStartAngle(x, y);
          _touchStartPoint.x = x;
          _touchStartPoint.y = y;
          _touchStartedOnChart = _isOnChart(x, y);

        case ChartTouchAction.move:
          if (chart.isDragDecelerationEnabled) _sampleVelocity(x, y);

          if (touchMode == ChartTouchListener.NONE &&
              _touchStartedOnChart &&
              ChartTouchListener.distance(
                    x,
                    _touchStartPoint.x,
                    y,
                    _touchStartPoint.y,
                  ) >
                  Utils.convertDpToPixel(8)) {
            lastGesture = ChartGesture.ROTATE;
            touchMode = ChartTouchListener.ROTATE;
            chart.disableScroll();
            // Not in Kotlin (see the file header): leave the detector's tap region as Android's 8 dp
            // slop would have.
            gestureDetectorOnTouchEvent(
              ChartTouchEvent(
                action: ChartTouchAction.cancel,
                actionIndex: 0,
                pointerIds: event.pointerIds,
                positions: event.positions,
                eventTimeMillis: event.eventTimeMillis,
              ),
            );
          } else if (touchMode == ChartTouchListener.ROTATE) {
            updateGestureRotation(x, y);
            chart.invalidate();
          }

        case ChartTouchAction.up:
          if (chart.isDragDecelerationEnabled && _touchStartedOnChart) {
            stopDeceleration();

            _sampleVelocity(x, y);

            _decelerationAngularVelocity = _calculateVelocity();

            if (_decelerationAngularVelocity != 0) {
              _decelerationLastTime = clock();
              _postInvalidateOnAnimation();
            }
          }

          chart.enableScroll();

          touchMode = ChartTouchListener.NONE;

          endAction(event);

        case ChartTouchAction.cancel:
          chart.enableScroll();
          touchMode = ChartTouchListener.NONE;
          endAction(event);

        case ChartTouchAction.pointerDown:
        case ChartTouchAction.pointerUp:
          break;
      }
    }

    return true;
  }

  /// Reports the long press [me], the down event, to the chart's gesture listeners.
  @override
  void onLongPress(ChartTouchEvent me) {
    lastGesture = ChartGesture.LONG_PRESS;
    chart.notifyGesture((it) => it.onChartLongPressed(me));
  }

  /// Reports the tap [e], the up event, to the chart's gesture listeners and, while `isHighlightPerTapEnabled` is
  /// true, highlights the value under it or clears the highlight. Returns true when it highlighted, so the event is
  /// consumed.
  @override
  bool onSingleTapUp(ChartTouchEvent e) {
    lastGesture = ChartGesture.SINGLE_TAP;

    chart.notifyGesture((it) => it.onChartSingleTapped(e));

    if (!chart.isHighlightPerTapEnabled) return false;

    final high = chart.getHighlightByTouchPoint(e.x, e.y);
    performHighlight(high, e);

    return true;
  }

  void _resetVelocity() {
    _velocitySamples.clear();
  }

  void _sampleVelocity(double touchLocationX, double touchLocationY) {
    final currentTime = clock();

    _velocitySamples.add(
      _AngularVelocitySample(
        currentTime,
        chart.getAngleForPoint(touchLocationX, touchLocationY),
      ),
    );

    var i = 0;
    var count = _velocitySamples.length;
    while (i < count - 2) {
      if (currentTime - _velocitySamples[i].time > 1000) {
        _velocitySamples.removeAt(0);
        i--;
        count--;
      } else {
        break;
      }
      i++;
    }
  }

  double _calculateVelocity() {
    if (_velocitySamples.isEmpty) return 0;

    final firstSample = _velocitySamples[0];
    final lastSample = _velocitySamples[_velocitySamples.length - 1];

    var beforeLastSample = firstSample;
    for (var i = _velocitySamples.length - 1; i >= 0; i--) {
      beforeLastSample = _velocitySamples[i];
      if (beforeLastSample.angle != lastSample.angle) break;
    }

    var timeDelta = (lastSample.time - firstSample.time) / 1000;
    if (timeDelta == 0) timeDelta = 0.1;

    var clockwise = lastSample.angle >= beforeLastSample.angle;

    if ((lastSample.angle - beforeLastSample.angle).abs() > 270.0) {
      clockwise = !clockwise;
    }

    if (lastSample.angle - firstSample.angle > 180.0) {
      firstSample.angle += 360;
    } else if (firstSample.angle - lastSample.angle > 180.0) {
      lastSample.angle += 360;
    }

    var velocity = ((lastSample.angle - firstSample.angle) / timeDelta).abs();

    if (!clockwise) velocity = -velocity;

    return velocity;
  }

  /// True when the pixel position lies on the drawn chart: inside its radius and, for a pie chart, outside its hole.
  bool _isOnChart(double x, double y) {
    final radius = chart.radius;
    final distance = chart.distanceToCenter(x, y);
    if (distance > radius) return false;

    final pie = chart;
    if (pie is! PieChart) return true;
    return !pie.isDrawHoleEnabled || distance > radius * (pie.holeRadius / 100);
  }

  /// Remembers the angle between the touch position ([x], [y]) in pixels and the chart's current rotation, so later
  /// rotation updates keep that offset.
  void setGestureStartAngle(double x, double y) {
    _startAngle = chart.getAngleForPoint(x, y) - chart.rawRotationAngle;
  }

  /// Rotates the chart so the angle remembered by [setGestureStartAngle] follows the touch position ([x], [y]) in
  /// pixels.
  void updateGestureRotation(double x, double y) {
    chart.rotationAngle = chart.getAngleForPoint(x, y) - _startAngle;
  }

  /// Stops a running rotation deceleration by setting its angular velocity to 0, and stops its ticker.
  void stopDeceleration() {
    _decelerationAngularVelocity = 0;
    _stopDecelerationTicker();
  }

  /// Advances the rotation deceleration by one frame: applies friction, rotates the chart by the angle covered and
  /// requests the next frame until the angular velocity is nearly 0. Called through `Chart.computeScroll`, on every
  /// frame by the deceleration ticker. Does nothing when no deceleration is running.
  void computeScroll() {
    if (_decelerationAngularVelocity == 0) return;

    final currentTime = clock();

    _decelerationAngularVelocity *= chart.dragDecelerationFrictionCoef;

    final timeInterval = (currentTime - _decelerationLastTime) / 1000;

    chart.rotationAngle =
        chart.rotationAngle + _decelerationAngularVelocity * timeInterval;

    _decelerationLastTime = currentTime;

    if (_decelerationAngularVelocity.abs() >= 0.001) {
      _postInvalidateOnAnimation();
    } else {
      stopDeceleration();
    }
  }

  /// Kotlin's `Utils.postInvalidateOnAnimation(chart)`: redraws the chart and keeps `Chart.computeScroll` running on
  /// every frame, through a ticker from the host's vsync, until [stopDeceleration]. Without a host vsync only the
  /// redraw happens.
  void _postInvalidateOnAnimation() {
    chart.invalidate();
    if (_decelerationTicker != null) return;
    final vsync = chart.host?.vsync;
    if (vsync == null) return;
    _decelerationTicker = vsync.createTicker(_onDecelerationTick)..start();
  }

  void _onDecelerationTick(Duration elapsed) {
    // The chart got another touch listener: this one's deceleration would never stop.
    if (!identical(chart.chartTouchListener, this)) {
      _stopDecelerationTicker();
      return;
    }
    chart.computeScroll();
  }

  void _stopDecelerationTicker() {
    final ticker = _decelerationTicker;
    if (ticker == null) return;
    _decelerationTicker = null;
    ticker
      ..stop()
      ..dispose();
  }
}

/// One velocity sample of a rotation: when, in milliseconds of the listener's clock, the touch was at which angle in
/// degrees. [angle] is changed by `_calculateVelocity` when the samples wrap across 0.
class _AngularVelocitySample {
  _AngularVelocitySample(this.time, this.angle);

  final int time;
  double angle;
}
