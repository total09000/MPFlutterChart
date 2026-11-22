// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/highlight/PieRadarHighlighter.kt
//
// Kotlin's `PieRadarChartBase<*>` bound is the raw `PieRadarChartBase` here. The import of pie_chart.dart for the
// `chart is PieChart` check closes an import cycle with pie_chart.dart, which Dart allows.
import 'package:flutter/foundation.dart' show protected;

import '../charts/pie_chart.dart';
import '../charts/pie_radar_chart_base.dart';
import 'highlight.dart';
import 'i_highlighter.dart';

/// Shared highlighter logic for pie and radar charts.
///
/// Strategy: touches outside the chart radius select nothing. Otherwise the angle of the touch around the center,
/// measured clockwise from 3 o'clock and corrected for the running y animation on pie charts, is turned into an entry
/// index and [getClosestHighlight] decides which data set to pick at that index.
///
/// [T] is the chart type this highlighter serves.
abstract class PieRadarHighlighter<T extends PieRadarChartBase>
    implements IHighlighter {
  /// Creates a highlighter for [chart].
  PieRadarHighlighter(this.chart);

  /// The chart whose radius, angles and data the highlights are searched with.
  @protected
  final T chart;

  /// Reused list that collects the candidate highlights of one lookup.
  @protected
  final List<Highlight> highlightBuffer = [];

  /// Returns the highlight for the touch at the pixel position ([x], [y]), or null when the touch lies outside the
  /// chart radius, no entry lies under its angle or the chart has no data. The hole of a pie chart is not excluded.
  @override
  Highlight? getHighlight(double x, double y) {
    final chart = this.chart;
    final touchDistanceToCenter = chart.distanceToCenter(x, y);

    if (touchDistanceToCenter > chart.radius) return null;

    var angle = chart.getAngleForPoint(x, y);

    if (chart is PieChart) {
      angle /= chart.animator.phaseY;
    }

    final index = chart.getIndexForAngle(angle);

    final entryCount = chart.data?.maxEntryCountSet?.entryCount ?? 0;
    if (index < 0 || index >= entryCount) return null;

    return getClosestHighlight(index, x, y);
  }

  /// Returns the highlight for the entry [index] closest to the pixel position ([x], [y]), or null if the chart has
  /// no data.
  @protected
  Highlight? getClosestHighlight(int index, double x, double y);
}
