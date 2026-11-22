// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/DataSet.kt
import 'package:flutter/foundation.dart' show protected;

import '../utils/float_math.dart';
import 'base_data_set.dart';
import 'entry.dart';

/// A group of entries that belong together, for example one line in a line chart or one group of bars.
/// Holds the entries and caches their x and y ranges. Entries must be sorted by x ascending for the x value
/// lookups ([getEntryForXValue], [getEntryIndex], [getEntriesForXValue]) to work. Looking an entry up by the
/// entry itself works either way; sorted entries only make it faster.
///
/// [T] is the entry type this set holds. Kotlin's protected overloads `calcMinMax(e)` and `calcMinMaxY(e)` are
/// [calcMinMaxForEntry] and [calcMinMaxYForEntry] (Dart has no overloading).
abstract class DataSet<T extends Entry> extends BaseDataSet<T> {
  /// Creates a set holding [entries] (kept by reference, see [entries]) named [label], shown in the legend.
  DataSet(List<T> entries, super.label) : _entries = entries {
    calcMinMax();
  }

  List<T> _entries;

  /// The entries of this set. The list is kept by reference, so the caller can keep changing it; it must be growable
  /// for [addEntry] and friends to work. Assigning recomputes the cached ranges; after changing the list in place
  /// call [notifyDataSetChanged] yourself.
  ///
  /// Kotlin keeps an `ArrayList` by reference and copies any other list; Dart lists cannot be told apart that way,
  /// so every list is kept.
  List<T> get entries => _entries;

  set entries(List<T> value) {
    _entries = value;
    notifyDataSetChanged();
  }

  double _yMax = -kotlinFloatMaxValue;

  /// Largest y over the entries, or -`Float.MAX_VALUE` when empty. Refreshed by [calcMinMax] and [calcMinMaxY].
  @override
  double get yMax => _yMax;

  @protected
  set yMax(double value) => _yMax = value;

  double _yMin = kotlinFloatMaxValue;

  /// Smallest y over the entries, or `Float.MAX_VALUE` when empty. Refreshed by [calcMinMax] and [calcMinMaxY].
  @override
  double get yMin => _yMin;

  @protected
  set yMin(double value) => _yMin = value;

  double _xMax = -kotlinFloatMaxValue;

  /// Largest x over the entries, or -`Float.MAX_VALUE` when empty. Refreshed by [calcMinMax].
  @override
  double get xMax => _xMax;

  @protected
  set xMax(double value) => _xMax = value;

  double _xMin = kotlinFloatMaxValue;

  /// Smallest x over the entries, or `Float.MAX_VALUE` when empty. Refreshed by [calcMinMax].
  @override
  double get xMin => _xMin;

  @protected
  set xMin(double value) => _xMin = value;

  bool _hasNonFiniteY = false;

  /// True when any entry's y is not a finite number, so a renderer knows the line may need a gap. Set while the
  /// entries are walked, and only cleared by a full [calcMinMax]; removing the offending entry without one leaves
  /// it true, which costs a check rather than a wrong drawing.
  @override
  bool get hasNonFiniteY => _hasNonFiniteY;

  @protected
  set hasNonFiniteY(bool value) => _hasNonFiniteY = value;

  /// Recomputes [xMin], [xMax], [yMin] and [yMax] from all entries.
  @override
  void calcMinMax() {
    hasNonFiniteY = false;
    yMax = -kotlinFloatMaxValue;
    yMin = kotlinFloatMaxValue;
    xMax = -kotlinFloatMaxValue;
    xMin = kotlinFloatMaxValue;

    if (entries.isEmpty) return;

    for (final e in entries) {
      calcMinMaxForEntry(e);
    }
  }

  /// Recomputes only [yMin] and [yMax] from the entries between [fromX] and [toX], used by charts that
  /// auto scale the y axis to the visible x range. The x range is left untouched. With no entries in the
  /// range the y range is reset to its empty values.
  ///
  /// [fromX] is the first x value to include and rounds down to the nearest entry; [toX] is the last x value to
  /// include and rounds up to the nearest entry.
  @override
  void calcMinMaxY(double fromX, double toX) {
    yMax = -kotlinFloatMaxValue;
    yMin = kotlinFloatMaxValue;

    if (entries.isEmpty) return;

    final indexFrom = getEntryIndex(fromX, double.nan, Rounding.DOWN);
    final indexTo = getEntryIndex(toX, double.nan, Rounding.UP);

    if (indexFrom < 0 || indexTo < indexFrom) return;

    for (var i = indexFrom; i <= indexTo; i++) {
      calcMinMaxYForEntry(entries[i]);
    }
  }

  /// Widens the cached x and y ranges to include [e].
  ///
  /// Kotlin's protected `calcMinMax(e: T)` overload.
  @protected
  void calcMinMaxForEntry(T e) {
    calcMinMaxX(e);
    calcMinMaxYForEntry(e);
  }

  /// Widens [xMin] and [xMax] to include the x of [e].
  @protected
  void calcMinMaxX(T e) {
    if (e.x < xMin) xMin = e.x;
    if (e.x > xMax) xMax = e.x;
  }

  /// Widens [yMin] and [yMax] to include the y of [e]; a NaN or infinite y is left out.
  ///
  /// Kotlin's protected `calcMinMaxY(e: T)` overload.
  @protected
  void calcMinMaxYForEntry(T e) {
    if (!e.y.isFinite) {
      hasNonFiniteY = true;
      return;
    }
    if (e.y < yMin) yMin = e.y;
    if (e.y > yMax) yMax = e.y;
  }

  @override
  int get entryCount => entries.length;

  /// Returns a deep copy: the entries are copied with [Entry.copy], the styling as in [BaseDataSet.copyTo].
  DataSet<T> copy();

  /// Copies the styling from this set into [dataSet]; entries are not copied here.
  @override
  @protected
  void copyTo(covariant DataSet dataSet) {
    super.copyTo(dataSet);
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(toSimpleString());
    for (final entry in entries) {
      buffer
        ..write(entry.toString())
        ..write(' ');
    }
    return buffer.toString();
  }

  /// Returns the label and the entry count in one line, without listing the entries.
  String toSimpleString() =>
      'DataSet, label: $label, entries: ${entries.length}\n';

  /// Adds [e] so that the entries stay sorted by x: it is appended when its x is not smaller than the last
  /// entry's x, otherwise inserted before the first entry with a larger x. The cached ranges are widened to
  /// include [e] without a full recalculation.
  @override
  void addEntryOrdered(T e) {
    calcMinMaxForEntry(e);

    if (entries.isNotEmpty && entries[entries.length - 1].x > e.x) {
      var closestIndex = getEntryIndex(e.x, e.y, Rounding.UP);
      if (closestIndex < 0) closestIndex = 0;
      entries.insert(closestIndex, e);
    } else {
      entries.add(e);
    }
  }

  /// Removes all entries and resets the cached ranges.
  @override
  void clear() {
    entries.clear();
    notifyDataSetChanged();
  }

  /// Appends [e] to the end without checking the x order; use [addEntryOrdered] to keep the entries sorted.
  /// The cached ranges are widened to include [e].
  ///
  /// Returns always true.
  @override
  bool addEntry(T e) {
    calcMinMaxForEntry(e);
    entries.add(e);
    return true;
  }

  /// Removes [e], matched with `==` (identity for [Entry]), and recomputes the ranges if it was found.
  ///
  /// Returns true if the entry was removed.
  @override
  bool removeEntry(T e) {
    final removed = entries.remove(e);
    if (removed) calcMinMax();
    return removed;
  }

  /// Returns the index of [e] in the entries, or -1 when the set does not hold it. Matching is by identity, so an
  /// entry with the same x and y as [e] but built separately is not a match.
  ///
  /// While the entries are sorted by x ascending, a binary search finds [e] by its x and the entries sharing that
  /// x are then searched for [e] itself. A set sorted differently falls back to walking all entries, which is
  /// slower but still returns the right index.
  ///
  /// Kotlin's `getEntryIndex(e: Entry)` overload.
  @override
  int getEntryIndexOf(Entry e) {
    final sorted = _indexOfEntrySortedByX(e);
    if (sorted >= 0) return sorted;

    for (var i = 0; i < entries.length; i++) {
      if (identical(entries[i], e)) return i;
    }
    return -1;
  }

  /// Returns the index of [e] found through the x order of the entries, or -1 when that order does not lead to it.
  int _indexOfEntrySortedByX(Entry e) {
    final x = e.x;
    var low = 0;
    var high = entries.length - 1;

    while (low <= high) {
      final middle = (low + high) >> 1;
      final middleX = entries[middle].x;

      if (middleX < x) {
        low = middle + 1;
      } else if (middleX > x) {
        high = middle - 1;
      } else {
        if (identical(entries[middle], e)) return middle;

        var i = middle - 1;
        while (i >= 0 && entries[i].x == x) {
          if (identical(entries[i], e)) return i;
          i--;
        }

        i = middle + 1;
        while (i < entries.length && entries[i].x == x) {
          if (identical(entries[i], e)) return i;
          i++;
        }
        return -1;
      }
    }

    return -1;
  }

  /// Returns the entry at the index found by [getEntryIndex] with the same arguments, or null when the set
  /// is empty. The x need not match exactly; see [getEntryIndex].
  @override
  T? getEntryForXValue(
    double xValue, [
    double closestToY = double.nan,
    Rounding rounding = Rounding.CLOSEST,
  ]) {
    final index = getEntryIndex(xValue, closestToY, rounding);
    return index > -1 ? entries[index] : null;
  }

  /// Returns the entry at [index].
  ///
  /// Throws a [RangeError] when [index] is not a valid entry index.
  @override
  T getEntryForIndex(int index) => entries[index];

  /// Finds the index of the entry nearest to [xValue] by binary search; the entries must be sorted by x.
  /// When two entries are equally close, the one with the larger x is taken.
  ///
  /// [xValue] is the x value to look for, in value space. [closestToY]: when not NaN and several entries share the
  /// found x, the one whose y is closest to this value is returned; NaN takes the first of them. [rounding]:
  /// [Rounding.CLOSEST] takes the nearest entry. [Rounding.UP] moves one entry up when the nearest x is below
  /// [xValue] (unless it is the last entry), [Rounding.DOWN] moves one entry down when the nearest x is above
  /// [xValue] (unless it is the first entry). Returns the entry index, or -1 when the set is empty or [xValue] is
  /// NaN.
  @override
  int getEntryIndex(
    double xValue, [
    double closestToY = double.nan,
    Rounding rounding = Rounding.CLOSEST,
  ]) {
    if (entries.isEmpty || xValue.isNaN) return -1;

    var low = 0;
    var high = entries.length - 1;
    var closest = high;

    while (low < high) {
      final m = (low + high) ~/ 2;

      final d1 = entries[m].x - xValue;
      final d2 = entries[m + 1].x - xValue;
      final ad1 = d1.abs();
      final ad2 = d2.abs();

      if (ad2 < ad1) {
        low = m + 1;
      } else if (ad1 < ad2) {
        high = m;
      } else if (d1 >= 0.0) {
        high = m;
      } else {
        // also taken when d1 is NaN, so the search always narrows
        low = m + 1;
      }
      closest = high;
    }

    final closestXValue = entries[closest].x;
    if (rounding == Rounding.UP) {
      if (closestXValue < xValue && closest < entries.length - 1) {
        ++closest;
      }
    } else if (rounding == Rounding.DOWN) {
      if (closestXValue > xValue && closest > 0) {
        --closest;
      }
    }

    if (!closestToY.isNaN) {
      while (closest > 0 && entries[closest - 1].x == closestXValue) {
        closest -= 1;
      }

      var closestYValue = entries[closest].y;
      var closestYIndex = closest;

      while (true) {
        closest += 1;
        if (closest >= entries.length) break;

        final value = entries[closest];
        if (value.x != closestXValue) break;

        if ((value.y - closestToY).abs() <=
            (closestYValue - closestToY).abs()) {
          closestYValue = value.y;
          closestYIndex = closest;
        }
      }
      closest = closestYIndex;
    }

    return closest;
  }

  /// Returns all entries whose x equals [xValue] exactly, in list order, found by binary search over the
  /// x sorted entries. Empty when there is no exact match.
  @override
  List<T> getEntriesForXValue(double xValue) {
    final result = <T>[];

    var low = 0;
    var high = entries.length - 1;

    while (low <= high) {
      var m = (high + low) ~/ 2;
      var entry = entries[m];

      if (xValue == entry.x) {
        while (m > 0 && entries[m - 1].x == xValue) {
          m--;
        }

        high = entries.length;
        while (m < high) {
          entry = entries[m];
          if (entry.x == xValue) {
            result.add(entry);
          } else {
            break;
          }
          m++;
        }
        break;
      } else {
        if (xValue > entry.x) {
          low = m + 1;
        } else {
          high = m - 1;
        }
      }
    }

    return result;
  }
}

/// How [DataSet.getEntryIndex] picks an entry when no entry has exactly the requested x.
///
/// Kotlin's `DataSet.Rounding`; a top-level enum because Dart has no nested types.
enum Rounding {
  /// Prefer the entry with the next larger x.
  UP,

  /// Prefer the entry with the next smaller x.
  DOWN,

  /// Take the entry whose x is nearest.
  CLOSEST,
}
