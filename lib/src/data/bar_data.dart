// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/BarData.kt
import '../interfaces/datasets/i_bar_data_set.dart';
import 'bar_line_scatter_candle_bubble_data.dart';

/// Data for a bar chart: one or more [IBarDataSet]s plus the shared bar width and grouping.
class BarData extends BarLineScatterCandleBubbleData<IBarDataSet> {
  /// Creates a data object holding [dataSets] (kept by reference), or an empty one (Kotlin's `()`,
  /// `(vararg dataSets)` and `(dataSets: List)` constructors).
  BarData([super.dataSets]);

  /// Width of every bar in x value units, not pixels. Default 0.85, which leaves a gap between bars 1 apart.
  double barWidth = 0.85;

  /// Places the bars of all sets side by side in groups by rewriting the x of their entries in place.
  /// Entry i of every set forms group i; groups are laid out for the set with the most entries, starting at
  /// [fromX], each group taking [getGroupWidth]. Previously set x values are lost. Recomputes the cached
  /// ranges here; the chart still needs its own notify call. Set the x axis range to [fromX] plus the
  /// group count times [getGroupWidth] to show all groups.
  ///
  /// [fromX] is the x value where the first group starts, [groupSpace] the space between groups in x value units,
  /// for example 0.8 for a bar width of 1, and [barSpace] the space between the bars of a group in x value units,
  /// for example 0.1 for a bar width of 1.
  ///
  /// Throws a [StateError] when this data holds fewer than 2 sets.
  void groupBars(double fromX, double groupSpace, double barSpace) {
    final setCount = dataSets.length;
    if (setCount <= 1) {
      throw StateError(
        'BarData needs to hold at least 2 BarDataSets to allow grouping.',
      );
    }

    final max = maxEntryCountSet;
    if (max == null) return;
    final maxEntryCount = max.entryCount;

    final groupSpaceWidthHalf = groupSpace / 2;
    final barSpaceHalf = barSpace / 2;
    final barWidthHalf = barWidth / 2;

    final interval = getGroupWidth(groupSpace, barSpace);

    var x = fromX;
    for (var i = 0; i < maxEntryCount; i++) {
      final start = x;
      x += groupSpaceWidthHalf;

      for (final set in dataSets) {
        x += barSpaceHalf;
        x += barWidthHalf;

        if (i < set.entryCount) {
          set.getEntryForIndex(i).x = x;
        }

        x += barWidthHalf;
        x += barSpaceHalf;
      }

      x += groupSpaceWidthHalf;
      final end = x;
      final innerInterval = end - start;
      final diff = interval - innerInterval;

      if (diff > 0 || diff < 0) {
        x += diff;
      }
    }

    notifyDataChanged();
  }

  /// Returns the x range one group of bars takes after [groupBars]: one [barWidth] plus [barSpace] per set,
  /// plus [groupSpace].
  ///
  /// [groupSpace] is the space between groups and [barSpace] the space between the bars of a group, both in x value
  /// units.
  double getGroupWidth(double groupSpace, double barSpace) {
    return dataSets.length * (barWidth + barSpace) + groupSpace;
  }
}
