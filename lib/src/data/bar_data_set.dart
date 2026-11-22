// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/BarDataSet.kt
import 'dart:ui';

import 'package:flutter/foundation.dart' show protected;

import '../interfaces/datasets/i_bar_data_set.dart';
import '../utils/fill.dart';
import 'bar_entry.dart';
import 'bar_line_scatter_candle_bubble_data_set.dart';
import 'data_set.dart';

/// One group of bars in a bar chart. Bars may be stacked when their entries carry [BarEntry.stackValues].
///
/// [D] is the payload type of the entries.
class BarDataSet<D> extends BarLineScatterCandleBubbleDataSet<BarEntry<D>>
    implements IBarDataSet<D> {
  /// Creates a set from [entries], the bars sorted by x (kept by reference, see `DataSet.entries`), named [label],
  /// shown in the legend.
  BarDataSet(super.entries, super.label) {
    highlightColor = const Color.fromARGB(255, 0, 0, 0);
    _calcStackSize(entries);
    _calcEntryCountIncludingStacks(entries);
  }

  int _stackSize = 1;

  /// Largest number of stack values of any entry, 1 for unstacked bars. Recomputed whenever the ranges are,
  /// so after [notifyDataSetChanged] or after assigning [entries], and widened by [addEntry].
  @override
  int get stackSize => _stackSize;

  @protected
  set stackSize(int value) => _stackSize = value;

  @override
  Color barShadowColor = const Color.fromARGB(255, 215, 215, 215);

  @override
  double barBorderWidth = 0;

  @override
  Color barBorderColor = const Color(0xFF000000);

  @override
  int highlightAlpha = 120;

  int _entryCountStacks = 0;

  /// Number of entries where each stack value counts separately. Recomputed whenever the full ranges are,
  /// so an entry added through [addEntry] leaves it stale until [notifyDataSetChanged].
  int get entryCountStacks => _entryCountStacks;

  @override
  List<String> stackLabels = const [];

  @override
  double barCornerRadius = 0;

  @override
  bool isStackSectionsRounded = false;

  /// Gradient fills used instead of [colors] when set, reused from the start when there are more bars than fills.
  @override
  List<Fill>? fills;

  @override
  DataSet<BarEntry<D>> copy() {
    final copiedEntries = [for (final it in entries) it.copy()];
    final copied = BarDataSet<D>(copiedEntries, label);
    copyTo(copied);
    return copied;
  }

  /// Copies the styling from this set into [barDataSet]; the entries are not copied.
  @override
  @protected
  void copyTo(covariant BarDataSet<D> barDataSet) {
    super.copyTo(barDataSet);
    barDataSet.barBorderColor = barBorderColor;
    barDataSet.fills = fills?.toList();
    barDataSet.stackSize = stackSize;
    barDataSet.barCornerRadius = barCornerRadius;
    barDataSet.isStackSectionsRounded = isStackSectionsRounded;
    barDataSet.barShadowColor = barShadowColor;
    barDataSet.barBorderWidth = barBorderWidth;
    barDataSet.stackLabels = stackLabels;
    barDataSet.highlightAlpha = highlightAlpha;
  }

  /// Returns the fill for the bar at [index], wrapping around [fills], or an empty fill that draws nothing when none
  /// are set.
  @override
  Fill getFill(int index) {
    final fills = this.fills;
    if (fills == null || fills.isEmpty) return Fill();
    // Dart's % with a positive divisor is never negative, like Kotlin's Math.floorMod.
    return fills[index % fills.length];
  }

  /// Replaces [fills] with a single gradient from [startColor] to [endColor] used for every bar.
  void setGradientColor(Color startColor, Color endColor) {
    fills = [Fill.ofColors(startColor, endColor)];
  }

  void _calcEntryCountIncludingStacks(List<BarEntry<D>> entries) {
    _entryCountStacks = 0;
    for (final entry in entries) {
      final vals = entry.stackValues;
      _entryCountStacks += vals?.length ?? 1;
    }
  }

  void _calcStackSize(List<BarEntry<D>> entries) {
    stackSize = 1;
    for (final entry in entries) {
      final vals = entry.stackValues;
      if (vals != null && vals.length > stackSize) stackSize = vals.length;
    }
  }

  /// Widens the ranges with the full extent of a bar: for stacked entries from `-negativeSum` to
  /// `positiveSum` instead of y. Entries whose y is NaN or infinite are skipped.
  @override
  void calcMinMax() {
    _calcStackSize(entries);
    _calcEntryCountIncludingStacks(entries);
    super.calcMinMax();
  }

  /// Kotlin's protected `calcMinMax(e: BarEntry<D>)` overload.
  @override
  @protected
  void calcMinMaxForEntry(BarEntry<D> e) {
    if (!e.y.isFinite) return;

    final vals = e.stackValues;
    if (vals == null) {
      if (e.y < yMin) yMin = e.y;
      if (e.y > yMax) yMax = e.y;
    } else {
      if (vals.length > stackSize) stackSize = vals.length;
      if (-e.negativeSum < yMin) yMin = -e.negativeSum;
      if (e.positiveSum > yMax) yMax = e.positiveSum;
    }

    calcMinMaxX(e);
  }

  /// True when any entry has more than one stack value, that is when [stackSize] is above 1.
  @override
  bool get isStacked => stackSize > 1;
}
