// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/jobs/AnimatedViewPortJob.kt
//
// Android's ValueAnimator is a Flutter AnimationController here. It needs a TickerProvider, which the job
// takes from the chart's host when it runs (Chart.host?.vsync), so the controller is created by run() instead of with
// the job. The listener methods of Kotlin's AnimatorUpdateListener / AnimatorListener keep their names without the
// Animator argument.
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart' show internal, protected;

import '../animation/easing.dart';
import '../charts/chart.dart';
import '../utils/float_math.dart';
import 'view_port_job.dart';

/// Base class of the viewport jobs that animate from an origin to a target over a duration. An animation drives
/// [phase] from 0 to 1 and calls [onAnimationUpdate] on every frame, where subclasses apply the interpolated
/// position. The job recycles itself when the animation ends or is cancelled.
///
/// The animation ticks on the vsync of the chart's host (`Chart.host`). Without one, a chart built in code or not
/// shown yet, or with a [duration] of 0, the job jumps to its end state when it runs: [phase] becomes 1,
/// [onAnimationUpdate] and then [onAnimationEnd] are called at once. A chart that leaves the window ends its
/// running viewport animations at their end state.
abstract class AnimatedViewPortJob extends ViewPortJob {
  /// Creates a job that animates from ([xOrigin], [yOrigin]) to ([xValue], [yValue]) over [duration] milliseconds.
  AnimatedViewPortJob(
    super.viewPortHandler,
    super.xValue,
    super.yValue,
    super.transformer,
    super.view,
    double xOrigin,
    double yOrigin,
    this.duration,
  ) : _xOrigin = xOrigin,
      _yOrigin = yOrigin;

  /// Length of the animation in milliseconds, Kotlin's `animator.duration`.
  int duration;

  AnimationController? _animator;

  /// The animation running [phase] from 0 to 1, or null while the job is not animating. Kotlin's `animator`, a
  /// `ValueAnimator` the job creates up front; here [run] creates it from the host's vsync.
  @protected
  AnimationController? get animator => _animator;

  /// The running jobs of the chart this job was added to while it animates, so the chart can end them.
  Set<AnimatedViewPortJob>? _registry;

  /// Progress of the animation, 0 at the origin and 1 at the target.
  double phase = 0;

  double _xOrigin;

  /// x value the animation starts from.
  double get xOrigin => _xOrigin;

  @protected
  set xOrigin(double value) => _xOrigin = value;

  double _yOrigin;

  /// y value the animation starts from.
  double get yOrigin => _yOrigin;

  @protected
  set yOrigin(double value) => _yOrigin = value;

  /// Starts the animation. Running the job again while it animates starts it over, like `ValueAnimator.start()`.
  @override
  void run() {
    _dropAnimator();
    final chart = view;
    final vsync = chart is Chart ? chart.host?.vsync : null;
    if (chart is! Chart || vsync == null || duration <= 0) {
      // Nothing ticks (or nothing to animate over): end at once at the end state, like ChartAnimator.
      onAnimationStart();
      phase = 1;
      onAnimationUpdate();
      onAnimationEnd();
      return;
    }

    final animator = AnimationController(
      duration: Duration(milliseconds: duration),
      vsync: vsync,
      debugLabel: 'AnimatedViewPortJob',
    );
    _animator = animator;
    final registry = chart.runningViewPortJobs;
    _registry = registry..add(this);
    animator.addListener(() {
      // ValueAnimator's default interpolator, AccelerateDecelerateInterpolator, is the ease in out sine curve.
      phase = toKotlinFloat(Easing.EaseInOutSine(animator.value));
      onAnimationUpdate();
    });
    animator.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish(animator);
    });
    onAnimationStart();
    animator.forward(from: 0);
  }

  /// Ends a running animation at once at its end state: [phase] becomes 1, then [onAnimationUpdate] and
  /// [onAnimationEnd] are called, like `ValueAnimator.end()`. Does nothing while the job is not animating. The chart
  /// calls it when it leaves the window. Internal API.
  @internal
  void endAnimation() {
    final animator = _animator;
    if (animator == null) return;
    animator.stop();
    phase = 1;
    onAnimationUpdate();
    _finish(animator);
  }

  void _finish(AnimationController animator) {
    if (!identical(_animator, animator)) return;
    _unregister();
    animator.dispose();
    onAnimationEnd();
  }

  /// Stops and drops the animation of an earlier run without reporting its end.
  void _dropAnimator() {
    final animator = _animator;
    if (animator == null) return;
    _unregister();
    animator.dispose();
  }

  void _unregister() {
    _registry?.remove(this);
    _registry = null;
    _animator = null;
  }

  /// Returns this job to its pool. Called when the animation ends or is cancelled.
  void recycleSelf();

  /// Prepares a pooled instance for reuse: stops an animation that is still running, without reporting its end.
  ///
  /// Kotlin removes the animator's listeners, calls `reverse()` and registers this job again. On a stopped
  /// `ValueAnimator`, `reverse()` also plays it backwards once until [run] starts it again; the port creates a
  /// fresh animation in every [run] instead, so there is nothing to reverse.
  @protected
  void resetAnimator() {
    _dropAnimator();
  }

  /// Called when the animation starts.
  void onAnimationStart() {}

  /// Called once when the animation ends; recycles the job.
  void onAnimationEnd() {
    try {
      recycleSelf();
    } on ArgumentError {
      // Already in the pool.
    }
  }

  /// Called when the animation is cancelled; recycles the job.
  void onAnimationCancel() {
    try {
      recycleSelf();
    } on ArgumentError {
      // Already in the pool.
    }
  }

  /// Called when the animation repeats; it never does.
  void onAnimationRepeat() {}

  /// Called on every animation frame after [phase] was updated. Subclasses apply the interpolated position here.
  void onAnimationUpdate() {}
}
