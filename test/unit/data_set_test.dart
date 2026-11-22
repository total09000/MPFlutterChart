// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/DataSetTest.kt
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/data_set.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/data/radar_data_set.dart';
import 'package:mp_flutter_chart/src/data/radar_entry.dart';
import 'package:mp_flutter_chart/src/data/scatter_data_set.dart';
import 'package:mp_flutter_chart/src/highlight/highlight_line_span.dart';

void main() {
  test('newHighlightAndStackStylingIsCopied', () {
    final line = LineDataSet([Entry(x: 0, y: 1)], 'line');
    line.verticalHighlightIndicatorSpan = HighlightLineSpan.TO_ENTRY;
    line.horizontalHighlightIndicatorSpan = HighlightLineSpan.FROM_ENTRY;
    final lineCopy = line.copy() as LineDataSet;
    expect(lineCopy.verticalHighlightIndicatorSpan, HighlightLineSpan.TO_ENTRY);
    expect(
      lineCopy.horizontalHighlightIndicatorSpan,
      HighlightLineSpan.FROM_ENTRY,
    );
  });

  test('newHighlightAndStackStylingIsCopied (bar part)', () {
    final bar = BarDataSet([
      BarEntry.stacked(x: 0, stackValues: [1, 2]),
    ], 'bar');
    bar.isStackSectionsRounded = true;
    expect((bar.copy() as BarDataSet).isStackSectionsRounded, isTrue);
  });

  test('aValueThatIsNotANumberIsRemembered', () {
    final clean = LineDataSet([Entry(x: 0, y: 1), Entry(x: 1, y: 2)], 'clean');
    expect(clean.hasNonFiniteY, isFalse);

    final withGap = LineDataSet([
      Entry(x: 0, y: 1),
      Entry(x: 1, y: double.nan),
      Entry(x: 2, y: 3),
    ], 'gap');
    expect(withGap.hasNonFiniteY, isTrue);

    final infinite = LineDataSet([Entry(x: 0, y: double.infinity)], 'infinite');
    expect(infinite.hasNonFiniteY, isTrue);
  });

  test('calcMinMax', () {
    final set = ScatterDataSet([
      Entry(x: 10, y: 10),
      Entry(x: 15, y: 2),
      Entry(x: 21, y: 5),
    ], '');

    expect(set.xMin, closeTo(10, 1e-4));
    expect(set.xMax, closeTo(21, 1e-4));
    expect(set.yMin, closeTo(2, 1e-4));
    expect(set.yMax, closeTo(10, 1e-4));
    expect(set.entryCount, 3);

    set.addEntry(Entry(x: 25, y: 1));

    expect(set.xMin, closeTo(10, 1e-4));
    expect(set.xMax, closeTo(25, 1e-4));
    expect(set.yMin, closeTo(1, 1e-4));
    expect(set.yMax, closeTo(10, 1e-4));
    expect(set.entryCount, 4);

    set.removeEntryByIndex(3);

    expect(set.xMin, closeTo(10, 1e-4));
    expect(set.xMax, closeTo(21, 1e-4));
    expect(set.yMin, closeTo(2, 1e-4));
    expect(set.yMax, closeTo(10, 1e-4));
  });

  test('addRemoveEntry', () {
    final set = ScatterDataSet([
      Entry(x: 10, y: 10),
      Entry(x: 15, y: 2),
      Entry(x: 21, y: 5),
    ], '');

    expect(set.entryCount, 3);

    set.addEntryOrdered(Entry(x: 5, y: 1));

    expect(set.entryCount, 4);
    expect(set.xMin, closeTo(5, 1e-4));
    expect(set.xMax, closeTo(21, 1e-4));
    expect(set.yMin, closeTo(1, 1e-4));
    expect(set.yMax, closeTo(10, 1e-4));
    expect(set.getEntryForIndex(0).x, closeTo(5, 1e-4));
    expect(set.getEntryForIndex(0).y, closeTo(1, 1e-4));

    set.addEntryOrdered(Entry(x: 20, y: 50));

    expect(set.entryCount, 5);
    expect(set.getEntryForIndex(3).x, closeTo(20, 1e-4));
    expect(set.getEntryForIndex(3).y, closeTo(50, 1e-4));

    expect(set.removeEntryByIndex(3), isTrue);

    expect(set.entryCount, 4);
    expect(set.getEntryForIndex(3).x, closeTo(21, 1e-4));
    expect(set.getEntryForIndex(3).y, closeTo(5, 1e-4));
    expect(set.getEntryForIndex(0).x, closeTo(5, 1e-4));
    expect(set.getEntryForIndex(0).y, closeTo(1, 1e-4));

    expect(set.removeFirst(), isTrue);

    expect(set.entryCount, 3);
    expect(set.getEntryForIndex(0).x, closeTo(10, 1e-4));
    expect(set.getEntryForIndex(0).y, closeTo(10, 1e-4));

    set.addEntryOrdered(Entry(x: 15, y: 3));

    expect(set.entryCount, 4);
    expect(set.getEntryForIndex(1).x, closeTo(15, 1e-4));
    expect(set.getEntryForIndex(1).y, closeTo(3, 1e-4));
    expect(set.getEntryForIndex(3).x, closeTo(21, 1e-4));
    expect(set.getEntryForIndex(3).y, closeTo(5, 1e-4));

    expect(set.removeLast(), isTrue);

    expect(set.entryCount, 3);
    expect(set.getEntryForIndex(2).x, closeTo(15, 1e-4));
    expect(set.getEntryForIndex(2).y, closeTo(2, 1e-4));

    expect(set.removeLast(), isTrue);
    expect(set.entryCount, 2);

    expect(set.removeLast(), isTrue);
    expect(set.entryCount, 1);
    expect(set.getEntryForIndex(0).x, closeTo(10, 1e-4));
    expect(set.getEntryForIndex(0).y, closeTo(10, 1e-4));

    expect(set.removeLast(), isTrue);
    expect(set.entryCount, 0);

    expect(set.removeLast(), isFalse);
    expect(set.removeFirst(), isFalse);
  });

  test('getEntryForXValue', () {
    final set = ScatterDataSet([
      Entry(x: 10, y: 10),
      Entry(x: 15, y: 5),
      Entry(x: 21, y: 5),
    ], '');

    var closest = set.getEntryForXValue(17, double.nan, Rounding.CLOSEST)!;
    expect(closest.x, closeTo(15, 1e-4));
    expect(closest.y, closeTo(5, 1e-4));

    closest = set.getEntryForXValue(17, double.nan, Rounding.DOWN)!;
    expect(closest.x, closeTo(15, 1e-4));
    expect(closest.y, closeTo(5, 1e-4));

    closest = set.getEntryForXValue(15, double.nan, Rounding.DOWN)!;
    expect(closest.x, closeTo(15, 1e-4));
    expect(closest.y, closeTo(5, 1e-4));

    closest = set.getEntryForXValue(14, double.nan, Rounding.DOWN)!;
    expect(closest.x, closeTo(10, 1e-4));
    expect(closest.y, closeTo(10, 1e-4));

    closest = set.getEntryForXValue(17, double.nan, Rounding.UP)!;
    expect(closest.x, closeTo(21, 1e-4));
    expect(closest.y, closeTo(5, 1e-4));

    closest = set.getEntryForXValue(21, double.nan, Rounding.UP)!;
    expect(closest.x, closeTo(21, 1e-4));
    expect(closest.y, closeTo(5, 1e-4));

    closest = set.getEntryForXValue(21, double.nan, Rounding.CLOSEST)!;
    expect(closest.x, closeTo(21, 1e-4));
    expect(closest.y, closeTo(5, 1e-4));
  });

  test('getEntryForXValueWithDuplicates', () {
    final values = [
      Entry(x: 0, y: 10),
      Entry(x: 1, y: 20),
      Entry(x: 2, y: 30),
      Entry(x: 3, y: 40),
      Entry(x: 3, y: 50),
      Entry(x: 4, y: 60),
      Entry(x: 4, y: 70),
      Entry(x: 5, y: 80),
      Entry(x: 6, y: 90),
      Entry(x: 7, y: 100),
      Entry(x: 8, y: 110),
      Entry(x: 8, y: 120),
    ];
    final set = ScatterDataSet(values, '');

    var closest = set.getEntryForXValue(0, double.nan, Rounding.CLOSEST)!;
    expect(closest.x, closeTo(0, 1e-4));
    expect(closest.y, closeTo(10, 1e-4));

    closest = set.getEntryForXValue(5, double.nan, Rounding.CLOSEST)!;
    expect(closest.x, closeTo(5, 1e-4));
    expect(closest.y, closeTo(80, 1e-4));

    closest = set.getEntryForXValue(5.4, double.nan, Rounding.CLOSEST)!;
    expect(closest.x, closeTo(5, 1e-4));
    expect(closest.y, closeTo(80, 1e-4));

    closest = set.getEntryForXValue(4.6, double.nan, Rounding.CLOSEST)!;
    expect(closest.x, closeTo(5, 1e-4));
    expect(closest.y, closeTo(80, 1e-4));

    closest = set.getEntryForXValue(7, double.nan, Rounding.CLOSEST)!;
    expect(closest.x, closeTo(7, 1e-4));
    expect(closest.y, closeTo(100, 1e-4));

    closest = set.getEntryForXValue(4, double.nan, Rounding.CLOSEST)!;
    expect(closest.x, closeTo(4, 1e-4));
    expect(closest.y, closeTo(60, 1e-4));

    var entries = set.getEntriesForXValue(4);
    expect(entries.length, 2);
    expect(entries[0].y, closeTo(60, 1e-4));
    expect(entries[1].y, closeTo(70, 1e-4));

    entries = set.getEntriesForXValue(3.5);
    expect(entries.length, 0);

    entries = set.getEntriesForXValue(2);
    expect(entries.length, 1);
    expect(entries[0].y, closeTo(30, 1e-4));
  });

  test('radarCornerRadiusIsNeverNegativeAndIsCopied', () {
    final set = RadarDataSet([
      RadarEntry(4),
      RadarEntry(8),
      RadarEntry(6),
    ], 'skills');
    expect(set.cornerRadius, closeTo(0, 0.01));

    set.cornerRadius = 12;
    expect(set.cornerRadius, closeTo(12, 0.01));

    set.cornerRadius = -5;
    expect(set.cornerRadius, closeTo(0, 0.01));

    set.cornerRadius = 9;
    final copy = set.copy() as RadarDataSet;
    expect(copy.cornerRadius, closeTo(9, 0.01));
  });
}
