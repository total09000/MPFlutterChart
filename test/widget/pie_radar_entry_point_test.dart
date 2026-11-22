// Not a port of a Kotlin test: MPChartCompose v4.0.1 has no test for its entry points. Checks that the default entry
// point has the PieChart and RadarChart widgets and names their core charts PieChartView and RadarChartView, while
// core.dart has the chart classes under the MPChartLib names, as line_chart_widget_test.dart does for
// LineChart.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/core.dart' as core;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

void main() {
  test('the default entry point has the pie widget and PieChartView', () {
    final Widget widget = PieChart(
      data: PieData(PieDataSet([PieEntry(1), PieEntry(2)], 'a')),
    );
    expect(widget, isA<StatefulWidget>());

    final PieChartView view = core.PieChart();
    expect(view, isA<core.PieRadarChartBase>());
    expect(view, isA<PieRadarChartBase>());
    expect(PieChartView == core.PieChart, isTrue);
  });

  test('the default entry point has the radar widget and RadarChartView', () {
    final Widget widget = RadarChart(
      data: RadarData([
        RadarDataSet([RadarEntry(1), RadarEntry(2), RadarEntry(3)], 'a'),
      ]),
    );
    expect(widget, isA<StatefulWidget>());

    final RadarChartView view = core.RadarChart();
    expect(view, isA<core.PieRadarChartBase>());
    expect(view, isA<PieRadarChartBase>());
    expect(RadarChartView == core.RadarChart, isTrue);
  });
}
