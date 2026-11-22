// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for the bubble data classes. Locks BubbleEntry
// (its writable size, copy), the BubbleDataSet defaults, maxSize (recomputed from scratch by calcMinMax, only widened
// by addEntry), copy, and the BubbleData constructor and setHighlightCircleWidth. The Kotlin RegressionTest bubble
// part (maxSize follows a new entry list) runs in regression_test.dart.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/data/bubble_data.dart';
import 'package:mp_flutter_chart/src/data/bubble_data_set.dart';
import 'package:mp_flutter_chart/src/data/bubble_entry.dart';
import 'package:mp_flutter_chart/src/graphics/chart_drawable.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';

const _yellow = ui.Color(0xFFFFFF00);

class _Icon extends ChartDrawable {
  @override
  int get intrinsicWidth => 1;

  @override
  int get intrinsicHeight => 1;

  @override
  void draw(ui.Canvas canvas, MutableRect bounds) {}
}

BubbleEntry _bubble(double x, double y, double size) =>
    BubbleEntry(x: x, y: y, size: size);

void main() {
  group('BubbleEntry', () {
    test('holds a point and a writable size', () {
      final bubble = BubbleEntry(x: 1, y: 2, size: 3);
      expect([bubble.x, bubble.y, bubble.size], [1, 2, 3]);

      bubble.size = 7;
      expect(bubble.size, 7);
    });

    test('copy keeps the values and shares the icon and the payload', () {
      final icon = _Icon();
      final payload = Object();
      final bubble = BubbleEntry<Object>(
        x: 3,
        y: 4,
        size: 5,
        icon: icon,
        data: payload,
      );

      final copied = bubble.copy();
      expect(copied, isA<BubbleEntry<Object>>());
      expect(identical(copied, bubble), isFalse);
      expect([copied.x, copied.y, copied.size], [3, 4, 5]);
      expect(copied.icon, same(icon));
      expect(copied.data, same(payload));

      copied.size = 50;
      expect(bubble.size, 5);
    });
  });

  group('BubbleDataSet', () {
    test('defaults: normalized sizes and a 1 dp highlight ring', () {
      final set = BubbleDataSet([_bubble(0, 1, 2)], 'bubbles');
      expect(set.isNormalizeSizeEnabled, isTrue);
      expect(set.highlightCircleWidth, 1);
    });

    test('maxSize is the largest size, computed at construction', () {
      final set = BubbleDataSet([
        _bubble(0, 1, 2),
        _bubble(1, 5, 9),
        _bubble(2, 3, 4),
      ], 'bubbles');
      expect(set.maxSize, 9);
      // The y range is the range of the y values, not of the sizes.
      expect(set.yMin, 1);
      expect(set.yMax, 5);
      expect(set.xMin, 0);
      expect(set.xMax, 2);
    });

    test('an empty set, or one with only zero, negative or NaN sizes, has a '
        'maxSize of 0', () {
      expect(BubbleDataSet(<BubbleEntry>[], 'empty').maxSize, 0);
      expect(
        BubbleDataSet([
          _bubble(0, 1, 0),
          _bubble(1, 1, -5),
          _bubble(2, 1, double.nan),
        ], 'degenerate').maxSize,
        0,
      );
    });

    test('a NaN size is skipped, an infinite one is the largest', () {
      final set = BubbleDataSet([
        _bubble(0, 1, 3),
        _bubble(1, 1, double.nan),
      ], 'bubbles');
      expect(set.maxSize, 3);

      set.addEntry(_bubble(2, 1, double.infinity));
      expect(set.maxSize, double.infinity);
    });

    test('addEntry only widens maxSize; a recompute of the ranges starts it '
        'from scratch', () {
      final big = _bubble(1, 1, 9);
      final set = BubbleDataSet([_bubble(0, 1, 2), big], 'bubbles');

      set.addEntry(_bubble(2, 1, 4));
      expect(set.maxSize, 9);
      set.addEntry(_bubble(3, 1, 12));
      expect(set.maxSize, 12);

      // removeEntry recomputes the ranges, so maxSize drops back.
      set.removeEntryByIndex(3);
      expect(set.maxSize, 9);

      // A size changed in place counts once the ranges are recomputed, even a smaller one.
      big.size = 1;
      expect(set.maxSize, 9);
      set.notifyDataSetChanged();
      expect(set.maxSize, 4);
    });

    test('copy copies the entries and the bubble settings', () {
      final set = BubbleDataSet([_bubble(0, 1, 2), _bubble(1, 5, 9)], 'bubbles')
        ..highlightCircleWidth = 3
        ..isNormalizeSizeEnabled = false
        ..highlightColor = _yellow
        ..isHighlightEnabled = false;

      final copied = set.copy() as BubbleDataSet;

      expect(copied.label, 'bubbles');
      expect(copied.entryCount, 2);
      expect(
        identical(copied.getEntryForIndex(0), set.getEntryForIndex(0)),
        isFalse,
      );
      expect(copied.getEntryForIndex(1).size, 9);
      expect(copied.maxSize, 9);
      expect(copied.yMax, 5);
      expect(copied.highlightCircleWidth, 3);
      expect(copied.isNormalizeSizeEnabled, isFalse);
      expect(copied.highlightColor, _yellow);
      expect(copied.isHighlightEnabled, isFalse);
    });
  });

  group('BubbleData', () {
    test('the empty and the list constructors', () {
      expect(BubbleData().dataSets, isEmpty);

      final sets = [
        BubbleDataSet([_bubble(0, 1, 2)], 'a'),
        BubbleDataSet([_bubble(0, 3, 4)], 'b'),
      ];
      final data = BubbleData(sets);
      expect(data.dataSets, same(sets));
      expect(data.yMax, 3);
    });

    test('setHighlightCircleWidth writes the width into every set', () {
      final a = BubbleDataSet([_bubble(0, 1, 2)], 'a');
      final b = BubbleDataSet([_bubble(0, 3, 4)], 'b');

      BubbleData([a, b]).setHighlightCircleWidth(3);

      expect(a.highlightCircleWidth, 3);
      expect(b.highlightCircleWidth, 3);
    });
  });
}
