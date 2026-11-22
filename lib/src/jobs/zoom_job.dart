// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/jobs/ZoomJob.kt
import 'package:flutter/foundation.dart' show protected;

import '../charts/bar_line_chart_base.dart';
import '../components/y_axis_dependency.dart';
import '../graphics/matrix.dart';
import '../utils/chart_invalidator.dart';
import '../utils/object_pool.dart';
import '../utils/transformer.dart';
import '../utils/view_port_handler.dart';
import 'view_port_job.dart';

/// Zooms the viewport by the factors [scaleX] and [scaleY] relative to the current zoom and then moves it so
/// that the value point ([xValue], [yValue]) sits in the center of the content rectangle, without animation.
/// Runs once, recalculates the chart offsets, redraws and returns itself to the pool.
class ZoomJob extends ViewPortJob {
  /// Creates a job; use [getInstance] to take one from the pool instead.
  ZoomJob(
    ViewPortHandler? viewPortHandler,
    this.scaleX,
    this.scaleY,
    double xValue,
    double yValue,
    Transformer? transformer,
    this.axisDependency,
    ChartInvalidator? view,
  ) : super(viewPortHandler, xValue, yValue, transformer, view);

  /// Zoom factor along x, relative to the current zoom.
  @protected
  double scaleX;

  /// Zoom factor along y, relative to the current zoom.
  @protected
  double scaleY;

  /// The y axis whose range decides how many y values fit into the view.
  @protected
  AxisDependency? axisDependency;

  final Matrix _runMatrixBuffer = Matrix();

  /// Applies the zoom and translation and refreshes the chart, then recycles this job. Does nothing unless the
  /// view is a [BarLineChartBase] and all pooled fields are set.
  @override
  void run() {
    final viewPortHandler = this.viewPortHandler;
    if (viewPortHandler == null) return;
    final transformer = this.transformer;
    if (transformer == null) return;
    final view = this.view;
    if (view is! BarLineChartBase) return;
    final axisDependency = this.axisDependency;
    if (axisDependency == null) return;

    final save = _runMatrixBuffer;
    viewPortHandler.zoom(scaleX, scaleY, null, null, save);
    viewPortHandler.refresh(save, view, false);

    final stackValuesInView =
        view.getAxis(axisDependency).axisRange / viewPortHandler.scaleY;
    final xValsInView = view.xAxis.axisRange / viewPortHandler.scaleX;

    pts[0] = xValue - xValsInView / 2;
    pts[1] = yValue + stackValuesInView / 2;

    transformer.pointValuesToPixel(pts);

    viewPortHandler.translate(pts, save);
    viewPortHandler.refresh(save, view, false);

    view.calculateOffsets();
    // Kotlin's View.postInvalidate().
    view.invalidate();

    releaseChart();
    recycleInstance(this);
  }

  @override
  Poolable instantiate() => ZoomJob(null, 0, 0, 0, 0, null, null, null);

  static final ObjectPool<ZoomJob> _pool = ObjectPool.create(
    1,
    ZoomJob(null, 0, 0, 0, 0, null, null, null),
  )..replenishPercentage = 0.5;

  /// Returns a pooled job set up to zoom the viewport of [view].
  ///
  /// [xValue] and [yValue] are the values that end up in the center of the content rectangle, [transformer] the
  /// transformer of [axis] and [axis] the y axis that [yValue] belongs to.
  static ZoomJob getInstance(
    ViewPortHandler viewPortHandler,
    double scaleX,
    double scaleY,
    double xValue,
    double yValue,
    Transformer transformer,
    AxisDependency axis,
    ChartInvalidator view,
  ) {
    final result = _pool.get();
    result.xValue = xValue;
    result.yValue = yValue;
    result.scaleX = scaleX;
    result.scaleY = scaleY;
    result.viewPortHandler = viewPortHandler;
    result.transformer = transformer;
    result.axisDependency = axis;
    result.view = view;
    return result;
  }

  /// Returns [instance] to the pool. Jobs recycle themselves after running, so this is only needed for jobs that
  /// were never run.
  ///
  /// Throws an [ArgumentError] when [instance] is already in the pool.
  static void recycleInstance(ZoomJob instance) {
    _pool.recycle(instance);
  }
}
