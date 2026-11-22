// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/RegressionTest.kt
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/animation/easing.dart';
import 'package:mp_flutter_chart/src/components/x_axis.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/bubble_data_set.dart';
import 'package:mp_flutter_chart/src/data/bubble_entry.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/data/scatter_data_set.dart';
import 'package:mp_flutter_chart/src/formatter/large_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/percent_formatter.dart';
import 'package:mp_flutter_chart/src/utils/float_math.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';

void main() {
  test('easeOutExpoProgressesThroughTheAnimation', () {
    expect(Easing.EaseOutExpo(0.5), closeTo(0.97, 0.01));
    expect(Easing.EaseOutExpo(0.1) > 0.4, isTrue);
  });

  test('closestYPicksTheNearestEntryAmongEqualX', () {
    final set = ScatterDataSet([
      Entry(x: 1, y: 1),
      Entry(x: 1, y: 5),
      Entry(x: 1, y: 3),
    ], '');
    expect(set.getEntryForXValue(1, 4.4)!.y, closeTo(5, 0.001));
    expect(set.getEntryForXValue(1, 2.6)!.y, closeTo(3, 0.001));
  });

  test('derivedSizesFollowLaterChanges (bar part)', () {
    final bars = BarDataSet([BarEntry(x: 0, y: 1)], 'bars');
    expect(bars.stackSize, 1);
    bars.addEntry(BarEntry.stacked(x: 1, stackValues: [1, 2, 3]));
    bars.notifyDataSetChanged();
    expect(bars.stackSize, 3);
    expect(bars.isStacked, isTrue);

    final stacked = BarEntry.stacked(x: 0, stackValues: [1, 2]);
    stacked.stackValues = null;
    expect(stacked.ranges, isNull);
  });

  test('derivedSizesFollowLaterChanges (bubble part)', () {
    final bubbles = BubbleDataSet([
      BubbleEntry(x: 0, y: 0, size: 9),
      BubbleEntry(x: 1, y: 1, size: 2),
    ], 'bubbles');
    expect(bubbles.maxSize, closeTo(9, 0.001));
    bubbles.entries = [BubbleEntry(x: 0, y: 0, size: 4)];
    expect(bubbles.maxSize, closeTo(4, 0.001));
  });

  test('formattersAndHelpersHandleEdgeValues', () {
    expect(Utils.getDecimals(0), 0);
    expect(
      LargeValueFormatter().getFormattedValue(toKotlinFloat(1e16), XAxis()),
      endsWith('t'),
    );
    expect(PercentFormatter().decimalDigits, 1);
    final line = LineDataSet([Entry(x: 0, y: 0)], '')
      ..circleColors = [const Color(0x00000001), const Color(0x00000002)];
    expect(line.getCircleColor(2), const Color(0x00000001));
  });
}
