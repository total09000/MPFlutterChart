// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/listener/OnChartValueSelectedListener.kt
import '../data/entry.dart';
import '../highlight/highlight.dart';

/// Receives the value the user selects in a chart by tapping or, when enabled, dragging.
/// Register it as `chart.onChartValueSelectedListener`, add it to `chart.valueSelectedListeners` or use the
/// `chart.onValueSelected(...)` shortcut.
///
/// Programmatic calls to `chart.highlightValue(...)` also report here unless their `callListener` parameter is false.
///
/// Kotlin's `interface`; implement it, or create one from two functions with [OnChartValueSelectedListener.fromFunction]
/// where Kotlin would write an `object : OnChartValueSelectedListener { ... }` expression.
abstract class OnChartValueSelectedListener {
  /// Lets subclasses be constant.
  const OnChartValueSelectedListener();

  /// Creates a listener that calls [onValueSelected] and [onNothingSelected].
  const factory OnChartValueSelectedListener.fromFunction({
    required void Function(Entry e, Highlight h) onValueSelected,
    required void Function() onNothingSelected,
  }) = _FunctionValueSelectedListener;

  /// Called when a value is selected.
  ///
  /// [e] is the selected entry, [h] where the selection is: data set index, x and y value, pixel position and stack
  /// index.
  void onValueSelected(Entry e, Highlight h);

  /// Called when the selection is cleared: the user tapped empty space, tapped the selected value again,
  /// or the highlighted entry no longer exists in the data.
  void onNothingSelected();
}

class _FunctionValueSelectedListener extends OnChartValueSelectedListener {
  const _FunctionValueSelectedListener({
    required void Function(Entry e, Highlight h) onValueSelected,
    required void Function() onNothingSelected,
  }) : _onValueSelected = onValueSelected,
       _onNothingSelected = onNothingSelected;

  final void Function(Entry e, Highlight h) _onValueSelected;
  final void Function() _onNothingSelected;

  @override
  void onValueSelected(Entry e, Highlight h) => _onValueSelected(e, h);

  @override
  void onNothingSelected() => _onNothingSelected();
}
