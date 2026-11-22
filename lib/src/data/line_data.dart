// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/LineData.kt
import '../interfaces/datasets/i_line_data_set.dart';
import 'bar_line_scatter_candle_bubble_data.dart';

/// Data for a line chart: one or more [ILineDataSet]s, one per line.
class LineData extends BarLineScatterCandleBubbleData<ILineDataSet> {
  /// Creates a data object holding [dataSets] (kept by reference), or an empty one (Kotlin's `()`,
  /// `(vararg dataSets)` and `(dataSets: List)` constructors).
  LineData([super.dataSets]);
}
