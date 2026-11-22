// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/dataprovider/ScatterDataProvider.kt
import '../../data/scatter_data.dart';
import 'bar_line_scatter_candle_bubble_data_provider.dart';

/// What the scatter chart renderer reads from a chart that shows scatter shapes.
/// Implemented by `ScatterChart` and the combined chart.
abstract class ScatterDataProvider
    extends BarLineScatterCandleBubbleDataProvider {
  /// The scatter data of the chart, null when there is none.
  ScatterData? get scatterData;
}
