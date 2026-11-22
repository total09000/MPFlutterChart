// Ported from MPChartExample: listviewitems/LineChartItem.kt, with res/layout/list_item_linechart.xml.
//
// A row with a line chart 200dp high. The row is the `LineChart` widget, which owns its chart as the ViewHolder
// does; its `setup` is the body of Kotlin's `getView`, so the chart is configured and animated whenever the row is
// built, as a recycled view is in Kotlin.
import 'package:flutter/widgets.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';
import 'chart_item.dart';

/// LineChartItem.
class LineChartItem extends ChartItem {
  LineChartItem(super.chartData);

  /// `Typeface.createFromAsset(context.assets, "OpenSans-Regular.ttf")`.
  final Typeface _tf = tfRegular;

  @override
  int get itemType => ChartItem.typeLineChart;

  @override
  Widget getView(int position, BuildContext context) => SizedBox(
    height: 200,
    child: LineChart(
      data: chartData as LineData,
      setup: (chart) {
        chart
          ..description.isEnabled = false
          ..isDrawGridBackgroundEnabled = false;

        chart.xAxis
          ..position = XAxisPosition.BOTTOM
          ..typeface = _tf
          ..isDrawGridLinesEnabled = false
          ..isDrawAxisLineEnabled = true;

        chart.axisLeft
          ..typeface = _tf
          ..labelCount = 5
          ..axisMinimum = 0;

        chart.axisRight
          ..typeface = _tf
          ..labelCount = 5
          ..isDrawGridLinesEnabled = false
          ..axisMinimum = 0;

        chart.animateX(750);
      },
    ),
  );
}
