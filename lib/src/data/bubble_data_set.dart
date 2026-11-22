// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/BubbleDataSet.kt
import 'package:flutter/foundation.dart' show protected;

import '../interfaces/datasets/i_bubble_data_set.dart';
import 'bar_line_scatter_candle_bubble_data_set.dart';
import 'bubble_entry.dart';
import 'data_set.dart';

/// One series of bubbles in a bubble chart.
///
/// [D] is the payload type of the entries.
class BubbleDataSet<D> extends BarLineScatterCandleBubbleDataSet<BubbleEntry<D>>
    implements IBubbleDataSet<D> {
  /// Creates a set from [entries], the bubbles sorted by x (kept by reference, see `DataSet.entries`), named [label],
  /// shown in the legend.
  BubbleDataSet(super.entries, super.label);

  double _maxSize = 0;

  /// Largest [BubbleEntry.size] in the set, the reference for scaling bubbles when [isNormalizeSizeEnabled] is on.
  /// Adding an entry can only widen it; [calcMinMax] recomputes it from scratch.
  @override
  double get maxSize => _maxSize;

  @protected
  set maxSize(double value) => _maxSize = value;

  @override
  bool isNormalizeSizeEnabled = true;

  @override
  double highlightCircleWidth = 1;

  /// Recomputes [maxSize] from scratch along with the ranges.
  @override
  void calcMinMax() {
    maxSize = 0;
    super.calcMinMax();
  }

  /// Widens the ranges and [maxSize] to include [e].
  ///
  /// Kotlin's protected `calcMinMax(e: BubbleEntry<D>)` overload.
  @override
  @protected
  void calcMinMaxForEntry(BubbleEntry<D> e) {
    super.calcMinMaxForEntry(e);
    if (e.size > maxSize) maxSize = e.size;
  }

  @override
  DataSet<BubbleEntry<D>> copy() {
    final copiedEntries = [for (final it in entries) it.copy()];
    final copied = BubbleDataSet<D>(copiedEntries, label);
    copyTo(copied);
    return copied;
  }

  /// Copies the styling into [bubbleDataSet]; the entries are not copied.
  @override
  @protected
  void copyTo(covariant BubbleDataSet<D> bubbleDataSet) {
    super.copyTo(bubbleDataSet);
    bubbleDataSet.highlightCircleWidth = highlightCircleWidth;
    bubbleDataSet.isNormalizeSizeEnabled = isNormalizeSizeEnabled;
  }
}
