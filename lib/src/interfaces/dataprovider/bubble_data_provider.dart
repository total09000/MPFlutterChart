// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/dataprovider/BubbleDataProvider.kt
import '../../data/bubble_data.dart';
import 'bar_line_scatter_candle_bubble_data_provider.dart';

/// What the bubble chart renderer reads from a chart that shows bubbles.
/// Implemented by `BubbleChart` and the combined chart.
abstract class BubbleDataProvider
    extends BarLineScatterCandleBubbleDataProvider {
  /// The bubble data of the chart, null when there is none.
  BubbleData? get bubbleData;
}
