// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/formatter/DefaultFillFormatter.kt
import '../interfaces/dataprovider/line_data_provider.dart';
import '../interfaces/datasets/i_line_data_set.dart';
import 'i_fill_formatter.dart';

/// Fill position used by line data sets that set no formatter. The fill reaches the zero line when the data set or
/// the whole line data has values on both sides of zero, otherwise the axis minimum for a positive data set and the
/// axis maximum for a negative one. Returns 0 while the chart has no line data.
class DefaultFillFormatter extends IFillFormatter {
  /// Creates the default fill formatter.
  const DefaultFillFormatter();

  @override
  double getFillLinePosition(
    ILineDataSet dataSet,
    LineDataProvider dataProvider,
  ) {
    final chartMaxY = dataProvider.yChartMax;
    final chartMinY = dataProvider.yChartMin;
    final data = dataProvider.lineData;
    if (data == null) return 0;

    if (dataSet.yMax > 0 && dataSet.yMin < 0) return 0;

    final max = data.yMax > 0 ? 0.0 : chartMaxY;
    final min = data.yMin < 0 ? 0.0 : chartMinY;
    return dataSet.yMin >= 0 ? min : max;
  }
}
