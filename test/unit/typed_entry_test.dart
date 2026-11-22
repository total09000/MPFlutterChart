// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/TypedEntryTest.kt
//
// Dart generics are reified, so the payload type is written on the data set (`LineDataSet<_Order>`) where Kotlin
// infers it from the entries; an entry without a payload then is an `Entry<_Order>` with null data. Kotlin's Int colors
// 1, 2, 3 are Color(0x00000001) to Color(0x00000003).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';

class _Order {
  const _Order(this.id);

  final int id;

  @override
  bool operator ==(Object other) => other is _Order && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

void main() {
  test('payloadTypeFlowsFromEntriesToDataSetAndBack', () {
    final set = LineDataSet<_Order>([
      Entry(x: 0, y: 1, data: const _Order(7)),
      Entry(x: 1, y: 2),
    ], 'orders');
    final _Order? order = set.getEntryForXValue(0)?.data;
    expect(order, const _Order(7));
    expect(set.getEntryForXValue(1)?.data, isNull);

    final data = LineData([set]);
    final Object? untyped = data.dataSets[0].getEntryForIndex(0).data;
    expect(untyped, const _Order(7));

    final copied = set.copy() as LineDataSet<_Order>;
    expect(copied.entries[0].data, const _Order(7));
  });

  test('copyKeepsConfigurationAndStackValues (bar part)', () {
    final set =
        BarDataSet([
            BarEntry.stacked(x: 0, stackValues: [1, 2]),
            BarEntry(x: 1, y: 4),
          ], 'stacks')
          ..colors = [
            const Color(0x00000001),
            const Color(0x00000002),
            const Color(0x00000003),
          ]
          ..stackLabels = ['a', 'b']
          ..isDrawValuesEnabled = false
          ..barCornerRadius = 7;
    final copied = set.copy() as BarDataSet;
    expect(copied.colors, [
      const Color(0x00000001),
      const Color(0x00000002),
      const Color(0x00000003),
    ]);
    expect(copied.stackLabels, ['a', 'b']);
    expect(copied.isDrawValuesEnabled, false);
    expect(copied.entries[0].stackValues, [1, 2]);
    expect(copied.stackSize, 2);
    expect(copied.barCornerRadius, closeTo(7, 1e-4));
  });

  test('copyKeepsConfigurationAndStackValues', () {
    final line = LineDataSet([Entry(x: 0, y: 1)], 'line')
      ..isDrawHighlightCircleEnabled = true
      ..highlightCircleRadius = 6;
    final lineCopy = line.copy() as LineDataSet;
    expect(lineCopy.isDrawHighlightCircleEnabled, true);
    expect(lineCopy.highlightCircleRadius, closeTo(6, 1e-4));
  });
}
