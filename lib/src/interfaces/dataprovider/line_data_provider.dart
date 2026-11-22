// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/dataprovider/LineDataProvider.kt
import '../../components/y_axis.dart';
import '../../data/line_data.dart';
import 'bar_line_scatter_candle_bubble_data_provider.dart';

/// What the line chart renderer reads from a chart that shows lines.
/// Implemented by `LineChart` and the combined chart.
abstract class LineDataProvider extends BarLineScatterCandleBubbleDataProvider {
  /// The line data of the chart, null when there is none.
  LineData? get lineData;

  /// Returns the left or right y axis, used to find the axis minimum when filling below a line.
  YAxis getAxis(AxisDependency axis);
}
