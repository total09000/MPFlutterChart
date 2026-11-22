// Ported from MPChartExample: custom/MyValueFormatter.kt
import 'package:mp_flutter_chart/core.dart';

/// Formats an entry value with one decimal and a dollar sign.
class MyValueFormatter extends IValueFormatter {
  final DecimalFormat _format = DecimalFormat('###,###,###,##0.0');

  @override
  String getFormattedValue(double value, Entry entry, int dataSetIndex, ViewPortHandler viewPortHandler) =>
      '${_format.format(value)} \$';
}
