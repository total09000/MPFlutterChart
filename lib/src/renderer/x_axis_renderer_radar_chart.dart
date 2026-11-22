// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/XAxisRendererRadarChart.kt
//
// The renderer has no Transformer (null): the base computeAxis then computes the labels from the given
// range directly. Kotlin's `%` on the label angle is the signed `remainder`, and its Float arithmetic is done in double
// precision, as in the rest of the port. A label whose position is not finite as a Float (a NaN rotation
// angle, or a y axis range of 0 or infinity) is not drawn; Kotlin's Float position is infinite or NaN there, and
// Android draws nothing.
import 'dart:ui' as ui;

import '../charts/radar_chart.dart';
import '../components/x_axis.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';
import '../utils/view_port_handler.dart';
import 'x_axis_renderer.dart';

/// Draws the x axis labels of a [RadarChart]: one label per entry index at the outer end of its spoke. Grid lines are
/// part of the web drawn by the chart's data renderer, and limit lines are not supported.
class XAxisRendererRadarChart extends XAxisRenderer {
  /// Creates the renderer of [xAxis] for the radar chart [_chart], without a transformer.
  XAxisRendererRadarChart(
    ViewPortHandler viewPortHandler,
    XAxis xAxis,
    this._chart,
  ) : super(viewPortHandler, xAxis, null);

  final RadarChart _chart;

  /// Draws one label per entry index, formatted from the index, just outside the web at the angle
  /// `sliceAngle * index + rotationAngle` degrees clockwise from 3 o'clock: half the rotated label width beyond the
  /// web radius, raised by half the rotated label height. Does nothing when the axis or its labels are disabled.
  @override
  void renderAxisLabels(ui.Canvas c) {
    if (!xAxis.isEnabled || !xAxis.isDrawLabelsEnabled) return;

    final labelRotationAngleDegrees = xAxis.labelRotationAngle;
    final drawLabelAnchor = MPPointF.getInstance(0.5, 0.25);

    paintAxisLabels.typeface = xAxis.typeface;
    paintAxisLabels.textSize = Utils.convertDpToPixel(xAxis.textSize);
    paintAxisLabels.color = xAxis.textColor;

    final sliceangle = _chart.sliceAngle;
    final factor = _chart.factor;

    final center = _chart.centerOffsets;
    final pOut = MPPointF.getInstance(0, 0);
    final entryCount = _chart.data?.maxEntryCountSet?.entryCount ?? 0;
    for (var i = 0; i < entryCount; i++) {
      final label = xAxis.valueFormatter.getFormattedValue(i.toDouble(), xAxis);

      final angle = (sliceangle * i + _chart.rotationAngle).remainder(360);

      Utils.getPosition(
        center,
        _chart.yRange * factor + xAxis.labelRotatedWidth / 2,
        angle,
        pOut,
      );

      final y = pOut.y - xAxis.labelRotatedHeight / 2;

      if (!toKotlinFloat(pOut.x).isFinite || !toKotlinFloat(y).isFinite) {
        continue;
      }

      drawLabel(
        c,
        label,
        pOut.x,
        y,
        drawLabelAnchor,
        labelRotationAngleDegrees,
      );
    }

    MPPointF.recycleInstance(center);
    MPPointF.recycleInstance(pOut);
    MPPointF.recycleInstance(drawLabelAnchor);
  }

  /// Does nothing; the x axis of a radar chart has no limit lines.
  @override
  void renderLimitLines(ui.Canvas c) {}
}
