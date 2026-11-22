// Ported from MPChartExample: LineChartActivityColored.kt, with res/layout/activity_colored_lines.xml and
// res/menu/only_github.xml.
//
// Line Charts / Colorful: four charts of equal height, one above the other, each with one white data set of 36 values
// on a background of its own colour and without axes, legend or description. Not ported: the "View on GitHub" menu
// item (see notimportant/demo_base.dart), which leaves the page without a menu.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// LineChartActivityColored.
class LineChartColoredPage extends StatefulWidget {
  const LineChartColoredPage({super.key});

  @override
  State<LineChartColoredPage> createState() => _LineChartColoredPageState();
}

class _LineChartColoredPageState extends State<LineChartColoredPage> with DemoBase {
  /// `binding.chart1` to `binding.chart4`.
  final List<LineChartView> _charts = [LineChartView(), LineChartView(), LineChartView(), LineChartView()];

  /// `colors`.
  static const List<Color> _colors = [
    Color.fromARGB(255, 137, 230, 81),
    Color.fromARGB(255, 240, 240, 30),
    Color.fromARGB(255, 89, 199, 250),
    Color.fromARGB(255, 250, 104, 104),
  ];

  @override
  void initState() {
    super.initState();

    for (var i = 0; i < _charts.length; i++) {
      final data = _getData(36, 100)..setValueTypeface(tfBold);

      _setupChart(_charts[i], data, _colors[i % _colors.length]);
    }
  }

  /// `setupChart(chart, data, color)`; the background is the [ColoredBox] around the chart, its `animateX(2500)` the
  /// host's `setup`.
  void _setupChart(LineChartView chart, LineData data, Color color) {
    (data.getDataSetByIndex(0) as LineDataSet).circleHoleColor = color;

    chart
      ..description.isEnabled = false
      ..isDrawGridBackgroundEnabled = false
      ..isTouchEnabled = true
      ..isDragEnabled = true
      ..isScaleEnabled = true
      ..isPinchZoomEnabled = false
      ..setViewPortOffsets(10, 0, 10, 0)
      ..data = data
      ..legend.isEnabled = false
      ..axisLeft.isEnabled = false
      ..axisLeft.spaceTop = 40
      ..axisLeft.spaceBottom = 40
      ..axisRight.isEnabled = false
      ..xAxis.isEnabled = false;
  }

  /// `getData(count, range)`.
  LineData _getData(int count, double range) {
    final values = <Entry>[];

    for (var i = 0; i < count; i++) {
      final value = mathRandom() * range + 3;
      values.add(Entry(x: i.toDouble(), y: value));
    }

    final set1 = LineDataSet(values, 'DataSet 1')
      ..lineWidth = 1.75
      ..circleRadius = 5
      ..circleHoleRadius = 2.5
      ..color = const Color(0xFFFFFFFF)
      ..circleColor = const Color(0xFFFFFFFF)
      ..highlightColor = const Color(0xFFFFFFFF)
      ..isDrawValuesEnabled = false;

    return LineData([set1]);
  }

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Colorful',
    body: Column(
      children: [
        for (var i = 0; i < _charts.length; i++)
          Expanded(
            child: ColoredBox(
              color: _colors[i % _colors.length],
              child: ChartHostWidget<LineChartView, LineData>(
                chart: _charts[i],
                data: _charts[i].data,
                setup: (chart) => chart.animateX(2500),
              ),
            ),
          ),
      ],
    ),
  );
}
