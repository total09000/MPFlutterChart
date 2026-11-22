// Tests for the pooled MPPointF / MPPointD / FSize ports; no Kotlin counterpart.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/utils/f_size.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_d.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_f.dart';

void main() {
  group('MPPointF', () {
    test('getInstance sets, keeps or copies the coordinates', () {
      final p = MPPointF.getInstance(1, 2);
      expect([p.x, p.y], [1, 2]);
      final copy = MPPointF.getInstanceFrom(p);
      expect([copy.x, copy.y], [1, 2]);
      expect(identical(copy, p), isFalse);
      MPPointF.recycleInstance(p);
      final reused = MPPointF.getInstance();
      // The pool is a stack: the point just recycled comes back with its old coordinates.
      expect(identical(reused, p), isTrue);
      expect([reused.x, reused.y], [1, 2]);
      MPPointF.recycleInstances([reused, copy]);
    });

    test('recycling twice throws', () {
      final p = MPPointF.getInstance(0, 0);
      MPPointF.recycleInstance(p);
      expect(() => MPPointF.recycleInstance(p), throwsArgumentError);
      expect(identical(MPPointF.getInstance(), p), isTrue);
    });

    test('defaults to the origin', () {
      final p = MPPointF();
      expect([p.x, p.y], [0, 0]);
    });
  });

  group('MPPointD', () {
    test('getInstance and toString', () {
      final p = MPPointD.getInstance(1.5, -2);
      expect(p.toString(), 'MPPointD, x: 1.5, y: -2.0');
      MPPointD.recycleInstance(p);
      expect(() => MPPointD.recycleInstances([p]), throwsArgumentError);
    });
  });

  group('FSize', () {
    test('equality, hashCode and toString', () {
      expect(FSize(1, 2), FSize(1, 2));
      expect(FSize(1, 2) == FSize(2, 1), isFalse);
      expect(FSize(1, 2).hashCode, FSize(1, 2).hashCode);
      expect(FSize(1, 2).toString(), '1.0x2.0');
    });

    test('getInstance sets the size', () {
      final s = FSize.getInstance(3, 4);
      expect([s.width, s.height], [3, 4]);
      FSize.recycleInstance(s);
      expect(() => FSize.recycleInstance(s), throwsArgumentError);
    });
  });
}
