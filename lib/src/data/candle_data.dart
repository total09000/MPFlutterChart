// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/CandleData.kt
import '../interfaces/datasets/i_candle_data_set.dart';
import 'bar_line_scatter_candle_bubble_data.dart';

/// Data for a candle stick chart: one or more [ICandleDataSet]s.
class CandleData extends BarLineScatterCandleBubbleData<ICandleDataSet> {
  /// Creates a data object holding [dataSets] (kept by reference), or an empty one (Kotlin's `()`,
  /// `(vararg dataSets)` and `(dataSets: List)` constructors).
  CandleData([super.dataSets]);
}
