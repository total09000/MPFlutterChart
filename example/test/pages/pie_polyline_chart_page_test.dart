import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/pages/pie_polyline_chart_page.dart';

import '../support/pages.dart';

/// res/menu/pie.xml, without the items this app leaves out.
const List<String> _menu = [
  'Toggle Y-Values',
  'Toggle X-Values',
  'Toggle Icons',
  'Toggle Percent',
  'Toggle Minimum Angles',
  'Toggle Hole',
  'Toggle Curved Slices',
  'Draw Center Text',
  'Spin Animation',
  'Animate X',
  'Animate Y',
  'Animate XY',
];

void main() {
  testWidgets('the page shows PiePolylineChartActivity\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const PiePolylineChartPage());

    expect(find.widgetWithText(AppBar, 'Value Lines'), findsOneWidget);
    final chart = chartOf<PieChartView>(tester);
    // animateY(1400, Easing.EaseInOutQuad) from onCreate.
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();

    expect(seekBars(tester), [4, 100]);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(await menuTitles(tester), _menu);

    expect(chart.description.isEnabled, isFalse);
    expect(chart.isUsePercentValuesEnabled, isTrue);
    expect(chart.dragDecelerationFrictionCoef, closeTo(0.95, 1e-6));
    expect(chart.centerText, 'MPAndroidChart\ndeveloped by Philipp Jahoda');
    expect(chart.isDrawHoleEnabled, isTrue);
    expect(chart.holeRadius, 58);
    expect(chart.transparentCircleRadius, 61);
    expect(chart.transparentCircleAlpha, 110);
    expect(chart.rotationAngle, 0);
    expect(chart.isRotationEnabled, isTrue);
    expect(chart.legend.isEnabled, isFalse);
    expect(chart.legend.orientation, LegendOrientation.VERTICAL);

    final data = chart.data!;
    final set = data.dataSets.single as PieDataSet;
    expect(set.label, 'Election Results');
    expect(set.entryCount, 4);
    expect([for (var i = 0; i < 4; i++) set.getEntryForIndex(i).label], ['Party A', 'Party B', 'Party C', 'Party D']);
    // (Math.random() * 100) + 100 / 5
    expect(ysOf(data), everyElement(inInclusiveRange(20, 120)));
    expect(set.sliceSpace, 3);
    expect(set.selectionShift, 5);
    expect(set.valueLinePart1OffsetPercentage, 80);
    expect(set.valueLinePart1Length, closeTo(0.2, 1e-6));
    expect(set.valueLinePart2Length, closeTo(0.4, 1e-6));
    expect(set.yValuePosition, ValuePosition.OUTSIDE_SLICE);
    expect(set.colors, [
      ...ColorTemplate.VORDIPLOM_COLORS,
      ...ColorTemplate.JOYFUL_COLORS,
      ...ColorTemplate.COLORFUL_COLORS,
      ...ColorTemplate.LIBERTY_COLORS,
      ...ColorTemplate.PASTEL_COLORS,
      ColorTemplate.holoBlue,
    ]);
    expect(set.valueFormatter, isA<PercentFormatter>());
    expect(set.valueTextColor, const Color(0xFF000000));
    expect(chart.highlighted, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const PiePolylineChartPage());
    final first = ysOf(chartOf<PieChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const PiePolylineChartPage());
    expect(ysOf(chartOf<PieChartView>(tester).data!), first);
    await tester.pumpAndSettle();
  });

  testWidgets('a seek bar sets new data, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const PiePolylineChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<PieChartView>(tester);
    final before = chart.data;

    await setSeekBar(tester, 0, 25);
    final data = chart.data!;
    expect(data, isNot(same(before)));
    expect(data.dataSets.single.entryCount, 25);
    expect(data.dataSets.single.getEntryForIndex(24).label, 'Party Y');
    expect(find.text('25'), findsOneWidget);

    await setSeekBar(tester, 1, 200);
    expect(ysOf(chart.data!), everyElement(inInclusiveRange(40, 240)));
    expect(find.text('200'), findsOneWidget);

    final shown = chart.data;
    tester.element(find.byType(PiePolylineChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the seek bars can reach both ends', (tester) async {
    await pumpPage(tester, const PiePolylineChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<PieChartView>(tester);

    await setSeekBar(tester, 1, 0);
    await tester.pump();
    expect(ysOf(chart.data!), everyElement(0));
    expect(tester.takeException(), isNull);

    await setSeekBar(tester, 0, 0);
    await tester.pump();
    expect(chart.data!.dataSets.single.entryCount, 0);
    expect(tester.takeException(), isNull);

    await setSeekBar(tester, 0, 25);
    await setSeekBar(tester, 1, 200);
    await tester.pump();
    expect(chart.data!.dataSets.single.entryCount, 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const PiePolylineChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<PieChartView>(tester);
    PieDataSet set() => chart.data!.dataSets.single as PieDataSet;

    await selectMenuItem(tester, 'Toggle Y-Values');
    expect(set().isDrawValuesEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle X-Values');
    expect(chart.isDrawEntryLabelsEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Percent');
    expect(chart.isUsePercentValuesEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Minimum Angles');
    expect(chart.minAngleForSlices, 36);
    await selectMenuItem(tester, 'Toggle Minimum Angles');
    expect(chart.minAngleForSlices, 0);
    await selectMenuItem(tester, 'Toggle Hole');
    expect(chart.isDrawHoleEnabled, isFalse);
    // With the hole off, Toggle Curved Slices turns the rounded slices and the hole on.
    await selectMenuItem(tester, 'Toggle Curved Slices');
    expect(chart.isDrawRoundedSlicesEnabled, isTrue);
    expect(chart.isDrawHoleEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Curved Slices');
    expect(chart.isDrawRoundedSlicesEnabled, isFalse);
    await selectMenuItem(tester, 'Draw Center Text');
    expect(chart.isDrawCenterTextEnabled, isFalse);

    final icons = [for (final s in chart.data!.dataSets) s.isDrawIconsEnabled];
    await selectMenuItem(tester, 'Toggle Icons');
    expect([for (final s in chart.data!.dataSets) s.isDrawIconsEnabled], icons);

    await selectMenuItem(tester, 'Spin Animation', settle: false);
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    // A full turn from 0 back to 0.
    expect(chart.rotationAngle, anyOf(closeTo(0, 1e-3), closeTo(360, 1e-3)));

    for (final title in ['Animate X', 'Animate Y', 'Animate XY']) {
      await selectMenuItem(tester, title, settle: false);
      expect(chart.isAnimating, isTrue, reason: title);
      await tester.pumpAndSettle();
      expect(chart.isAnimating, isFalse, reason: title);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every menu item can be chosen twice', (tester) async {
    await pumpPage(tester, const PiePolylineChartPage());
    await tester.pumpAndSettle();
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}
