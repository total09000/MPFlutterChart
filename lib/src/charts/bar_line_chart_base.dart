// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/charts/BarLineChartBase.kt
//
// View.scaleX/scaleY clash in Kotlin is why the zoom factors are named zoomX/zoomY; postInvalidate() is invalidate().
// Overloads: zoom(scaleX, scaleY, x, y) and zoom(scaleX, scaleY, xValue, yValue, axis) are one zoom with an optional
// trailing axis; getValuesByTouchPoint(x, y, axis[, outputPoint]) returns the point it wrote to.
// Flutter addition: onDraw ends with notifyAfterDraw() (Chart.afterDrawListeners, not in Kotlin).
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint, internal, protected;

import '../components/legend.dart';
import '../components/x_axis.dart';
import '../components/y_axis.dart';
import '../data/bar_line_scatter_candle_bubble_data.dart';
import '../data/entry.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/matrix.dart';
import '../graphics/mutable_rect.dart';
import '../highlight/chart_highlighter.dart';
import '../interfaces/dataprovider/bar_line_scatter_candle_bubble_data_provider.dart';
import '../interfaces/datasets/i_bar_line_scatter_candle_bubble_data_set.dart';
import '../jobs/animated_move_view_job.dart';
import '../jobs/animated_zoom_job.dart';
import '../jobs/move_view_job.dart';
import '../jobs/zoom_job.dart';
import '../listener/bar_line_chart_touch_listener.dart';
import '../renderer/x_axis_renderer.dart';
import '../renderer/y_axis_renderer.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_d.dart';
import '../utils/mp_point_f.dart';
import '../utils/transformer.dart';
import '../utils/utils.dart';
import '../widgets/chart_touch_event.dart';
import 'chart.dart';

/// Base class of the charts with an x axis and two y axes: `LineChart`, `BarChart`, `ScatterChart`,
/// `CandleStickChart`, `BubbleChart` and `CombinedChart`. It adds the axes, zooming, dragging and the
/// viewport functions, and implements [BarLineScatterCandleBubbleDataProvider] for the renderers.
///
/// [T] is the [BarLineScatterCandleBubbleData] type this chart displays, fixed by each subclass.
abstract class BarLineChartBase<T extends BarLineScatterCandleBubbleData>
    extends Chart<T>
    implements BarLineScatterCandleBubbleDataProvider {
  /// Value labels of a data set are only drawn while at most this many of its entries are inside the visible
  /// x range, so zooming in brings them back. Default 100.
  @override
  int maxVisibleCount = 100;

  /// Whether entries that share a pixel column may be dropped while drawing. Off by default, so a chart draws every
  /// entry you gave it. Line circles that another circle would cover are always skipped, with or without this.
  ///
  /// Turn it on when a lot of entries are on screen at once and each one costs a draw call of its own: a bar
  /// chart, a scatter chart, or a line with a color per segment. It does not pay for a plain single color line,
  /// which is already one call to the canvas. The reduction keeps the first, lowest, highest and last entry of every
  /// pixel column, so peaks survive.
  @override
  bool isDecimationEnabled = false;

  /// Whether the y axes are recalculated on every draw from the entries currently in view.
  bool isAutoScaleMinMaxEnabled = false;

  /// Whether a pinch scales both axes together. When false, x and y can be scaled separately.
  bool isPinchZoomEnabled = false;

  /// Whether a double tap zooms in.
  bool isDoubleTapToZoomEnabled = true;

  /// Whether dragging highlights values while the chart is fully zoomed out and cannot be panned.
  bool isHighlightPerDragEnabled = true;

  /// Whether the chart can be dragged horizontally.
  bool isDragXEnabled = true;

  /// Whether the chart can be dragged vertically.
  bool isDragYEnabled = true;

  /// Whether the chart can be scaled horizontally by gesture.
  bool isScaleXEnabled = true;

  /// Whether the chart can be scaled vertically by gesture.
  bool isScaleYEnabled = true;

  /// Paint used for the grid background, filled light grey by default.
  late ChartPaint gridBackgroundPaint;

  /// Paint used for the border around the content area.
  @protected
  late ChartPaint borderPaint;

  /// Whether the content area is filled with [gridBackgroundPaint].
  bool isDrawGridBackgroundEnabled = false;

  /// Whether a border is drawn around the content area. With it on, the axis lines are redundant.
  bool isDrawBordersEnabled = false;

  /// Whether value labels are clipped to the content area instead of bleeding outside it.
  bool isClipValuesToContentEnabled = false;

  /// Whether data and highlights are clipped to the content area. Turn it off when thick lines or
  /// large shapes inside the content get cut at its edges.
  bool isClipDataToContentEnabled = true;

  /// Smallest space in dp between the view edge and the content area on every side. Default 15.
  double minOffset = 15;

  /// Whether the top left corner stays at the same values when the view is resized, such as on rotation.
  bool isKeepPositionOnRotation = false;

  late YAxis _axisLeft;

  /// The left y axis.
  YAxis get axisLeft => _axisLeft;

  @protected
  set axisLeft(YAxis value) => _axisLeft = value;

  late YAxis _axisRight;

  /// The right y axis.
  YAxis get axisRight => _axisRight;

  @protected
  set axisRight(YAxis value) => _axisRight = value;

  /// Draws [axisLeft].
  late YAxisRenderer rendererLeftYAxis;

  /// Draws [axisRight].
  late YAxisRenderer rendererRightYAxis;

  /// Converts values that depend on [axisLeft] to pixels and back.
  @protected
  late Transformer leftAxisTransformer;

  /// Converts values that depend on [axisRight] to pixels and back.
  @protected
  late Transformer rightAxisTransformer;

  /// Draws the [xAxis].
  late XAxisRenderer rendererXAxis;

  @override
  void init() {
    super.init();

    axisLeft = YAxis(AxisDependency.LEFT);
    axisRight = YAxis(AxisDependency.RIGHT);

    leftAxisTransformer = Transformer(viewPortHandler);
    rightAxisTransformer = Transformer(viewPortHandler);

    rendererLeftYAxis = YAxisRenderer(
      viewPortHandler,
      axisLeft,
      leftAxisTransformer,
    );
    rendererRightYAxis = YAxisRenderer(
      viewPortHandler,
      axisRight,
      rightAxisTransformer,
    );

    rendererXAxis = XAxisRenderer(viewPortHandler, xAxis, leftAxisTransformer);

    highlighter = ChartHighlighter(this);

    chartTouchListener = BarLineChartTouchListener(
      this,
      viewPortHandler.matrixTouch,
      3,
    );

    gridBackgroundPaint = ChartPaint(antiAlias: false)
      ..style = PaintStyle.FILL
      ..color = const ui.Color.fromARGB(255, 240, 240, 240);

    borderPaint = ChartPaint(antiAlias: false)
      ..style = PaintStyle.STROKE
      ..color = const ui.Color(0xFF000000)
      ..strokeWidth = Utils.convertDpToPixel(1);
  }

  int _totalTime = 0;
  int _drawCycles = 0;

  @override
  void onDraw(ui.Canvas canvas) {
    super.onDraw(canvas);

    if (showsEmptyState) return;

    final starttime = DateTime.now().millisecondsSinceEpoch;

    drawGridBackground(canvas);

    if (isAutoScaleMinMaxEnabled) autoScale();

    if (axisLeft.isEnabled) {
      rendererLeftYAxis.computeAxis(
        axisLeft.axisMinimum,
        axisLeft.axisMaximum,
        axisLeft.isInverted,
      );
    }
    if (axisRight.isEnabled) {
      rendererRightYAxis.computeAxis(
        axisRight.axisMinimum,
        axisRight.axisMaximum,
        axisRight.isInverted,
      );
    }
    if (xAxis.isEnabled) {
      rendererXAxis.computeAxis(xAxis.axisMinimum, xAxis.axisMaximum, false);
    }

    // The gutters were sized from the axis labels that the lines above have just replaced.
    if (isAutoScaleMinMaxEnabled) {
      calculateOffsets();
      viewPortHandler.refresh(viewPortHandler.matrixTouch, this, false);
    }

    rendererXAxis.renderAxisLine(canvas);
    rendererLeftYAxis.renderAxisLine(canvas);
    rendererRightYAxis.renderAxisLine(canvas);

    if (xAxis.isDrawGridLinesBehindDataEnabled) {
      rendererXAxis.renderGridLines(canvas);
    }
    if (axisLeft.isDrawGridLinesBehindDataEnabled) {
      rendererLeftYAxis.renderGridLines(canvas);
    }
    if (axisRight.isDrawGridLinesBehindDataEnabled) {
      rendererRightYAxis.renderGridLines(canvas);
    }

    if (xAxis.isEnabled && xAxis.isDrawLimitLinesBehindDataEnabled) {
      rendererXAxis.renderLimitLines(canvas);
    }
    if (axisLeft.isEnabled && axisLeft.isDrawLimitLinesBehindDataEnabled) {
      rendererLeftYAxis.renderLimitLines(canvas);
    }
    if (axisRight.isEnabled && axisRight.isDrawLimitLinesBehindDataEnabled) {
      rendererRightYAxis.renderLimitLines(canvas);
    }

    final clipRestoreCount = canvas.getSaveCount();
    canvas.save();

    if (isClipDataToContentEnabled) {
      canvas.clipRectM(viewPortHandler.contentRect);
    }

    renderer.drawData(canvas);

    if (!xAxis.isDrawGridLinesBehindDataEnabled) {
      rendererXAxis.renderGridLines(canvas);
    }
    if (!axisLeft.isDrawGridLinesBehindDataEnabled) {
      rendererLeftYAxis.renderGridLines(canvas);
    }
    if (!axisRight.isDrawGridLinesBehindDataEnabled) {
      rendererRightYAxis.renderGridLines(canvas);
    }

    final highlighted = this.highlighted;
    if (valuesToHighlight()) renderer.drawHighlighted(canvas, highlighted);

    canvas.restoreToCount(clipRestoreCount);

    renderer.drawExtras(canvas);

    if (xAxis.isEnabled && !xAxis.isDrawLimitLinesBehindDataEnabled) {
      rendererXAxis.renderLimitLines(canvas);
    }
    if (axisLeft.isEnabled && !axisLeft.isDrawLimitLinesBehindDataEnabled) {
      rendererLeftYAxis.renderLimitLines(canvas);
    }
    if (axisRight.isEnabled && !axisRight.isDrawLimitLinesBehindDataEnabled) {
      rendererRightYAxis.renderLimitLines(canvas);
    }

    rendererXAxis.renderAxisLabels(canvas);
    rendererLeftYAxis.renderAxisLabels(canvas);
    rendererRightYAxis.renderAxisLabels(canvas);

    if (isClipValuesToContentEnabled) {
      final valuesClipRestoreCount = canvas.getSaveCount();
      canvas.save();
      canvas.clipRectM(viewPortHandler.contentRect);
      renderer.drawValues(canvas);
      canvas.restoreToCount(valuesClipRestoreCount);
    } else {
      renderer.drawValues(canvas);
    }

    legendRenderer.renderLegend(canvas);

    drawDescription(canvas);

    drawMarkers(canvas);

    if (isLogEnabled) {
      final drawtime = DateTime.now().millisecondsSinceEpoch - starttime;
      _totalTime += drawtime;
      _drawCycles += 1;
      final average = _totalTime ~/ _drawCycles;
      debugPrint(
        '${Chart.LOG_TAG}: Drawtime: $drawtime ms, average: $average ms, cycles: $_drawCycles',
      );
    }

    // Not in Kotlin, see Chart.afterDrawListeners.
    notifyAfterDraw();
  }

  /// Resets the draw time statistics printed while [isLogEnabled] is true.
  void resetTracking() {
    _totalTime = 0;
    _drawCycles = 0;
  }

  /// Refreshes the value to pixel matrices of both transformers from the current axis ranges.
  @protected
  void prepareValuePxMatrix() {
    if (isLogEnabled) {
      debugPrint(
        '${Chart.LOG_TAG}: Preparing Value-Px Matrix, xmin: ${xAxis.axisMinimum}, xmax: ${xAxis.axisMaximum}, '
        'xdelta: ${xAxis.axisRange}',
      );
    }

    rightAxisTransformer.prepareMatrixValuePx(
      xAxis.axisMinimum,
      xAxis.axisRange,
      axisRight.axisRange,
      axisRight.axisMinimum,
    );
    leftAxisTransformer.prepareMatrixValuePx(
      xAxis.axisMinimum,
      xAxis.axisRange,
      axisLeft.axisRange,
      axisLeft.axisMinimum,
    );
  }

  /// Refreshes the offset matrices of both transformers, honouring inverted axes.
  @protected
  void prepareOffsetMatrix() {
    rightAxisTransformer.prepareMatrixOffset(axisRight.isInverted);
    leftAxisTransformer.prepareMatrixOffset(axisLeft.isInverted);
  }

  @override
  void notifyDataSetChanged() {
    final data = this.data;
    if (data == null) {
      if (isLogEnabled) {
        debugPrint('${Chart.LOG_TAG}: Preparing... DATA NOT SET.');
      }
      return;
    } else {
      if (isLogEnabled) debugPrint('${Chart.LOG_TAG}: Preparing...');
    }

    data.notifyDataChanged();

    if (isRendererInitialized) renderer.initBuffers();

    calcMinMax();

    computeAxes();

    legendRenderer.computeLegend(data);

    calculateOffsets();
    invalidate();
  }

  @internal
  @override
  void computeAxes() {
    rendererLeftYAxis.computeAxis(
      axisLeft.axisMinimum,
      axisLeft.axisMaximum,
      axisLeft.isInverted,
    );
    rendererRightYAxis.computeAxis(
      axisRight.axisMinimum,
      axisRight.axisMaximum,
      axisRight.isInverted,
    );
    rendererXAxis.computeAxis(xAxis.axisMinimum, xAxis.axisMaximum, false);
  }

  /// Recalculates the y axes from the entries between [lowestVisibleX] and [highestVisibleX], then recalculates
  /// the offsets. Called on every draw while [isAutoScaleMinMaxEnabled] is on; call it yourself, followed by
  /// [invalidate], when you want the same after changing data or the visible range.
  void autoScale() {
    final data = this.data;
    if (data == null) return;

    final fromX = lowestVisibleX;
    final toX = highestVisibleX;

    data.calcMinMaxY(fromX, toX);

    xAxis.calculate(data.xMin, data.xMax);

    axisLeft.calculate(
      data.getYMin(AxisDependency.LEFT),
      data.getYMax(AxisDependency.LEFT),
    );
    axisRight.calculate(
      data.getYMin(AxisDependency.RIGHT),
      data.getYMax(AxisDependency.RIGHT),
    );

    calculateOffsets();
  }

  @override
  void calcMinMax() {
    final data = this.data;
    if (data == null) return;

    xAxis.calculate(data.xMin, data.xMax);

    axisLeft.calculate(
      data.getYMin(AxisDependency.LEFT),
      data.getYMax(AxisDependency.LEFT),
    );
    axisRight.calculate(
      data.getYMin(AxisDependency.RIGHT),
      data.getYMax(AxisDependency.RIGHT),
    );
  }

  /// Writes the space in pixels the legend needs on each side into [offsets]. Zero when it is drawn inside.
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
  }

  final MutableRect _offsetsBuffer = MutableRect();

  /// Computes the content rectangle from legend, axis labels, extra offsets and [minOffset], then
  /// refreshes the transformers. The rectangle is left alone while [setViewPortOffsets] is active.
  @override
  void calculateOffsets() {
    if (!_customViewPortEnabled) {
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
        offsetLeft += axisLeft.getRequiredWidthSpace(
          rendererLeftYAxis.paintAxisLabels,
        );
      }

      if (axisRight.needsOffset) {
        offsetRight += axisRight.getRequiredWidthSpace(
          rendererRightYAxis.paintAxisLabels,
        );
      }

      if (xAxis.isEnabled && xAxis.isDrawLabelsEnabled) {
        final xLabelHeight =
            xAxis.labelRotatedHeight + Utils.convertDpToPixel(xAxis.yOffset);

        switch (xAxis.position) {
          case XAxisPosition.BOTTOM:
            offsetBottom += xLabelHeight;
          case XAxisPosition.TOP:
            offsetTop += xLabelHeight;
          case XAxisPosition.BOTH_SIDED:
            offsetBottom += xLabelHeight;
            offsetTop += xLabelHeight;
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
    }

    prepareOffsetMatrix();
    prepareValuePxMatrix();
  }

  /// Fills the content area and draws its border when the matching flags are on.
  @protected
  void drawGridBackground(ui.Canvas c) {
    if (isDrawGridBackgroundEnabled) {
      c.drawRectP(viewPortHandler.contentRect, gridBackgroundPaint);
    }

    if (isDrawBordersEnabled) {
      c.drawRectP(viewPortHandler.contentRect, borderPaint);
    }
  }

  @override
  Transformer getTransformer(AxisDependency axis) {
    return axis == AxisDependency.LEFT
        ? leftAxisTransformer
        : rightAxisTransformer;
  }

  @override
  bool onTouchEvent(ChartTouchEvent event) {
    super.onTouchEvent(event);
    if (!isChartTouchListenerInitialized || data == null) return false;

    if (!isTouchEnabled) return false;

    return chartTouchListener.onTouch(this, event);
  }

  @override
  void computeScroll() {
    final listener = chartTouchListener;
    if (listener is BarLineChartTouchListener) listener.computeScroll();
  }

  /// Also stops a running fling deceleration, whose ticker runs on the host's vsync.
  ///
  /// Not in Kotlin, where a detached view simply stops getting `computeScroll` calls: here no ticker may outlive the
  /// host.
  @override
  void onDetachedFromWindow() {
    _stopDeceleration();
    super.onDetachedFromWindow();
  }

  /// Also stops a running fling deceleration, whose ticker runs on the previous vsync. Not in Kotlin.
  @override
  void onHostVsyncChanged() {
    _stopDeceleration();
    super.onHostVsyncChanged();
  }

  /// Stops the fling deceleration of the touch listener, once one is assigned.
  void _stopDeceleration() {
    if (!isChartTouchListenerInitialized) return;
    final listener = chartTouchListener;
    if (listener is BarLineChartTouchListener) listener.stopDeceleration();
  }

  /// Scratch matrix reused by the zoom functions.
  @protected
  final Matrix zoomMatrixBuffer = Matrix();

  /// Zooms in by a factor of 1.4 around the content center right away, recalculates offsets and redraws.
  void zoomIn() {
    final center = viewPortHandler.contentCenter;

    viewPortHandler.zoomIn(center.x, -center.y, zoomMatrixBuffer);
    viewPortHandler.refresh(zoomMatrixBuffer, this, false);

    MPPointF.recycleInstance(center);

    calculateOffsets();
    invalidate();
  }

  /// Zooms out by a factor of 0.7 around the content center right away, recalculates offsets and redraws.
  void zoomOut() {
    final center = viewPortHandler.contentCenter;

    viewPortHandler.zoomOut(center.x, -center.y, zoomMatrixBuffer);
    viewPortHandler.refresh(zoomMatrixBuffer, this, false);

    MPPointF.recycleInstance(center);

    calculateOffsets();
    invalidate();
  }

  /// Takes the zoom back to 1 around the content center, recalculates offsets and redraws. [fitScreen]
  /// additionally resets the scale minima.
  void resetZoom() {
    viewPortHandler.resetZoom(zoomMatrixBuffer);
    viewPortHandler.refresh(zoomMatrixBuffer, this, false);

    calculateOffsets();
    invalidate();
  }

  /// Zooms by the given factors around a position. Above 1 [scaleX] and [scaleY] zoom in, below 1 they zoom out.
  ///
  /// Without [axis], ([x], [y]) is the zoom center in pixels and the zoom happens right away, followed by recalculating
  /// the offsets and a redraw (Kotlin's `zoom(scaleX, scaleY, x, y)`).
  ///
  /// With [axis], ([x], [y]) is the zoom center in values, `y` in values of [axis], and the zoom runs as a viewport
  /// job, so it takes effect once the chart has a size (see [addViewportJob]) (Kotlin's
  /// `zoom(scaleX, scaleY, xValue, yValue, axis)`).
  ///
  /// Does nothing when any of the numbers is not finite.
  void zoom(
    double scaleX,
    double scaleY,
    double x,
    double y, [
    AxisDependency? axis,
  ]) {
    if (!_allFinite([scaleX, scaleY, x, y])) return;
    if (axis != null) {
      final job = ZoomJob.getInstance(
        viewPortHandler,
        scaleX,
        scaleY,
        x,
        y,
        getTransformer(axis),
        axis,
        this,
      );
      addViewportJob(job.run);
      return;
    }
    viewPortHandler.zoom(scaleX, scaleY, x, -y, zoomMatrixBuffer);
    viewPortHandler.refresh(zoomMatrixBuffer, this, false);

    calculateOffsets();
    invalidate();
  }

  /// Zooms by the given factors around the content center right away, recalculates offsets and redraws.
  ///
  /// Above 1 [scaleX] and [scaleY] zoom in, below 1 they zoom out.
  void zoomToCenter(double scaleX, double scaleY) {
    if (!_allFinite([scaleX, scaleY])) return;
    final center = centerOffsets;

    final save = zoomMatrixBuffer;
    viewPortHandler.zoom(scaleX, scaleY, center.x, -center.y, save);
    viewPortHandler.refresh(save, this, false);
    calculateOffsets();
    invalidate();
  }

  /// Animates from the current zoom and position to the given zoom factors, centered on a position given
  /// in values. Runs as a viewport job, so it starts once the chart has a size (see [addViewportJob]).
  ///
  /// [scaleX] and [scaleY] are the target zoom factors, 1 being fully zoomed out; [xValue] the target center on the x
  /// axis and [yValue] on the y axis, in values of [axis]; [duration] the animation duration in milliseconds.
  void zoomAndCenterAnimated(
    double scaleX,
    double scaleY,
    double xValue,
    double yValue,
    AxisDependency axis,
    int duration,
  ) {
    if (!_allFinite([scaleX, scaleY, xValue, yValue])) return;
    final origin = getValuesByTouchPoint(
      viewPortHandler.contentLeft,
      viewPortHandler.contentTop,
      axis,
    );

    final job = AnimatedZoomJob.getInstance(
      viewPortHandler,
      this,
      getTransformer(axis),
      getAxis(axis),
      xAxis.axisRange,
      scaleX,
      scaleY,
      viewPortHandler.scaleX,
      viewPortHandler.scaleY,
      xValue,
      yValue,
      toKotlinFloat(origin.x),
      toKotlinFloat(origin.y),
      duration,
    );
    addViewportJob(job.run);

    MPPointD.recycleInstance(origin);
  }

  /// Scratch matrix reused by [fitScreen].
  @protected
  final Matrix fitScreenMatrixBuffer = Matrix();

  /// Undoes all zooming and dragging so the data fills the content area, then recalculates offsets and redraws.
  void fitScreen() {
    final save = fitScreenMatrixBuffer;
    viewPortHandler.fitScreen(save);
    viewPortHandler.refresh(save, this, false);

    calculateOffsets();
    invalidate();
  }

  /// Sets how far the chart can be zoomed out. A factor of 1 means fully zoomed out; smaller values
  /// are raised to 1. The current zoom is clamped at once.
  void setScaleMinima(double scaleX, double scaleY) {
    viewPortHandler.setMinimumScaleX(scaleX);
    viewPortHandler.setMinimumScaleY(scaleY);
  }

  /// Limits how much of the x axis can be visible at once, so the user cannot zoom out further.
  /// Computed from the current x axis range, so call it after [data] is set. A range that is not above 0 does nothing.
  ///
  /// [maxXRange] is the largest visible span in x values, for example 10 shows at most 10 units without scrolling.
  void setVisibleXRangeMaximum(double maxXRange) {
    final xScale = scaleForVisibleRange(xAxis.axisRange, maxXRange);
    if (xScale == null) return;
    viewPortHandler.setMinimumScaleX(xScale);
  }

  /// Limits how little of the x axis can be visible at once, so the user cannot zoom in further.
  /// Computed from the current x axis range, so call it after [data] is set. A range that is not above 0 does nothing.
  ///
  /// [minXRange] is the smallest visible span in x values.
  void setVisibleXRangeMinimum(double minXRange) {
    final xScale = scaleForVisibleRange(xAxis.axisRange, minXRange);
    if (xScale == null) return;
    viewPortHandler.setMaximumScaleX(xScale);
  }

  /// Limits the visible span of the x axis in both directions. Computed from the current x axis range,
  /// so call it after [data] is set. A range that is not above 0 does nothing.
  ///
  /// [minXRange] is the smallest visible span in x values, [maxXRange] the largest.
  void setVisibleXRange(double minXRange, double maxXRange) {
    final minScale = scaleForVisibleRange(xAxis.axisRange, maxXRange);
    if (minScale == null) return;
    final maxScale = scaleForVisibleRange(xAxis.axisRange, minXRange);
    if (maxScale == null) return;
    viewPortHandler.setMinMaxScaleX(minScale, maxScale);
  }

  /// Limits how much of a y axis can be visible at once, so the user cannot zoom out further.
  /// Computed from the current axis range, so call it after [data] is set. A range that is not above 0 does nothing.
  ///
  /// [maxYRange] is the largest visible span in y values and [axis] the y axis the span refers to.
  void setVisibleYRangeMaximum(double maxYRange, AxisDependency axis) {
    final yScale = scaleForVisibleRange(getAxisRange(axis), maxYRange);
    if (yScale == null) return;
    viewPortHandler.setMinimumScaleY(yScale);
  }

  /// Limits how little of a y axis can be visible at once, so the user cannot zoom in further.
  /// Computed from the current axis range, so call it after [data] is set. A range that is not above 0 does nothing.
  ///
  /// [minYRange] is the smallest visible span in y values and [axis] the y axis the span refers to.
  void setVisibleYRangeMinimum(double minYRange, AxisDependency axis) {
    final yScale = scaleForVisibleRange(getAxisRange(axis), minYRange);
    if (yScale == null) return;
    viewPortHandler.setMaximumScaleY(yScale);
  }

  /// Limits the visible span of a y axis in both directions. Computed from the current axis range,
  /// so call it after [data] is set. A range that is not above 0 does nothing.
  ///
  /// [minYRange] is the smallest visible span in y values, [maxYRange] the largest and [axis] the y axis the spans
  /// refer to.
  void setVisibleYRange(
    double minYRange,
    double maxYRange,
    AxisDependency axis,
  ) {
    final minScale = scaleForVisibleRange(getAxisRange(axis), maxYRange);
    if (minScale == null) return;
    final maxScale = scaleForVisibleRange(getAxisRange(axis), minYRange);
    if (maxScale == null) return;
    viewPortHandler.setMinMaxScaleY(minScale, maxScale);
  }

  /// Zoom factor at which [visibleRange] of an axis spanning [axisRange] fills the content, or null when there is
  /// none. Computed in Kotlin's Float arithmetic. Internal API.
  @internal
  double? scaleForVisibleRange(double axisRange, double visibleRange) {
    if (!(visibleRange > 0)) return null;
    final scale = toKotlinFloat(axisRange / visibleRange);
    return scale.isFinite ? scale : null;
  }

  /// Scrolls so the left edge of the content area sits at the given x value, keeping the vertical
  /// position within the viewport limits. Runs as a viewport job and redraws (see [addViewportJob]).
  void moveViewToX(double xValue) {
    if (!_allFinite([xValue])) return;
    final job = MoveViewJob.getInstance(
      viewPortHandler,
      xValue,
      0,
      getTransformer(AxisDependency.LEFT),
      this,
    );
    addViewportJob(job.run);
  }

  /// Scrolls so the left edge sits at [xValue] and [yValue] is vertically centered. Runs as a viewport
  /// job and redraws (see [addViewportJob]).
  ///
  /// [xValue] is the value shown at the left edge of the content area, [yValue] the value shown at the vertical
  /// center, in values of [axis].
  void moveViewTo(double xValue, double yValue, AxisDependency axis) {
    if (!_allFinite([xValue, yValue])) return;
    final yInView = getAxisRange(axis) / viewPortHandler.scaleY;

    final job = MoveViewJob.getInstance(
      viewPortHandler,
      xValue,
      yValue + yInView / 2,
      getTransformer(axis),
      this,
    );
    addViewportJob(job.run);
  }

  /// Like [moveViewTo], but animates from the current position.
  ///
  /// [xValue] is the value shown at the left edge of the content area when the animation ends, [yValue] the value
  /// shown at the vertical center when the animation ends, in values of [axis], and [duration] the animation duration
  /// in milliseconds.
  void moveViewToAnimated(
    double xValue,
    double yValue,
    AxisDependency axis,
    int duration,
  ) {
    if (!_allFinite([xValue, yValue])) return;
    final bounds = getValuesByTouchPoint(
      viewPortHandler.contentLeft,
      viewPortHandler.contentTop,
      axis,
    );

    final yInView = getAxisRange(axis) / viewPortHandler.scaleY;

    final job = AnimatedMoveViewJob.getInstance(
      viewPortHandler,
      xValue,
      yValue + yInView / 2,
      getTransformer(axis),
      this,
      toKotlinFloat(bounds.x),
      toKotlinFloat(bounds.y),
      duration,
    );
    addViewportJob(job.run);

    MPPointD.recycleInstance(bounds);
  }

  /// Scrolls so [yValue] is vertically centered. The left edge is moved to x value 0 at the same time,
  /// within the viewport limits. Runs as a viewport job and redraws (see [addViewportJob]).
  ///
  /// [yValue] is the value shown at the vertical center, in values of [axis].
  void centerViewToY(double yValue, AxisDependency axis) {
    if (!_allFinite([yValue])) return;
    final valsInView = getAxisRange(axis) / viewPortHandler.scaleY;

    final job = MoveViewJob.getInstance(
      viewPortHandler,
      0,
      yValue + valsInView / 2,
      getTransformer(axis),
      this,
    );
    addViewportJob(job.run);
  }

  /// Scrolls so the given position is at the center of the content area. Runs as a viewport job and
  /// redraws (see [addViewportJob]).
  ///
  /// [xValue] is the value shown at the horizontal center, [yValue] the value shown at the vertical center, in
  /// values of [axis].
  void centerViewTo(double xValue, double yValue, AxisDependency axis) {
    if (!_allFinite([xValue, yValue])) return;
    final yInView = getAxisRange(axis) / viewPortHandler.scaleY;
    final xInView = xAxis.axisRange / viewPortHandler.scaleX;

    final job = MoveViewJob.getInstance(
      viewPortHandler,
      xValue - xInView / 2,
      yValue + yInView / 2,
      getTransformer(axis),
      this,
    );
    addViewportJob(job.run);
  }

  /// Like [centerViewTo], but animates from the current position.
  ///
  /// [xValue] is the value shown at the horizontal center when the animation ends, [yValue] the value shown at the
  /// vertical center when the animation ends, in values of [axis], and [duration] the animation duration in
  /// milliseconds.
  void centerViewToAnimated(
    double xValue,
    double yValue,
    AxisDependency axis,
    int duration,
  ) {
    if (!_allFinite([xValue, yValue])) return;
    final bounds = getValuesByTouchPoint(
      viewPortHandler.contentLeft,
      viewPortHandler.contentTop,
      axis,
    );

    final yInView = getAxisRange(axis) / viewPortHandler.scaleY;
    final xInView = xAxis.axisRange / viewPortHandler.scaleX;

    final job = AnimatedMoveViewJob.getInstance(
      viewPortHandler,
      xValue - xInView / 2,
      yValue + yInView / 2,
      getTransformer(axis),
      this,
      toKotlinFloat(bounds.x),
      toKotlinFloat(bounds.y),
      duration,
    );
    addViewportJob(job.run);

    MPPointD.recycleInstance(bounds);
  }

  static bool _allFinite(List<double> values) =>
      values.every((it) => it.isFinite);

  bool _customViewPortEnabled = false;

  /// Replaces the automatic offsets with fixed ones and applies them on the next UI loop pass.
  /// Legend and axis labels are no longer accounted for; prefer [setExtraOffsets] unless you need this.
  /// [resetViewPortOffsets] restores automatic offsets.
  ///
  /// [left], [top], [right] and [bottom] are the space in pixels between each view edge and the content area.
  void setViewPortOffsets(
    double left,
    double top,
    double right,
    double bottom,
  ) {
    _customViewPortEnabled = true;
    post(() {
      viewPortHandler.restrainViewPort(left, top, right, bottom);
      prepareOffsetMatrix();
      prepareValuePxMatrix();
    });
  }

  /// Removes offsets set with [setViewPortOffsets] and recalculates them automatically.
  void resetViewPortOffsets() {
    _customViewPortEnabled = false;
    calculateOffsets();
  }

  /// Range of the given y axis in values.
  @protected
  double getAxisRange(AxisDependency axis) {
    return axis == AxisDependency.LEFT
        ? axisLeft.axisRange
        : axisRight.axisRange;
  }

  final Float32List _getPositionBuffer = Float32List(2);

  /// Pixel position of an entry inside the view.
  ///
  /// [e] is the entry, or null, and [axis] the y axis the entry's data set depends on. Returns a new point in
  /// pixels, or null when [e] is null.
  MPPointF? getPosition(Entry? e, AxisDependency axis) {
    if (e == null) return null;

    _getPositionBuffer[0] = e.x;
    _getPositionBuffer[1] = e.y;

    getTransformer(axis).pointValuesToPixel(_getPositionBuffer);

    return MPPointF(_getPositionBuffer[0], _getPositionBuffer[1]);
  }

  /// Fill color of the content area, used while [isDrawGridBackgroundEnabled] is true.
  ui.Color get gridBackgroundColor => gridBackgroundPaint.color;

  set gridBackgroundColor(ui.Color value) {
    gridBackgroundPaint.color = value;
  }

  /// True when dragging is enabled on at least one axis. Setting it sets both [isDragXEnabled] and
  /// [isDragYEnabled]. Dragging does not affect scaling.
  bool get isDragEnabled => isDragXEnabled || isDragYEnabled;

  set isDragEnabled(bool value) {
    isDragXEnabled = value;
    isDragYEnabled = value;
  }

  /// True when scaling by gesture is enabled on at least one axis. Setting it sets both [isScaleXEnabled]
  /// and [isScaleYEnabled]. Scaling does not affect dragging.
  bool get isScaleEnabled => isScaleXEnabled || isScaleYEnabled;

  set isScaleEnabled(bool value) {
    isScaleXEnabled = value;
    isScaleYEnabled = value;
  }

  double _borderWidth = 1;

  /// Width in dp of the border drawn while [isDrawBordersEnabled] is true. Default 1.
  double get borderWidth => _borderWidth;

  set borderWidth(double value) {
    _borderWidth = value;
    borderPaint.strokeWidth = Utils.convertDpToPixel(value);
  }

  /// Color of the border drawn while [isDrawBordersEnabled] is true.
  ui.Color get borderColor => borderPaint.color;

  set borderColor(ui.Color value) {
    borderPaint.color = value;
  }

  /// Converts a pixel position inside the view to values.
  ///
  /// [x] and [y] are the pixel position and [axis] the y axis the y value should refer to. Returns the point holding
  /// the x value and the y value: [outputPoint] when given (Kotlin's `getValuesByTouchPoint(x, y, axis, outputPoint)`
  /// overload, which returns nothing), else a new point.
  MPPointD getValuesByTouchPoint(
    double x,
    double y,
    AxisDependency axis, [
    MPPointD? outputPoint,
  ]) {
    final result = outputPoint ?? MPPointD(0.0, 0.0);
    getTransformer(axis).getValuesByTouchPoint(x, y, result);
    return result;
  }

  /// Converts values to a pixel position inside the view.
  ///
  /// [x] is the x value and [y] the y value on [axis]. Returns the pixel position.
  MPPointD getPixelForValues(double x, double y, AxisDependency axis) {
    return getTransformer(axis).getPixelForValues(x, y);
  }

  /// Entry nearest to a pixel position, or null when there is no data or no entry within
  /// [maxHighlightDistance].
  Entry? getEntryByTouchPoint(double x, double y) {
    final h = getHighlightByTouchPoint(x, y);
    if (h == null) return null;
    return data?.getEntryForHighlight(h);
  }

  /// Data set of the entry nearest to a pixel position, or null when there is no data or no entry
  /// within [maxHighlightDistance].
  IBarLineScatterCandleBubbleDataSet? getDataSetByTouchPoint(
    double x,
    double y,
  ) {
    final h = getHighlightByTouchPoint(x, y);
    if (h == null) return null;
    return data?.getDataSetByIndex(h.dataSetIndex);
  }

  /// Scratch point reused by [lowestVisibleX].
  @protected
  final MPPointD posForGetLowestVisibleX = MPPointD.getInstance(0.0, 0.0);

  @override
  double get lowestVisibleX {
    getTransformer(AxisDependency.LEFT).getValuesByTouchPoint(
      viewPortHandler.contentLeft,
      viewPortHandler.contentBottom,
      posForGetLowestVisibleX,
    );
    return toKotlinFloat(
      math.max(xAxis.axisMinimum, posForGetLowestVisibleX.x),
    );
  }

  /// Scratch point reused by [highestVisibleX].
  @protected
  final MPPointD posForGetHighestVisibleX = MPPointD.getInstance(0.0, 0.0);

  @override
  double get highestVisibleX {
    getTransformer(AxisDependency.LEFT).getValuesByTouchPoint(
      viewPortHandler.contentRight,
      viewPortHandler.contentBottom,
      posForGetHighestVisibleX,
    );
    return toKotlinFloat(
      math.min(xAxis.axisMaximum, posForGetHighestVisibleX.x),
    );
  }

  /// Span of x values currently visible in the content area.
  double get visibleXRange =>
      toKotlinFloat((highestVisibleX - lowestVisibleX).abs());

  /// Current horizontal zoom factor of the viewport, 1 when fully zoomed out. Kotlin names it so because a View's
  /// `scaleX` is its own transform.
  double get zoomX => viewPortHandler.scaleX;

  /// Current vertical zoom factor of the viewport, 1 when fully zoomed out.
  double get zoomY => viewPortHandler.scaleY;

  /// True when both zoom factors are at their minimum.
  bool get isFullyZoomedOut => viewPortHandler.isFullyZoomedOut;

  /// The [YAxis] for the given side.
  YAxis getAxis(AxisDependency axis) {
    return axis == AxisDependency.LEFT ? axisLeft : axisRight;
  }

  @override
  bool isInverted(AxisDependency axis) => getAxis(axis).isInverted;

  /// Extra distance in dp the content may be dragged past its left and right bounds. Default 0.
  double get dragOffsetX => viewPortHandler.dragOffsetX;

  set dragOffsetX(double value) {
    viewPortHandler.dragOffsetX = value;
  }

  /// Extra distance in dp the content may be dragged past its top and bottom bounds. Default 0.
  double get dragOffsetY => viewPortHandler.dragOffsetY;

  set dragOffsetY(double value) {
    viewPortHandler.dragOffsetY = value;
  }

  /// True when neither [dragOffsetX] nor [dragOffsetY] is above 0.
  bool get hasNoDragOffset => viewPortHandler.hasNoDragOffset;

  /// Larger of the two y axis maximums.
  @override
  double get yChartMax => math.max(axisLeft.axisMaximum, axisRight.axisMaximum);

  /// Smaller of the two y axis minimums.
  @override
  double get yChartMin => math.min(axisLeft.axisMinimum, axisRight.axisMinimum);

  /// True when the left or the right y axis is inverted.
  bool get isAnyAxisInverted => axisLeft.isInverted || axisRight.isInverted;

  final Float32List _onSizeChangedBuffer = Float32List(2);

  @override
  void onSizeChanged(double w, double h) {
    _onSizeChangedBuffer[0] = 0;
    _onSizeChangedBuffer[1] = 0;

    if (isKeepPositionOnRotation) {
      _onSizeChangedBuffer[0] = viewPortHandler.contentLeft;
      _onSizeChangedBuffer[1] = viewPortHandler.contentTop;
      getTransformer(AxisDependency.LEFT).pixelsToValue(_onSizeChangedBuffer);
    }

    super.onSizeChanged(w, h);

    if (isKeepPositionOnRotation) {
      getTransformer(
        AxisDependency.LEFT,
      ).pointValuesToPixel(_onSizeChangedBuffer);
      viewPortHandler.centerViewPort(_onSizeChangedBuffer, this);
    } else {
      viewPortHandler.refresh(viewPortHandler.matrixTouch, this, true);
    }
  }
}
