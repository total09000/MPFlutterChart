// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/charts/HorizontalBarChart.kt
//
// Overloads: getBarBounds(e, outputRect) is the getBarBounds of BarChart with an optional output rectangle.
// Log.i / Log.e are debugPrint, as in Chart.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint, protected;

import '../components/legend.dart';
import '../components/x_axis.dart';
import '../components/y_axis_dependency.dart';
import '../data/bar_entry.dart';
import '../data/entry.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../highlight/highlight.dart';
import '../highlight/horizontal_bar_highlighter.dart';
import '../renderer/horizontal_bar_chart_renderer.dart';
import '../renderer/x_axis_renderer_horizontal_bar_chart.dart';
import '../renderer/y_axis_renderer_horizontal_bar_chart.dart';
import '../utils/float_math.dart';
import '../utils/horizontal_view_port_handler.dart';
import '../utils/mp_point_f.dart';
import '../utils/transformer_horizontal_bar_chart.dart';
import '../utils/utils.dart';
import 'bar_chart.dart';
import 'chart.dart';

/// [BarChart] with horizontal bars. The axes swap roles on screen: the [xAxis] runs vertically along
/// the bars and the two y axes run horizontally along the values. The visible range setters and
/// touch helpers take that swap into account, so callers keep using x for entries and y for values.
class HorizontalBarChart extends BarChart {
  @override
  void init() {
    viewPortHandler = HorizontalViewPortHandler();

    super.init();

    leftAxisTransformer = TransformerHorizontalBarChart(viewPortHandler);
    rightAxisTransformer = TransformerHorizontalBarChart(viewPortHandler);

    renderer = HorizontalBarChartRenderer(this, animator, viewPortHandler);
    highlighter = HorizontalBarHighlighter(this);

    rendererLeftYAxis = YAxisRendererHorizontalBarChart(
      viewPortHandler,
      axisLeft,
      leftAxisTransformer,
    );
    rendererRightYAxis = YAxisRendererHorizontalBarChart(
      viewPortHandler,
      axisRight,
      rightAxisTransformer,
    );
    rendererXAxis = XAxisRendererHorizontalBarChart(
      viewPortHandler,
      xAxis,
      leftAxisTransformer,
      this,
    );
  }

  final MutableRect _offsetsBuffer = MutableRect();

  /// Like [BarChart.calculateLegendOffsets], but a horizontal legend at the top or bottom also reserves the
  /// labels of the y axis on that side, which run along the width here.
  @override
  @protected
  void calculateLegendOffsets(MutableRect offsets) {
    offsets.left = 0;
    offsets.right = 0;
    offsets.top = 0;
    offsets.bottom = 0;

    final legend = this.legend;
    if (!legend.isEnabled || legend.isDrawInsideEnabled) return;

    switch (legend.orientation) {
      case LegendOrientation.VERTICAL:
        switch (legend.horizontalAlignment) {
          case LegendHorizontalAlignment.LEFT:
            offsets.left +=
                math.min(
                  legend.neededWidth,
                  viewPortHandler.chartWidth * legend.maxSizePercent,
                ) +
                Utils.convertDpToPixel(legend.xOffset);
          case LegendHorizontalAlignment.RIGHT:
            offsets.right +=
                math.min(
                  legend.neededWidth,
                  viewPortHandler.chartWidth * legend.maxSizePercent,
                ) +
                Utils.convertDpToPixel(legend.xOffset);
          case LegendHorizontalAlignment.CENTER:
            switch (legend.verticalAlignment) {
              case LegendVerticalAlignment.TOP:
                offsets.top +=
                    math.min(
                      legend.neededHeight,
                      viewPortHandler.chartHeight * legend.maxSizePercent,
                    ) +
                    Utils.convertDpToPixel(legend.yOffset);
              case LegendVerticalAlignment.BOTTOM:
                offsets.bottom +=
                    math.min(
                      legend.neededHeight,
                      viewPortHandler.chartHeight * legend.maxSizePercent,
                    ) +
                    Utils.convertDpToPixel(legend.yOffset);
              case LegendVerticalAlignment.CENTER:
                break;
            }
        }
      case LegendOrientation.HORIZONTAL:
        switch (legend.verticalAlignment) {
          case LegendVerticalAlignment.TOP:
            offsets.top +=
                math.min(
                  legend.neededHeight,
                  viewPortHandler.chartHeight * legend.maxSizePercent,
                ) +
                Utils.convertDpToPixel(legend.yOffset);
            if (axisLeft.isEnabled && axisLeft.isDrawLabelsEnabled) {
              offsets.top += axisLeft.getRequiredHeightSpace(
                rendererLeftYAxis.paintAxisLabels,
              );
            }
          case LegendVerticalAlignment.BOTTOM:
            offsets.bottom +=
                math.min(
                  legend.neededHeight,
                  viewPortHandler.chartHeight * legend.maxSizePercent,
                ) +
                Utils.convertDpToPixel(legend.yOffset);
            if (axisRight.isEnabled && axisRight.isDrawLabelsEnabled) {
              offsets.bottom += axisRight.getRequiredHeightSpace(
                rendererRightYAxis.paintAxisLabels,
              );
            }
          case LegendVerticalAlignment.CENTER:
            break;
        }
    }
  }

  /// Computes the content rectangle with the axes swapped: the y axis labels take space at the top (left axis)
  /// and bottom (right axis), the x axis labels at the left ([XAxisPosition.BOTTOM]) or right
  /// ([XAxisPosition.TOP]). Unlike [BarChart.calculateOffsets], this always recalculates, also while
  /// `setViewPortOffsets` is active, as in Kotlin.
  @override
  void calculateOffsets() {
    var offsetLeft = 0.0;
    var offsetRight = 0.0;
    var offsetTop = 0.0;
    var offsetBottom = 0.0;

    calculateLegendOffsets(_offsetsBuffer);

    offsetLeft += _offsetsBuffer.left;
    offsetTop += _offsetsBuffer.top;
    offsetRight += _offsetsBuffer.right;
    offsetBottom += _offsetsBuffer.bottom;

    if (axisLeft.needsOffset) {
      offsetTop += axisLeft.getRequiredHeightSpace(
        rendererLeftYAxis.paintAxisLabels,
      );
    }

    if (axisRight.needsOffset) {
      offsetBottom += axisRight.getRequiredHeightSpace(
        rendererRightYAxis.paintAxisLabels,
      );
    }

    final xlabelwidth = xAxis.labelRotatedWidth;

    if (xAxis.isEnabled) {
      switch (xAxis.position) {
        case XAxisPosition.BOTTOM:
          offsetLeft += xlabelwidth;
        case XAxisPosition.TOP:
          offsetRight += xlabelwidth;
        case XAxisPosition.BOTH_SIDED:
          offsetLeft += xlabelwidth;
          offsetRight += xlabelwidth;
        default:
          break;
      }
    }

    offsetTop += Utils.convertDpToPixel(extraTopOffset);
    offsetRight += Utils.convertDpToPixel(extraRightOffset);
    offsetBottom += Utils.convertDpToPixel(extraBottomOffset);
    offsetLeft += Utils.convertDpToPixel(extraLeftOffset);

    final minOffset = Utils.convertDpToPixel(this.minOffset);

    viewPortHandler.restrainViewPort(
      math.max(minOffset, offsetLeft),
      math.max(minOffset, offsetTop),
      math.max(minOffset, offsetRight),
      math.max(minOffset, offsetBottom),
    );

    if (isLogEnabled) {
      debugPrint(
        '${Chart.LOG_TAG}: offsetLeft: $offsetLeft, offsetTop: $offsetTop, offsetRight: $offsetRight, '
        'offsetBottom: $offsetBottom',
      );
      debugPrint('${Chart.LOG_TAG}: Content: ${viewPortHandler.contentRect}');
    }

    prepareOffsetMatrix();
    prepareValuePxMatrix();
  }

  /// Maps the y axis values along the transformers' x and the x values along their y.
  @override
  @protected
  void prepareValuePxMatrix() {
    rightAxisTransformer.prepareMatrixValuePx(
      axisRight.axisMinimum,
      axisRight.axisRange,
      xAxis.axisRange,
      xAxis.axisMinimum,
    );
    leftAxisTransformer.prepareMatrixValuePx(
      axisLeft.axisMinimum,
      axisLeft.axisRange,
      xAxis.axisRange,
      xAxis.axisMinimum,
    );
  }

  /// The draw position of [high] with x and y swapped, see
  /// [HorizontalBarChartRenderer.setHighlightDrawPos].
  @override
  @protected
  Float32List getMarkerPosition(Highlight high) =>
      Float32List.fromList([high.drawY, high.drawX]);

  /// Bounding box in pixels of the horizontal bar drawn for [e]: from 0 to its y value along the width and half
  /// a bar width either side of its x value along the height. It is written into [outputRect] when one is given,
  /// and returned.
  ///
  /// Returns the bounds, or a rectangle with `Float.MIN_VALUE` ([Utils.FLOAT_EPSILON]) on all sides when the
  /// entry is not in the data.
  @override
  MutableRect getBarBounds(BarEntry e, [MutableRect? outputRect]) {
    final bounds = outputRect ?? MutableRect();

    final data = this.data;
    final set = data?.getDataSetForEntry(e);

    if (data == null || set == null) {
      bounds.set(
        Utils.FLOAT_EPSILON,
        Utils.FLOAT_EPSILON,
        Utils.FLOAT_EPSILON,
        Utils.FLOAT_EPSILON,
      );
      return bounds;
    }

    final y = e.y;
    final x = e.x;

    final barWidth = data.barWidth;

    final top = x - barWidth / 2;
    final bottom = x + barWidth / 2;
    final left = y >= 0 ? y : 0.0;
    final right = y <= 0 ? y : 0.0;

    bounds.set(left, top, right, bottom);

    getTransformer(set.axisDependency).rectValueToPixel(bounds);
    return bounds;
  }

  final Float32List _positionBuffer = Float32List(2);

  /// Pixel position of an entry inside the view: its y value along the width and its x value along the height.
  @override
  MPPointF? getPosition(Entry? e, AxisDependency axis) {
    if (e == null) return null;

    final vals = _positionBuffer;
    vals[0] = e.y;
    vals[1] = e.x;

    getTransformer(axis).pointValuesToPixel(vals);

    return MPPointF(vals[0], vals[1]);
  }

  /// Like [BarChart.getHighlightByTouchPoint]; the highlighter takes the touch position as ([y], [x]).
  @override
  Highlight? getHighlightByTouchPoint(double x, double y) {
    if (data == null) {
      if (isLogEnabled) {
        debugPrint("${Chart.LOG_TAG}: Can't select by touch. No data set.");
      }
      return null;
    }
    final h = highlighter.getHighlight(y, x);
    if (h == null || !isHighlightFullBarEnabled) return h;

    return Highlight.stackedWithPixels(
      h.x,
      h.y,
      h.xPx,
      h.yPx,
      h.dataSetIndex,
      -1,
      h.axis,
    );
  }

  /// The x value at the bottom of the content area, where the x axis starts here.
  @override
  double get lowestVisibleX {
    getTransformer(AxisDependency.LEFT).getValuesByTouchPoint(
      viewPortHandler.contentLeft,
      viewPortHandler.contentBottom,
      posForGetLowestVisibleX,
    );
    return toKotlinFloat(
      math.max(xAxis.axisMinimum, posForGetLowestVisibleX.y),
    );
  }

  /// The x value at the top of the content area, where the x axis ends here.
  @override
  double get highestVisibleX {
    getTransformer(AxisDependency.LEFT).getValuesByTouchPoint(
      viewPortHandler.contentLeft,
      viewPortHandler.contentTop,
      posForGetHighestVisibleX,
    );
    return toKotlinFloat(
      math.min(xAxis.axisMaximum, posForGetHighestVisibleX.y),
    );
  }

  /// Like [BarChart.setVisibleXRangeMaximum], but limits the vertical zoom, along which the x axis runs.
  @override
  void setVisibleXRangeMaximum(double maxXRange) {
    final xScale = scaleForVisibleRange(xAxis.axisRange, maxXRange);
    if (xScale == null) return;
    viewPortHandler.setMinimumScaleY(xScale);
  }

  /// Like [BarChart.setVisibleXRangeMinimum], but limits the vertical zoom, along which the x axis runs.
  @override
  void setVisibleXRangeMinimum(double minXRange) {
    final xScale = scaleForVisibleRange(xAxis.axisRange, minXRange);
    if (xScale == null) return;
    viewPortHandler.setMaximumScaleY(xScale);
  }

  /// Like [BarChart.setVisibleXRange], but limits the vertical zoom, along which the x axis runs.
  @override
  void setVisibleXRange(double minXRange, double maxXRange) {
    final minScale = scaleForVisibleRange(xAxis.axisRange, maxXRange);
    if (minScale == null) return;
    final maxScale = scaleForVisibleRange(xAxis.axisRange, minXRange);
    if (maxScale == null) return;
    viewPortHandler.setMinMaxScaleY(minScale, maxScale);
  }

  /// Like [BarChart.setVisibleYRangeMaximum], but limits the horizontal zoom, along which the y axes run.
  @override
  void setVisibleYRangeMaximum(double maxYRange, AxisDependency axis) {
    final yScale = scaleForVisibleRange(getAxisRange(axis), maxYRange);
    if (yScale == null) return;
    viewPortHandler.setMinimumScaleX(yScale);
  }

  /// Like [BarChart.setVisibleYRangeMinimum], but limits the horizontal zoom, along which the y axes run.
  @override
  void setVisibleYRangeMinimum(double minYRange, AxisDependency axis) {
    final yScale = scaleForVisibleRange(getAxisRange(axis), minYRange);
    if (yScale == null) return;
    viewPortHandler.setMaximumScaleX(yScale);
  }

  /// Like [BarChart.setVisibleYRange], but limits the horizontal zoom, along which the y axes run.
  @override
  void setVisibleYRange(
    double minYRange,
    double maxYRange,
    AxisDependency axis,
  ) {
    final minScale = scaleForVisibleRange(getAxisRange(axis), maxYRange);
    if (minScale == null) return;
    final maxScale = scaleForVisibleRange(getAxisRange(axis), minYRange);
    if (maxScale == null) return;
    viewPortHandler.setMinMaxScaleX(minScale, maxScale);
  }

  /// Draws three horizontal bars from the left edge of [bounds], top to bottom.
  @override
  @protected
  void drawNoDataIcon(ui.Canvas canvas, MutableRect bounds, ChartPaint paint) {
    paint.style = PaintStyle.FILL;
    final barHeight = bounds.height() / 4.5;
    final gap = (bounds.height() - 3 * barHeight) / 2;
    final widths = Float32List.fromList([0.55, 1, 0.75]);
    final radius = barHeight / 3.5;
    for (var i = 0; i <= 2; i++) {
      final top = bounds.top + i * (barHeight + gap);
      canvas.drawRoundRectP(
        MutableRect(
          bounds.left,
          top,
          bounds.left + bounds.width() * widths[i],
          top + barHeight,
        ),
        radius,
        radius,
        paint,
      );
    }
  }
}
