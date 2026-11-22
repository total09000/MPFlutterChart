// Not a port of a Kotlin test (task brief): MPAndroidChart has no unit test for BarBuffer.kt / AbstractBuffer.kt,
// only the device test BarBufferReuseTest.kt (ported with the bar chart). Locks the rectangles the buffer writes in
// value space for plain, inverted, phased and stacked bars, the padding of short stacks, the indexed feed with its
// widened bars, and the range feed's clamping.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/buffer/bar_buffer.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';

/// The rectangle at [bar] (left, top, right, bottom), counted from the start of the buffer.
List<double> _rect(BarBuffer buffer, int bar) =>
    buffer.buffer.sublist(bar * 4, bar * 4 + 4);

/// A buffer sized for every bar of [set], as the bar renderer sizes it.
BarBuffer _bufferFor(BarDataSet set, {bool containsStacks = false}) =>
    BarBuffer(
      set.entryCount * 4 * (set.isStacked ? set.stackSize : 1),
      1,
      containsStacks,
    );

void main() {
  group('AbstractBuffer', () {
    test('size is the number of floats in the buffer', () {
      final buffer = BarBuffer(12, 1, false);
      expect(buffer.size, 12);
      expect(buffer.buffer, hasLength(12));
    });
  });

  group('feed of plain bars', () {
    test('a positive bar spans x ± barWidth / 2 from its value down to 0', () {
      final set = BarDataSet([BarEntry(x: 2, y: 5)], '');
      final buffer = _bufferFor(set)..barWidth = 0.5;
      buffer.feed(set);
      expect(_rect(buffer, 0), [1.75, 5, 2.25, 0]);
      expect(buffer.filledSize, 4);
      expect(buffer.barsPerEntry, 1);
      expect(buffer.firstEntry, 0);
    });

    test('a negative bar spans from 0 down to its value', () {
      final set = BarDataSet([BarEntry(x: 2, y: -3)], '');
      final buffer = _bufferFor(set)..barWidth = 0.5;
      buffer.feed(set);
      expect(_rect(buffer, 0), [1.75, 0, 2.25, -3]);
    });

    test('an inverted axis swaps top and bottom', () {
      final set = BarDataSet([BarEntry(x: 2, y: 5), BarEntry(x: 3, y: -3)], '');
      final buffer = _bufferFor(set)
        ..barWidth = 0.5
        ..isInverted = true;
      buffer.feed(set);
      expect(_rect(buffer, 0), [1.75, 0, 2.25, 5]);
      expect(_rect(buffer, 1), [2.75, -3, 3.25, 0]);
    });

    test('the y phase scales only the edge away from 0', () {
      final set = BarDataSet([BarEntry(x: 2, y: 5), BarEntry(x: 3, y: -3)], '');
      final buffer = _bufferFor(set)..barWidth = 0.5;
      buffer.setPhases(1, 0.5);
      buffer.feed(set);
      expect(_rect(buffer, 0), [1.75, 2.5, 2.25, 0]);
      expect(_rect(buffer, 1), [2.75, 0, 3.25, -1.5]);
    });

    test('on an inverted axis the y phase scales the bottom edge only', () {
      // As in Kotlin: `if (top > 0) top *= phaseY else bottom *= phaseY` runs after the inverted swap, so a positive
      // bar (value in bottom) is scaled but a negative one (value in top) keeps its full height.
      final set = BarDataSet([BarEntry(x: 2, y: 5), BarEntry(x: 3, y: -3)], '');
      final buffer = _bufferFor(set)
        ..barWidth = 0.5
        ..isInverted = true;
      buffer.setPhases(1, 0.5);
      buffer.feed(set);
      expect(_rect(buffer, 0), [1.75, 0, 2.25, 2.5]);
      expect(_rect(buffer, 1), [2.75, -3, 3.25, 0]);
    });

    test(
      'a buffer without stacks draws a stacked entry as one bar of its sum',
      () {
        final set = BarDataSet([
          BarEntry.stacked(x: 1, stackValues: [2, -3, 5]),
        ], '');
        final buffer = BarBuffer(set.entryCount * 4, 1, false);
        buffer.feed(set);
        expect(buffer.barsPerEntry, 1);
        expect(buffer.filledSize, 4);
        expect(_rect(buffer, 0), [0.5, 4, 1.5, 0]);
      },
    );
  });

  group('feed of stacked bars', () {
    test(
      'each stack value gets its own rectangle, positives upwards and negatives downwards from 0',
      () {
        final set = BarDataSet([
          BarEntry.stacked(x: 1, stackValues: [2, -3, 5]),
        ], '');
        expect(set.stackSize, 3);
        final buffer = _bufferFor(set, containsStacks: true);
        buffer.feed(set);
        expect(buffer.barsPerEntry, 3);
        expect(buffer.filledSize, 12);
        expect(_rect(buffer, 0), [0.5, 2, 1.5, 0]);
        expect(_rect(buffer, 1), [0.5, 0, 1.5, -3]);
        expect(_rect(buffer, 2), [0.5, 7, 1.5, 2]);
      },
    );

    test('an inverted axis and the y phase apply to every stack rectangle', () {
      final set = BarDataSet([
        BarEntry.stacked(x: 1, stackValues: [2, -3, 5]),
      ], '');
      final buffer = _bufferFor(set, containsStacks: true)..isInverted = true;
      buffer.setPhases(1, 0.5);
      buffer.feed(set);
      expect(_rect(buffer, 0), [0.5, 0, 1.5, 1]);
      expect(_rect(buffer, 1), [0.5, -1.5, 1.5, 0]);
      expect(_rect(buffer, 2), [0.5, 1, 1.5, 3.5]);
    });

    test(
      'a zero value at the base of the stack is a rectangle without height at 0',
      () {
        final set = BarDataSet([
          BarEntry.stacked(x: 1, stackValues: [0, 3]),
        ], '');
        final buffer = _bufferFor(set, containsStacks: true);
        buffer.feed(set);
        expect(_rect(buffer, 0), [0.5, 0, 1.5, 0]);
        expect(_rect(buffer, 1), [0.5, 3, 1.5, 0]);
      },
    );

    test(
      'a short stack is padded with rectangles without width up to barsPerEntry',
      () {
        final set = BarDataSet([
          BarEntry.stacked(x: 0, stackValues: [1, 2, 3]),
          BarEntry.stacked(x: 1, stackValues: [4, 5]),
        ], '');
        final buffer = _bufferFor(set, containsStacks: true);
        buffer.feed(set);
        expect(buffer.barsPerEntry, 3);
        expect(buffer.filledSize, 24);
        expect(_rect(buffer, 3), [0.5, 4, 1.5, 0]);
        expect(_rect(buffer, 4), [0.5, 9, 1.5, 4]);
        expect(_rect(buffer, 5), [1, 0, 1, 0]);
      },
    );

    test('a plain entry in a stacked set is padded to barsPerEntry too', () {
      final set = BarDataSet([
        BarEntry.stacked(x: 0, stackValues: [1, 2]),
        BarEntry(x: 1, y: 4),
      ], '');
      final buffer = _bufferFor(set, containsStacks: true);
      buffer.feed(set);
      expect(buffer.barsPerEntry, 2);
      expect(buffer.filledSize, 16);
      expect(_rect(buffer, 2), [0.5, 4, 1.5, 0]);
      expect(_rect(buffer, 3), [1, 0, 1, 0]);
    });
  });

  group('feedIndices', () {
    BarDataSet plainSet() => BarDataSet([
      for (var i = 0; i < 6; i++) BarEntry(x: i.toDouble(), y: i + 1.0),
    ], '');

    test(
      'feeds only the named entries and maps every rectangle back to its entry',
      () {
        final set = plainSet();
        final buffer = _bufferFor(set)..barWidth = 0.5;
        buffer.feedIndices(
          set,
          Int32List.fromList([1, 4]),
          Int32List.fromList([1, 1]),
          2,
        );
        expect(buffer.firstEntry, 1);
        expect(buffer.filledSize, 8);
        expect(buffer.entryOfBar(0), 1);
        expect(buffer.entryOfBar(1), 4);
        expect(buffer.positionOfBar(1), 4);
        expect(_rect(buffer, 0), [0.75, 2, 1.25, 0]);
        expect(_rect(buffer, 1), [3.75, 5, 4.25, 0]);
      },
    );

    test('a bar standing for several entries is widened up to columnWidth', () {
      final set = plainSet();
      final buffer = _bufferFor(set)
        ..barWidth = 0.5
        ..columnWidth = 2;
      expect(buffer.widthOfBar(1), 0.5);
      expect(buffer.widthOfBar(3), 1.5);
      expect(buffer.widthOfBar(10), 2);

      buffer.feedIndices(
        set,
        Int32List.fromList([1, 4]),
        Int32List.fromList([1, 3]),
        2,
      );
      expect(_rect(buffer, 0), [0.75, 2, 1.25, 0]);
      expect(_rect(buffer, 1), [3.25, 5, 4.75, 0]);
    });

    test('a stacked bar standing for several entries widens every stack '
        'rectangle', () {
      final set = BarDataSet([
        BarEntry.stacked(x: 1, stackValues: [1, 2]),
      ], '');
      final buffer = _bufferFor(set, containsStacks: true)
        ..barWidth = 0.5
        ..columnWidth = 2;
      buffer.feedIndices(
        set,
        Int32List.fromList([0]),
        Int32List.fromList([3]),
        1,
      );
      expect(buffer.filledSize, 8);
      // widthOfBar(3) is 1.5: both stack rectangles span x ± 0.75.
      expect(_rect(buffer, 0), [0.25, 1, 1.75, 0]);
      expect(_rect(buffer, 1), [0.25, 3, 1.75, 1]);
    });

    test('without a columnWidth a bar is never wider than barWidth', () {
      final buffer = BarBuffer(4, 1, false)..barWidth = 0.5;
      expect(buffer.columnWidth, 0);
      expect(buffer.widthOfBar(3), 0.5);
    });

    test('only the first count indices are fed', () {
      final set = plainSet();
      final buffer = _bufferFor(set);
      buffer.feedIndices(
        set,
        Int32List.fromList([1, 4, 5]),
        Int32List.fromList([1, 1, 1]),
        2,
      );
      expect(buffer.filledSize, 8);

      buffer.feedIndices(
        set,
        Int32List.fromList([3]),
        Int32List.fromList([1]),
        0,
      );
      expect(buffer.firstEntry, 0);
      expect(buffer.filledSize, 0);
    });

    test('positionOfBar counts the bars of the whole stacked set', () {
      final set = BarDataSet([
        for (var i = 0; i < 5; i++)
          BarEntry.stacked(x: i.toDouble(), stackValues: [1, 2]),
      ], '');
      final buffer = _bufferFor(set, containsStacks: true);
      buffer.feedIndices(
        set,
        Int32List.fromList([1, 3]),
        Int32List.fromList([1, 1]),
        2,
      );
      expect(buffer.barsPerEntry, 2);
      expect(buffer.filledSize, 16);
      expect(
        [for (var bar = 0; bar < 4; bar++) buffer.entryOfBar(bar)],
        [1, 1, 3, 3],
      );
      expect(
        [for (var bar = 0; bar < 4; bar++) buffer.positionOfBar(bar)],
        [2, 3, 6, 7],
      );
    });

    test('padding rectangles keep no width when the bar is widened', () {
      final set = BarDataSet([
        BarEntry.stacked(x: 0, stackValues: [1, 2]),
        BarEntry(x: 1, y: 4),
      ], '');
      final buffer = _bufferFor(set, containsStacks: true)
        ..barWidth = 0.5
        ..columnWidth = 2;
      buffer.feedIndices(
        set,
        Int32List.fromList([1]),
        Int32List.fromList([4]),
        1,
      );
      expect(_rect(buffer, 0), [0, 4, 2, 0]);
      expect(_rect(buffer, 1), [1, 0, 1, 0]);
    });

    test(
      'a later feed of more entries than before still maps every rectangle',
      () {
        final set = plainSet();
        final buffer = _bufferFor(set);
        buffer.feedIndices(
          set,
          Int32List.fromList([0, 1]),
          Int32List.fromList([1, 1]),
          2,
        );
        buffer.feedIndices(
          set,
          Int32List.fromList([0, 1, 2, 3, 5]),
          Int32List.fromList([1, 1, 1, 1, 1]),
          5,
        );
        expect(
          [for (var bar = 0; bar < 5; bar++) buffer.entryOfBar(bar)],
          [0, 1, 2, 3, 5],
        );
        buffer.feed(set);
        expect(
          [for (var bar = 0; bar < 6; bar++) buffer.entryOfBar(bar)],
          [0, 1, 2, 3, 4, 5],
        );
      },
    );
  });

  group('feedRange', () {
    BarDataSet plainSet() => BarDataSet([
      for (var i = 0; i < 4; i++) BarEntry(x: i.toDouble(), y: i + 1.0),
    ], '');

    test('clamps from and to to the entries of the set', () {
      final set = plainSet();
      final buffer = _bufferFor(set);
      buffer.feedRange(set, -5, 99);
      expect(buffer.firstEntry, 0);
      expect(buffer.filledSize, 16);
      expect(buffer.entryOfBar(3), 3);
      expect(_rect(buffer, 3), [2.5, 4, 3.5, 0]);
    });

    test(
      'feeds the entries from from to to inclusive, writing from the start of the buffer',
      () {
        final set = plainSet();
        final buffer = _bufferFor(set);
        buffer.feedRange(set, 2, 3);
        expect(buffer.firstEntry, 2);
        expect(buffer.filledSize, 8);
        expect(buffer.entryOfBar(0), 2);
        expect(_rect(buffer, 0), [1.5, 3, 2.5, 0]);
      },
    );

    test('an empty range fills nothing', () {
      final set = plainSet();
      final buffer = _bufferFor(set);
      buffer.feedRange(set, 3, 2);
      expect(buffer.filledSize, 0);
    });

    test(
      'every feed writes from the start again and leaves the rest of the buffer as it was',
      () {
        final set = plainSet();
        final buffer = _bufferFor(set);
        buffer.feed(set);
        buffer.feed(set);
        expect(buffer.filledSize, 16);
        expect(_rect(buffer, 0), [-0.5, 1, 0.5, 0]);

        buffer.feedRange(set, 3, 3);
        expect(buffer.filledSize, 4);
        expect(_rect(buffer, 0), [2.5, 4, 3.5, 0]);
        expect(_rect(buffer, 1), [0.5, 2, 1.5, 0]);
      },
    );
  });
}
