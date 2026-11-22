// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/ChartData.kt
import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint, protected;

import '../components/y_axis_dependency.dart';
import '../formatter/i_value_formatter.dart';
import '../graphics/typeface.dart';
import '../highlight/highlight.dart';
import '../interfaces/datasets/i_data_set.dart';
import '../utils/float_math.dart';
import 'entry.dart';

/// Everything a chart draws: a list of data sets plus the cached x and y ranges over all of them, split by
/// y axis. The ranges are computed once at construction and again by [notifyDataChanged]; adding sets or
/// entries through this class widens them on the fly, changing a set in place does not.
///
/// [T] is the data set type this object holds. Dart has no overloading, so Kotlin's `removeDataSet(index: Int)` and
/// `removeEntry(xValue: Float, dataSetIndex: Int)` are [removeDataSetByIndex] and [removeEntryByXValue], and the
/// protected `calcMinMax(e, axis)` / `calcMinMax(d)` are [calcMinMaxForEntry] / [calcMinMaxForDataSet].
abstract class ChartData<T extends IDataSet> {
  /// Creates a data object holding [dataSets], or an empty one to add sets to with [addDataSet] (Kotlin's
  /// `()`, `(vararg dataSets)` and `(dataSets: List)` constructors).
  ///
  /// The list is kept by reference, so it must be growable for [addDataSet] to work. Kotlin keeps an `ArrayList` by
  /// reference and copies any other list; Dart lists cannot be told apart that way, so every list is kept.
  ChartData([List<T>? dataSets]) : dataSets = dataSets ?? <T>[] {
    notifyDataChanged();
  }

  /// The data sets in drawing order. Changing this list in place does not update the cached ranges; call
  /// [notifyDataChanged] afterwards or use [addDataSet] and [removeDataSet].
  final List<T> dataSets;

  double _yMax = -kotlinFloatMaxValue;

  /// Largest y over all sets on both axes, or -`Float.MAX_VALUE` when there is no data.
  double get yMax => _yMax;

  @protected
  set yMax(double value) => _yMax = value;

  double _yMin = kotlinFloatMaxValue;

  /// Smallest y over all sets on both axes, or `Float.MAX_VALUE` when there is no data.
  double get yMin => _yMin;

  @protected
  set yMin(double value) => _yMin = value;

  double _xMax = -kotlinFloatMaxValue;

  /// Largest x over all sets, or -`Float.MAX_VALUE` when there is no data.
  double get xMax => _xMax;

  @protected
  set xMax(double value) => _xMax = value;

  double _xMin = kotlinFloatMaxValue;

  /// Smallest x over all sets, or `Float.MAX_VALUE` when there is no data.
  double get xMin => _xMin;

  @protected
  set xMin(double value) => _xMin = value;

  /// Largest y over the sets on the left axis, or -`Float.MAX_VALUE` when there are none.
  @protected
  double leftAxisMax = -kotlinFloatMaxValue;

  /// Smallest y over the sets on the left axis, or `Float.MAX_VALUE` when there are none.
  @protected
  double leftAxisMin = kotlinFloatMaxValue;

  /// Largest y over the sets on the right axis, or -`Float.MAX_VALUE` when there are none.
  @protected
  double rightAxisMax = -kotlinFloatMaxValue;

  /// Smallest y over the sets on the right axis, or `Float.MAX_VALUE` when there are none.
  @protected
  double rightAxisMin = kotlinFloatMaxValue;

  /// Recomputes the cached ranges from the sets' own ranges. It does not ask the sets to recompute theirs,
  /// so after changing a set's entries in place call `DataSet.notifyDataSetChanged` on that set first.
  /// The chart still needs its own notify call to redraw.
  void notifyDataChanged() {
    calcMinMax();
  }

  /// Tells every set to recompute its y range from the entries between [fromX] and [toX] only, then
  /// recomputes the cached ranges. Used by charts that auto scale the y axis to the visible x range.
  void calcMinMaxY(double fromX, double toX) {
    for (final set in dataSets) {
      set.calcMinMaxY(fromX, toX);
    }
    calcMinMax();
  }

  /// Recomputes the overall and per axis x and y ranges from the sets' cached ranges.
  @protected
  void calcMinMax() {
    yMax = -kotlinFloatMaxValue;
    yMin = kotlinFloatMaxValue;
    xMax = -kotlinFloatMaxValue;
    xMin = kotlinFloatMaxValue;

    for (final set in dataSets) {
      calcMinMaxForDataSet(set);
    }

    leftAxisMax = -kotlinFloatMaxValue;
    leftAxisMin = kotlinFloatMaxValue;
    rightAxisMax = -kotlinFloatMaxValue;
    rightAxisMin = kotlinFloatMaxValue;

    final firstLeft = getFirstLeft(dataSets);
    if (firstLeft != null) {
      leftAxisMax = firstLeft.yMax;
      leftAxisMin = firstLeft.yMin;
      for (final dataSet in dataSets) {
        if (dataSet.axisDependency == AxisDependency.LEFT) {
          if (dataSet.yMin < leftAxisMin) leftAxisMin = dataSet.yMin;
          if (dataSet.yMax > leftAxisMax) leftAxisMax = dataSet.yMax;
        }
      }
    }

    final firstRight = getFirstRight(dataSets);
    if (firstRight != null) {
      rightAxisMax = firstRight.yMax;
      rightAxisMin = firstRight.yMin;
      for (final dataSet in dataSets) {
        if (dataSet.axisDependency == AxisDependency.RIGHT) {
          if (dataSet.yMin < rightAxisMin) rightAxisMin = dataSet.yMin;
          if (dataSet.yMax > rightAxisMax) rightAxisMax = dataSet.yMax;
        }
      }
    }
  }

  /// Number of data sets.
  int get dataSetCount => dataSets.length;

  /// Returns the smallest y of the sets on [axis]. When no set uses that axis the other axis' minimum is
  /// returned, so both axes show the same range.
  double getYMin(AxisDependency axis) {
    if (axis == AxisDependency.LEFT) {
      return leftAxisMin == kotlinFloatMaxValue ? rightAxisMin : leftAxisMin;
    } else {
      return rightAxisMin == kotlinFloatMaxValue ? leftAxisMin : rightAxisMin;
    }
  }

  /// Returns the largest y of the sets on [axis]. When no set uses that axis the other axis' maximum is
  /// returned, so both axes show the same range.
  double getYMax(AxisDependency axis) {
    if (axis == AxisDependency.LEFT) {
      return leftAxisMax == -kotlinFloatMaxValue ? rightAxisMax : leftAxisMax;
    } else {
      return rightAxisMax == -kotlinFloatMaxValue ? leftAxisMax : rightAxisMax;
    }
  }

  /// Finds the first set in [dataSets] whose label equals [label] by scanning the list.
  ///
  /// [ignoreCase] is true to compare labels case insensitively. Returns the index in [dataSets], or -1 if no label
  /// matches.
  @protected
  int getDataSetIndexByLabel(List<T> dataSets, String label, bool ignoreCase) {
    for (var i = 0; i < dataSets.length; i++) {
      if (_labelEquals(label, dataSets[i].label, ignoreCase)) return i;
    }
    return -1;
  }

  /// The labels of all sets in set order.
  List<String> get dataSetLabels => [for (final it in dataSets) it.label];

  /// Returns the entry a highlight refers to: the entry in the set at [Highlight.dataSetIndex] whose x is
  /// closest to [Highlight.x] and, among equal x, whose y is closest to [Highlight.y].
  ///
  /// Returns the entry, or null when the set index is out of range or the set is empty.
  Entry? getEntryForHighlight(Highlight highlight) {
    if (highlight.dataSetIndex < 0 ||
        highlight.dataSetIndex >= dataSets.length) {
      return null;
    }
    return dataSets[highlight.dataSetIndex].getEntryForXValue(
      highlight.x,
      highlight.y,
    );
  }

  /// Returns the first set whose label equals [label] by scanning all sets.
  ///
  /// [ignoreCase] is true to compare labels case insensitively. Returns the set, or null if no label matches.
  T? getDataSetByLabel(String label, bool ignoreCase) {
    final index = getDataSetIndexByLabel(dataSets, label, ignoreCase);
    return (index < 0 || index >= dataSets.length) ? null : dataSets[index];
  }

  /// Returns the set at [index], or null when the index is out of range.
  T? getDataSetByIndex(int index) {
    if (index < 0 || index >= dataSets.length) return null;
    return dataSets[index];
  }

  /// Appends [d] and widens the cached ranges to include it. Does nothing for null.
  void addDataSet(T? d) {
    if (d == null) return;
    calcMinMaxForDataSet(d);
    dataSets.add(d);
  }

  /// Removes [d] and recomputes the cached ranges if it was found.
  ///
  /// Returns true if the set was removed, false for null or a set that is not part of this data.
  bool removeDataSet(T? d) {
    if (d == null) return false;
    final removed = dataSets.remove(d);
    if (removed) notifyDataChanged();
    return removed;
  }

  /// Removes the set at [index] and recomputes the cached ranges.
  ///
  /// Returns true if a set was removed, false when the index is out of range. Kotlin's `removeDataSet(index: Int)`
  /// overload.
  bool removeDataSetByIndex(int index) {
    if (index >= dataSets.length || index < 0) return false;
    return removeDataSet(dataSets[index]);
  }

  /// Appends [e] to the set at [dataSetIndex] with [IDataSet.addEntry] and widens the cached ranges to
  /// include that set's ranges. An index out of range only logs an error.
  ///
  /// [e] must be an entry of the set's entry type (for a `LineDataSet<D>`, an `Entry<D>`), otherwise Dart throws a
  /// [TypeError] where Kotlin's unchecked cast let it through.
  void addEntry(Entry e, int dataSetIndex) {
    if (dataSets.length > dataSetIndex && dataSetIndex >= 0) {
      final set = dataSets[dataSetIndex];
      if (!set.addEntry(e)) return;
      calcMinMaxForDataSet(dataSets[dataSetIndex]);
    } else {
      debugPrint(
        'addEntry: Cannot add Entry<*> because dataSetIndex too high or too low.',
      );
    }
  }

  /// Widens the overall ranges and the ranges of [axis] to include [e].
  ///
  /// [axis] is the y axis the entry's set belongs to. Kotlin's protected `calcMinMax(e: Entry, axis)` overload.
  @protected
  void calcMinMaxForEntry(Entry e, AxisDependency axis) {
    if (yMax < e.y) yMax = e.y;
    if (yMin > e.y) yMin = e.y;
    if (xMax < e.x) xMax = e.x;
    if (xMin > e.x) xMin = e.x;

    if (axis == AxisDependency.LEFT) {
      if (leftAxisMax < e.y) leftAxisMax = e.y;
      if (leftAxisMin > e.y) leftAxisMin = e.y;
    } else {
      if (rightAxisMax < e.y) rightAxisMax = e.y;
      if (rightAxisMin > e.y) rightAxisMin = e.y;
    }
  }

  /// Widens the overall ranges and the ranges of the set's axis to include the cached ranges of [d].
  ///
  /// Kotlin's protected `calcMinMax(d: T)` overload.
  @protected
  void calcMinMaxForDataSet(T d) {
    if (yMax < d.yMax) yMax = d.yMax;
    if (yMin > d.yMin) yMin = d.yMin;
    if (xMax < d.xMax) xMax = d.xMax;
    if (xMin > d.xMin) xMin = d.xMin;

    if (d.axisDependency == AxisDependency.LEFT) {
      if (leftAxisMax < d.yMax) leftAxisMax = d.yMax;
      if (leftAxisMin > d.yMin) leftAxisMin = d.yMin;
    } else {
      if (rightAxisMax < d.yMax) rightAxisMax = d.yMax;
      if (rightAxisMin > d.yMin) rightAxisMin = d.yMin;
    }
  }

  /// Removes [e] from the set at [dataSetIndex] and recomputes the cached ranges if it was found.
  ///
  /// Returns true if the entry was removed, false for null or an index outside the sets.
  bool removeEntry(Entry? e, int dataSetIndex) {
    if (e == null || dataSetIndex < 0 || dataSetIndex >= dataSets.length) {
      return false;
    }
    final set = dataSets[dataSetIndex];
    final removed = set.removeEntry(e);
    if (removed) notifyDataChanged();
    return removed;
  }

  /// Removes the entry whose x is closest to [xValue] (not necessarily an exact match) from the set at
  /// [dataSetIndex] and recomputes the cached ranges.
  ///
  /// Returns true if an entry was removed, false for an empty set or an index outside the sets. Kotlin's
  /// `removeEntry(xValue: Float, dataSetIndex: Int)` overload.
  bool removeEntryByXValue(double xValue, int dataSetIndex) {
    if (dataSetIndex < 0 || dataSetIndex >= dataSets.length) return false;
    final e = dataSets[dataSetIndex].getEntryForXValue(xValue, double.nan);
    if (e == null) return false;
    return removeEntry(e, dataSetIndex);
  }

  /// Finds the set that holds an entry matching [e] by x, y and payload (see [Entry.equalTo]).
  ///
  /// Returns the set, or null for a null entry or when no set contains a match.
  T? getDataSetForEntry(Entry? e) {
    if (e == null) return null;
    for (final set in dataSets) {
      if (e.equalTo(set.getEntryForXValue(e.x, e.y))) return set;
    }
    return null;
  }

  /// The colors of all sets, set by set, in one list.
  List<Color> get colors => [for (final it in dataSets) ...it.colors];

  /// Returns the index of [dataSet] in [dataSets], or -1 if it is not part of this data.
  int getIndexOfDataSet(T dataSet) => dataSets.indexOf(dataSet);

  /// Returns the first of [sets] that is plotted against the left y axis, or null if there is none.
  @protected
  T? getFirstLeft(List<T> sets) {
    for (final it in sets) {
      if (it.axisDependency == AxisDependency.LEFT) return it;
    }
    return null;
  }

  /// Returns the first of [sets] that is plotted against the right y axis, or null if there is none.
  T? getFirstRight(List<T> sets) {
    for (final it in sets) {
      if (it.axisDependency == AxisDependency.RIGHT) return it;
    }
    return null;
  }

  /// Assigns [f] as the value label formatter of every set.
  void setValueFormatter(IValueFormatter f) {
    for (final set in dataSets) {
      set.valueFormatter = f;
    }
  }

  /// Assigns [color] as the only value label color of every set.
  void setValueTextColor(Color color) {
    for (final set in dataSets) {
      set.valueTextColor = color;
    }
  }

  /// Assigns the same list of value label colors to every set.
  void setValueTextColors(List<Color> colors) {
    for (final set in dataSets) {
      set.valueTextColors = colors;
    }
  }

  /// Assigns [tf] as the value label typeface of every set; null uses the default typeface.
  void setValueTypeface(Typeface? tf) {
    for (final set in dataSets) {
      set.valueTypeface = tf;
    }
  }

  /// Assigns [size] in dp as the value label text size of every set.
  void setValueTextSize(double size) {
    for (final set in dataSets) {
      set.valueTextSize = size;
    }
  }

  /// Turns value labels on or off for every set.
  void setDrawValues(bool enabled) {
    for (final set in dataSets) {
      set.isDrawValuesEnabled = enabled;
    }
  }

  /// True when every set allows highlighting by touch or code (also true with no sets).
  /// Assigning applies the value to every set.
  bool get isHighlightEnabled => dataSets.every((it) => it.isHighlightEnabled);

  set isHighlightEnabled(bool value) {
    for (final set in dataSets) {
      set.isHighlightEnabled = value;
    }
  }

  /// Removes all sets and resets the cached ranges.
  void clearValues() {
    dataSets.clear();
    notifyDataChanged();
  }

  /// Returns true if [dataSet] is one of the sets, compared with `==`.
  bool contains(T dataSet) => dataSets.any((it) => it == dataSet);

  /// Total number of entries over all sets.
  int get entryCount {
    var count = 0;
    for (final it in dataSets) {
      count += it.entryCount;
    }
    return count;
  }

  /// The set with the most entries (the first of them on a tie), or null when there are no sets.
  T? get maxEntryCountSet {
    if (dataSets.isEmpty) return null;
    var max = dataSets[0];
    for (var i = 1; i < dataSets.length; i++) {
      final set = dataSets[i];
      if (set.entryCount > max.entryCount) max = set;
    }
    return max;
  }
}

/// Kotlin `String.equals(other, ignoreCase)`.
bool _labelEquals(String a, String b, bool ignoreCase) {
  if (!ignoreCase) return a == b;
  return a.toLowerCase() == b.toLowerCase();
}
