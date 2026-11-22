// Tests for the Paint.measureText / StaticLayout measurement cache TextMeasure; no Kotlin counterpart.
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/text_measure.dart';

void main() {
  const style = TextStyle(fontSize: 10, color: Color(0xFF000000));

  setUp(TextMeasure.clearCache);

  group('TextMeasure', () {
    test('the same key returns the same laid out instance', () {
      final a = TextMeasure.layout('abc', style);
      expect(TextMeasure.layout('abc', style), same(a));
      expect(
        TextMeasure.layout(
          'abc',
          const TextStyle(fontSize: 10, color: Color(0xFF000000)),
        ),
        same(a),
      );
      expect(a.width, greaterThan(0));
    });

    test('clearCache drops all entries', () {
      final a = TextMeasure.layout('abc', style);
      TextMeasure.clearCache();
      expect(TextMeasure.layout('abc', style), isNot(same(a)));
    });

    test('text, style, maxWidth and maxLines are all part of the key', () {
      final a = TextMeasure.layout('abc', style);
      expect(TextMeasure.layout('abd', style), isNot(same(a)));
      expect(
        TextMeasure.layout('abc', style.copyWith(fontSize: 11)),
        isNot(same(a)),
      );
      final wrapped = TextMeasure.layout('abc', style, maxWidth: 15);
      expect(wrapped, isNot(same(a)));
      expect(TextMeasure.layout('abc', style, maxWidth: 15), same(wrapped));
      expect(
        TextMeasure.layout('abc', style, maxWidth: 15, maxLines: 1),
        isNot(same(wrapped)),
      );
    });

    test('maxWidth wraps and maxLines limits the lines', () {
      final one = TextMeasure.layout('aa aa aa', style);
      final wrapped = TextMeasure.layout('aa aa aa', style, maxWidth: 25);
      expect(wrapped.height, greaterThan(one.height));
      final limited = TextMeasure.layout(
        'aa aa aa',
        style,
        maxWidth: 25,
        maxLines: 1,
      );
      expect(limited.height, closeTo(one.height, 1e-4));
    });

    test(
      'the cache keeps at most 512 entries and evicts the least recently used',
      () {
        final first = TextMeasure.layout('0', style);
        final second = TextMeasure.layout('1', style);
        for (var i = 2; i < 512; i++) {
          TextMeasure.layout('$i', style);
        }
        expect(TextMeasure.cacheSize, 512);
        // Touch '0' so '1' becomes the least recently used entry.
        expect(TextMeasure.layout('0', style), same(first));
        TextMeasure.layout('512', style);
        expect(TextMeasure.cacheSize, 512);
        expect(TextMeasure.layout('0', style), same(first));
        expect(TextMeasure.layout('1', style), isNot(same(second)));
      },
    );
  });
}
