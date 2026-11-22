// Ported from MPChartExample: FilledLineActivity.kt, with res/layout/activity_linechart_noseekbar.xml and
// res/menu/only_github.xml.
//
// Line Charts / Filled: two yellow data sets of 100 values on a blue grid background, the lower one filled in white
// down to the bottom of the left axis, the upper one filled in white up to its top, so that only the band between them
// shows blue. Not ported: the "View on GitHub" menu item (see notimportant/demo_base.dart), which leaves the page
// without a menu.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// FilledLineActivity.
class FilledLinePage extends StatefulWidget {
  const FilledLinePage({super.key});

  @override
  State<FilledLinePage> createState() => _FilledLinePageState();
}

class _FilledLinePageState extends State<FilledLinePage> with DemoBase {
  /// `binding.chart1`.
  final LineChartView _chart = LineChartView();

  /// `lineSets`: the two sets, once `setData` created them.
  List<LineDataSet> _lineSets = const [];

  /// `fillColor`, `Color.argb(150, 51, 181, 229)`: the grid background.
  static const Color _fillColor = Color.fromARGB(150, 51, 181, 229);

  @override
  void initState() {
    super.initState();

    _chart
      ..gridBackgroundColor = _fillColor
      ..isDrawGridBackgroundEnabled = true
      ..isDrawBordersEnabled = true
      ..description.isEnabled = false
      ..isPinchZoomEnabled = false
      ..legend.isEnabled = false
      ..xAxis.isEnabled = false;

    _chart.axisLeft
      ..axisMaximum = 900
      ..axisMinimum = -250
      ..isDrawAxisLineEnabled = false
      ..isDrawZeroLineEnabled = false
      ..isDrawGridLinesEnabled = false;

    _chart.axisRight.isEnabled = false;

    _setData(100, 60);

    _chart.invalidate();
  }

  /// `setData(count, range)`.
  void _setData(int count, double range) {
    final values1 = <Entry>[];
    for (var i = 0; i < count; i++) {
      final value = mathRandom() * range + 50;
      values1.add(Entry(x: i.toDouble(), y: value));
    }

    final values2 = <Entry>[];
    for (var i = 0; i < count; i++) {
      final value = mathRandom() * range + 450;
      values2.add(Entry(x: i.toDouble(), y: value));
    }

    if (_lineSets.isNotEmpty) {
      _lineSets[0].entries = values1;
      _lineSets[1].entries = values2;
      _chart.notifyDataSetChanged();
    } else {
      final set1 = LineDataSet(values1, 'DataSet 1')
        ..axisDependency = AxisDependency.LEFT
        ..color = const Color.fromARGB(255, 255, 241, 46)
        ..isDrawCirclesEnabled = false
        ..lineWidth = 2
        ..circleRadius = 3
        ..fillAlpha = 255
        ..isDrawFilledEnabled = true
        ..fillColor = const Color(0xFFFFFFFF)
        ..highlightColor = const Color.fromARGB(255, 244, 117, 117)
        ..isDrawCircleHoleEnabled = false
        ..fillFormatter = IFillFormatter.fromFunction((_, _) => _chart.axisLeft.axisMinimum);

      final set2 = LineDataSet(values2, 'DataSet 2')
        ..axisDependency = AxisDependency.LEFT
        ..color = const Color.fromARGB(255, 255, 241, 46)
        ..isDrawCirclesEnabled = false
        ..lineWidth = 2
        ..circleRadius = 3
        ..fillAlpha = 255
        ..isDrawFilledEnabled = true
        ..fillColor = const Color(0xFFFFFFFF)
        ..isDrawCircleHoleEnabled = false
        ..highlightColor = const Color.fromARGB(255, 244, 117, 117)
        ..fillFormatter = IFillFormatter.fromFunction((_, _) => _chart.axisLeft.axisMaximum);

      final lineData = LineData(<ILineDataSet>[set1, set2])..setDrawValues(false);

      _lineSets = [set1, set2];
      _chart.data = lineData;
    }
  }

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Filled',
    body: ColoredBox(
      color: demoChartBackground,
      child: ChartHostWidget<LineChartView, LineData>(chart: _chart, data: _chart.data),
    ),
  );
}
