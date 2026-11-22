// Tests for the android.graphics.DashPathEffect shim dashPath; no Kotlin counterpart.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/graphics/dash_path.dart';

ui.Path _line(double length) => ui.Path()
  ..moveTo(0, 0)
  ..lineTo(length, 0);

List<double> _lengths(ui.Path p) =>
    p.computeMetrics().map((m) => m.length).toList();

void main() {
  group('dashPath', () {
    test('a line of 10 with intervals [2, 2] and phase 0 has 3 dashes', () {
      final dashed = dashPath(_line(10), DashPathEffect(const [2, 2], 0));
      expect(dashed.computeMetrics().length, 3);
      final lengths = _lengths(dashed);
      for (final l in lengths) {
        expect(l, closeTo(2, 1e-4));
      }
      final bounds = dashed.getBounds();
      expect(bounds.left, closeTo(0, 1e-4));
      expect(bounds.right, closeTo(10, 1e-4));
    });

    test('no empty dash when an off interval ends exactly at the end', () {
      expect(
        dashPath(
          _line(4),
          DashPathEffect(const [2, 2], 0),
        ).computeMetrics().length,
        1,
      );
    });

    test('the last dash is cut at the end of the contour', () {
      final lengths = _lengths(
        dashPath(_line(9), DashPathEffect(const [2, 2], 0)),
      );
      expect(lengths.length, 3);
      expect(lengths.last, closeTo(1, 1e-4));
    });

    test('phase shifts into the pattern', () {
      // Phase 1: first dash is the remaining 1 of [0, 2), then on at 3..5, 7..9.
      final lengths = _lengths(
        dashPath(_line(10), DashPathEffect(const [2, 2], 1)),
      );
      expect(lengths.length, 3);
      expect(lengths.first, closeTo(1, 1e-4));
      // Phase 3 starts in the off interval: dashes at 1..3, 5..7, 9..10.
      final shifted = dashPath(_line(10), DashPathEffect(const [2, 2], 3));
      expect(shifted.getBounds().left, closeTo(1, 1e-4));
      expect(_lengths(shifted).length, 3);
    });

    test('phase wraps modulo the pattern length, negative phases included', () {
      final a = _lengths(dashPath(_line(10), DashPathEffect(const [2, 2], 1)));
      expect(_lengths(dashPath(_line(10), DashPathEffect(const [2, 2], 5))), a);
      // -3 ≡ 1 (mod 4)
      expect(
        _lengths(dashPath(_line(10), DashPathEffect(const [2, 2], -3))),
        a,
      );
    });

    test('the pattern restarts on every contour', () {
      final path = ui.Path()
        ..moveTo(0, 0)
        ..lineTo(3, 0)
        ..moveTo(0, 5)
        ..lineTo(3, 5);
      final lengths = _lengths(dashPath(path, DashPathEffect(const [2, 2], 0)));
      expect(lengths.length, 2);
      expect(lengths[0], closeTo(2, 1e-4));
      expect(lengths[1], closeTo(2, 1e-4));
    });

    test('more than two intervals cycle in order', () {
      // on 1, off 1, on 3, off 1 → dashes [0,1], [2,5], [6,7], [8,11→10]
      final lengths = _lengths(
        dashPath(_line(10), DashPathEffect(const [1, 1, 3, 1], 0)),
      );
      expect(lengths.length, 4);
      expect(lengths[0], closeTo(1, 1e-4));
      expect(lengths[1], closeTo(3, 1e-4));
      expect(lengths[2], closeTo(1, 1e-4));
      expect(lengths[3], closeTo(2, 1e-4));
    });

    test(
      'a zero-length dash is a zero-length line (a dot with a round cap)',
      () {
        // on 0, off 4 → dots at 0, 4 and 8.
        final dashed = dashPath(_line(10), DashPathEffect(const [0, 4], 0));
        final bounds = dashed.getBounds();
        expect(bounds.left, closeTo(0, 1e-4));
        expect(bounds.right, closeTo(8, 1e-4));
      },
    );

    test('an invalid effect leaves the path undashed, like Skia', () {
      final source = _line(10);
      expect(dashPath(source, DashPathEffect(const [0, 0], 0)), same(source));
      expect(dashPath(source, DashPathEffect(const [-1, 2], 0)), same(source));
    });

    test('an empty path stays empty', () {
      expect(
        dashPath(
          ui.Path(),
          DashPathEffect(const [2, 2], 0),
        ).computeMetrics().length,
        0,
      );
    });
  });
}
