// Ported from MPChartExample: listviewitems/ChartItem.kt.
//
// The base class of the rows of the Scrolling Charts / Multiple list: an item holds its chart data and builds the
// row that shows it. Kotlin's `getView(position, convertView, context)` fills a recycled view; a lazy ListView row is
// a new widget whenever it scrolls into view, so `getView` returns that widget and there is no `convertView`. The data
// stays in the item, which the page builds once, so a row that comes back shows the same data.
import 'package:flutter/widgets.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

/// ChartItem: the data of one row and the row that shows it.
abstract class ChartItem {
  ChartItem(this.chartData);

  /// The data the row's chart shows.
  final ChartData chartData;

  /// One of [typeBarChart], [typeLineChart], [typePieChart].
  int get itemType;

  /// The row at [position] of the list.
  Widget getView(int position, BuildContext context);

  /// `TYPE_BARCHART`.
  static const int typeBarChart = 0;

  /// `TYPE_LINECHART`.
  static const int typeLineChart = 1;

  /// `TYPE_PIECHART`.
  static const int typePieChart = 2;
}
