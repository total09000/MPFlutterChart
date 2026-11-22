// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/highlight/ChartHighlighter.kt
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show protected;

import '../components/y_axis_dependency.dart';
import '../data/bar_line_scatter_candle_bubble_data.dart';
import '../data/data_set.dart';
import '../data/entry.dart';
import '../interfaces/dataprovider/bar_line_scatter_candle_bubble_data_provider.dart';
import '../interfaces/datasets/i_data_set.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_d.dart';
import '../utils/utils.dart';
import 'highlight.dart';
import 'i_highlighter.dart';

/// Default highlighter for line, scatter, candle and bubble charts.
///
/// Strategy: convert the touch to an x value, collect the entry closest to that x value in every
/// data set with highlighting enabled, prefer the y axis whose entries are nearer to the touch, then
/// pick the entry with the smallest pixel distance to the touch. Nothing is selected when that
/// distance exceeds [BarLineScatterCandleBubbleDataProvider.maxHighlightDistance].
class ChartHighlighter<T extends BarLineScatterCandleBubbleDataProvider>
    implements IHighlighter {
  /// The chart whose data and transformers the highlights are searched with.
  @protected
  final T chart;

  /// Creates a highlighter for [chart].
  ChartHighlighter(this.chart);

  /// Reused list that collects the candidate highlights of one lookup.
  @protected
  final List<Highlight> highlightBuffer = [];

  @override
  Highlight? getHighlight(double x, double y) {
    final pos = getValsForTouch(x, y);
    final xVal = pos.x;
    MPPointD.recycleInstance(pos);
    return getHighlightForX(xVal, x, y);
  }

  /// Converts the pixel position ([x], [y]) to values using the left axis transformer.
  ///
  /// Returns a point that may be given to [MPPointD.recycleInstance] when done.
  @protected
  MPPointD getValsForTouch(double x, double y) {
    return chart
        .getTransformer(AxisDependency.LEFT)
        .getValuesByTouchPoint(x, y);
  }

  /// Finds the highlight for the x value [xVal] closest to the pixel position ([x], [y]).
  ///
  /// Picks the y axis whose candidates are nearer to the touch, then the nearest candidate on that axis
  /// within the maximum highlight distance.
  @protected
  Highlight? getHighlightForX(double xVal, double x, double y) {
    final closestValues = getHighlightsAtXValue(xVal, x, y);
    if (closestValues.isEmpty) return null;

    final leftAxisMinDist = getMinimumDistance(
      closestValues,
      y,
      AxisDependency.LEFT,
    );
    final rightAxisMinDist = getMinimumDistance(
      closestValues,
      y,
      AxisDependency.RIGHT,
    );

    final axis = leftAxisMinDist < rightAxisMinDist
        ? AxisDependency.LEFT
        : AxisDependency.RIGHT;

    return getClosestHighlightByPixel(
      closestValues,
      x,
      y,
      axis,
      Utils.convertDpToPixel(chart.maxHighlightDistance),
    );
  }

  /// Returns the smallest pixel distance between [pos] and the [getHighlightPos] of the candidates on [axis],
  /// or `Float.MAX_VALUE` if none belongs to that axis.
  @protected
  double getMinimumDistance(
    List<Highlight> closestValues,
    double pos,
    AxisDependency axis,
  ) {
    double distance = kotlinFloatMaxValue;
    for (final high in closestValues) {
      if (high.axis == axis) {
        final tempDistance = (getHighlightPos(high) - pos).abs();
        if (tempDistance < distance) distance = tempDistance;
      }
    }
    return distance;
  }

  /// The pixel coordinate of [h] used to compare against the touch when choosing the axis; the y pixel here.
  @protected
  double getHighlightPos(Highlight h) => h.yPx;

  /// Collects one candidate highlight per entry at [xVal] from every data set with highlighting enabled.
  ///
  /// [xVal] is the touch position converted to an x value, [x] the touch x position in pixels and [y] the touch
  /// y position in pixels. Returns the shared [highlightBuffer]; empty when the chart has no data.
  @protected
  List<Highlight> getHighlightsAtXValue(double xVal, double x, double y) {
    highlightBuffer.clear();

    final data = this.data;
    if (data == null) return highlightBuffer;

    for (int i = 0; i < data.dataSetCount; i++) {
      final dataSet = data.getDataSetByIndex(i);
      if (dataSet == null) continue;
      if (!dataSet.isHighlightEnabled) continue;
      highlightBuffer.addAll(
        buildHighlights(dataSet, i, xVal, Rounding.CLOSEST),
      );
    }

    return highlightBuffer;
  }

  /// Builds a highlight for every entry of [set] at [xVal], or at the closest x value according to [rounding]
  /// if there is none exactly at [xVal].
  ///
  /// [dataSetIndex] is the index of [set] in the chart data, stored in the highlights. Returns an empty list if
  /// the set has no entries near [xVal].
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
          .getPixelForValues(e.x, e.y);
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

  /// Picks the candidate with the smallest [getDistance] to the pixel position ([x], [y]).
  ///
  /// [axis]: only candidates on this axis are considered; null considers all. [minSelectionDistance]: candidates
  /// at this pixel distance or further are ignored. Returns the closest candidate, or null if none is within
  /// [minSelectionDistance].
  Highlight? getClosestHighlightByPixel(
    List<Highlight> closestValues,
    double x,
    double y,
    AxisDependency? axis,
    double minSelectionDistance,
  ) {
    Highlight? closest;
    double distance = minSelectionDistance;

    for (final high in closestValues) {
      if (axis == null || high.axis == axis) {
        final cDistance = getDistance(x, y, high.xPx, high.yPx);
        if (cDistance < distance) {
          closest = high;
          distance = cDistance;
        }
      }
    }

    return closest;
  }

  /// Distance in pixels between two points; the straight line distance here.
  @protected
  double getDistance(double x1, double y1, double x2, double y2) =>
      _hypot(x1 - x2, y1 - y2);

  /// The chart data the highlights are searched in.
  @protected
  BarLineScatterCandleBubbleData? get data => chart.data;
}

/// `kotlin.math.hypot` (`java.lang.Math.hypot`): sqrt(a² + b²) without intermediate overflow; infinite if either
/// argument is infinite, even when the other is NaN, otherwise NaN if either is NaN.
double _hypot(double a, double b) {
  a = a.abs();
  b = b.abs();
  if (a.isInfinite || b.isInfinite) return double.infinity;
  if (a.isNaN || b.isNaN) return double.nan;
  if (a < b) {
    final t = a;
    a = b;
    b = t;
  }
  if (a == 0) return 0;
  final r = b / a;
  return a * math.sqrt(1 + r * r);
}
