// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/PointReducerTest.kt
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/renderer/point_reducer.dart';

class _Points extends ColumnValues {
  _Points(this._xs, this._ys);

  final Float32List _xs;
  final Float32List _ys;

  @override
  double xAt(int index) => _xs[index];

  @override
  double lowAt(int index) => _ys[index];

  @override
  double highAt(int index) => _ys[index];
}

List<int> _kept(PointReducer reducer) =>
    reducer.indices.sublist(0, reducer.count).toList();

Float32List _floats(int n, double Function(int i) f) =>
    Float32List.fromList(List<double>.generate(n, f));

void main() {
  test('keepsTheHighestAndLowestOfEveryColumn', () {
    final xs = _floats(40, (i) => i.toDouble());
    final ys = _floats(40, (_) => 10);
    ys[21] = -5;
    ys[22] = 99;

    final reducer = PointReducer();
    reducer.reduce(_Points(xs, ys), 0, 39, 0, 4, 10);

    expect(_kept(reducer).contains(22), isTrue, reason: 'the spike survives');
    expect(_kept(reducer).contains(21), isTrue, reason: 'the dip survives');
  });

  test('keepsANonFiniteEntryAndTheRealExtremesOfItsColumn', () {
    final xs = _floats(40, (i) => i.toDouble());
    final ys = _floats(40, (_) => 10);
    ys[20] = double.nan;
    ys[21] = -5;
    ys[22] = 99;

    final reducer = PointReducer();
    reducer.reduce(_Points(xs, ys), 0, 39, 0, 4, 10);

    final indices = _kept(reducer);
    expect(indices.contains(20), isTrue, reason: 'the gap survives');
    expect(indices.contains(21), isTrue, reason: 'the dip survives');
    expect(indices.contains(22), isTrue, reason: 'the spike survives');
  });

  test('keepsEveryEntryBelowOnePointPerPixel', () {
    final xs = _floats(10, (i) => i.toDouble());
    final ys = _floats(10, (i) => i.toDouble());

    final reducer = PointReducer();
    reducer.reduce(_Points(xs, ys), 0, 9, 0, 0.1, 100);

    expect(_kept(reducer), List<int>.generate(10, (i) => i));
  });

  test('returnsAscendingIndices', () {
    final xs = _floats(1000, (i) => i.toDouble());
    // Kotlin: sin(it * 0.1f) * 100f, in Float.
    final ys = _floats(1000, (i) => math.sin(i * 0.1) * 100);

    final reducer = PointReducer();
    reducer.reduce(_Points(xs, ys), 0, 999, 0, 10, 100);

    final indices = _kept(reducer);
    expect(
      indices.length,
      lessThan(1000),
      reason: 'reduced below the input size',
    );
    for (var i = 1; i < indices.length; i++) {
      expect(
        indices[i],
        greaterThan(indices[i - 1]),
        reason: 'index $i is after index ${i - 1}',
      );
    }
  });
}
