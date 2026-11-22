// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/HorizontalBarChartRenderer.kt
//
// The protected `drawValue(c, valueText: String, x, y, color)` is [HorizontalBarChartRenderer.drawValueText]: Dart
// has no overloading, and the name `drawValue` is taken by the inherited `DataRenderer.drawValue`.
// Not in v4.0.1: the setHighlightDrawPos override, restored from MPAndroidChart 3.x (a deliberate deviation).
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../buffer/horizontal_bar_buffer.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../highlight/highlight.dart';
import '../interfaces/datasets/i_bar_data_set.dart';
import '../utils/fill.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/transformer.dart';
import '../utils/utils.dart';
import 'bar_chart_renderer.dart';

/// Draws the bars of a horizontal bar chart, where the x values run along the vertical axis and the bar values
/// along the horizontal axis. Uses a [HorizontalBarBuffer] per data set and places value labels to the right of
/// the bars (to the left for negative values).
class HorizontalBarChartRenderer extends BarChartRenderer {
  /// Creates a renderer for the bar data of [chart]; value labels are drawn left aligned.
  HorizontalBarChartRenderer(
    super.chart,
    super.animator,
    super.viewPortHandler,
  ) {
    valuePaint.textAlign = PaintAlign.LEFT;
  }

  @override
  @protected
  double get xAxisPixels => viewPortHandler.contentHeight;

  /// Rectangle reused to hand the bars of the buffer to the canvas (Kotlin's `drawRect(left, top, right, bottom,
  /// paint)` overload takes the floats directly).
  final MutableRect _barDrawRect = MutableRect();

  /// Creates one [HorizontalBarBuffer] per data set.
  @override
  void initBuffers() {
    final barData = chart.barData;
    if (barData == null) return;
    if (buffersFitData(barData)) return;

    barBuffers = List.generate(barData.dataSetCount, (i) {
      final set = barData.dataSets[i];
      return HorizontalBarBuffer(
        set.entryCount * 4 * (set.isStacked ? set.stackSize : 1),
        barData.dataSetCount,
        set.isStacked,
      );
    });
  }

  /// Same as the base class, but skips bars by their vertical position and fills custom fills left to right.
  @override
  @protected
  void drawDataSet(ui.Canvas c, IBarDataSet dataSet, int index) {
    if (dataSet.entryCount < 1) return;

    final trans = chart.getTransformer(dataSet.axisDependency);

    barBorderPaint.color = dataSet.barBorderColor;
    barBorderPaint.strokeWidth = Utils.convertDpToPixel(dataSet.barBorderWidth);

    final drawBorder = dataSet.barBorderWidth > 0;

    final phaseX = animator.phaseX;
    final phaseY = animator.phaseY;

    xBounds.set(chart, dataSet);
    reduceVisible(chart, dataSet);

    final buffer = barBuffers[index];
    buffer.setPhases(phaseX, phaseY);
    buffer.dataSetIndex = index;
    buffer.isInverted = chart.isInverted(dataSet.axisDependency);
    final barWidth = chart.barData?.barWidth;
    if (barWidth == null) return;
    buffer.barWidth = barWidth;
    buffer.columnWidth = reducedColumnWidth;

    if (chart.isDrawBarShadowEnabled) {
      shadowPaint.color = dataSet.barShadowColor;

      for (var k = 0; k < reducer.count; k++) {
        final e = dataSet.getEntryForIndex(reducer.indices[k]);

        final x = e.x;
        final barWidthHalf = buffer.widthOfBar(reducer.columnCounts[k]) / 2;

        barShadowRectBuffer.top = x - barWidthHalf;
        barShadowRectBuffer.bottom = x + barWidthHalf;

        trans.rectValueToPixel(barShadowRectBuffer);

        if (!viewPortHandler.isInBoundsTop(barShadowRectBuffer.bottom)) {
          continue;
        }

        if (!viewPortHandler.isInBoundsBottom(barShadowRectBuffer.top)) break;

        barShadowRectBuffer.left = viewPortHandler.contentLeft;
        barShadowRectBuffer.right = viewPortHandler.contentRight;

        drawBarShape(
          c,
          dataSet,
          barShadowRectBuffer.left,
          barShadowRectBuffer.top,
          barShadowRectBuffer.right,
          barShadowRectBuffer.bottom,
          BarCorners.ALL,
          () => c.drawRectP(barShadowRectBuffer, shadowPaint),
        );
      }
    }

    buffer.feedIndices(
      dataSet,
      reducer.indices,
      reducer.columnCounts,
      reducer.count,
    );

    trans.pointValuesToPixel(buffer.buffer, buffer.filledSize);

    final fills = dataSet.fills;
    final isCustomFill = fills != null && fills.isNotEmpty;
    final isSingleColor = dataSet.colors.length == 1;
    final isInverted = chart.isInverted(dataSet.axisDependency);

    if (isSingleColor) {
      renderPaint.color = dataSet.color;
    }

    final barsPerEntry = buffer.barsPerEntry;
    var sections = 1;

    for (var j = 0; j < buffer.filledSize; j += 4) {
      final bar = j ~/ 4;
      final pos = buffer.positionOfBar(bar);

      if (dataSet.isStacked && bar % barsPerEntry == 0) {
        sections =
            dataSet
                .getEntryForIndex(buffer.entryOfBar(bar))
                .stackValues
                ?.length ??
            1;
      }

      if (!viewPortHandler.isInBoundsTop(buffer.buffer[j + 3])) break;

      if (!viewPortHandler.isInBoundsBottom(buffer.buffer[j + 1])) continue;

      if (!isSingleColor) {
        renderPaint.color = dataSet.getColor(pos);
      }

      final left = buffer.buffer[j];
      final top = buffer.buffer[j + 1];
      final right = buffer.buffer[j + 2];
      final bottom = buffer.buffer[j + 3];

      final corners = barCorners(dataSet, pos, sections, BarCorners.RIGHT);
      drawBarShape(c, dataSet, left, top, right, bottom, corners, () {
        if (isCustomFill) {
          dataSet
              .getFill(pos)
              .fillRect(
                c,
                renderPaint,
                left,
                top,
                right,
                bottom,
                isInverted ? FillDirection.LEFT : FillDirection.RIGHT,
              );
        } else {
          c.drawRectP(_barDrawRect..set(left, top, right, bottom), renderPaint);
        }

        if (drawBorder) {
          c.drawRectP(
            _barDrawRect..set(left, top, right, bottom),
            barBorderPaint,
          );
        }
      });
    }
  }

  @override
  void drawValues(ui.Canvas c) {
    final barData = chart.barData;
    if (barData == null) return;
    final dataSets = barData.dataSets;

    final valueOffsetPlus = Utils.convertDpToPixel(5);
    double posOffset;
    double negOffset;
    final drawValueAboveBar = chart.isDrawValueAboveBarEnabled;

    for (var i = 0; i < barData.dataSetCount; i++) {
      final dataSet = dataSets[i];

      if (!shouldDrawValues(chart, dataSet)) continue;

      final isInverted = chart.isInverted(dataSet.axisDependency);

      applyValueTextStyle(dataSet);
      final halfTextHeight = Utils.calcTextHeight(valuePaint, '10') / 2;

      final formatter = dataSet.valueFormatter;

      final buffer = barBuffers[i];

      final phaseY = animator.phaseY;

      final iconsOffset = MPPointF.getInstanceFrom(dataSet.iconsOffset);
      iconsOffset.x = Utils.convertDpToPixel(iconsOffset.x);
      iconsOffset.y = Utils.convertDpToPixel(iconsOffset.y);

      if (!dataSet.isStacked) {
        var j = 0;
        while (j < buffer.filledSize) {
          final y = (buffer.buffer[j + 1] + buffer.buffer[j + 3]) / 2;

          if (!viewPortHandler.isInBoundsTop(buffer.buffer[j + 1])) break;

          // The label sits at the tip of the bar, so the whole bar counts as visible, not only its base.
          final barStart = math.min(buffer.buffer[j], buffer.buffer[j + 2]);
          final barEnd = math.max(buffer.buffer[j], buffer.buffer[j + 2]);

          if (!viewPortHandler.isInBoundsLeft(barEnd) ||
              !viewPortHandler.isInBoundsRight(barStart) ||
              !viewPortHandler.isInBoundsBottom(buffer.buffer[j + 1])) {
            j += 4;
            continue;
          }

          final entryIndex = buffer.entryOfBar(j ~/ 4);
          final entry = dataSet.getEntryForIndex(entryIndex);
          final value = entry.y;
          final formattedValue = formatter.getFormattedValue(
            value,
            entry,
            i,
            viewPortHandler,
          );

          final valueTextWidth = Utils.calcTextWidth(
            valuePaint,
            formattedValue,
          );
          posOffset = drawValueAboveBar
              ? valueOffsetPlus
              : -(valueTextWidth + valueOffsetPlus);
          negOffset =
              (drawValueAboveBar
                  ? -(valueTextWidth + valueOffsetPlus)
                  : valueOffsetPlus) -
              (buffer.buffer[j + 2] - buffer.buffer[j]);

          if (isInverted) {
            posOffset = -posOffset - valueTextWidth;
            negOffset = -negOffset - valueTextWidth;
          }

          if (dataSet.isDrawValuesEnabled) {
            drawValueText(
              c,
              formattedValue,
              buffer.buffer[j + 2] + (value >= 0 ? posOffset : negOffset),
              y + halfTextHeight,
              dataSet.getValueTextColor(entryIndex),
            );
          }

          final icon = entry.icon;
          if (icon != null && dataSet.isDrawIconsEnabled) {
            var px =
                buffer.buffer[j + 2] + (value >= 0 ? posOffset : negOffset);
            var py = y;

            px += iconsOffset.x;
            py += iconsOffset.y;

            Utils.drawImage(
              c,
              icon,
              truncateToDevicePx(px),
              truncateToDevicePx(py),
              icon.intrinsicWidth,
              icon.intrinsicHeight,
            );
          }

          j += 4;
        }
      } else {
        final trans = chart.getTransformer(dataSet.axisDependency);

        final entryStride = 4 * buffer.barsPerEntry;

        var bufferIndex = 0;

        while (bufferIndex < buffer.filledSize) {
          final index = buffer.entryOfBar(bufferIndex ~/ 4);
          final entry = dataSet.getEntryForIndex(index);

          final color = dataSet.getValueTextColor(index);
          final vals = entry.stackValues;

          final entryStart = bufferIndex;
          bufferIndex += entryStride;

          if (vals == null) {
            if (!viewPortHandler.isInBoundsTop(buffer.buffer[entryStart + 1])) {
              break;
            }

            final barStart = math.min(
              buffer.buffer[entryStart],
              buffer.buffer[entryStart + 2],
            );
            final barEnd = math.max(
              buffer.buffer[entryStart],
              buffer.buffer[entryStart + 2],
            );

            if (!viewPortHandler.isInBoundsLeft(barEnd) ||
                !viewPortHandler.isInBoundsRight(barStart) ||
                !viewPortHandler.isInBoundsBottom(
                  buffer.buffer[entryStart + 1],
                )) {
              continue;
            }

            final value = entry.y;
            final formattedValue = formatter.getFormattedValue(
              value,
              entry,
              i,
              viewPortHandler,
            );

            final valueTextWidth = Utils.calcTextWidth(
              valuePaint,
              formattedValue,
            );
            posOffset = drawValueAboveBar
                ? valueOffsetPlus
                : -(valueTextWidth + valueOffsetPlus);
            negOffset = drawValueAboveBar
                ? -(valueTextWidth + valueOffsetPlus)
                : valueOffsetPlus;

            if (isInverted) {
              posOffset = -posOffset - valueTextWidth;
              negOffset = -negOffset - valueTextWidth;
            }

            if (dataSet.isDrawValuesEnabled) {
              drawValueText(
                c,
                formattedValue,
                buffer.buffer[entryStart + 2] +
                    (entry.y >= 0 ? posOffset : negOffset),
                buffer.buffer[entryStart + 1] + halfTextHeight,
                color,
              );
            }

            final icon = entry.icon;
            if (icon != null && dataSet.isDrawIconsEnabled) {
              var px =
                  buffer.buffer[entryStart + 2] +
                  (entry.y >= 0 ? posOffset : negOffset);
              var py = buffer.buffer[entryStart + 1];

              px += iconsOffset.x;
              py += iconsOffset.y;

              Utils.drawImage(
                c,
                icon,
                truncateToDevicePx(px),
                truncateToDevicePx(py),
                icon.intrinsicWidth,
                icon.intrinsicHeight,
              );
            }
          } else {
            final transformed = Float32List(vals.length * 2);

            var posY = 0.0;
            var negY = -entry.negativeSum;

            var k = 0;
            var idx = 0;
            while (k < transformed.length) {
              final value = vals[idx];
              final double y;

              if (value == 0.0 && (posY == 0.0 || negY == 0.0)) {
                y = value;
              } else if (value >= 0.0) {
                posY += value;
                y = posY;
              } else {
                y = negY;
                negY -= value;
              }

              transformed[k] = y * phaseY;
              k += 2;
              idx++;
            }

            trans.pointValuesToPixel(transformed);

            for (var k = 0; k < transformed.length; k += 2) {
              final value = vals[k ~/ 2];
              final formattedValue = formatter.getStackedFormattedValue(
                value,
                k ~/ 2,
                entry,
                i,
                viewPortHandler,
              );

              final valueTextWidth = Utils.calcTextWidth(
                valuePaint,
                formattedValue,
              );
              posOffset = drawValueAboveBar
                  ? valueOffsetPlus
                  : -(valueTextWidth + valueOffsetPlus);
              negOffset = drawValueAboveBar
                  ? -(valueTextWidth + valueOffsetPlus)
                  : valueOffsetPlus;

              if (isInverted) {
                posOffset = -posOffset - valueTextWidth;
                negOffset = -negOffset - valueTextWidth;
              }

              final drawBelow =
                  (value == 0.0 && negY == 0.0 && posY > 0.0) || value < 0.0;

              final x = transformed[k] + (drawBelow ? negOffset : posOffset);
              final y =
                  (buffer.buffer[entryStart + 1] +
                      buffer.buffer[entryStart + 3]) /
                  2;

              if (!viewPortHandler.isInBoundsTop(y)) break;

              if (!viewPortHandler.isInBoundsX(x) ||
                  !viewPortHandler.isInBoundsBottom(y)) {
                continue;
              }

              if (dataSet.isDrawValuesEnabled) {
                drawValueText(c, formattedValue, x, y + halfTextHeight, color);
              }

              final icon = entry.icon;
              if (icon != null && dataSet.isDrawIconsEnabled) {
                Utils.drawImage(
                  c,
                  icon,
                  truncateToDevicePx(x + iconsOffset.x),
                  truncateToDevicePx(y + iconsOffset.y),
                  icon.intrinsicWidth,
                  icon.intrinsicHeight,
                );
              }
            }
          }
        }
      }

      MPPointF.recycleInstance(iconsOffset);
    }
  }

  /// Draws an already formatted value text with [valuePaint] in [color], left aligned at the pixel position
  /// ([x], [y]), where [y] is the text baseline.
  ///
  /// Kotlin's `drawValue(c, valueText, x, y, color)`; renamed because Dart has no overloading and
  /// `DataRenderer.drawValue` already has the name.
  @protected
  void drawValueText(
    ui.Canvas c,
    String valueText,
    double x,
    double y,
    ui.Color color,
  ) {
    valuePaint.color = color;
    c.drawText(valueText, x, y, valuePaint);
  }

  /// Swaps the axes: the bar is centered vertically on the x value [x] and spans horizontally from [y1] to [y2].
  @override
  @protected
  void prepareBarHighlight(
    double x,
    double y1,
    double y2,
    double barWidthHalf,
    Transformer trans,
  ) {
    final top = x - barWidthHalf;
    final bottom = x + barWidthHalf;
    final left = y1;
    final right = y2;

    barRect.set(left, top, right, bottom);

    trans.rectToPixelPhaseHorizontal(barRect, animator.phaseY);
  }

  /// Stores on [high] the vertical center of the highlighted [bar] as its x and the bar's right edge as its y;
  /// `HorizontalBarChart.getMarkerPosition` swaps them back, so the marker sits at the right end of the bar,
  /// vertically centered.
  ///
  /// Deliberate deviation: MPAndroidChart 3.x had this override and v4.0.1 lost it, which put the marker at the
  /// transposed point (the bar's top edge as x, its horizontal center as y).
  @override
  @protected
  void setHighlightDrawPos(Highlight high, MutableRect bar) =>
      high.setDraw(bar.centerY(), bar.right);
}
