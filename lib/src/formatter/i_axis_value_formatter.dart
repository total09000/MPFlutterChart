// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/formatter/IAxisValueFormatter.kt
import '../components/axis_base.dart';

/// Formats the labels of an axis. Set it with `AxisBase.valueFormatter`.
/// Usage: `IAxisValueFormatter.fromFunction((value, axis) => value.toInt().toString())`.
/// Called for every label on every frame, so avoid allocations and heavy work.
///
/// Kotlin's `fun interface`; a lambda is wrapped with [IAxisValueFormatter.fromFunction].
abstract class IAxisValueFormatter {
  /// Lets subclasses be constant.
  const IAxisValueFormatter();

  /// Wraps [getFormattedValue] in a formatter.
  const factory IAxisValueFormatter.fromFunction(
    String Function(double value, AxisBase axis) getFormattedValue,
  ) = _FunctionAxisValueFormatter;

  /// Returns the label text.
  ///
  /// [value] is the axis value to format, in value space, and [axis] the axis the value belongs to.
  String getFormattedValue(double value, AxisBase axis);
}

class _FunctionAxisValueFormatter extends IAxisValueFormatter {
  const _FunctionAxisValueFormatter(this._getFormattedValue);

  final String Function(double value, AxisBase axis) _getFormattedValue;

  @override
  String getFormattedValue(double value, AxisBase axis) =>
      _getFormattedValue(value, axis);
}
