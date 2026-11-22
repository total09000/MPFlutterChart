// Ported from MPChartExample: ListViewMultiChartActivity.kt, with res/layout/activity_listview_chart.xml and
// res/menu/only_github.xml.
//
// Scrolling Charts / Multiple: a list of 30 rows, a line, a bar and a pie chart in turn, each with its own random
// data. The items (listviewitems/) are built once in initState, as onCreate builds its list, and each item keeps its
// data, so a row that scrolls away and back shows the same numbers. A row is the chart widget the item's `getView`
// returns (`LineChart`, `BarChart`, `PieChart`), which owns its chart as the ViewHolder does and configures and
// animates it whenever the row is built.
//
// Not ported: the "View on GitHub" menu item (see notimportant/demo_base.dart), the only item of only_github.xml, so
// the page has no options menu; the spans of the pie rows' center text (see listviewitems/pie_chart_item.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/nightfall.dart';
import '../listviewitems/bar_chart_item.dart';
import '../listviewitems/chart_item.dart';
import '../listviewitems/line_chart_item.dart';
import '../listviewitems/pie_chart_item.dart';
import '../notimportant/demo_base.dart';

/// ListViewMultiChartActivity.
class ListViewMultiChartPage extends StatefulWidget {
  const ListViewMultiChartPage({super.key});

  @override
  State<ListViewMultiChartPage> createState() => _ListViewMultiChartPageState();
}

class _ListViewMultiChartPageState extends State<ListViewMultiChartPage> with DemoBase {
  /// The adapter's items.
  late final List<ChartItem> _list;

  @override
  void initState() {
    super.initState();

    final list = <ChartItem>[];
    for (var i = 0; i < 30; i++) {
      switch (i % 3) {
        case 0:
          list.add(LineChartItem(_generateDataLine(i + 1)));
        case 1:
          list.add(BarChartItem(_generateDataBar(i + 1)));
        case 2:
          list.add(PieChartItem(_generateDataPie()));
      }
    }
    _list = list;
  }

  LineData _generateDataLine(int cnt) {
    final values1 = <Entry>[];
    for (var i = 0; i < 12; i++) {
      values1.add(Entry(x: i.toDouble(), y: ((mathRandom() * 65).toInt() + 40).toDouble()));
    }

    final d1 = LineDataSet(values1, 'New DataSet $cnt, (1)')
      ..lineWidth = 2.5
      ..circleRadius = 4.5
      ..highlightColor = const Color.fromARGB(255, 244, 117, 117)
      ..isDrawValuesEnabled = false;

    final values2 = <Entry>[];
    for (var i = 0; i < 12; i++) {
      values2.add(Entry(x: i.toDouble(), y: values1[i].y - 30));
    }

    final d2 = LineDataSet(values2, 'New DataSet $cnt, (2)')
      ..lineWidth = 2.5
      ..circleRadius = 4.5
      ..highlightColor = const Color.fromARGB(255, 244, 117, 117)
      ..color = ColorTemplate.VORDIPLOM_COLORS[0]
      ..circleColor = ColorTemplate.VORDIPLOM_COLORS[0]
      ..isDrawValuesEnabled = false;

    final sets = <ILineDataSet>[d1, d2];

    return LineData(sets);
  }

  BarData _generateDataBar(int cnt) {
    final entries = <BarEntry>[];
    for (var i = 0; i < 12; i++) {
      entries.add(BarEntry(x: i.toDouble(), y: ((mathRandom() * 70).toInt() + 30).toDouble()));
    }

    final d = BarDataSet(entries, 'New DataSet $cnt')
      ..colors = ColorTemplate.VORDIPLOM_COLORS.toList()
      ..highlightAlpha = 255;

    return BarData([d])..barWidth = 0.9;
  }

  PieData _generateDataPie() {
    final entries = <PieEntry>[];
    for (var i = 0; i < 4; i++) {
      entries.add(PieEntry(mathRandom() * 70 + 30, label: 'Quarter ${i + 1}'));
    }

    final d = PieDataSet(entries, '')
      ..sliceSpace = 2
      ..colors = ColorTemplate.VORDIPLOM_COLORS.toList();

    return PieData(d);
  }

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Multiple',
    body: ListView.builder(
      dragStartBehavior: chartScrollDragStartBehavior,
      itemCount: _list.length,
      // ChartDataAdapter.getView.
      itemBuilder: (context, position) =>
          KeyedSubtree(key: ValueKey(position), child: _list[position].getView(position, context)),
    ),
  );
}
