// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/formatter/DefaultAxisValueFormatter.kt
import 'package:flutter/foundation.dart' show protected;

import '../components/axis_base.dart';
import '../graphics/decimal_format.dart';
import 'default_value_formatter.dart';
import 'i_axis_value_formatter.dart';

/// Formats axis labels with a fixed number of decimal digits and thousands separators. An axis creates one with its
/// computed `AxisBase.decimals` while no formatter is assigned.
class DefaultAxisValueFormatter extends IAxisValueFormatter {
  /// Number of decimal digits the formatter produces; 0 or less formats whole numbers.
  final int decimalDigits;

  /// The number format used for the labels.
  @protected
  final DecimalFormat format;

  /// Creates a formatter with [decimalDigits] decimal digits.
  DefaultAxisValueFormatter(this.decimalDigits)
    : format = DecimalFormat('###,###,###,##0${decimalPattern(decimalDigits)}');

  @override
  String getFormattedValue(double value, AxisBase axis) {
    return format.format(value);
  }
}
