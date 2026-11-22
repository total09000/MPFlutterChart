import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/demo_drawables.dart';
import 'package:mp_flutter_chart_example/pages/pie_chart_page.dart';

import '../support/pages.dart';

/// res/menu/pie.xml as PieChartActivity shows it, without the items this app leaves out.
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
  testWidgets('the page shows PieChartActivity\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const PieChartPage());
    final chart = chartOf<PieChartView>(tester);
    // animateY(1400, EaseInOutQuad) from onCreate.
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);

    expect(find.widgetWithText(AppBar, 'Basic'), findsOneWidget);
    expect(seekBars(tester), [4, 10]);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(await menuTitles(tester), _menu);

    expect(chart.isUsePercentValuesEnabled, isTrue);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.dragDecelerationFrictionCoef, closeTo(0.95, 1e-6));
    expect(chart.centerText, 'MPAndroidChart\ndeveloped by Philipp Jahoda');
    expect(chart.isDrawHoleEnabled, isTrue);
    expect(chart.holeColor, const Color(0xFFFFFFFF));
    expect(chart.transparentCircleRadius, 61);
    expect(chart.holeRadius, 58);
    expect(chart.isDrawCenterTextEnabled, isTrue);
    expect(chart.rotationAngle, 0);
    expect(chart.isRotationEnabled, isTrue);
    expect(chart.entryLabelTextSize, 12);
    expect(chart.legend.verticalAlignment, LegendVerticalAlignment.TOP);
    expect(chart.legend.horizontalAlignment, LegendHorizontalAlignment.RIGHT);
    expect(chart.legend.orientation, LegendOrientation.VERTICAL);
    expect(chart.legend.xEntrySpace, 7);

    final data = chart.data!;
    final set = data.dataSet! as PieDataSet;
    expect(set.label, 'Election Results');
    expect(set.entryCount, 4);
    expect([for (var i = 0; i < 4; i++) set.getEntryForIndex(i).label], ['Party A', 'Party B', 'Party C', 'Party D']);
    expect(set.getEntryForIndex(0).icon, same(starDrawable));
    // (Math.random() * 10) + 10 / 5
    expect(ysOf(data), everyElement(inInclusiveRange(2, 12)));
    expect(set.isDrawIconsEnabled, isFalse);
    expect(set.sliceSpace, 3);
    expect(set.selectionShift, 5);
    expect(set.colors.length, 26);
    expect(set.colors.last, ColorTemplate.holoBlue);
    expect(set.valueFormatter, isA<PercentFormatter>());
    expect(set.valueTextSize, 11);
    expect(chart.highlighted, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const PieChartPage());
    await tester.pumpAndSettle();
    final first = ysOf(chartOf<PieChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const PieChartPage());
    await tester.pumpAndSettle();
    expect(ysOf(chartOf<PieChartView>(tester).data!), first);
  });

  testWidgets('a seek bar sets new data, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const PieChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<PieChartView>(tester);
    final before = chart.data;

    await setSeekBar(tester, 0, 25);
    final data = chart.data!;
    expect(data, isNot(same(before)));
    expect(data.dataSet!.entryCount, 25);
    expect(data.dataSet!.getEntryForIndex(24).label, 'Party Y');
    expect(find.text('25'), findsOneWidget);

    await setSeekBar(tester, 1, 100);
    // (Math.random() * 100) + 100 / 5
    expect(ysOf(chart.data!), everyElement(inInclusiveRange(20, 120)));
    expect(find.text('100'), findsOneWidget);

    final shown = chart.data;
    tester.element(find.byType(PieChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const PieChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<PieChartView>(tester);
    IPieDataSet set() => chart.data!.dataSet!;

    await selectMenuItem(tester, 'Toggle Y-Values');
    expect(set().isDrawValuesEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle X-Values');
    expect(chart.isDrawEntryLabelsEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Icons');
    expect(set().isDrawIconsEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Percent');
    expect(chart.isUsePercentValuesEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Minimum Angles');
    expect(chart.minAngleForSlices, 36);
    await selectMenuItem(tester, 'Toggle Minimum Angles');
    expect(chart.minAngleForSlices, 0);
    await selectMenuItem(tester, 'Toggle Hole');
    expect(chart.isDrawHoleEnabled, isFalse);
    // Curved slices need the hole, so the item turns it back on.
    await selectMenuItem(tester, 'Toggle Curved Slices');
    expect(chart.isDrawRoundedSlicesEnabled, isTrue);
    expect(chart.isDrawHoleEnabled, isTrue);
    expect(chart.isDrawSlicesUnderHoleEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Curved Slices');
    expect(chart.isDrawRoundedSlicesEnabled, isFalse);
    await selectMenuItem(tester, 'Draw Center Text');
    expect(chart.isDrawCenterTextEnabled, isFalse);

    // spin(1000, angle, angle + 360, EaseInOutCubic): the pie turns once and stops where it started.
    final angle = chart.rotationAngle;
    await selectMenuItem(tester, 'Spin Animation', settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(chart.rotationAngle, isNot(angle));
    await tester.pumpAndSettle();
    expect(chart.rotationAngle % 360, closeTo(angle % 360, 1e-3));

    for (final title in ['Animate X', 'Animate Y', 'Animate XY']) {
      await selectMenuItem(tester, title, settle: false);
      expect(chart.isAnimating, isTrue, reason: title);
      await tester.pumpAndSettle();
      expect(chart.isAnimating, isFalse, reason: title);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every menu item can be chosen twice', (tester) async {
    await pumpPage(tester, const PieChartPage());
    await tester.pumpAndSettle();
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}
