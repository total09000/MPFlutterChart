// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/ValueTransitionTest.kt
//
// The tests after the ported ones cover ofY, release, shared entries and the data set class check.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/animation/chart_animator.dart';
import 'package:mp_flutter_chart/src/animation/value_transition.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/bubble_data.dart';
import 'package:mp_flutter_chart/src/data/bubble_data_set.dart';
import 'package:mp_flutter_chart/src/data/bubble_entry.dart';
import 'package:mp_flutter_chart/src/data/candle_data.dart';
import 'package:mp_flutter_chart/src/data/candle_data_set.dart';
import 'package:mp_flutter_chart/src/data/candle_entry.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/data/scatter_data.dart';
import 'package:mp_flutter_chart/src/data/scatter_data_set.dart';

LineData _line(List<double> ys) => LineData([
  LineDataSet([
    for (var i = 0; i < ys.length; i++) Entry(x: i.toDouble(), y: ys[i]),
  ], 'line'),
]);

List<double> _ys(LineData data, [int set = 0]) => [
  for (var i = 0; i < data.dataSets[set].entryCount; i++)
    data.dataSets[set].getEntryForIndex(i).y,
];

/// A data set class of its own, so that a data object holding it has another shape than one holding a LineDataSet.
class _OtherLineDataSet extends LineDataSet<dynamic> {
  _OtherLineDataSet(super.entries, super.label);
}

void main() {
  test('linePairsByIndexAndGrowsNewEntriesFromZero', () {
    final old = _line([10, 20, 30]);
    final updated = _line([20, 40, 60, 80]);
    final transition = ValueTransition.between(old, updated)!;

    transition.apply(0);
    expect(_ys(updated), [10, 20, 30, 0]);
    transition.apply(0.5);
    expect(_ys(updated), [15, 30, 45, 40]);
    transition.finish();
    expect(_ys(updated), [20, 40, 60, 80]);
    expect(_ys(old), [10, 20, 30]);

    final shrunk = _line([1]);
    ValueTransition.between(updated, shrunk)!.apply(0);
    expect(_ys(shrunk), [20]);
  });

  test('stacksCandlesAndBubblesMoveEveryValue (bar part)', () {
    final targetStack = <double>[4, 6, 10];
    final bar = BarEntry.stacked(x: 0, stackValues: targetStack);
    final bars = BarData([
      BarDataSet([bar], 'bars'),
    ]);
    final transition = ValueTransition.between(
      BarData([
        BarDataSet([BarEntry(x: 0, y: 10)], 'bars'),
      ]),
      bars,
    )!;
    transition.apply(0);
    expect(bar.stackValues, [10, 0, 0]);
    transition.apply(0.5);
    expect(bar.stackValues, [7, 3, 5]);
    expect(bar.y, 15);
    transition.finish();
    expect(identical(bar.stackValues, targetStack), isTrue);
    expect(bar.y, 20);
  });

  // Not in ValueTransitionTest.kt: the other pairings of startValues for bars.
  test(
    'a stack starts from the old stack padded with 0 and a plain bar from the old total',
    () {
      final grown = BarEntry.stacked(x: 0, stackValues: [3, 4, 5]);
      final plain = BarEntry(x: 1, y: 8);
      final transition = ValueTransition.between(
        BarData([
          BarDataSet([
            BarEntry.stacked(x: 0, stackValues: [1, 2]),
            BarEntry.stacked(x: 1, stackValues: [2, 4]),
          ], 'bars'),
        ]),
        BarData([
          BarDataSet([grown, plain], 'bars'),
        ]),
      )!;
      transition.apply(0);
      expect(grown.stackValues, [1, 2, 0]);
      expect(grown.y, 3);
      expect(plain.y, 6);
      expect(plain.stackValues, isNull);
      transition.apply(0.5);
      expect(grown.stackValues, [2, 3, 2.5]);
      expect(plain.y, 7);
      transition.finish();
      expect(grown.stackValues, [3, 4, 5]);
      expect(plain.y, 8);
    },
  );

  test('stacksCandlesAndBubblesMoveEveryValue (candle part)', () {
    final candle = CandleEntry(x: 0, high: 20, low: 10, open: 12, close: 18);
    final candles = CandleData([
      CandleDataSet([candle], 'candles'),
    ]);
    ValueTransition.between(
      CandleData([
        CandleDataSet([
          CandleEntry(x: 0, high: 10, low: 0, open: 2, close: 8),
        ], 'candles'),
      ]),
      candles,
    )!.apply(0.5);
    expect(
      [candle.high, candle.low, candle.open, candle.close, candle.y],
      [15, 5, 7, 13, 10],
    );
  });

  test('stacksCandlesAndBubblesMoveEveryValue (bubble part)', () {
    final bubble = BubbleEntry(x: 0, y: 10, size: 4);
    final bubbles = BubbleData([
      BubbleDataSet([bubble], 'bubbles'),
    ]);
    ValueTransition.between(
      BubbleData([BubbleDataSet(<BubbleEntry>[], 'bubbles')]),
      bubbles,
    )!.apply(0.5);
    expect([bubble.y, bubble.size], [5, 2]);
  });

  test('differentShapesAreNotPaired', () {
    final old = _line([1, 2]);
    expect(
      ValueTransition.between(
        old,
        LineData([
          old.dataSets[0],
          LineDataSet([Entry(x: 0, y: 1)], 'second'),
        ]),
      ),
      isNull,
    );
    expect(ValueTransition.between(old, LineData()), isNull);
  });

  test('differentShapesAreNotPaired (scatter part)', () {
    final old = _line([1, 2]);
    expect(
      ValueTransition.between(
        old,
        ScatterData([
          ScatterDataSet([Entry(x: 0, y: 1)], 'scatter'),
        ]),
      ),
      isNull,
    );
  });

  test('afterCallsRunsTheBlockOnTheLastCallOnly', () {
    var runs = 0;
    final call = ChartAnimator.afterCalls(2, () => runs++);
    call();
    expect(runs, 0);
    call();
    call();
    expect(runs, 1);
  });

  test('a data set of another class at the same index is not paired', () {
    final old = _line([1, 2]);
    final other = LineData([
      _OtherLineDataSet([Entry(x: 0, y: 5)], 'other'),
    ]);
    expect(ValueTransition.between(old, other), isNull);
    expect(ValueTransition.between(other, old), isNull);
  });

  test(
    'between reports the new data sets and reads every value before writing',
    () {
      // The two data objects share their entries in swapped order: every start value is read before the first write.
      final a = Entry(x: 0, y: 10);
      final b = Entry(x: 1, y: 20);
      final old = LineData([
        LineDataSet([a, b], 'old'),
      ]);
      final swapped = LineData([
        LineDataSet([b, a], 'new'),
      ]);
      final transition = ValueTransition.between(old, swapped)!;
      expect(transition.dataSets, hasLength(1));
      expect(identical(transition.dataSets[0], swapped.dataSets[0]), isTrue);

      transition.apply(0);
      expect([b.y, a.y], [10, 20]);
      transition.apply(0.25);
      expect([b.y, a.y], [12.5, 17.5]);
      transition.finish();
      expect([b.y, a.y], [20, 10]);
    },
  );

  test('finish writes back the exact double targets', () {
    // Kotlin's entries hold Floats; Dart's hold doubles, which a Float buffer would round (0.1 → 0.10000000149…,
    // 1e-300 → 0).
    final updated = _line([0.1, 1e-300]);
    final transition = ValueTransition.between(_line([0, 0]), updated)!;
    transition.apply(0.5);
    expect(_ys(updated), [0.05, 5e-301]);
    transition.finish();
    expect(_ys(updated), [0.1, 1e-300]);
  });

  test('ofY moves one entry from its current y and release stops it', () {
    final data = _line([10, 20]);
    final set = data.dataSets[0];
    final entry = set.getEntryForIndex(1);
    final transition = ValueTransition.ofY(entry, 40, set);
    expect(transition.dataSets, hasLength(1));
    expect(identical(transition.dataSets[0], set), isTrue);

    transition.apply(0.5);
    expect(entry.y, 30);
    expect(entry.x, 1);
    transition.release(entry);
    transition.apply(1);
    expect(entry.y, 30);
    transition.finish();
    expect(entry.y, 30);

    // Releasing an entry the transition does not move changes nothing.
    final other = ValueTransition.ofY(entry, 0, set);
    other.release(Entry(x: 1, y: 30));
    other.finish();
    expect(entry.y, 0);
  });
}
