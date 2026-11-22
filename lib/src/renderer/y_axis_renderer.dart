// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/YAxisRenderer.kt
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../components/limit_line.dart';
import '../components/y_axis.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../utils/mp_point_f.dart';
import '../utils/transformer.dart';
import '../utils/utils.dart';
import '../utils/view_port_handler.dart';
import 'axis_renderer.dart';

/// Draws a y axis of charts with axes: the labels along the left or right edge (inside or outside the content
/// rectangle), horizontal grid lines, the zero line, the axis line and horizontal limit lines. Assign a subclass
/// to `chart.rendererLeftYAxis` or `chart.rendererRightYAxis` to change the drawing.
class YAxisRenderer extends AxisRenderer {
  /// Creates a renderer for [yAxis]; [transformer] converts axis values to pixels.
  YAxisRenderer(
    ViewPortHandler viewPortHandler,
    this.yAxis,
    Transformer? transformer,
  ) : super(viewPortHandler, transformer, yAxis) {
    paintAxisLabels.color = const ui.Color(0xFF000000);
    paintAxisLabels.textSize = Utils.convertDpToPixel(10);
  }

  /// The y axis this renderer draws.
  @protected
  final YAxis yAxis;

  /// Paint for the line at the value 0; color and width (dp) are copied from the axis when it is drawn.
  @protected
  final ChartPaint zeroLinePaint = ChartPaint()
    ..color = const ui.Color(0xFF888888)
    ..strokeWidth = 1
    ..style = PaintStyle.STROKE;

  @override
  void renderAxisLabels(ui.Canvas c) {
    if (!yAxis.isEnabled || !yAxis.isDrawLabelsEnabled) return;

    final positions = getTransformedPositions();

    paintAxisLabels.typeface = yAxis.typeface;
    paintAxisLabels.textSize = Utils.convertDpToPixel(yAxis.textSize);
    paintAxisLabels.color = yAxis.textColor;

    final xoffset = Utils.convertDpToPixel(yAxis.xOffset);
    final yoffset =
        Utils.calcTextHeight(paintAxisLabels, 'A') / 2.5 +
        Utils.convertDpToPixel(yAxis.yOffset);

    final dependency = yAxis.axisDependency;
    final labelPosition = yAxis.labelPosition;

    final double xPos;
    if (dependency == AxisDependency.LEFT) {
      if (labelPosition == YAxisLabelPosition.OUTSIDE_CHART) {
        paintAxisLabels.textAlign = PaintAlign.RIGHT;
        xPos = viewPortHandler.offsetLeft - xoffset;
      } else {
        paintAxisLabels.textAlign = PaintAlign.LEFT;
        xPos = viewPortHandler.offsetLeft + xoffset;
      }
    } else {
      if (labelPosition == YAxisLabelPosition.OUTSIDE_CHART) {
        paintAxisLabels.textAlign = PaintAlign.LEFT;
        xPos = viewPortHandler.contentRight + xoffset;
      } else {
        paintAxisLabels.textAlign = PaintAlign.RIGHT;
        xPos = viewPortHandler.contentRight - xoffset;
      }
    }

    drawYLabels(c, xPos, positions, yoffset);
  }

  @override
  void renderAxisLine(ui.Canvas c) {
    if (!yAxis.isEnabled || !yAxis.isDrawAxisLineEnabled) return;

    paintAxisLine.color = yAxis.axisLineColor;
    paintAxisLine.strokeWidth = Utils.convertDpToPixel(yAxis.axisLineWidth);

    if (yAxis.axisDependency == AxisDependency.LEFT) {
      c.drawLineP(
        viewPortHandler.contentLeft,
        viewPortHandler.contentTop,
        viewPortHandler.contentLeft,
        viewPortHandler.contentBottom,
        paintAxisLine,
      );
    } else {
      c.drawLineP(
        viewPortHandler.contentRight,
        viewPortHandler.contentTop,
        viewPortHandler.contentRight,
        viewPortHandler.contentBottom,
        paintAxisLine,
      );
    }
  }

  /// Draws the axis labels at the horizontal pixel position [fixedPosition], plus the label x offset of the axis,
  /// rotated by the label rotation angle of the axis. Skips the first or last entry when the axis disables drawing
  /// the bottom or top label.
  ///
  /// [positions] are the pixel positions of the axis entries as x, y pairs, from [getTransformedPositions];
  /// [offset] is the vertical pixel offset that centers the text on its grid line.
  @protected
  void drawYLabels(
    ui.Canvas c,
    double fixedPosition,
    Float32List positions,
    double offset,
  ) {
    final from = yAxis.isDrawBottomYLabelEntryEnabled ? 0 : 1;
    // The positions were built from the entry count, which another thread can change in between.
    final to = math.min(
      yAxis.isDrawTopYLabelEntryEnabled
          ? yAxis.entryCount
          : yAxis.entryCount - 1,
      positions.length ~/ 2,
    );

    final xOffset = Utils.convertDpToPixel(yAxis.labelXOffset);
    final angle = yAxis.labelRotationAngle;
    final anchorX = switch (paintAxisLabels.textAlign) {
      PaintAlign.RIGHT => 1.0,
      PaintAlign.CENTER => 0.5,
      _ => 0.0,
    };
    final anchor = MPPointF.getInstance(anchorX, 0.5);
    final rotatedOffset = Utils.convertDpToPixel(yAxis.yOffset);

    for (var i = from; i < to; i++) {
      final text = yAxis.getFormattedLabel(i);
      if (angle == 0) {
        c.drawText(
          text,
          fixedPosition + xOffset,
          positions[i * 2 + 1] + offset,
          paintAxisLabels,
        );
      } else {
        Utils.drawXAxisValue(
          c,
          text,
          fixedPosition + xOffset,
          positions[i * 2 + 1] + rotatedOffset,
          paintAxisLabels,
          anchor,
          angle,
        );
      }
    }

    MPPointF.recycleInstance(anchor);
  }

  /// Path reused for drawing grid lines.
  @protected
  final ui.Path renderGridLinesPath = ui.Path();

  /// Draws one horizontal grid line per axis entry, clipped to [gridClippingRect], and then the zero line when the
  /// axis enables it.
  @override
  void renderGridLines(ui.Canvas c) {
    if (!yAxis.isEnabled) return;

    if (yAxis.isDrawGridLinesEnabled) {
      final clipRestoreCount = c.getSaveCount();
      c.save();
      c.clipRectM(gridClippingRect);

      final positions = getTransformedPositions();

      paintGrid.color = yAxis.gridColor;
      paintGrid.strokeWidth = Utils.convertDpToPixel(yAxis.gridLineWidth);
      paintGrid.pathEffect = yAxis.gridDashPathEffect;

      final gridLinePath = renderGridLinesPath;
      gridLinePath.reset();

      for (var i = 0; i < positions.length; i += 2) {
        c.drawPathP(linePath(gridLinePath, i, positions), paintGrid);
        gridLinePath.reset();
      }

      c.restoreToCount(clipRestoreCount);
    }

    if (yAxis.isDrawZeroLineEnabled) {
      drawZeroLine(c);
    }
  }

  /// Backing rectangle of [gridClippingRect].
  @protected
  final MutableRect gridClippingRectBuffer = MutableRect();

  /// The content rectangle widened vertically by the grid line width, in pixels, so grid lines at the edges are
  /// not cut in half.
  MutableRect get gridClippingRect {
    gridClippingRectBuffer.setFrom(viewPortHandler.contentRect);
    gridClippingRectBuffer.inset(
      0,
      -Utils.convertDpToPixel(axis.gridLineWidth),
    );
    return gridClippingRectBuffer;
  }

  /// Builds the grid line of the entry at pair index [i] of [positions] (pixel x, y pairs) into [p] and returns it.
  /// The line runs from the left chart offset to the right edge of the content rectangle.
  @protected
  ui.Path linePath(ui.Path p, int i, Float32List positions) {
    p.moveTo(viewPortHandler.offsetLeft, positions[i + 1]);
    p.lineTo(viewPortHandler.contentRight, positions[i + 1]);
    return p;
  }

  /// Buffer reused by [getTransformedPositions]; resized to twice the entry count of the axis.
  @protected
  Float32List getTransformedPositionsBuffer = Float32List(2);

  /// Returns the pixel positions of all axis entries as x, y pairs. Only the y values are filled; the x values are
  /// unspecified (as in Kotlin, the reused array keeps the converted x values of the previous call, which are
  /// converted again and grow from call to call). The y values stay valid because the transformer's matrices have no
  /// skew and `Matrix.mapPoints` then maps each axis on its own, as Android's `SkMatrix` does; a subclass
  /// that maps through a skewed matrix must set the x values first. The array is reused between calls.
  @protected
  Float32List getTransformedPositions() {
    if (getTransformedPositionsBuffer.length != yAxis.entryCount * 2) {
      getTransformedPositionsBuffer = Float32List(yAxis.entryCount * 2);
    }
    final positions = getTransformedPositionsBuffer;

    for (var i = 0; i < positions.length; i += 2) {
      positions[i + 1] = yAxis.entries[i ~/ 2];
    }

    transformer?.pointValuesToPixel(positions);
    return positions;
  }

  /// Path reused for the zero line.
  @protected
  final ui.Path drawZeroLinePath = ui.Path();

  /// Clip rectangle for the zero line, the content rectangle widened by the zero line width.
  @protected
  final MutableRect zeroLineClippingRect = MutableRect();

  /// Draws a horizontal line over the content width at the pixel position of the value 0, with the zero line
  /// color and width (dp) of the axis. Does nothing without a transformer.
  @protected
  void drawZeroLine(ui.Canvas c) {
    final transformer = this.transformer;
    if (transformer == null) return;

    final clipRestoreCount = c.getSaveCount();
    c.save();
    zeroLineClippingRect.setFrom(viewPortHandler.contentRect);
    zeroLineClippingRect.inset(0, -Utils.convertDpToPixel(yAxis.zeroLineWidth));
    c.clipRectM(zeroLineClippingRect);

    final pos = transformer.getPixelForValues(0, 0);

    zeroLinePaint.color = yAxis.zeroLineColor;
    zeroLinePaint.strokeWidth = Utils.convertDpToPixel(yAxis.zeroLineWidth);

    final zeroLinePath = drawZeroLinePath;
    zeroLinePath.reset();

    zeroLinePath.moveTo(viewPortHandler.contentLeft, pos.y);
    zeroLinePath.lineTo(viewPortHandler.contentRight, pos.y);

    c.drawPathP(zeroLinePath, zeroLinePaint);

    c.restoreToCount(clipRestoreCount);
  }

  /// Path reused for drawing limit lines.
  ///
  /// Kotlin's property `renderLimitLines`; renamed because Dart cannot have a field and a method
  /// ([renderLimitLines]) of the same name.
  @protected
  final ui.Path renderLimitLinesPath = ui.Path();

  /// Buffer for the pixel position of the limit line being drawn.
  @protected
  final Float32List renderLimitLinesBuffer = Float32List(2);

  /// Clip rectangle for the limit line being drawn, the content rectangle widened by the line width.
  @protected
  final MutableRect limitLineClippingRect = MutableRect();

  /// Draws each enabled limit line as a horizontal line at the pixel y of its limit value and its label at the
  /// left or right of the content rectangle, above or below the line. A label that would stick out of the content
  /// rectangle is moved inside it; the label of a line outside the content rectangle is not drawn.
  @override
  void renderLimitLines(ui.Canvas c) {
    final limitLines = yAxis.limitLines;
    if (limitLines.isEmpty) return;

    final pts = renderLimitLinesBuffer;
    pts[0] = 0;
    pts[1] = 0;
    final limitLinePath = renderLimitLinesPath;
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
        limitLinePaint.typeface = l.typeface;
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
