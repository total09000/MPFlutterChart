// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/jobs/AnimatedMoveViewJob.kt
import '../utils/chart_invalidator.dart';
import '../utils/object_pool.dart';
import '../utils/transformer.dart';
import '../utils/view_port_handler.dart';
import 'animated_view_port_job.dart';

/// Animates the viewport from the value point ([xOrigin], [yOrigin]) to ([xValue], [yValue]). On every frame the
/// interpolated point is placed at the top left corner of the content rectangle.
class AnimatedMoveViewJob extends AnimatedViewPortJob {
  /// Creates a job; use [getInstance] to take one from the pool instead.
  AnimatedMoveViewJob(
    super.viewPortHandler,
    super.xValue,
    super.yValue,
    super.transformer,
    super.view,
    super.xOrigin,
    super.yOrigin,
    super.duration,
  );

  @override
  void onAnimationUpdate() {
    final transformer = this.transformer;
    if (transformer == null) return;
    final viewPortHandler = this.viewPortHandler;
    if (viewPortHandler == null) return;
    final view = this.view;
    if (view == null) return;

    pts[0] = xOrigin + (xValue - xOrigin) * phase;
    pts[1] = yOrigin + (yValue - yOrigin) * phase;

    transformer.pointValuesToPixel(pts);
    viewPortHandler.centerViewPort(pts, view);
  }

  @override
  void recycleSelf() {
    releaseChart();
    recycleInstance(this);
  }

  @override
  Poolable instantiate() =>
      AnimatedMoveViewJob(null, 0, 0, null, null, 0, 0, 0);

  static final ObjectPool<AnimatedMoveViewJob> _pool = ObjectPool.create(
    4,
    AnimatedMoveViewJob(null, 0, 0, null, null, 0, 0, 0),
  )..replenishPercentage = 0.5;

  /// Returns a pooled job set up to animate the viewport of [view].
  ///
  /// [xValue] is the x value that lands at the left edge of the content rectangle when the animation ends, [yValue]
  /// the y value that lands at the top edge of the content rectangle when the animation ends, [transformer] the
  /// transformer of the axis that [yValue] belongs to, [xOrigin] the x value at the left edge when the animation
  /// starts, [yOrigin] the y value at the top edge when the animation starts and [duration] the length of the
  /// animation in milliseconds.
  static AnimatedMoveViewJob getInstance(
    ViewPortHandler viewPortHandler,
    double xValue,
    double yValue,
    Transformer transformer,
    ChartInvalidator view,
    double xOrigin,
    double yOrigin,
    int duration,
  ) {
    final result = _pool.get();
    result.viewPortHandler = viewPortHandler;
    result.xValue = xValue;
    result.yValue = yValue;
    result.transformer = transformer;
    result.view = view;
    result.xOrigin = xOrigin;
    result.yOrigin = yOrigin;
    result.duration = duration;
    return result;
  }

  /// Returns [instance] to the pool. Jobs recycle themselves when their animation ends, so this is only needed for
  /// jobs that were never run.
  ///
  /// Throws an [ArgumentError] when [instance] is already in the pool.
  static void recycleInstance(AnimatedMoveViewJob instance) {
    _pool.recycle(instance);
  }
}
