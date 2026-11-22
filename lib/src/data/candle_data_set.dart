// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/CandleDataSet.kt
import 'dart:ui';

import 'package:flutter/foundation.dart' show protected;

import '../graphics/chart_paint.dart';
import '../interfaces/datasets/i_candle_data_set.dart';
import '../utils/color_template.dart';
import 'candle_entry.dart';
import 'data_set.dart';
import 'line_scatter_candle_radar_data_set.dart';

/// One series of candles in a candle stick chart. The y range covers the candles' low to high values.
///
/// [D] is the payload type of the entries.
class CandleDataSet<D> extends LineScatterCandleRadarDataSet<CandleEntry<D>>
    implements ICandleDataSet<D> {
  /// Creates a set from [entries], the candles sorted by x (kept by reference, see `DataSet.entries`), named [label],
  /// shown in the legend.
  CandleDataSet(super.entries, super.label);

  @override
  double shadowWidth = 1.5;

  @override
  bool showCandleBar = true;

  double _barSpace = 0.1;

  /// Space left free on each side of a candle as a fraction of the slot width, clamped to 0 to 0.45. Default 0.1.
  @override
  double get barSpace => _barSpace;

  set barSpace(double value) {
    // Kotlin's coerceIn(0f, 0.45f), which lets NaN through.
    _barSpace = value < 0
        ? 0
        : value > 0.45
        ? 0.45
        : value;
  }

  @override
  bool shadowColorSameAsCandle = false;

  @override
  PaintStyle increasingPaintStyle = PaintStyle.STROKE;

  @override
  PaintStyle decreasingPaintStyle = PaintStyle.FILL;

  /// Color for candles with open equal to close. [ColorTemplate.COLOR_NONE], the default, uses the entry color.
  @override
  Color neutralColor = ColorTemplate.COLOR_NONE;

  /// Color for candles with close above open. [ColorTemplate.COLOR_NONE], the default, uses the entry color from
  /// [colors].
  @override
  Color increasingColor = ColorTemplate.COLOR_NONE;

  /// Color for candles with close below open. [ColorTemplate.COLOR_NONE], the default, uses the entry color from
  /// [colors].
  @override
  Color decreasingColor = ColorTemplate.COLOR_NONE;

  /// Color of the shadow lines when [shadowColorSameAsCandle] is off. Set [ColorTemplate.COLOR_NONE] to use
  /// the entry color from [colors].
  @override
  Color shadowColor = ColorTemplate.COLOR_NONE;

  @override
  DataSet<CandleEntry<D>> copy() {
    final copiedEntries = [for (final it in entries) it.copy()];
    final copied = CandleDataSet<D>(copiedEntries, label);
    copyTo(copied);
    return copied;
  }

  /// Copies the styling from this set into [candleDataSet]; entries are not copied here.
  @override
  @protected
  void copyTo(covariant CandleDataSet<D> candleDataSet) {
    super.copyTo(candleDataSet);
    candleDataSet.shadowWidth = shadowWidth;
    candleDataSet.showCandleBar = showCandleBar;
    candleDataSet.barSpace = barSpace;
    candleDataSet.shadowColorSameAsCandle = shadowColorSameAsCandle;
    candleDataSet.highlightColor = highlightColor;
    candleDataSet.increasingPaintStyle = increasingPaintStyle;
    candleDataSet.decreasingPaintStyle = decreasingPaintStyle;
    candleDataSet.neutralColor = neutralColor;
    candleDataSet.increasingColor = increasingColor;
    candleDataSet.decreasingColor = decreasingColor;
    candleDataSet.shadowColor = shadowColor;
  }

  /// Widens the ranges with the candle's [CandleEntry.low] and [CandleEntry.high] instead of its y.
  ///
  /// Kotlin's protected `calcMinMax(e: CandleEntry<D>)` overload.
  @override
  @protected
  void calcMinMaxForEntry(CandleEntry<D> e) {
    calcMinMaxYForEntry(e);
    calcMinMaxX(e);
  }

  /// Widens the y range with the candle's [CandleEntry.low] and [CandleEntry.high] instead of its y; a candle with a
  /// NaN or infinite low or high is left out.
  ///
  /// Kotlin's protected `calcMinMaxY(e: CandleEntry<D>)` overload.
  @override
  @protected
  void calcMinMaxYForEntry(CandleEntry<D> e) {
    if (!e.high.isFinite || !e.low.isFinite) return;
    if (e.high < yMin) yMin = e.high;
    if (e.high > yMax) yMax = e.high;
    if (e.low < yMin) yMin = e.low;
    if (e.low > yMax) yMax = e.low;
  }
}
