// Not a port of a Kotlin test: MPChartExample has no tests. Checks that the PieChart and RadarChart example pages
// build with their chart; that Spin runs to its end without errors and does nothing on the half pie; that the Half pie
// switch turns the pie into a half pie at 180 degrees, also while a fling decelerates, and back into the donut; that
// Values outside moves the values out of the slices and back; that the status lines follow the rotation; and that the
// radar's Animate runs to its end.
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/pages/pie_chart_page.dart';
import 'package:mp_flutter_chart_example/pages/radar_chart_page.dart';

/// The core chart the page's PieChart widget shows.
PieChartView _pieChart(WidgetTester tester) => tester
    .widget<ChartHostWidget<PieChartView, PieData>>(
      find.byType(ChartHostWidget<PieChartView, PieData>),
    )
    .chart;

/// The core chart the page's RadarChart widget shows.
RadarChartView _radarChart(WidgetTester tester) => tester
    .widget<ChartHostWidget<RadarChartView, RadarData>>(
      find.byType(ChartHostWidget<RadarChartView, RadarData>),
    )
    .chart;

/// The text of the page's status line, the only text that starts with "rotation ".
String _status(WidgetTester tester) =>
    tester.widget<Text>(find.textContaining(RegExp('^rotation '))).data!;

/// Scrolls [label] into view and taps it.
Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await tester.pump();
}

/// Drags the pie's ring from 3 o'clock clockwise through about 60 degrees, in moves of about 4 px, and lifts the
/// finger. At the test's touch slop, Flutter's default kTouchSlop of 18 px (as on iOS), the rotation claims the gesture
/// 8 dp from the down, before the list's slop. With an 8 dp list slop (Android, HarmonyOS) a straight
/// swipe along the list goes to the list however small its moves, and only a drag with a component across the list
/// rotates the pie. The root test's test/support/pie_radar_gestures.dart is not visible from the example
/// package, so this is its own small copy of moveAround.
Future<void> _dragRing(WidgetTester tester, PieChartView chart) async {
  final topLeft = tester.getTopLeft(find.byType(ChartRenderBoxWidget));
  // Outside the page's hole of 58 percent of the radius.
  final distance = chart.radius * 0.8;
  Offset at(double angle) {
    final p = chart.getPosition(chart.centerOffsets, distance, angle);
    return topLeft + Offset(p.x, p.y);
  }

  final gesture = await tester.startGesture(at(0));
  final steps = (distance * 60 * math.pi / 180 / 4).ceil();
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(at(60.0 * i / steps));
  }
  await gesture.up();
}

void main() {
  testWidgets('the pie page shows a PieChart', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PieChartPage()));
    await tester.pump();

    expect(find.byType(PieChart), findsOneWidget);
    for (final label in ['Spin', 'Half pie', 'Values outside']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('Spin runs to its end without errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PieChartPage()));
    await tester.pump();

    await _tap(tester, 'Spin');
    expect(_pieChart(tester).isAnimating, isTrue);

    await tester.pumpAndSettle();
    expect(_pieChart(tester).isAnimating, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Half pie makes the pie span 180 degrees', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PieChartPage()));
    await tester.pump();
    expect(_pieChart(tester).maxAngle, closeTo(360, 1e-4));

    await _tap(tester, 'Half pie');
    await tester.pumpAndSettle();

    final chart = _pieChart(tester);
    expect(chart.maxAngle, closeTo(180, 1e-4));
    expect(chart.rotationAngle, closeTo(180, 1e-4));
    expect(chart.isRotationEnabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Half pie off restores the donut', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PieChartPage()));
    await tester.pump();

    await _tap(tester, 'Half pie');
    await tester.pumpAndSettle();
    await _tap(tester, 'Half pie');
    await tester.pumpAndSettle();

    final chart = _pieChart(tester);
    expect(chart.maxAngle, closeTo(360, 1e-4));
    expect(chart.absoluteAngles.last, closeTo(360, 1e-3));
    expect(chart.rotationAngle, closeTo(270, 1e-4));
    expect(chart.isRotationEnabled, isTrue);
    final offset = chart.centerTextOffset;
    expect(offset.x, 0);
    expect(offset.y, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spin does nothing on the half pie', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PieChartPage()));
    await tester.pump();
    await _tap(tester, 'Half pie');
    await tester.pumpAndSettle();
    final chart = _pieChart(tester);

    await _tap(tester, 'Spin');
    expect(chart.isAnimating, isFalse);
    // Halfway through a spin the pie would be turned half a circle away from its 9 to 3 o'clock arc.
    await tester.pump(const Duration(milliseconds: 600));
    expect(chart.rotationAngle, closeTo(180, 1e-4));
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);
    expect(chart.rotationAngle, closeTo(180, 1e-4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('A fling stops when Half pie is switched on', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PieChartPage()));
    await tester.pump();
    final chart = _pieChart(tester);
    // The test binding's fake clock, which stands still during the moves: the fling velocity is the swept angle over
    // the listener's 0.1 s fallback, and the deceleration advances with the pumps.
    (chart.chartTouchListener as PieRadarChartTouchListener).clock = () =>
        tester.binding.clock.now().millisecondsSinceEpoch;
    await tester.ensureVisible(find.byType(PieChart));
    await tester.pump();

    await _dragRing(tester, chart);
    await tester.pump(const Duration(milliseconds: 16));
    final turning = chart.rotationAngle;
    await tester.pump(const Duration(milliseconds: 16));
    expect(chart.rotationAngle, isNot(closeTo(turning, 1e-3)));

    await _tap(tester, 'Half pie');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(chart.maxAngle, closeTo(180, 1e-4));
    expect(chart.rotationAngle, closeTo(180, 1e-4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Values outside moves the values out of the slices and back', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PieChartPage()));
    await tester.pump();
    final chart = _pieChart(tester);
    final set = chart.data!.dataSet! as PieDataSet;
    expect(set.xValuePosition, ValuePosition.INSIDE_SLICE);
    expect(set.yValuePosition, ValuePosition.INSIDE_SLICE);

    await _tap(tester, 'Values outside');
    await tester.pumpAndSettle();
    expect(set.xValuePosition, ValuePosition.OUTSIDE_SLICE);
    expect(set.yValuePosition, ValuePosition.OUTSIDE_SLICE);
    expect(
      [
        chart.extraLeftOffset,
        chart.extraTopOffset,
        chart.extraRightOffset,
        chart.extraBottomOffset,
      ],
      [40, 16, 40, 16],
    );

    await _tap(tester, 'Values outside');
    await tester.pumpAndSettle();
    expect(set.xValuePosition, ValuePosition.INSIDE_SLICE);
    expect(set.yValuePosition, ValuePosition.INSIDE_SLICE);
    expect(
      [
        chart.extraLeftOffset,
        chart.extraTopOffset,
        chart.extraRightOffset,
        chart.extraBottomOffset,
      ],
      [0, 0, 0, 0],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pie status line follows the rotation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PieChartPage()));
    await tester.pump();
    expect(_status(tester), 'rotation 270° · tap a slice');

    // The chart reports the angle while it paints; the status line shows it on the frame after.
    await _tap(tester, 'Spin');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    final mid = _pieChart(tester).rotationAngle.round() % 360;
    expect(mid, isNot(270));
    expect(_status(tester), 'rotation $mid° · tap a slice');

    // A full turn ends where it started, in whole degrees.
    await tester.pumpAndSettle();
    expect(_status(tester), 'rotation 270° · tap a slice');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the radar page shows a RadarChart and animates', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RadarChartPage()));
    await tester.pump();

    expect(find.byType(RadarChart), findsOneWidget);
    final chart = _radarChart(tester);
    expect(chart.isAnimating, isFalse);

    await _tap(tester, 'Animate');
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the radar status line follows the rotation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RadarChartPage()));
    await tester.pump();
    expect(_status(tester), 'rotation 270° · tap a point');

    final chart = _radarChart(tester);
    chart.rotationAngle = 123.4;
    chart.invalidate();
    await tester.pump();
    await tester.pump();
    expect(_status(tester), 'rotation 123° · tap a point');

    await _tap(tester, 'Animate');
    await tester.pumpAndSettle();
    expect(_status(tester), 'rotation 123° · tap a point');
    expect(tester.takeException(), isNull);
  });
}
