// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/listener/BarLineChartTouchListener.kt
//
// android.view.VelocityTracker is ChartVelocityTracker, ViewConfiguration.scaledTouchSlop is kTouchSlop and
// AnimationUtils.currentAnimationTimeMillis() is the [BarLineChartTouchListener.clock]. Utils.postInvalidateOnAnimation
// redraws the chart and keeps a Ticker from the host's vsync running that calls Chart.computeScroll on every frame
// until the deceleration stops; Android's view system called computeScroll from each draw.
// postInvalidate() is invalidate(), Log.i is debugPrint while Chart.isLogEnabled, getMeasuredHeight() is Chart.height.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/scheduler.dart' show Ticker;

import '../charts/bar_line_chart_base.dart';
import '../charts/horizontal_bar_chart.dart';
import '../graphics/matrix.dart';
import '../interfaces/datasets/i_data_set.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';
import '../widgets/chart_touch_event.dart';
import '../widgets/chart_velocity_tracker.dart';
import 'chart_touch_listener.dart';

/// Touch handling for bar, line, scatter, candle and bubble charts: tap to highlight, double tap to zoom in,
/// single finger drag to pan (or to move the highlight when the chart cannot pan), two finger pinch to zoom,
/// and fling with deceleration.
///
/// Which gestures work depends on the chart's drag, scale, pinch zoom and highlight settings. Zoom and drag
/// change the chart's touch matrix directly and are applied through the `ViewPortHandler`.
///
/// [touchMatrix] is the chart's touch matrix, see [matrix]; [dragTriggerDist] the distance in dp a finger must move
/// before the touch counts as a drag; charts create the listener with 3 dp.
///
/// The deceleration after a fling runs on a ticker from the chart host's vsync. A chart without a host, or whose host
/// has no vsync, does not decelerate by itself: call `Chart.computeScroll` once per frame to run it.
class BarLineChartTouchListener extends ChartTouchListener<BarLineChartBase> {
  /// Creates the touch listener of [chart], which changes [touchMatrix].
  BarLineChartTouchListener(
    super.chart,
    Matrix touchMatrix,
    this.dragTriggerDist,
  ) : _matrix = touchMatrix;

  /// Distance in dp a finger must move before the touch counts as a drag.
  double dragTriggerDist;

  Matrix _matrix;

  /// The touch matrix that holds the chart's zoom and drag state.
  Matrix get matrix => _matrix;

  final Matrix _savedMatrix = Matrix();

  final MPPointF _touchStartPoint = MPPointF.getInstance(0, 0);

  final MPPointF _touchPointCenter = MPPointF.getInstance(0, 0);

  double _savedXDist = 1;
  double _savedYDist = 1;
  double _savedDist = 1;

  final Float32List _savedMatrixValues = Float32List(9);

  IDataSet? _closestDataSetToTouch;

  ChartVelocityTracker? _velocityTracker;

  int _decelerationLastTime = 0;
  final MPPointF _decelerationCurrentPoint = MPPointF.getInstance(0, 0);
  final MPPointF _decelerationVelocity = MPPointF.getInstance(0, 0);

  final double _minScalePointerDistance = Utils.convertDpToPixel(3.5);

  bool _highlightDragging = false;

  /// Calls [computeScroll] through `Chart.computeScroll` on every frame while a deceleration runs, or null.
  Ticker? _decelerationTicker;

  int Function() _clock = _currentTimeMillis;

  /// The time in milliseconds the deceleration is measured with, Kotlin's
  /// `AnimationUtils.currentAnimationTimeMillis()`. By default `DateTime.now().millisecondsSinceEpoch`.
  int Function() get clock => _clock;

  /// Replaces the [clock], so that a test can advance the deceleration time deterministically.
  @visibleForTesting
  set clock(int Function() value) => _clock = value;

  static int _currentTimeMillis() => DateTime.now().millisecondsSinceEpoch;

  @override
  bool onTouch(BarLineChartBase chart, ChartTouchEvent event) {
    final tracker = _velocityTracker ??= ChartVelocityTracker();
    tracker.addMovement(event);

    if (event.action == ChartTouchAction.cancel) {
      tracker.recycle();
      _velocityTracker = null;
    }

    if (touchMode == ChartTouchListener.NONE) {
      gestureDetectorOnTouchEvent(event);
    } else if (event.action == ChartTouchAction.up ||
        event.action == ChartTouchAction.cancel) {
      // Not in Kotlin (deliberate deviation): the detector gets no events once a drag or zoom started, so on Android
      // its long press stays pending past the end of a drag that started within the touch slop and fires later.
      cancelLongPress();
    }

    switch (event.action) {
      case ChartTouchAction.down:
        _highlightDragging = false;
        startAction(event);
        stopDeceleration();
        _saveTouchStart(event);

      case ChartTouchAction.pointerDown:
        if (chart.isScaleEnabled && event.pointerCount >= 2) {
          chart.disableScroll();

          _saveTouchStart(event);

          _savedXDist = _getXDist(event);
          _savedYDist = _getYDist(event);
          _savedDist = _spacing(event);

          if (_savedDist > 10) {
            touchMode = chart.isPinchZoomEnabled
                ? ChartTouchListener.PINCH_ZOOM
                : chart.isScaleXEnabled != chart.isScaleYEnabled
                ? (chart.isScaleXEnabled
                      ? ChartTouchListener.X_ZOOM
                      : ChartTouchListener.Y_ZOOM)
                : (_savedXDist > _savedYDist
                      ? ChartTouchListener.X_ZOOM
                      : ChartTouchListener.Y_ZOOM);
          }

          _midPoint(_touchPointCenter, event);
        }

      case ChartTouchAction.move:
        if (touchMode == ChartTouchListener.DRAG) {
          chart.disableScroll();

          final x = chart.isDragXEnabled ? event.x - _touchStartPoint.x : 0.0;
          final y = chart.isDragYEnabled ? event.y - _touchStartPoint.y : 0.0;

          _performDrag(event, x, y);
        } else if (touchMode == ChartTouchListener.X_ZOOM ||
            touchMode == ChartTouchListener.Y_ZOOM ||
            touchMode == ChartTouchListener.PINCH_ZOOM) {
          chart.disableScroll();

          if (chart.isScaleXEnabled || chart.isScaleYEnabled) {
            _performZoom(event);
          }
        } else if (touchMode == ChartTouchListener.NONE &&
            ChartTouchListener.distance(
                  event.x,
                  _touchStartPoint.x,
                  event.y,
                  _touchStartPoint.y,
                ).abs() >
                Utils.convertDpToPixel(dragTriggerDist)) {
          final shouldPan =
              chart.isDragEnabled &&
              (!chart.isFullyZoomedOut || !chart.hasNoDragOffset);

          if (shouldPan) {
            final distanceX = (event.x - _touchStartPoint.x).abs();
            final distanceY = (event.y - _touchStartPoint.y).abs();

            if ((chart.isDragXEnabled || distanceY >= distanceX) &&
                (chart.isDragYEnabled || distanceY <= distanceX)) {
              lastGesture = ChartGesture.DRAG;
              touchMode = ChartTouchListener.DRAG;
            }
          } else if (chart.isHighlightPerDragEnabled &&
              (_highlightDragging || _startsHighlightDrag(event))) {
            _highlightDragging = true;
            lastGesture = ChartGesture.DRAG;
            _performHighlightDrag(event);
          }
        }

      case ChartTouchAction.up:
        final pointerId = event.getPointerId(0);
        tracker.computeCurrentVelocity(
          1000,
          Utils.maximumFlingVelocity.toDouble(),
        );
        final velocityY = tracker.getYVelocity(pointerId);
        final velocityX = tracker.getXVelocity(pointerId);

        if (velocityX.abs() > Utils.minimumFlingVelocity ||
            velocityY.abs() > Utils.minimumFlingVelocity) {
          if (touchMode == ChartTouchListener.DRAG &&
              chart.isDragDecelerationEnabled) {
            stopDeceleration();

            _decelerationLastTime = clock();

            _decelerationCurrentPoint.x = event.x;
            _decelerationCurrentPoint.y = event.y;

            _decelerationVelocity.x = velocityX;
            _decelerationVelocity.y = velocityY;

            _postInvalidateOnAnimation();
          }
        }

        if (touchMode == ChartTouchListener.X_ZOOM ||
            touchMode == ChartTouchListener.Y_ZOOM ||
            touchMode == ChartTouchListener.PINCH_ZOOM ||
            touchMode == ChartTouchListener.POST_ZOOM) {
          chart.calculateOffsets();
          chart.invalidate();
        }

        touchMode = ChartTouchListener.NONE;
        chart.enableScroll();

        _velocityTracker?.recycle();
        _velocityTracker = null;

        endAction(event);

      case ChartTouchAction.pointerUp:
        ChartVelocityTracker.pointerUpCleanUpIfNecessary(event, tracker);
        touchMode = ChartTouchListener.POST_ZOOM;

      case ChartTouchAction.cancel:
        chart.enableScroll();
        touchMode = ChartTouchListener.NONE;
        endAction(event);
    }

    if (chart.isDragEnabled || chart.isScaleEnabled) {
      _matrix = chart.viewPortHandler.refresh(_matrix, chart, true);
    }

    return true;
  }

  void _saveTouchStart(ChartTouchEvent event) {
    _savedMatrix.set(_matrix);
    _touchStartPoint.x = event.x;
    _touchStartPoint.y = event.y;

    _closestDataSetToTouch = chart.getDataSetByTouchPoint(event.x, event.y);
  }

  void _performDrag(ChartTouchEvent event, double distanceX, double distanceY) {
    lastGesture = ChartGesture.DRAG;

    _matrix.set(_savedMatrix);

    var dX = distanceX;
    var dY = distanceY;

    if (_inverted()) {
      if (_isHorizontalBar) {
        dX = -dX;
      } else {
        dY = -dY;
      }
    }

    _matrix.postTranslate(dX, dY);

    chart.notifyGesture((it) => it.onChartTranslate(event, dX, dY));
  }

  /// Limits [scale] so that applying it on top of [current] keeps the chart between [min] and [max]. Without this
  /// the view port clamps the scale afterwards but keeps the translation of the larger scale, and the chart jumps.
  double _limitScale(double scale, double current, double min, double max) {
    if (current <= 0) return scale;
    return _coerceIn(scale, min / current, max / current);
  }

  void _performZoom(ChartTouchEvent event) {
    if (event.pointerCount >= 2) {
      final totalDist = _spacing(event);

      if (totalDist > _minScalePointerDistance) {
        final t = getTrans(_touchPointCenter.x, _touchPointCenter.y);
        final h = chart.viewPortHandler;

        _savedMatrix.getValues(_savedMatrixValues);
        final savedScaleX = _savedMatrixValues[Matrix.MSCALE_X];
        final savedScaleY = _savedMatrixValues[Matrix.MSCALE_Y];

        if (touchMode == ChartTouchListener.PINCH_ZOOM) {
          lastGesture = ChartGesture.PINCH_ZOOM;

          final scale = totalDist / _savedDist;

          final isZoomingOut = scale < 1;
          final canZoomMoreX = isZoomingOut
              ? h.canZoomOutMoreX
              : h.canZoomInMoreX;
          final canZoomMoreY = isZoomingOut
              ? h.canZoomOutMoreY
              : h.canZoomInMoreY;

          final scaleX = chart.isScaleXEnabled ? scale : 1.0;
          final scaleY = chart.isScaleYEnabled ? scale : 1.0;

          if (canZoomMoreY || canZoomMoreX) {
            _matrix.set(_savedMatrix);
            _matrix.postScale(
              _limitScale(scaleX, savedScaleX, h.minScaleX, h.maxScaleX),
              _limitScale(scaleY, savedScaleY, h.minScaleY, h.maxScaleY),
              t.x,
              t.y,
            );

            chart.notifyGesture((it) => it.onChartScale(event, scaleX, scaleY));
          }
        } else if (touchMode == ChartTouchListener.X_ZOOM &&
            chart.isScaleXEnabled) {
          lastGesture = ChartGesture.X_ZOOM;

          final xDist = _getXDist(event);
          final scaleX = xDist / _savedXDist;

          final isZoomingOut = scaleX < 1;
          final canZoomMoreX = isZoomingOut
              ? h.canZoomOutMoreX
              : h.canZoomInMoreX;

          if (canZoomMoreX && scaleX.isFinite) {
            _matrix.set(_savedMatrix);
            _matrix.postScale(
              _limitScale(scaleX, savedScaleX, h.minScaleX, h.maxScaleX),
              1,
              t.x,
              t.y,
            );

            chart.notifyGesture((it) => it.onChartScale(event, scaleX, 1));
          }
        } else if (touchMode == ChartTouchListener.Y_ZOOM &&
            chart.isScaleYEnabled) {
          lastGesture = ChartGesture.Y_ZOOM;

          final yDist = _getYDist(event);
          final scaleY = yDist / _savedYDist;

          final isZoomingOut = scaleY < 1;
          final canZoomMoreY = isZoomingOut
              ? h.canZoomOutMoreY
              : h.canZoomInMoreY;

          if (canZoomMoreY && scaleY.isFinite) {
            _matrix.set(_savedMatrix);
            _matrix.postScale(
              1,
              _limitScale(scaleY, savedScaleY, h.minScaleY, h.maxScaleY),
              t.x,
              t.y,
            );

            chart.notifyGesture((it) => it.onChartScale(event, 1, scaleY));
          }
        }

        MPPointF.recycleInstance(t);
      }
    }
  }

  /// Highlighting follows the x axis, so it starts only on a gesture past the system touch slop that runs mostly
  /// along that axis. A swipe across it belongs to a scrolling parent such as a list.
  bool _startsHighlightDrag(ChartTouchEvent e) {
    final dx = (e.x - _touchStartPoint.x).abs();
    final dy = (e.y - _touchStartPoint.y).abs();
    if (ChartTouchListener.distance(
          e.x,
          _touchStartPoint.x,
          e.y,
          _touchStartPoint.y,
        ) <=
        kTouchSlop) {
      return false;
    }
    return _isHorizontalBar ? dy >= dx : dx >= dy;
  }

  void _performHighlightDrag(ChartTouchEvent e) {
    final h = chart.getHighlightByTouchPoint(e.x, e.y);

    if (h != null && !h.equalTo(lastHighlighted)) {
      lastHighlighted = h;
      chart.highlightValueOf(h, callListener: true);
    }
  }

  /// Converts the pixel position ([x], [y]) on the view into the pivot used for zooming: relative to the
  /// content rectangle, with y measured from the bottom unless the touched axis is inverted.
  ///
  /// Returns a pooled [MPPointF]; recycle it with [MPPointF.recycleInstance] when done.
  MPPointF getTrans(double x, double y) {
    final vph = chart.viewPortHandler;

    final xTrans = x - vph.offsetLeft;
    final yTrans = _inverted()
        ? -(y - vph.offsetTop)
        : -(chart.height - y - vph.offsetBottom);

    return MPPointF.getInstance(xTrans, yTrans);
  }

  bool _inverted() {
    final closest = _closestDataSetToTouch;
    return (closest == null && chart.isAnyAxisInverted) ||
        (closest != null && chart.isInverted(closest.axisDependency));
  }

  /// Whether the chart is a [HorizontalBarChart], whose drag and highlight axes are swapped.
  bool get _isHorizontalBar => chart is HorizontalBarChart;

  @override
  bool onDoubleTap(ChartTouchEvent e) {
    lastGesture = ChartGesture.DOUBLE_TAP;

    chart.notifyGesture((it) => it.onChartDoubleTapped(e));

    if (chart.isDoubleTapToZoomEnabled && (chart.data?.entryCount ?? 0) > 0) {
      final trans = getTrans(e.x, e.y);

      final scaleX = chart.isScaleXEnabled ? 1.4 : 1.0;
      final scaleY = chart.isScaleYEnabled ? 1.4 : 1.0;

      chart.zoom(scaleX, scaleY, trans.x, trans.y);

      if (chart.isLogEnabled) {
        debugPrint(
          'BarlineChartTouch: Double-Tap, Zooming In, x: ${trans.x}, y: ${trans.y}',
        );
      }

      chart.notifyGesture((it) => it.onChartScale(e, scaleX, scaleY));

      MPPointF.recycleInstance(trans);
    }

    return super.onDoubleTap(e);
  }

  @override
  void onLongPress(ChartTouchEvent e) {
    lastGesture = ChartGesture.LONG_PRESS;
    chart.notifyGesture((it) => it.onChartLongPressed(e));
  }

  @override
  bool onSingleTapUp(ChartTouchEvent e) {
    lastGesture = ChartGesture.SINGLE_TAP;

    chart.notifyGesture((it) => it.onChartSingleTapped(e));

    if (!chart.isHighlightPerTapEnabled) return false;

    final h = chart.getHighlightByTouchPoint(e.x, e.y);
    performHighlight(h, e);

    return super.onSingleTapUp(e);
  }

  @override
  bool onFling(
    ChartTouchEvent? e1,
    ChartTouchEvent e2,
    double velocityX,
    double velocityY,
  ) {
    lastGesture = ChartGesture.FLING;

    chart.notifyGesture((it) => it.onChartFling(e1, e2, velocityX, velocityY));

    return super.onFling(e1, e2, velocityX, velocityY);
  }

  /// Stops a running fling deceleration by setting its velocity to 0, and stops its ticker.
  void stopDeceleration() {
    _decelerationVelocity.x = 0;
    _decelerationVelocity.y = 0;
    _stopDecelerationTicker();
  }

  /// Advances the fling deceleration by one frame: applies friction, drags the chart by the distance covered
  /// and requests the next frame until the velocity is nearly 0. Called through `Chart.computeScroll`, on every frame
  /// by the deceleration ticker. Does nothing when no deceleration is running.
  void computeScroll() {
    if (_decelerationVelocity.x == 0 && _decelerationVelocity.y == 0) return;

    final currentTime = clock();

    _decelerationVelocity.x *= chart.dragDecelerationFrictionCoef;
    _decelerationVelocity.y *= chart.dragDecelerationFrictionCoef;

    final timeInterval = (currentTime - _decelerationLastTime) / 1000;

    final distanceX = _decelerationVelocity.x * timeInterval;
    final distanceY = _decelerationVelocity.y * timeInterval;

    _decelerationCurrentPoint.x += distanceX;
    _decelerationCurrentPoint.y += distanceY;

    final event = ChartTouchEvent(
      action: ChartTouchAction.move,
      pointerIds: const [0],
      positions: [
        Offset(_decelerationCurrentPoint.x, _decelerationCurrentPoint.y),
      ],
      eventTimeMillis: currentTime,
    );

    final dragDistanceX = chart.isDragXEnabled
        ? _decelerationCurrentPoint.x - _touchStartPoint.x
        : 0.0;
    final dragDistanceY = chart.isDragYEnabled
        ? _decelerationCurrentPoint.y - _touchStartPoint.y
        : 0.0;

    _performDrag(event, dragDistanceX, dragDistanceY);

    _matrix = chart.viewPortHandler.refresh(_matrix, chart, false);

    _decelerationLastTime = currentTime;

    if (_decelerationVelocity.x.abs() >= 0.01 ||
        _decelerationVelocity.y.abs() >= 0.01) {
      _postInvalidateOnAnimation();
    } else {
      chart.calculateOffsets();
      chart.invalidate();

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

  /// Kotlin `Float.coerceIn(min, max)`: keeps NaN as NaN, unlike Dart's `clamp`.
  static double _coerceIn(double value, double min, double max) {
    if (min > max) {
      throw ArgumentError(
        'Cannot coerce value to an empty range: maximum $max is less than minimum $min.',
      );
    }
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static void _midPoint(MPPointF point, ChartTouchEvent event) {
    final x = event.getX(0) + event.getX(1);
    final y = event.getY(0) + event.getY(1);
    point.x = x / 2;
    point.y = y / 2;
  }

  static double _spacing(ChartTouchEvent event) {
    final x = event.getX(0) - event.getX(1);
    final y = event.getY(0) - event.getY(1);
    return math.sqrt(x * x + y * y);
  }

  static double _getXDist(ChartTouchEvent e) => (e.getX(0) - e.getX(1)).abs();

  static double _getYDist(ChartTouchEvent e) => (e.getY(0) - e.getY(1)).abs();
}
