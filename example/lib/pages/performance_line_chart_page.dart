// Ported from MPChartExample: PerformanceLineChart.kt, with res/layout/activity_performance_linechart.xml and
// res/menu/only_github.xml.
//
// Line Charts / Performance: one thin black data set of 1,000 to 30,000 values, without circles, values or legend,
// with a seek bar for the number of values. Every change of the seek bar sets new data. Not ported: the "View on
// GitHub" menu item (see notimportant/demo_base.dart), which leaves the page without a menu.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// PerformanceLineChart.
class PerformanceLineChartPage extends StatefulWidget {
  const PerformanceLineChartPage({super.key});

  @override
  State<PerformanceLineChartPage> createState() => _PerformanceLineChartPageState();
}

class _PerformanceLineChartPageState extends State<PerformanceLineChartPage> with DemoBase {
  /// `binding.chart1`.
  final LineChartView _chart = LineChartView();

  /// `binding.seekbarValues.progress`.
  int _seekbarValues = 9000;

  @override
  void initState() {
    super.initState();

    _chart
      ..isDrawGridBackgroundEnabled = false
      ..description.isEnabled = false
      ..isTouchEnabled = true
      ..isDragEnabled = true
      ..isScaleEnabled = true
      ..isPinchZoomEnabled = false
      ..axisLeft.isDrawGridLinesEnabled = false
      ..axisRight.isEnabled = false
      ..xAxis.isDrawGridLinesEnabled = true
      ..xAxis.isDrawAxisLineEnabled = false;

    // Setting the progress of the seek bar calls onProgressChanged, which sets the data.
    _onProgressChanged();

    _chart.invalidate();
  }

  /// The value count of the seek bar's progress, which `tvValueCount` shows.
  int get _count => _seekbarValues + 1000;

  /// `onProgressChanged`: new random data with the seek bar's value count.
  void _onProgressChanged() {
    _chart.resetTracking();

    _setData(_count, 500);

    _chart.invalidate();
  }

  /// `setData(count, range)`.
  void _setData(int count, double range) {
    final values = <Entry>[];

    for (var i = 0; i < count; i++) {
      final value = mathRandom() * (range + 1) + 3;
      values.add(Entry(x: i * 0.001, y: value));
    }

    final set1 = LineDataSet(values, 'DataSet 1')
      ..color = const Color(0xFF000000)
      ..lineWidth = 0.5
      ..isDrawValuesEnabled = false
      ..isDrawCirclesEnabled = false
      ..mode = LineDataSetMode.LINEAR
      ..isDrawFilledEnabled = false;

    _chart.data = LineData([set1]);

    _chart.legend.isEnabled = false;
  }

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Performance',
    body: Column(
      children: [
        Expanded(child: ChartHostWidget<LineChartView, LineData>(chart: _chart, data: _chart.data)),
        // tvValueCount is 60dp wide, so that five digits fit.
        DemoSeekBar(
          progress: _seekbarValues,
          max: 29000,
          text: '$_count',
          textWidth: 60,
          onProgressChanged: (progress) => setState(() {
            _seekbarValues = progress;
            _onProgressChanged();
          }),
        ),
      ],
    ),
  );
}
