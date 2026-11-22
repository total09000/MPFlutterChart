// Ported from MPChartExample: custom/YearXAxisFormatter.kt
import 'package:mp_flutter_chart/core.dart';

/// Formats an x value as the month at its share of the axis range.
class YearXAxisFormatter implements IAxisValueFormatter {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  @override
  String getFormattedValue(double value, AxisBase axis) {
    final percent = value / axis.axisRange;
    // Kotlin's Float.toInt() saturates and maps NaN to 0, where Dart's toInt() throws on a value that is not finite.
    final scaled = _months.length * percent;
    final index = scaled.isNaN ? 0 : scaled.clamp(0, _months.length - 1).toInt();
    return _months[index];
  }
}
