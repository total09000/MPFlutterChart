// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/formatter/IValueFormatter.kt
import '../data/entry.dart';
import '../utils/view_port_handler.dart';

/// Formats the values drawn next to the entries inside the chart. Set it on a data set or on the chart data.
/// Usage: `IValueFormatter.fromFunction((value, entry, dataSetIndex, viewPortHandler) => value.toInt().toString())`.
/// Called for every drawn value on every frame, so avoid allocations and heavy work.
///
/// Kotlin's `fun interface`; a lambda is wrapped with [IValueFormatter.fromFunction].
abstract class IValueFormatter {
  /// Lets subclasses be constant.
  const IValueFormatter();

  /// Wraps [getFormattedValue] in a formatter; [getStackedFormattedValue] keeps its default.
  const factory IValueFormatter.fromFunction(
    String Function(
      double value,
      Entry entry,
      int dataSetIndex,
      ViewPortHandler viewPortHandler,
    )
    getFormattedValue,
  ) = _FunctionValueFormatter;

  /// Returns the text to draw for [value].
  ///
  /// [entry] is the entry the value belongs to, for example a `BarEntry` in a bar chart, [dataSetIndex] the index of
  /// the entry's data set in the chart data and [viewPortHandler] the current chart state such as scale and
  /// translation.
  String getFormattedValue(
    double value,
    Entry entry,
    int dataSetIndex,
    ViewPortHandler viewPortHandler,
  );

  /// Formats one value of a stacked bar entry. The bar renderers call this instead of [getFormattedValue] so a
  /// formatter can tell the segments apart by position rather than by value. The default ignores the position.
  ///
  /// [value] is one of the entry's stack values and [stackIndex] its position in the entry's stack values, counted
  /// from the first; [entry], [dataSetIndex] and [viewPortHandler] are as for [getFormattedValue]. Returns the text
  /// to draw.
  String getStackedFormattedValue(
    double value,
    int stackIndex,
    Entry entry,
    int dataSetIndex,
    ViewPortHandler viewPortHandler,
  ) => getFormattedValue(value, entry, dataSetIndex, viewPortHandler);
}

class _FunctionValueFormatter extends IValueFormatter {
  const _FunctionValueFormatter(this._getFormattedValue);

  final String Function(
    double value,
    Entry entry,
    int dataSetIndex,
    ViewPortHandler viewPortHandler,
  )
  _getFormattedValue;

  @override
  String getFormattedValue(
    double value,
    Entry entry,
    int dataSetIndex,
    ViewPortHandler viewPortHandler,
  ) => _getFormattedValue(value, entry, dataSetIndex, viewPortHandler);
}
