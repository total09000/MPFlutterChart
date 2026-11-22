// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/AxisRenderer.kt
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../components/axis_base.dart';
import '../graphics/chart_paint.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_d.dart';
import '../utils/transformer.dart';
import '../utils/utils.dart';
import 'renderer.dart';

/// Base class of the axis renderers. Computes the label values of an axis from its visible range and draws its
/// labels, grid lines, axis line and limit lines.
///
/// On every draw pass the chart calls [computeAxis] first, then [renderAxisLine], [renderGridLines] and
/// [renderLimitLines] (each either before or after the data, depending on the axis settings), and finally
/// [renderAxisLabels]. Subclass a concrete renderer and assign it to the chart's axis renderer slot
/// (`rendererXAxis`, `rendererLeftYAxis`, `rendererRightYAxis`) to change how an axis is drawn.
abstract class AxisRenderer extends Renderer {
  /// Creates a renderer for [axis]; [transformer] converts axis values to pixels and back.
  AxisRenderer(super.viewPortHandler, this.transformer, this.axis);

  /// Converts axis values to pixels and back; null for the radar chart axes, which are placed by the chart
  /// instead.
  final Transformer? transformer;

  /// The axis this renderer draws.
  @protected
  final AxisBase axis;

  /// Paint for the axis labels; typeface, text size (dp) and color are copied from the axis on every draw.
  final ChartPaint paintAxisLabels = ChartPaint();

  /// Paint for the grid lines; color, line width (dp) and dash effect are copied from the axis on every draw.
  final ChartPaint paintGrid = ChartPaint(antiAlias: false)
    ..color = const ui.Color(0xFF888888)
    ..strokeWidth = 1
    ..style = PaintStyle.STROKE
    ..alpha = 90;

  /// Paint for the axis line; color and line width (dp) are copied from the axis on every draw.
  final ChartPaint paintAxisLine = ChartPaint(antiAlias: false)
    ..color = const ui.Color(0xFF000000)
    ..strokeWidth = 1
    ..style = PaintStyle.STROKE;

  /// Paint for the limit lines and their labels; restyled per `LimitLine` while drawing.
  @protected
  final ChartPaint limitLinePaint = ChartPaint()..style = PaintStyle.STROKE;

  /// Reused for the value at the top edge of the content rectangle, so a draw pass allocates nothing.
  @protected
  final MPPointD computeAxisPoint1 = MPPointD(0.0, 0.0);

  /// Reused for the value at the bottom edge of the content rectangle.
  @protected
  final MPPointD computeAxisPoint2 = MPPointD(0.0, 0.0);

  /// Computes the label values of the axis for the value range [min] to [max]. When the chart is zoomed in, the
  /// range is replaced by the values at the top and bottom edge of the content rectangle so that labels are only
  /// computed for what is visible.
  ///
  /// [inverted] is true when the axis runs in the opposite direction, which swaps the edge that holds the minimum.
  void computeAxis(double min, double max, bool inverted) {
    var newMin = min;
    var newMax = max;

    final transformer = this.transformer;
    if (transformer != null &&
        viewPortHandler.contentWidth > 10 &&
        !viewPortHandler.isFullyZoomedOutY) {
      final p1 = computeAxisPoint1;
      final p2 = computeAxisPoint2;
      transformer.getValuesByTouchPoint(
        viewPortHandler.contentLeft,
        viewPortHandler.contentTop,
        p1,
      );
      transformer.getValuesByTouchPoint(
        viewPortHandler.contentLeft,
        viewPortHandler.contentBottom,
        p2,
      );

      if (!inverted) {
        newMin = toKotlinFloat(p2.y);
        newMax = toKotlinFloat(p1.y);
      } else {
        newMin = toKotlinFloat(p1.y);
        newMax = toKotlinFloat(p2.y);
      }
    }

    computeAxisValues(newMin, newMax);
  }

  /// Fills the axis with evenly spaced label values between [min] and [max] (axis values) and stores them in its
  /// `entries`, `entryCount`, `centeredEntries` and `decimals`. Honors the label count, granularity, forced label
  /// count, centered labels and [minimumInterval]. Leaves the axis without entries when the range is zero or
  /// infinite.
  ///
  /// Like Kotlin's `computeAxisValues(min: Float, max: Float)`, [min] and [max] are rounded to Float on entry: a
  /// range below the Float resolution collapses to zero instead of giving an interval too small to advance a label
  /// value. Where Kotlin would still loop forever counting the labels (an interval below half an ulp of the label
  /// values, only reachable with a label count in the billions), the count stops at the label that no longer
  /// advances; see MIGRATION.md.
  @protected
  void computeAxisValues(double min, double max) {
    final yMin = toKotlinFloat(min);
    final yMax = toKotlinFloat(max);

    final labelCount = axis.labelCount;
    // Kotlin subtracts in Float: the empty-data range Float.MAX_VALUE .. -Float.MAX_VALUE overflows to infinity.
    final range = kotlinFloatOverflow(yMax - yMin).abs();

    if (labelCount == 0 || range <= 0 || range.isInfinite) {
      axis.entries = Float32List(0);
      axis.centeredEntries = Float32List(0);
      axis.entryCount = 0;
      return;
    }

    final rawInterval = range / labelCount;
    var interval = Utils.roundToNextSignificant(rawInterval);

    if (axis.isGranularityEnabled) {
      interval = interval < axis.granularity ? axis.granularity : interval;
    }

    final minInterval = minimumInterval(range);
    if (interval < minInterval) {
      final magnitude = Utils.roundToNextSignificant(
        math.pow(10.0, kotlinFloatToInt(kotlinLog10(minInterval))).toDouble(),
      );
      final rounded = Utils.roundToNextSignificant(minInterval);
      // Rounding to a significant digit must not fall back below the minimum, so round up in that case.
      interval = rounded < minInterval
          ? (kotlinFloatToInt(minInterval / magnitude) + 1) * magnitude
          : rounded;
    }

    final intervalMagnitude = Utils.roundToNextSignificant(
      math.pow(10.0, kotlinFloatToInt(kotlinLog10(interval))).toDouble(),
    );
    final intervalSigDigit = kotlinFloatToInt(interval / intervalMagnitude);
    if (intervalSigDigit > 5) {
      interval = (10.0 * intervalMagnitude).floorToDouble() == 0.0
          ? interval
          : (10.0 * intervalMagnitude).floorToDouble();
    }

    var n = axis.isCenterAxisLabelsEnabled ? 1 : 0;

    if (axis.isForceLabelsEnabled) {
      interval = toKotlinFloat(
        toKotlinFloat(range) / (labelCount - 1).toDouble(),
      );

      var forcedCount = labelCount;
      if (axis.isGranularityEnabled && interval < axis.granularity) {
        interval = axis.granularity;
        forcedCount = kotlinFloatToInt(range / interval) + 1;
      }

      axis.entryCount = forcedCount;

      if (axis.entries.length < forcedCount) {
        axis.entries = Float32List(forcedCount);
      }

      var v = yMin;
      final step = toKotlinFloat(interval);
      for (var i = 0; i < forcedCount; i++) {
        axis.entries[i] = v;
        v = toKotlinFloat(v + step);
      }

      n = forcedCount;
    } else {
      var first = interval == 0.0
          ? 0.0
          : (yMin / interval).ceilToDouble() * interval;
      if (axis.isCenterAxisLabelsEnabled) {
        first -= interval;
      }

      final last = interval == 0.0
          ? 0.0
          : Utils.nextUp((yMax / interval).floorToDouble() * interval);

      if (interval != 0.0 && last != first) {
        var f = first;
        while (f <= last) {
          ++n;
          final next = f + interval;
          // Deliberate deviation: Kotlin hangs here when the interval no longer advances f; a UI-thread hang is
          // never acceptable, so stop counting. Only fires where Kotlin would loop forever.
          if (next == f) break;
          f = next;
        }
      } else if (last == first && n == 0) {
        n = 1;
      }

      axis.entryCount = n;

      if (axis.entries.length < n) {
        axis.entries = Float32List(n);
      }

      var f = first;
      for (var i = 0; i < n; i++) {
        if (f == 0.0) f = 0.0;
        axis.entries[i] = f;
        f += interval;
      }
    }

    axis.decimals = interval < 1
        ? kotlinFloatToInt((-kotlinLog10(interval)).ceilToDouble())
        : 0;

    if (axis.isCenterAxisLabelsEnabled) {
      if (axis.centeredEntries.length < n) {
        axis.centeredEntries = Float32List(n);
      }

      final offset = toKotlinFloat(interval) / 2;
      for (var i = 0; i < n; i++) {
        axis.centeredEntries[i] = axis.entries[i] + offset;
      }
    }
  }

  /// Smallest interval in axis values the labels may use, so that neighbouring labels do not overlap.
  /// 0, the default, places no limit.
  @protected
  double minimumInterval(double range) => 0.0;

  /// Draws the axis labels onto [c]. Does nothing when the axis or its labels are disabled.
  void renderAxisLabels(ui.Canvas c);

  /// Draws the grid lines onto [c]. Does nothing when the axis or its grid lines are disabled.
  void renderGridLines(ui.Canvas c);

  /// Draws the axis line onto [c]. Does nothing when the axis or its line is disabled.
  void renderAxisLine(ui.Canvas c);

  /// Draws the enabled limit lines of the axis and their labels onto [c].
  void renderLimitLines(ui.Canvas c);
}
