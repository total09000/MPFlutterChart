// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/jobs/AnimatedZoomJob.kt
import 'package:flutter/foundation.dart' show protected;

import '../charts/bar_line_chart_base.dart';
import '../components/y_axis.dart';
import '../graphics/matrix.dart';
import '../utils/chart_invalidator.dart';
import '../utils/object_pool.dart';
import '../utils/transformer.dart';
import '../utils/view_port_handler.dart';
import 'animated_view_port_job.dart';

/// Animates the zoom of a chart from the absolute scale ([xOrigin], [yOrigin]) to ([xValue], [yValue]) while
/// moving the viewport so that the centered value point travels from ([zoomOriginX], [zoomOriginY]) to
/// ([zoomCenterX], [zoomCenterY]). Recalculates the chart offsets when the animation ends. Used instances are
/// not returned to the pool.
class AnimatedZoomJob extends AnimatedViewPortJob {
  /// Creates a job; use [getInstance] to take one from the pool instead.
  ///
  /// [scaleX] and [scaleY] are the absolute scales when the animation ends; they are stored as [xValue] and [yValue].
  AnimatedZoomJob(
    ViewPortHandler? viewPortHandler,
    ChartInvalidator? view,
    Transformer? transformer,
    this.yAxis,
    this.xAxisRange,
    double scaleX,
    double scaleY,
    double xOrigin,
    double yOrigin,
    this.zoomCenterX,
    this.zoomCenterY,
    this.zoomOriginX,
    this.zoomOriginY,
    int duration,
  ) : super(
        viewPortHandler,
        scaleX,
        scaleY,
        transformer,
        view,
        xOrigin,
        yOrigin,
        duration,
      );

  /// The y axis whose range decides how many y values fit into the view at a given scale.
  @protected
  YAxis? yAxis;

  /// Full range of the x axis in value units.
  @protected
  double xAxisRange;

  /// x value in the center of the content rectangle when the animation ends.
  @protected
  double zoomCenterX;

  /// y value in the center of the content rectangle when the animation ends.
  @protected
  double zoomCenterY;

  /// x value in the center of the content rectangle when the animation starts.
  @protected
  double zoomOriginX;

  /// y value in the center of the content rectangle when the animation starts.
  @protected
  double zoomOriginY;

  final Matrix _onAnimationUpdateMatrixBuffer = Matrix();

  @override
  void onAnimationUpdate() {
    final viewPortHandler = this.viewPortHandler;
    if (viewPortHandler == null) return;
    final transformer = this.transformer;
    if (transformer == null) return;
    final view = this.view;
    if (view == null) return;
    final yAxis = this.yAxis;
    if (yAxis == null) return;

    final scaleX = xOrigin + (xValue - xOrigin) * phase;
    final scaleY = yOrigin + (yValue - yOrigin) * phase;

    final save = _onAnimationUpdateMatrixBuffer;
    viewPortHandler.setZoom(scaleX, scaleY, null, null, save);
    viewPortHandler.refresh(save, view, false);

    final valsInView = yAxis.axisRange / viewPortHandler.scaleY;
    final xsInView = xAxisRange / viewPortHandler.scaleX;

    pts[0] = zoomOriginX + ((zoomCenterX - xsInView / 2) - zoomOriginX) * phase;
    pts[1] =
        zoomOriginY + ((zoomCenterY + valsInView / 2) - zoomOriginY) * phase;

    transformer.pointValuesToPixel(pts);

    viewPortHandler.translate(pts, save);
    viewPortHandler.refresh(save, view, true);
  }

  /// Recalculates the offsets of the chart and redraws it. Unlike the base class, the job is not recycled.
  @override
  void onAnimationEnd() {
    final view = this.view;
    if (view is BarLineChartBase) view.calculateOffsets();
    // Kotlin's View.postInvalidate().
    view?.invalidate();
  }

  @override
  void onAnimationCancel() {}

  @override
  void onAnimationRepeat() {}

  @override
  void recycleSelf() {}

  @override
  void onAnimationStart() {}

  @override
  Poolable instantiate() =>
      AnimatedZoomJob(null, null, null, null, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

  static final ObjectPool<AnimatedZoomJob> _pool = ObjectPool.create(
    8,
    AnimatedZoomJob(null, null, null, null, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  );

  /// Returns a pooled job set up to animate the zoom of [view].
  ///
  /// [axis] is the y axis the zoom and the y values refer to, [xAxisRange] the full range of the x axis in value
  /// units, [scaleX] / [scaleY] the absolute scales when the animation ends, [xOrigin] / [yOrigin] the absolute
  /// scales when the animation starts, [zoomCenterX] / [zoomCenterY] the values centered when the animation ends,
  /// [zoomOriginX] / [zoomOriginY] the values centered when the animation starts and [duration] the length of the
  /// animation in milliseconds.
  static AnimatedZoomJob getInstance(
    ViewPortHandler viewPortHandler,
    ChartInvalidator view,
    Transformer transformer,
    YAxis axis,
    double xAxisRange,
    double scaleX,
    double scaleY,
    double xOrigin,
    double yOrigin,
    double zoomCenterX,
    double zoomCenterY,
    double zoomOriginX,
    double zoomOriginY,
    int duration,
  ) {
    final result = _pool.get();
    result.viewPortHandler = viewPortHandler;
    result.xValue = scaleX;
    result.yValue = scaleY;
    result.transformer = transformer;
    result.view = view;
    result.xOrigin = xOrigin;
    result.yOrigin = yOrigin;
    result.yAxis = axis;
    result.xAxisRange = xAxisRange;
    result.zoomCenterX = zoomCenterX;
    result.zoomCenterY = zoomCenterY;
    result.zoomOriginX = zoomOriginX;
    result.zoomOriginY = zoomOriginY;
    result.resetAnimator();
    result.duration = duration;
    return result;
  }
}
