// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/charts/RadarChart.kt
//
// Not ported (Android only): the Context/AttributeSet constructors. yAxis is Kotlin's `lateinit var ... private set`:
// a private late field with a public getter. computeAxes is Kotlin `internal` (@internal, as in Chart). Kotlin's
// `.toFloat()` results are doubles and its Float arithmetic is done in double precision, as in the rest of the port;
// Math.toRadians is the multiplication by Utils.DEG2RAD. The import of this file by pie_radar_chart_base.dart, for the
// `this is RadarChart` branch of calculateOffsets, closes an import cycle, which Dart allows.
//
// Flutter addition: onDraw ends with notifyAfterDraw() (Chart.afterDrawListeners, not in Kotlin), as PieChart.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show internal, protected;

import '../components/y_axis.dart';
import '../data/radar_data.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../highlight/radar_highlighter.dart';
import '../renderer/radar_chart_renderer.dart';
import '../renderer/x_axis_renderer_radar_chart.dart';
import '../renderer/y_axis_renderer_radar_chart.dart';
import '../utils/utils.dart';
import 'pie_radar_chart_base.dart';

/// Chart that draws [RadarData] as a spider web: each entry sits on its own spoke from the center, and the entries of
/// a data set are joined into a polygon. Works best with 5 to 10 entries per data set. The `xAxis` labels the spokes
/// and [yAxis] scales the distance from the center. Angles are in degrees, 0 at 3 o'clock, increasing clockwise; the
/// first spoke points at `rotationAngle`.
class RadarChart extends PieRadarChartBase<RadarData> {
  /// Width in dp of the web lines running from the center outwards. Default 1.5.
  double webLineWidth = 1.5;

  /// Width in dp of the web rings between the spokes. Default 0.75.
  double webLineWidthInner = 0.75;

  /// Color of the web lines running from the center outwards. Default gray, `Color.rgb(122, 122, 122)`; its alpha is
  /// replaced by [webAlpha].
  ui.Color webColor = const ui.Color.fromARGB(255, 122, 122, 122);

  /// Color of the web rings between the spokes. Default gray, `Color.rgb(122, 122, 122)`; its alpha is replaced by
  /// [webAlpha].
  ui.Color webColorInner = const ui.Color.fromARGB(255, 122, 122, 122);

  /// Opacity of all web lines from 0 (invisible) to 255 (opaque). Default 150.
  int webAlpha = 150;

  /// Whether the web is drawn at all. Default true.
  bool isDrawWebEnabled = true;

  int _skipWebLineCount = 0;

  /// Number of spokes left out between two drawn ones, for charts with many entries. Negative values are raised to
  /// 0. Default 0.
  int get skipWebLineCount => _skipWebLineCount;

  set skipWebLineCount(int value) {
    _skipWebLineCount = math.max(0, value);
  }

  late YAxis _yAxis;

  /// The single y axis, scaling the distance from the center: the left axis, with labels 10 dp right of the first
  /// spoke.
  YAxis get yAxis => _yAxis;

  /// Draws [yAxis].
  late YAxisRendererRadarChart yAxisRenderer;

  /// Draws the `xAxis` labels around the web.
  late XAxisRendererRadarChart xAxisRenderer;

  @override
  void init() {
    super.init();

    _yAxis = YAxis(AxisDependency.LEFT);
    _yAxis.labelXOffset = 10;

    renderer = RadarChartRenderer(this, animator, viewPortHandler);
    yAxisRenderer = YAxisRendererRadarChart(viewPortHandler, yAxis, this);
    xAxisRenderer = XAxisRendererRadarChart(viewPortHandler, xAxis, this);

    highlighter = RadarHighlighter(this);
  }

  /// Computes the [yAxis] range from the y values and the `xAxis` range from 0 to the entry count of the largest
  /// data set.
  @override
  void calcMinMax() {
    super.calcMinMax();

    final data = this.data;
    if (data == null) return;

    yAxis.calculate(
      data.getYMin(AxisDependency.LEFT),
      data.getYMax(AxisDependency.LEFT),
    );
    xAxis.calculate(0, (data.maxEntryCountSet?.entryCount ?? 0).toDouble());
  }

  /// Like the base, but also computes the axis labels (see [computeAxes]) before the legend and the offsets.
  @override
  void notifyDataSetChanged() {
    final data = this.data;
    if (data == null) return;

    data.notifyDataChanged();
    calcMinMax();
    renderer.initBuffers();

    computeAxes();

    legendRenderer.computeLegend(data);

    calculateOffsets();
    invalidate();
  }

  /// Computes the labels of [yAxis] and of the `xAxis`. The y axis range becomes the first and last label, except that
  /// a custom minimum or maximum is kept. Internal API.
  @internal
  @override
  void computeAxes() {
    yAxisRenderer.computeAxis(
      yAxis.axisMinimum,
      yAxis.axisMaximum,
      yAxis.isInverted,
    );
    xAxisRenderer.computeAxis(xAxis.axisMinimum, xAxis.axisMaximum, false);
  }

  /// Draws the x axis labels, the web, the limit lines behind the data, the data, the highlights, the limit lines in
  /// front of the data, the y axis labels, the values, the legend, the description and the markers, in that order, or
  /// the empty state while there is nothing to draw.
  @override
  void onDraw(ui.Canvas canvas) {
    super.onDraw(canvas);

    if (showsEmptyState) return;

    if (xAxis.isEnabled) {
      xAxisRenderer.computeAxis(xAxis.axisMinimum, xAxis.axisMaximum, false);
    }

    xAxisRenderer.renderAxisLabels(canvas);

    if (isDrawWebEnabled) renderer.drawExtras(canvas);

    if (yAxis.isEnabled && yAxis.isDrawLimitLinesBehindDataEnabled) {
      yAxisRenderer.renderLimitLines(canvas);
    }

    renderer.drawData(canvas);

    final highlighted = this.highlighted;
    if (valuesToHighlight()) renderer.drawHighlighted(canvas, highlighted);

    if (yAxis.isEnabled && !yAxis.isDrawLimitLinesBehindDataEnabled) {
      yAxisRenderer.renderLimitLines(canvas);
    }

    yAxisRenderer.renderAxisLabels(canvas);

    renderer.drawValues(canvas);

    legendRenderer.renderLegend(canvas);

    drawDescription(canvas);

    drawMarkers(canvas);

    notifyAfterDraw();
  }

  /// Pixels per y value unit: the [radius] divided by the [yAxis] range. Infinite or NaN while the range is 0.
  double get factor {
    final content = viewPortHandler.contentRect;
    return math.min(content.width() / 2, content.height() / 2) /
        yAxis.axisRange;
  }

  /// Angle in degrees between two neighbouring spokes: 360 divided by the entry count of the largest data set (by 1
  /// without data).
  double get sliceAngle =>
      360 / (data?.maxEntryCountSet?.entryCount ?? 1).toDouble();

  /// Index of the entry whose spoke is nearest to [angle], in degrees (0 at 3 o'clock, increasing clockwise), taking
  /// `rotationAngle` into account. Never -1: every angle maps to a spoke, and to 0 without data.
  @override
  int getIndexForAngle(double angle) {
    final a = Utils.getNormalizedAngle(angle - rotationAngle);

    final sliceangle = sliceAngle;

    final max = data?.maxEntryCountSet?.entryCount ?? 0;

    var index = 0;

    for (var i = 0; i < max; i++) {
      final referenceAngle = sliceangle * (i + 1) - sliceangle / 2;

      if (referenceAngle > a) {
        index = i;
        break;
      }
    }

    return index;
  }

  /// Twice the legend text size in pixels.
  @protected
  @override
  double get requiredLegendOffset => legendRenderer.labelPaint.textSize * 2;

  /// The rotated label width in pixels while the x axis draws labels, otherwise 10 dp.
  @protected
  @override
  double get requiredBaseOffset => xAxis.isEnabled && xAxis.isDrawLabelsEnabled
      ? xAxis.labelRotatedWidth
      : Utils.convertDpToPixel(10);

  /// Half the rotated label width plus the rotated label height in pixels while the x axis draws labels, otherwise
  /// 10 dp. A label is drawn half its width beyond the web, so above and below that is half a width plus its height.
  @protected
  @override
  double get requiredVerticalBaseOffset =>
      xAxis.isEnabled && xAxis.isDrawLabelsEnabled
      ? xAxis.labelRotatedWidth / 2 + xAxis.labelRotatedHeight
      : Utils.convertDpToPixel(10);

  /// Radius of the web in pixels: half the smaller side of the content rectangle.
  @override
  double get radius {
    final content = viewPortHandler.contentRect;
    return math.min(content.width() / 2, content.height() / 2);
  }

  /// The [yAxis] maximum.
  @override
  double get yChartMax => yAxis.axisMaximum;

  /// The [yAxis] minimum, the value at the center.
  @override
  double get yChartMin => yAxis.axisMinimum;

  /// Range of [yAxis] in values.
  double get yRange => yAxis.axisRange;

  /// Draws two nested hexagons, the outline of a web, inside [bounds] for the empty state.
  @protected
  @override
  void drawNoDataIcon(ui.Canvas canvas, MutableRect bounds, ChartPaint paint) {
    paint.style = PaintStyle.STROKE;
    paint.strokeWidth = bounds.height() / 12;
    paint.strokeJoin = ui.StrokeJoin.round;
    final outer = (bounds.height() - paint.strokeWidth) / 2;
    for (final radius in Float32List.fromList([outer, outer * 0.5])) {
      final path = ui.Path();
      for (var i = 0; i <= 5; i++) {
        final angle = (60.0 * i - 90.0) * Utils.DEG2RAD;
        final x = bounds.centerX() + radius * math.cos(angle);
        final y = bounds.centerY() + radius * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPathP(path, paint);
    }
  }
}
