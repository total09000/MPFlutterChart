// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/XAxisRenderer.kt
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../components/limit_line.dart';
import '../components/x_axis.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../utils/f_size.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/transformer.dart';
import '../utils/utils.dart';
import '../utils/view_port_handler.dart';
import 'axis_renderer.dart';

/// Draws the x axis of charts with axes: the labels above or below the content rectangle, vertical grid lines,
/// the axis line along the top or bottom edge and vertical limit lines. Assign a subclass to
/// `chart.rendererXAxis` to change the drawing.
class XAxisRenderer extends AxisRenderer {
  /// Creates a renderer for [xAxis]; [transformer] converts axis values to pixels.
  XAxisRenderer(
    ViewPortHandler viewPortHandler,
    this.xAxis,
    Transformer? transformer,
  ) : super(viewPortHandler, transformer, xAxis) {
    paintAxisLabels.color = const ui.Color(0xFF000000);
    paintAxisLabels.textAlign = PaintAlign.CENTER;
    paintAxisLabels.textSize = Utils.convertDpToPixel(10);
  }

  /// The x axis this renderer draws.
  @protected
  final XAxis xAxis;

  /// Copies the grid color, grid line width (dp) and dash effect of the axis into [paintGrid].
  @protected
  void setupGridPaint() {
    paintGrid.color = xAxis.gridColor;
    paintGrid.strokeWidth = Utils.convertDpToPixel(xAxis.gridLineWidth);
    paintGrid.pathEffect = xAxis.gridDashPathEffect;
  }

  /// Like [AxisRenderer.computeAxis], but along x: when zoomed in horizontally the range is taken from the left and
  /// right edge of the content rectangle.
  @override
  void computeAxis(double min, double max, bool inverted) {
    var newMin = min;
    var newMax = max;

    final transformer = this.transformer;
    if (transformer != null &&
        viewPortHandler.contentWidth > 10 &&
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

      if (inverted) {
        newMin = toKotlinFloat(p2.x);
        newMax = toKotlinFloat(p1.x);
      } else {
        newMin = toKotlinFloat(p1.x);
        newMax = toKotlinFloat(p2.x);
      }
    }

    computeAxisValues(newMin, newMax);
  }

  /// Computes the label values and the label size with [computeSize]. The size is measured first as well, because
  /// the interval between two labels is kept at least as wide as a label.
  @override
  void computeAxisValues(double min, double max) {
    computeSize();
    super.computeAxisValues(min, max);
    computeSize();
  }

  /// Keeps the labels at least one label width apart, so that neighbouring labels do not overlap.
  @override
  double minimumInterval(double range) {
    final contentWidth = viewPortHandler.contentWidth;
    if (contentWidth <= 0) return 0.0;
    return xAxis.labelRotatedWidth * range / contentWidth;
  }

  /// Measures the longest label of the axis with its typeface and text size and stores the plain and rotated label
  /// width and height (pixels) on the axis, which the chart uses to reserve space for the labels.
  @protected
  void computeSize() {
    final longest = xAxis.longestLabel;

    paintAxisLabels.typeface = xAxis.typeface;
    paintAxisLabels.textSize = Utils.convertDpToPixel(xAxis.textSize);

    final labelSize = Utils.calcTextSize(paintAxisLabels, longest);

    final labelWidth = labelSize.width;
    final labelHeight = Utils.calcTextHeight(paintAxisLabels, 'Q');

    final labelRotatedSize = Utils.getSizeOfRotatedRectangleByDegrees(
      labelWidth,
      labelHeight,
      xAxis.labelRotationAngle,
    );

    // Kotlin's roundToInt in device px.
    xAxis.labelWidth = roundToDevicePx(labelWidth);
    xAxis.labelHeight = roundToDevicePx(labelHeight);
    xAxis.labelRotatedWidth = roundToDevicePx(labelRotatedSize.width);
    xAxis.labelRotatedHeight = roundToDevicePx(labelRotatedSize.height);

    FSize.recycleInstance(labelRotatedSize);
    FSize.recycleInstance(labelSize);
  }

  @override
  void renderAxisLabels(ui.Canvas c) {
    if (!xAxis.isEnabled || !xAxis.isDrawLabelsEnabled) return;

    final yoffset = Utils.convertDpToPixel(xAxis.yOffset);

    paintAxisLabels.typeface = xAxis.typeface;
    paintAxisLabels.textSize = Utils.convertDpToPixel(xAxis.textSize);
    paintAxisLabels.color = xAxis.textColor;

    final pointF = MPPointF.getInstance(0, 0);
    switch (xAxis.position) {
      case XAxisPosition.TOP:
        pointF.x = 0.5;
        pointF.y = 1.0;
        drawLabels(c, viewPortHandler.contentTop - yoffset, pointF);
      case XAxisPosition.TOP_INSIDE:
        pointF.x = 0.5;
        pointF.y = 1.0;
        drawLabels(
          c,
          viewPortHandler.contentTop + yoffset + xAxis.labelRotatedHeight,
          pointF,
        );
      case XAxisPosition.BOTTOM:
        pointF.x = 0.5;
        pointF.y = 0.0;
        drawLabels(c, viewPortHandler.contentBottom + yoffset, pointF);
      case XAxisPosition.BOTTOM_INSIDE:
        pointF.x = 0.5;
        pointF.y = 0.0;
        drawLabels(
          c,
          viewPortHandler.contentBottom - yoffset - xAxis.labelRotatedHeight,
          pointF,
        );
      case XAxisPosition.BOTH_SIDED:
        pointF.x = 0.5;
        pointF.y = 1.0;
        drawLabels(c, viewPortHandler.contentTop - yoffset, pointF);
        pointF.x = 0.5;
        pointF.y = 0.0;
        drawLabels(c, viewPortHandler.contentBottom + yoffset, pointF);
    }
    MPPointF.recycleInstance(pointF);
  }

  @override
  void renderAxisLine(ui.Canvas c) {
    if (!xAxis.isDrawAxisLineEnabled || !xAxis.isEnabled) return;

    paintAxisLine.color = xAxis.axisLineColor;
    paintAxisLine.strokeWidth = Utils.convertDpToPixel(xAxis.axisLineWidth);
    paintAxisLine.pathEffect = xAxis.axisLineDashPathEffect;

    if (xAxis.position == XAxisPosition.TOP ||
        xAxis.position == XAxisPosition.TOP_INSIDE ||
        xAxis.position == XAxisPosition.BOTH_SIDED) {
      c.drawLineP(
        viewPortHandler.contentLeft,
        viewPortHandler.contentTop,
        viewPortHandler.contentRight,
        viewPortHandler.contentTop,
        paintAxisLine,
      );
    }

    if (xAxis.position == XAxisPosition.BOTTOM ||
        xAxis.position == XAxisPosition.BOTTOM_INSIDE ||
        xAxis.position == XAxisPosition.BOTH_SIDED) {
      c.drawLineP(
        viewPortHandler.contentLeft,
        viewPortHandler.contentBottom,
        viewPortHandler.contentRight,
        viewPortHandler.contentBottom,
        paintAxisLine,
      );
    }
  }

  /// Draws all axis labels inside the visible x range at the vertical pixel position [pos]. When the axis avoids
  /// first and last clipping, the outer labels are shifted inwards so they stay inside the chart.
  ///
  /// [anchor] says which point of a label sits on its position, as fractions of the label size: (0.5, 1) is the
  /// bottom center, (0.5, 0) the top center.
  @protected
  void drawLabels(ui.Canvas c, double pos, MPPointF anchor) {
    final labelRotationAngleDegrees = xAxis.labelRotationAngle;
    final centeringEnabled = xAxis.isCenterAxisLabelsEnabled;

    final positions = Float32List(xAxis.entryCount * 2);

    for (var i = 0; i < positions.length; i += 2) {
      positions[i] = centeringEnabled
          ? xAxis.centeredEntries[i ~/ 2]
          : xAxis.entries[i ~/ 2];
    }

    transformer?.pointValuesToPixel(positions);

    for (var i = 0; i < positions.length; i += 2) {
      var x = positions[i];

      if (viewPortHandler.isInBoundsX(x)) {
        final label = xAxis.valueFormatter.getFormattedValue(
          xAxis.entries[i ~/ 2],
          xAxis,
        );

        if (xAxis.isAvoidFirstLastClippingEnabled) {
          if (i ~/ 2 == xAxis.entryCount - 1 && xAxis.entryCount > 1) {
            final width = Utils.calcTextWidth(paintAxisLabels, label);
            if (width > viewPortHandler.offsetRight * 2 &&
                x + width > viewPortHandler.chartWidth) {
              x -= width / 2;
            }
          } else if (i == 0) {
            final width = Utils.calcTextWidth(paintAxisLabels, label);
            x += width / 2;
          }
        }

        drawLabel(c, label, x, pos, anchor, labelRotationAngleDegrees);
      }
    }
  }

  /// Draws one label with [paintAxisLabels] at the pixel position ([x], [y]), rotated by [angleDegrees] around
  /// [anchor] (fractions of the label size).
  @protected
  void drawLabel(
    ui.Canvas c,
    String formattedLabel,
    double x,
    double y,
    MPPointF anchor,
    double angleDegrees,
  ) {
    Utils.drawXAxisValue(
      c,
      formattedLabel,
      x,
      y,
      paintAxisLabels,
      anchor,
      angleDegrees,
    );
  }

  /// Path reused for drawing grid lines.
  @protected
  final ui.Path renderGridLinesPath = ui.Path();

  /// Pixel positions of the grid lines as x, y pairs; resized to twice the entry count of the axis.
  @protected
  Float32List renderGridLinesBuffer = Float32List(2);

  /// Draws one vertical grid line per axis entry, clipped to [gridClippingRect].
  @override
  void renderGridLines(ui.Canvas c) {
    if (!xAxis.isDrawGridLinesEnabled || !xAxis.isEnabled) return;

    final clipRestoreCount = c.getSaveCount();
    c.save();
    c.clipRectM(gridClippingRect);

    if (renderGridLinesBuffer.length != axis.entryCount * 2) {
      renderGridLinesBuffer = Float32List(xAxis.entryCount * 2);
    }
    final positions = renderGridLinesBuffer;

    for (var i = 0; i < positions.length; i += 2) {
      positions[i] = xAxis.entries[i ~/ 2];
      positions[i + 1] = xAxis.entries[i ~/ 2];
    }

    transformer?.pointValuesToPixel(positions);

    setupGridPaint();

    final gridLinePath = renderGridLinesPath;
    gridLinePath.reset();

    for (var i = 0; i < positions.length; i += 2) {
      drawGridLine(c, positions[i], positions[i + 1], gridLinePath);
    }

    c.restoreToCount(clipRestoreCount);
  }

  /// Backing rectangle of [gridClippingRect].
  @protected
  final MutableRect gridClippingRectBuffer = MutableRect();

  /// The content rectangle widened horizontally by the grid line width, in pixels, so grid lines at the edges are
  /// not cut in half.
  MutableRect get gridClippingRect {
    gridClippingRectBuffer.setFrom(viewPortHandler.contentRect);
    gridClippingRectBuffer.inset(
      -Utils.convertDpToPixel(axis.gridLineWidth),
      0,
    );
    return gridClippingRectBuffer;
  }

  /// Draws one vertical grid line at the pixel position [x] over the content height, using [gridLinePath] as a
  /// scratch path. [y] is not used here.
  @protected
  void drawGridLine(ui.Canvas c, double x, double y, ui.Path gridLinePath) {
    gridLinePath.moveTo(x, viewPortHandler.contentBottom);
    gridLinePath.lineTo(x, viewPortHandler.contentTop);

    c.drawPathP(gridLinePath, paintGrid);

    gridLinePath.reset();
  }

  /// Buffer for the pixel position of the limit line being drawn.
  @protected
  final Float32List renderLimitLinesBuffer = Float32List(2);

  /// Clip rectangle for the limit line being drawn, the content rectangle widened by the line width.
  @protected
  final MutableRect limitLineClippingRect = MutableRect();

  /// Draws each enabled limit line as a vertical line at the pixel x of its limit value and, while the line is
  /// inside the content rectangle, its label at the top or bottom of the content rectangle.
  @override
  void renderLimitLines(ui.Canvas c) {
    final limitLines = xAxis.limitLines;
    if (limitLines.isEmpty) return;

    final position = renderLimitLinesBuffer;
    position[0] = 0;
    position[1] = 0;

    for (final l in limitLines) {
      if (!l.isEnabled) continue;

      final clipRestoreCount = c.getSaveCount();
      c.save();
      limitLineClippingRect.setFrom(viewPortHandler.contentRect);
      limitLineClippingRect.inset(-Utils.convertDpToPixel(l.lineWidth), 0);
      c.clipRectM(limitLineClippingRect);

      position[0] = l.limit;
      position[1] = 0;

      transformer?.pointValuesToPixel(position);

      renderLimitLineLine(c, l, position);
      if (position[0] >= limitLineClippingRect.left &&
          position[0] <= limitLineClippingRect.right) {
        renderLimitLineLabel(
          c,
          l,
          position,
          2 + Utils.convertDpToPixel(l.yOffset),
        );
      }

      c.restoreToCount(clipRestoreCount);
    }
  }

  final Float32List _limitLineSegmentsBuffer = Float32List(4);

  final ui.Path _limitLinePath = ui.Path();

  /// Draws the line of [limitLine] over the content height with its color, width (dp) and dash effect.
  ///
  /// [position] is the pixel position of the limit value, x at index 0.
  void renderLimitLineLine(
    ui.Canvas c,
    LimitLine limitLine,
    Float32List position,
  ) {
    _limitLineSegmentsBuffer[0] = position[0];
    _limitLineSegmentsBuffer[1] = viewPortHandler.contentTop;
    _limitLineSegmentsBuffer[2] = position[0];
    _limitLineSegmentsBuffer[3] = viewPortHandler.contentBottom;

    _limitLinePath.reset();
    _limitLinePath.moveTo(
      _limitLineSegmentsBuffer[0],
      _limitLineSegmentsBuffer[1],
    );
    _limitLinePath.lineTo(
      _limitLineSegmentsBuffer[2],
      _limitLineSegmentsBuffer[3],
    );

    limitLinePaint.style = PaintStyle.STROKE;
    limitLinePaint.color = limitLine.lineColor;
    limitLinePaint.strokeWidth = Utils.convertDpToPixel(limitLine.lineWidth);
    limitLinePaint.pathEffect = limitLine.dashPathEffect;

    c.drawPathP(_limitLinePath, limitLinePaint);
  }

  /// Draws the label of [limitLine] next to its line, at the corner given by its label position, moved sideways
  /// where needed so it stays inside the content rectangle. Does nothing for an empty label.
  ///
  /// [position] is the pixel position of the limit value, x at index 0; [yOffset] the distance in pixels between
  /// the label and the top or bottom content edge.
  void renderLimitLineLabel(
    ui.Canvas c,
    LimitLine limitLine,
    Float32List position,
    double yOffset,
  ) {
    final label = limitLine.label;

    if (label.isNotEmpty) {
      limitLinePaint.style = limitLine.textStyle;
      limitLinePaint.pathEffect = null;
      limitLinePaint.color = limitLine.textColor;
      limitLinePaint.strokeWidth = 0.5;
      limitLinePaint.textSize = Utils.convertDpToPixel(limitLine.textSize);
      limitLinePaint.typeface = limitLine.typeface;

      final xOffset =
          Utils.convertDpToPixel(limitLine.lineWidth) +
          Utils.convertDpToPixel(limitLine.xOffset);
      final labelWidth = Utils.calcTextWidth(limitLinePaint, label);
      final rightX = math.min(
        position[0] + xOffset,
        viewPortHandler.contentRight - labelWidth,
      );
      final leftX = math.max(
        position[0] - xOffset,
        viewPortHandler.contentLeft + labelWidth,
      );

      switch (limitLine.labelPosition) {
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
  }
}
