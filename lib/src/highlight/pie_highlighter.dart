// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/highlight/PieHighlighter.kt
import '../charts/pie_chart.dart';
import 'highlight.dart';
import 'pie_radar_highlighter.dart';

/// Highlighter for the pie chart. A pie chart has one data set, so the slice index found by [PieRadarHighlighter] is
/// the whole answer; the highlight carries the slice index as x, the slice value as y and the touch position as pixel
/// position.
class PieHighlighter extends PieRadarHighlighter<PieChart> {
  /// Creates the highlighter of [chart].
  PieHighlighter(super.chart);

  /// Returns the highlight of the slice at [index] with the touch position ([x], [y]) in pixels, data set index 0
  /// and the axis of the data set, or null without a data set or when [index] is not a slice.
  @override
  Highlight? getClosestHighlight(int index, double x, double y) {
    final set = chart.data?.dataSet;
    if (set == null) return null;
    if (index < 0 || index >= set.entryCount) return null;
    final entry = set.getEntryForIndex(index);
    return Highlight.withPixels(
      index.toDouble(),
      entry.y,
      x,
      y,
      0,
      set.axisDependency,
    );
  }
}
