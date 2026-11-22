// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/PieData.kt
//
// Kotlin's `highlight.x.toInt()` is `kotlinFloatToInt`, which gives 0 for NaN like Kotlin instead of throwing.
// [PieData.yValueSum] sums in double precision, so it does not overflow to infinity where Kotlin's Float sum does.
import '../highlight/highlight.dart';
import '../interfaces/datasets/i_pie_data_set.dart';
import '../utils/float_math.dart';
import 'chart_data.dart';
import 'entry.dart';

/// Data for a pie chart. Unlike the other data objects it holds exactly one set, whose entries are the slices;
/// the legend is built from the entry labels, not from the set label.
class PieData extends ChartData<IPieDataSet> {
  /// Creates a data object holding [dataSet], or one without a set when [dataSet] is null; assign [dataSet] before
  /// use then (Kotlin's `()` and `(dataSet)` constructors).
  PieData([IPieDataSet? dataSet])
    : super(dataSet == null ? null : <IPieDataSet>[dataSet]);

  /// The single set of this data, or null while no set has been assigned. Assigning replaces any existing set,
  /// null removes it, and the cached ranges are recomputed.
  IPieDataSet? get dataSet => dataSets.isEmpty ? null : dataSets[0];

  set dataSet(IPieDataSet? value) {
    dataSets.clear();
    if (value != null) dataSets.add(value);
    notifyDataChanged();
  }

  /// Returns [dataSet] for index 0 and null for every other index or while no set has been assigned.
  @override
  IPieDataSet? getDataSetByIndex(int index) {
    return index == 0 ? dataSet : null;
  }

  /// Returns [dataSet] if its label equals [label], otherwise null, also while no set has been assigned.
  ///
  /// [ignoreCase] is true to compare labels case insensitively.
  @override
  IPieDataSet? getDataSetByLabel(String label, bool ignoreCase) {
    final set = dataSet;
    if (set == null) return null;
    final matches = ignoreCase
        ? label.toLowerCase() == set.label.toLowerCase()
        : label == set.label;
    return matches ? set : null;
  }

  /// Returns the slice a highlight refers to. For pie charts [Highlight.x] holds the entry index (truncated towards
  /// zero), not an x value; [Highlight.dataSetIndex] is ignored.
  ///
  /// Returns the slice, or null when that index is out of range or no set has been assigned.
  @override
  Entry? getEntryForHighlight(Highlight highlight) {
    final set = dataSet;
    if (set == null) return null;
    final index = kotlinFloatToInt(highlight.x);
    return (index >= 0 && index < set.entryCount)
        ? set.getEntryForIndex(index)
        : null;
  }

  /// Sum of all slice values, the whole pie. 0 while no set has been assigned.
  ///
  /// Summed in double precision: unlike Kotlin's Float sum it does not overflow to infinity for values near
  /// `Float.MAX_VALUE`.
  double get yValueSum {
    final set = dataSet;
    if (set == null) return 0;
    var sum = 0.0;
    for (var i = 0; i < set.entryCount; i++) {
      sum += set.getEntryForIndex(i).y;
    }
    return sum;
  }
}
