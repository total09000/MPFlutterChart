// Ported from MPChartExample: DynamicalAddingActivity.kt, with res/layout/activity_linechart_noseekbar.xml and
// res/menu/dynamical.xml.
//
// Line Charts / Dynamic: a line chart that starts empty and gets its entries and data sets from the menu, one at a
// time; the view keeps the last six x values in sight. The toasts keep the Kotlin texts, "Entry<*> added!" and
// "Entry<*> removed!" included. Not ported: the "View on GitHub" and "Save to Gallery" menu items (see
// notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// DynamicalAddingActivity.
class DynamicalAddingPage extends StatefulWidget {
  const DynamicalAddingPage({super.key});

  @override
  State<DynamicalAddingPage> createState() => _DynamicalAddingPageState();
}

class _DynamicalAddingPageState extends State<DynamicalAddingPage> with DemoBase {
  /// `binding.chart1`.
  final LineChartView _chart = LineChartView();

  static const List<Color> _colors = ColorTemplate.VORDIPLOM_COLORS;

  @override
  void initState() {
    super.initState();

    _chart
      ..onChartValueSelectedListener = OnChartValueSelectedListener.fromFunction(
        onValueSelected: (e, h) => toast(e.toString()),
        onNothingSelected: () {},
      )
      ..isDrawGridBackgroundEnabled = false
      ..description.isEnabled = false
      ..noDataText = 'Use the menu to add entries and data sets'
      ..invalidate();
  }

  void _addEntry() {
    var data = _chart.data;
    if (data == null) {
      data = LineData();
      _chart.data = data;
    }

    if (data.getDataSetByIndex(0) == null) {
      data.addDataSet(_createSet());
    }

    final randomDataSetIndex = (mathRandom() * data.dataSetCount).toInt();
    final randomSet = data.getDataSetByIndex(randomDataSetIndex);
    if (randomSet == null) return;
    final value = mathRandom() * 50 + 50 * (randomDataSetIndex + 1);

    data.addEntry(Entry(x: randomSet.entryCount.toDouble(), y: value), randomDataSetIndex);

    _chart.notifyDataSetChanged();

    _chart.setVisibleXRangeMaximum(6);
    _chart.moveViewTo((data.entryCount - 7).toDouble(), 50, AxisDependency.LEFT);
  }

  void _removeLastEntry() {
    final data = _chart.data;
    if (data == null) return;
    final set = data.getDataSetByIndex(0);
    if (set == null) return;

    final e = set.getEntryForXValue((set.entryCount - 1).toDouble(), double.nan);

    data.removeEntry(e, 0);
    _chart.notifyDataSetChanged();
    _chart.invalidate();
  }

  void _addDataSet() {
    final data = _chart.data;

    if (data == null) {
      _chart.data = LineData();
      return;
    }

    final count = data.dataSetCount + 1;
    final amount = data.getDataSetByIndex(0)?.entryCount;
    if (amount == null) return;

    final values = <Entry>[];
    for (var i = 0; i < amount; i++) {
      values.add(Entry(x: i.toDouble(), y: mathRandom() * 50 + 50 * count));
    }

    final color = _colors[count % _colors.length];
    final set = LineDataSet(values, 'DataSet $count')
      ..lineWidth = 2.5
      ..circleRadius = 4.5
      ..color = color
      ..circleColor = color
      ..highlightColor = color
      ..valueTextSize = 10
      ..valueTextColor = color;

    data.addDataSet(set);
    _chart.notifyDataSetChanged();
    _chart.invalidate();
  }

  void _removeDataSet() {
    final data = _chart.data;
    if (data == null) return;

    data.removeDataSet(data.getDataSetByIndex(data.dataSetCount - 1));

    _chart.notifyDataSetChanged();
    _chart.invalidate();
  }

  LineDataSet _createSet() => LineDataSet(<Entry>[], 'DataSet 1')
    ..lineWidth = 2.5
    ..circleRadius = 4.5
    ..color = const Color.fromARGB(255, 240, 99, 99)
    ..circleColor = const Color.fromARGB(255, 240, 99, 99)
    ..highlightColor = const Color.fromARGB(255, 190, 190, 190)
    ..axisDependency = AxisDependency.LEFT
    ..valueTextSize = 10;

  /// Runs a menu action and rebuilds the page, so the host gets the chart's data when the action replaced it.
  void _act(VoidCallback action, String message) {
    setState(action);
    toast(message);
  }

  /// res/menu/dynamical.xml.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Add Entry', () => _act(_addEntry, 'Entry<*> added!')),
    DemoMenuItem('Remove Entry', () => _act(_removeLastEntry, 'Entry<*> removed!')),
    DemoMenuItem('Add Data Set', () => _act(_addDataSet, 'DataSet added!')),
    DemoMenuItem('Remove Data Set', () => _act(_removeDataSet, 'DataSet removed!')),
    DemoMenuItem('Clear chart', () => _act(_chart.clear, 'Chart cleared!')),
  ];

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Dynamic',
    menu: _menu,
    body: ChartHostWidget<LineChartView, LineData>(chart: _chart, data: _chart.data),
  );
}
