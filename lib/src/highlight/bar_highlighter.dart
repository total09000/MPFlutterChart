// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/highlight/BarHighlighter.kt
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show protected;

import '../data/bar_line_scatter_candle_bubble_data.dart';
import '../data/data_set.dart';
import '../interfaces/dataprovider/bar_data_provider.dart';
import '../interfaces/datasets/i_bar_data_set.dart';
import '../utils/mp_point_d.dart';
import 'chart_highlighter.dart';
import 'highlight.dart';
import 'range.dart';

/// Highlighter for the bar chart.
///
/// Strategy: like [ChartHighlighter], but only the horizontal pixel distance counts, so a touch anywhere
/// above or below a bar selects it. For stacked bars the touched y value decides which stack value is
/// selected and is stored in [Highlight.stackIndex].
class BarHighlighter extends ChartHighlighter<BarDataProvider> {
  /// Creates a highlighter for the bar chart [chart].
  BarHighlighter(super.chart);

  @override
  Highlight? getHighlight(double x, double y) {
    final high = super.getHighlight(x, y);
    if (high == null) return null;

    final pos = getValsForTouch(x, y);

    final barData = chart.barData;
    final set = barData?.getDataSetByIndex(high.dataSetIndex);
    if (set != null && set.isStacked) {
      final stacked = getStackedHighlight(high, set, pos.x, pos.y);
      MPPointD.recycleInstance(pos);
      return stacked;
    }

    MPPointD.recycleInstance(pos);

    return high;
  }

  /// Turns [high] into a highlight of the stack value that contains [yVal].
  ///
  /// [set] is the stacked data set [high] belongs to, [xVal] the touch x value and [yVal] the touch y value.
  /// Returns [high] unchanged if the entry has no stack values, a new highlight with the stack index and the
  /// pixel position of the top of that stack value, or null if no entry or ranges are found.
  Highlight? getStackedHighlight(
    Highlight high,
    IBarDataSet set,
    double xVal,
    double yVal,
  ) {
    final entry = set.getEntryForXValue(xVal, yVal, Rounding.CLOSEST);
    if (entry == null) return null;

    if (entry.stackValues == null) return high;

    final ranges = entry.ranges;
    if (ranges == null) return null;
    if (ranges.isEmpty) return null;

    final stackIndex = getClosestStackIndex(ranges, yVal);

    final pixels = chart
        .getTransformer(set.axisDependency)
        .getPixelForValues(high.x, ranges[stackIndex].to);

    final stackedHigh = Highlight.stackedWithPixels(
      entry.x,
      entry.y,
      pixels.x,
      pixels.y,
      high.dataSetIndex,
      stackIndex,
      high.axis,
    );

    MPPointD.recycleInstance(pixels);

    return stackedHigh;
  }

  /// Returns the index of the range in [ranges] that contains [value]. Values beyond the last range give
  /// the last index, values below the first range and empty or null lists give 0.
  @protected
  int getClosestStackIndex(List<Range>? ranges, double value) {
    if (ranges == null || ranges.isEmpty) return 0;

    var stackIndex = 0;
    for (final range in ranges) {
      if (range.contains(value)) return stackIndex;
      stackIndex++;
    }

    final length = math.max(ranges.length - 1, 0);
    return value > ranges[length].to ? length : 0;
  }

  /// Keeps only the candidates nearest to the touch, so the y axis choice cannot skip the touched bar.
  @override
  @protected
  List<Highlight> getHighlightsAtXValue(double xVal, double x, double y) {
    final highlights = super.getHighlightsAtXValue(xVal, x, y);
    if (highlights.isEmpty) return highlights;
    // Kotlin's `minOfOrNull`, which measures each candidate once: NaN if any distance is NaN, as with `math.min`.
    var nearest = getDistance(x, y, highlights[0].xPx, highlights[0].yPx);
    for (var i = 1; i < highlights.length; i++) {
      final it = highlights[i];
      nearest = math.min(nearest, getDistance(x, y, it.xPx, it.yPx));
    }
    highlightBuffer.removeWhere(
      (it) => getDistance(x, y, it.xPx, it.yPx) > nearest,
    );
    return highlightBuffer;
  }

  /// Only the horizontal distance counts for bars.
  @override
  @protected
  double getDistance(double x1, double y1, double x2, double y2) =>
      (x1 - x2).abs();

  @override
  @protected
  BarLineScatterCandleBubbleData? get data => chart.barData;
}
