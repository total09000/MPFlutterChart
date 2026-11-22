// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/RadarChartRenderer.kt
//
// Geometry that is not finite is skipped explicitly and never reaches a path or a canvas call. Values or
// a rotation angle that are not finite, or a y axis range of 0 or infinity, give radii, angles and points that are not
// finite, which Kotlin passes on to Android and which leave nothing drawn there. A position counts as finite when it
// is finite as a Float: Kotlin's positions are Floats, which overflow to infinity (values far beyond a small fixed
// axis range), while Flutter would clamp such a double to the Float range and draw it there. Here drawDataSet still
// drops a corner whose x is NaN, as Kotlin does, and then skips the whole polygon (fill and outline) when a corner it
// kept, or a point of its rounded corners, is not finite, or when no corner is left: Android draws nothing for a path
// holding such a point, and Kotlin's empty path draws nothing either. drawWeb skips a web line, drawValues a value text
// and drawHighlighted the highlight lines whose points are not finite; drawHighlightCircle skips a fill or stroke
// whose center or radius is not finite (Kotlin checks only for a NaN center, in drawHighlighted). Icons are drawn as
// in Kotlin, whose `.toInt()` turns any position into whole device pixels (truncateToDevicePx). The loops still
// advance as Kotlin's.
//
// Android builds the highlight ring from an outer circle added clockwise and an inner one
// added counter-clockwise, which the winding fill leaves empty in the middle. Here they are two concentric ovals filled
// PathFillType.evenOdd, which gives the same ring whichever circle is larger. The reused path gets its fill type set
// again after every reset.
//
// The corner buffer is a Float32List (Kotlin's FloatArray), so the corners keep Float precision. Kotlin's
// `hypot(Float, Float)` is the square root of the summed squares in double precision, and its other Float arithmetic is
// done in double precision too, as in the rest of the port. Kotlin's `high.x.toInt()` is kotlinFloatToInt and
// `pIcon.x.toInt()` is truncateToDevicePx, which give 0 for NaN like Kotlin instead of throwing. The chart's
// skipWebLineCount is a Dart int, so 1 + skipWebLineCount does not wrap around at the Int range as Kotlin's does.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../animation/chart_animator.dart';
import '../charts/radar_chart.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../highlight/highlight.dart';
import '../interfaces/datasets/i_radar_data_set.dart';
import '../utils/color_template.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';
import '../utils/view_port_handler.dart';
import 'line_radar_renderer.dart';

/// Draws a [RadarChart]: the web in [drawExtras], one closed polygon per data set in [drawData] (filled when the data
/// set enables it), the values at the corners in [drawValues], and highlight lines and circles in [drawHighlighted].
/// Angles are in degrees clockwise from 3 o'clock, offset by the chart's rotation angle; radii are pixels.
class RadarChartRenderer extends LineRadarRenderer {
  /// Creates the renderer of [chart], whose drawing follows the phases of [animator].
  RadarChartRenderer(
    this.chart,
    ChartAnimator animator,
    ViewPortHandler viewPortHandler,
  ) : super(animator, viewPortHandler);

  /// The radar chart, which supplies the data, the center, the slice angle and the web settings.
  @protected
  final RadarChart chart;

  /// Paint for the web lines; color, alpha and line width (dp) are copied from the chart on every draw.
  final ChartPaint webPaint = ChartPaint()..style = PaintStyle.STROKE;

  /// Paint for the fill and the stroke of the highlight circle.
  @protected
  final ChartPaint highlightCirclePaint = ChartPaint();

  final ui.Path _drawDataSetSurfacePathBuffer = ui.Path();

  final ui.Path _drawHighlightCirclePathBuffer = ui.Path();

  /// Does nothing; radar polygons are drawn without a buffer.
  @override
  void initBuffers() {}

  /// Draws the polygon of every visible data set onto [c].
  @override
  void drawData(ui.Canvas c) {
    final radarData = chart.data;
    if (radarData == null) return;
    final mostEntries = radarData.maxEntryCountSet?.entryCount;
    if (mostEntries == null) return;

    for (final set in radarData.dataSets) {
      if (set.isVisible) {
        drawDataSet(c, set, mostEntries);
      }
    }
  }

  /// Corners of the polygon being drawn, as x and y pairs, so a draw pass allocates nothing.
  Float32List _cornerBuffer = Float32List(32);

  /// Appends one corner to [_cornerBuffer] and returns the new corner count.
  int _addCorner(int count, double x, double y) {
    if ((count + 1) * 2 > _cornerBuffer.length) {
      final grown = Float32List(_cornerBuffer.length * 2);
      grown.setAll(0, _cornerBuffer);
      _cornerBuffer = grown;
    }
    _cornerBuffer[count * 2] = x;
    _cornerBuffer[count * 2 + 1] = y;
    return count + 1;
  }

  /// Builds the closed polygon of the first [count] corners in [_cornerBuffer] into [path]. With a [radius] above
  /// zero each corner is cut back along both of its edges and joined with a curve, clamped to half the shorter edge so
  /// a small polygon keeps its shape.
  ///
  /// Returns false, with [path] left empty, when there is no corner or a corner or curve point is not finite;
  /// Kotlin returns nothing.
  bool _buildPolygon(ui.Path path, int count, double radius) {
    if (count == 0) return false;

    for (var i = 0; i < count * 2; i++) {
      if (!_cornerBuffer[i].isFinite) return false;
    }

    if (radius <= 0 || count < 3) {
      path.moveTo(_cornerBuffer[0], _cornerBuffer[1]);
      for (var i = 1; i < count; i++) {
        path.lineTo(_cornerBuffer[i * 2], _cornerBuffer[i * 2 + 1]);
      }
      path.close();
      return true;
    }

    for (var i = 0; i < count; i++) {
      final previous = (i + count - 1) % count;
      final next = (i + 1) % count;

      final x = _cornerBuffer[i * 2];
      final y = _cornerBuffer[i * 2 + 1];
      final previousX = _cornerBuffer[previous * 2];
      final previousY = _cornerBuffer[previous * 2 + 1];
      final nextX = _cornerBuffer[next * 2];
      final nextY = _cornerBuffer[next * 2 + 1];

      final toPrevious = _hypot(previousX - x, previousY - y);
      final toNext = _hypot(nextX - x, nextY - y);
      final cut = math.min(radius, math.min(toPrevious, toNext) / 2);

      final startX = toPrevious == 0
          ? x
          : x + (previousX - x) / toPrevious * cut;
      final startY = toPrevious == 0
          ? y
          : y + (previousY - y) / toPrevious * cut;
      final endX = toNext == 0 ? x : x + (nextX - x) / toNext * cut;
      final endY = toNext == 0 ? y : y + (nextY - y) / toNext * cut;

      // A corner radius that is not a number makes every curve point NaN.
      if (!_isFinitePoint(startX, startY) || !_isFinitePoint(endX, endY)) {
        path.reset();
        return false;
      }

      if (i == 0) {
        path.moveTo(startX, startY);
      } else {
        path.lineTo(startX, startY);
      }
      path.quadraticBezierTo(x, y, endX, endY);
    }

    path.close();
    return true;
  }

  /// Draws the polygon of [dataSet]: one corner per entry at the radius of its value and the angle of its index,
  /// rounded by the data set's corner radius when it has one, filled with the fill drawable or fill color when the
  /// data set enables it, and outlined with its line width (dp) unless the fill is fully opaque.
  ///
  /// [mostEntries] is the entry count of the largest data set; a data set with more entries is closed through the
  /// center.
  @protected
  void drawDataSet(ui.Canvas c, IRadarDataSet dataSet, int mostEntries) {
    final phaseX = animator.phaseX;
    final phaseY = animator.phaseY;

    final sliceangle = chart.sliceAngle;
    final factor = chart.factor;

    final center = chart.centerOffsets;
    final pOut = MPPointF.getInstance(0, 0);
    final surface = _drawDataSetSurfacePathBuffer;
    surface.reset();

    renderPaint.color = dataSet.color;

    var count = 0;

    for (var j = 0; j < dataSet.entryCount; j++) {
      final e = dataSet.getEntryForIndex(j);

      Utils.getPosition(
        center,
        (e.y - chart.yChartMin) * factor * phaseY,
        sliceangle * j * phaseX + chart.rotationAngle,
        pOut,
      );

      if (pOut.x.isNaN) continue;

      count = _addCorner(count, pOut.x, pOut.y);
    }

    if (dataSet.entryCount > mostEntries) {
      count = _addCorner(count, center.x, center.y);
    }

    final hasShape = _buildPolygon(
      surface,
      count,
      Utils.convertDpToPixel(dataSet.cornerRadius),
    );

    if (hasShape) {
      if (dataSet.isDrawFilledEnabled) {
        final fillDrawable = dataSet.fillDrawable;
        if (fillDrawable != null) {
          drawFilledPath(c, surface, fillDrawable);
        } else {
          drawFilledPathColor(c, surface, dataSet.fillColor, dataSet.fillAlpha);
        }
      }
    }

    renderPaint.strokeWidth = Utils.convertDpToPixel(dataSet.lineWidth);
    renderPaint.style = PaintStyle.STROKE;

    if (hasShape && (!dataSet.isDrawFilledEnabled || dataSet.fillAlpha < 255)) {
      c.drawPathP(surface, renderPaint);
    }

    MPPointF.recycleInstance(center);
    MPPointF.recycleInstance(pOut);
  }

  /// Draws the y value and icon of each entry just above its corner of the polygon.
  @override
  void drawValues(ui.Canvas c) {
    final radarData = chart.data;
    if (radarData == null) return;

    final phaseX = animator.phaseX;
    final phaseY = animator.phaseY;

    final sliceangle = chart.sliceAngle;
    final factor = chart.factor;

    final center = chart.centerOffsets;
    final pOut = MPPointF.getInstance(0, 0);
    final pIcon = MPPointF.getInstance(0, 0);

    final yoffset = Utils.convertDpToPixel(5);

    for (var i = 0; i < radarData.dataSetCount; i++) {
      final dataSet = radarData.getDataSetByIndex(i);
      if (dataSet == null) continue;

      if (!shouldDrawValuesOf(dataSet)) continue;

      applyValueTextStyle(dataSet);

      final iconsOffset = MPPointF.getInstanceFrom(dataSet.iconsOffset);
      iconsOffset.x = Utils.convertDpToPixel(iconsOffset.x);
      iconsOffset.y = Utils.convertDpToPixel(iconsOffset.y);

      for (var j = 0; j < dataSet.entryCount; j++) {
        final entry = dataSet.getEntryForIndex(j);

        Utils.getPosition(
          center,
          (entry.y - chart.yChartMin) * factor * phaseY,
          sliceangle * j * phaseX + chart.rotationAngle,
          pOut,
        );

        // No text at a position that is not finite.
        if (dataSet.isDrawValuesEnabled &&
            _isFinitePoint(pOut.x, pOut.y - yoffset)) {
          drawValue(
            c,
            dataSet.valueFormatter,
            entry.y,
            entry,
            i,
            pOut.x,
            pOut.y - yoffset,
            dataSet.getValueTextColor(j),
          );
        }

        final icon = entry.icon;
        if (icon != null && dataSet.isDrawIconsEnabled) {
          Utils.getPosition(
            center,
            entry.y * factor * phaseY + iconsOffset.y,
            sliceangle * j * phaseX + chart.rotationAngle,
            pIcon,
          );

          pIcon.y += iconsOffset.x;

          Utils.drawImage(
            c,
            icon,
            truncateToDevicePx(pIcon.x),
            truncateToDevicePx(pIcon.y),
            icon.intrinsicWidth,
            icon.intrinsicHeight,
          );
        }
      }

      MPPointF.recycleInstance(iconsOffset);
    }

    MPPointF.recycleInstance(center);
    MPPointF.recycleInstance(pOut);
    MPPointF.recycleInstance(pIcon);
  }

  /// Draws the web, see [drawWeb].
  @override
  void drawExtras(ui.Canvas c) {
    drawWeb(c);
  }

  /// Draws the web: one spoke from the center per entry index (skipping spokes according to the chart's skip count)
  /// and one ring per y axis entry, with the outer and inner web line widths (dp) of the chart.
  ///
  /// As in Kotlin, a ring has one line per entry of the whole data (all data sets together), so with several data
  /// sets every ring is drawn more than once.
  @protected
  void drawWeb(ui.Canvas c) {
    final radarData = chart.data;
    if (radarData == null) return;

    final sliceangle = chart.sliceAngle;
    final factor = chart.factor;
    final rotationangle = chart.rotationAngle;

    final center = chart.centerOffsets;

    webPaint.strokeWidth = Utils.convertDpToPixel(chart.webLineWidth);
    webPaint.color = chart.webColor;
    webPaint.alpha = chart.webAlpha;

    final xIncrements = 1 + chart.skipWebLineCount;
    final maxEntryCount = radarData.maxEntryCountSet?.entryCount ?? 0;

    final p = MPPointF.getInstance(0, 0);
    var i = 0;
    while (i < maxEntryCount) {
      Utils.getPosition(
        center,
        chart.yRange * factor,
        sliceangle * i + rotationangle,
        p,
      );

      _drawLine(c, center.x, center.y, p.x, p.y, webPaint);
      i += xIncrements;
    }
    MPPointF.recycleInstance(p);

    webPaint.strokeWidth = Utils.convertDpToPixel(chart.webLineWidthInner);
    webPaint.color = chart.webColorInner;
    webPaint.alpha = chart.webAlpha;

    final yAxis = chart.yAxis;
    final labelCount = yAxis.entryCount;

    final p1out = MPPointF.getInstance(0, 0);
    final p2out = MPPointF.getInstance(0, 0);
    for (var j = 0; j < labelCount; j++) {
      for (var k = 0; k < radarData.entryCount; k++) {
        final r = (yAxis.entries[j] - chart.yChartMin) * factor;

        Utils.getPosition(center, r, sliceangle * k + rotationangle, p1out);
        Utils.getPosition(
          center,
          r,
          sliceangle * (k + 1) + rotationangle,
          p2out,
        );

        _drawLine(c, p1out.x, p1out.y, p2out.x, p2out.y, webPaint);
      }
    }
    MPPointF.recycleInstance(p1out);
    MPPointF.recycleInstance(p2out);
  }

  /// Draws the highlight lines through each highlighted corner and, when the data set enables it, a highlight circle
  /// around it. The entry is picked by the highlight's x value as an index; highlights of entries that do not exist
  /// or that the x animation has not revealed yet are skipped. Records the corner as the draw position of the
  /// highlight, where the marker goes.
  @override
  void drawHighlighted(ui.Canvas c, List<Highlight> indices) {
    final radarData = chart.data;
    if (radarData == null) return;

    final sliceangle = chart.sliceAngle;
    final factor = chart.factor;

    final center = chart.centerOffsets;
    final pOut = MPPointF.getInstance(0, 0);

    for (final high in indices) {
      final set = radarData.getDataSetByIndex(high.dataSetIndex);

      if (set == null || !set.isHighlightEnabled) continue;

      final index = kotlinFloatToInt(high.x);
      if (index < 0 || index >= set.entryCount) continue;

      final e = set.getEntryForIndex(index);

      if (!isInBoundsX(e, set)) continue;

      final y = e.y - chart.yChartMin;

      Utils.getPosition(
        center,
        y * factor * animator.phaseY,
        sliceangle * high.x * animator.phaseX + chart.rotationAngle,
        pOut,
      );

      high.setDraw(pOut.x, pOut.y);

      // Kotlin draws the lines through any point; a point that is not finite draws nothing on Android.
      if (_isFinitePoint(pOut.x, pOut.y)) {
        drawHighlightLines(c, pOut.x, pOut.y, set);
      }

      if (set.isDrawHighlightCircleEnabled) {
        if (!pOut.x.isNaN && !pOut.y.isNaN) {
          var strokeColor = set.highlightCircleStrokeColor;
          if (strokeColor == ColorTemplate.COLOR_NONE) {
            strokeColor = set.getColor(0);
          }

          if (set.highlightCircleStrokeAlpha < 255) {
            strokeColor = ColorTemplate.colorWithAlpha(
              strokeColor,
              set.highlightCircleStrokeAlpha,
            );
          }

          drawHighlightCircle(
            c,
            pOut,
            set.highlightCircleInnerRadius,
            set.highlightCircleOuterRadius,
            set.highlightCircleFillColor,
            strokeColor,
            set.highlightCircleStrokeWidth,
          );
        }
      }
    }

    MPPointF.recycleInstance(center);
    MPPointF.recycleInstance(pOut);
  }

  /// Draws a highlight ring around [point] (pixels).
  ///
  /// [innerRadius] is the inner radius of the fill in dp, where 0 fills a full disc; [outerRadius] the outer radius in
  /// dp; [fillColor] the fill color, or `ColorTemplate.COLOR_NONE` for no fill; [strokeColor] the stroke color, or
  /// `ColorTemplate.COLOR_NONE` for no stroke; [strokeWidth] the stroke width in dp. A fill or stroke whose center or
  /// radius is not finite is not drawn.
  void drawHighlightCircle(
    ui.Canvas c,
    MPPointF point,
    double innerRadius,
    double outerRadius,
    ui.Color fillColor,
    ui.Color strokeColor,
    double strokeWidth,
  ) {
    c.save();

    final outerRadiusPx = Utils.convertDpToPixel(outerRadius);
    final innerRadiusPx = Utils.convertDpToPixel(innerRadius);

    final outerIsFinite =
        _isFinitePoint(point.x, point.y) && _isFloat(outerRadiusPx);

    if (fillColor != ColorTemplate.COLOR_NONE &&
        outerIsFinite &&
        !(innerRadiusPx > 0 && !_isFloat(innerRadiusPx))) {
      final p = _drawHighlightCirclePathBuffer;
      p.reset();
      p.fillType = ui.PathFillType.evenOdd;
      _addCircle(p, point.x, point.y, outerRadiusPx);
      if (innerRadiusPx > 0) {
        _addCircle(p, point.x, point.y, innerRadiusPx);
      }
      highlightCirclePaint.color = fillColor;
      highlightCirclePaint.style = PaintStyle.FILL;
      c.drawPathP(p, highlightCirclePaint);
    }

    if (strokeColor != ColorTemplate.COLOR_NONE && outerIsFinite) {
      highlightCirclePaint.color = strokeColor;
      highlightCirclePaint.style = PaintStyle.STROKE;
      highlightCirclePaint.strokeWidth = Utils.convertDpToPixel(strokeWidth);
      c.drawCircleP(point.x, point.y, outerRadiusPx, highlightCirclePaint);
    }

    c.restore();
  }

  /// Android's `Path.addCircle(x, y, radius, direction)`; the direction only matters for the winding fill, which the
  /// ring replaces with the even-odd fill.
  static void _addCircle(ui.Path path, double x, double y, double radius) {
    path.addOval(ui.Rect.fromCircle(center: ui.Offset(x, y), radius: radius));
  }

  /// `Canvas.drawLine`; a line with an end that is not finite is not drawn.
  static void _drawLine(
    ui.Canvas c,
    double x1,
    double y1,
    double x2,
    double y2,
    ChartPaint paint,
  ) {
    if (_isFinitePoint(x1, y1) && _isFinitePoint(x2, y2)) {
      c.drawLineP(x1, y1, x2, y2, paint);
    }
  }

  /// Kotlin's `hypot(Float, Float)`, in double precision.
  static double _hypot(double a, double b) => math.sqrt(a * a + b * b);

  /// Whether ([x], [y]) is finite as a Float, as Kotlin's positions are.
  static bool _isFinitePoint(double x, double y) => _isFloat(x) && _isFloat(y);

  /// Whether [value] is finite as a Float.
  static bool _isFloat(double value) => toKotlinFloat(value).isFinite;
}
