// Ported from MPChartExample: custom/MyAxisValueFormatter.kt
import 'package:mp_flutter_chart/core.dart';

/// Formats an axis value with one decimal and a dollar sign.
class MyAxisValueFormatter implements IAxisValueFormatter {
  final DecimalFormat _format = DecimalFormat('###,###,###,##0.0');

  @override
  String getFormattedValue(double value, AxisBase axis) => '${_format.format(value)} \$';
}
