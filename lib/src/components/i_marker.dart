// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/components/IMarker.kt
import 'dart:ui' as ui;

import '../data/entry.dart';
import '../highlight/highlight.dart';
import '../utils/mp_point_f.dart';

/// Something drawn at a highlighted value, such as a popup with details. Assign it to `Chart.marker`; the chart then
/// calls [refreshContent] followed by [draw] for every highlighted entry. Positions and offsets are in px on the chart
/// view.
abstract class IMarker {
  /// Offset in px from the highlighted point to the top left corner of the marker. Use -width / 2 and -height / 2 to
  /// center it.
  MPPointF get offset;

  /// Offset to use when drawing at the given point, so the marker can adjust its position case by case, for example
  /// to stay inside the chart. Return [offset] when no adjustment is needed.
  ///
  /// [posX] and [posY] are the position in px at which the marker is about to be drawn.
  MPPointF getOffsetForDrawingAtPoint(double posX, double posY);

  /// Updates the content before the marker is drawn.
  ///
  /// [e] is the highlighted entry; cast it to the chart's entry type if needed. [highlight] holds details of the
  /// highlight such as the data set index and, for stacked bars, the stack index.
  void refreshContent(Entry e, Highlight highlight);

  /// Draws the marker on [canvas], the chart's canvas, for the highlighted point at [posX] / [posY] in px.
  void draw(ui.Canvas canvas, double posX, double posY);
}
