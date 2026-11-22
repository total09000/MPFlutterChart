// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for its touch listeners. Drives the ported
// PieRadarChartTouchListener state machine (rotation past 8 dp, tap, long press, deceleration) with ChartTouchEvents on
// a minimal round chart, without a widget. The tests run in testWidgets for its fake clock: Flutter's
// VelocityTracker behind the gesture detector reads the gesture binding's sampling clock, the long press timer runs on
// fake time and the deceleration ticker on its frames. _FakeHost, _RecordingVSync and _Gestures follow the fixtures of
// the same name in bar_line_chart_touch_listener_test.dart; the events come from test/support/pie_radar_gestures.dart.
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show kLongPressTimeout, kTouchSlop;
import 'package:flutter/scheduler.dart'
    show Ticker, TickerCallback, TickerProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/chart_host.dart';
import 'package:mp_flutter_chart/src/charts/pie_radar_chart_base.dart';
import 'package:mp_flutter_chart/src/data/pie_data.dart';
import 'package:mp_flutter_chart/src/data/pie_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_entry.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/highlight/i_highlighter.dart';
import 'package:mp_flutter_chart/src/listener/chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/listener/on_chart_gesture_listener.dart';
import 'package:mp_flutter_chart/src/listener/pie_radar_chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/renderer/data_renderer.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';
import 'package:mp_flutter_chart/src/widgets/chart_touch_event.dart';

import '../support/pie_radar_gestures.dart';

/// Records the scroll requests of the touch listener; [vsync] is null unless a test drives the deceleration ticker.
class _FakeHost implements ChartHost {
  _FakeHost([this.vsync]);

  @override
  final TickerProvider? vsync;

  int paints = 0;
  int scrollDisables = 0;
  int scrollEnables = 0;

  @override
  void markNeedsPaint() => paints++;

  @override
  void postFrame(void Function() job) => job();

  @override
  void disableScroll() => scrollDisables++;

  @override
  void enableScroll() => scrollEnables++;
}

/// Hands out plain tickers and keeps them, so a test can see whether the deceleration ticker still runs.
class _RecordingVSync implements TickerProvider {
  final List<Ticker> tickers = [];

  @override
  Ticker createTicker(TickerCallback onTick) {
    final ticker = Ticker(onTick);
    tickers.add(ticker);
    return ticker;
  }
}

/// Records the gesture callbacks.
class _Gestures extends OnChartGestureListener {
  final List<ChartTouchEvent> longPresses = [];
  final List<ChartTouchEvent> singleTaps = [];

  /// The gesture each onChartGestureEnd reported.
  final List<ChartGesture> ends = [];

  @override
  void onChartLongPressed(ChartTouchEvent me) => longPresses.add(me);

  @override
  void onChartSingleTapped(ChartTouchEvent me) => singleTaps.add(me);

  @override
  void onChartGestureEnd(
    ChartTouchEvent me,
    ChartGesture lastPerformedGesture,
  ) => ends.add(lastPerformedGesture);
}

/// Draws nothing.
class _NoopRenderer extends DataRenderer {
  _NoopRenderer(super.animator, super.viewPortHandler);

  @override
  void initBuffers() {}

  @override
  void drawData(ui.Canvas c) {}

  @override
  void drawValues(ui.Canvas c) {}

  @override
  void drawExtras(ui.Canvas c) {}

  @override
  void drawHighlighted(ui.Canvas c, List<Highlight> indices) {}
}

/// The smallest round chart: a radius of 100 px, four equal quarters starting at [rotationAngle], no offsets, a
/// renderer that draws nothing and a highlighter that always answers the second entry.
class _RoundChart extends PieRadarChartBase<PieData> {
  @override
  void init() {
    super.init();
    renderer = _NoopRenderer(animator, viewPortHandler);
    highlighter = IHighlighter.fromFunction((x, y) => Highlight(1, 1, 0));
  }

  @override
  double get radius => 100;

  @override
  int getIndexForAngle(double angle) =>
      Utils.getNormalizedAngle(angle - rotationAngle) ~/ 90;

  @override
  double get requiredLegendOffset => 0;

  @override
  double get requiredBaseOffset => 0;
}

/// A 400 x 300 round chart with four slices, hosted by [host].
_RoundChart _chart(ChartHost host) {
  final chart = _RoundChart()..host = host;
  chart
    ..onSizeChanged(400, 300)
    ..data = PieData(
      PieDataSet([
        for (final v in [1.0, 2.0, 3.0, 4.0]) PieEntry(v),
      ], 'quarters'),
    );
  return chart;
}

PieRadarChartTouchListener _listener(PieRadarChartBase chart) =>
    chart.chartTouchListener as PieRadarChartTouchListener;

/// The rotation threshold of the listener: Kotlin's 8 dp.
final double _slop = Utils.convertDpToPixel(8);

/// Sends one-finger events to a chart.
extension on _RoundChart {
  bool down(double x, double y, int time) =>
      onTouchEvent(event(ChartTouchAction.down, time, [ui.Offset(x, y)]));

  bool move(double x, double y, int time) =>
      onTouchEvent(event(ChartTouchAction.move, time, [ui.Offset(x, y)]));

  bool up(double x, double y, int time) =>
      onTouchEvent(event(ChartTouchAction.up, time, [ui.Offset(x, y)]));

  bool cancel(double x, double y, int time) =>
      onTouchEvent(event(ChartTouchAction.cancel, time, [ui.Offset(x, y)]));

  /// Sends [action] at the point [angle] degrees around the content center, 50 px out (on the chart).
  void atAngle(ChartTouchAction action, double angle, int time) {
    final p = getPosition(centerOffsets, 50, angle);
    onTouchEvent(event(action, time, [ui.Offset(p.x, p.y)]));
  }

  /// Rotates clockwise from 0 to 40 degrees in steps of 10 degrees, one step every 16 ms of [clock] time from
  /// [time]: 625 degrees per second. The first step is 8.7 px long and only starts the rotation.
  void fling(int time, void Function(int time) setClock) {
    var t = time;
    setClock(t);
    atAngle(ChartTouchAction.down, 0, t);
    for (final angle in [10.0, 20.0, 30.0, 40.0]) {
      t += 16;
      setClock(t);
      atAngle(ChartTouchAction.move, angle, t);
    }
    t += 16;
    setClock(t);
    atAngle(ChartTouchAction.up, 40, t);
  }
}

void main() {
  group('PieRadarChartTouchListener', () {
    testWidgets('rotationStartsOnlyPastEightDp', (tester) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      final c = chart.centerOffsets;
      final sx = c.x + 50;
      final sy = c.y;

      expect(chart.down(sx, sy, 0), isTrue);
      chart.move(sx, sy + _slop - 1, 16);
      expect(listener.touchMode, ChartTouchListener.NONE);
      expect(host.scrollDisables, 0);
      // Exactly 8 dp is not past it: Kotlin's distance(...) > convertDpToPixel(8f).
      chart.move(sx, sy + _slop, 24);
      expect(listener.touchMode, ChartTouchListener.NONE);

      chart.move(sx, sy + _slop + 1, 32);
      expect(listener.touchMode, ChartTouchListener.ROTATE);
      expect(listener.lastGesture, ChartGesture.ROTATE);
      expect(host.scrollDisables, 1);
      // Kotlin's MOVE branch is if / else-if: the move that starts the rotation does not rotate.
      expect(chart.rotationAngle, 270);

      // From then on the rotation follows the angle covered since the down, from 270.
      final startAngle = chart.getAngleForPoint(sx, sy);
      final paints = host.paints;
      chart.move(sx - 10, sy + 40, 48);
      expect(
        chart.rotationAngle,
        closeTo(
          Utils.getNormalizedAngle(
            270 + chart.getAngleForPoint(sx - 10, sy + 40) - startAngle,
          ),
          1e-4,
        ),
      );
      expect(host.paints, paints + 1);
      // 9 o'clock is 180 degrees on from 3 o'clock: 270 + 180 = 450, normalized 90.
      chart.move(c.x - 50, c.y, 64);
      expect(chart.rotationAngle, closeTo(90, 1e-4));
      expect(host.scrollDisables, 1);

      chart.up(c.x - 50, c.y, 80);
      expect(listener.touchMode, ChartTouchListener.NONE);
    });

    testWidgets('aTouchOffTheChartNeverRotates', (tester) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      final gestures = _Gestures();
      chart.onChartGestureListener = gestures;
      expect(chart.distanceToCenter(2, 2), greaterThan(chart.radius));

      chart.down(2, 2, 0);
      for (var i = 1; i <= 15; i++) {
        chart.move(2 + 4.0 * i, 2, 16 * i);
      }
      expect(listener.touchMode, ChartTouchListener.NONE);
      expect(host.scrollDisables, 0);
      expect(chart.rotationAngle, 270);

      // Kotlin enables scrolling on every up.
      chart.up(62, 2, 256);
      expect(host.scrollEnables, 1);
      expect(listener.touchMode, ChartTouchListener.NONE);
      expect(gestures.ends, [ChartGesture.NONE]);
      expect(chart.rotationAngle, 270);
    });

    testWidgets('rotationDisabledNeverRotatesButStillTaps', (tester) async {
      final host = _FakeHost();
      final chart = _chart(host)..isRotationEnabled = false;
      final listener = _listener(chart);
      final gestures = _Gestures();
      chart.onChartGestureListener = gestures;
      final c = chart.centerOffsets;
      final sx = c.x + 50;
      final sy = c.y;

      chart.down(sx, sy, 0);
      for (var i = 1; i <= 10; i++) {
        chart.move(sx, sy + 4.0 * i, 16 * i);
      }
      expect(listener.touchMode, ChartTouchListener.NONE);
      expect(host.scrollDisables, 0);
      expect(chart.rotationAngle, 270);
      chart.up(sx, sy + 40, 176);
      // Without rotation Kotlin skips its whole `when`: no gesture start or end, no scroll calls.
      expect(host.scrollEnables, 0);
      expect(gestures.ends, isEmpty);

      chart.down(sx, sy, 1000);
      chart.up(sx, sy, 1050);
      expect(gestures.singleTaps, hasLength(1));
      expect(chart.highlighted, hasLength(1));
      expect(chart.highlighted.single.equalTo(Highlight(1, 1, 0)), isTrue);
    });

    testWidgets('upAndCancelEndTheRotation', (tester) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      final gestures = _Gestures();
      chart.onChartGestureListener = gestures;
      final c = chart.centerOffsets;

      void rotate(int t) {
        chart.down(c.x + 50, c.y, t);
        chart.move(c.x + 50, c.y + 12, t + 16);
        chart.move(c.x, c.y + 50, t + 32);
        expect(listener.touchMode, ChartTouchListener.ROTATE);
      }

      rotate(0);
      chart.up(c.x, c.y + 50, 48);
      expect(listener.touchMode, ChartTouchListener.NONE);
      expect(host.scrollEnables, 1);
      expect(gestures.ends, [ChartGesture.ROTATE]);

      rotate(1000);
      expect(host.scrollDisables, 2);
      chart.cancel(c.x, c.y + 50, 1048);
      expect(listener.touchMode, ChartTouchListener.NONE);
      expect(host.scrollEnables, 2);
      expect(gestures.ends, [ChartGesture.ROTATE, ChartGesture.ROTATE]);
      listener.stopDeceleration();
    });

    testWidgets('aShortRotationIsNotATap', (tester) async {
      // A rotation that starts within Flutter's kTouchSlop (18) cancels the gesture
      // detector's tap, as crossing Android's 8 dp slop does.
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      final gestures = _Gestures();
      chart.onChartGestureListener = gestures;
      final c = chart.centerOffsets;
      final sx = c.x + 50;
      final sy = c.y;
      expect(12, inExclusiveRange(_slop, kTouchSlop));

      chart.down(sx, sy, 0);
      chart.move(sx, sy + 12, 16);
      expect(listener.touchMode, ChartTouchListener.ROTATE);
      expect(host.scrollDisables, 1);
      chart.up(sx, sy + 12, 32);
      expect(chart.highlighted, isEmpty);
      expect(listener.lastHighlighted, isNull);
      expect(gestures.singleTaps, isEmpty);
      expect(listener.touchMode, ChartTouchListener.NONE);
      expect(gestures.ends, [ChartGesture.ROTATE]);
      expect(host.scrollEnables, 1);

      // The next gesture goes through the 8 dp threshold again and claims the gesture again.
      chart.down(sx, sy, 1000);
      chart.move(sx, sy + _slop - 1, 1016);
      expect(listener.touchMode, ChartTouchListener.NONE);
      expect(host.scrollDisables, 1);
      chart.move(sx, sy + _slop + 1, 1032);
      expect(listener.touchMode, ChartTouchListener.ROTATE);
      expect(host.scrollDisables, 2);
      chart.up(sx, sy + _slop + 1, 1048);
      listener.stopDeceleration();

      // A plain tap right after it still highlights: the cancel left the detector ready for the next tap.
      chart.down(sx, sy, 2000);
      chart.up(sx, sy, 2050);
      expect(gestures.singleTaps, hasLength(1));
      expect(chart.highlighted, hasLength(1));
      expect(chart.highlighted.single.equalTo(Highlight(1, 1, 0)), isTrue);
      expect(listener.touchMode, ChartTouchListener.NONE);
    });

    testWidgets('aTapHighlightsAndASecondTapClears', (tester) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      final gestures = _Gestures();
      chart.onChartGestureListener = gestures;
      final c = chart.centerOffsets;
      final sx = c.x + 50;
      final sy = c.y;

      chart.down(sx, sy, 0);
      chart.up(sx, sy, 50);
      expect(gestures.singleTaps, hasLength(1));
      expect(listener.lastGesture, ChartGesture.SINGLE_TAP);
      expect(chart.highlighted, hasLength(1));
      expect(chart.highlighted.single.equalTo(Highlight(1, 1, 0)), isTrue);
      expect(listener.lastHighlighted?.equalTo(Highlight(1, 1, 0)), isTrue);
      // onSingleTapUp consumed the up, so Kotlin's UP branch did not run.
      expect(gestures.ends, isEmpty);
      expect(host.scrollEnables, 0);

      // Past kDoubleTapTimeout (300 ms) after the first up, so this is a single tap too: tapping the highlighted
      // value again clears it (performHighlight).
      chart.down(sx, sy, 1000);
      chart.up(sx, sy, 1050);
      expect(gestures.singleTaps, hasLength(2));
      expect(chart.highlighted, isEmpty);
      expect(listener.lastHighlighted, isNull);

      // Without highlight per tap the tap is reported but not consumed, and the UP branch runs.
      chart.isHighlightPerTapEnabled = false;
      chart.down(sx, sy, 2000);
      chart.up(sx, sy, 2050);
      expect(gestures.singleTaps, hasLength(3));
      expect(chart.highlighted, isEmpty);
      expect(gestures.ends, [ChartGesture.SINGLE_TAP]);
      expect(host.scrollEnables, 1);
    });

    testWidgets('aLongPressIsReportedOnceAndARotationCancelsIt', (
      tester,
    ) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      final gestures = _Gestures();
      chart.onChartGestureListener = gestures;
      final c = chart.centerOffsets;
      final sx = c.x + 50;
      final sy = c.y;

      chart.down(sx, sy, 0);
      await tester.pump(kLongPressTimeout);
      expect(gestures.longPresses, hasLength(1));
      expect(gestures.longPresses.single.action, ChartTouchAction.down);
      expect(listener.lastGesture, ChartGesture.LONG_PRESS);
      await tester.pump(kLongPressTimeout);
      expect(gestures.longPresses, hasLength(1));
      chart.up(sx, sy, 1000);
      expect(gestures.singleTaps, isEmpty);
      expect(chart.highlighted, isEmpty);

      // A rotation that starts before the timeout, within kTouchSlop: no long press.
      chart.down(sx, sy, 2000);
      await tester.pump(const Duration(milliseconds: 100));
      chart.move(sx, sy + 12, 2100);
      expect(listener.touchMode, ChartTouchListener.ROTATE);
      await tester.pump(kLongPressTimeout);
      expect(gestures.longPresses, hasLength(1));
      chart.up(sx, sy + 12, 2700);
      listener.stopDeceleration();
    });

    testWidgets('pointerDownAndUpAreIgnored', (tester) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      final gestures = _Gestures();
      chart.onChartGestureListener = gestures;
      final c = chart.centerOffsets;

      chart.down(c.x + 50, c.y, 0);
      chart.move(c.x + 50, c.y + 12, 16);
      chart.move(c.x, c.y + 50, 32);
      expect(listener.touchMode, ChartTouchListener.ROTATE);
      final angle = chart.rotationAngle;
      final paints = host.paints;

      final twoFingers = [ui.Offset(c.x, c.y + 50), ui.Offset(c.x - 50, c.y)];
      chart.onTouchEvent(
        event(ChartTouchAction.pointerDown, 40, twoFingers, actionIndex: 1),
      );
      chart.onTouchEvent(
        event(ChartTouchAction.pointerUp, 48, twoFingers, actionIndex: 1),
      );
      expect(listener.touchMode, ChartTouchListener.ROTATE);
      expect(chart.rotationAngle, angle);
      expect(host.paints, paints);
      expect(host.scrollDisables, 1);
      expect(host.scrollEnables, 0);
      expect(gestures.ends, isEmpty);

      // The remaining finger keeps rotating: 3 o'clock to 9 o'clock is 270 + 180 = 450, normalized 90.
      chart.move(c.x - 50, c.y, 64);
      expect(chart.rotationAngle, closeTo(90, 1e-4));
      chart.up(c.x - 50, c.y, 80);
      expect(listener.touchMode, ChartTouchListener.NONE);
      expect(host.scrollEnables, 1);
      listener.stopDeceleration();
    });

    testWidgets('decelerationSlowsDownAndStops', (tester) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      expect(chart.isDragDecelerationEnabled, isTrue);
      final coef = chart.dragDecelerationFrictionCoef;
      expect(coef, 0.9);
      var now = 10000;
      listener.clock = () => now;

      // Samples (ms, degrees): (0, 0) at the down, (16, 10) … (64, 40), (80, 40) at the up. calculateVelocity:
      // first (0, 0), last (80, 40), the last sample with another angle (48, 30), so clockwise; 40 degrees in 0.08 s.
      chart.fling(now, (t) => now = t);
      expect(listener.touchMode, ChartTouchListener.NONE);
      const velocity = 40 / 0.08;

      final deltas = <double>[];
      var steps = 0;
      while (steps < 1000) {
        now += 16;
        final before = chart.rotationAngle;
        final paints = host.paints;
        chart.computeScroll();
        steps++;
        // The raw angle is the normalized one before the step plus the step, so it does not wrap at 360.
        deltas.add(chart.rawRotationAngle - before);
        if (host.paints == paints) break;
      }
      // Each step multiplies the velocity by the friction first: the first one turns 500 * 0.9 * 0.016 degrees.
      expect(deltas.first, closeTo(velocity * coef * 0.016, 1e-4));
      for (var i = 1; i < deltas.length; i++) {
        expect(deltas[i], greaterThan(0));
        expect(deltas[i] / deltas[i - 1], closeTo(coef, 1e-4));
      }
      // 500 * 0.9^n stays at or above 0.001 up to n = 124: the 125th step turns the chart once more, then stops
      // without asking for another frame.
      expect(steps, 125);

      // Stopped: further calls do nothing.
      final stopped = chart.rotationAngle;
      final stoppedRaw = chart.rawRotationAngle;
      final stoppedPaints = host.paints;
      now += 16;
      chart.computeScroll();
      expect(chart.rotationAngle, stopped);
      expect(chart.rawRotationAngle, stoppedRaw);
      expect(host.paints, stoppedPaints);
    });

    testWidgets('velocityWrapsAcrossZero', (tester) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      var now = 0;
      listener.clock = () => now;

      chart.atAngle(ChartTouchAction.down, 350, now);
      now = 16;
      // 4.4 px from the down: not rotating yet, but sampled.
      chart.atAngle(ChartTouchAction.move, 355, now);
      now = 32;
      // 10.5 px from the down: the rotation starts.
      chart.atAngle(ChartTouchAction.move, 2, now);
      expect(listener.touchMode, ChartTouchListener.ROTATE);
      now = 48;
      chart.atAngle(ChartTouchAction.move, 8, now);
      now = 64;
      chart.atAngle(ChartTouchAction.up, 8, now);

      // Kotlin's calculateVelocity on the samples (ms, degrees) (0, 350) down, (16, 355), (32, 2), (48, 8),
      // (64, 8) up: firstSample = (0, 350), lastSample = (64, 8); beforeLastSample walks back past the samples at 8
      // to (32, 2). timeDelta = 0.064 s. clockwise = 8 >= 2 = true, and |8 - 2| = 6 is not > 270, so it stays true.
      // lastSample - firstSample = -342 is not > 180; firstSample - lastSample = 342 > 180, so lastSample.angle +=
      // 360 = 368. velocity = |368 - 350| / 0.064 = 18 / 0.064 = 281.25, positive because clockwise. Without that
      // wrap it would be |8 - 350| / 0.064 = 5343.75 degrees per second.
      const velocity = 18 / 0.064;

      // The first deceleration step turns velocity * friction * 16 ms.
      now += 16;
      final before = chart.rotationAngle;
      final paints = host.paints;
      chart.computeScroll();
      expect(host.paints, paints + 1);
      final measured =
          (chart.rawRotationAngle - before) /
          (chart.dragDecelerationFrictionCoef * 0.016);
      expect(measured, greaterThan(0));
      expect(measured, closeTo(velocity, 1e-4));
      listener.stopDeceleration();
    });

    testWidgets('velocityWrapsAcrossZeroCounterClockwise', (tester) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      var now = 0;
      listener.clock = () => now;

      chart.atAngle(ChartTouchAction.down, 10, now);
      now = 16;
      // 4.4 px from the down: not rotating yet, but sampled.
      chart.atAngle(ChartTouchAction.move, 5, now);
      now = 32;
      // 10.5 px from the down: the rotation starts.
      chart.atAngle(ChartTouchAction.move, 358, now);
      expect(listener.touchMode, ChartTouchListener.ROTATE);
      now = 48;
      chart.atAngle(ChartTouchAction.move, 352, now);
      now = 64;
      chart.atAngle(ChartTouchAction.up, 352, now);

      // Kotlin's calculateVelocity on the samples (ms, degrees) (0, 10) down, (16, 5), (32, 358), (48, 352),
      // (64, 352) up: firstSample = (0, 10), lastSample = (64, 352); beforeLastSample walks back past the samples at
      // 352 to (32, 358). timeDelta = 0.064 s. clockwise = 352 >= 358 = false, and |352 - 358| = 6 is not > 270, so
      // it stays false. lastSample - firstSample = 342 > 180, so firstSample.angle += 360 = 370. velocity =
      // |352 - 370| / 0.064 = 18 / 0.064 = 281.25, negated because not clockwise: -281.25. Without that wrap it would
      // be -|352 - 10| / 0.064 = -5343.75 degrees per second.
      const velocity = -18 / 0.064;

      // The first deceleration step turns velocity * friction * 16 ms, backwards.
      now += 16;
      final before = chart.rotationAngle;
      final paints = host.paints;
      chart.computeScroll();
      expect(host.paints, paints + 1);
      final measured =
          (chart.rawRotationAngle - before) /
          (chart.dragDecelerationFrictionCoef * 0.016);
      expect(measured, lessThan(0));
      expect(measured, closeTo(velocity, 1e-4));
      listener.stopDeceleration();
    });

    testWidgets('samplesOlderThanASecondArePruned', (tester) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      var now = 0;
      listener.clock = () => now;

      chart.atAngle(ChartTouchAction.down, 0, now);
      now = 100;
      // 8.7 px from the down: the rotation starts.
      chart.atAngle(ChartTouchAction.move, 10, now);
      expect(listener.touchMode, ChartTouchListener.ROTATE);
      now = 1500;
      chart.atAngle(ChartTouchAction.move, 20, now);
      now = 1600;
      chart.atAngle(ChartTouchAction.move, 30, now);
      now = 1650;
      chart.atAngle(ChartTouchAction.up, 40, now);

      // Kotlin's sampleVelocity keeps at least two samples and drops the first ones more than 1000 ms older than
      // the new one: (1500, 20) drops (0, 0), (1600, 30) drops (100, 10), and (1650, 40) keeps (1500, 20), 150 ms
      // older. calculateVelocity: first (1500, 20), last (1650, 40), clockwise; 20 degrees in 0.15 s. With all the
      // samples it would be 40 degrees in 1.65 s, 24.2 degrees per second.
      const velocity = 20 / 0.15;

      // The first deceleration step turns velocity * friction * 16 ms.
      now += 16;
      final before = chart.rotationAngle;
      final paints = host.paints;
      chart.computeScroll();
      expect(host.paints, paints + 1);
      final measured =
          (chart.rawRotationAngle - before) /
          (chart.dragDecelerationFrictionCoef * 0.016);
      expect(measured, closeTo(velocity, 1e-3));
      listener.stopDeceleration();
    });

    testWidgets('aNewDownStopsTheDeceleration', (tester) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      var now = 0;
      listener.clock = () => now;

      chart.fling(now, (t) => now = t);
      now += 16;
      var before = chart.rotationAngle;
      chart.computeScroll();
      expect(chart.rawRotationAngle, greaterThan(before));

      final c = chart.centerOffsets;
      now += 16;
      chart.down(c.x + 50, c.y, now);
      before = chart.rotationAngle;
      final paints = host.paints;
      now += 16;
      chart.computeScroll();
      expect(chart.rotationAngle, before);
      expect(host.paints, paints);
      chart.up(c.x + 50, c.y, now);
    });

    testWidgets('theDecelerationTickerStops', (tester) async {
      final vsync = _RecordingVSync();
      final host = _FakeHost(vsync);
      final chart = _chart(host);
      final listener = _listener(chart);
      listener.clock = () => tester.binding.clock.now().millisecondsSinceEpoch;
      // The fake clock stands still between the events, so the samples share one time and calculateVelocity takes
      // 0.1 s: 400 degrees per second.
      void fling(int t) => chart.fling(t, (_) {});

      fling(0);
      expect(vsync.tickers, hasLength(1));
      expect(vsync.tickers.last.isActive, isTrue);
      final angle = chart.rotationAngle;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(chart.rotationAngle, isNot(angle));
      chart.onDetachedFromWindow();
      expect(vsync.tickers.last.isActive, isFalse);

      fling(1000);
      expect(vsync.tickers, hasLength(2));
      expect(vsync.tickers.last.isActive, isTrue);
      await tester.pump(const Duration(milliseconds: 16));
      chart.onHostVsyncChanged();
      expect(vsync.tickers.last.isActive, isFalse);

      fling(2000);
      expect(vsync.tickers, hasLength(3));
      expect(vsync.tickers.last.isActive, isTrue);
      await tester.pump(const Duration(milliseconds: 16));
      final c = chart.centerOffsets;
      chart.down(c.x + 50, c.y, 3000);
      expect(vsync.tickers.last.isActive, isFalse);
      chart.up(c.x + 50, c.y, 3050);

      fling(4000);
      expect(vsync.tickers, hasLength(4));
      expect(vsync.tickers.last.isActive, isTrue);
      // The chart gets another touch listener: the old one's ticker stops on its next frame.
      chart.chartTouchListener = PieRadarChartTouchListener(chart);
      await tester.pump(const Duration(milliseconds: 16));
      expect(vsync.tickers.last.isActive, isFalse);
      expect(vsync.tickers, hasLength(4));

      // A fling left to itself: the deceleration ends on the frame where the velocity falls below 0.001 degrees per
      // second, 400 * 0.9^n < 0.001 from n = 123, and its ticker stops with it, leaving no frame callback behind.
      final next = _listener(chart)
        ..clock = () => tester.binding.clock.now().millisecondsSinceEpoch;
      fling(5000);
      expect(vsync.tickers, hasLength(5));
      expect(vsync.tickers.last.isActive, isTrue);
      var frames = 0;
      while (vsync.tickers.last.isActive && frames < 1000) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      expect(frames, 123);
      expect(vsync.tickers.last.isActive, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      final stopped = chart.rotationAngle;
      await tester.pump(const Duration(milliseconds: 16));
      expect(chart.rotationAngle, stopped);
      expect(vsync.tickers, hasLength(5));
      next.stopDeceleration();
    });
  });
}
