// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/animation/ValueTransition.kt
//
// Internal API (Kotlin `internal class`): used by the charts' animateValue / animateDataChange, not exported from
// core.dart or mp_flutter_chart.dart.
//
// Kotlin's FloatArray values are Float64List here, not Float32List: Dart entries hold doubles, and finish() must write
// back exactly the target values (Float storage would round a y of 0.1 to 0.10000000149011612).
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show internal;

import '../data/bar_entry.dart';
import '../data/bubble_entry.dart';
import '../data/candle_entry.dart';
import '../data/chart_data.dart';
import '../data/entry.dart';
import '../interfaces/datasets/i_data_set.dart';

/// Moves the values of entries from start values to target values. The values of an entry are its y, its size for a
/// bubble, and y, high, low, open and close for a candle; a stacked bar has its stack values instead.
///
/// Internal API.
@internal
class ValueTransition {
  ValueTransition._(this._items, this.dataSets);

  final List<_Item> _items;

  /// The data sets holding the moved entries, whose ranges must be recomputed after each step.
  final List<IDataSet> dataSets;

  /// Writes the values [fraction] of the way from start to target into the entries; 0 is the start, 1 the target.
  void apply(double fraction) {
    for (final item in _items) {
      if (item.isReleased) continue;
      final values = Float64List(item.to.length);
      for (var it = 0; it < values.length; it++) {
        values[it] = item.from[it] + (item.to[it] - item.from[it]) * fraction;
      }
      _write(item.entry, values);
    }
  }

  /// Writes the exact target values, and for stacked bars the original stack list, into the entries.
  void finish() {
    for (final item in _items) {
      if (item.isReleased) continue;
      final targetStack = item.targetStack;
      if (targetStack != null) {
        (item.entry as BarEntry).stackValues = targetStack;
      } else {
        _write(item.entry, item.to);
      }
    }
  }

  /// Stops moving [entry], so that another animation can take it over.
  void release(Entry entry) {
    for (final item in _items) {
      if (identical(item.entry, entry)) item.isReleased = true;
    }
  }

  /// Pairs the entries of [newData] with those of [oldData] by data set index and entry index. Entries past the end
  /// of their old data set start at 0. Reads every value before anything is written, so the two data objects may
  /// share entries.
  ///
  /// Returns the transition, or null when the shapes differ: another data class, another number of data sets or
  /// another data set class at any index. Kotlin compares the erased classes (`::class`); Dart compares the
  /// `runtimeType`, which includes type arguments, so a `LineDataSet<Order>` and a `LineDataSet<dynamic>` count as
  /// different classes here.
  static ValueTransition? between(ChartData oldData, ChartData newData) {
    if (oldData.runtimeType != newData.runtimeType ||
        oldData.dataSetCount != newData.dataSetCount) {
      return null;
    }
    for (var i = 0; i < newData.dataSetCount; i++) {
      if (oldData.dataSets[i].runtimeType != newData.dataSets[i].runtimeType) {
        return null;
      }
    }

    final items = <_Item>[];
    for (var i = 0; i < newData.dataSetCount; i++) {
      final oldSet = oldData.dataSets[i];
      final newSet = newData.dataSets[i];
      for (var j = 0; j < newSet.entryCount; j++) {
        final target = newSet.getEntryForIndex(j);
        final old = j < oldSet.entryCount ? oldSet.getEntryForIndex(j) : null;
        final to = _valuesOf(target);
        final targetStack = target is BarEntry ? target.stackValues : null;
        items.add(
          _Item(target, _startValues(old, target, to.length), to, targetStack),
        );
      }
    }
    return ValueTransition._(items, newData.dataSets.toList());
  }

  /// Moves the y value of [entry] from its current value to [toY].
  static ValueTransition ofY(Entry entry, double toY, IDataSet dataSet) =>
      ValueTransition._(
        [
          _Item(
            entry,
            Float64List.fromList([entry.y]),
            Float64List.fromList([toY]),
            null,
          ),
        ],
        [dataSet],
      );

  static Float64List _valuesOf(Entry entry) {
    if (entry is BarEntry && entry.isStacked) {
      return Float64List.fromList(entry.stackValues ?? const <double>[]);
    }
    if (entry is CandleEntry) {
      return Float64List.fromList([
        entry.y,
        entry.high,
        entry.low,
        entry.open,
        entry.close,
      ]);
    }
    if (entry is BubbleEntry) {
      return Float64List.fromList([entry.y, entry.size]);
    }
    return Float64List.fromList([entry.y]);
  }

  static Float64List _startValues(Entry? old, Entry target, int size) {
    if (old == null) return Float64List(size);
    if (target is BarEntry && target.isStacked) {
      final values = _valuesOf(old);
      final start = Float64List(size);
      for (var it = 0; it < size; it++) {
        start[it] = it < values.length ? values[it] : 0;
      }
      return start;
    }
    final values = old is BarEntry && old.isStacked
        ? Float64List.fromList([old.y])
        : _valuesOf(old);
    if (values.length == size) return values;
    final start = Float64List(size);
    for (var it = 0; it < size; it++) {
      start[it] = old.y;
    }
    return start;
  }

  /// Writes [values] as read by [_valuesOf]; an array holding only y leaves the other values alone.
  static void _write(Entry entry, Float64List values) {
    if (entry is BarEntry && entry.isStacked) {
      // A Float64List is a fixed-length List<double>, as Kotlin's FloatArray.asList() is.
      entry.stackValues = values;
      return;
    }
    entry.y = values[0];
    if (values.length == 1) return;
    if (entry is CandleEntry) {
      entry.high = values[1];
      entry.low = values[2];
      entry.open = values[3];
      entry.close = values[4];
    } else if (entry is BubbleEntry) {
      entry.size = values[1];
    }
  }
}

class _Item {
  _Item(this.entry, this.from, this.to, this.targetStack);

  final Entry entry;
  final Float64List from;
  final Float64List to;
  final List<double>? targetStack;
  bool isReleased = false;
}
