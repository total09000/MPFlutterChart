// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/EntryIndexLookupTest.kt
//
// Kotlin's DataSet.getEntryIndex(e: Entry) is DataSet.getEntryIndexOf(e) here (Dart has no overloading).
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';

/// Counts every entry a lookup touched, including the ones a list-wide scan would walk past.
class _CountingList<T> extends ListBase<T> {
  _CountingList(this._backing);

  final List<T> _backing;

  int _reads = 0;

  int get reads => _reads;

  @override
  int get length => _backing.length;

  @override
  set length(int newLength) => _backing.length = newLength;

  @override
  T operator [](int index) {
    _reads++;
    return _backing[index];
  }

  @override
  void operator []=(int index, T value) => _backing[index] = value;

  @override
  void add(T element) => _backing.add(element);

  @override
  int indexOf(Object? element, [int start = 0]) {
    for (var i = start; i < _backing.length; i++) {
      if (this[i] == element) return i;
    }
    return -1;
  }
}

List<Entry> _sortedEntries(int n) => [
  for (var i = 0; i < n; i++) Entry(x: i.toDouble(), y: i * 2.0),
];

LineDataSet _setOf(List<Entry> entries) => LineDataSet(entries, 'line');

void main() {
  test('findsTheIndexOfAnEntryOfASortedSet', () {
    final entries = _sortedEntries(50);
    final set = _setOf(entries);

    expect(set.getEntryIndexOf(entries[0]), 0);
    expect(set.getEntryIndexOf(entries[23]), 23);
    expect(set.getEntryIndexOf(entries[49]), 49);
  });

  test('picksTheInstanceItWasGivenWhenSeveralEntriesShareAnX', () {
    final entries = [
      Entry(x: 0, y: 1),
      Entry(x: 1, y: 10),
      Entry(x: 1, y: 20),
      Entry(x: 1, y: 30),
      Entry(x: 2, y: 4),
    ];
    final set = _setOf(entries);

    expect(set.getEntryIndexOf(entries[1]), 1);
    expect(set.getEntryIndexOf(entries[2]), 2);
    expect(set.getEntryIndexOf(entries[3]), 3);
    expect(set.getEntryIndexOf(Entry(x: 1, y: 20)), -1);
  });

  test('returnsMinusOneForAnEntryThatIsNotInTheSet', () {
    final set = _setOf(_sortedEntries(20));

    expect(set.getEntryIndexOf(Entry(x: 7, y: 14)), -1);
    expect(set.getEntryIndexOf(Entry(x: 100, y: 3)), -1);
    expect(set.getEntryIndexOf(Entry(x: -5, y: 3)), -1);
  });

  test('tellsTwoEntriesWithTheSameXAndYApart', () {
    final first = Entry(x: 5, y: 9);
    final second = Entry(x: 5, y: 9);
    final set = _setOf([Entry(x: 4, y: 1), first, second, Entry(x: 6, y: 1)]);

    expect(set.getEntryIndexOf(first), 1);
    expect(set.getEntryIndexOf(second), 2);
  });

  test('findsTheIndexInASetThatIsNotSortedByX', () {
    final entries = [
      Entry(x: 9, y: 1),
      Entry(x: 2, y: 2),
      Entry(x: 7, y: 3),
      Entry(x: 0, y: 4),
      Entry(x: 4, y: 5),
    ];
    final set = _setOf(entries);

    for (var i = 0; i < entries.length; i++) {
      expect(set.getEntryIndexOf(entries[i]), i);
    }
    expect(set.getEntryIndexOf(Entry(x: 7, y: 3)), -1);
  });

  test('findsTheIndexWithoutReadingEveryEntry', () {
    final entries = _sortedEntries(100000);
    final set = _setOf(entries);
    final counting = _CountingList(entries);
    set.entries = counting;

    final wanted = entries[90000];
    final before = counting.reads;
    expect(set.getEntryIndexOf(wanted), 90000);

    final read = counting.reads - before;
    expect(
      read,
      lessThanOrEqualTo(100),
      reason: 'read $read of ${entries.length} entries to find one of them',
    );
  });
}
