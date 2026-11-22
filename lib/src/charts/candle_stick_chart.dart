// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/charts/CandleStickChart.kt
import '../data/candle_data.dart';
import '../interfaces/dataprovider/candle_data_provider.dart';
import '../renderer/candle_stick_chart_renderer.dart';
import 'bar_line_chart_base.dart';

/// Chart that draws [CandleData] as candlesticks with open, high, low and close values, as used for
/// prices. It implements [CandleDataProvider] for the candle renderer.
class CandleStickChart extends BarLineChartBase<CandleData>
    implements CandleDataProvider {
  @override
  void init() {
    super.init();

    renderer = CandleStickChartRenderer(this, animator, viewPortHandler);

    xAxis.spaceMin = 0.5;
    xAxis.spaceMax = 0.5;
  }

  @override
  CandleData? get candleData => data;
}
