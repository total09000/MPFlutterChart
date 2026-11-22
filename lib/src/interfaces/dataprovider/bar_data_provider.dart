// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/dataprovider/BarDataProvider.kt
import '../../data/bar_data.dart';
import 'bar_line_scatter_candle_bubble_data_provider.dart';

/// What the bar chart renderer and highlighter read from a chart that shows bars.
/// Implemented by `BarChart` and the combined chart.
abstract class BarDataProvider extends BarLineScatterCandleBubbleDataProvider {
  /// The bar data of the chart, null when there is none.
  BarData? get barData;

  /// True to draw a shadow bar behind each bar that spans the full axis height.
  bool get isDrawBarShadowEnabled;

  /// True to draw value labels above bars, false to draw them inside near the top.
  bool get isDrawValueAboveBarEnabled;

  /// True to highlight the whole stacked bar instead of only the touched stack value.
  bool get isHighlightFullBarEnabled;
}
