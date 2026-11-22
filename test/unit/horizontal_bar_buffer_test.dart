// Not a port of a Kotlin test: MPAndroidChart has no unit test for HorizontalBarBuffer.kt. Mirrors
// bar_buffer_test.dart with the axes swapped: left and right are y values, top and bottom are x values. Locks the
// rectangles of plain, inverted, phased and stacked bars, the padding of short stacks, and that the feeds of BarBuffer
// reach the horizontal geometry.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/buffer/bar_buffer.dart';
import 'package:mp_flutter_chart/src/buffer/horizontal_bar_buffer.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';

/// The rectangle at [bar] (left, top, right, bottom), counted from the start of the buffer.
List<double> _rect(BarBuffer buffer, int bar) =>
    buffer.buffer.sublist(bar * 4, bar * 4 + 4);

/// A buffer sized for every bar of [set], as the horizontal bar renderer sizes it.
HorizontalBarBuffer _bufferFor(BarDataSet set, {bool containsStacks = false}) =>
    HorizontalBarBuffer(
      set.entryCount * 4 * (set.isStacked ? set.stackSize : 1),
      1,
      containsStacks,
    );

void main() {
  test('a HorizontalBarBuffer is a BarBuffer', () {
    final buffer = HorizontalBarBuffer(8, 2, true);
    expect(buffer, isA<BarBuffer>());
    expect(buffer.size, 8);
    expect(buffer.containsStacks, isTrue);
  });

  group('feed of plain bars', () {
    test(
      'a positive bar spans from 0 to its value, x ± barWidth / 2 from bottom to top',
      () {
        final set = BarDataSet([BarEntry(x: 2, y: 5)], '');
        final buffer = _bufferFor(set)..barWidth = 0.5;
        buffer.feed(set);
        expect(_rect(buffer, 0), [0, 2.25, 5, 1.75]);
        expect(buffer.filledSize, 4);
        expect(buffer.barsPerEntry, 1);
      },
    );

    test('a negative bar spans from its value to 0', () {
      final set = BarDataSet([BarEntry(x: 2, y: -3)], '');
      final buffer = _bufferFor(set)..barWidth = 0.5;
      buffer.feed(set);
      expect(_rect(buffer, 0), [-3, 2.25, 0, 1.75]);
    });

    test('an inverted axis swaps left and right', () {
      final set = BarDataSet([BarEntry(x: 2, y: 5), BarEntry(x: 3, y: -3)], '');
      final buffer = _bufferFor(set)
        ..barWidth = 0.5
        ..isInverted = true;
      buffer.feed(set);
      expect(_rect(buffer, 0), [5, 2.25, 0, 1.75]);
      expect(_rect(buffer, 1), [0, 3.25, -3, 2.75]);
    });

    test('the y phase scales only the edge away from 0', () {
      final set = BarDataSet([BarEntry(x: 2, y: 5), BarEntry(x: 3, y: -3)], '');
      final buffer = _bufferFor(set)..barWidth = 0.5;
      buffer.setPhases(1, 0.5);
      buffer.feed(set);
      expect(_rect(buffer, 0), [0, 2.25, 2.5, 1.75]);
      expect(_rect(buffer, 1), [-1.5, 3.25, 0, 2.75]);
    });

    test('on an inverted axis the y phase scales the left edge only', () {
      // As in Kotlin: `if (right > 0) right *= phaseY else left *= phaseY` runs after the inverted swap, so a positive
      // bar (value in left) is scaled but a negative one (value in right) keeps its full length.
      final set = BarDataSet([BarEntry(x: 2, y: 5), BarEntry(x: 3, y: -3)], '');
      final buffer = _bufferFor(set)
        ..barWidth = 0.5
        ..isInverted = true;
      buffer.setPhases(1, 0.5);
      buffer.feed(set);
      expect(_rect(buffer, 0), [2.5, 2.25, 0, 1.75]);
      expect(_rect(buffer, 1), [0, 3.25, -3, 2.75]);
    });

    test(
      'a buffer without stacks draws a stacked entry as one bar of its sum',
      () {
        final set = BarDataSet([
          BarEntry.stacked(x: 1, stackValues: [2, -3, 5]),
        ], '');
        final buffer = HorizontalBarBuffer(set.entryCount * 4, 1, false);
        buffer.feed(set);
        expect(buffer.barsPerEntry, 1);
        expect(buffer.filledSize, 4);
        expect(_rect(buffer, 0), [0, 1.5, 4, 0.5]);
      },
    );
  });

  group('feed of stacked bars', () {
    test(
      'each stack value gets its own rectangle, positives rightwards and negatives leftwards from 0',
      () {
        final set = BarDataSet([
          BarEntry.stacked(x: 1, stackValues: [2, -3, 5]),
        ], '');
        final buffer = _bufferFor(set, containsStacks: true);
        buffer.feed(set);
        expect(buffer.barsPerEntry, 3);
        expect(buffer.filledSize, 12);
        expect(_rect(buffer, 0), [0, 1.5, 2, 0.5]);
        expect(_rect(buffer, 1), [-3, 1.5, 0, 0.5]);
        expect(_rect(buffer, 2), [2, 1.5, 7, 0.5]);
      },
    );

    test('an inverted axis and the y phase apply to every stack rectangle', () {
      final set = BarDataSet([
        BarEntry.stacked(x: 1, stackValues: [2, -3, 5]),
      ], '');
      final buffer = _bufferFor(set, containsStacks: true)..isInverted = true;
      buffer.setPhases(1, 0.5);
      buffer.feed(set);
      expect(_rect(buffer, 0), [1, 1.5, 0, 0.5]);
      expect(_rect(buffer, 1), [0, 1.5, -1.5, 0.5]);
      expect(_rect(buffer, 2), [3.5, 1.5, 1, 0.5]);
    });

    test(
      'a zero value at the base of the stack is a rectangle without length at 0',
      () {
        final set = BarDataSet([
          BarEntry.stacked(x: 1, stackValues: [0, 3]),
        ], '');
        final buffer = _bufferFor(set, containsStacks: true);
        buffer.feed(set);
        expect(_rect(buffer, 0), [0, 1.5, 0, 0.5]);
        expect(_rect(buffer, 1), [0, 1.5, 3, 0.5]);
      },
    );

    test(
      'a short stack is padded with rectangles without height up to barsPerEntry',
      () {
        final set = BarDataSet([
          BarEntry.stacked(x: 0, stackValues: [1, 2, 3]),
          BarEntry.stacked(x: 1, stackValues: [4, 5]),
        ], '');
        final buffer = _bufferFor(set, containsStacks: true);
        buffer.feed(set);
        expect(buffer.barsPerEntry, 3);
        expect(buffer.filledSize, 24);
        expect(_rect(buffer, 3), [0, 1.5, 4, 0.5]);
        expect(_rect(buffer, 4), [4, 1.5, 9, 0.5]);
        expect(_rect(buffer, 5), [0, 1, 0, 1]);
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
      expect(_rect(buffer, 2), [0, 1.5, 4, 0.5]);
      expect(_rect(buffer, 3), [0, 1, 0, 1]);
    });

    test(
      'a stack that grew after the set was built writes no more than barsPerEntry rectangles',
      () {
        final entry = BarEntry.stacked(x: 0, stackValues: [1, 2]);
        final set = BarDataSet([entry], '');
        entry.stackValues = [1, 2, 3, 4];
        final buffer = HorizontalBarBuffer(
          set.entryCount * 4 * set.stackSize,
          1,
          true,
        );
        buffer.feed(set);
        expect(buffer.filledSize, 8);
        expect(_rect(buffer, 0), [0, 0.5, 1, -0.5]);
        expect(_rect(buffer, 1), [1, 0.5, 3, -0.5]);
      },
    );
  });

  group('the feeds of BarBuffer reach the horizontal geometry', () {
    BarDataSet plainSet() => BarDataSet([
      for (var i = 0; i < 6; i++) BarEntry(x: i.toDouble(), y: i + 1.0),
    ], '');

    test('feedIndices widens a bar standing for several entries along x', () {
      final set = plainSet();
      final buffer = _bufferFor(set)
        ..barWidth = 0.5
        ..columnWidth = 2;
      buffer.feedIndices(
        set,
        Int32List.fromList([1, 4]),
        Int32List.fromList([1, 3]),
        2,
      );
      expect(buffer.firstEntry, 1);
      expect(buffer.filledSize, 8);
      expect(buffer.entryOfBar(1), 4);
      expect(_rect(buffer, 0), [0, 1.25, 2, 0.75]);
      expect(_rect(buffer, 1), [0, 4.75, 5, 3.25]);
    });

    test('padding rectangles keep no height when the bar is widened', () {
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
      expect(_rect(buffer, 0), [0, 2, 4, 0]);
      expect(_rect(buffer, 1), [0, 1, 0, 1]);
    });

    test('feedRange feeds the entries from from to to inclusive', () {
      final set = plainSet();
      final buffer = _bufferFor(set);
      buffer.feedRange(set, 2, 3);
      expect(buffer.firstEntry, 2);
      expect(buffer.filledSize, 8);
      expect(_rect(buffer, 0), [0, 2.5, 3, 1.5]);
      expect(_rect(buffer, 1), [0, 3.5, 4, 2.5]);
    });
  });
}
