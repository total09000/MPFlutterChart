// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/YAxisRendererRadarChart.kt
//
// The renderer has no Transformer (null): the base computeAxis then computes the labels from the given
// range directly. computeAxisValues keeps Kotlin's Float semantics as AxisRenderer does: min and max are
// rounded to Float on entry (toKotlinFloat), the range is a Float subtraction (kotlinFloatOverflow), every `.toInt()`
// is kotlinFloatToInt (which gives 0 for NaN and saturates at the Int range instead of throwing), `log10` is
// kotlinLog10 and the entries are written as Floats. Where Kotlin would loop forever counting the labels (an interval
// below half an ulp of the label values, only reachable with a label count in the billions), the count stops at the
// label that no longer advances, as in AxisRenderer. Like Kotlin, it does not look at minimumInterval.
//
// A label whose position is not finite as a Float is not drawn, and a limit line with such a corner is
// not drawn at all; Kotlin's Float positions are infinite or NaN there, and Android draws nothing.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../charts/radar_chart.dart';
import '../components/y_axis.dart';
import '../graphics/chart_canvas.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';
import '../utils/view_port_handler.dart';
import 'y_axis_renderer.dart';

/// Draws the y axis of a [RadarChart]: the label values along the spoke at the chart's rotation angle, and limit lines
/// as closed polygons around the web. Grid lines and the axis line are part of the web drawn by the chart's data
/// renderer.
class YAxisRendererRadarChart extends YAxisRenderer {
  /// Creates the renderer of [yAxis] for the radar chart [_chart], without a transformer.
  YAxisRendererRadarChart(
    ViewPortHandler viewPortHandler,
    YAxis yAxis,
    this._chart,
  ) : super(viewPortHandler, yAxis, null);

  final RadarChart _chart;

  /// Like `AxisRenderer.computeAxisValues`, but where a limit is not custom it adds one more entry after the last
  /// interval and applies the first and last entry as the axis range, so the web ends exactly on a label. [min] and
  /// [max] are axis values.
  ///
  /// A custom limit (`isAxisMinCustom`, `isAxisMaxCustom`) stays as it was set and no entry lies beyond it, deliberate
  /// deviations: a custom maximum gets neither the
  /// extra entry nor, with centered labels, the one that centering adds above the range, and a custom minimum drops
  /// the one that centering adds below it. When no entry is left, a computed limit is [min] or [max]. The entries are
  /// Kotlin's Float values while a custom limit keeps the double it was set to, so an outer entry can still lie a
  /// Float rounding beyond it.
  ///
  /// Leaves the axis without entries, and its range unchanged, when the label count is 0 or the range is zero or
  /// infinite. Forced labels are spread evenly from [min] to [max] without regard to the granularity, as Kotlin's Float
  /// sums.
  @protected
  @override
  void computeAxisValues(double min, double max) {
    final yMin = toKotlinFloat(min);
    final yMax = toKotlinFloat(max);
    final isMinCustom = axis.isAxisMinCustom;
    final isMaxCustom = axis.isAxisMaxCustom;

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

    final intervalMagnitude = Utils.roundToNextSignificant(
      math.pow(10.0, kotlinFloatToInt(kotlinLog10(interval))).toDouble(),
    );
    final intervalSigDigit = kotlinFloatToInt(interval / intervalMagnitude);
    if (intervalSigDigit > 5) {
      interval = (10.0 * intervalMagnitude).floorToDouble() == 0.0
          ? interval
          : (10.0 * intervalMagnitude).floorToDouble();
    }

    final centeringEnabled = axis.isCenterAxisLabelsEnabled;
    var n = centeringEnabled ? 1 : 0;

    if (axis.isForceLabelsEnabled) {
      final step = toKotlinFloat(
        toKotlinFloat(range) / toKotlinFloat((labelCount - 1).toDouble()),
      );
      axis.entryCount = labelCount;

      if (axis.entries.length < labelCount) {
        axis.entries = Float32List(labelCount);
      }

      var v = yMin;
      for (var i = 0; i < labelCount; i++) {
        axis.entries[i] = v;
        v = toKotlinFloat(v + step);
      }

      n = labelCount;
    } else {
      var first = interval == 0.0
          ? 0.0
          : (yMin / interval).ceilToDouble() * interval;
      if (centeringEnabled) {
        first -= interval;
      }

      final last = interval == 0.0
          ? 0.0
          : Utils.nextUp((yMax / interval).floorToDouble() * interval);

      if (interval != 0.0) {
        var f = first;
        while (f <= last) {
          ++n;
          final next = f + interval;
          // Deliberate deviation: Kotlin hangs here when the interval no longer advances f; a UI-thread
          // hang is never acceptable, so stop counting. Only fires where Kotlin would loop forever.
          if (next == f) break;
          f = next;
        }
      }

      // Deliberate deviation: Kotlin always adds this outer entry and
      // applies the last entry as the axis maximum below, into the field that holds a custom maximum, so a custom
      // maximum grows on every notifyDataSetChanged. With a custom maximum only the entries up to `last`, the bound
      // the loop counted to, are kept: neither this outer entry nor the one beyond `last` that centering's start at
      // n = 1 stands for.
      if (!isMaxCustom) {
        n++;
      } else if (centeringEnabled) {
        n--;
      }

      // Deliberate deviation: Kotlin applies the first entry as the axis minimum below, into the field
      // that holds a custom minimum, so with centered labels a custom minimum falls by an interval on every
      // notifyDataSetChanged. A custom minimum is kept as set and no entry lies below it; only centering's shifted
      // first entry can, so it is left out.
      if (isMinCustom && centeringEnabled && n > 0) {
        first += interval;
        n--;
      }

      axis.entryCount = n;

      if (axis.entries.length < n) {
        axis.entries = Float32List(n);
      }

      var f = first;
      for (var i = 0; i < n; i++) {
        if (f == 0.0) f = 0.0;
        axis.entries[i] = toKotlinFloat(f);
        f += interval;
      }
    }

    axis.decimals = interval < 1
        ? kotlinFloatToInt((-kotlinLog10(interval)).ceilToDouble())
        : 0;

    if (centeringEnabled) {
      if (axis.centeredEntries.length < n) {
        axis.centeredEntries = Float32List(n);
      }

      // With a custom limit fewer than two entries can be left, and half the interval
      // stands in for half the distance of the first two.
      final offset = n > 1
          ? toKotlinFloat(axis.entries[1] - axis.entries[0]) / 2
          : toKotlinFloat(interval) / 2;
      for (var i = 0; i < n; i++) {
        axis.centeredEntries[i] = axis.entries[i] + offset;
      }
    }

    // A custom limit is never written back. With a custom limit no entry may be left
    // (n == 0, no label in the range), and a computed limit is then min or max.
    axis.applyAxisRange(
      isMinCustom ? axis.axisMinimum : (n > 0 ? axis.entries[0] : min),
      isMaxCustom ? axis.axisMaximum : (n > 0 ? axis.entries[n - 1] : max),
    );
  }

  /// Draws the labels along the spoke at the chart's rotation angle, each at the distance from the center that matches
  /// its value and the axis label x offset (dp) to the right of it. The lowest and highest label are left out when the
  /// axis disables them. Does nothing when the axis or its labels are disabled.
  @override
  void renderAxisLabels(ui.Canvas c) {
    if (!yAxis.isEnabled || !yAxis.isDrawLabelsEnabled) return;

    paintAxisLabels.typeface = yAxis.typeface;
    paintAxisLabels.textSize = Utils.convertDpToPixel(yAxis.textSize);
    paintAxisLabels.color = yAxis.textColor;

    final center = _chart.centerOffsets;
    final pOut = MPPointF.getInstance(0, 0);
    final factor = _chart.factor;

    final from = yAxis.isDrawBottomYLabelEntryEnabled ? 0 : 1;
    final to = yAxis.isDrawTopYLabelEntryEnabled
        ? yAxis.entryCount
        : yAxis.entryCount - 1;

    final xOffset = Utils.convertDpToPixel(yAxis.labelXOffset);

    for (var j = from; j < to; j++) {
      final r = (yAxis.entries[j] - yAxis.axisMinimum) * factor;

      Utils.getPosition(center, r, _chart.rotationAngle, pOut);

      final label = yAxis.getFormattedLabel(j);

      if (!_isFinitePoint(pOut.x + xOffset, pOut.y)) continue;

      c.drawText(label, pOut.x + xOffset, pOut.y, paintAxisLabels);
    }
    MPPointF.recycleInstance(center);
    MPPointF.recycleInstance(pOut);
  }

  final ui.Path _renderLimitLinesPathBuffer = ui.Path();

  /// Draws each enabled limit line as a closed polygon through all spokes at the radius of its limit value, with the
  /// color, dash effect and line width (dp) of the limit line. Limit line labels are not drawn.
  @override
  void renderLimitLines(ui.Canvas c) {
    final limitLines = yAxis.limitLines;

    final sliceangle = _chart.sliceAngle;
    final factor = _chart.factor;

    final center = _chart.centerOffsets;
    final pOut = MPPointF.getInstance(0, 0);
    final entryCount = _chart.data?.maxEntryCountSet?.entryCount ?? 0;
    for (final l in limitLines) {
      if (!l.isEnabled) continue;

      limitLinePaint.color = l.lineColor;
      limitLinePaint.pathEffect = l.dashPathEffect;
      limitLinePaint.strokeWidth = Utils.convertDpToPixel(l.lineWidth);

      final r = (l.limit - _chart.yChartMin) * factor;

      final limitPath = _renderLimitLinesPathBuffer;
      limitPath.reset();

      var isFinite = true;
      for (var j = 0; j < entryCount; j++) {
        Utils.getPosition(
          center,
          r,
          sliceangle * j + _chart.rotationAngle,
          pOut,
        );

        // A polygon with a corner that is not finite is not drawn.
        if (!_isFinitePoint(pOut.x, pOut.y)) {
          isFinite = false;
          break;
        }

        if (j == 0) {
          limitPath.moveTo(pOut.x, pOut.y);
        } else {
          limitPath.lineTo(pOut.x, pOut.y);
        }
      }
      if (!isFinite) {
        limitPath.reset();
        continue;
      }
      limitPath.close();

      c.drawPathP(limitPath, limitLinePaint);
    }
    MPPointF.recycleInstance(center);
    MPPointF.recycleInstance(pOut);
  }

  /// Whether ([x], [y]) is finite as a Float, as Kotlin's positions are.
  static bool _isFinitePoint(double x, double y) =>
      toKotlinFloat(x).isFinite && toKotlinFloat(y).isFinite;
}
