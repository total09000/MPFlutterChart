// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/XAxisRendererHorizontalBarChart.kt
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../charts/bar_chart.dart';
import '../components/limit_line.dart';
import '../components/x_axis.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../utils/f_size.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';
import 'x_axis_renderer.dart';

/// Draws the x axis of a horizontal bar chart, where the x axis runs vertically: the labels left or right of the
/// content rectangle, horizontal grid lines, the axis line along the left or right edge and horizontal limit
/// lines. The x axis positions TOP and BOTTOM map to the right and left edge.
class XAxisRendererHorizontalBarChart extends XAxisRenderer {
  /// Creates a renderer for [xAxis] of [chart]; [transformer] converts axis values to pixels.
  XAxisRendererHorizontalBarChart(
    super.viewPortHandler,
    super.xAxis,
    super.transformer,
    this.chart,
  );

  /// The bar chart whose x axis is drawn.
  @protected
  final BarChart chart;

  /// The labels run down the side here, so their width places no limit on the interval.
  @override
  @protected
  double minimumInterval(double range) => 0.0;

  /// Takes the visible range from the top and bottom edge of the content rectangle, because the x axis runs
  /// vertically here.
  @override
  void computeAxis(double min, double max, bool inverted) {
    var newMin = min;
    var newMax = max;

    final transformer = this.transformer;
    if (transformer != null &&
        viewPortHandler.contentWidth > 10 &&
        !viewPortHandler.isFullyZoomedOutY) {
      final p1 = computeAxisPoint1;
      final p2 = computeAxisPoint2;
      transformer.getValuesByTouchPoint(
        viewPortHandler.contentLeft,
        viewPortHandler.contentBottom,
        p1,
      );
      transformer.getValuesByTouchPoint(
        viewPortHandler.contentLeft,
        viewPortHandler.contentTop,
        p2,
      );

      if (inverted) {
        newMin = toKotlinFloat(p2.y);
        newMax = toKotlinFloat(p1.y);
      } else {
        newMin = toKotlinFloat(p1.y);
        newMax = toKotlinFloat(p2.y);
      }
    }

    computeAxisValues(newMin, newMax);
  }

  /// Also adds 3.5 times the axis x offset to the stored label widths, to keep the labels clear of the bars.
  @override
  @protected
  void computeSize() {
    paintAxisLabels.typeface = xAxis.typeface;
    paintAxisLabels.textSize = Utils.convertDpToPixel(xAxis.textSize);

    final longest = xAxis.longestLabel;

    final labelSize = Utils.calcTextSize(paintAxisLabels, longest);

    final labelWidth = truncateToDevicePx(
      labelSize.width + Utils.convertDpToPixel(xAxis.xOffset) * 3.5,
    );
    final labelHeight = labelSize.height;

    final labelRotatedSize = Utils.getSizeOfRotatedRectangleByDegrees(
      labelSize.width,
      labelHeight,
      xAxis.labelRotationAngle,
    );

    // Kotlin's toInt and roundToInt in device px.
    xAxis.labelWidth = roundToDevicePx(labelWidth);
    xAxis.labelHeight = roundToDevicePx(labelHeight);
    xAxis.labelRotatedWidth = truncateToDevicePx(
      labelRotatedSize.width + Utils.convertDpToPixel(xAxis.xOffset) * 3.5,
    );
    xAxis.labelRotatedHeight = roundToDevicePx(labelRotatedSize.height);

    // As in Kotlin, only the rotated size goes back to the pool here.
    FSize.recycleInstance(labelRotatedSize);
  }

  @override
  void renderAxisLabels(ui.Canvas c) {
    if (!xAxis.isEnabled || !xAxis.isDrawLabelsEnabled) return;

    final xoffset = Utils.convertDpToPixel(xAxis.xOffset);

    paintAxisLabels.typeface = xAxis.typeface;
    paintAxisLabels.textSize = Utils.convertDpToPixel(xAxis.textSize);
    paintAxisLabels.color = xAxis.textColor;

    final pointF = MPPointF.getInstance(0, 0);

    switch (xAxis.position) {
      case XAxisPosition.TOP:
        pointF.x = 0.0;
        pointF.y = 0.5;
        drawLabels(c, viewPortHandler.contentRight + xoffset, pointF);
      case XAxisPosition.TOP_INSIDE:
        pointF.x = 1.0;
        pointF.y = 0.5;
        drawLabels(c, viewPortHandler.contentRight - xoffset, pointF);
      case XAxisPosition.BOTTOM:
        pointF.x = 1.0;
        pointF.y = 0.5;
        drawLabels(c, viewPortHandler.contentLeft - xoffset, pointF);
      case XAxisPosition.BOTTOM_INSIDE:
        pointF.x = 1.0;
        pointF.y = 0.5;
        drawLabels(c, viewPortHandler.contentLeft + xoffset, pointF);
      case XAxisPosition.BOTH_SIDED:
        pointF.x = 0.0;
        pointF.y = 0.5;
        drawLabels(c, viewPortHandler.contentRight + xoffset, pointF);
        pointF.x = 1.0;
        pointF.y = 0.5;
        drawLabels(c, viewPortHandler.contentLeft - xoffset, pointF);
    }

    MPPointF.recycleInstance(pointF);
  }

  /// Draws the labels at the horizontal pixel position [pos], one per axis entry inside the visible y range.
  @override
  @protected
  void drawLabels(ui.Canvas c, double pos, MPPointF anchor) {
    final labelRotationAngleDegrees = xAxis.labelRotationAngle;
    final centeringEnabled = xAxis.isCenterAxisLabelsEnabled;

    final positions = Float32List(xAxis.entryCount * 2);

    for (var i = 0; i < positions.length; i += 2) {
      positions[i + 1] = centeringEnabled
          ? xAxis.centeredEntries[i ~/ 2]
          : xAxis.entries[i ~/ 2];
    }

    transformer?.pointValuesToPixel(positions);

    for (var i = 0; i < positions.length; i += 2) {
      final y = positions[i + 1];

      if (viewPortHandler.isInBoundsY(y)) {
        final label = xAxis.valueFormatter.getFormattedValue(
          xAxis.entries[i ~/ 2],
          xAxis,
        );
        drawLabel(c, label, pos, y, anchor, labelRotationAngleDegrees);
      }
    }
  }

  /// Widened vertically instead of horizontally, because the grid lines are horizontal here.
  @override
  MutableRect get gridClippingRect {
    gridClippingRectBuffer.setFrom(viewPortHandler.contentRect);
    gridClippingRectBuffer.inset(
      0,
      -Utils.convertDpToPixel(axis.gridLineWidth),
    );
    return gridClippingRectBuffer;
  }

  /// Draws one horizontal grid line at the pixel position [y] over the content width. [x] is not used here.
  @override
  @protected
  void drawGridLine(ui.Canvas c, double x, double y, ui.Path gridLinePath) {
    gridLinePath.moveTo(viewPortHandler.contentRight, y);
    gridLinePath.lineTo(viewPortHandler.contentLeft, y);

    c.drawPathP(gridLinePath, paintGrid);

    gridLinePath.reset();
  }

  /// Draws the axis line along the right edge for the TOP positions and along the left edge for the BOTTOM
  /// positions.
  @override
  void renderAxisLine(ui.Canvas c) {
    if (!xAxis.isDrawAxisLineEnabled || !xAxis.isEnabled) return;

    paintAxisLine.color = xAxis.axisLineColor;
    paintAxisLine.strokeWidth = Utils.convertDpToPixel(xAxis.axisLineWidth);

    if (xAxis.position == XAxisPosition.TOP ||
        xAxis.position == XAxisPosition.TOP_INSIDE ||
        xAxis.position == XAxisPosition.BOTH_SIDED) {
      c.drawLineP(
        viewPortHandler.contentRight,
        viewPortHandler.contentTop,
        viewPortHandler.contentRight,
        viewPortHandler.contentBottom,
        paintAxisLine,
      );
    }

    if (xAxis.position == XAxisPosition.BOTTOM ||
        xAxis.position == XAxisPosition.BOTTOM_INSIDE ||
        xAxis.position == XAxisPosition.BOTH_SIDED) {
      c.drawLineP(
        viewPortHandler.contentLeft,
        viewPortHandler.contentTop,
        viewPortHandler.contentLeft,
        viewPortHandler.contentBottom,
        paintAxisLine,
      );
    }
  }

  final ui.Path _renderLimitLinesPathBuffer = ui.Path();

  /// Draws each enabled limit line as a horizontal line at the pixel y of its limit value and its label at the
  /// left or right of the content rectangle. A label that would stick out of the content rectangle is moved inside
  /// it; the label of a line outside the content rectangle is not drawn.
  @override
  void renderLimitLines(ui.Canvas c) {
    final limitLines = xAxis.limitLines;
    if (limitLines.isEmpty) return;

    final pts = renderLimitLinesBuffer;
    pts[0] = 0;
    pts[1] = 0;

    final limitLinePath = _renderLimitLinesPathBuffer;
    limitLinePath.reset();

    for (final l in limitLines) {
      if (!l.isEnabled) continue;

      final clipRestoreCount = c.getSaveCount();
      c.save();
      limitLineClippingRect.setFrom(viewPortHandler.contentRect);
      limitLineClippingRect.inset(0, -Utils.convertDpToPixel(l.lineWidth));
      c.clipRectM(limitLineClippingRect);

      limitLinePaint.style = PaintStyle.STROKE;
      limitLinePaint.color = l.lineColor;
      limitLinePaint.strokeWidth = Utils.convertDpToPixel(l.lineWidth);
      limitLinePaint.pathEffect = l.dashPathEffect;

      pts[1] = l.limit;

      transformer?.pointValuesToPixel(pts);

      limitLinePath.moveTo(viewPortHandler.contentLeft, pts[1]);
      limitLinePath.lineTo(viewPortHandler.contentRight, pts[1]);

      c.drawPathP(limitLinePath, limitLinePaint);
      limitLinePath.reset();

      final label = l.label;
      final lineVisible =
          pts[1] >= limitLineClippingRect.top &&
          pts[1] <= limitLineClippingRect.bottom;

      if (label.isNotEmpty && lineVisible) {
        limitLinePaint.style = l.textStyle;
        limitLinePaint.pathEffect = null;
        limitLinePaint.color = l.textColor;
        limitLinePaint.strokeWidth = 0.5;
        limitLinePaint.textSize = Utils.convertDpToPixel(l.textSize);

        final labelLineHeight = Utils.calcTextHeight(limitLinePaint, label);
        final xOffset =
            Utils.convertDpToPixel(4) + Utils.convertDpToPixel(l.xOffset);
        final yOffset =
            Utils.convertDpToPixel(l.lineWidth) +
            labelLineHeight +
            Utils.convertDpToPixel(l.yOffset);
        final topBaseline = pts[1] - yOffset + labelLineHeight;
        final bottomBaseline = pts[1] + yOffset;
        final baseline = _coerceIn(
          switch (l.labelPosition) {
            LimitLabelPosition.RIGHT_TOP ||
            LimitLabelPosition.LEFT_TOP => topBaseline,
            LimitLabelPosition.RIGHT_BOTTOM ||
            LimitLabelPosition.LEFT_BOTTOM => bottomBaseline,
          },
          viewPortHandler.contentTop + labelLineHeight,
          math.max(
            viewPortHandler.contentBottom,
            viewPortHandler.contentTop + labelLineHeight,
          ),
        );

        switch (l.labelPosition) {
          case LimitLabelPosition.RIGHT_TOP:
          case LimitLabelPosition.RIGHT_BOTTOM:
            limitLinePaint.textAlign = PaintAlign.RIGHT;
            c.drawText(
              label,
              viewPortHandler.contentRight - xOffset,
              baseline,
              limitLinePaint,
            );
          case LimitLabelPosition.LEFT_TOP:
            limitLinePaint.textAlign = PaintAlign.LEFT;
            c.drawText(
              label,
              viewPortHandler.contentLeft + xOffset,
              baseline,
              limitLinePaint,
            );
          case LimitLabelPosition.LEFT_BOTTOM:
            limitLinePaint.textAlign = PaintAlign.LEFT;
            c.drawText(
              label,
              viewPortHandler.offsetLeft + xOffset,
              baseline,
              limitLinePaint,
            );
        }
      }

      c.restoreToCount(clipRestoreCount);
    }
  }

  /// Kotlin `Float.coerceIn(min, max)`: keeps NaN as NaN, unlike Dart's `clamp`.
  static double _coerceIn(double value, double min, double max) {
    if (min > max) {
      throw ArgumentError(
        'Cannot coerce value to an empty range: maximum $max is less than minimum $min.',
      );
    }
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
