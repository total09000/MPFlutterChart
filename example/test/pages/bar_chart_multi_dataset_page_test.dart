import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/my_marker_view.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';
import 'package:mp_flutter_chart_example/pages/bar_chart_multi_dataset_page.dart';

import '../support/pages.dart';

/// res/menu/bar.xml as BarChartActivityMultiDataset shows it, without the items this app leaves out.
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
  testWidgets('the page shows BarChartActivityMultiDataset\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const BarChartMultiDatasetPage());

    expect(find.widgetWithText(AppBar, 'Multiple'), findsOneWidget);
    expect(seekBars(tester), [10, 100]);
    expect(tester.widget<Slider>(find.byType(Slider).first).max, 50);
    expect(tester.widget<Slider>(find.byType(Slider).last).max, 200);
    expect(find.text('1980-1991'), findsOneWidget);
    expect(tester.widget<Text>(find.text('1980-1991')).style!.fontSize, 10);
    expect(find.text('100'), findsOneWidget);
    expect(await menuTitles(tester), _menu);

    final chart = chartOf<BarChartView>(tester);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.isPinchZoomEnabled, isFalse);
    expect(chart.isDrawBarShadowEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.marker, isA<MyMarkerView>());

    final legend = chart.legend;
    expect(legend.verticalAlignment, LegendVerticalAlignment.TOP);
    expect(legend.horizontalAlignment, LegendHorizontalAlignment.RIGHT);
    expect(legend.orientation, LegendOrientation.VERTICAL);
    expect(legend.isDrawInsideEnabled, isTrue);
    expect(legend.typeface, tfLight);
    expect(legend.yOffset, 0);
    expect(legend.xOffset, 10);
    expect(legend.yEntrySpace, 0);
    expect(legend.textSize, 8);

    final xAxis = chart.xAxis;
    expect(xAxis.typeface, tfLight);
    expect(xAxis.granularity, 1);
    expect(xAxis.isCenterAxisLabelsEnabled, isTrue);
    expect(xAxis.valueFormatter.getFormattedValue(1984.6, xAxis), '1984');
    // startYear + groupWidth * groupCount, a group being (0.2 + 0.03) * 4 + 0.08 = 1 wide.
    expect(xAxis.axisMinimum, 1980);
    expect(xAxis.axisMaximum, closeTo(1991, 1e-6));

    expect(chart.axisLeft.typeface, tfLight);
    expect(chart.axisLeft.valueFormatter, isA<LargeValueFormatter>());
    expect(chart.axisLeft.isDrawGridLinesEnabled, isFalse);
    expect(chart.axisLeft.spaceTop, 35);
    expect(chart.axisLeft.axisMinimum, 0);
    expect(chart.axisRight.isEnabled, isFalse);

    final data = chart.data!;
    expect(data.barWidth, 0.2);
    expect([for (final set in data.dataSets) set.label], ['Company A', 'Company B', 'Company C', 'Company D']);
    expect([for (final set in data.dataSets) set.color], const [
      Color.fromARGB(255, 104, 241, 175),
      Color.fromARGB(255, 164, 228, 251),
      Color.fromARGB(255, 242, 247, 158),
      Color.fromARGB(255, 255, 102, 0),
    ]);
    expect([for (final set in data.dataSets) set.entryCount], [11, 11, 11, 11]);
    expect([for (final set in data.dataSets) set.valueFormatter], everyElement(isA<LargeValueFormatter>()));
    expect([for (final set in data.dataSets) set.valueTypeface], everyElement(tfLight));
    // Math.random() * 100 * 100000
    expect(ysOf(data), everyElement(inInclusiveRange(0, 10000000)));
    // groupBars moved the bars into their year's group.
    for (final set in data.dataSets) {
      for (var i = 0; i < set.entryCount; i++) {
        expect(set.getEntryForIndex(i).x, inExclusiveRange(1980 + i, 1981 + i));
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const BarChartMultiDatasetPage());
    final first = ysOf(chartOf<BarChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const BarChartMultiDatasetPage());
    expect(ysOf(chartOf<BarChartView>(tester).data!), first);
  });

  testWidgets('a seek bar gives the sets new entries and regroups them, which a later rebuild keeps', (tester) async {
    await pumpPage(tester, const BarChartMultiDatasetPage());
    final chart = chartOf<BarChartView>(tester);
    final data = chart.data!;
    final sets = data.dataSets.toList();

    await setSeekBar(tester, 0, 20);
    expect(chart.data, same(data));
    expect(chart.data!.dataSets, sets);
    expect([for (final set in sets) set.entryCount], [21, 21, 21, 21]);
    expect(chart.xAxis.axisMaximum, closeTo(2001, 1e-6));
    expect(find.text('1980-2001'), findsOneWidget);

    await setSeekBar(tester, 1, 1);
    expect(ysOf(chart.data!), everyElement(inInclusiveRange(0, 100000)));
    expect(find.text('1'), findsOneWidget);

    tester.element(find.byType(BarChartMultiDatasetPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(data));
    expect([for (final set in sets) set.entryCount], [21, 21, 21, 21]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a highlighted bar shows MyMarkerView', (tester) async {
    await pumpPage(tester, const BarChartMultiDatasetPage());
    final chart = chartOf<BarChartView>(tester);
    final entry = chart.data!.dataSets[2].getEntryForIndex(4);

    chart.highlightValue(entry.x, 2);
    await tester.pump();
    expect(chart.highlighted, hasLength(1));
    expect((chart.marker! as MyMarkerView).text, Utils.formatNumber(entry.y, 0, true));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const BarChartMultiDatasetPage());
    final chart = chartOf<BarChartView>(tester);
    List<BarDataSet> sets() => chart.data!.dataSets.cast<BarDataSet>();

    await selectMenuItem(tester, 'Toggle Bar Borders');
    expect([for (final set in sets()) set.barBorderWidth], everyElement(1));
    await selectMenuItem(tester, 'Toggle Bar Borders');
    expect([for (final set in sets()) set.barBorderWidth], everyElement(0));
    // No branch in onOptionsItemSelected for these two.
    await selectMenuItem(tester, 'Toggle Rounded Sections');
    expect([for (final set in sets()) set.isStackSectionsRounded], everyElement(isFalse));
    await selectMenuItem(tester, 'Toggle Icons');
    expect([for (final set in sets()) set.isDrawIconsEnabled], everyElement(isTrue));
    await selectMenuItem(tester, 'Toggle Values');
    expect([for (final set in sets()) set.isDrawValuesEnabled], everyElement(isFalse));
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
    await pumpPage(tester, const BarChartMultiDatasetPage());
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}
