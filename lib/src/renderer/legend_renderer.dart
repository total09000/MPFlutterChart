// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/LegendRenderer.kt
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../components/legend.dart';
import '../components/legend_entry.dart';
import '../data/chart_data.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../interfaces/datasets/i_bar_data_set.dart';
import '../interfaces/datasets/i_candle_data_set.dart';
import '../interfaces/datasets/i_pie_data_set.dart';
import '../utils/color_template.dart';
import '../utils/utils.dart';
import 'renderer.dart';

/// Draws the [Legend] of a chart. [computeLegend] builds the legend entries from the data sets and measures the
/// legend; [renderLegend] then draws the forms and labels at the position given by the legend's alignment,
/// orientation and direction. Assign a subclass to `chart.legendRenderer` to change the drawing.
class LegendRenderer extends Renderer {
  /// Creates a renderer for [legend].
  LegendRenderer(super.viewPortHandler, this.legend);

  /// The legend this renderer draws.
  @protected
  final Legend legend;

  /// Paint for the legend labels; typeface, text size (dp) and color are copied from the legend before drawing.
  /// Left aligned, 9 dp by default.
  ChartPaint labelPaint = ChartPaint()
    ..textSize = Utils.convertDpToPixel(9)
    ..textAlign = PaintAlign.LEFT;

  /// Paint for the legend forms (circle, square or line); restyled per entry while drawing.
  final ChartPaint formPaint = ChartPaint()..style = PaintStyle.FILL;

  /// The entries built from the data by [computeLegend], followed by the extra entries of the legend.
  @protected
  final List<LegendEntry> computedEntries = <LegendEntry>[];

  /// Builds the legend entries from the data sets of [data], unless the legend is custom: one entry per color of a
  /// data set, with stack labels for stacked bar sets, entry labels for pie sets and the decreasing and increasing
  /// colors for candle sets, plus the extra entries of the legend. Then measures the legend with [labelPaint] so
  /// the chart can reserve space for it.
  void computeLegend(ChartData data) {
    if (!legend.isLegendCustom) {
      computedEntries.clear();

      for (var i = 0; i < data.dataSetCount; i++) {
        final dataSet = data.getDataSetByIndex(i);
        if (dataSet == null) continue;

        final clrs = dataSet.colors;
        final entryCount = dataSet.entryCount;

        if (dataSet is IBarDataSet && dataSet.isStacked) {
          final sLabels = dataSet.stackLabels;
          final minEntries = math.min(clrs.length, dataSet.stackSize);

          for (var j = 0; j < minEntries; j++) {
            final String? label;
            if (sLabels.isNotEmpty) {
              final labelIndex = j % minEntries;
              label = labelIndex < sLabels.length ? sLabels[labelIndex] : null;
            } else {
              label = null;
            }

            computedEntries.add(
              LegendEntry(
                label,
                dataSet.form,
                dataSet.formSize,
                dataSet.formLineWidth,
                dataSet.formLineDashEffect,
                clrs[j],
              ),
            );
          }

          computedEntries.add(
            LegendEntry(
              dataSet.label,
              LegendForm.NONE,
              double.nan,
              double.nan,
              null,
              ColorTemplate.COLOR_NONE,
            ),
          );
        } else if (dataSet is IPieDataSet) {
          var j = 0;
          while (j < clrs.length && j < entryCount) {
            computedEntries.add(
              LegendEntry(
                dataSet.getEntryForIndex(j).label?.replaceAll('\n', ' '),
                dataSet.form,
                dataSet.formSize,
                dataSet.formLineWidth,
                dataSet.formLineDashEffect,
                clrs[j],
              ),
            );
            j++;
          }

          if (dataSet.label.trim().isNotEmpty) {
            computedEntries.add(
              LegendEntry(
                dataSet.label,
                LegendForm.NONE,
                double.nan,
                double.nan,
                null,
                ColorTemplate.COLOR_NONE,
              ),
            );
          }
        } else if (dataSet is ICandleDataSet &&
            dataSet.decreasingColor != ColorTemplate.COLOR_NONE) {
          final decreasingColor = dataSet.decreasingColor;
          final increasingColor = dataSet.increasingColor;

          computedEntries.add(
            LegendEntry(
              null,
              dataSet.form,
              dataSet.formSize,
              dataSet.formLineWidth,
              dataSet.formLineDashEffect,
              decreasingColor,
            ),
          );
          computedEntries.add(
            LegendEntry(
              dataSet.label,
              dataSet.form,
              dataSet.formSize,
              dataSet.formLineWidth,
              dataSet.formLineDashEffect,
              increasingColor,
            ),
          );
        } else {
          var j = 0;
          while (j < clrs.length && j < entryCount) {
            final label = j < clrs.length - 1 && j < entryCount - 1
                ? null
                : dataSet.label;
            computedEntries.add(
              LegendEntry(
                label,
                dataSet.form,
                dataSet.formSize,
                dataSet.formLineWidth,
                dataSet.formLineDashEffect,
                clrs[j],
              ),
            );
            j++;
          }
        }
      }

      computedEntries.addAll(legend.extraEntries);

      legend.setComputedEntries(computedEntries);
    }

    final tf = legend.typeface;
    if (tf != null) labelPaint.typeface = tf;

    labelPaint.textSize = Utils.convertDpToPixel(legend.textSize);
    labelPaint.color = legend.textColor;

    legend.calculateDimensions(labelPaint, viewPortHandler);
  }

  final FontMetrics _legendFontMetrics = FontMetrics();

  /// Draws the legend onto [c]. Does nothing when the legend is disabled.
  void renderLegend(ui.Canvas c) {
    if (!legend.isEnabled) return;

    final tf = legend.typeface;
    if (tf != null) labelPaint.typeface = tf;

    labelPaint.textSize = Utils.convertDpToPixel(legend.textSize);
    labelPaint.color = legend.textColor;

    final labelLineHeight = Utils.getLineHeight(labelPaint, _legendFontMetrics);
    final labelLineSpacing =
        Utils.getLineSpacing(labelPaint, _legendFontMetrics) +
        Utils.convertDpToPixel(legend.yEntrySpace);
    final formYOffset =
        labelLineHeight - Utils.calcTextHeight(labelPaint, 'ABC') / 2;

    final entries = legend.entries;

    final formToTextSpace = Utils.convertDpToPixel(legend.formToTextSpace);
    final xEntrySpace = Utils.convertDpToPixel(legend.xEntrySpace);
    final orientation = legend.orientation;
    final horizontalAlignment = legend.horizontalAlignment;
    final verticalAlignment = legend.verticalAlignment;
    final direction = legend.direction;
    final defaultFormSize = Utils.convertDpToPixel(legend.formSize);
    final stackSpace = Utils.convertDpToPixel(legend.stackSpace);

    final yoffset = Utils.convertDpToPixel(legend.yOffset);
    final xoffset = Utils.convertDpToPixel(legend.xOffset);
    var originPosX = 0.0;

    switch (horizontalAlignment) {
      case LegendHorizontalAlignment.LEFT:
        originPosX = orientation == LegendOrientation.VERTICAL
            ? xoffset
            : viewPortHandler.contentLeft + xoffset;
        if (direction == LegendDirection.RIGHT_TO_LEFT) {
          originPosX += legend.neededWidth;
        }
      case LegendHorizontalAlignment.RIGHT:
        originPosX = orientation == LegendOrientation.VERTICAL
            ? viewPortHandler.chartWidth - xoffset
            : viewPortHandler.contentRight - xoffset;
        if (direction == LegendDirection.LEFT_TO_RIGHT) {
          originPosX -= legend.neededWidth;
        }
      case LegendHorizontalAlignment.CENTER:
        originPosX = orientation == LegendOrientation.VERTICAL
            ? viewPortHandler.chartWidth / 2
            : viewPortHandler.contentLeft + viewPortHandler.contentWidth / 2;

        originPosX += direction == LegendDirection.LEFT_TO_RIGHT
            ? xoffset
            : -xoffset;

        if (orientation == LegendOrientation.VERTICAL) {
          originPosX += direction == LegendDirection.LEFT_TO_RIGHT
              ? -legend.neededWidth / 2.0 + xoffset
              : legend.neededWidth / 2.0 - xoffset;
        }
    }

    switch (orientation) {
      case LegendOrientation.HORIZONTAL:
        final calculatedLineSizes = legend.calculatedLineSizes;
        final calculatedLabelSizes = legend.calculatedLabelSizes;
        final calculatedLabelBreakPoints = legend.calculatedLabelBreakPoints;

        var posX = originPosX;
        var posY = 0.0;

        switch (verticalAlignment) {
          case LegendVerticalAlignment.TOP:
            posY = yoffset;
          case LegendVerticalAlignment.BOTTOM:
            posY = viewPortHandler.chartHeight - yoffset - legend.neededHeight;
          case LegendVerticalAlignment.CENTER:
            posY =
                (viewPortHandler.chartHeight - legend.neededHeight) / 2 +
                yoffset;
        }

        var lineIndex = 0;

        for (var i = 0; i < entries.length; i++) {
          final e = entries[i];
          final drawingForm = e.form != LegendForm.NONE;
          final formSize = e.formSize.isNaN
              ? defaultFormSize
              : Utils.convertDpToPixel(e.formSize);

          if (i < calculatedLabelBreakPoints.length &&
              calculatedLabelBreakPoints[i]) {
            posX = originPosX;
            posY += labelLineHeight + labelLineSpacing;
          }

          if (posX == originPosX &&
              horizontalAlignment == LegendHorizontalAlignment.CENTER &&
              lineIndex < calculatedLineSizes.length) {
            posX +=
                (direction == LegendDirection.RIGHT_TO_LEFT
                    ? calculatedLineSizes[lineIndex].width
                    : -calculatedLineSizes[lineIndex].width) /
                2;
            lineIndex++;
          }

          final isStacked = e.label == null;

          if (drawingForm) {
            if (direction == LegendDirection.RIGHT_TO_LEFT) posX -= formSize;

            drawForm(c, posX, posY + formYOffset, e, legend);

            if (direction == LegendDirection.LEFT_TO_RIGHT) posX += formSize;
          }

          if (!isStacked) {
            if (drawingForm) {
              posX += direction == LegendDirection.RIGHT_TO_LEFT
                  ? -formToTextSpace
                  : formToTextSpace;
            }

            final label = e.label ?? '';
            // The sizes are only measured for a horizontal legend, so a legend that was switched to
            // horizontal, or whose entries were replaced, after the last pass has none for this entry.
            final labelWidth = i < calculatedLabelSizes.length
                ? calculatedLabelSizes[i].width
                : Utils.calcTextWidth(labelPaint, label);

            if (direction == LegendDirection.RIGHT_TO_LEFT) posX -= labelWidth;

            drawLabel(c, posX, posY + labelLineHeight, label);

            if (direction == LegendDirection.LEFT_TO_RIGHT) posX += labelWidth;

            posX += direction == LegendDirection.RIGHT_TO_LEFT
                ? -xEntrySpace
                : xEntrySpace;
          } else {
            posX += direction == LegendDirection.RIGHT_TO_LEFT
                ? -stackSpace
                : stackSpace;
          }
        }
      case LegendOrientation.VERTICAL:
        var stack = 0.0;
        var wasStacked = false;
        var posY = 0.0;

        switch (verticalAlignment) {
          case LegendVerticalAlignment.TOP:
            posY = horizontalAlignment == LegendHorizontalAlignment.CENTER
                ? 0.0
                : viewPortHandler.contentTop;
            posY += yoffset;
          case LegendVerticalAlignment.BOTTOM:
            posY = horizontalAlignment == LegendHorizontalAlignment.CENTER
                ? viewPortHandler.chartHeight
                : viewPortHandler.contentBottom;
            posY -= legend.neededHeight + yoffset;
          case LegendVerticalAlignment.CENTER:
            posY =
                viewPortHandler.chartHeight / 2 -
                legend.neededHeight / 2 +
                Utils.convertDpToPixel(legend.yOffset);
        }

        for (final e in entries) {
          final drawingForm = e.form != LegendForm.NONE;
          final formSize = e.formSize.isNaN
              ? defaultFormSize
              : Utils.convertDpToPixel(e.formSize);

          var posX = originPosX;

          if (drawingForm) {
            if (direction == LegendDirection.LEFT_TO_RIGHT) {
              posX += stack;
            } else {
              posX -= formSize - stack;
            }

            drawForm(c, posX, posY + formYOffset, e, legend);

            if (direction == LegendDirection.LEFT_TO_RIGHT) posX += formSize;
          }

          final label = e.label;
          if (label != null) {
            if (drawingForm && !wasStacked) {
              posX += direction == LegendDirection.LEFT_TO_RIGHT
                  ? formToTextSpace
                  : -formToTextSpace;
            } else if (wasStacked) {
              posX = originPosX;
            }

            if (direction == LegendDirection.RIGHT_TO_LEFT) {
              posX -= Utils.calcTextWidth(labelPaint, label);
            }

            if (!wasStacked) {
              drawLabel(c, posX, posY + labelLineHeight, label);
            } else {
              posY += labelLineHeight + labelLineSpacing;
              drawLabel(c, posX, posY + labelLineHeight, label);
            }

            posY += labelLineHeight + labelLineSpacing;
            stack = 0;
          } else {
            stack += formSize + stackSpace;
            wasStacked = true;
          }
        }
    }
  }

  final ui.Path _lineFormPath = ui.Path();

  /// Reused for the square form; Kotlin draws it from four coordinates.
  final MutableRect _squareFormRect = MutableRect();

  /// Draws the form of [entry] with its left edge at the pixel position [x] and its vertical center at [y]. Form,
  /// size (dp), line width (dp) and dash effect fall back to those of [legend] where the entry leaves them unset.
  /// Does nothing for entries without a color.
  @protected
  void drawForm(
    ui.Canvas c,
    double x,
    double y,
    LegendEntry entry,
    Legend legend,
  ) {
    if (entry.formColor == ColorTemplate.COLOR_SKIP ||
        entry.formColor == ColorTemplate.COLOR_NONE ||
        entry.formColor.toARGB32() == 0) {
      return;
    }

    final restoreCount = c.getSaveCount();
    c.save();

    var form = entry.form;
    if (form == LegendForm.DEFAULT) form = legend.form;

    formPaint.color = entry.formColor;

    final formSize = Utils.convertDpToPixel(
      entry.formSize.isNaN ? legend.formSize : entry.formSize,
    );
    final half = formSize / 2;

    switch (form) {
      case LegendForm.NONE:
      case LegendForm.EMPTY:
        break;
      case LegendForm.DEFAULT:
      case LegendForm.CIRCLE:
        formPaint.style = PaintStyle.FILL;
        c.drawCircleP(x + half, y, half, formPaint);
      case LegendForm.SQUARE:
        formPaint.style = PaintStyle.FILL;
        _squareFormRect.set(x, y - half, x + formSize, y + half);
        c.drawRectP(_squareFormRect, formPaint);
      case LegendForm.LINE:
        final formLineWidth = Utils.convertDpToPixel(
          entry.formLineWidth.isNaN
              ? legend.formLineWidth
              : entry.formLineWidth,
        );
        final formLineDashEffect =
            entry.formLineDashEffect ?? legend.formLineDashEffect;
        formPaint.style = PaintStyle.STROKE;
        formPaint.strokeWidth = formLineWidth;
        formPaint.pathEffect = formLineDashEffect;

        _lineFormPath.reset();
        _lineFormPath.moveTo(x, y);
        _lineFormPath.lineTo(x + formSize, y);
        c.drawPathP(_lineFormPath, formPaint);
    }

    c.restoreToCount(restoreCount);
  }

  /// Draws [label] with [labelPaint] at the pixel position ([x], [y]), where [y] is the text baseline.
  @protected
  void drawLabel(ui.Canvas c, double x, double y, String label) {
    c.drawText(label, x, y, labelPaint);
  }
}
