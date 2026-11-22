// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/formatter/DefaultValueFormatter.kt
import 'package:flutter/foundation.dart' show protected;

import '../data/entry.dart';
import '../graphics/decimal_format.dart';
import '../utils/view_port_handler.dart';
import 'i_value_formatter.dart';

/// Formats values with a fixed number of decimal digits and thousands separators, for example 1,234.50. The chart
/// creates one with a digit count derived from its data range and uses it wherever no formatter is set.
class DefaultValueFormatter extends IValueFormatter {
  DecimalFormat? _format;

  /// The number format built by [setup].
  @protected
  DecimalFormat get format => _format!;

  @protected
  set format(DecimalFormat value) => _format = value;

  int _decimalDigits = 0;

  /// Number of decimal digits the formatter produces.
  int get decimalDigits => _decimalDigits;

  @protected
  set decimalDigits(int value) => _decimalDigits = value;

  /// Creates a formatter with [digits] decimal digits.
  DefaultValueFormatter(int digits) {
    setup(digits);
  }

  /// Rebuilds the number format. Does nothing when [digits] equals the current [decimalDigits].
  ///
  /// [digits] is the number of decimal digits; 0 or less formats whole numbers.
  void setup(int digits) {
    if (_format != null && digits == _decimalDigits) return;
    _decimalDigits = digits;
    _format = DecimalFormat('###,###,###,##0${decimalPattern(digits)}');
  }

  @override
  String getFormattedValue(
    double value,
    Entry entry,
    int dataSetIndex,
    ViewPortHandler viewPortHandler,
  ) {
    return format.format(value);
  }
}

/// A float carries no digits past the 45th decimal place, and a zero or subnormal range can ask for billions.
const int _MAX_DECIMAL_DIGITS = 45;

/// The fraction part of a DecimalFormat pattern with [digits] required digits ("" for 0 or less, at most 45).
///
/// Kotlin `internal`: package-internal helper shared with DefaultAxisValueFormatter and StackedValueFormatter, not
/// MPAndroidChart API; the library entry points hide it.
String decimalPattern(int digits) {
  if (digits <= 0) return '';
  return '.${'0' * (digits > _MAX_DECIMAL_DIGITS ? _MAX_DECIMAL_DIGITS : digits)}';
}
