// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/jobs/MoveViewJob.kt
import '../utils/chart_invalidator.dart';
import '../utils/object_pool.dart';
import '../utils/transformer.dart';
import '../utils/view_port_handler.dart';
import 'view_port_job.dart';

/// Moves the viewport so that the value point ([xValue], [yValue]) lands at the top left corner of the content
/// rectangle, without animation. Runs once, redraws the chart and returns itself to the pool.
class MoveViewJob extends ViewPortJob {
  /// Creates a job; use [getInstance] to take one from the pool instead.
  MoveViewJob(
    super.viewPortHandler,
    super.xValue,
    super.yValue,
    super.transformer,
    super.view,
  );

  /// Translates the viewport and refreshes the chart, then recycles this job. Does nothing when the pooled fields
  /// have not been set.
  @override
  void run() {
    final transformer = this.transformer;
    if (transformer == null) return;
    final viewPortHandler = this.viewPortHandler;
    if (viewPortHandler == null) return;
    final view = this.view;
    if (view == null) return;

    pts[0] = xValue;
    pts[1] = yValue;

    transformer.pointValuesToPixel(pts);
    viewPortHandler.centerViewPort(pts, view);

    releaseChart();
    recycleInstance(this);
  }

  @override
  Poolable instantiate() =>
      MoveViewJob(viewPortHandler, xValue, yValue, transformer, view);

  static final ObjectPool<MoveViewJob> _pool = ObjectPool.create(
    2,
    MoveViewJob(null, 0, 0, null, null),
  )..replenishPercentage = 0.5;

  /// Returns a pooled job set up to move the viewport of [view].
  ///
  /// [xValue] is the x value that lands at the left edge of the content rectangle, [yValue] the y value that lands
  /// at the top edge of the content rectangle and [transformer] the transformer of the axis that [yValue] belongs to.
  static MoveViewJob getInstance(
    ViewPortHandler viewPortHandler,
    double xValue,
    double yValue,
    Transformer transformer,
    ChartInvalidator view,
  ) {
    final result = _pool.get();
    result.viewPortHandler = viewPortHandler;
    result.xValue = xValue;
    result.yValue = yValue;
    result.transformer = transformer;
    result.view = view;
    return result;
  }

  /// Returns [instance] to the pool. Jobs recycle themselves after running, so this is only needed for jobs that
  /// were never run.
  ///
  /// Throws an [ArgumentError] when [instance] is already in the pool.
  static void recycleInstance(MoveViewJob instance) {
    _pool.recycle(instance);
  }
}
