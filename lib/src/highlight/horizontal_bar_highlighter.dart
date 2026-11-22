// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/highlight/HorizontalBarHighlighter.kt
import 'package:flutter/foundation.dart' show protected;

import '../data/data_set.dart';
import '../data/entry.dart';
import '../interfaces/datasets/i_data_set.dart';
import '../utils/mp_point_d.dart';
import 'bar_highlighter.dart';
import 'highlight.dart';

/// Highlighter for the horizontal bar chart, where x values run along the vertical screen axis.
///
/// Strategy: like [BarHighlighter] with x and y swapped, so only the vertical pixel distance counts and the touched x
/// pixel decides the stack value.
///
/// `HorizontalBarChart.getHighlightByTouchPoint(x, y)` passes the touch on as `getHighlight(y, x)`, so [getHighlight]
/// takes the vertical pixel first and swaps the two back before converting them to values.
class HorizontalBarHighlighter extends BarHighlighter {
  /// Creates a highlighter for the horizontal bar chart [chart].
  HorizontalBarHighlighter(super.chart);

  @override
  Highlight? getHighlight(double x, double y) {
    final barData = chart.barData;

    final pos = getValsForTouch(y, x);

    final high = getHighlightForX(pos.y, y, x);
    if (high == null) return null;

    final set = barData?.getDataSetByIndex(high.dataSetIndex);
    if (set != null && set.isStacked) {
      final stacked = getStackedHighlight(high, set, pos.y, pos.x);
      MPPointD.recycleInstance(pos);
      return stacked;
    }

    MPPointD.recycleInstance(pos);

    return high;
  }

  @override
  @protected
  List<Highlight> buildHighlights(
    IDataSet set,
    int dataSetIndex,
    double xVal,
    Rounding rounding,
  ) {
    final highlights = <Highlight>[];

    List<Entry> entries = set.getEntriesForXValue(xVal);
    if (entries.isEmpty) {
      final closest = set.getEntryForXValue(xVal, double.nan, rounding);
      if (closest != null) entries = set.getEntriesForXValue(closest.x);
    }

    if (entries.isEmpty) return highlights;

    for (final e in entries) {
      final pixels = chart
          .getTransformer(set.axisDependency)
          .getPixelForValues(e.y, e.x);
      highlights.add(
        Highlight.withPixels(
          e.x,
          e.y,
          pixels.x,
          pixels.y,
          dataSetIndex,
          set.axisDependency,
        ),
      );
    }

    return highlights;
  }

  /// Only the vertical distance counts for horizontal bars.
  @override
  @protected
  double getDistance(double x1, double y1, double x2, double y2) =>
      (y1 - y2).abs();
}
