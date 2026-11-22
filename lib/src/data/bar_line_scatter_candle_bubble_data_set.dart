// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/BarLineScatterCandleBubbleDataSet.kt
import 'dart:ui';

import 'package:flutter/foundation.dart' show protected;

import '../interfaces/datasets/i_bar_line_scatter_candle_bubble_data_set.dart';
import 'data_set.dart';
import 'entry.dart';

/// Base for the data sets of the charts with an x and a y axis (bar, line, scatter, candle and bubble).
/// Adds the highlight color those charts share.
///
/// [T] is the entry type this set holds.
abstract class BarLineScatterCandleBubbleDataSet<T extends Entry>
    extends DataSet<T>
    implements IBarLineScatterCandleBubbleDataSet<T> {
  /// Creates a set holding [entries] named [label].
  BarLineScatterCandleBubbleDataSet(super.entries, super.label);

  @override
  Color highlightColor = const Color.fromARGB(255, 255, 187, 115);

  /// Copies the styling from this set into [dataSet]; entries are not copied here.
  @override
  @protected
  void copyTo(covariant BarLineScatterCandleBubbleDataSet dataSet) {
    super.copyTo(dataSet);
    dataSet.highlightColor = highlightColor;
  }
}
