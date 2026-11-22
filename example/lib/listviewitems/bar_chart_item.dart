// Ported from MPChartExample: listviewitems/BarChartItem.kt, with res/layout/list_item_barchart.xml.
//
// A row with a bar chart 200dp high. The row is the `BarChart` widget, which owns its chart as the ViewHolder does;
// its `setup` is the body of Kotlin's `getView`, so the chart is configured and animated whenever the row is built, as
// a recycled view is in Kotlin. `setup` runs before the widget sets the data, so `isFitBarsEnabled` is set before
// the data instead of after it; the data's min and max are computed with it either way.
import 'package:flutter/widgets.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';
import 'chart_item.dart';

/// BarChartItem.
class BarChartItem extends ChartItem {
  BarChartItem(super.chartData);

  /// `Typeface.createFromAsset(context.assets, "OpenSans-Regular.ttf")`.
  final Typeface _tf = tfRegular;

  @override
  int get itemType => ChartItem.typeBarChart;

  @override
  Widget getView(int position, BuildContext context) => SizedBox(
    height: 200,
    child: BarChart(
      data: chartData as BarData,
      setup: (chart) {
        chart
          ..description.isEnabled = false
          ..isDrawGridBackgroundEnabled = false
          ..isDrawBarShadowEnabled = false;

        chart.xAxis
          ..position = XAxisPosition.BOTTOM
          ..typeface = _tf
          ..isDrawGridLinesEnabled = false
          ..isDrawAxisLineEnabled = true;

        chart.axisLeft
          ..typeface = _tf
          ..labelCount = 5
          ..spaceTop = 20
          ..axisMinimum = 0;

        chart.axisRight
          ..typeface = _tf
          ..labelCount = 5
          ..spaceTop = 20
          ..axisMinimum = 0;

        chartData.setValueTypeface(_tf);
        chart.isFitBarsEnabled = true;

        chart.animateY(700);
      },
    ),
  );
}
