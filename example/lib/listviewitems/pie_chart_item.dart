// Ported from MPChartExample: listviewitems/PieChartItem.kt, with res/layout/list_item_piechart.xml.
//
// A row with a pie chart 345dp high. The row is the `PieChart` widget, which owns its chart as the ViewHolder does;
// its `setup` is the body of Kotlin's `getView`, so the chart is configured and animated whenever the row is built, as
// a recycled view is in Kotlin.
//
// Not ported: the spans of the center text (the relative sizes 1.6, 0.9 and 1.4 and the colours VORDIPLOM_COLORS[0],
// grey and holo blue of its three lines), because `PieChart.centerText` is a plain String; the text is drawn in the
// chart's center text colour and size.
import 'package:flutter/widgets.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';
import 'chart_item.dart';

/// PieChartItem.
class PieChartItem extends ChartItem {
  PieChartItem(super.chartData);

  /// `Typeface.createFromAsset(context.assets, "OpenSans-Regular.ttf")`.
  final Typeface _tf = tfRegular;

  final String _centerText = _generateCenterText();

  @override
  int get itemType => ChartItem.typePieChart;

  @override
  Widget getView(int position, BuildContext context) => SizedBox(
    height: 345,
    child: PieChart(
      data: chartData as PieData,
      setup: (chart) {
        chart
          ..description.isEnabled = false
          ..holeRadius = 52
          ..transparentCircleRadius = 57
          ..centerText = _centerText
          ..centerTextTypeface = _tf
          ..centerTextSize = 9
          ..isUsePercentValuesEnabled = true
          ..setExtraOffsets(5, 10, 50, 10);

        chartData
          ..setValueFormatter(PercentFormatter())
          ..setValueTypeface(_tf)
          ..setValueTextSize(11)
          ..setValueTextColor(const Color(0xFFFFFFFF));

        chart.legend
          ..verticalAlignment = LegendVerticalAlignment.TOP
          ..horizontalAlignment = LegendHorizontalAlignment.RIGHT
          ..orientation = LegendOrientation.VERTICAL
          ..isDrawInsideEnabled = false
          ..yEntrySpace = 0
          ..yOffset = 0;

        chart.animateY(900);
      },
    ),
  );

  /// `generateCenterText()`: the text of Kotlin's SpannableString, without its spans.
  static String _generateCenterText() => 'MPAndroidChart\ncreated by\nPhilipp Jahoda';
}
