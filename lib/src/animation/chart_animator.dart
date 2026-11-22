// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/animation/ChartAnimator.kt
//
// Android's ValueAnimator is a Flutter AnimationController here, driven by the TickerProvider in [vsync].
// The constructor's `listener` (a ValueAnimator.AnimatorUpdateListener) is the `onUpdate` callback. Kotlin's
// `internal` members (start, endValueAnimations, SPIN, DATA_CHANGE, afterCalls) are public, since Dart has no
// module-internal visibility; they are internal API for the charts.
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, internal, visibleForTesting;
import 'package:flutter/scheduler.dart';

import '../utils/float_math.dart';
import 'easing.dart';

/// Runs the animations of a chart. It drives [phaseX] and [phaseY] from 0 to 1 with an [AnimationController]; the
/// renderers draw only the first [phaseX] share of the entries and scale their values by [phaseY]. It also runs the
/// chart's spin and value animations. Every chart owns one and passes a callback that redraws the chart on each
/// animation frame.
///
/// Each animation has a slot: one for [phaseX], one for [phaseY], one for the spin of a pie or radar chart, one per
/// animated entry and one for a data change. Starting an animation cancels the one running in the same slot, which
/// keeps its current value; the cancelled animation still counts as ended and calls its `onEnd`. All members are
/// main-thread only.
class ChartAnimator {
  /// Creates an animator with both phases at 1, so everything is drawn.
  ///
  /// [vsync] drives the animations; without one they end at once (see [vsync]). [onUpdate] is called on every
  /// animation frame; the chart passes one that invalidates itself.
  ChartAnimator({TickerProvider? vsync, void Function()? onUpdate})
    : _vsync = vsync,
      _listener = onUpdate;

  final void Function()? _listener;

  TickerProvider? _vsync;

  /// The ticker provider that drives the animations, normally the State of the widget that shows the chart.
  ///
  /// Without one (a chart built in code, or drawn with `toImage`) every animation ends at once at its final state:
  /// `animateX`, `animateY`, `animateXY` and [start] apply the final value and call `onEnd` before they return. An
  /// animation with a duration of 0 does the same with a vsync.
  ///
  /// An `onEnd` that starts a new animation in its own slot while that slot is ending this way (a self-restarting loop
  /// such as `void loop() => animateY(1000, onEnd: loop)`, or one that comes back through other slots) would recurse
  /// until a StackOverflowError, since nothing waits for a frame. Instead, that new animation is applied at its end
  /// state (its value is written and the chart redrawn) but its `onEnd` is not called, which ends the loop; a debug
  /// build prints a warning once per animator. An `onEnd` that starts an animation in another slot (x, then y) still
  /// gets that animation's `onEnd`. On Android such a loop keeps running, one restart per animation.
  ///
  /// Changing it ends the running animations at their final state, as a chart leaving the window does, because they
  /// tick on the previous provider, which may be going away. Animations started afterwards use the new one.
  TickerProvider? get vsync => _vsync;

  set vsync(TickerProvider? value) {
    if (identical(value, _vsync)) return;
    _vsync = value;
    stop();
  }

  double _phaseY = 1;

  /// Progress of the y animation, 0..1; the renderers multiply the drawn values by it. Assigned values are clamped
  /// (like Kotlin's `coerceIn`, NaN is kept) and stored as a Kotlin Float. Default 1.
  double get phaseY => _phaseY;

  set phaseY(double value) => _phaseY = _coerceIn01(toKotlinFloat(value));

  double _phaseX = 1;

  /// Progress of the x animation, 0..1; the renderers draw only this share of the entries. Assigned values are clamped
  /// (like Kotlin's `coerceIn`, NaN is kept) and stored as a Kotlin Float. Default 1.
  double get phaseX => _phaseX;

  set phaseX(double value) => _phaseX = _coerceIn01(toKotlinFloat(value));

  final Map<Object, _ValueAnimator> _running = Map.identity();

  /// The slots whose animation is ending inside [start] (no vsync, or a duration of 0); a [start] in one of them from
  /// an `onEnd` is the self-restarting loop that [vsync] describes.
  final Set<Object> _endingAtOnce = Set.identity();

  bool _debugWarnedRestart = false;

  /// The slots whose running animation a [start] is cancelling; a [start] in one of them from that animation's
  /// `onEnd` is superseded by the animation being started.
  final Set<Object> _cancelling = Set.identity();

  bool _debugWarnedSuperseded = false;

  /// The running animations by slot (Kotlin's private `IdentityHashMap<Any, ValueAnimator>`), read-only.
  @visibleForTesting
  Map<Object, AnimationController> get running => UnmodifiableMapView(_running);

  /// True while any animation runs: a phase animation, a spin or a value animation.
  bool get isAnimating => _running.isNotEmpty;

  /// Animates [phaseX] from 0 to 1. A running x animation is cancelled first.
  ///
  /// [durationMillis] is the duration in milliseconds, [easing] the easing curve (default [Easing.Linear]). [onEnd] is
  /// called once when the animation ends, whether it finished, was stopped or was cancelled by a new x animation.
  void animateX(
    int durationMillis, {
    EasingFunction easing = Easing.Linear,
    void Function() onEnd = _noop,
  }) {
    _animatePhase(_PHASE_X, durationMillis, easing, onEnd, (it) => phaseX = it);
  }

  /// Animates [phaseX] and [phaseY] from 0 to 1 at the same time. Running x and y animations are cancelled first.
  ///
  /// [durationMillisX] and [durationMillisY] are the durations of the x and y animations in milliseconds, [easingX]
  /// the easing curve for x (default [Easing.Linear]) and [easingY] the one for y (default the same as [easingX]).
  /// [onEnd] is called once after both animations have ended.
  void animateXY(
    int durationMillisX,
    int durationMillisY, {
    EasingFunction easingX = Easing.Linear,
    EasingFunction? easingY,
    void Function() onEnd = _noop,
  }) {
    final bothEnded = afterCalls(2, onEnd);
    _animatePhase(
      _PHASE_X,
      durationMillisX,
      easingX,
      bothEnded,
      (it) => phaseX = it,
    );
    _animatePhase(
      _PHASE_Y,
      durationMillisY,
      easingY ?? easingX,
      bothEnded,
      (it) => phaseY = it,
    );
  }

  /// Animates [phaseY] from 0 to 1. A running y animation is cancelled first.
  ///
  /// [durationMillis] is the duration in milliseconds, [easing] the easing curve (default [Easing.Linear]). [onEnd] is
  /// called once when the animation ends, whether it finished, was stopped or was cancelled by a new y animation.
  void animateY(
    int durationMillis, {
    EasingFunction easing = Easing.Linear,
    void Function() onEnd = _noop,
  }) {
    _animatePhase(_PHASE_Y, durationMillis, easing, onEnd, (it) => phaseY = it);
  }

  /// Ends every running animation at once at its final state: the phases jump to 1, a spin to its end angle and
  /// animated values to their targets. Each `onEnd` runs.
  void stop() {
    for (final animator in _running.values.toList()) {
      animator.end();
    }
  }

  /// Ends the value animations, those started with [start] under an entry or [DATA_CHANGE], at their final state.
  ///
  /// Internal API.
  @internal
  void endValueAnimations() {
    for (final MapEntry(:key, value: animator) in _running.entries.toList()) {
      if (!identical(key, _PHASE_X) &&
          !identical(key, _PHASE_Y) &&
          !identical(key, SPIN)) {
        animator.end();
      }
    }
  }

  void _animatePhase(
    Object key,
    int durationMillis,
    EasingFunction easing,
    void Function() onEnd,
    void Function(double) setPhase,
  ) {
    start(
      key: key,
      from: 0,
      to: 1,
      durationMillis: durationMillis,
      easing: easing,
      onUpdate: setPhase,
      onEnd: (_) => onEnd(),
    );
  }

  /// Animates a value from [from] to [to] in the slot [key], cancelling the animation running there first.
  ///
  /// [onUpdate] is called on every frame with the current value, before the redraw callback. [onEnd] is called once
  /// when the animation ends; the argument is true when a new animation in the same slot cancelled it, false when it
  /// finished or was ended by [stop].
  ///
  /// Without a [vsync], or with a [durationMillis] of 0 or less, the animation ends at once (see [vsync]): [onUpdate]
  /// is called once with the final value, then [onEnd]. If the slot is already ending that way further up the stack
  /// (an `onEnd` restarting it), [onEnd] is not called.
  ///
  /// The `onEnd` of the cancelled animation runs inside this call. If it starts the slot [key] again (a loop such as
  /// `void loop() => animateY(1000, onEnd: loop)` restarts on every end, cancellations included), that start does
  /// nothing and its `onEnd` is never called: the animation being started here supersedes it, and a debug build prints
  /// a warning once per animator. On Android both would run, the restart unseen in the slot, and update the same value
  /// until the restart ends.
  ///
  /// Internal API. Kotlin's call sites pass every argument by name, so the parameters are named here.
  @internal
  void start({
    required Object key,
    required double from,
    required double to,
    required int durationMillis,
    required EasingFunction easing,
    required void Function(double value) onUpdate,
    required void Function(bool cancelled) onEnd,
  }) {
    if (_cancelling.contains(key)) {
      // An onEnd of the animation that a start further up the stack is cancelling restarts the slot: that start's
      // animation wins. Registering this one would leave either one running unseen (its ticker never disposed).
      _debugWarnSuperseded();
      return;
    }
    final previous = _running.remove(key);
    if (previous != null) {
      _cancelling.add(key);
      try {
        previous.cancel();
      } finally {
        _cancelling.remove(key);
      }
    }
    // Only start() fills a slot, and it returned above for this one while the previous animation was cancelled.
    assert(!_running.containsKey(key));
    final vsync = _vsync;
    // Like ValueAnimator.start() with no duration (setCurrentPlayTime(0) gives fraction 1), a duration of 0 shows only
    // the final value; with nothing to tick it ends at once, as without a vsync.
    final endsAtOnce = vsync == null || durationMillis <= 0;
    // The slot is ending at once further up the stack, so an onEnd is restarting it; calling this animation's onEnd
    // as well would recurse without end, so it is skipped.
    final restartsWhileEnding = endsAtOnce && _endingAtOnce.contains(key);
    final animator = _ValueAnimator(
      from,
      to,
      easing,
      Duration(milliseconds: math.max(durationMillis, 0)),
      endsAtOnce ? const _NullTickerProvider() : vsync,
    );
    animator.addListener(() {
      onUpdate(animator.animatedValue);
      _listener?.call();
    });
    var cancelled = false;
    animator.onAnimationCancel = () {
      cancelled = true;
    };
    animator.onAnimationEnd = () {
      // Kotlin removes all listeners here; the controller is never used again, so disposing it drops them.
      animator.dispose();
      if (identical(_running[key], animator)) _running.remove(key);
      if (restartsWhileEnding) {
        _debugWarnRestart();
        return;
      }
      onEnd(cancelled);
    };
    _running[key] = animator;
    if (endsAtOnce) {
      // Nothing ticks: the animation ends at once at its final state.
      final added = _endingAtOnce.add(key);
      try {
        animator.end();
      } finally {
        if (added) _endingAtOnce.remove(key);
      }
    } else {
      animator.start();
    }
  }

  void _debugWarnRestart() {
    assert(() {
      if (!_debugWarnedRestart) {
        _debugWarnedRestart = true;
        debugPrint(
          'ChartAnimator: an onEnd started a new animation in a slot that was still ending at once (no vsync, or a '
          'duration of 0). That animation was applied at its end state and its onEnd was not called, so that the '
          'loop ends instead of recursing.',
        );
      }
      return true;
    }());
  }

  void _debugWarnSuperseded() {
    assert(() {
      if (!_debugWarnedSuperseded) {
        _debugWarnedSuperseded = true;
        debugPrint(
          'ChartAnimator: the onEnd of a cancelled animation started its slot again while a new animation in that slot '
          'was starting. The new animation replaces that start, which did nothing.',
        );
      }
      return true;
    }());
  }

  static final Object _PHASE_X = Object();
  static final Object _PHASE_Y = Object();

  /// Slot of the spin of a pie or radar chart. Internal API.
  @internal
  static final Object SPIN = Object();

  /// Slot of an animated data change. Internal API.
  @internal
  static final Object DATA_CHANGE = Object();

  /// Returns a function that calls [block] on its [count]th call and does nothing on the others. Internal API.
  @internal
  static void Function() afterCalls(int count, void Function() block) {
    var left = count;
    return () {
      left--;
      if (left == 0) block();
    };
  }

  static void _noop() {}

  static double _coerceIn01(double value) {
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }
}

/// Android's `ValueAnimator.ofFloat(from, to)` with an interpolator and one `AnimatorListener`, as [ChartAnimator]
/// uses it, on an [AnimationController] that runs linearly from 0 to 1 over the duration. The easing is applied to the
/// controller's value outside the controller, so curves that overshoot are not clamped.
///
/// [cancel] and [end] behave like `Animator.cancel()` / `end()`: the end is reported once, on whichever of finishing,
/// [cancel] or [end] comes first, and the later calls do nothing.
class _ValueAnimator extends AnimationController {
  _ValueAnimator(
    this._from,
    this._to,
    this._interpolator,
    Duration duration,
    TickerProvider vsync,
  ) : super(duration: duration, vsync: vsync, debugLabel: 'ChartAnimator') {
    addStatusListener((status) {
      if (status == AnimationStatus.completed) _endAnimation();
    });
  }

  final double _from;
  final double _to;
  final EasingFunction _interpolator;

  /// The listener's `onAnimationCancel`: the animation was cancelled; [onAnimationEnd] follows.
  void Function()? onAnimationCancel;

  /// The listener's `onAnimationEnd`: called once when the animation finished, was cancelled or was ended.
  void Function()? onAnimationEnd;

  /// Android's `mAnimationEndRequested`: the end was reported, so nothing is reported any more.
  bool _endRequested = false;

  /// `ValueAnimator.getAnimatedValue()`: [_from] plus the eased fraction of the way to [_to].
  double get animatedValue => _from + _interpolator(value) * (_to - _from);

  /// `ValueAnimator.start()`: applies the start value at once and moves on with the frames.
  void start() {
    forward(from: 0);
  }

  /// `ValueAnimator.cancel()`: stops at the current value without a final update; reports cancel, then the end.
  void cancel() {
    if (_endRequested) return;
    stop();
    onAnimationCancel?.call();
    _endAnimation();
  }

  /// `ValueAnimator.end()`: jumps to the final value, reports it to the update listeners and reports the end.
  void end() {
    if (_endRequested) return;
    // The completed status this sets ends the animation; the call below covers a status that did not change.
    value = upperBound;
    _endAnimation();
  }

  void _endAnimation() {
    if (_endRequested) return;
    _endRequested = true;
    onAnimationEnd?.call();
  }
}

/// The ticker provider of an animator without a vsync. Its tickers are never started, because such an
/// animation ends as soon as it starts.
class _NullTickerProvider implements TickerProvider {
  const _NullTickerProvider();

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
