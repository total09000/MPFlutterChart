// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/formatter/StackedValueFormatter.kt
import '../data/bar_entry.dart';
import '../data/entry.dart';
import '../graphics/decimal_format.dart';
import '../utils/float_math.dart';
import '../utils/view_port_handler.dart';
import 'default_value_formatter.dart';
import 'i_value_formatter.dart';

/// Formats the values of a stacked bar chart, labelling either every stack value or only the total on top of each bar.
/// With `drawWholeStack` false, a stacked `BarEntry` gets its total (`BarEntry.y`) at the topmost stack value and an
/// empty string for the others. The bar renderers pass the position in the stack, so a value that appears twice in
/// one stack is handled correctly; a caller that formats a value itself, without the position, falls back to
/// comparing values. Entries without a stack and `drawWholeStack` true format each value as it is.
///
/// The values are compared at Float precision, as Kotlin's Floats are, so a value read back from a Float buffer still
/// matches the top of its stack.
class StackedValueFormatter extends IValueFormatter {
  final bool _drawWholeStack;
  final String _appendix;
  final DecimalFormat _format;

  /// Creates a stacked value formatter.
  ///
  /// [drawWholeStack] is true to label every stack value, false to label only the total on top of the bar;
  /// [appendix] is the text appended after each formatted value and [decimals] the number of decimal digits.
  StackedValueFormatter(bool drawWholeStack, String appendix, int decimals)
    : _drawWholeStack = drawWholeStack,
      _appendix = appendix,
      _format = DecimalFormat('###,###,###,##0${decimalPattern(decimals)}');

  @override
  String getFormattedValue(
    double value,
    Entry entry,
    int dataSetIndex,
    ViewPortHandler viewPortHandler,
  ) {
    if (!_drawWholeStack && entry is BarEntry) {
      final vals = entry.stackValues;
      if (vals != null) {
        return vals.isNotEmpty &&
                toKotlinFloat(value) == toKotlinFloat(vals.last)
            ? _format.format(entry.y) + _appendix
            : '';
      }
    }
    return _format.format(value) + _appendix;
  }

  @override
  String getStackedFormattedValue(
    double value,
    int stackIndex,
    Entry entry,
    int dataSetIndex,
    ViewPortHandler viewPortHandler,
  ) {
    if (!_drawWholeStack && entry is BarEntry) {
      final vals = entry.stackValues;
      if (vals != null) {
        return stackIndex == vals.length - 1
            ? _format.format(entry.y) + _appendix
            : '';
      }
    }
    return _format.format(value) + _appendix;
  }
}
