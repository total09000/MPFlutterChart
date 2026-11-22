import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/day_axis_value_formatter.dart';
import 'package:mp_flutter_chart_example/custom/demo_drawables.dart';
import 'package:mp_flutter_chart_example/custom/my_axis_value_formatter.dart';
import 'package:mp_flutter_chart_example/custom/my_marker_view.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';
import 'package:mp_flutter_chart_example/pages/bar_chart_page.dart';

import '../support/pages.dart';

/// res/menu/bar.xml as BarChartActivity shows it, without the items this app leaves out.
const List<String> _menu = [
  'Toggle Bar Borders',
  'Toggle Rounded Sections',
  'Toggle Values',
  'Toggle Icons',
  'Toggle Highlight',
  'Toggle PinchZoom',
  'Toggle Auto Scale',
  'Animate X',
  'Animate Y',
  'Animate XY',
];

void main() {
  testWidgets('the page shows BarChartActivity\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const BarChartPage());

    expect(find.widgetWithText(AppBar, 'Basic'), findsOneWidget);
    expect(seekBars(tester), [12, 50]);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(await menuTitles(tester), _menu);

    final chart = chartOf<BarChartView>(tester);
    expect(chart.isDrawBarShadowEnabled, isFalse);
    expect(chart.isDrawValueAboveBarEnabled, isTrue);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.maxVisibleCount, 60);
    expect(chart.isPinchZoomEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.marker, isA<XYMarkerView>());

    final xAxis = chart.xAxis;
    expect(xAxis.position, XAxisPosition.BOTTOM);
    expect(xAxis.typeface, tfLight);
    expect(xAxis.isDrawGridLinesEnabled, isFalse);
    expect(xAxis.granularity, 1);
    expect(xAxis.labelCount, 7);
    expect(xAxis.valueFormatter, isA<DayAxisValueFormatter>());

    for (final axis in [chart.axisLeft, chart.axisRight]) {
      expect(axis.isEnabled, isTrue);
      expect(axis.typeface, tfLight);
      expect(axis.labelCount, 8);
      expect(axis.valueFormatter, isA<MyAxisValueFormatter>());
      expect(axis.spaceTop, 15);
      expect(axis.axisMinimum, 0);
    }
    expect(chart.axisLeft.labelPosition, YAxisLabelPosition.OUTSIDE_CHART);
    expect(chart.axisRight.isDrawGridLinesEnabled, isFalse);

    final legend = chart.legend;
    expect(legend.verticalAlignment, LegendVerticalAlignment.BOTTOM);
    expect(legend.horizontalAlignment, LegendHorizontalAlignment.LEFT);
    expect(legend.orientation, LegendOrientation.HORIZONTAL);
    expect(legend.isDrawInsideEnabled, isFalse);
    expect(legend.form, LegendForm.SQUARE);
    expect(legend.formSize, 9);
    expect(legend.textSize, 11);
    expect(legend.xEntrySpace, 4);

    final data = chart.data!;
    expect(data.barWidth, 0.9);
    final set = data.dataSets.single as BarDataSet;
    expect(set.label, 'The year 2017');
    expect(set.entryCount, 12);
    expect([for (final e in set.entries) e.x], [for (var i = 1; i <= 12; i++) i.toDouble()]);
    // Math.random() * (50 + 1)
    expect(ysOf(data), everyElement(inInclusiveRange(0, 51)));
    // About a quarter of the entries carry the star.
    final icons = [for (final e in set.entries) e.icon];
    expect(icons.where((icon) => icon != null), everyElement(same(starDrawable)));
    expect(icons, contains(isNull));
    expect(set.isDrawIconsEnabled, isFalse);
    expect(set.valueTextSize, 10);
    expect(set.valueTypeface, tfLight);
    expect([for (final fill in set.fills!) fill.gradientColors], [
      [const Color(0xFFFFBB33), const Color(0xFF0099CC)],
      [const Color(0xFF33B5E5), const Color(0xFFAA66CC)],
      [const Color(0xFFFFBB33), const Color(0xFF669900)],
      [const Color(0xFF99CC00), const Color(0xFFCC0000)],
      [const Color(0xFFFF4444), const Color(0xFFFF8800)],
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const BarChartPage());
    final first = ysOf(chartOf<BarChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const BarChartPage());
    expect(ysOf(chartOf<BarChartView>(tester).data!), first);
  });

  testWidgets('a seek bar gives the set new entries, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const BarChartPage());
    final chart = chartOf<BarChartView>(tester);
    final data = chart.data!;
    final set = data.dataSets.single;

    await setSeekBar(tester, 0, 30);
    expect(chart.data, same(data));
    expect(chart.data!.dataSets.single, same(set));
    expect(set.entryCount, 30);
    expect(find.text('30'), findsOneWidget);

    await setSeekBar(tester, 1, 9);
    expect(ysOf(chart.data!), everyElement(inInclusiveRange(0, 10)));
    expect(find.text('9'), findsOneWidget);

    tester.element(find.byType(BarChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(data));
    expect(set.entryCount, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a highlighted bar calls the listener and shows XYMarkerView', (tester) async {
    await pumpPage(tester, const BarChartPage());
    final chart = chartOf<BarChartView>(tester);

    chart.highlightValue(3, 0);
    await tester.pump();
    expect(chart.highlighted, hasLength(1));
    // Day 3 of 2016 while 12 days are visible, y with one decimal.
    expect((chart.marker! as XYMarkerView).text, startsWith('x: 3rd Jan, y: '));
    expect(tester.takeException(), isNull);
  });

  testWidgets('seekBar1 at 0 leaves the set without entries, as on Android', (tester) async {
    await pumpPage(tester, const BarChartPage());
    final chart = chartOf<BarChartView>(tester);

    await setSeekBar(tester, 0, 0);
    expect(chart.data!.dataSets.single.entryCount, 0);
    expect(tester.takeException(), isNull);

    await setSeekBar(tester, 0, 5);
    expect(chart.data!.dataSets.single.entryCount, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const BarChartPage());
    final chart = chartOf<BarChartView>(tester);
    BarDataSet set() => chart.data!.dataSets.single as BarDataSet;

    await selectMenuItem(tester, 'Toggle Bar Borders');
    expect(set().barBorderWidth, 1);
    await selectMenuItem(tester, 'Toggle Bar Borders');
    expect(set().barBorderWidth, 0);
    // No branch in onOptionsItemSelected.
    await selectMenuItem(tester, 'Toggle Rounded Sections');
    expect(set().isStackSectionsRounded, isFalse);
    expect(set().barCornerRadius, 0);
    await selectMenuItem(tester, 'Toggle Values');
    expect(set().isDrawValuesEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Icons');
    expect(set().isDrawIconsEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Highlight');
    expect(chart.data!.isHighlightEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle PinchZoom');
    expect(chart.isPinchZoomEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Auto Scale');
    expect(chart.isAutoScaleMinMaxEnabled, isTrue);

    for (final title in ['Animate X', 'Animate Y', 'Animate XY']) {
      await selectMenuItem(tester, title, settle: false);
      expect(chart.isAnimating, isTrue, reason: title);
      await tester.pumpAndSettle();
      expect(chart.isAnimating, isFalse, reason: title);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every menu item can be chosen twice', (tester) async {
    await pumpPage(tester, const BarChartPage());
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}
