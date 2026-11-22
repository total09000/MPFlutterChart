// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for the pie and radar defaults, PieEntry /
// RadarEntry copies and labels, PieData.dataSet, the highlight lookups or a NaN corner radius. These tests pin those to
// the Kotlin sources. DataSetTest.kt's radarCornerRadiusIsNeverNegativeAndIsCopied runs in
// test/unit/data_set_test.dart.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/data/pie_data.dart';
import 'package:mp_flutter_chart/src/data/pie_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_entry.dart';
import 'package:mp_flutter_chart/src/data/radar_data.dart';
import 'package:mp_flutter_chart/src/data/radar_data_set.dart';
import 'package:mp_flutter_chart/src/data/radar_entry.dart';
import 'package:mp_flutter_chart/src/graphics/chart_drawable.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/interfaces/datasets/i_pie_data_set.dart';
import 'package:mp_flutter_chart/src/interfaces/datasets/i_radar_data_set.dart';
import 'package:mp_flutter_chart/src/utils/color_template.dart';
import 'package:mp_flutter_chart/src/utils/float_math.dart';

void main() {
  test('pieSliceSpaceIsClampedAndDefaultsMatchKotlin', () {
    final IPieDataSet<Object?> set = PieDataSet([PieEntry(1)], 'pie');
    expect(set.sliceSpace, 0);
    expect(set.isAutomaticallyDisableSliceSpacingEnabled, isFalse);
    expect(set.selectionShift, 9);
    expect(set.xValuePosition, ValuePosition.INSIDE_SLICE);
    expect(set.yValuePosition, ValuePosition.INSIDE_SLICE);
    expect(set.valueLineColor, const Color(0xFF000000));
    expect(set.isUseValueColorForLineEnabled, isFalse);
    expect(set.valueLineWidth, 1);
    expect(set.valueLinePart1OffsetPercentage, 75);
    expect(set.valueLinePart1Length, closeTo(0.3, 1e-4));
    expect(set.valueLinePart2Length, closeTo(0.4, 1e-4));
    expect(set.isValueLineVariableLength, isTrue);
    expect(set.highlightColor, isNull);

    final pie = set as PieDataSet;
    pie.sliceSpace = 7.5;
    expect(pie.sliceSpace, 7.5);
    pie.sliceSpace = 25;
    expect(pie.sliceSpace, 20);
    pie.sliceSpace = -3;
    expect(pie.sliceSpace, 0);
    // Kotlin coerceIn keeps NaN.
    pie.sliceSpace = double.nan;
    expect(pie.sliceSpace.isNaN, isTrue);
  });

  test('pieDataSetTracksOnlyTheYRange', () {
    final set = PieDataSet([
      PieEntry(5),
      PieEntry(-2),
      PieEntry(double.nan),
    ], 'pie');
    expect(set.yMin, -2);
    expect(set.yMax, 5);
    expect(set.xMin, kotlinFloatMaxValue);
    expect(set.xMax, -kotlinFloatMaxValue);

    set.addEntry(PieEntry(8));
    expect(set.yMax, 8);
    expect(set.xMin, kotlinFloatMaxValue);
    expect(set.xMax, -kotlinFloatMaxValue);
  });

  test('pieCopyKeepsTheEntriesAndInheritedStylingButNotThePieSettings', () {
    final set =
        PieDataSet<String>([
            PieEntry(1, label: 'a', data: 'x'),
            PieEntry(2, label: 'b'),
          ], 'pie')
          ..valueTextSize = 21
          ..sliceSpace = 4
          ..selectionShift = 3
          ..highlightColor = const Color(0xFF00FF00);

    final copy = set.copy() as PieDataSet<String>;
    expect(copy.label, 'pie');
    expect(copy.entryCount, 2);
    expect(copy.getEntryForIndex(0), isNot(same(set.getEntryForIndex(0))));
    expect(copy.getEntryForIndex(0).label, 'a');
    expect(copy.getEntryForIndex(0).data, 'x');
    expect(copy.getEntryForIndex(1).value, 2);
    expect(copy.valueTextSize, 21);
    // Kotlin's copy(pieDataSet) only calls super, so the pie settings keep their defaults.
    expect(copy.sliceSpace, 0);
    expect(copy.selectionShift, 9);
    expect(copy.highlightColor, isNull);
  });

  test('radarHighlightDefaultsMatchKotlin', () {
    final IRadarDataSet<Object?> set = RadarDataSet([RadarEntry(1)], 'radar');
    expect(set.cornerRadius, 0);
    expect(set.isDrawHighlightCircleEnabled, isFalse);
    expect(set.highlightCircleFillColor, const Color(0xFFFFFFFF));
    expect(set.highlightCircleStrokeColor, ColorTemplate.COLOR_NONE);
    expect(set.highlightCircleStrokeAlpha, 76);
    expect(set.highlightCircleInnerRadius, 3);
    expect(set.highlightCircleOuterRadius, 4);
    expect(set.highlightCircleStrokeWidth, 2);

    set.isDrawHighlightCircleEnabled = true;
    expect(set.isDrawHighlightCircleEnabled, isTrue);
  });

  test('radarCopyKeepsTheRadarStyling', () {
    final set =
        RadarDataSet<String>([RadarEntry(1, data: 'x'), RadarEntry(2)], 'radar')
          ..lineWidth = 3
          ..cornerRadius = 5
          ..isDrawHighlightCircleEnabled = true
          ..highlightCircleFillColor = const Color(0xFF112233)
          ..highlightCircleStrokeColor = const Color(0xFF445566)
          ..highlightCircleStrokeAlpha = 200
          ..highlightCircleInnerRadius = 6
          ..highlightCircleOuterRadius = 7
          ..highlightCircleStrokeWidth = 8;

    final copy = set.copy() as RadarDataSet<String>;
    expect(copy.label, 'radar');
    expect(copy.entryCount, 2);
    expect(copy.getEntryForIndex(0), isNot(same(set.getEntryForIndex(0))));
    expect(copy.getEntryForIndex(0).data, 'x');
    expect(copy.lineWidth, 3);
    expect(copy.cornerRadius, 5);
    expect(copy.isDrawHighlightCircleEnabled, isTrue);
    expect(copy.highlightCircleFillColor, const Color(0xFF112233));
    expect(copy.highlightCircleStrokeColor, const Color(0xFF445566));
    expect(copy.highlightCircleStrokeAlpha, 200);
    expect(copy.highlightCircleInnerRadius, 6);
    expect(copy.highlightCircleOuterRadius, 7);
    expect(copy.highlightCircleStrokeWidth, 8);
  });

  test('entryCopiesKeepTypeAndPayload', () {
    final pie = PieEntry<String>(3, label: 'x', data: 'p');
    expect(pie.x, 0);
    expect(pie.y, 3);
    final PieEntry<String> pieCopy = pie.copy();
    expect(pieCopy, isA<PieEntry<String>>());
    expect(pieCopy, isNot(same(pie)));
    expect(pieCopy.value, 3);
    expect(pieCopy.x, 0);
    expect(pieCopy.label, 'x');
    expect(pieCopy.data, 'p');

    final radar = RadarEntry<String>(4, data: 'q');
    expect(radar.x, 0);
    expect(radar.y, 4);
    final RadarEntry<String> radarCopy = radar.copy();
    expect(radarCopy, isA<RadarEntry<String>>());
    expect(radarCopy, isNot(same(radar)));
    expect(radarCopy.value, 4);
    expect(radarCopy.x, 0);
    expect(radarCopy.data, 'q');
  });

  test('entryCopiesShareTheIcon', () {
    // Kotlin's copy() passes the icon on: PieEntry(y, label, icon, data) and RadarEntry(y, icon, data).
    final icon = PainterDrawable((canvas, size) {}, width: 4, height: 4);
    final pie = PieEntry(1, label: 'a', icon: icon);
    expect(pie.copy().icon, same(icon));
    final radar = RadarEntry(2, icon: icon);
    expect(radar.copy().icon, same(icon));
    expect(PieEntry(1).copy().icon, isNull);
    expect(RadarEntry(2).copy().icon, isNull);
  });

  test('aPieEntryLabelIsWritable', () {
    // Kotlin's `public var label: String?`.
    final entry = PieEntry(1, label: 'a');
    entry.label = 'b';
    expect(entry.label, 'b');
    expect(entry.copy().label, 'b');
    entry.label = null;
    expect(entry.label, isNull);
    final set = PieDataSet([entry], 'pie');
    set.getEntryForIndex(0).label = 'c';
    expect(entry.label, 'c');
  });

  test('aNaNCornerRadiusIsStoredAsNaN', () {
    // Kotlin's coerceAtLeast(0f) is `if (this < 0f) 0f else this`, which keeps NaN; the copy keeps it too. Infinity
    // stays as it is; minus infinity becomes 0.
    final set = RadarDataSet([RadarEntry(1)], 'radar');
    set.cornerRadius = double.nan;
    expect(set.cornerRadius, isNaN);
    expect((set.copy() as RadarDataSet).cornerRadius, isNaN);
    set.cornerRadius = double.infinity;
    expect(set.cornerRadius, double.infinity);
    set.cornerRadius = double.negativeInfinity;
    expect(set.cornerRadius, 0);
  });

  test('pieDataSetSetterReplacesTheSet', () {
    final s = PieDataSet([PieEntry(4), PieEntry(6)], 'first');
    final data = PieData()..dataSet = s;
    expect(data.dataSets, [s]);
    expect(data.dataSet, same(s));
    expect(data.yMax, 6);
    expect(data.yValueSum, 10);

    final t = PieDataSet([PieEntry(1)], 'second');
    data.dataSet = t;
    expect(data.dataSets, [t]);
    expect(data.yMax, 1);

    data.dataSet = null;
    expect(data.dataSets, isEmpty);
    expect(data.dataSet, isNull);
    expect(data.yMax, -kotlinFloatMaxValue);
    expect(data.yValueSum, 0);
  });

  test('highlightsFindTheEntryAtTheirIndex', () {
    final pie = PieDataSet([
      PieEntry(1, label: 'a'),
      PieEntry(2, label: 'b'),
    ], 'pie');
    final pieData = PieData(pie);
    // Highlight.x holds the entry index; the data set index is ignored for pie data.
    expect(
      pieData.getEntryForHighlight(Highlight(1, 0, 0)),
      same(pie.getEntryForIndex(1)),
    );
    expect(
      pieData.getEntryForHighlight(Highlight(1.9, 0, 3)),
      same(pie.getEntryForIndex(1)),
    );
    expect(pieData.getDataSetByIndex(0), same(pie));
    expect(pieData.getDataSetByIndex(1), isNull);
    expect(pieData.getDataSetByLabel('pie', false), same(pie));
    expect(pieData.getDataSetByLabel('PIE', false), isNull);
    // Kotlin Float.toInt() gives 0 for NaN instead of throwing.
    expect(
      pieData.getEntryForHighlight(Highlight(double.nan, 0, 0)),
      same(pie.getEntryForIndex(0)),
    );

    final short = RadarDataSet([RadarEntry(1)], 'short');
    final long = RadarDataSet([RadarEntry(1), RadarEntry(2)], 'long');
    final radarData = RadarData([short, long]);
    expect(
      radarData.getEntryForHighlight(Highlight(1, 0, 1)),
      same(long.getEntryForIndex(1)),
    );
    expect(
      radarData.getEntryForHighlight(Highlight(0, 0, 0)),
      same(short.getEntryForIndex(0)),
    );
    expect(radarData.getEntryForHighlight(Highlight(0, 0, 2)), isNull);
    expect(RadarData().getEntryForHighlight(Highlight(0, 0, 0)), isNull);

    // Kotlin Float.toInt() clamps the infinities to Int.MAX_VALUE and Int.MIN_VALUE, both outside `0 until
    // entryCount`, so there is no entry, and no exception, for them. NaN picks entry 0 here too.
    for (final x in [double.infinity, double.negativeInfinity]) {
      expect(pieData.getEntryForHighlight(Highlight(x, 0, 0)), isNull);
      expect(radarData.getEntryForHighlight(Highlight(x, 0, 1)), isNull);
    }
    expect(
      radarData.getEntryForHighlight(Highlight(double.nan, 0, 1)),
      same(long.getEntryForIndex(0)),
    );
  });
}
