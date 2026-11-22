// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/formatter/PercentFormatter.kt
import 'package:flutter/foundation.dart' show protected;

import '../graphics/decimal_format.dart';
import '../utils/view_port_handler.dart';
import 'i_axis_value_formatter.dart';
import 'i_value_formatter.dart';

/// Appends " %" to each value, formatted with one decimal digit by default, for example "12.5 %". Meant for pie charts.
/// Works as value formatter and as axis formatter.
///
/// Kotlin overloads `getFormattedValue` for the two interfaces; Dart has no overloading, so one [getFormattedValue]
/// takes either signature.
class PercentFormatter extends IValueFormatter implements IAxisValueFormatter {
  /// The number format applied before the percent sign.
  @protected
  final DecimalFormat format;

  /// Creates a formatter using [format], by default `###,###,##0.0`.
  PercentFormatter([DecimalFormat? format])
    : format = format ?? DecimalFormat('###,###,##0.0');

  /// Formats [value] followed by " %".
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
    return '${format.format(value)} %';
  }

  /// Number of decimals [format] produces.
  int get decimalDigits => format.maximumFractionDigits;
}
