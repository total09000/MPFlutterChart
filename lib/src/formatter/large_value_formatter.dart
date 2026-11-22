// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/formatter/LargeValueFormatter.kt
import '../graphics/decimal_format.dart';
import '../utils/view_port_handler.dart';
import 'i_axis_value_formatter.dart';
import 'i_value_formatter.dart';

/// Shortens large numbers with a suffix per power of one thousand: 856 stays 856, 5821 becomes 5.8k, 101800 becomes
/// 102k, 7800000 becomes 7.8m and 1000000000 becomes 1b. Works as value formatter and as axis formatter.
/// Numbers below one thousand and numbers beyond the last entry of [suffix] are written out with one decimal.
///
/// Kotlin overloads `getFormattedValue` for the two interfaces; Dart has no overloading, so one [getFormattedValue]
/// takes either signature.
class LargeValueFormatter extends IValueFormatter
    implements IAxisValueFormatter {
  /// Suffix per power of one thousand, starting at 10^0. Default "", "k", "m", "b", "t".
  List<String> suffix = ['', 'k', 'm', 'b', 't'];

  /// Text appended after the shortened number.
  String appendix;

  final DecimalFormat _plain = DecimalFormat('###,###,##0.#');
  final DecimalFormat _rounded = DecimalFormat('###,###,##0');

  /// Creates a formatter appending [appendix] after the shortened number.
  LargeValueFormatter([this.appendix = '']);

  /// Shortens [value] and appends [appendix].
  ///
  /// Called as `IValueFormatter.getFormattedValue(value, entry, dataSetIndex, viewPortHandler)` or as
  /// `IAxisValueFormatter.getFormattedValue(value, axis)`; [entryOrAxis] is the entry or the axis, and neither it nor
  /// [dataSetIndex] or [viewPortHandler] affects the result.
  @override
  String getFormattedValue(
    double value,
    Object entryOrAxis, [
    int dataSetIndex = 0,
    ViewPortHandler? viewPortHandler,
  ]) {
    return _makePretty(value) + appendix;
  }

  /// Always 0; the shortened numbers carry their own decimals.
  int get decimalDigits => 0;

  String _makePretty(double number) {
    if (!number.isFinite) return number.toString();

    var scaled = number;
    var step = 0;
    // Compare what would be printed, so a value that rounds up to 1000 moves on to the next suffix.
    while (step < suffix.length - 1 && _asPrinted(scaled).abs() >= 1000.0) {
      scaled /= 1000.0;
      step++;
    }
    final text = scaled.abs() >= 100.0
        ? _rounded.format(scaled)
        : _plain.format(scaled);
    return text + (step < suffix.length ? suffix[step] : '');
  }

  double _asPrinted(double value) {
    return value.abs() >= 100.0 ? _round(value) : _round(value * 10.0) / 10.0;
  }
}

/// Kotlin `kotlin.math.round(Double)`: rounds to the nearest integer, ties to even (Dart's `roundToDouble()` rounds
/// ties away from zero).
double _round(double x) {
  final r = x.roundToDouble();
  if ((r - x).abs() == 0.5 && r.remainder(2) != 0) return 2 * x - r;
  return r;
}
