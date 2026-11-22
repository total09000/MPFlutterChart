// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/YAxisRendererHorizontalBarChart.kt
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../components/limit_line.dart';
import '../components/y_axis.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../utils/float_math.dart';
import '../utils/utils.dart';
import 'y_axis_renderer.dart';

/// Draws a y axis of a horizontal bar chart, where the y axis runs horizontally: the left axis along the top
/// edge and the right axis along the bottom edge, with vertical grid lines, a vertical zero line and vertical
/// limit lines.
class YAxisRendererHorizontalBarChart extends YAxisRenderer {
  /// Creates a renderer for [yAxis]; [transformer] converts axis values to pixels. Limit line labels are drawn
  /// left aligned.
  YAxisRendererHorizontalBarChart(
    super.viewPortHandler,
    super.yAxis,
    super.transformer,
  ) {
    limitLinePaint.textAlign = PaintAlign.LEFT;
  }

  /// Takes the visible range from the left and right edge of the content rectangle, because the y axis runs
  /// horizontally here.
  @override
  void computeAxis(double min, double max, bool inverted) {
    var yMin = min;
    var yMax = max;

    final transformer = this.transformer;
    if (transformer != null &&
        viewPortHandler.contentHeight > 10 &&
        !viewPortHandler.isFullyZoomedOutX) {
      final p1 = computeAxisPoint1;
      final p2 = computeAxisPoint2;
      transformer.getValuesByTouchPoint(
        viewPortHandler.contentLeft,
        viewPortHandler.contentTop,
        p1,
      );
      transformer.getValuesByTouchPoint(
        viewPortHandler.contentRight,
        viewPortHandler.contentTop,
        p2,
      );

      if (!inverted) {
        yMin = toKotlinFloat(p1.x);
        yMax = toKotlinFloat(p2.x);
      } else {
        yMin = toKotlinFloat(p2.x);
        yMax = toKotlinFloat(p1.x);
      }
    }

    computeAxisValues(yMin, yMax);
  }

  /// Draws the labels centered above the content rectangle for the left axis and below it for the right axis.
  @override
  void renderAxisLabels(ui.Canvas c) {
    if (!yAxis.isEnabled || !yAxis.isDrawLabelsEnabled) return;

    final positions = getTransformedPositions();

    paintAxisLabels.typeface = yAxis.typeface;
    paintAxisLabels.textSize = Utils.convertDpToPixel(yAxis.textSize);
    paintAxisLabels.color = yAxis.textColor;
    paintAxisLabels.textAlign = PaintAlign.CENTER;

    final baseYOffset = Utils.convertDpToPixel(2.5);
    final textHeight = Utils.calcTextHeight(paintAxisLabels, 'Q');

    final dependency = yAxis.axisDependency;

    final yPos = dependency == AxisDependency.LEFT
        ? viewPortHandler.contentTop - baseYOffset
        : viewPortHandler.contentBottom + textHeight + baseYOffset;

    drawYLabels(c, yPos, positions, Utils.convertDpToPixel(yAxis.yOffset));
  }

  /// Draws the axis line along the top edge for the left axis and along the bottom edge for the right axis.
  @override
  void renderAxisLine(ui.Canvas c) {
    if (!yAxis.isEnabled || !yAxis.isDrawAxisLineEnabled) return;

    paintAxisLine.color = yAxis.axisLineColor;
    paintAxisLine.strokeWidth = Utils.convertDpToPixel(yAxis.axisLineWidth);

    if (yAxis.axisDependency == AxisDependency.LEFT) {
      c.drawLineP(
        viewPortHandler.contentLeft,
        viewPortHandler.contentTop,
        viewPortHandler.contentRight,
        viewPortHandler.contentTop,
        paintAxisLine,
      );
    } else {
      c.drawLineP(
        viewPortHandler.contentLeft,
        viewPortHandler.contentBottom,
        viewPortHandler.contentRight,
        viewPortHandler.contentBottom,
        paintAxisLine,
      );
    }
  }

  /// Draws the labels at the vertical pixel position [fixedPosition] minus [offset], one per entry along the
  /// horizontal direction.
  @override
  @protected
  void drawYLabels(
    ui.Canvas c,
    double fixedPosition,
    Float32List positions,
    double offset,
  ) {
    paintAxisLabels.typeface = yAxis.typeface;
    paintAxisLabels.textSize = Utils.convertDpToPixel(yAxis.textSize);
    paintAxisLabels.color = yAxis.textColor;

    final from = yAxis.isDrawBottomYLabelEntryEnabled ? 0 : 1;
    // The positions were built from the entry count, which another thread can change in between.
    final to = math.min(
      yAxis.isDrawTopYLabelEntryEnabled
          ? yAxis.entryCount
          : yAxis.entryCount - 1,
      positions.length ~/ 2,
    );

    final xOffset = Utils.convertDpToPixel(yAxis.labelXOffset);

    for (var i = from; i < to; i++) {
      final text = yAxis.getFormattedLabel(i);
      c.drawText(
        text,
        positions[i * 2],
        fixedPosition - offset + xOffset,
        paintAxisLabels,
      );
    }
  }

  /// Fills the x values of the pairs instead of the y values.
  @override
  @protected
  Float32List getTransformedPositions() {
    if (getTransformedPositionsBuffer.length != yAxis.entryCount * 2) {
      getTransformedPositionsBuffer = Float32List(yAxis.entryCount * 2);
    }
    final positions = getTransformedPositionsBuffer;

    for (var i = 0; i < positions.length; i += 2) {
      positions[i] = yAxis.entries[i ~/ 2];
    }

    transformer?.pointValuesToPixel(positions);
    return positions;
  }

  /// Widened horizontally instead of vertically, because the grid lines are vertical here.
  @override
  MutableRect get gridClippingRect {
    gridClippingRectBuffer.setFrom(viewPortHandler.contentRect);
    gridClippingRectBuffer.inset(
      -Utils.convertDpToPixel(axis.gridLineWidth),
      0,
    );
    return gridClippingRectBuffer;
  }

  /// Builds a vertical grid line at the pixel x of the entry over the content height.
  @override
  @protected
  ui.Path linePath(ui.Path p, int i, Float32List positions) {
    p.moveTo(positions[i], viewPortHandler.contentTop);
    p.lineTo(positions[i], viewPortHandler.contentBottom);
    return p;
  }

  final ui.Path _drawZeroLinePathBuffer = ui.Path();

  /// Draws a vertical line over the content height at the pixel position of the value 0.
  @override
  @protected
  void drawZeroLine(ui.Canvas c) {
    final transformer = this.transformer;
    if (transformer == null) return;

    final clipRestoreCount = c.getSaveCount();
    c.save();
    zeroLineClippingRect.setFrom(viewPortHandler.contentRect);
    zeroLineClippingRect.inset(-Utils.convertDpToPixel(yAxis.zeroLineWidth), 0);
    c.clipRectM(zeroLineClippingRect);

    final pos = transformer.getPixelForValues(0, 0);

    zeroLinePaint.color = yAxis.zeroLineColor;
    zeroLinePaint.strokeWidth = Utils.convertDpToPixel(yAxis.zeroLineWidth);

    final zeroLinePath = _drawZeroLinePathBuffer;
    zeroLinePath.reset();

    zeroLinePath.moveTo(pos.x - 1, viewPortHandler.contentTop);
    zeroLinePath.lineTo(pos.x - 1, viewPortHandler.contentBottom);

    c.drawPathP(zeroLinePath, zeroLinePaint);

    c.restoreToCount(clipRestoreCount);
  }

  final ui.Path _renderLimitLinesPathBuffer = ui.Path();

  final Float32List _limitLinesBuffer = Float32List(4);

  /// Draws each enabled limit line as a vertical line at the pixel x of its limit value and, while the line is
  /// inside the content rectangle, its label at the top or bottom of the content rectangle, moved sideways where
  /// needed so it stays inside the content rectangle.
  @override
  void renderLimitLines(ui.Canvas c) {
    final limitLines = yAxis.limitLines;
    if (limitLines.isEmpty) return;

    final pts = _limitLinesBuffer;
    pts.fillRange(0, pts.length, 0);
    final limitLinePath = _renderLimitLinesPathBuffer;
    limitLinePath.reset();

    for (final l in limitLines) {
      if (!l.isEnabled) continue;

      final clipRestoreCount = c.getSaveCount();
      c.save();
      limitLineClippingRect.setFrom(viewPortHandler.contentRect);
      limitLineClippingRect.inset(-Utils.convertDpToPixel(l.lineWidth), 0);
      c.clipRectM(limitLineClippingRect);

      pts[0] = l.limit;
      pts[2] = l.limit;

      transformer?.pointValuesToPixel(pts);

      pts[1] = viewPortHandler.contentTop;
      pts[3] = viewPortHandler.contentBottom;

      limitLinePath.moveTo(pts[0], pts[1]);
      limitLinePath.lineTo(pts[2], pts[3]);

      limitLinePaint.style = PaintStyle.STROKE;
      limitLinePaint.color = l.lineColor;
      limitLinePaint.pathEffect = l.dashPathEffect;
      limitLinePaint.strokeWidth = Utils.convertDpToPixel(l.lineWidth);

      c.drawPathP(limitLinePath, limitLinePaint);
      limitLinePath.reset();

      final label = l.label;
      final lineVisible =
          pts[0] >= limitLineClippingRect.left &&
          pts[0] <= limitLineClippingRect.right;

      if (label.isNotEmpty && lineVisible) {
        limitLinePaint.style = l.textStyle;
        limitLinePaint.pathEffect = null;
        limitLinePaint.color = l.textColor;
        limitLinePaint.typeface = l.typeface;
        limitLinePaint.strokeWidth = 0.5;
        limitLinePaint.textSize = Utils.convertDpToPixel(l.textSize);

        final xOffset =
            Utils.convertDpToPixel(l.lineWidth) +
            Utils.convertDpToPixel(l.xOffset);
        final yOffset =
            Utils.convertDpToPixel(2) + Utils.convertDpToPixel(l.yOffset);
        final labelWidth = Utils.calcTextWidth(limitLinePaint, label);
        final rightX = math.min(
          pts[0] + xOffset,
          viewPortHandler.contentRight - labelWidth,
        );
        final leftX = math.max(
          pts[0] - xOffset,
          viewPortHandler.contentLeft + labelWidth,
        );

        switch (l.labelPosition) {
          case LimitLabelPosition.RIGHT_TOP:
            final labelLineHeight = Utils.calcTextHeight(limitLinePaint, label);
            limitLinePaint.textAlign = PaintAlign.LEFT;
            c.drawText(
              label,
              rightX,
              viewPortHandler.contentTop + yOffset + labelLineHeight,
              limitLinePaint,
            );
          case LimitLabelPosition.RIGHT_BOTTOM:
            limitLinePaint.textAlign = PaintAlign.LEFT;
            c.drawText(
              label,
              rightX,
              viewPortHandler.contentBottom - yOffset,
              limitLinePaint,
            );
          case LimitLabelPosition.LEFT_TOP:
            limitLinePaint.textAlign = PaintAlign.RIGHT;
            final labelLineHeight = Utils.calcTextHeight(limitLinePaint, label);
            c.drawText(
              label,
              leftX,
              viewPortHandler.contentTop + yOffset + labelLineHeight,
              limitLinePaint,
            );
          case LimitLabelPosition.LEFT_BOTTOM:
            limitLinePaint.textAlign = PaintAlign.RIGHT;
            c.drawText(
              label,
              leftX,
              viewPortHandler.contentBottom - yOffset,
              limitLinePaint,
            );
        }
      }

      c.restoreToCount(clipRestoreCount);
    }
  }
}
