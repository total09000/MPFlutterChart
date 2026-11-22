// Tests for the android.graphics.RectF shim MutableRect; no Kotlin counterpart.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';

void main() {
  group('MutableRect', () {
    test('default constructor is the empty rect at the origin', () {
      final r = MutableRect();
      expect([r.left, r.top, r.right, r.bottom], [0, 0, 0, 0]);
      expect(r.isEmpty, isTrue);
    });

    test('width, height, centerX, centerY', () {
      final r = MutableRect(1, 2, 5, 10);
      expect(r.width(), 4);
      expect(r.height(), 8);
      expect(r.centerX(), 3);
      expect(r.centerY(), 6);
      expect(r.isEmpty, isFalse);
    });

    test('inset(1, 1) shrinks width and height by 2', () {
      final r = MutableRect(0, 0, 10, 20)..inset(1, 1);
      expect([r.left, r.top, r.right, r.bottom], [1, 1, 9, 19]);
      expect(r.width(), 8);
      expect(r.height(), 18);
    });

    test('negative inset expands', () {
      final r = MutableRect(0, 0, 10, 20)..inset(-2, 0);
      expect([r.left, r.top, r.right, r.bottom], [-2, 0, 12, 20]);
    });

    test('offset moves all edges', () {
      final r = MutableRect(0, 0, 10, 20)..offset(3, -4);
      expect([r.left, r.top, r.right, r.bottom], [3, -4, 13, 16]);
    });

    test('set and setFrom copy edges', () {
      final a = MutableRect()..set(1, 2, 3, 4);
      expect([a.left, a.top, a.right, a.bottom], [1, 2, 3, 4]);
      final b = MutableRect()..setFrom(a);
      a.offset(10, 10);
      expect([b.left, b.top, b.right, b.bottom], [1, 2, 3, 4]);
    });

    test('contains is half-open and false for an empty rect', () {
      final r = MutableRect(0, 0, 10, 10);
      expect(r.contains(0, 0), isTrue);
      expect(r.contains(5, 5), isTrue);
      expect(r.contains(10, 5), isFalse);
      expect(r.contains(5, 10), isFalse);
      expect(r.contains(-1, 5), isFalse);
      expect(MutableRect(5, 5, 5, 5).contains(5, 5), isFalse);
    });

    test('isEmpty when left >= right or top >= bottom', () {
      expect(MutableRect(1, 0, 1, 5).isEmpty, isTrue);
      expect(MutableRect(0, 6, 5, 5).isEmpty, isTrue);
      expect(MutableRect(0, 0, 1, 1).isEmpty, isFalse);
    });

    test('toRect and setFromRect round-trip', () {
      const rect = ui.Rect.fromLTRB(1.5, 2.5, 30.25, 40.75);
      final r = MutableRect()..setFromRect(rect);
      expect([r.left, r.top, r.right, r.bottom], [1.5, 2.5, 30.25, 40.75]);
      expect(r.toRect(), rect);
    });

    test('fields are mutable', () {
      final r = MutableRect(0, 2, 10, 4);
      r.top *= 0.5;
      r.bottom *= 0.5;
      expect([r.top, r.bottom], [1, 2]);
    });
  });
}
