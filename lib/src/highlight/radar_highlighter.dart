// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/highlight/RadarHighlighter.kt
//
// Kotlin's `Float.MAX_VALUE` is kotlinFloatMaxValue. As in Kotlin, the entry value of each candidate is compared with
// the touch distance in value units, measured from the center (not from the y axis minimum).
import 'package:flutter/foundation.dart' show protected;

import '../charts/radar_chart.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';
import 'highlight.dart';
import 'pie_radar_highlighter.dart';

/// Highlighter for the radar chart.
///
/// Strategy: the touch angle picks the entry index on the web, then among all data sets the entry whose value is
/// closest to the touch distance from the center (in value units, the distance divided by the chart's factor) wins.
/// The highlight carries the entry index as x and the entry value as y.
class RadarHighlighter extends PieRadarHighlighter<RadarChart> {
  /// Creates the highlighter of [chart].
  RadarHighlighter(super.chart);

  /// Returns the highlight at the entry [index] of the data set whose value is closest to the touch distance of the
  /// pixel position ([x], [y]) from the center, or null when no data set has an entry at [index].
  @override
  Highlight? getClosestHighlight(int index, double x, double y) {
    final highlights = getHighlightsAtIndex(index);

    final distanceToCenter = chart.distanceToCenter(x, y) / chart.factor;

    Highlight? closest;
    var distance = kotlinFloatMaxValue;

    for (final high in highlights) {
      final cdistance = (high.y - distanceToCenter).abs();
      if (cdistance < distance) {
        closest = high;
        distance = cdistance;
      }
    }

    return closest;
  }

  /// Builds one highlight per data set that has an entry at [index], with the pixel position of that entry on the web
  /// including the current animation phases.
  ///
  /// Returns the shared `highlightBuffer`; empty when the chart has no data.
  @protected
  List<Highlight> getHighlightsAtIndex(int index) {
    highlightBuffer.clear();

    final data = chart.data;
    if (data == null) return highlightBuffer;

    final phaseX = chart.animator.phaseX;
    final phaseY = chart.animator.phaseY;
    final sliceangle = chart.sliceAngle;
    final factor = chart.factor;

    final pOut = MPPointF.getInstance(0, 0);
    for (var i = 0; i < data.dataSetCount; i++) {
      final dataSet = data.getDataSetByIndex(i);
      if (dataSet == null) continue;
      if (index < 0 || index >= dataSet.entryCount) continue;
      final entry = dataSet.getEntryForIndex(index);

      final y = entry.y - chart.yChartMin;

      Utils.getPosition(
        chart.centerOffsets,
        y * factor * phaseY,
        sliceangle * index * phaseX + chart.rotationAngle,
        pOut,
      );

      highlightBuffer.add(
        Highlight.withPixels(
          index.toDouble(),
          entry.y,
          pOut.x,
          pOut.y,
          i,
          dataSet.axisDependency,
        ),
      );
    }

    return highlightBuffer;
  }
}
