// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/ScatterChartRenderer.kt
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../animation/chart_animator.dart';
import '../data/data_set.dart';
import '../highlight/highlight.dart';
import '../interfaces/dataprovider/scatter_data_provider.dart';
import '../interfaces/datasets/i_scatter_data_set.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';
import '../utils/view_port_handler.dart';
import 'line_scatter_candle_radar_renderer.dart';

/// Draws the points of a [ScatterDataProvider]. Each entry is drawn at its pixel position by the shape renderer
/// of its data set; a highlight is shown with the standard highlight lines.
class ScatterChartRenderer extends LineScatterCandleRadarRenderer {
  /// Creates a renderer for the scatter data of [chart].
  ScatterChartRenderer(
    this.chart,
    ChartAnimator animator,
    ViewPortHandler viewPortHandler,
  ) : super(animator, viewPortHandler);

  /// The chart that supplies the scatter data and the transformers.
  @protected
  final ScatterDataProvider chart;

  final Float32List _pixelBuffer = Float32List(2);

  /// Does nothing; scatter shapes are drawn without a buffer.
  @override
  void initBuffers() {}

  @override
  void drawData(ui.Canvas c) {
    final scatterData = chart.scatterData;
    if (scatterData == null) return;

    for (final set in scatterData.dataSets) {
      if (set.isVisible) drawDataSet(c, set);
    }
  }

  /// Draws every entry of [dataSet] that is visible in the content rectangle with the data set's shape renderer,
  /// stopping at the entry count revealed by the x animation phase.
  @protected
  void drawDataSet(ui.Canvas c, IScatterDataSet dataSet) {
    if (dataSet.entryCount < 1) return;

    final trans = chart.getTransformer(dataSet.axisDependency);

    xBounds.set(chart, dataSet);
    reduceVisible(chart, dataSet);

    final phaseY = animator.phaseY;

    final renderer = dataSet.shapeRenderer;

    for (var k = 0; k < reducer.count; k++) {
      final index = reducer.indices[k];
      final e = dataSet.getEntryForIndex(index);

      _pixelBuffer[0] = e.x;
      _pixelBuffer[1] = e.y * phaseY;

      trans.pointValuesToPixel(_pixelBuffer);

      if (!viewPortHandler.isInBoundsRight(_pixelBuffer[0])) break;

      if (!viewPortHandler.isInBoundsLeft(_pixelBuffer[0]) ||
          !viewPortHandler.isInBoundsY(_pixelBuffer[1])) {
        continue;
      }

      renderPaint.color = dataSet.getColor(index);
      renderer.renderShape(
        c,
        dataSet,
        viewPortHandler,
        _pixelBuffer[0],
        _pixelBuffer[1],
        renderPaint,
      );
    }
  }

  /// Draws the y value of each entry that was drawn one shape size above it.
  @override
  void drawValues(ui.Canvas c) {
    final scatterData = chart.scatterData;
    if (scatterData == null) return;
    final dataSets = scatterData.dataSets;

    for (var i = 0; i < scatterData.dataSetCount; i++) {
      final dataSet = dataSets[i];

      if (!shouldDrawValues(chart, dataSet) || dataSet.entryCount < 1) {
        continue;
      }

      applyValueTextStyle(dataSet);

      xBounds.set(chart, dataSet);
      reduceVisible(chart, dataSet);

      final positions = reducedPositions(
        dataSet,
        chart.getTransformer(dataSet.axisDependency),
        animator.phaseY,
      );

      final shapeSize = Utils.convertDpToPixel(dataSet.scatterShapeSize);

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
            entry.y,
            entry,
            i,
            x,
            y - shapeSize,
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

  /// Does nothing; scatter charts have no extras.
  @override
  void drawExtras(ui.Canvas c) {}

  @override
  void drawHighlighted(ui.Canvas c, List<Highlight> indices) {
    final scatterData = chart.scatterData;
    if (scatterData == null) return;

    for (final high in indices) {
      final set = scatterData.getDataSetByIndex(high.dataSetIndex);

      if (set == null || !set.isHighlightEnabled) continue;

      final e = set.getEntryForXValue(high.x, high.y, Rounding.CLOSEST);
      if (e == null) continue;

      if (!isInBoundsX(e, set)) continue;

      final pix = chart
          .getTransformer(set.axisDependency)
          .getPixelForValues(e.x, e.y * animator.phaseY);

      high.setDraw(toKotlinFloat(pix.x), toKotlinFloat(pix.y));

      drawHighlightLines(c, toKotlinFloat(pix.x), toKotlinFloat(pix.y), set);
    }
  }
}
