// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/PieDataTest.kt
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/data/pie_data.dart';
import 'package:mp_flutter_chart/src/data/pie_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_entry.dart';

void main() {
  test('sumsValuesAndFindsDataSetByLabel', () {
    final set = PieDataSet([
      PieEntry(10, label: 'A'),
      PieEntry(30, label: 'B'),
      PieEntry(60, label: 'C'),
    ], 'Parties');
    final data = PieData(set);
    expect(data.yValueSum, closeTo(100, 0.001));
    expect(data.entryCount, 3);
    expect(data.yMax, closeTo(60, 0.001));
    expect(data.getDataSetByLabel('parties', true), same(set));
    expect(data.getDataSetByLabel('other', true), isNull);
    expect(set.getEntryForIndex(1).label, 'B');
  });
}
