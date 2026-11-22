// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/BarRendererTest.kt
//
// Kotlin's FakeBarChart is FakeBarChart from support/fake_providers.dart with the values of the Kotlin fake; as there,
// its transformers are unprepared and its content rectangle is the single point (0, 0). Kotlin draws on a JVM stub
// canvas; the port draws on a StrictCanvas, which also fails on NaN geometry.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/animation/chart_animator.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/renderer/bar_chart_renderer.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

import 'support/fake_providers.dart';
import 'support/strict_canvas.dart';

FakeBarChart _fakeBarChart(BarData barData) =>
    FakeBarChart(barData, maxHighlightDistance: 0);

BarData _barData(int sets, int entries) => BarData([
  for (var s = 0; s < sets; s++)
    BarDataSet([
      for (var i = 0; i < entries; i++)
        BarEntry(x: i.toDouble(), y: i.toDouble()),
    ], 'set $s'),
]);

void main() {
  test('drawingSurvivesDataChangedWithoutNotifying', () {
    final chart = _fakeBarChart(_barData(2, 5));
    final renderer = BarChartRenderer(
      chart,
      ChartAnimator(),
      ViewPortHandler(),
    );
    renderer.initBuffers();

    final canvas = StrictCanvas();
    renderer.drawData(canvas);

    chart.barData = _barData(1, 9);
    renderer.drawData(canvas);
    renderer.drawValues(canvas);
  });
}
