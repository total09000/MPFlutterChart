// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/CandleStickChartRenderer.kt
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../animation/chart_animator.dart';
import '../data/candle_entry.dart';
import '../data/data_set.dart';
import '../data/entry.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../highlight/highlight.dart';
import '../interfaces/dataprovider/candle_data_provider.dart';
import '../interfaces/datasets/i_candle_data_set.dart';
import '../utils/color_template.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';
import '../utils/view_port_handler.dart';
import 'line_scatter_candle_radar_renderer.dart';

/// Draws the candles of a [CandleDataProvider]. With `showCandleBar` an entry becomes a body from open to
/// close plus a shadow line from high to low; otherwise it is drawn as a high-low line with an open tick on the
/// left and a close tick on the right. Colors follow whether the entry increased, decreased or stayed equal.
class CandleStickChartRenderer extends LineScatterCandleRadarRenderer {
  /// Creates a renderer for the candle data of [chart].
  CandleStickChartRenderer(
    this.chart,
    ChartAnimator animator,
    ViewPortHandler viewPortHandler,
  ) : super(animator, viewPortHandler);

  /// The chart that supplies the candle data and the transformers.
  @protected
  final CandleDataProvider chart;

  final Float32List _shadowBuffers = Float32List(8);
  final Float32List _bodyBuffers = Float32List(4);
  final Float32List _rangeBuffers = Float32List(4);
  final Float32List _openBuffers = Float32List(4);
  final Float32List _closeBuffers = Float32List(4);

  /// The body handed to `drawRectP`; Kotlin's `drawRect(left, top, right, bottom, paint)` takes the four floats.
  final MutableRect _bodyRect = MutableRect();

  @override
  double lowOf(Entry entry) => (entry as CandleEntry).low;

  @override
  double highOf(Entry entry) => (entry as CandleEntry).high;

  /// Does nothing; candles are drawn without a buffer.
  @override
  void initBuffers() {}

  @override
  void drawData(ui.Canvas c) {
    final candleData = chart.candleData;
    if (candleData == null) return;

    for (final set in candleData.dataSets) {
      if (set.isVisible) drawDataSet(c, set);
    }
  }

  /// Draws every candle of [dataSet] inside the visible range, using its shadow width (dp), bar space (x value
  /// units), paint styles and colors.
  @protected
  void drawDataSet(ui.Canvas c, ICandleDataSet dataSet) {
    if (dataSet.entryCount < 1) return;

    final trans = chart.getTransformer(dataSet.axisDependency);

    final phaseY = animator.phaseY;
    final barSpace = dataSet.barSpace;
    final showCandleBar = dataSet.showCandleBar;

    xBounds.set(chart, dataSet);
    reduceVisible(chart, dataSet, true);

    renderPaint.strokeWidth = Utils.convertDpToPixel(dataSet.shadowWidth);

    for (var k = 0; k < reducer.count; k++) {
      final index = reducer.indices[k];
      final e = dataSet.getEntryForIndex(index);

      final xPos = e.x;
      final open = e.open;
      final close = e.close;
      final high = e.high;
      final low = e.low;

      if (showCandleBar) {
        _shadowBuffers[0] = xPos;
        _shadowBuffers[2] = xPos;
        _shadowBuffers[4] = xPos;
        _shadowBuffers[6] = xPos;

        if (open > close) {
          _shadowBuffers[1] = high * phaseY;
          _shadowBuffers[3] = open * phaseY;
          _shadowBuffers[5] = low * phaseY;
          _shadowBuffers[7] = close * phaseY;
        } else if (open < close) {
          _shadowBuffers[1] = high * phaseY;
          _shadowBuffers[3] = close * phaseY;
          _shadowBuffers[5] = low * phaseY;
          _shadowBuffers[7] = open * phaseY;
        } else {
          _shadowBuffers[1] = high * phaseY;
          _shadowBuffers[3] = open * phaseY;
          _shadowBuffers[5] = low * phaseY;
          _shadowBuffers[7] = _shadowBuffers[3];
        }

        trans.pointValuesToPixel(_shadowBuffers);

        if (dataSet.shadowColorSameAsCandle) {
          if (open > close) {
            renderPaint.color =
                dataSet.decreasingColor == ColorTemplate.COLOR_NONE
                ? dataSet.getColor(index)
                : dataSet.decreasingColor;
          } else if (open < close) {
            renderPaint.color =
                dataSet.increasingColor == ColorTemplate.COLOR_NONE
                ? dataSet.getColor(index)
                : dataSet.increasingColor;
          } else {
            renderPaint.color = dataSet.neutralColor == ColorTemplate.COLOR_NONE
                ? dataSet.getColor(index)
                : dataSet.neutralColor;
          }
        } else {
          renderPaint.color = dataSet.shadowColor == ColorTemplate.COLOR_NONE
              ? dataSet.getColor(index)
              : dataSet.shadowColor;
        }

        renderPaint.style = PaintStyle.STROKE;

        c.drawLinesP(_shadowBuffers, 0, _shadowBuffers.length, renderPaint);

        _bodyBuffers[0] = xPos - 0.5 + barSpace;
        _bodyBuffers[1] = close * phaseY;
        _bodyBuffers[2] = xPos + 0.5 - barSpace;
        _bodyBuffers[3] = open * phaseY;

        trans.pointValuesToPixel(_bodyBuffers);

        if (open > close) {
          renderPaint.color =
              dataSet.decreasingColor == ColorTemplate.COLOR_NONE
              ? dataSet.getColor(index)
              : dataSet.decreasingColor;

          renderPaint.style = dataSet.decreasingPaintStyle;

          _bodyRect.set(
            _bodyBuffers[0],
            _bodyBuffers[3],
            _bodyBuffers[2],
            _bodyBuffers[1],
          );
          c.drawRectP(_bodyRect, renderPaint);
        } else if (open < close) {
          renderPaint.color =
              dataSet.increasingColor == ColorTemplate.COLOR_NONE
              ? dataSet.getColor(index)
              : dataSet.increasingColor;

          renderPaint.style = dataSet.increasingPaintStyle;

          _bodyRect.set(
            _bodyBuffers[0],
            _bodyBuffers[1],
            _bodyBuffers[2],
            _bodyBuffers[3],
          );
          c.drawRectP(_bodyRect, renderPaint);
        } else {
          renderPaint.color = dataSet.neutralColor == ColorTemplate.COLOR_NONE
              ? dataSet.getColor(index)
              : dataSet.neutralColor;

          c.drawLineP(
            _bodyBuffers[0],
            _bodyBuffers[1],
            _bodyBuffers[2],
            _bodyBuffers[3],
            renderPaint,
          );
        }
      } else {
        _rangeBuffers[0] = xPos;
        _rangeBuffers[1] = high * phaseY;
        _rangeBuffers[2] = xPos;
        _rangeBuffers[3] = low * phaseY;

        _openBuffers[0] = xPos - 0.5 + barSpace;
        _openBuffers[1] = open * phaseY;
        _openBuffers[2] = xPos;
        _openBuffers[3] = open * phaseY;

        _closeBuffers[0] = xPos + 0.5 - barSpace;
        _closeBuffers[1] = close * phaseY;
        _closeBuffers[2] = xPos;
        _closeBuffers[3] = close * phaseY;

        trans.pointValuesToPixel(_rangeBuffers);
        trans.pointValuesToPixel(_openBuffers);
        trans.pointValuesToPixel(_closeBuffers);

        final ui.Color barColor;
        if (open > close) {
          barColor = dataSet.decreasingColor == ColorTemplate.COLOR_NONE
              ? dataSet.getColor(index)
              : dataSet.decreasingColor;
        } else if (open < close) {
          barColor = dataSet.increasingColor == ColorTemplate.COLOR_NONE
              ? dataSet.getColor(index)
              : dataSet.increasingColor;
        } else {
          barColor = dataSet.neutralColor == ColorTemplate.COLOR_NONE
              ? dataSet.getColor(index)
              : dataSet.neutralColor;
        }

        renderPaint.color = barColor;
        c.drawLineP(
          _rangeBuffers[0],
          _rangeBuffers[1],
          _rangeBuffers[2],
          _rangeBuffers[3],
          renderPaint,
        );
        c.drawLineP(
          _openBuffers[0],
          _openBuffers[1],
          _openBuffers[2],
          _openBuffers[3],
          renderPaint,
        );
        c.drawLineP(
          _closeBuffers[0],
          _closeBuffers[1],
          _closeBuffers[2],
          _closeBuffers[3],
          renderPaint,
        );
      }
    }
  }

  /// Draws the high value of each candle that was drawn above it.
  @override
  void drawValues(ui.Canvas c) {
    final candleData = chart.candleData;
    if (candleData == null) return;
    final dataSets = candleData.dataSets;

    for (var i = 0; i < dataSets.length; i++) {
      final dataSet = dataSets[i];

      if (!shouldDrawValues(chart, dataSet) || dataSet.entryCount < 1) {
        continue;
      }

      applyValueTextStyle(dataSet);

      final trans = chart.getTransformer(dataSet.axisDependency);

      xBounds.set(chart, dataSet);
      reduceVisible(chart, dataSet, true);

      final positions = reducedPositions(dataSet, trans, animator.phaseY);

      final yOffset = Utils.convertDpToPixel(5);

      final iconsOffset = MPPointF.getInstanceFrom(dataSet.iconsOffset);
      iconsOffset.x = Utils.convertDpToPixel(iconsOffset.x);
      iconsOffset.y = Utils.convertDpToPixel(iconsOffset.y);

      for (var k = 0; k < reducer.count; k++) {
        final x = positions[2 * k];
        final y = positions[2 * k + 1];

        if (!viewPortHandler.isInBoundsRight(x)) break;

        if (!viewPortHandler.isInBoundsLeft(x) ||
            !viewPortHandler.isInBoundsY(y)) {
          continue;
        }

        final index = reducer.indices[k];
        final entry = dataSet.getEntryForIndex(index);

        if (dataSet.isDrawValuesEnabled) {
          drawValue(
            c,
            dataSet.valueFormatter,
            entry.high,
            entry,
            i,
            x,
            y - yOffset,
            dataSet.getValueTextColor(index),
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

      MPPointF.recycleInstance(iconsOffset);
    }
  }

  /// Does nothing; candle charts have no extras.
  @override
  void drawExtras(ui.Canvas c) {}

  /// Draws the highlight lines through the vertical middle of each highlighted candle.
  @override
  void drawHighlighted(ui.Canvas c, List<Highlight> indices) {
    final candleData = chart.candleData;
    if (candleData == null) return;

    for (final high in indices) {
      final set = candleData.getDataSetByIndex(high.dataSetIndex);

      if (set == null || !set.isHighlightEnabled) continue;

      final e = set.getEntryForXValue(high.x, high.y, Rounding.CLOSEST);

      if (e == null || !isInBoundsX(e, set)) continue;

      final lowValue = e.low * animator.phaseY;
      final highValue = e.high * animator.phaseY;
      final y = (lowValue + highValue) / 2;

      final pix = chart
          .getTransformer(set.axisDependency)
          .getPixelForValues(e.x, y);

      high.setDraw(toKotlinFloat(pix.x), toKotlinFloat(pix.y));

      drawHighlightLines(c, toKotlinFloat(pix.x), toKotlinFloat(pix.y), set);
    }
  }
}
