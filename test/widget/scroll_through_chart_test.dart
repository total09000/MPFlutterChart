// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no test for a chart inside a scrolling parent. Checks that a
// swipe along an enclosing scrollable that starts on a chart which does not claim it (never calls disableScroll)
// reaches the scrollable in full: with `DragStartBehavior.down` the list scrolls exactly as for a swipe from outside
// the chart, with the same travel and the same fling (C3 D1). And it pins Flutter's own arena behaviour behind the
// default `DragStartBehavior.start`, which drops the travel up to and including the move that passes the list's slop
// whenever the list has to win the arena against another recognizer, the chart's or any other.
//
// The pie and radar cases pin lane A's route order (5bff694, ChartGestureRecognizer._handleDown: the list sees each
// event of a finger before the chart) against PieRadarChartTouchListener.kt:59-64, where a rotation starts and claims
// the gesture once the finger is more than 8 dp from its down. With Android's 8 dp list slop, a straight swipe along
// the list passes both thresholds on the same move however small its moves are, and the list, which sees that move
// first, takes it as Android's parent does in onInterceptTouchEvent: the ring does not turn. A drag across the list
// still rotates, and with Flutter's default slop (kTouchSlop, 18 px, as on iOS) the rotation claims first.
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show DragStartBehavior, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/core.dart' as core;
import 'package:mp_flutter_chart/mp_flutter_chart.dart' as w;

/// The emulator of the device comparison: 2.625 physical pixels per logical pixel.
const double _dpr = 2.625;

/// Android's 8 dp touch slop, which a Flutter `Scrollable` takes from the `MediaQuery` gesture settings.
const double _listSlop = 8;

/// Records the velocity of each ballistic the scroll position starts, a drag end's included (0 for one without a
/// fling).
class _RecordingPhysics extends ClampingScrollPhysics {
  const _RecordingPhysics(this.velocities, {super.parent});

  final List<double> velocities;

  @override
  _RecordingPhysics applyTo(ScrollPhysics? ancestor) =>
      _RecordingPhysics(velocities, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    velocities.add(velocity);
    return super.createBallisticSimulation(position, velocity);
  }
}

/// A DesignActivity card's chart: drag, scale and double tap zoom off, as `nightfallBase` sets them, and a value
/// highlighted.
core.LineChart _designChart() {
  final chart = core.LineChart()
    ..isScaleEnabled = false
    ..isDragEnabled = false
    ..isDoubleTapToZoomEnabled = false;
  chart.data = _lineData();
  chart.highlightValue(9, 0);
  return chart;
}

core.LineData _lineData() => core.LineData([
  core.LineDataSet([
    for (var i = 0; i < 12; i++)
      core.Entry(x: i.toDouble(), y: (i * 7 % 11).toDouble()),
  ], 'a'),
]);

core.BarData _barData() => core.BarData([
  core.BarDataSet([
    for (var i = 0; i < 10; i++) core.BarEntry(x: i.toDouble(), y: i + 1.0),
  ], 'b'),
]);

/// A pie or radar chart widget whose [setup] hands over the core chart.
typedef _RoundChart =
    Widget Function(void Function(core.PieRadarChartBase chart) setup);

/// The pie and radar widgets of the default entry point, with the rotation and deceleration on by default.
final List<(String, _RoundChart)> _roundCharts = [
  (
    'pie',
    (setup) => w.PieChart(
      data: core.PieData(
        core.PieDataSet([
          core.PieEntry(1),
          core.PieEntry(2),
          core.PieEntry(3),
        ], 'p'),
      ),
      setup: setup,
    ),
  ),
  (
    'radar',
    (setup) => w.RadarChart(
      data: core.RadarData([
        core.RadarDataSet([
          for (var i = 1; i <= 5; i++) core.RadarEntry(i.toDouble()),
        ], 'r'),
      ]),
      setup: setup,
    ),
  ),
];

/// The screen position [fraction] of [chart]'s radius out from its center at [angle] degrees (0 at 3 o'clock,
/// clockwise): on the ring of a pie, outside its hole, and on the web of a radar.
Offset _onTheChart(
  WidgetTester tester,
  core.PieRadarChartBase chart,
  double angle, {
  double fraction = 0.75,
}) {
  final p = chart.getPosition(
    chart.centerOffsets,
    chart.radius * fraction,
    angle,
  );
  return tester.getTopLeft(find.byType(w.ChartRenderBoxWidget)) +
      Offset(p.x, p.y);
}

/// What a swipe ended with: the list's offset when the finger lifted and once the list settled, in logical pixels,
/// and the velocity the drag ended with (the first ballistic after the down), or null where no velocity was recorded.
typedef _Result = ({double afterUp, double settled, double? endVelocity});

/// A finger's swipe: [distance] logical pixels in [moves] equal moves over [millis] ms, the move `i` at
/// `round(i * millis / moves)` ms and the up at [millis], with the last move.
typedef _Swipe = ({double distance, int moves, int millis});

/// A device swipe of [physical] pixels in [millis] ms as `adb input swipe` gives it to a Flutter app at 60 Hz: one move
/// per frame of about 16 ms.
_Swipe _adbSwipe(double physical, int millis) =>
    (distance: physical / _dpr, moves: (millis / 16).round(), millis: millis);

/// Shows [target] in a list along [axis] with [dragStartBehavior], after 100 px of other content (the "header") and
/// before 3000 more, and does [swipe] against [axis] from the centre of the header or of [target].
///
/// By default the list has Android's 8 dp touch slop and `ClampingScrollPhysics` that record the fling velocities.
/// With [platformDefaults] it has the platform's default physics and no slop from the platform (`kTouchSlop`), as on
/// iOS, and records no velocity.
///
/// [startOnTarget], read once [target] is shown, replaces the centre of [target] as the start of a swipe from the
/// target; [direction], a unit vector, replaces the direction against [axis].
Future<_Result> _swipe(
  WidgetTester tester, {
  required Widget target,
  required Axis axis,
  required DragStartBehavior dragStartBehavior,
  required bool fromTarget,
  required _Swipe swipe,
  bool platformDefaults = false,
  Offset Function()? startOnTarget,
  Offset? direction,
}) async {
  tester.view.devicePixelRatio = _dpr;
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.gestureSettings = platformDefaults
      ? const ui.GestureSettings()
      : const ui.GestureSettings(physicalTouchSlop: _listSlop * _dpr);
  addTearDown(tester.view.reset);
  final controller = ScrollController();
  addTearDown(controller.dispose);
  final velocities = <double>[];
  // A fresh tree, so that no scroll offset carries over from an earlier swipe in the same test.
  await tester.pumpWidget(const SizedBox());
  final vertical = axis == Axis.vertical;
  Widget sized(Key key, double extent, Widget child) => vertical
      ? SizedBox(key: key, height: extent, child: child)
      : SizedBox(key: key, width: extent, child: child);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          controller: controller,
          scrollDirection: axis,
          dragStartBehavior: dragStartBehavior,
          physics: platformDefaults ? null : _RecordingPhysics(velocities),
          child: Flex(
            direction: axis,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sized(const ValueKey('header'), 100, const SizedBox.expand()),
              sized(const ValueKey('target'), 300, target),
              sized(const ValueKey('rest'), 3000, const SizedBox.expand()),
            ],
          ),
        ),
      ),
    ),
  );
  final start = fromTarget && startOnTarget != null
      ? startOnTarget()
      : tester.getCenter(
          find.byKey(ValueKey(fromTarget ? 'target' : 'header')),
        );
  final step =
      (direction ?? (vertical ? const Offset(0, -1) : const Offset(-1, 0))) *
      (swipe.distance / swipe.moves);
  final gesture = await tester.createGesture();
  velocities.clear();
  await gesture.down(start);
  var time = 0;
  for (var i = 1; i <= swipe.moves; i++) {
    final next = (i * swipe.millis / swipe.moves).round();
    await tester.pump(Duration(milliseconds: next - time));
    time = next;
    await gesture.moveTo(
      start + step * i.toDouble(),
      timeStamp: Duration(milliseconds: time),
    );
  }
  await gesture.up(timeStamp: Duration(milliseconds: time));
  final afterUp = controller.offset;
  await tester.pumpAndSettle();
  return (
    afterUp: afterUp,
    settled: controller.offset,
    endVelocity: velocities.firstOrNull,
  );
}

void main() {
  final cases = <(String, Axis, Widget Function())>[
    (
      'a chart with drag and scale disabled in a vertical list',
      Axis.vertical,
      () {
        final chart = _designChart();
        return w.ChartHostWidget(chart: chart, data: chart.data);
      },
    ),
    (
      'a fully zoomed out LineChart with drag enabled in a vertical list',
      Axis.vertical,
      () => w.LineChart(data: _lineData()),
    ),
    (
      'a fully zoomed out HorizontalBarChart in a horizontal list',
      Axis.horizontal,
      () => w.HorizontalBarChart(data: _barData()),
    ),
  ];
  for (final (name, axis, target) in cases) {
    group('$name with DragStartBehavior.down', () {
      Future<_Result> swipe(
        WidgetTester tester, {
        required bool fromTarget,
        required double physical,
        required int millis,
      }) {
        return _swipe(
          tester,
          target: target(),
          axis: axis,
          dragStartBehavior: DragStartBehavior.down,
          fromTarget: fromTarget,
          swipe: _adbSwipe(physical, millis),
        );
      }

      for (final (physical, millis) in [(150.0, 400), (400.0, 300)]) {
        testWidgets(
          'a ${physical.toInt()} px swipe in $millis ms from the chart scrolls the list as one from outside it',
          (tester) async {
            final outside = await swipe(
              tester,
              fromTarget: false,
              physical: physical,
              millis: millis,
            );
            final onChart = await swipe(
              tester,
              fromTarget: true,
              physical: physical,
              millis: millis,
            );
            expect(outside.afterUp, closeTo(physical / _dpr, 0.01));
            expect(onChart.afterUp, closeTo(outside.afterUp, 0.01));
            expect(onChart.settled, closeTo(outside.settled, 0.01));
            expect(onChart.endVelocity, closeTo(outside.endVelocity!, 0.01));
          },
        );
      }

      testWidgets('a fast swipe from the chart flings the list', (
        tester,
      ) async {
        final onChart = await swipe(
          tester,
          fromTarget: true,
          physical: 400,
          millis: 300,
        );
        expect(onChart.endVelocity, allOf(isNotNull, isNot(0)));
        expect(onChart.settled, greaterThan(onChart.afterUp));
      });
    });
  }

  testWidgets(
    "Flutter's arena, not the chart: with the default DragStartBehavior.start a list that has to win against another "
    "recognizer, the chart's or a tap's, drops the travel up to and including the move past its slop, and a list "
    'alone drops none',
    (tester) async {
      // Fine moves of 0.5 px: the 17th, at 8.5 px, is the first past the 8 px slop, and the list accepts on it.
      const swipe = (distance: 60.0, moves: 120, millis: 480);
      final step = swipe.distance / swipe.moves;
      final dropped = ((_listSlop / step).floor() + 1) * step;
      Future<double> travel(Widget target, {required bool fromTarget}) async {
        final r = await _swipe(
          tester,
          target: target,
          axis: Axis.vertical,
          dragStartBehavior: DragStartBehavior.start,
          fromTarget: fromTarget,
          swipe: swipe,
        );
        return r.afterUp;
      }

      final chart = _designChart();
      final onChart = await travel(
        w.ChartHostWidget(chart: chart, data: chart.data),
        fromTarget: true,
      );
      final onTap = await travel(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: const SizedBox.expand(),
        ),
        fromTarget: true,
      );
      final outside = await travel(const SizedBox.expand(), fromTarget: false);

      expect(outside, swipe.distance);
      expect(onChart, swipe.distance - dropped);
      expect(onTap, onChart);
    },
  );

  testWidgets(
    "on iOS BouncingScrollPhysics' start threshold eases the jump DragStartBehavior.down gives the list: a slow swipe "
    'from the chart still scrolls the list less than one from outside it',
    (tester) async {
      // iOS's default physics, and its slop: kTouchSlop, as iOS reports none. The physics scroll nothing until a drag
      // has moved 3.5 px and then only 3.5 / 3 px for the update that passes that, unless that update is a single jump
      // of more than 24 px (ScrollDragController._bigThresholdBreakDistance). A 150 px swipe in 400 ms is 25 moves of
      // 2.29 px. From outside the chart the list is alone and starts at the down, so it drops the first move and
      // about half of the second; from the chart it starts on the 8th move, past kTouchSlop at 18.3 px, and those
      // 18.3 px come as one update, eased like the second move from outside: 13.7 px less of 57.1 px.
      final swipe = _adbSwipe(150, 400);
      final step = swipe.distance / swipe.moves;
      final threshold =
          const BouncingScrollPhysics().dragStartDistanceMotionThreshold;
      final eased = threshold / 3;
      final passingThreshold = (threshold / step).floor() + 1;
      final passingSlop = (kTouchSlop / step).floor() + 1;
      expect(passingSlop * step, lessThanOrEqualTo(24));
      Future<double> travel({required bool fromTarget}) async {
        final chart = _designChart();
        final r = await _swipe(
          tester,
          target: w.ChartHostWidget(chart: chart, data: chart.data),
          axis: Axis.vertical,
          dragStartBehavior: DragStartBehavior.down,
          fromTarget: fromTarget,
          swipe: swipe,
          platformDefaults: true,
        );
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .physics,
          isA<BouncingScrollPhysics>(),
        );
        return r.afterUp;
      }

      final outside = await travel(fromTarget: false);
      final onChart = await travel(fromTarget: true);

      expect(
        outside,
        closeTo(swipe.distance - passingThreshold * step + eased, 1e-9),
      );
      expect(
        onChart,
        closeTo(swipe.distance - passingSlop * step + eased, 1e-9),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final (name, roundChart) in _roundCharts) {
    group('a $name chart in a vertical list (HB4 route order)', () {
      late core.PieRadarChartBase chart;
      Widget target({bool decelerate = true}) => roundChart((it) {
        chart = it;
        it.isDragDecelerationEnabled = decelerate;
      });
      // At 3 o'clock, on a pie's ring or a radar's web, a swipe up is the tangent of the rotation: the straight drag
      // along the list that turns the chart most.
      Offset Function() atThreeOClock(WidgetTester tester) =>
          () => _onTheChart(tester, chart, 0);

      void expectNotRotated() {
        expect(chart.rotationAngle, closeTo(270, 1e-9));
        expect(
          chart.chartTouchListener.touchMode,
          core.ChartTouchListener.NONE,
        );
        expect(chart.chartTouchListener.lastGesture, core.ChartGesture.NONE);
      }

      for (final (physical, millis) in [(150.0, 400), (400.0, 300)]) {
        testWidgets(
          'with an 8 dp list slop a straight ${physical.toInt()} px swipe in $millis ms on the $name scrolls the list '
          'as one from outside it, and the $name does not turn',
          (tester) async {
            final outside = await _swipe(
              tester,
              target: target(),
              axis: Axis.vertical,
              dragStartBehavior: DragStartBehavior.down,
              fromTarget: false,
              swipe: _adbSwipe(physical, millis),
            );
            final onChart = await _swipe(
              tester,
              target: target(),
              axis: Axis.vertical,
              dragStartBehavior: DragStartBehavior.down,
              fromTarget: true,
              swipe: _adbSwipe(physical, millis),
              startOnTarget: atThreeOClock(tester),
            );
            expect(onChart.afterUp, closeTo(outside.afterUp, 0.01));
            expect(onChart.settled, closeTo(outside.settled, 0.01));
            expect(onChart.endVelocity, closeTo(outside.endVelocity!, 0.01));
            expectNotRotated();
          },
        );
      }

      // Moves of 0.5 px: the 17th, at 8.5 px, is the first past both 8 px thresholds.
      const fine = (distance: 60.0, moves: 120, millis: 480);

      testWidgets(
        'with an 8 dp list slop a straight swipe in moves of 0.5 px on the $name still goes to the list',
        (tester) async {
          final r = await _swipe(
            tester,
            target: target(),
            axis: Axis.vertical,
            dragStartBehavior: DragStartBehavior.down,
            fromTarget: true,
            swipe: fine,
            startOnTarget: atThreeOClock(tester),
          );
          expect(r.afterUp, closeTo(fine.distance, 0.01));
          expectNotRotated();
        },
      );

      testWidgets(
        'with the default kTouchSlop the same swipe on the $name rotates it, and the list stays where it is',
        (tester) async {
          final r = await _swipe(
            tester,
            target: target(decelerate: false),
            axis: Axis.vertical,
            dragStartBehavior: DragStartBehavior.down,
            fromTarget: true,
            swipe: fine,
            startOnTarget: atThreeOClock(tester),
            platformDefaults: true,
          );
          expect(r.afterUp, 0);
          expect(r.settled, 0);
          expect(
            chart.chartTouchListener.lastGesture,
            core.ChartGesture.ROTATE,
          );
          // A swipe up at 3 o'clock turns the chart counterclockwise, to a smaller angle.
          expect(chart.rotationAngle, lessThan(269));
        },
      );

      testWidgets(
        'with an 8 dp list slop a drag across the list on the $name rotates it, and the list stays where it is',
        (tester) async {
          // From 12 o'clock to the right: the tangent of the rotation there, and no travel along the list.
          final r = await _swipe(
            tester,
            target: target(decelerate: false),
            axis: Axis.vertical,
            dragStartBehavior: DragStartBehavior.down,
            fromTarget: true,
            swipe: fine,
            startOnTarget: () => _onTheChart(tester, chart, 270),
            direction: const Offset(1, 0),
          );
          expect(r.afterUp, 0);
          expect(r.settled, 0);
          expect(
            chart.chartTouchListener.lastGesture,
            core.ChartGesture.ROTATE,
          );
          expect(chart.rotationAngle, greaterThan(275));
        },
      );
    });
  }
}
