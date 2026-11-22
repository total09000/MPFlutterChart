// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/BubbleChartRenderer.kt
//
// Android's `Color.RGBToHSV` / `HSVToColor` (with Kotlin's `hsvBuffer`) are Flutter's `HSVColor`.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;
import 'package:flutter/painting.dart' show HSVColor;

import '../animation/chart_animator.dart';
import '../data/bubble_entry.dart';
import '../data/data_set.dart';
import '../data/entry.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../highlight/highlight.dart';
import '../interfaces/dataprovider/bubble_data_provider.dart';
import '../interfaces/datasets/i_bubble_data_set.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/transformer.dart';
import '../utils/utils.dart';
import '../utils/view_port_handler.dart';
import 'bar_line_scatter_candle_bubble_renderer.dart';

/// Draws the bubbles of a [BubbleDataProvider]. Each entry is a filled circle at its x and y value whose
/// diameter follows the entry size relative to the largest size of its data set. A highlight redraws the outline
/// of the bubble in a darker shade of its color.
class BubbleChartRenderer extends BarLineScatterCandleBubbleRenderer {
  /// Creates a renderer for the bubble data of [chart].
  BubbleChartRenderer(
    this.chart,
    ChartAnimator animator,
    ViewPortHandler viewPortHandler,
  ) : super(animator, viewPortHandler) {
    renderPaint.style = PaintStyle.FILL;

    highlightPaint.style = PaintStyle.STROKE;
    highlightPaint.strokeWidth = Utils.convertDpToPixel(1.5);
  }

  /// The chart that supplies the bubble data and the transformers.
  @protected
  final BubbleDataProvider chart;

  final Float32List _sizeBuffer = Float32List(4);
  final Float32List _pointBuffer = Float32List(2);

  double _maxBubbleSize = 0;
  double _bubbleReference = 0;
  bool _normalizeBubbleSize = true;
  double _valuesPerPixelY = 0;

  /// Does nothing; bubbles are drawn without a buffer.
  @override
  void initBuffers() {}

  @override
  void drawData(ui.Canvas c) {
    final bubbleData = chart.bubbleData;
    if (bubbleData == null) return;

    for (final set in bubbleData.dataSets) {
      if (set.isVisible) drawDataSet(c, set);
    }
  }

  /// Returns the diameter in pixels of a bubble with the given size.
  ///
  /// [entrySize] is the size value of the entry and [maxSize] the largest size value in the data set; [reference]
  /// is the pixel diameter of the largest bubble: the smaller of one x unit and the content height. [normalizeSize]
  /// true scales [reference] by the square root of `entrySize / maxSize`, false multiplies it by [entrySize]
  /// directly.
  @protected
  double getShapeSize(
    double entrySize,
    double maxSize,
    double reference,
    bool normalizeSize,
  ) {
    final factor = normalizeSize
        ? (maxSize == 0 ? 1.0 : math.sqrt(entrySize / maxSize))
        : entrySize;
    return reference * factor;
  }

  /// Half the height the bubble of [entry] paints, in y value units, as of the last [_measureBubbles]. A bubble
  /// stands for the whole disc it covers, so the reduction keeps the ones that reach furthest rather than the
  /// ones whose center sits furthest out.
  double _halfHeightOf(Entry entry) {
    if (entry is! BubbleEntry) return 0;
    return getShapeSize(
          entry.size,
          _maxBubbleSize,
          _bubbleReference,
          _normalizeBubbleSize,
        ) /
        2 *
        _valuesPerPixelY;
  }

  @override
  double lowOf(Entry entry) => entry.y - _halfHeightOf(entry);

  @override
  double highOf(Entry entry) => entry.y + _halfHeightOf(entry);

  @override
  bool get hasSizes => true;

  @override
  double sizeOf(Entry entry) => entry is BubbleEntry ? entry.size : 0;

  /// Remembers how [dataSet] scales its bubbles in the current viewport, so that [lowOf] and [highOf] can say how
  /// much room one bubble takes. Needed before every reduction of a bubble data set.
  void _measureBubbles(IBubbleDataSet dataSet, Transformer trans) {
    _sizeBuffer[0] = 0;
    _sizeBuffer[1] = 0;
    _sizeBuffer[2] = 1;
    _sizeBuffer[3] = 1;

    trans.pointValuesToPixel(_sizeBuffer);

    final maxBubbleWidth = (_sizeBuffer[2] - _sizeBuffer[0]).abs();
    final maxBubbleHeight =
        (viewPortHandler.contentBottom - viewPortHandler.contentTop).abs();
    final pixelsPerValueY = (_sizeBuffer[3] - _sizeBuffer[1]).abs();

    _maxBubbleSize = dataSet.maxSize;
    _normalizeBubbleSize = dataSet.isNormalizeSizeEnabled;
    _bubbleReference = math.min(maxBubbleHeight, maxBubbleWidth);
    _valuesPerPixelY = pixelsPerValueY > 0 ? 1 / pixelsPerValueY : 0;
  }

  /// Draws every bubble of [dataSet] inside the visible range that the reduction kept, with the color of its
  /// entry.
  @protected
  void drawDataSet(ui.Canvas c, IBubbleDataSet dataSet) {
    if (dataSet.entryCount < 1) return;

    final trans = chart.getTransformer(dataSet.axisDependency);

    final phaseY = animator.phaseY;

    xBounds.set(chart, dataSet);
    _measureBubbles(dataSet, trans);
    reduceVisible(chart, dataSet);

    for (var k = 0; k < reducer.count; k++) {
      final index = reducer.indices[k];
      final entry = dataSet.getEntryForIndex(index);

      _pointBuffer[0] = entry.x;
      _pointBuffer[1] = entry.y * phaseY;
      trans.pointValuesToPixel(_pointBuffer);

      final shapeHalf =
          getShapeSize(
            entry.size,
            _maxBubbleSize,
            _bubbleReference,
            _normalizeBubbleSize,
          ) /
          2;

      if (!viewPortHandler.isInBoundsTop(_pointBuffer[1] + shapeHalf) ||
          !viewPortHandler.isInBoundsBottom(_pointBuffer[1] - shapeHalf)) {
        continue;
      }

      if (!viewPortHandler.isInBoundsLeft(_pointBuffer[0] + shapeHalf)) {
        continue;
      }

      if (!viewPortHandler.isInBoundsRight(_pointBuffer[0] - shapeHalf)) break;

      renderPaint.color = dataSet.getColor(index);
      c.drawCircleP(_pointBuffer[0], _pointBuffer[1], shapeHalf, renderPaint);
    }
  }

  /// Draws the size value of each bubble that was drawn centered on it, fading the text in with the animation.
  @override
  void drawValues(ui.Canvas c) {
    final bubbleData = chart.bubbleData;
    if (bubbleData == null) return;

    final dataSets = bubbleData.dataSets;

    final lineHeight = Utils.calcTextHeight(valuePaint, '1');

    for (var i = 0; i < dataSets.length; i++) {
      final dataSet = dataSets[i];

      if (!shouldDrawValues(chart, dataSet) || dataSet.entryCount < 1) {
        continue;
      }

      applyValueTextStyle(dataSet);

      final phaseX = math.max(0.0, math.min(1.0, animator.phaseX));
      final phaseY = animator.phaseY;

      final trans = chart.getTransformer(dataSet.axisDependency);

      xBounds.set(chart, dataSet);
      _measureBubbles(dataSet, trans);
      reduceVisible(chart, dataSet);

      final alpha = phaseX == 1 ? phaseY : phaseX;

      final iconsOffset = MPPointF.getInstanceFrom(dataSet.iconsOffset);
      iconsOffset.x = Utils.convertDpToPixel(iconsOffset.x);
      iconsOffset.y = Utils.convertDpToPixel(iconsOffset.y);

      for (var k = 0; k < reducer.count; k++) {
        final index = reducer.indices[k];

        // Kotlin's Color.argb((255f * alpha).roundToInt(), red, green, blue): the alpha is replaced, not scaled.
        final valueTextColor = dataSet
            .getValueTextColor(index)
            .withAlpha((255 * alpha).round());

        final entry = dataSet.getEntryForIndex(index);

        _pointBuffer[0] = entry.x;
        _pointBuffer[1] = entry.y * phaseY;
        trans.pointValuesToPixel(_pointBuffer);

        final x = _pointBuffer[0];
        final y = _pointBuffer[1];

        if (!viewPortHandler.isInBoundsRight(x)) break;

        if (!viewPortHandler.isInBoundsLeft(x) ||
            !viewPortHandler.isInBoundsY(y)) {
          continue;
        }

        if (dataSet.isDrawValuesEnabled) {
          drawValue(
            c,
            dataSet.valueFormatter,
            entry.size,
            entry,
            i,
            x,
            y + (0.5 * lineHeight),
            valueTextColor,
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

  /// Does nothing; bubble charts have no extras.
  @override
  void drawExtras(ui.Canvas c) {}

  @override
  void drawHighlighted(ui.Canvas c, List<Highlight> indices) {
    final bubbleData = chart.bubbleData;
    if (bubbleData == null) return;

    final phaseY = animator.phaseY;

    for (final high in indices) {
      final set = bubbleData.getDataSetByIndex(high.dataSetIndex);

      if (set == null || !set.isHighlightEnabled) continue;

      final entry = set.getEntryForXValue(high.x, high.y, Rounding.CLOSEST);
      if (entry == null) continue;

      if (entry.y != high.y) continue;

      if (!isInBoundsX(entry, set)) continue;

      final trans = chart.getTransformer(set.axisDependency);

      _sizeBuffer[0] = 0;
      _sizeBuffer[2] = 1;

      trans.pointValuesToPixel(_sizeBuffer);

      final normalizeSize = set.isNormalizeSizeEnabled;

      final maxBubbleWidth = (_sizeBuffer[2] - _sizeBuffer[0]).abs();
      final maxBubbleHeight =
          (viewPortHandler.contentBottom - viewPortHandler.contentTop).abs();
      final referenceSize = math.min(maxBubbleHeight, maxBubbleWidth);

      _pointBuffer[0] = entry.x;
      _pointBuffer[1] = entry.y * phaseY;
      trans.pointValuesToPixel(_pointBuffer);

      high.setDraw(_pointBuffer[0], _pointBuffer[1]);

      final shapeHalf =
          getShapeSize(entry.size, set.maxSize, referenceSize, normalizeSize) /
          2;

      if (!viewPortHandler.isInBoundsTop(_pointBuffer[1] + shapeHalf) ||
          !viewPortHandler.isInBoundsBottom(_pointBuffer[1] - shapeHalf)) {
        continue;
      }

      if (!viewPortHandler.isInBoundsLeft(_pointBuffer[0] + shapeHalf)) {
        continue;
      }

      if (!viewPortHandler.isInBoundsRight(_pointBuffer[0] - shapeHalf)) break;

      final originalColor = set.getColor(
        math.max(set.getEntryIndexOf(entry), 0),
      );

      // The value halved, the alpha kept: Kotlin's RGBToHSV, hsvBuffer[2] *= 0.5f and HSVToColor(alpha, hsvBuffer).
      final hsv = HSVColor.fromColor(originalColor);
      final color = hsv.withValue(hsv.value * 0.5).toColor();

      highlightPaint.color = color;
      highlightPaint.strokeWidth = Utils.convertDpToPixel(
        set.highlightCircleWidth,
      );
      c.drawCircleP(
        _pointBuffer[0],
        _pointBuffer[1],
        shapeHalf,
        highlightPaint,
      );
    }
  }
}
