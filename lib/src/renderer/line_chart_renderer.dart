// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/LineChartRenderer.kt
//
// The per-frame offscreen bitmap of the Kotlin renderer (drawBitmap, bitmapCanvas, bitmapConfig,
// releaseBitmap and the bitmap branch of drawData) is not ported. Cubic, horizontal bezier and dashed lines are
// drawn straight onto the chart canvas (a dash effect on the paint is applied by the ChartCanvas calls), so
// drawCubicBezier / drawHorizontalBezier take that canvas as their first parameter. To keep Kotlin's stacking,
// drawData draws in two passes whenever Kotlin would have used the bitmap: first what Kotlin draws onto the chart
// canvas (linear fills and plain linear lines), then what it draws onto the bitmap it composites last (bezier
// fills and lines, dashed linear lines). The cached circle bitmaps
// (DataSetImageCache) are not ported either: drawCircles draws each circle and its hole onto the canvas, which on
// Flutter costs one draw call per circle just like the bitmap did.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../animation/chart_animator.dart';
import '../data/entry.dart';
import '../data/line_data_set.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../highlight/highlight.dart';
import '../interfaces/dataprovider/line_data_provider.dart';
import '../interfaces/datasets/i_line_data_set.dart';
import '../utils/color_template.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/transformer.dart';
import '../utils/utils.dart';
import '../utils/view_port_handler.dart';
import 'line_radar_renderer.dart';

/// Draws the lines of a [LineDataProvider]. Supports the linear, stepped, cubic bezier and horizontal bezier
/// modes, filled areas, dashed lines and circles at the entries. Every mode is drawn directly onto the chart
/// canvas; circles are drawn in [drawExtras].
class LineChartRenderer extends LineRadarRenderer {
  /// Creates a renderer for the line data of [chart].
  LineChartRenderer(
    this.chart,
    ChartAnimator animator,
    ViewPortHandler viewPortHandler,
  ) : super(animator, viewPortHandler);

  /// The chart that supplies the line data and the transformers.
  @protected
  final LineDataProvider chart;

  /// Paint for the hole inside each circle; its color is the circle hole color of the data set.
  @protected
  final ChartPaint circlePaintInner = ChartPaint()
    ..style = PaintStyle.FILL
    ..color = const ui.Color(0xFFFFFFFF);

  /// Path of the bezier line, built in value space and converted to pixels before drawing.
  @protected
  final ui.Path cubicPath = ui.Path();

  /// Copy of [cubicPath] closed down to the fill line, used for the filled area under a bezier line.
  @protected
  final ui.Path cubicFillPath = ui.Path();

  Float32List _lineBuffer = Float32List(4);

  /// Holds the visible segments of a data set with several colors, in value space and then in pixels.
  Float32List _segmentBuffer = Float32List(4);

  /// Holds the visible points of a data set that draws circles, in value space and then in pixels.
  Float32List _circlePointBuffer = Float32List(4);

  /// Path reused for the filled area under a linear or stepped line.
  @protected
  final ui.Path generateFilledPathBuffer = ui.Path();

  /// Reused for a circle with a transparent hole: the circle and the hole as one even-odd path.
  final ui.Path _circlePathBuffer = ui.Path();

  /// Which pieces of the data sets the current [drawData] pass draws.
  _DrawPass _pass = _DrawPass.all;

  /// Lines and circles are drawn without buffers that depend on the data, so there is nothing to prepare.
  ///
  /// Kotlin drops the cached circle bitmaps of data sets the chart no longer holds here; the port draws circles
  /// without a cache.
  @override
  void initBuffers() {}

  /// Draws every visible data set onto [c].
  ///
  /// When a visible data set is a bezier or dashed line, Kotlin draws those lines onto an offscreen bitmap that it
  /// composites after all data sets, so they sit above every linear fill and plain linear line whatever the data
  /// set order. The port draws directly in two passes with the same stacking: first the pieces Kotlin draws onto
  /// [c] (linear fills, plain linear lines), then the pieces it draws onto the bitmap (bezier fills and lines,
  /// dashed linear lines), each pass in data set order. Like Kotlin, it then draws nothing while the chart has no
  /// size.
  @override
  void drawData(ui.Canvas c) {
    final lineData = chart.lineData;
    if (lineData == null) return;

    if (!lineData.dataSets.any(
      (s) => s.isVisible && _needsOffscreenBitmap(s),
    )) {
      for (final set in lineData.dataSets) {
        if (set.isVisible) drawDataSet(c, set);
      }
      return;
    }

    // Kotlin cannot create the bitmap for a chart without size and returns.
    final width = kotlinFloatToInt(viewPortHandler.chartWidth);
    final height = kotlinFloatToInt(viewPortHandler.chartHeight);
    if (width <= 0 || height <= 0) return;

    try {
      for (final pass in [_DrawPass.direct, _DrawPass.offscreen]) {
        _pass = pass;
        for (final set in lineData.dataSets) {
          if (set.isVisible) drawDataSet(c, set);
        }
      }
    } finally {
      _pass = _DrawPass.all;
    }
  }

  /// True for the data sets that Kotlin draws (in part) through the offscreen bitmap instead of onto the chart
  /// canvas.
  static bool _needsOffscreenBitmap(ILineDataSet dataSet) =>
      dataSet.isDashedLineEnabled ||
      dataSet.mode == LineDataSetMode.CUBIC_BEZIER ||
      dataSet.mode == LineDataSetMode.HORIZONTAL_BEZIER;

  /// Whether the current pass draws anything of [dataSet]: the direct pass skips bezier lines, the offscreen pass
  /// skips plain linear lines.
  bool _drawsInPass(ILineDataSet dataSet) => switch (_pass) {
    _DrawPass.all => true,
    _DrawPass.direct =>
      dataSet.mode == LineDataSetMode.LINEAR ||
          dataSet.mode == LineDataSetMode.STEPPED,
    _DrawPass.offscreen => _needsOffscreenBitmap(dataSet),
  };

  /// Entry at [position] of the reduced list, which must not be empty. A position outside the list steps that
  /// many entries on from the first or the last reduced entry, and stops at the first or the last entry of
  /// [dataSet], so the curve reaches past the visible range for its control points as it did before any
  /// reduction.
  @protected
  Entry reducedEntry(ILineDataSet dataSet, int position) {
    final last = reducer.count - 1;
    final int index;
    if (position < 0) {
      index = math.max(reducer.indices[0] + position, 0);
    } else if (position > last) {
      index = math.min(
        reducer.indices[last] + position - last,
        dataSet.entryCount - 1,
      );
    } else {
      index = reducer.indices[position];
    }
    return dataSet.getEntryForIndex(index);
  }

  /// Draws the line of [dataSet] in its mode, with the line width (dp) and dash effect of the data set.
  ///
  /// Runs once per draw pass: while any visible data set is dashed or bezier, [drawData] calls it twice for every
  /// visible data set (Kotlin: once), and it draws only the part of [dataSet] that belongs to the running pass. An
  /// override must leave the pass to `super.drawDataSet`; drawing of its own around it happens twice per frame in
  /// that mode, so draw such extras from [drawData] or [drawExtras] instead.
  @protected
  void drawDataSet(ui.Canvas c, ILineDataSet dataSet) {
    if (dataSet.entryCount < 1) return;
    if (!_drawsInPass(dataSet)) return;

    renderPaint.strokeWidth = Utils.convertDpToPixel(dataSet.lineWidth);
    renderPaint.pathEffect = dataSet.dashPathEffect;

    switch (dataSet.mode) {
      case LineDataSetMode.LINEAR:
      case LineDataSetMode.STEPPED:
        drawLinear(c, dataSet);
      case LineDataSetMode.CUBIC_BEZIER:
        drawCubicBezier(c, dataSet);
      case LineDataSetMode.HORIZONTAL_BEZIER:
        drawHorizontalBezier(c, dataSet);
    }

    renderPaint.pathEffect = null;
  }

  /// Draws [dataSet] onto [c] as a curve whose control points are horizontal, so the line never overshoots
  /// vertically between two entries.
  ///
  /// Kotlin draws onto the offscreen bitmap and takes no canvas; see the file header.
  @protected
  void drawHorizontalBezier(ui.Canvas c, ILineDataSet dataSet) {
    final phaseY = animator.phaseY;

    final trans = chart.getTransformer(dataSet.axisDependency);

    xBounds.set(chart, dataSet);
    reduceVisible(chart, dataSet);

    cubicPath.reset();

    if (reducer.count >= 2) {
      var prev = reducedEntry(dataSet, 0);
      var cur = prev;

      cubicPath.moveTo(cur.x, cur.y * phaseY);

      for (var j = 1; j < reducer.count; j++) {
        prev = cur;
        cur = reducedEntry(dataSet, j);

        final cpx = prev.x + (cur.x - prev.x) / 2.0;

        cubicPath.cubicTo(
          cpx,
          prev.y * phaseY,
          cpx,
          cur.y * phaseY,
          cur.x,
          cur.y * phaseY,
        );
      }
    }

    if (dataSet.isDrawFilledEnabled) {
      cubicFillPath.reset();
      cubicFillPath.addPath(cubicPath, ui.Offset.zero);
      drawCubicFill(c, dataSet, cubicFillPath, trans);
    }

    renderPaint.color = dataSet.color;
    renderPaint.style = PaintStyle.STROKE;

    trans.pathValueToPixel(cubicPath);

    c.drawPathP(cubicPath, renderPaint);

    renderPaint.pathEffect = null;
  }

  /// Draws [dataSet] onto [c] as a smooth cubic curve; the cubic intensity of the data set controls how far the
  /// control points reach.
  ///
  /// Kotlin draws onto the offscreen bitmap and takes no canvas; see the file header.
  @protected
  void drawCubicBezier(ui.Canvas c, ILineDataSet dataSet) {
    final phaseY = animator.phaseY;

    final trans = chart.getTransformer(dataSet.axisDependency);

    xBounds.set(chart, dataSet);
    reduceVisible(chart, dataSet);

    final intensity = dataSet.cubicIntensity;

    cubicPath.reset();

    if (reducer.count >= 2) {
      double prevDx;
      double prevDy;
      double curDx;
      double curDy;

      // A cubic bezier needs one extra point on each side, otherwise the curve misbehaves at the chart edges.
      const firstPosition = 1;

      Entry prevPrev;
      var prev = reducedEntry(dataSet, firstPosition - 2);
      var cur = reducedEntry(dataSet, firstPosition - 1);
      var next = cur;
      var nextPosition = -1;

      cubicPath.moveTo(cur.x, cur.y * phaseY);

      for (var j = 1; j < reducer.count; j++) {
        prevPrev = prev;
        prev = cur;
        cur = nextPosition == j ? next : reducedEntry(dataSet, j);

        nextPosition = j + 1;
        next = reducedEntry(dataSet, nextPosition);

        prevDx = (cur.x - prevPrev.x) * intensity;
        prevDy = (cur.y - prevPrev.y) * intensity;
        curDx = (next.x - prev.x) * intensity;
        curDy = (next.y - prev.y) * intensity;

        cubicPath.cubicTo(
          prev.x + prevDx,
          (prev.y + prevDy) * phaseY,
          cur.x - curDx,
          (cur.y - curDy) * phaseY,
          cur.x,
          cur.y * phaseY,
        );
      }
    }

    if (dataSet.isDrawFilledEnabled) {
      cubicFillPath.reset();
      cubicFillPath.addPath(cubicPath, ui.Offset.zero);
      drawCubicFill(c, dataSet, cubicFillPath, trans);
    }

    renderPaint.color = dataSet.color;
    renderPaint.style = PaintStyle.STROKE;

    trans.pathValueToPixel(cubicPath);

    c.drawPathP(cubicPath, renderPaint);

    renderPaint.pathEffect = null;
  }

  /// Closes [spline] (value space) down to the fill line given by the fill formatter of [dataSet], converts it to
  /// pixels with [trans] and fills it with the fill drawable, or the fill color and alpha, of the data set.
  /// Reads the reduction its caller performed.
  @protected
  void drawCubicFill(
    ui.Canvas c,
    ILineDataSet dataSet,
    ui.Path spline,
    Transformer trans,
  ) {
    if (reducer.count == 0) return;

    final fillMin = dataSet.fillFormatter.getFillLinePosition(dataSet, chart);

    // The same ends the spline has, so the bottom edge of the fill cannot reach past the curve above it.
    spline.lineTo(reducedEntry(dataSet, reducer.count - 1).x, fillMin);
    spline.lineTo(reducedEntry(dataSet, 0).x, fillMin);
    spline.close();

    trans.pathValueToPixel(spline);

    final drawable = dataSet.fillDrawable;
    if (drawable != null) {
      drawFilledPath(c, spline, drawable);
    } else {
      drawFilledPathColor(c, spline, dataSet.fillColor, dataSet.fillAlpha);
    }
  }

  /// Draws [dataSet] as straight or stepped segments between consecutive entries in the visible range, after the
  /// filled area when the data set enables it. Uses one draw call per segment when the data set has several
  /// colors, otherwise one call per run of drawable segments. An entry whose y value is not finite leaves a gap:
  /// the segments on both sides of it are skipped and the line starts again after it. Dashed lines are dashed by
  /// the paint's dash effect.
  @protected
  void drawLinear(ui.Canvas c, ILineDataSet dataSet) {
    final entryCount = dataSet.entryCount;

    final isDrawSteppedEnabled = dataSet.mode == LineDataSetMode.STEPPED;
    final pointsPerEntryPair = isDrawSteppedEnabled ? 4 : 2;

    final trans = chart.getTransformer(dataSet.axisDependency);

    final phaseY = animator.phaseY;

    renderPaint.style = PaintStyle.STROKE;

    // Kotlin draws dashed lines on the bitmap canvas and the fill always onto c; here both go onto c, the fill in
    // the direct pass and dashed lines in the offscreen pass of drawData (see the file header).
    final canvas = c;
    final drawsFill = _pass != _DrawPass.offscreen;
    final drawsLines = dataSet.isDashedLineEnabled
        ? _pass != _DrawPass.direct
        : _pass != _DrawPass.offscreen;

    xBounds.set(chart, dataSet);
    reduceVisible(chart, dataSet);

    if (drawsFill && dataSet.isDrawFilledEnabled && entryCount > 0) {
      drawLinearFill(c, dataSet, trans);
    }

    if (!drawsLines) {
      renderPaint.pathEffect = null;
      return;
    }

    if (dataSet.colors.length > 1) {
      final floatsPerSegment = pointsPerEntryPair * 2;
      final segmentCount = math.max(reducer.count - 1, 0);

      if (segmentCount > 0) {
        final floatsNeeded = segmentCount * floatsPerSegment;
        if (_segmentBuffer.length < floatsNeeded) {
          _segmentBuffer = Float32List(floatsNeeded * 2);
        }

        var w = 0;
        for (var j = 0; j < segmentCount; j++) {
          final start = dataSet.getEntryForIndex(reducer.indices[j]);
          final startX = start.x;
          final startY = start.y * phaseY;

          _segmentBuffer[w++] = startX;
          _segmentBuffer[w++] = startY;

          final end = dataSet.getEntryForIndex(reducer.indices[j + 1]);

          if (isDrawSteppedEnabled) {
            _segmentBuffer[w++] = end.x;
            _segmentBuffer[w++] = startY;
            _segmentBuffer[w++] = end.x;
            _segmentBuffer[w++] = startY;
          }

          _segmentBuffer[w++] = end.x;
          _segmentBuffer[w++] = end.y * phaseY;
        }

        trans.pointValuesToPixel(_segmentBuffer, floatsNeeded);

        for (var segment = 0; segment < segmentCount; segment++) {
          final base = segment * floatsPerSegment;

          final firstCoordinateX = _segmentBuffer[base];
          final firstCoordinateY = _segmentBuffer[base + 1];
          final lastCoordinateX = _segmentBuffer[base + floatsPerSegment - 2];
          final lastCoordinateY = _segmentBuffer[base + floatsPerSegment - 1];

          if (firstCoordinateX == lastCoordinateX &&
              firstCoordinateY == lastCoordinateY) {
            continue;
          }

          if (!viewPortHandler.isInBoundsRight(firstCoordinateX)) break;

          if (!viewPortHandler.isInBoundsLeft(lastCoordinateX) ||
              !viewPortHandler.isInBoundsTop(
                math.max(firstCoordinateY, lastCoordinateY),
              ) ||
              !viewPortHandler.isInBoundsBottom(
                math.min(firstCoordinateY, lastCoordinateY),
              )) {
            continue;
          }

          renderPaint.color = dataSet.getColor(reducer.indices[segment]);

          canvas.drawLinesP(
            _segmentBuffer,
            base,
            floatsPerSegment,
            renderPaint,
          );
        }
      }
    } else {
      if (_lineBuffer.length <
          math.max(entryCount * pointsPerEntryPair, pointsPerEntryPair) * 2) {
        _lineBuffer = Float32List(
          math.max(entryCount * pointsPerEntryPair, pointsPerEntryPair) * 4,
        );
      }

      var j = 0;
      Entry? previous;

      for (var k = 0; k < reducer.count; k++) {
        final current = dataSet.getEntryForIndex(reducer.indices[k]);
        final start = previous ?? current;

        _lineBuffer[j++] = start.x;
        _lineBuffer[j++] = start.y * phaseY;

        if (isDrawSteppedEnabled) {
          _lineBuffer[j++] = current.x;
          _lineBuffer[j++] = start.y * phaseY;
          _lineBuffer[j++] = current.x;
          _lineBuffer[j++] = start.y * phaseY;
        }

        _lineBuffer[j++] = current.x;
        _lineBuffer[j++] = current.y * phaseY;

        previous = current;
      }

      if (j > 0) {
        trans.pointValuesToPixel(_lineBuffer);

        renderPaint.color = dataSet.color;

        final floatsPerSegment = pointsPerEntryPair * 2;

        // Looking for gaps means reading every float of the buffer, which at a hundred thousand entries
        // costs more than the drawing does. Only a set that holds a value which is not a number can have
        // one; every other set goes straight to the canvas.
        if (!dataSet.hasNonFiniteY) {
          _drawLineRun(canvas, 0, j, floatsPerSegment);
          renderPaint.pathEffect = null;
          return;
        }

        // One draw call per run of drawable segments. A single entry without a value would otherwise
        // invalidate the bounds of the whole array and the canvas would drop every segment with it.
        var runStart = 0;
        var segment = 0;

        while (segment < j) {
          var drawable = true;
          for (var i = segment; i < segment + floatsPerSegment; i++) {
            if (!_lineBuffer[i].isFinite) {
              drawable = false;
              break;
            }
          }

          if (!drawable) {
            _drawLineRun(
              canvas,
              runStart,
              segment - runStart,
              floatsPerSegment,
            );
            runStart = segment + floatsPerSegment;
          }

          segment += floatsPerSegment;
        }

        _drawLineRun(canvas, runStart, j - runStart, floatsPerSegment);
      }
    }

    renderPaint.pathEffect = null;
  }

  /// Floats one drawLines call may hold. Android's own display list splits its line draws around this size.
  static const int MAX_LINE_FLOATS = 16384;

  /// Draws [count] floats of the line buffer from [offset] as lines, in chunks of at most [MAX_LINE_FLOATS]
  /// floats. A canvas drops a draw call that holds too many lines at once, which a data set of tens of thousands
  /// of entries reaches easily.
  ///
  /// [floatsPerSegment] is how many floats one segment of the line occupies, so that no chunk cuts a segment in
  /// half.
  void _drawLineRun(
    ui.Canvas canvas,
    int offset,
    int count,
    int floatsPerSegment,
  ) {
    if (count <= 0) return;

    final chunk =
        math.max(MAX_LINE_FLOATS ~/ floatsPerSegment, 1) * floatsPerSegment;
    var drawn = 0;

    while (drawn < count) {
      canvas.drawLinesP(
        _lineBuffer,
        offset + drawn,
        math.min(chunk, count - drawn),
        renderPaint,
      );
      drawn += chunk;
    }
  }

  /// Fills the area between the line of [dataSet] and its fill line onto [c], in chunks of 128 entries to keep
  /// the path small. Reads the reduction its caller performed.
  @protected
  void drawLinearFill(ui.Canvas c, ILineDataSet dataSet, Transformer trans) {
    final filled = generateFilledPathBuffer;

    const firstPosition = 0;
    final lastPosition = reducer.count - 1;
    const positionInterval = 128;

    int chunkStart;
    int chunkEnd;
    var iterations = 0;

    final drawable = dataSet.fillDrawable;
    // A drawable is not painted quite to the edge of its chunk, so the chunks overlap by one position.
    final overlap = drawable != null ? 1 : 0;

    // Filled in chunks to avoid OutOfMemory errors on large bounds sets.
    do {
      chunkStart = firstPosition + iterations * positionInterval;
      chunkEnd = chunkStart + positionInterval;
      chunkEnd = chunkEnd > lastPosition ? lastPosition : chunkEnd;

      if (chunkStart <= chunkEnd) {
        generateFilledPath(
          dataSet,
          math.max(firstPosition, chunkStart - overlap),
          math.min(lastPosition, chunkEnd + overlap),
          filled,
        );

        trans.pathValueToPixel(filled);

        if (drawable != null) {
          drawFilledPath(c, filled, drawable);
        } else {
          drawFilledPathColor(c, filled, dataSet.fillColor, dataSet.fillAlpha);
        }
      }

      iterations++;
    } while (chunkStart <= chunkEnd);
  }

  /// Builds the outline of the filled area from the entries at [startPosition] to [endPosition] of the reduced
  /// list.
  @protected
  void generateFilledPath(
    ILineDataSet dataSet,
    int startPosition,
    int endPosition,
    ui.Path outputPath,
  ) {
    final fillMin = dataSet.fillFormatter.getFillLinePosition(dataSet, chart);
    final phaseY = animator.phaseY;
    final isDrawSteppedEnabled = dataSet.mode == LineDataSetMode.STEPPED;

    final filled = outputPath;
    filled.reset();

    final entry = dataSet.getEntryForIndex(reducer.indices[startPosition]);

    filled.moveTo(entry.x, fillMin);
    filled.lineTo(entry.x, entry.y * phaseY);

    Entry? currentEntry;
    var previousEntry = entry;
    for (var x = startPosition + 1; x <= endPosition; x++) {
      final current = dataSet.getEntryForIndex(reducer.indices[x]);
      currentEntry = current;

      if (isDrawSteppedEnabled) {
        filled.lineTo(current.x, previousEntry.y * phaseY);
      }

      filled.lineTo(current.x, current.y * phaseY);

      previousEntry = current;
    }

    if (currentEntry != null) {
      filled.lineTo(currentEntry.x, fillMin);
    }

    filled.close();
  }

  /// Draws the y value and icon above each entry that was drawn, keeping clear of the circle radius.
  @override
  void drawValues(ui.Canvas c) {
    final dataSets = chart.lineData?.dataSets;
    if (dataSets == null) return;

    for (var i = 0; i < dataSets.length; i++) {
      final dataSet = dataSets[i];

      if (!shouldDrawValues(chart, dataSet) || dataSet.entryCount < 1) {
        continue;
      }

      applyValueTextStyle(dataSet);

      final trans = chart.getTransformer(dataSet.axisDependency);

      // keep the values clear of the circles
      // Kotlin's Int px are device px: truncate there, and halve as an Int (truncating the half px).
      var valOffset = truncateToDevicePx(
        toKotlinFloat(Utils.convertDpToPixel(dataSet.circleRadius) * 1.75),
      );

      if (!dataSet.isDrawCirclesEnabled) {
        valOffset = truncateToDevicePx(valOffset / 2);
      }

      xBounds.set(chart, dataSet);
      reduceVisible(chart, dataSet);

      final positions = reducedPositions(dataSet, trans, animator.phaseY);

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
            y - valOffset,
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

  /// Draws the circles, see [drawCircles].
  @override
  void drawExtras(ui.Canvas c) {
    drawCircles(c);
  }

  /// Draws a circle at each visible entry of every data set that enables circles. Circle radius and hole radius
  /// come from the data set in dp; the hole is transparent when the hole color is none. While decimation is on,
  /// the circles that another circle would cover are left out.
  ///
  /// Kotlin draws each circle from a bitmap cached per circle color; here each circle is drawn directly (see the
  /// file header), with the same colors, sizes and skipping.
  @protected
  void drawCircles(ui.Canvas c) {
    renderPaint.style = PaintStyle.FILL;

    final phaseY = animator.phaseY;

    final dataSets = chart.lineData?.dataSets;
    if (dataSets == null) return;

    for (final dataSet in dataSets) {
      if (!dataSet.isVisible ||
          !dataSet.isDrawCirclesEnabled ||
          dataSet.entryCount == 0) {
        continue;
      }

      circlePaintInner.color = dataSet.circleHoleColor;

      final trans = chart.getTransformer(dataSet.axisDependency);

      xBounds.set(chart, dataSet);
      reduceVisible(chart, dataSet);

      final circleRadius = Utils.convertDpToPixel(dataSet.circleRadius);
      final circleHoleRadius = Utils.convertDpToPixel(dataSet.circleHoleRadius);
      final drawCircleHole =
          dataSet.isDrawCircleHoleEnabled &&
          circleHoleRadius < circleRadius &&
          circleHoleRadius > 0;
      final drawTransparentCircleHole =
          drawCircleHole && dataSet.circleHoleColor == ColorTemplate.COLOR_NONE;

      final colorCount = dataSet.circleColorCount;

      final floatsNeeded = reducer.count * 2;

      if (_circlePointBuffer.length < floatsNeeded) {
        _circlePointBuffer = Float32List(floatsNeeded * 2);
      }

      var w = 0;
      for (var k = 0; k < reducer.count; k++) {
        final e = dataSet.getEntryForIndex(reducer.indices[k]);
        _circlePointBuffer[w++] = e.x;
        _circlePointBuffer[w++] = e.y * phaseY;
      }

      trans.pointValuesToPixel(_circlePointBuffer, floatsNeeded);

      // Once the points are closer together than a circle is wide the circles cover each other, so only
      // every so many are worth drawing.
      final circleDiameter = circleRadius * 2;
      var lastCircleX = double.negativeInfinity;

      for (var i = 0; i < reducer.count; i++) {
        final x = _circlePointBuffer[i * 2];
        final y = _circlePointBuffer[i * 2 + 1];

        if (!viewPortHandler.isInBoundsRight(x)) break;

        if (!viewPortHandler.isInBoundsLeft(x) ||
            !viewPortHandler.isInBoundsY(y)) {
          continue;
        }

        if (x - lastCircleX < circleDiameter) continue;

        lastCircleX = x;

        // Kotlin: imageCache.getBitmap(index), null (nothing drawn) for a set without circle colors.
        if (colorCount == 0) continue;

        renderPaint.color = dataSet.getCircleColor(
          reducer.indices[i] % colorCount,
        );

        if (drawTransparentCircleHole) {
          _circlePathBuffer.reset();
          // reset() also resets the fill type, so the hole needs even-odd set again every time.
          _circlePathBuffer.fillType = ui.PathFillType.evenOdd;
          _circlePathBuffer.addOval(
            ui.Rect.fromCircle(center: ui.Offset(x, y), radius: circleRadius),
          );
          _circlePathBuffer.addOval(
            ui.Rect.fromCircle(
              center: ui.Offset(x, y),
              radius: circleHoleRadius,
            ),
          );
          c.drawPathP(_circlePathBuffer, renderPaint);
        } else {
          c.drawCircleP(x, y, circleRadius, renderPaint);

          if (drawCircleHole) {
            c.drawCircleP(x, y, circleHoleRadius, circlePaintInner);
          }
        }
      }
    }
  }

  final ChartPaint _highlightCirclePaint = ChartPaint();

  @override
  void drawHighlighted(ui.Canvas c, List<Highlight> indices) {
    final lineData = chart.lineData;
    if (lineData == null) return;

    for (final high in indices) {
      final set = lineData.getDataSetByIndex(high.dataSetIndex);

      if (set == null || !set.isHighlightEnabled) continue;

      final e = set.getEntryForXValue(high.x, high.y);

      if (e == null || !isInBoundsX(e, set)) continue;

      final pix = chart
          .getTransformer(set.axisDependency)
          .getPixelForValues(e.x, e.y * animator.phaseY);

      final x = toKotlinFloat(pix.x);
      final y = toKotlinFloat(pix.y);

      high.setDraw(x, y);

      drawHighlightLines(c, x, y, set);

      if (set.isDrawHighlightCircleEnabled) {
        drawHighlightCircle(c, x, y, set);
      }
    }
  }

  /// Draws a soft halo in the highlight color, a ring in the line color and a center in the circle hole color at
  /// ([x], [y]) px.
  @protected
  void drawHighlightCircle(ui.Canvas c, double x, double y, ILineDataSet set) {
    final radius = Utils.convertDpToPixel(set.highlightCircleRadius);
    _highlightCirclePaint.style = PaintStyle.FILL;
    _highlightCirclePaint.color = set.highlightColor;
    _highlightCirclePaint.alpha = 70;
    c.drawCircleP(x, y, radius * 1.9, _highlightCirclePaint);
    _highlightCirclePaint.color = set.circleHoleColor;
    _highlightCirclePaint.alpha = 255;
    c.drawCircleP(x, y, radius, _highlightCirclePaint);
    _highlightCirclePaint.style = PaintStyle.STROKE;
    _highlightCirclePaint.strokeWidth = Utils.convertDpToPixel(2.5);
    _highlightCirclePaint.color = set.color;
    c.drawCircleP(x, y, radius, _highlightCirclePaint);
  }
}

/// The pieces of the data sets one [LineChartRenderer.drawData] pass draws: everything (no bezier or dashed line is
/// visible), what Kotlin draws onto the chart canvas, or what Kotlin draws onto its offscreen bitmap.
enum _DrawPass { all, direct, offscreen }
