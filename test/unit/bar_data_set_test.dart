// Not a port of a Kotlin test (task brief): locks the BarEntry / BarDataSet behaviour that BarDataTest.kt and
// StackedBarTest.kt leave out — fill lookup, the styling defaults and copy, the stack counts and when they refresh,
// and stacks without values or with values that are not finite.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/utils/fill.dart';

import 'support/counting_icon.dart';

const Color _RED = Color(0xFFFF0000);
const Color _BLUE = Color(0xFF0000FF);

void main() {
  group('BarEntry', () {
    test('an empty stack is stacked but has no ranges', () {
      final entry = BarEntry.stacked(x: 0, stackValues: []);
      expect(entry.isStacked, isTrue);
      expect(entry.ranges, isNull);
      expect(entry.y, 0);
      expect(entry.positiveSum, 0);
      expect(entry.negativeSum, 0);
    });

    test('a single bar has no stack', () {
      final entry = BarEntry(x: 1, y: 4);
      expect(entry.isStacked, isFalse);
      expect(entry.stackValues, isNull);
      expect(entry.ranges, isNull);
      expect(entry.y, 4);
      expect(entry.positiveSum, 0);
      expect(entry.negativeSum, 0);
      expect(entry.getSumBelow(0), 0);
    });

    test('assigning stack values recomputes y, the sums and the ranges', () {
      final entry = BarEntry.stacked(x: 0, stackValues: [1, 2]);
      entry.stackValues = [-1, 4];
      expect(entry.y, closeTo(3, 1e-4));
      expect(entry.positiveSum, closeTo(4, 1e-4));
      expect(entry.negativeSum, closeTo(1, 1e-4));
      final ranges = entry.ranges!;
      expect(ranges, hasLength(2));
      expect(ranges[0].from, closeTo(-1, 1e-4));
      expect(ranges[0].to, closeTo(0, 1e-4));
      expect(ranges[1].from, closeTo(0, 1e-4));
      expect(ranges[1].to, closeTo(4, 1e-4));
      expect(entry.getSumBelow(0), closeTo(4, 1e-4));
    });

    test('a copy shares the stack list, icon and payload', () {
      final stack = [1.0, 2.0];
      final icon = CountingIcon();
      final entry = BarEntry<String>.stacked(
        x: 5,
        stackValues: stack,
        icon: icon,
        data: 'payload',
      );
      final copied = entry.copy();
      expect(copied, isNot(same(entry)));
      expect(copied.x, 5);
      expect(copied.y, closeTo(3, 1e-4));
      expect(copied.stackValues, same(stack));
      expect(copied.icon, same(icon));
      expect(copied.data, same(entry.data));
      expect(copied.ranges, hasLength(2));
    });

    test(
      'copy of a single bar has y 0, as in MPAndroidChart v4.0.1: copy() assigns the null stack, whose sum is 0',
      () {
        final entry = BarEntry(x: 1, y: 4);
        final copied = entry.copy();
        expect(copied.x, 1);
        expect(copied.y, 0);
        expect(copied.isStacked, isFalse);
        expect(entry.y, 4);
      },
    );
  });

  group('BarDataSet', () {
    test('has the Kotlin styling defaults', () {
      final set = BarDataSet([BarEntry(x: 0, y: 1)], 'bars');
      expect(set.highlightColor, const Color(0xFF000000));
      expect(set.barShadowColor, const Color(0xFFD7D7D7));
      expect(set.barBorderWidth, 0);
      expect(set.barBorderColor, const Color(0xFF000000));
      expect(set.highlightAlpha, 120);
      expect(set.stackLabels, isEmpty);
      expect(set.barCornerRadius, 0);
      expect(set.isStackSectionsRounded, isFalse);
      expect(set.fills, isNull);
    });

    test('getFill wraps around the fills, negative indices too', () {
      final first = Fill.ofColor(_RED);
      final second = Fill.ofColor(_BLUE);
      final set = BarDataSet([BarEntry(x: 0, y: 1)], 'bars')
        ..fills = [first, second];
      expect(set.getFill(0), same(first));
      expect(set.getFill(-1), same(second));
      expect(set.getFill(3), same(second));

      // Kotlin's Math.floorMod: -1 is the last fill, not the second one a truncating remainder would give.
      final third = Fill.ofColor(_RED);
      set.fills = [first, second, third];
      expect(set.getFill(-1), same(third));
      expect(set.getFill(-4), same(third));
      expect(set.getFill(4), same(second));
    });

    test('getFill without fills is an empty fill', () {
      final set = BarDataSet([BarEntry(x: 0, y: 1)], 'bars');
      expect(set.getFill(0).type, FillType.EMPTY);
    });

    test('setGradientColor replaces the fills with one gradient', () {
      final set = BarDataSet([BarEntry(x: 0, y: 1)], 'bars')
        ..fills = [Fill.ofColor(_RED), Fill.ofColor(_BLUE)];
      set.setGradientColor(_RED, _BLUE);
      final fill = set.fills!.single;
      expect(fill.type, FillType.LINEAR_GRADIENT);
      expect(fill.gradientColors, [_RED, _BLUE]);
    });

    test('entryCountStacks counts every stack value', () {
      final set = BarDataSet([
        BarEntry.stacked(x: 0, stackValues: [1, 2, 3]),
        BarEntry(x: 1, y: 5),
      ], 'bars');
      expect(set.entryCountStacks, 4);
      expect(set.entryCount, 2);
    });

    test('assigning entries recomputes stackSize and entryCountStacks, '
        'narrower too', () {
      final set = BarDataSet([
        BarEntry.stacked(x: 0, stackValues: [1, 2, 3]),
        BarEntry(x: 1, y: 5),
      ], 'bars');
      expect(set.stackSize, 3);
      expect(set.entryCountStacks, 4);

      set.entries = [
        BarEntry.stacked(x: 0, stackValues: [1, 2]),
        BarEntry.stacked(x: 1, stackValues: [4, 5]),
      ];
      expect(set.stackSize, 2);
      expect(set.entryCountStacks, 4);
      expect(set.isStacked, isTrue);

      set.entries = [BarEntry(x: 0, y: 1)];
      expect(set.stackSize, 1);
      expect(set.entryCountStacks, 1);
      expect(set.isStacked, isFalse);
    });

    test(
      'addEntry widens stackSize but leaves entryCountStacks stale until notifyDataSetChanged',
      () {
        final set = BarDataSet([
          BarEntry.stacked(x: 0, stackValues: [1, 2, 3]),
          BarEntry(x: 1, y: 5),
        ], 'bars');
        expect(set.stackSize, 3);

        set.addEntry(BarEntry.stacked(x: 2, stackValues: [1, 1, 1, 1]));
        expect(set.stackSize, 4);
        expect(set.entryCountStacks, 4);

        set.notifyDataSetChanged();
        expect(set.stackSize, 4);
        expect(set.entryCountStacks, 8);
      },
    );

    test(
      'a stack with a value that is not finite stays out of the y range',
      () {
        final set = BarDataSet([
          BarEntry(x: 0, y: 2),
          BarEntry.stacked(x: 1, stackValues: [1, double.nan]),
          BarEntry.stacked(x: 2, stackValues: [-1, double.infinity]),
        ], 'bars');
        expect(set.yMin, 2);
        expect(set.yMax, 2);
      },
    );

    test('copy copies the entries and the bar styling', () {
      final fills = [Fill.ofColor(_RED), Fill.ofColor(_BLUE)];
      final set =
          BarDataSet([
              BarEntry.stacked(x: 0, stackValues: [1, 2]),
            ], 'bars')
            ..barBorderColor = _RED
            ..fills = fills
            ..barCornerRadius = 3
            ..isStackSectionsRounded = true
            ..barShadowColor = _BLUE
            ..barBorderWidth = 1.5
            ..stackLabels = ['a', 'b']
            ..highlightAlpha = 60
            ..highlightColor = _BLUE;

      final copied = set.copy() as BarDataSet;
      expect(copied.label, 'bars');
      expect(copied.entries.single, isNot(same(set.entries.single)));
      expect(copied.entries.single.stackValues, [1, 2]);
      expect(copied.barBorderColor, _RED);
      expect(copied.fills, isNot(same(fills)));
      expect(copied.fills, hasLength(2));
      expect(copied.fills![0], same(fills[0]));
      expect(copied.fills![1], same(fills[1]));
      expect(copied.stackSize, 2);
      expect(copied.barCornerRadius, closeTo(3, 1e-4));
      expect(copied.isStackSectionsRounded, isTrue);
      expect(copied.barShadowColor, _BLUE);
      expect(copied.barBorderWidth, closeTo(1.5, 1e-4));
      expect(copied.stackLabels, ['a', 'b']);
      expect(copied.highlightAlpha, 60);
      expect(copied.highlightColor, _BLUE);
    });

    test(
      'copy of a set of single bars has y 0 on every bar, as in MPAndroidChart v4.0.1, where BarEntry.copy() '
      'assigns the null stack',
      () {
        final set = BarDataSet([
          BarEntry(x: 0, y: 4),
          BarEntry(x: 1, y: -2),
        ], 'bars');
        final copied = set.copy() as BarDataSet;
        expect(copied.entries.map((e) => e.y), [0, 0]);
        expect(copied.yMax, 0);
        expect(copied.yMin, 0);
        expect(set.entries.map((e) => e.y), [4, -2]);
      },
    );
  });
}
