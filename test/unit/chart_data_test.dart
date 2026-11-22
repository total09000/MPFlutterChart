// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/ChartDataTest.kt
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/components/y_axis_dependency.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/data/scatter_data.dart';
import 'package:mp_flutter_chart/src/data/scatter_data_set.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';

/// Kotlin `Float.MAX_VALUE`, the "no data" sentinel of the cached ranges.
const double _FLOAT_MAX = 3.4028234663852886e38;

void main() {
  test('dynamicChartData', () {
    final set1 = ScatterDataSet([
      Entry(x: 10, y: 10),
      Entry(x: 15, y: -2),
      Entry(x: 21, y: 50),
    ], '');
    final set2 = ScatterDataSet([
      Entry(x: -1, y: 10),
      Entry(x: 10, y: 2),
      Entry(x: 20, y: 5),
    ], '');

    final data = ScatterData([set1, set2]);

    expect(data.getYMin(AxisDependency.LEFT), closeTo(-2, 1e-4));
    expect(data.getYMax(AxisDependency.LEFT), closeTo(50, 1e-4));
    expect(data.entryCount, 6);
    expect(data.xMin, closeTo(-1, 1e-4));
    expect(data.xMax, closeTo(21, 1e-4));
    expect(data.yMin, closeTo(-2, 1e-4));
    expect(data.yMax, closeTo(50, 1e-4));
    expect(data.maxEntryCountSet!.entryCount, 3);

    data.addEntry(Entry(x: -10, y: -10), 0);

    expect(data.maxEntryCountSet, same(set1));
    expect(data.maxEntryCountSet!.entryCount, 4);
    expect(data.getYMin(AxisDependency.LEFT), closeTo(-10, 1e-4));
    expect(data.getYMax(AxisDependency.LEFT), closeTo(50, 1e-4));
    expect(data.xMin, closeTo(-10, 1e-4));
    expect(data.xMax, closeTo(21, 1e-4));
    expect(data.yMin, closeTo(-10, 1e-4));
    expect(data.yMax, closeTo(50, 1e-4));

    data.addEntry(Entry(x: -100, y: 100), 0);
    data.addEntry(Entry(x: 0, y: -100), 0);

    expect(data.getYMin(AxisDependency.LEFT), closeTo(-100, 1e-4));
    expect(data.getYMax(AxisDependency.LEFT), closeTo(100, 1e-4));
    expect(data.getYMin(AxisDependency.RIGHT), closeTo(-100, 1e-4));
    expect(data.getYMax(AxisDependency.RIGHT), closeTo(100, 1e-4));

    final set3 = ScatterDataSet([Entry(x: 0, y: 200), Entry(x: 0, y: -50)], '');
    set3.axisDependency = AxisDependency.RIGHT;
    data.addDataSet(set3);

    expect(data.dataSetCount, 3);
    expect(data.getYMin(AxisDependency.LEFT), closeTo(-100, 1e-4));
    expect(data.getYMax(AxisDependency.LEFT), closeTo(100, 1e-4));
    expect(data.getYMin(AxisDependency.RIGHT), closeTo(-50, 1e-4));
    expect(data.getYMax(AxisDependency.RIGHT), closeTo(200, 1e-4));

    final lineData = LineData();

    expect(lineData.yMin, closeTo(_FLOAT_MAX, 1e-4));
    expect(lineData.yMax, closeTo(-_FLOAT_MAX, 1e-4));
    expect(lineData.getYMin(AxisDependency.LEFT), closeTo(_FLOAT_MAX, 1e-4));
    expect(lineData.getYMax(AxisDependency.LEFT), closeTo(-_FLOAT_MAX, 1e-4));
    expect(lineData.getYMin(AxisDependency.RIGHT), closeTo(_FLOAT_MAX, 1e-4));
    expect(lineData.getYMax(AxisDependency.RIGHT), closeTo(-_FLOAT_MAX, 1e-4));
    expect(lineData.dataSetCount, 0);

    final lineSet1 = LineDataSet([
      Entry(x: 10, y: 90),
      Entry(x: 1000, y: 1000),
    ], '');
    lineData.addDataSet(lineSet1);

    expect(lineData.dataSetCount, 1);
    expect(lineSet1.entryCount, 2);
    expect(lineData.entryCount, 2);
    expect(lineData.xMin, closeTo(10, 1e-4));
    expect(lineData.xMax, closeTo(1000, 1e-4));
    expect(lineData.yMin, closeTo(90, 1e-4));
    expect(lineData.yMax, closeTo(1000, 1e-4));
    expect(lineData.getYMin(AxisDependency.LEFT), closeTo(90, 1e-4));
    expect(lineData.getYMax(AxisDependency.LEFT), closeTo(1000, 1e-4));
    expect(lineData.getYMin(AxisDependency.RIGHT), closeTo(90, 1e-4));
    expect(lineData.getYMax(AxisDependency.RIGHT), closeTo(1000, 1e-4));

    final e = Entry(x: -1000, y: 2500);
    final lineSet2 = LineDataSet([
      Entry(x: -1000, y: 2000),
      Entry(x: 2000, y: -3000),
      e,
    ], '');
    lineSet2.axisDependency = AxisDependency.RIGHT;
    lineData.addDataSet(lineSet2);

    expect(lineData.dataSetCount, 2);
    expect(lineSet2.entryCount, 3);
    expect(lineData.entryCount, 5);
    expect(lineData.xMin, closeTo(-1000, 1e-4));
    expect(lineData.xMax, closeTo(2000, 1e-4));
    expect(lineData.yMin, closeTo(-3000, 1e-4));
    expect(lineData.yMax, closeTo(2500, 1e-4));
    expect(lineData.getYMin(AxisDependency.LEFT), closeTo(90, 1e-4));
    expect(lineData.getYMax(AxisDependency.LEFT), closeTo(1000, 1e-4));
    expect(lineData.getYMin(AxisDependency.RIGHT), closeTo(-3000, 1e-4));
    expect(lineData.getYMax(AxisDependency.RIGHT), closeTo(2500, 1e-4));

    expect(lineData.removeEntry(e, 1), isTrue);

    expect(lineData.xMin, closeTo(-1000, 1e-4));
    expect(lineData.xMax, closeTo(2000, 1e-4));
    expect(lineData.yMin, closeTo(-3000, 1e-4));
    expect(lineData.yMax, closeTo(2000, 1e-4));
    expect(lineData.getYMin(AxisDependency.LEFT), closeTo(90, 1e-4));
    expect(lineData.getYMax(AxisDependency.LEFT), closeTo(1000, 1e-4));
    expect(lineData.getYMin(AxisDependency.RIGHT), closeTo(-3000, 1e-4));
    expect(lineData.getYMax(AxisDependency.RIGHT), closeTo(2000, 1e-4));
    expect(lineData.dataSetCount, 2);

    expect(lineData.removeDataSet(lineSet2), isTrue);

    expect(lineData.dataSetCount, 1);
    expect(lineData.xMin, closeTo(10, 1e-4));
    expect(lineData.xMax, closeTo(1000, 1e-4));
    expect(lineData.yMin, closeTo(90, 1e-4));
    expect(lineData.yMax, closeTo(1000, 1e-4));
    expect(lineData.getYMin(AxisDependency.LEFT), closeTo(90, 1e-4));
    expect(lineData.getYMax(AxisDependency.LEFT), closeTo(1000, 1e-4));
    expect(lineData.getYMin(AxisDependency.RIGHT), closeTo(90, 1e-4));
    expect(lineData.getYMax(AxisDependency.RIGHT), closeTo(1000, 1e-4));

    expect(lineData.removeDataSet(lineSet1), isTrue);

    expect(lineData.dataSetCount, 0);
    expect(lineData.xMin, closeTo(_FLOAT_MAX, 1e-4));
    expect(lineData.xMax, closeTo(-_FLOAT_MAX, 1e-4));
    expect(lineData.yMin, closeTo(_FLOAT_MAX, 1e-4));
    expect(lineData.yMax, closeTo(-_FLOAT_MAX, 1e-4));
    expect(lineData.getYMin(AxisDependency.LEFT), closeTo(_FLOAT_MAX, 1e-4));
    expect(lineData.getYMax(AxisDependency.LEFT), closeTo(-_FLOAT_MAX, 1e-4));
    expect(lineData.getYMin(AxisDependency.RIGHT), closeTo(_FLOAT_MAX, 1e-4));
    expect(lineData.getYMax(AxisDependency.RIGHT), closeTo(-_FLOAT_MAX, 1e-4));

    expect(lineData.removeDataSet(lineSet1), isFalse);
    expect(lineData.removeDataSet(lineSet2), isFalse);
  });

  // Not in the Kotlin test: ChartData.getEntryForHighlight (implemented in this task per Ruling R21).
  test(
    'getEntryForHighlight finds the closest entry of the highlighted set',
    () {
      final first = LineDataSet([
        Entry(x: 0, y: 1),
        Entry(x: 1, y: 5),
        Entry(x: 1, y: 9),
        Entry(x: 3, y: 2),
      ], '');
      final data = LineData([first, LineDataSet(<Entry>[], 'empty')]);

      expect(
        data.getEntryForHighlight(Highlight(1, 8, 0)),
        same(first.entries[2]),
      );
      expect(
        data.getEntryForHighlight(Highlight(2.6, double.nan, 0)),
        same(first.entries[3]),
      );
      expect(data.getEntryForHighlight(Highlight(0, 0, 1)), isNull);
      expect(data.getEntryForHighlight(Highlight(0, 0, 2)), isNull);
      expect(data.getEntryForHighlight(Highlight(0, 0, -1)), isNull);
    },
  );
}
