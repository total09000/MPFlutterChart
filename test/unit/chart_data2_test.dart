// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/ChartDataTest2.kt
// (class ChartDataListsTest; file name per Ruling R8). Kotlin's Int colors 1, 2, 3 are Color(0x00000001) to Color(0x00000003).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';

void main() {
  test('exposesLabelsColorsAndLookupsAsLists', () {
    final a = LineDataSet([Entry(x: 0, y: 1)], 'A')
      ..colors = [const Color(0x00000001), const Color(0x00000002)];
    final b = LineDataSet([Entry(x: 0, y: 2)], 'B')
      ..color = const Color(0x00000003);
    final data = LineData([a, b]);

    expect(data.dataSetLabels, ['A', 'B']);
    expect(data.colors, [
      const Color(0x00000001),
      const Color(0x00000002),
      const Color(0x00000003),
    ]);
    expect(data.getDataSetByLabel('b', true), same(b));
    expect(data.getIndexOfDataSet(b), 1);
    expect(data.entryCount, 2);
  });
}
