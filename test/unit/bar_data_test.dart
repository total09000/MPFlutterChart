// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/BarDataTest.kt
//
// The second test (grouping fewer than two sets) is not in the Kotlin test; it locks the IllegalStateException of
// BarData.groupBars, which is a StateError here.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';

void main() {
  test('groupBars', () {
    const groupSpace = 5.0;
    const barSpace = 1.0;

    final values1 = <BarEntry>[];
    final values2 = <BarEntry>[];
    for (var i = 0; i < 5; i++) {
      values1.add(BarEntry(x: i.toDouble(), y: 50));
      values2.add(BarEntry(x: i.toDouble(), y: 60));
    }

    final data = BarData([
      BarDataSet(values1, 'Set1'),
      BarDataSet(values2, 'Set2'),
    ]);
    data.barWidth = 10;

    expect(data.getGroupWidth(groupSpace, barSpace), closeTo(27, 0.01));
    expect(values1[0].x, closeTo(0, 0.01));
    expect(values1[1].x, closeTo(1, 0.01));

    data.groupBars(1000, groupSpace, barSpace);

    expect(values1[0].x, closeTo(1008, 0.01));
    expect(values2[0].x, closeTo(1019, 0.01));
    expect(values1[1].x, closeTo(1035, 0.01));
    expect(values2[1].x, closeTo(1046, 0.01));

    data.groupBars(-1000, groupSpace, barSpace);

    expect(values1[0].x, closeTo(-992, 0.01));
    expect(values2[0].x, closeTo(-981, 0.01));
    expect(values1[1].x, closeTo(-965, 0.01));
    expect(values2[1].x, closeTo(-954, 0.01));

    data.barWidth = 20;
    expect(data.getGroupWidth(groupSpace, barSpace), closeTo(47, 0.01));

    data.barWidth = 10;
    data.groupBars(-20, groupSpace, barSpace);

    expect(values1[0].x, closeTo(-12, 0.01));
    expect(values2[0].x, closeTo(-1, 0.01));
    expect(values1[1].x, closeTo(15, 0.01));
    expect(values2[1].x, closeTo(26, 0.01));
  });

  test('groupBars needs at least two sets', () {
    final throwsTooFewSets = throwsA(
      isA<StateError>().having(
        (e) => e.message,
        'message',
        'BarData needs to hold at least 2 BarDataSets to allow grouping.',
      ),
    );

    final entry = BarEntry(x: 3, y: 1);
    final single = BarData([
      BarDataSet([entry], 'only'),
    ]);
    expect(() => single.groupBars(0, 1, 0.1), throwsTooFewSets);
    expect(entry.x, 3);

    expect(() => BarData().groupBars(0, 1, 0.1), throwsTooFewSets);
  });
}
