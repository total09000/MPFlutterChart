// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/StackedBarTest.kt
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';

void main() {
  test('stackedEntriesSplitIntoPositiveAndNegativeParts', () {
    final stacked = BarEntry.stacked(x: 0, stackValues: [2, -3, 5]);
    expect(stacked.isStacked, isTrue);
    expect(stacked.y, closeTo(4, 0.001));
    expect(stacked.positiveSum, closeTo(7, 0.001));
    expect(stacked.negativeSum, closeTo(3, 0.001));
    expect(stacked.getSumBelow(0), closeTo(2, 0.001));
    expect(stacked.getSumBelow(2), closeTo(0, 0.001));
    final ranges = stacked.ranges!;
    expect(ranges, hasLength(3));
    expect(ranges[0].from, closeTo(0, 0.001));
    expect(ranges[0].to, closeTo(2, 0.001));
    expect(ranges[1].from, closeTo(-3, 0.001));
    expect(ranges[1].to, closeTo(0, 0.001));
    expect(ranges[2].from, closeTo(2, 0.001));
    expect(ranges[2].to, closeTo(7, 0.001));

    final set = BarDataSet([
      stacked,
      BarEntry.stacked(x: 1, stackValues: [1, 1, 1]),
    ], 'stacks');
    expect(set.isStacked, isTrue);
    expect(set.stackSize, 3);
    expect(set.yMin, closeTo(-3, 0.001));
    expect(set.yMax, closeTo(7, 0.001));

    final flat = BarDataSet([BarEntry(x: 0, y: 4)], 'flat');
    expect(flat.isStacked, isFalse);
    expect(flat.stackSize, 1);
  });
}
