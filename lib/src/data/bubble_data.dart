// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/BubbleData.kt
import '../interfaces/datasets/i_bubble_data_set.dart';
import 'bar_line_scatter_candle_bubble_data.dart';

/// Data for a bubble chart: one or more [IBubbleDataSet]s.
class BubbleData extends BarLineScatterCandleBubbleData<IBubbleDataSet> {
  /// Creates a data object holding [dataSets] (kept by reference), or an empty one (Kotlin's `()`,
  /// `(vararg dataSets)` and `(dataSets: List)` constructors).
  BubbleData([super.dataSets]);

  /// Sets the stroke width in dp of the highlight circle for every set.
  void setHighlightCircleWidth(double width) {
    for (final set in dataSets) {
      set.highlightCircleWidth = width;
    }
  }
}
