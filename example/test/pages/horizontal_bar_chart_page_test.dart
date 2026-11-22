import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/demo_drawables.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';
import 'package:mp_flutter_chart_example/pages/horizontal_bar_chart_page.dart';

import '../support/pages.dart';

/// res/menu/bar.xml as HorizontalBarChartActivity shows it, without the items this app leaves out.
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
  testWidgets('the page shows HorizontalBarChartActivity\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const HorizontalBarChartPage());
    final chart = chartOf<HorizontalBarChartView>(tester);
    // onCreate's animateY(2500).
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);

    expect(find.widgetWithText(AppBar, 'Horizontal'), findsOneWidget);
    expect(seekBars(tester), [12, 50]);
    expect(tester.widget<Slider>(find.byType(Slider).first).max, 500);
    expect(tester.widget<Slider>(find.byType(Slider).last).max, 200);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(await menuTitles(tester), _menu);
    // android:background="@android:color/white".
    final white = find.byWidgetPredicate((w) => w is ColoredBox && w.color == const Color(0xFFFFFFFF));
    expect(find.ancestor(of: chartHosts, matching: white), findsOneWidget);

    expect(chart.isDrawBarShadowEnabled, isFalse);
    expect(chart.isDrawValueAboveBarEnabled, isTrue);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.maxVisibleCount, 60);
    expect(chart.isPinchZoomEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.isFitBarsEnabled, isTrue);
    expect(chart.marker, isNull);

    final xAxis = chart.xAxis;
    expect(xAxis.position, XAxisPosition.BOTTOM);
    expect(xAxis.typeface, tfLight);
    expect(xAxis.isDrawAxisLineEnabled, isTrue);
    expect(xAxis.isDrawGridLinesEnabled, isFalse);
    expect(xAxis.granularity, 10);
    for (final axis in [chart.axisLeft, chart.axisRight]) {
      expect(axis.isEnabled, isTrue);
      expect(axis.typeface, tfLight);
      expect(axis.isDrawAxisLineEnabled, isTrue);
      expect(axis.axisMinimum, 0);
    }
    expect(chart.axisLeft.isDrawGridLinesEnabled, isTrue);
    expect(chart.axisRight.isDrawGridLinesEnabled, isFalse);

    final legend = chart.legend;
    expect(legend.verticalAlignment, LegendVerticalAlignment.BOTTOM);
    expect(legend.horizontalAlignment, LegendHorizontalAlignment.LEFT);
    expect(legend.orientation, LegendOrientation.HORIZONTAL);
    expect(legend.isDrawInsideEnabled, isFalse);
    expect(legend.formSize, 8);
    expect(legend.xEntrySpace, 4);

    final data = chart.data!;
    expect(data.barWidth, 9);
    final set = data.dataSets.single as BarDataSet;
    expect(set.label, 'DataSet 1');
    expect(set.entryCount, 12);
    expect([for (final e in set.entries) e.x], [for (var i = 0; i < 12; i++) i * 10.0]);
    // Math.random() * 50
    expect(ysOf(data), everyElement(inInclusiveRange(0, 50)));
    expect([for (final e in set.entries) e.icon], everyElement(same(starDrawable)));
    expect(set.isDrawIconsEnabled, isFalse);
    expect(set.valueTextSize, 10);
    expect(set.valueTypeface, tfLight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const HorizontalBarChartPage());
    final first = ysOf(chartOf<HorizontalBarChartView>(tester).data!);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const HorizontalBarChartPage());
    expect(ysOf(chartOf<HorizontalBarChartView>(tester).data!), first);
    await tester.pumpAndSettle();
  });

  testWidgets('a seek bar gives the set new entries, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const HorizontalBarChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<HorizontalBarChartView>(tester);
    final data = chart.data!;
    final set = data.dataSets.single;

    await setSeekBar(tester, 0, 25);
    expect(chart.data, same(data));
    expect(chart.data!.dataSets.single, same(set));
    expect(set.entryCount, 25);
    expect(set.getEntryForIndex(24).x, 240);
    expect(find.text('25'), findsOneWidget);

    await setSeekBar(tester, 1, 5);
    expect(ysOf(chart.data!), everyElement(inInclusiveRange(0, 5)));
    expect(find.text('5'), findsOneWidget);

    tester.element(find.byType(HorizontalBarChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(data));
    expect(set.entryCount, 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a highlighted bar calls the listener without an exception', (tester) async {
    await pumpPage(tester, const HorizontalBarChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<HorizontalBarChartView>(tester);

    chart.highlightValue(30, 0);
    await tester.pump();
    expect(chart.highlighted, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('seekBar1 at 0 leaves the set without entries, as on Android', (tester) async {
    await pumpPage(tester, const HorizontalBarChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<HorizontalBarChartView>(tester);

    await setSeekBar(tester, 0, 0);
    expect(chart.data!.dataSets.single.entryCount, 0);
    expect(tester.takeException(), isNull);

    await setSeekBar(tester, 0, 5);
    expect(chart.data!.dataSets.single.entryCount, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const HorizontalBarChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<HorizontalBarChartView>(tester);
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
    await pumpPage(tester, const HorizontalBarChartPage());
    await tester.pumpAndSettle();
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}
