// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/BarLineScatterCandleBubbleData.kt
import '../interfaces/datasets/i_bar_line_scatter_candle_bubble_data_set.dart';
import 'chart_data.dart';

/// Base for the data objects of the charts with an x and a y axis (bar, line, scatter, candle, bubble and
/// combined). Adds nothing to [ChartData] beyond the set type; it lets a combined chart treat them alike.
///
/// [T] is the data set type this object holds.
abstract class BarLineScatterCandleBubbleData<
  T extends IBarLineScatterCandleBubbleDataSet
>
    extends ChartData<T> {
  /// Creates a data object holding [sets] (kept by reference), or an empty one (Kotlin's `()`, `(vararg sets)` and
  /// `(sets: List)` constructors).
  BarLineScatterCandleBubbleData([super.dataSets]);
}
