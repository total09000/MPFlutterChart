// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/highlight/IHighlighter.kt
import 'highlight.dart';

/// Finds the value to highlight for a touch position. Every chart owns one highlighter and asks it
/// on tap and, if enabled, while dragging.
///
/// Can be written as a function: `IHighlighter.fromFunction((x, y) => ...)`.
///
/// Kotlin's `fun interface`; a lambda is wrapped with [IHighlighter.fromFunction].
abstract class IHighlighter {
  /// Lets subclasses be constant.
  const IHighlighter();

  /// Wraps [getHighlight] in a highlighter.
  const factory IHighlighter.fromFunction(
    Highlight? Function(double x, double y) getHighlight,
  ) = _FunctionHighlighter;

  /// Returns the highlight for the pixel position ([x], [y]), or null if nothing is close enough
  /// or the chart has no data.
  Highlight? getHighlight(double x, double y);
}

class _FunctionHighlighter extends IHighlighter {
  const _FunctionHighlighter(this._getHighlight);

  final Highlight? Function(double x, double y) _getHighlight;

  @override
  Highlight? getHighlight(double x, double y) => _getHighlight(x, y);
}
