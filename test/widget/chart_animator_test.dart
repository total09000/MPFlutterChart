// Tests for animation/ChartAnimator.kt (spec §6.3: ValueAnimator → AnimationController). MPChartLib has no unit test
// for it; the device tests' AnimationTest checks the same behaviour through the charts on Android. Frames are driven
// by the test binding: the first pump after a start begins the ticker's clock, later pumps advance it.
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/animation/chart_animator.dart';
import 'package:mp_flutter_chart/src/animation/easing.dart';

/// A ticker that remembers whether it was disposed.
class _TrackingTicker extends Ticker {
  _TrackingTicker(super.onTick);

  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

/// Like TestVSync, but keeps the tickers it creates.
class _TrackingVSync implements TickerProvider {
  final List<_TrackingTicker> tickers = [];

  bool get allDisposed => tickers.every((it) => it.disposed);

  @override
  Ticker createTicker(TickerCallback onTick) {
    final ticker = _TrackingTicker(onTick);
    tickers.add(ticker);
    return ticker;
  }
}

Duration _ms(int millis) => Duration(milliseconds: millis);

void main() {
  testWidgets('animateX drives phaseX from 0 to 1 and redraws on every frame', (
    tester,
  ) async {
    var updates = 0;
    var ends = 0;
    final animator = ChartAnimator(
      vsync: const TestVSync(),
      onUpdate: () => updates++,
    );

    animator.animateX(100, onEnd: () => ends++);
    // Like ValueAnimator.start(), the start value is applied and drawn at once.
    expect(animator.phaseX, 0);
    expect(animator.phaseY, 1);
    expect(updates, 1);
    expect(animator.isAnimating, isTrue);
    expect(animator.running, hasLength(1));

    await tester.pump();
    await tester.pump(_ms(50));
    expect(animator.phaseX, closeTo(0.5, 1e-4));
    expect(updates, 3);
    expect(ends, 0);

    await tester.pump(_ms(51));
    expect(animator.phaseX, 1);
    expect(updates, 4);
    expect(ends, 1);
    expect(animator.isAnimating, isFalse);
    expect(animator.running, isEmpty);

    await tester.pump(_ms(100));
    expect(updates, 4);
    expect(ends, 1);
  });

  testWidgets('animateX and animateY ease their phase', (tester) async {
    final animator = ChartAnimator(vsync: const TestVSync());
    animator.animateX(100, easing: Easing.EaseInQuad);
    animator.animateY(100, easing: Easing.EaseOutQuad);
    await tester.pump();
    await tester.pump(_ms(50));
    expect(animator.phaseX, closeTo(0.25, 1e-4));
    expect(animator.phaseY, closeTo(0.75, 1e-4));
    await tester.pump(_ms(51));
    expect(animator.phaseX, 1);
    expect(animator.phaseY, 1);
  });

  testWidgets(
    'a new animateX cancels the running one, whose onEnd still runs once',
    (tester) async {
      final animator = ChartAnimator(vsync: const TestVSync());
      var first = 0;
      var second = 0;

      animator.animateX(100, onEnd: () => first++);
      await tester.pump();
      await tester.pump(_ms(30));
      expect(animator.phaseX, closeTo(0.3, 1e-4));

      animator.animateX(100, onEnd: () => second++);
      expect(first, 1);
      expect(second, 0);
      expect(animator.running, hasLength(1));
      expect(animator.phaseX, 0);

      await tester.pump();
      await tester.pump(_ms(101));
      expect(first, 1);
      expect(second, 1);
      expect(animator.phaseX, 1);
      expect(animator.running, isEmpty);
    },
  );

  testWidgets(
    'stop ends every animation at its final state, each onEnd runs once, nothing ticks afterwards',
    (tester) async {
      var updates = 0;
      // The tester as vsync also checks that no ticker is left active when the test ends.
      final animator = ChartAnimator(vsync: tester, onUpdate: () => updates++);
      var first = 0;
      var second = 0;
      var y = 0;

      animator.animateX(100, onEnd: () => first++);
      animator.animateX(100, onEnd: () => second++);
      animator.animateY(200, onEnd: () => y++);
      await tester.pump();
      await tester.pump(_ms(50));
      expect(first, 1);
      expect(animator.phaseY, closeTo(0.25, 1e-4));

      final updatesBeforeStop = updates;
      animator.stop();
      expect(animator.phaseX, 1);
      expect(animator.phaseY, 1);
      expect([first, second, y], [1, 1, 1]);
      expect(animator.isAnimating, isFalse);
      expect(animator.running, isEmpty);
      // Like ValueAnimator.end(), each ended animation draws its final value once.
      expect(updates, updatesBeforeStop + 2);

      await tester.pump(_ms(300));
      animator.stop();
      expect(updates, updatesBeforeStop + 2);
      expect([first, second, y], [1, 1, 1]);
    },
  );

  testWidgets(
    'without a vsync every animation ends at once and calls onEnd synchronously',
    (tester) async {
      var updates = 0;
      final animator = ChartAnimator(onUpdate: () => updates++);
      expect(animator.vsync, isNull);

      var ends = 0;
      animator.animateX(100, onEnd: () => ends++);
      expect(ends, 1);
      expect(animator.phaseX, 1);
      expect(animator.isAnimating, isFalse);
      expect(animator.running, isEmpty);
      expect(updates, 1);

      var both = 0;
      animator.animateXY(
        100,
        200,
        easingX: Easing.EaseOutBack,
        onEnd: () => both++,
      );
      expect(both, 1);
      expect(animator.phaseX, 1);
      expect(animator.phaseY, 1);

      double? value;
      bool? cancelled;
      animator.start(
        key: ChartAnimator.SPIN,
        from: 0,
        to: 90,
        durationMillis: 100,
        easing: Easing.Linear,
        onUpdate: (it) => value = it,
        onEnd: (it) => cancelled = it,
      );
      expect(value, 90);
      expect(cancelled, isFalse);
      expect(animator.isAnimating, isFalse);
    },
  );

  testWidgets(
    'animateXY runs both phases and calls onEnd once after both ended',
    (tester) async {
      final animator = ChartAnimator(vsync: const TestVSync());
      var ends = 0;

      // easingY defaults to easingX.
      animator.animateXY(
        100,
        200,
        easingX: Easing.EaseInQuad,
        onEnd: () => ends++,
      );
      expect(animator.running, hasLength(2));
      await tester.pump();
      await tester.pump(_ms(50));
      expect(animator.phaseX, closeTo(0.25, 1e-4));
      expect(animator.phaseY, closeTo(0.0625, 1e-4));

      await tester.pump(_ms(51));
      expect(animator.phaseX, 1);
      expect(ends, 0);
      expect(animator.isAnimating, isTrue);

      await tester.pump(_ms(100));
      expect(animator.phaseY, 1);
      expect(ends, 1);
      expect(animator.isAnimating, isFalse);

      animator.animateXY(100, 100, easingY: Easing.EaseInQuad);
      await tester.pump();
      await tester.pump(_ms(50));
      expect(animator.phaseX, closeTo(0.5, 1e-4));
      expect(animator.phaseY, closeTo(0.25, 1e-4));
      await tester.pump(_ms(51));
    },
  );

  testWidgets('animateXY counts a half cancelled by animateX as ended', (
    tester,
  ) async {
    final animator = ChartAnimator(vsync: const TestVSync());
    var both = 0;
    var x = 0;

    animator.animateXY(60000, 100, onEnd: () => both++);
    animator.animateX(100, onEnd: () => x++);
    expect(both, 0);
    expect(animator.running, hasLength(2));

    await tester.pump();
    await tester.pump(_ms(101));
    expect(x, 1);
    expect(both, 1);
    expect(animator.running, isEmpty);
  });

  testWidgets(
    'start eases from..to without clamping, and onUpdate runs before the redraw listener',
    (tester) async {
      final log = <String>[];
      final animator = ChartAnimator(
        vsync: const TestVSync(),
        onUpdate: () => log.add('redraw'),
      );
      final values = <double>[];
      final ends = <bool>[];

      animator.start(
        key: Object(),
        from: 10,
        to: 20,
        durationMillis: 100,
        easing: Easing.EaseOutBack,
        onUpdate: (it) {
          values.add(it);
          log.add('update');
        },
        onEnd: ends.add,
      );
      // EaseOutBack(0) is 0 up to rounding.
      expect(values.single, closeTo(10, 1e-9));
      expect(log, ['update', 'redraw']);

      await tester.pump();
      await tester.pump(_ms(50));
      // EaseOutBack overshoots: 10 + 10 * 1.0876975.
      expect(values.last, closeTo(20.876975, 1e-4));

      await tester.pump(_ms(51));
      expect(values.last, closeTo(20, 1e-4));
      expect(ends, [false]);
    },
  );

  testWidgets(
    'start in a running slot cancels it: onEnd(true), the old value stays and is not redrawn',
    (tester) async {
      final animator = ChartAnimator(vsync: const TestVSync());
      final key = Object();
      final first = <double>[];
      final firstEnds = <bool>[];
      final second = <double>[];
      final secondEnds = <bool>[];

      animator.start(
        key: key,
        from: 0,
        to: 100,
        durationMillis: 100,
        easing: Easing.Linear,
        onUpdate: first.add,
        onEnd: firstEnds.add,
      );
      await tester.pump();
      await tester.pump(_ms(40));
      expect(first.last, closeTo(40, 1e-4));
      final firstUpdates = first.length;

      animator.start(
        key: key,
        from: 50,
        to: 60,
        durationMillis: 60000,
        easing: Easing.Linear,
        onUpdate: second.add,
        onEnd: secondEnds.add,
      );
      expect(firstEnds, [true]);
      expect(first, hasLength(firstUpdates));
      expect(second, [50]);
      expect(animator.running, hasLength(1));

      animator.stop();
      expect(secondEnds, [false]);
      expect(second.last, 60);
      expect(firstEnds, [true]);
    },
  );

  testWidgets('endValueAnimations ends the entry and data change slots only', (
    tester,
  ) async {
    final animator = ChartAnimator(vsync: const TestVSync());
    final spin = <bool>[];
    final dataChange = <bool>[];
    final entry = <bool>[];
    double? entryValue;
    var x = 0;

    void startIn(
      Object key,
      List<bool> ends, [
      void Function(double)? onUpdate,
    ]) => animator.start(
      key: key,
      from: 0,
      to: 5,
      durationMillis: 60000,
      easing: Easing.Linear,
      onUpdate: onUpdate ?? (_) {},
      onEnd: ends.add,
    );

    expect(identical(ChartAnimator.SPIN, ChartAnimator.DATA_CHANGE), isFalse);
    animator.animateX(60000, onEnd: () => x++);
    startIn(ChartAnimator.SPIN, spin);
    startIn(ChartAnimator.DATA_CHANGE, dataChange);
    startIn(Object(), entry, (it) => entryValue = it);
    expect(animator.running, hasLength(4));
    await tester.pump();
    await tester.pump(_ms(10));

    animator.endValueAnimations();
    expect(dataChange, [false]);
    expect(entry, [false]);
    expect(entryValue, 5);
    expect(spin, isEmpty);
    expect(x, 0);
    expect(animator.running, hasLength(2));
    expect(animator.isAnimating, isTrue);

    animator.stop();
    expect(spin, [false]);
    expect(x, 1);
  });

  testWidgets(
    'an onEnd that starts a new animation in its own slot keeps it running',
    (tester) async {
      final animator = ChartAnimator(vsync: const TestVSync());
      var ends = 0;
      void restartOnce() {
        ends++;
        if (ends == 1) animator.animateX(100, onEnd: restartOnce);
      }

      animator.animateX(100, onEnd: restartOnce);
      await tester.pump();
      await tester.pump(_ms(101));
      expect(ends, 1);
      expect(animator.running, hasLength(1));
      expect(animator.isAnimating, isTrue);
      expect(animator.phaseX, 0);

      await tester.pump();
      await tester.pump(_ms(101));
      expect(ends, 2);
      expect(animator.phaseX, 1);
      expect(animator.running, isEmpty);
    },
  );

  testWidgets(
    'a zero or negative duration ends at once with one update at the final value',
    (tester) async {
      final vsync = _TrackingVSync();
      final values = <double>[];
      final animator = ChartAnimator(vsync: vsync);
      var ends = 0;
      animator.animateX(0, onEnd: () => ends++);
      expect(animator.phaseX, 1);
      expect(ends, 1);
      animator.animateY(-5, onEnd: () => ends++);
      expect(animator.phaseY, 1);
      expect(ends, 2);
      // Like ValueAnimator.start() with no duration (setCurrentPlayTime(0) → fraction 1): one update, at the end
      // value.
      animator.start(
        key: Object(),
        from: 3,
        to: 7,
        durationMillis: 0,
        easing: Easing.Linear,
        onUpdate: values.add,
        onEnd: (_) => ends++,
      );
      expect(values, [7]);
      expect(ends, 3);
      expect(animator.isAnimating, isFalse);
      // Nothing ticks, so the host's provider is not asked for a ticker.
      expect(vsync.tickers, isEmpty);
      await tester.pump();
      expect(ends, 3);
    },
  );

  testWidgets(
    'an onEnd restarting its own slot with a duration of 0 ends the loop',
    (tester) async {
      final logs = <String?>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message);
      try {
        final animator = ChartAnimator(vsync: const TestVSync());
        var ends = 0;
        void loop() {
          ends++;
          animator.animateX(0, onEnd: loop);
        }

        animator.animateX(0, onEnd: loop);
        expect(ends, 1);
        expect(animator.phaseX, 1);
        expect(animator.isAnimating, isFalse);
        expect(logs, hasLength(1));
      } finally {
        debugPrint = previous;
      }
    },
  );

  testWidgets(
    'setting vsync to null while a self-restarting animation runs ends the loop',
    (tester) async {
      final logs = <String?>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message);
      try {
        final animator = ChartAnimator(vsync: const TestVSync());
        var ends = 0;
        void loop() {
          ends++;
          animator.animateY(1000, onEnd: loop);
        }

        animator.animateY(1000, onEnd: loop);
        await tester.pump();
        await tester.pump(_ms(1001));
        expect(ends, 1);
        expect(animator.isAnimating, isTrue);

        // As when the host widget goes away: the running restart ends (onEnd 2), its restart ends at once
        // (onEnd 3), and the restart from that onEnd is applied at its end state without onEnd.
        animator.vsync = null;
        expect(ends, 3);
        expect(animator.phaseY, 1);
        expect(animator.isAnimating, isFalse);
        expect(logs, hasLength(1));
      } finally {
        debugPrint = previous;
      }
    },
  );

  testWidgets(
    'every controller is disposed once its animation ended, however it ended',
    (tester) async {
      final vsync = _TrackingVSync();
      final animator = ChartAnimator(vsync: vsync);

      animator.animateX(100);
      animator.animateX(100);
      expect(vsync.tickers, hasLength(2));
      expect(vsync.tickers[0].disposed, isTrue);
      expect(vsync.tickers[1].disposed, isFalse);

      await tester.pump();
      await tester.pump(_ms(101));
      expect(vsync.tickers[1].disposed, isTrue);

      animator.animateY(100);
      await tester.pump();
      animator.stop();
      expect(vsync.tickers, hasLength(3));
      expect(vsync.allDisposed, isTrue);
    },
  );

  testWidgets('setting vsync to null ends the running animations', (
    tester,
  ) async {
    final animator = ChartAnimator(vsync: const TestVSync());
    var ends = 0;
    animator.animateX(100, onEnd: () => ends++);
    await tester.pump();
    await tester.pump(_ms(30));

    animator.vsync = null;
    expect(animator.vsync, isNull);
    expect(ends, 1);
    expect(animator.phaseX, 1);
    expect(animator.isAnimating, isFalse);

    animator.animateY(100, onEnd: () => ends++);
    expect(ends, 2);
    expect(animator.phaseY, 1);
  });

  testWidgets(
    'a new vsync ends the running animations and drives the later ones',
    (tester) async {
      final first = _TrackingVSync();
      final second = _TrackingVSync();
      final animator = ChartAnimator(vsync: first);
      var ends = 0;

      animator.animateX(100, onEnd: () => ends++);
      animator.vsync = first;
      expect(ends, 0);

      animator.vsync = second;
      expect(identical(animator.vsync, second), isTrue);
      expect(ends, 1);
      expect(animator.phaseX, 1);
      expect(first.allDisposed, isTrue);

      animator.animateX(100, onEnd: () => ends++);
      expect(second.tickers, hasLength(1));
      await tester.pump();
      await tester.pump(_ms(50));
      expect(animator.phaseX, closeTo(0.5, 1e-4));
      await tester.pump(_ms(51));
      expect(ends, 2);
      expect(second.allDisposed, isTrue);
    },
  );

  testWidgets(
    'an onEnd restarting the slot a new animation is cancelling is superseded by it',
    (tester) async {
      final logs = <String?>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message);
      try {
        final vsync = _TrackingVSync();
        final animator = ChartAnimator(vsync: vsync);
        var loopEnds = 0;
        void loop() {
          loopEnds++;
          animator.animateY(100, onEnd: loop);
        }

        animator.animateY(100, onEnd: loop);
        await tester.pump();
        await tester.pump(_ms(50));
        expect(animator.phaseY, closeTo(0.5, 1e-4));

        // Cancelling the loop's animation calls its onEnd, which starts the y slot again from inside this start; the
        // explicit animation wins and that restart is never created, so no controller is left behind.
        var ends = 0;
        animator.animateY(100, onEnd: () => ends++);
        expect(loopEnds, 1);
        expect(animator.running, hasLength(1));
        expect(vsync.tickers, hasLength(2));
        expect(vsync.tickers[0].disposed, isTrue);
        expect(animator.phaseY, 0);
        expect(logs, hasLength(1));

        await tester.pump();
        await tester.pump(_ms(101));
        expect(animator.phaseY, 1);
        expect(ends, 1);
        expect(loopEnds, 1);
        expect(animator.isAnimating, isFalse);
        expect(vsync.allDisposed, isTrue);
      } finally {
        debugPrint = previous;
      }
    },
  );
}
