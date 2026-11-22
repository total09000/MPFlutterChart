// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/BarChartRenderer.kt
//
// The `protected enum class BarCorners` is the top-level [BarCorners]. The inline `drawBarShape(…, draw: () -> Unit)`
// takes a `void Function()` callback. Skia draws nothing for a bar whose pixel rectangle has a NaN edge, while
// Flutter's canvas asserts on it in debug builds, so [BarChartRenderer.drawBarShape] leaves such a bar out.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../animation/chart_animator.dart';
import '../buffer/bar_buffer.dart';
import '../data/bar_data.dart';
import '../data/data_set.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../highlight/highlight.dart';
import '../interfaces/dataprovider/bar_data_provider.dart';
import '../interfaces/datasets/i_bar_data_set.dart';
import '../utils/fill.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/transformer.dart';
import '../utils/utils.dart';
import '../utils/view_port_handler.dart';
import 'bar_line_scatter_candle_bubble_renderer.dart';

/// Which corners of a bar get rounded.
///
/// Kotlin's `protected enum class BarChartRenderer.BarCorners`; top level here, since Dart has no nested types.
enum BarCorners { ALL, TOP, BOTTOM, LEFT, RIGHT, NONE }

/// Draws the bars of a [BarDataProvider] (a bar chart, or a combined chart with bar data). The bars of each data
/// set are collected in a [BarBuffer] in value space, converted to pixels in one step and drawn as rectangles
/// or custom fills. A highlight is drawn as a translucent rectangle over the selected bar or stack value.
class BarChartRenderer extends BarLineScatterCandleBubbleRenderer {
  /// Creates a renderer for the bar data of [chart].
  BarChartRenderer(
    this.chart,
    ChartAnimator animator,
    ViewPortHandler viewPortHandler,
  ) : super(animator, viewPortHandler) {
    highlightPaint.style = PaintStyle.FILL;
    highlightPaint.color = const ui.Color.fromARGB(255, 0, 0, 0);
    highlightPaint.alpha = 120;
  }

  /// The chart that supplies the bar data, the transformers and the bar settings.
  @protected
  final BarDataProvider chart;

  /// Pixel rectangle of the bar being highlighted, filled by [prepareBarHighlight].
  @protected
  final MutableRect barRect = MutableRect();

  /// Clip path for rounded bars, reused across draws.
  @protected
  final ui.Path barShapePath = ui.Path();

  /// Corner radii for [barShapePath], two values per corner starting top left.
  @protected
  final Float32List barShapeRadii = Float32List(8);

  /// Runs [draw] clipped to the rounded shape of a bar when [dataSet] has a [IBarDataSet.barCornerRadius],
  /// otherwise runs it directly. Coordinates are pixels.
  ///
  /// A bar with a NaN edge is left out and [draw] is not run: Skia would draw nothing for it, Flutter's canvas
  /// asserts.
  @protected
  void drawBarShape(
    ui.Canvas c,
    IBarDataSet dataSet,
    double left,
    double top,
    double right,
    double bottom,
    BarCorners corners,
    void Function() draw,
  ) {
    if (left.isNaN || top.isNaN || right.isNaN || bottom.isNaN) return;

    final radius = Utils.convertDpToPixel(dataSet.barCornerRadius);
    if (radius <= 0 || corners == BarCorners.NONE) {
      draw();
      return;
    }
    final r = math.min(
      radius,
      math.min((right - left).abs() / 2, (bottom - top).abs() / 2),
    );
    final radii = barShapeRadii;
    radii.fillRange(0, radii.length, 0);
    if (corners == BarCorners.ALL ||
        corners == BarCorners.TOP ||
        corners == BarCorners.LEFT) {
      radii[0] = r;
      radii[1] = r;
    }
    if (corners == BarCorners.ALL ||
        corners == BarCorners.TOP ||
        corners == BarCorners.RIGHT) {
      radii[2] = r;
      radii[3] = r;
    }
    if (corners == BarCorners.ALL ||
        corners == BarCorners.BOTTOM ||
        corners == BarCorners.RIGHT) {
      radii[4] = r;
      radii[5] = r;
    }
    if (corners == BarCorners.ALL ||
        corners == BarCorners.BOTTOM ||
        corners == BarCorners.LEFT) {
      radii[6] = r;
      radii[7] = r;
    }
    barShapePath.reset();
    barShapePath.addRRect(
      ui.RRect.fromLTRBAndCorners(
        math.min(left, right),
        math.min(top, bottom),
        math.max(left, right),
        math.max(top, bottom),
        topLeft: ui.Radius.elliptical(radii[0], radii[1]),
        topRight: ui.Radius.elliptical(radii[2], radii[3]),
        bottomRight: ui.Radius.elliptical(radii[4], radii[5]),
        bottomLeft: ui.Radius.elliptical(radii[6], radii[7]),
      ),
    );
    final save = c.getSaveCount();
    c.save();
    c.clipPath(barShapePath);
    draw();
    c.restoreToCount(save);
  }

  /// Corners to round for the bar rect at [pos] of a data set: all for plain bars and, in a stack, all of every
  /// section when the set rounds its sections, otherwise only the end of the outermost one.
  ///
  /// [sections] is how many values the entry this rect belongs to carries, which is at most the stack size of the
  /// data set; an entry that carries fewer leaves the rest of its room in the buffer empty. [outermost] is the
  /// corners of the section farthest from zero, which is the top in a vertical bar chart.
  @protected
  BarCorners barCorners(
    IBarDataSet dataSet,
    int pos,
    int sections, [
    BarCorners outermost = BarCorners.TOP,
  ]) {
    if (!dataSet.isStacked) return BarCorners.ALL;
    if (dataSet.isStackSectionsRounded) return BarCorners.ALL;
    return pos % dataSet.stackSize == sections - 1
        ? outermost
        : BarCorners.NONE;
  }

  /// One buffer per data set holding its bar rectangles, created by [initBuffers]. Empty until the chart has data.
  @protected
  List<BarBuffer> barBuffers = [];

  /// Paint for the bar shadow drawn behind each bar over the full content height when the chart enables it; its
  /// color is the bar shadow color of the data set.
  @protected
  final ChartPaint shadowPaint = ChartPaint()..style = PaintStyle.FILL;

  /// Stroke paint for the bar borders; color and width (dp) come from the data set.
  @protected
  final ChartPaint barBorderPaint = ChartPaint()..style = PaintStyle.STROKE;

  /// Rectangle reused while drawing bar shadows.
  @protected
  final MutableRect barShadowRectBuffer = MutableRect();

  /// Rectangle reused to hand the bars of the buffer to the canvas (Kotlin's `drawRect(left, top, right, bottom,
  /// paint)` overload takes the floats directly).
  final MutableRect _barDrawRect = MutableRect();

  /// Creates one [BarBuffer] per data set, sized for four floats per bar (times the stack size for stacked sets).
  /// Does nothing without bar data and nothing while the buffers still fit, so a chart that keeps appending
  /// entries does not throw its buffers away on every call. An override is expected to keep that.
  @override
  void initBuffers() {
    final barData = chart.barData;
    if (barData == null) return;
    if (buffersFitData(barData)) return;

    barBuffers = List.generate(barData.dataSetCount, (i) {
      final set = barData.dataSets[i];
      return BarBuffer(
        set.entryCount * 4 * (set.isStacked ? set.stackSize : 1),
        barData.dataSetCount,
        set.isStacked,
      );
    });
  }

  /// True while [barBuffers] still holds one buffer for every data set of [barData] that has both its size and
  /// its stacking. The stacking is part of the question because two data sets of different shape can need the
  /// same number of floats, and a buffer built for plain bars would drop the sections of a stacked one.
  @protected
  bool buffersFitData(BarData barData) {
    if (barBuffers.length != barData.dataSetCount) return false;

    for (var i = 0; i < barData.dataSetCount; i++) {
      final set = barData.dataSets[i];
      if (barBuffers[i].containsStacks != set.isStacked) return false;
      if (barBuffers[i].size !=
          set.entryCount * 4 * (set.isStacked ? set.stackSize : 1)) {
        return false;
      }
    }

    return true;
  }

  @override
  void drawData(ui.Canvas c) {
    final barData = chart.barData;
    if (barData == null) return;

    // The data can change without the chart being told, and a renderer can be installed after the data.
    initBuffers();

    for (var i = 0; i < barData.dataSetCount; i++) {
      final set = barData.getDataSetByIndex(i);
      if (set == null) continue;

      if (set.isVisible) {
        drawDataSet(c, set, i);
      }
    }
  }

  /// Draws the bars of [dataSet], the data set at [index] in the bar data, that lie inside the visible x range:
  /// first their shadows when the chart enables them, then each bar with its color or custom fill, then its
  /// border when the border width is above 0.
  ///
  /// The visible range rounds out to one entry past each edge, which is enough room for a bar whose center sits
  /// off screen while part of it still shows. A bar wider than about two x values would reach further than that
  /// and lose its edge.
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

        barShadowRectBuffer.left = x - barWidthHalf;
        barShadowRectBuffer.right = x + barWidthHalf;

        trans.rectValueToPixel(barShadowRectBuffer);

        if (!viewPortHandler.isInBoundsLeft(barShadowRectBuffer.right)) {
          continue;
        }

        if (!viewPortHandler.isInBoundsRight(barShadowRectBuffer.left)) break;

        barShadowRectBuffer.top = viewPortHandler.contentTop;
        barShadowRectBuffer.bottom = viewPortHandler.contentBottom;

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

      if (!viewPortHandler.isInBoundsLeft(buffer.buffer[j + 2])) continue;

      if (!viewPortHandler.isInBoundsRight(buffer.buffer[j])) break;

      if (!isSingleColor) {
        renderPaint.color = dataSet.getColor(pos);
      }

      final left = buffer.buffer[j];
      final top = buffer.buffer[j + 1];
      final right = buffer.buffer[j + 2];
      final bottom = buffer.buffer[j + 3];

      drawBarShape(
        c,
        dataSet,
        left,
        top,
        right,
        bottom,
        barCorners(dataSet, pos, sections),
        () {
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
                  isInverted ? FillDirection.DOWN : FillDirection.UP,
                );
          } else {
            c.drawRectP(
              _barDrawRect..set(left, top, right, bottom),
              renderPaint,
            );
          }

          if (drawBorder) {
            c.drawRectP(
              _barDrawRect..set(left, top, right, bottom),
              barBorderPaint,
            );
          }
        },
      );
    }
  }

  /// Fills [barRect] with the pixel rectangle of the bar centered at the x value [x], spanning from the value [y1]
  /// to [y2], using [trans] and the y animation phase.
  ///
  /// [barWidthHalf] is half the bar width in x value units.
  @protected
  void prepareBarHighlight(
    double x,
    double y1,
    double y2,
    double barWidthHalf,
    Transformer trans,
  ) {
    final left = x - barWidthHalf;
    final right = x + barWidthHalf;
    final top = y1;
    final bottom = y2;

    barRect.set(left, top, right, bottom);

    trans.rectToPixelPhase(barRect, animator.phaseY);
  }

  /// Draws the value label and icon of each visible bar above it (or below it for negative values, and the other
  /// way round when values are drawn inside the bars). Stacked bars get one label per stack value.
  @override
  void drawValues(ui.Canvas c) {
    final barData = chart.barData;
    if (barData == null) return;
    final dataSets = barData.dataSets;

    final valueOffsetPlus = Utils.convertDpToPixel(4.5);
    double posOffset;
    double negOffset;
    final drawValueAboveBar = chart.isDrawValueAboveBarEnabled;

    for (var i = 0; i < barData.dataSetCount; i++) {
      final dataSet = dataSets[i];

      if (!shouldDrawValues(chart, dataSet)) continue;

      applyValueTextStyle(dataSet);

      final isInverted = chart.isInverted(dataSet.axisDependency);

      final valueTextHeight = Utils.calcTextHeight(valuePaint, '8');
      posOffset = drawValueAboveBar
          ? -valueOffsetPlus
          : valueTextHeight + valueOffsetPlus;
      negOffset = drawValueAboveBar
          ? valueTextHeight + valueOffsetPlus
          : -valueOffsetPlus;

      if (isInverted) {
        posOffset = -posOffset - valueTextHeight;
        negOffset = -negOffset - valueTextHeight;
      }

      final buffer = barBuffers[i];

      final phaseY = animator.phaseY;

      final iconsOffset = MPPointF.getInstanceFrom(dataSet.iconsOffset);
      iconsOffset.x = Utils.convertDpToPixel(iconsOffset.x);
      iconsOffset.y = Utils.convertDpToPixel(iconsOffset.y);

      if (!dataSet.isStacked) {
        var j = 0;
        while (j < buffer.filledSize) {
          final x = (buffer.buffer[j] + buffer.buffer[j + 2]) / 2;

          if (!viewPortHandler.isInBoundsRight(x)) break;

          if (!viewPortHandler.isInBoundsY(buffer.buffer[j + 1]) ||
              !viewPortHandler.isInBoundsLeft(x)) {
            j += 4;
            continue;
          }

          final entryIndex = buffer.entryOfBar(j ~/ 4);
          final entry = dataSet.getEntryForIndex(entryIndex);
          final value = entry.y;

          if (dataSet.isDrawValuesEnabled) {
            drawValue(
              c,
              dataSet.valueFormatter,
              value,
              entry,
              i,
              x,
              value >= 0
                  ? buffer.buffer[j + 1] + posOffset
                  : buffer.buffer[j + 3] + negOffset,
              dataSet.getValueTextColor(entryIndex),
            );
          }

          final icon = entry.icon;
          if (icon != null && dataSet.isDrawIconsEnabled) {
            var px = x;
            var py = value >= 0
                ? buffer.buffer[j + 1] + posOffset
                : buffer.buffer[j + 3] + negOffset;

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

          final vals = entry.stackValues;
          final x =
              (buffer.buffer[bufferIndex] + buffer.buffer[bufferIndex + 2]) / 2;

          final color = dataSet.getValueTextColor(index);

          final entryStart = bufferIndex;
          bufferIndex += entryStride;

          if (vals == null) {
            if (!viewPortHandler.isInBoundsRight(x)) break;

            if (!viewPortHandler.isInBoundsY(buffer.buffer[entryStart + 1]) ||
                !viewPortHandler.isInBoundsLeft(x)) {
              continue;
            }

            if (dataSet.isDrawValuesEnabled) {
              drawValue(
                c,
                dataSet.valueFormatter,
                entry.y,
                entry,
                i,
                x,
                buffer.buffer[entryStart + 1] +
                    (entry.y >= 0 ? posOffset : negOffset),
                color,
              );
            }

            final icon = entry.icon;
            if (icon != null && dataSet.isDrawIconsEnabled) {
              var px = x;
              var py =
                  buffer.buffer[entryStart + 1] +
                  (entry.y >= 0 ? posOffset : negOffset);

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

              transformed[k + 1] = y * phaseY;
              k += 2;
              idx++;
            }

            trans.pointValuesToPixel(transformed);

            for (var k = 0; k < transformed.length; k += 2) {
              final value = vals[k ~/ 2];
              final drawBelow =
                  (value == 0.0 && negY == 0.0 && posY > 0.0) || value < 0.0;
              final y =
                  transformed[k + 1] + (drawBelow ? negOffset : posOffset);

              if (!viewPortHandler.isInBoundsRight(x)) break;

              if (!viewPortHandler.isInBoundsY(y) ||
                  !viewPortHandler.isInBoundsLeft(x)) {
                continue;
              }

              if (dataSet.isDrawValuesEnabled) {
                drawStackedValue(
                  c,
                  dataSet.valueFormatter,
                  vals[k ~/ 2],
                  k ~/ 2,
                  entry,
                  i,
                  x,
                  y,
                  color,
                );
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

  /// Draws a rectangle in the highlight color and alpha of the data set over each highlighted bar. For a stacked
  /// entry only the selected stack value is covered, unless the chart highlights full bars.
  @override
  void drawHighlighted(ui.Canvas c, List<Highlight> indices) {
    final barData = chart.barData;
    if (barData == null) return;

    for (final high in indices) {
      final set = barData.getDataSetByIndex(high.dataSetIndex);

      if (set == null || !set.isHighlightEnabled) continue;

      final e = set.getEntryForXValue(high.x, high.y, Rounding.CLOSEST);

      if (e == null || !isInBoundsX(e, set)) continue;

      final trans = chart.getTransformer(set.axisDependency);

      highlightPaint.color = set.highlightColor;
      highlightPaint.alpha = set.highlightAlpha;

      final isStack = high.stackIndex >= 0 && e.isStacked;

      final double y1;
      final double y2;

      if (isStack) {
        if (chart.isHighlightFullBarEnabled) {
          y1 = e.positiveSum;
          y2 = -e.negativeSum;
        } else {
          final ranges = e.ranges;
          if (ranges == null || high.stackIndex >= ranges.length) continue;
          final range = ranges[high.stackIndex];

          y1 = range.from;
          y2 = range.to;
        }
      } else {
        y1 = e.y;
        y2 = 0;
      }

      prepareBarHighlight(
        e.x,
        y1,
        y2,
        _highlightedBarWidth(barData, high.dataSetIndex) / 2,
        trans,
      );

      setHighlightDrawPos(high, barRect);

      final corners =
          !isStack ||
              chart.isHighlightFullBarEnabled ||
              set.isStackSectionsRounded
          ? BarCorners.ALL
          : BarCorners.NONE;
      drawBarShape(
        c,
        set,
        barRect.left,
        barRect.top,
        barRect.right,
        barRect.bottom,
        corners,
        () => c.drawRectP(barRect, highlightPaint),
      );
    }
  }

  /// Width in x value units of the bar the highlight has to cover for the data set at [index], which is the
  /// pixel column that set was drawn with while its bars stood for a whole column each. Falls back to the bar
  /// width of [barData] for a set that has no buffer yet or was skipped as invisible and whose buffer still
  /// holds the column of an older draw.
  double _highlightedBarWidth(BarData barData, int index) {
    final set = barData.getDataSetByIndex(index);
    if (set == null ||
        !set.isVisible ||
        index < 0 ||
        index >= barBuffers.length) {
      return barData.barWidth;
    }

    return math.max(barData.barWidth, barBuffers[index].columnWidth);
  }

  /// Stores on [high] the pixel position where a marker for the highlighted [bar] is drawn: its top center.
  @protected
  void setHighlightDrawPos(Highlight high, MutableRect bar) {
    high.setDraw(bar.centerX(), bar.top);
  }

  /// Does nothing; bar charts have no extras.
  @override
  void drawExtras(ui.Canvas c) {}
}
