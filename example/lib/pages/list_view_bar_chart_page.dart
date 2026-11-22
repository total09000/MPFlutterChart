// Ported from MPChartExample: ListViewBarChartActivity.kt, with res/layout/activity_listview_chart.xml,
// res/layout/list_item_barchart.xml and res/menu/only_github.xml.
//
// Scrolling Charts / Many Bar Charts: a list of 20 bar charts 200dp high, each with its own random data. The data is
// built once in initState, as onCreate builds the adapter's list, so a row that scrolls away and back shows the same
// numbers. A row is the `BarChart` widget, which owns its chart as the ViewHolder does; its `setup` is the body of
// the adapter's `getView`, so the chart is configured and animated whenever the row is built, as a recycled view is
// in Kotlin. `setup` runs before the widget sets the data, so `isFitBarsEnabled` is set before the data instead of
// after it; the data's min and max are computed with it either way.
//
// Not ported: the "View on GitHub" menu item (see notimportant/demo_base.dart), the only item of only_github.xml, so
// the page has no options menu.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/nightfall.dart';
import '../notimportant/demo_base.dart';

/// ListViewBarChartActivity.
class ListViewBarChartPage extends StatefulWidget {
  const ListViewBarChartPage({super.key});

  @override
  State<ListViewBarChartPage> createState() => _ListViewBarChartPageState();
}

class _ListViewBarChartPageState extends State<ListViewBarChartPage> with DemoBase {
  /// The adapter's items.
  late final List<BarData> _list = [for (var i = 0; i < 20; i++) _generateData(i + 1)];

  BarData _generateData(int cnt) {
    final entries = <BarEntry>[];
    for (var i = 0; i < 12; i++) {
      entries.add(BarEntry(x: i.toDouble(), y: mathRandom() * 70 + 30));
    }

    final d = BarDataSet(entries, 'New DataSet $cnt')
      ..colors = ColorTemplate.VORDIPLOM_COLORS.toList()
      ..barShadowColor = const Color.fromARGB(255, 203, 203, 203);

    final sets = <IBarDataSet>[d];

    return BarData(sets)..barWidth = 0.9;
  }

  /// ChartDataAdapter.getView.
  Widget _getView(int position) {
    final data = _list[position];

    return SizedBox(
      key: ValueKey(position),
      height: 200,
      child: BarChart(
        data: data,
        setup: (chart) {
          data
            ..setValueTypeface(tfLight)
            ..setValueTextColor(const Color(0xFF000000));

          chart
            ..description.isEnabled = false
            ..isDrawGridBackgroundEnabled = false;

          chart.xAxis
            ..position = XAxisPosition.BOTTOM
            ..typeface = tfLight
            ..isDrawGridLinesEnabled = false;

          chart.axisLeft
            ..typeface = tfLight
            ..labelCount = 5
            ..spaceTop = 15;

          chart.axisRight
            ..typeface = tfLight
            ..labelCount = 5
            ..spaceTop = 15;

          chart.isFitBarsEnabled = true;

          chart.animateY(700);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Many Bar Charts',
    body: ListView.builder(
      dragStartBehavior: chartScrollDragStartBehavior,
      itemCount: _list.length,
      itemBuilder: (context, position) => _getView(position),
    ),
  );
}
