// Tests for animation/ChartAnimator.kt without a test binding: a chart built in code (or drawn with toImage) has no
// vsync, and its animations must end at once without touching the scheduler. The ticking behaviour is
// tested in test/widget/chart_animator_test.dart.
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/animation/chart_animator.dart';
import 'package:mp_flutter_chart/src/animation/easing.dart';

void main() {
  test(
    'without a vsync and without a binding every animation ends at once',
    () {
      var updates = 0;
      final animator = ChartAnimator(onUpdate: () => updates++);
      var ends = 0;

      animator.animateX(100, onEnd: () => ends++);
      expect(ends, 1);
      expect(animator.phaseX, 1);
      expect(updates, 1);

      animator.animateXY(
        100,
        200,
        easingX: Easing.EaseInOutBounce,
        onEnd: () => ends++,
      );
      expect(ends, 2);
      expect(animator.phaseY, 1);

      double? value;
      final cancelled = <bool>[];
      animator.start(
        key: ChartAnimator.DATA_CHANGE,
        from: -5,
        to: 5,
        durationMillis: 60000,
        easing: Easing.EaseOutElastic,
        onUpdate: (it) => value = it,
        onEnd: cancelled.add,
      );
      expect(value, 5);
      expect(cancelled, [false]);
      expect(animator.running, isEmpty);
      expect(animator.isAnimating, isFalse);

      animator.stop();
      animator.endValueAnimations();
      expect(ends, 2);
    },
  );

  test('the phases are clamped like Kotlin coerceIn and stored as Float', () {
    final animator = ChartAnimator();
    expect(animator.phaseX, 1);
    expect(animator.phaseY, 1);

    animator.phaseX = double.nan;
    animator.phaseY = double.nan;
    expect(animator.phaseX.isNaN, isTrue);
    expect(animator.phaseY.isNaN, isTrue);

    animator.phaseX = 2;
    animator.phaseY = -1;
    expect(animator.phaseX, 1);
    expect(animator.phaseY, 0);
    animator.phaseX = double.negativeInfinity;
    animator.phaseY = double.infinity;
    expect(animator.phaseX, 0);
    expect(animator.phaseY, 1);

    animator.phaseX = -0.0;
    expect(animator.phaseX, 0);
    expect(animator.phaseX.isNegative, isTrue);

    animator.phaseY = 0.1;
    expect(animator.phaseY, 0.10000000149011612);
    animator.phaseX = 1 - 1e-12;
    expect(animator.phaseX, 1);
  });

  test('an onEnd that restarts its own slot without a vsync ends the loop', () {
    final logs = <String?>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message);
    try {
      var updates = 0;
      final animator = ChartAnimator(onUpdate: () => updates++);
      var ends = 0;
      void loop() {
        ends++;
        animator.animateY(1000, onEnd: loop);
      }

      // Without the guard this recursed until a StackOverflowError: the restart is applied at its end state (the
      // second update) and its onEnd is not called.
      animator.animateY(1000, onEnd: loop);
      expect(ends, 1);
      expect(updates, 2);
      expect(animator.phaseY, 1);
      expect(animator.isAnimating, isFalse);
      expect(animator.running, isEmpty);
      expect(logs, hasLength(1));
      expect(logs.single, contains('onEnd'));

      // The warning is printed once per animator.
      animator.animateY(1000, onEnd: loop);
      expect(ends, 2);
      expect(logs, hasLength(1));
    } finally {
      debugPrint = previous;
    }
  });

  test(
    'a chain across slots without a vsync runs every onEnd; a slot re-entered further down is guarded',
    () {
      final logs = <String?>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message);
      try {
        final animator = ChartAnimator();
        final order = <String>[];
        animator.animateX(
          100,
          onEnd: () {
            order.add('x');
            animator.animateY(
              100,
              onEnd: () {
                order.add('y');
                animator.start(
                  key: ChartAnimator.SPIN,
                  from: 0,
                  to: 90,
                  durationMillis: 100,
                  easing: Easing.Linear,
                  onUpdate: (_) {},
                  onEnd: (cancelled) {
                    order.add('spin $cancelled');
                    // x is still ending further up the stack: this restart would loop
                    // x → y → spin → x … forever.
                    animator.phaseX = 0.5;
                    animator.animateX(100, onEnd: () => order.add('x again'));
                  },
                );
              },
            );
          },
        );
        expect(order, ['x', 'y', 'spin false']);
        expect(animator.phaseX, 1);
        expect(animator.phaseY, 1);
        expect(animator.isAnimating, isFalse);
        expect(logs, hasLength(1));

        // Once x has ended, a new x animation from outside runs its onEnd again.
        animator.animateX(100, onEnd: () => order.add('x later'));
        expect(order.last, 'x later');
      } finally {
        debugPrint = previous;
      }
    },
  );
}
