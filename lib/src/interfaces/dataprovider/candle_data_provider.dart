// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/dataprovider/CandleDataProvider.kt
import '../../data/candle_data.dart';
import 'bar_line_scatter_candle_bubble_data_provider.dart';

/// What the candle stick renderer reads from a chart that shows candles.
/// Implemented by `CandleStickChart` and the combined chart.
abstract class CandleDataProvider
    extends BarLineScatterCandleBubbleDataProvider {
  /// The candle data of the chart, null when there is none.
  CandleData? get candleData;
}
