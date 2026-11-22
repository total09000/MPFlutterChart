import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/radar_marker_view.dart';
import 'package:mp_flutter_chart_example/pages/radar_chart_page.dart';

import '../support/pages.dart';

/// res/menu/radar.xml as RadarChartActivity shows it, without the items this app leaves out.
const List<String> _menu = [
  'Toggle Values',
  'Toggle Icons',
  'Toggle Filled',
  'Toggle Highlight',
  'Toggle Highlight Circle',
  'Toggle Rotation',
  'Toggle Y-Values',
  'Toggle X-Values',
  'Spin Animation',
  'Animate X',
  'Animate Y',
  'Animate XY',
];

void main() {
  testWidgets('the page shows RadarChartActivity\'s chart and menu', (tester) async {
    await pumpPage(tester, const RadarChartPage());
    final chart = chartOf<RadarChartView>(tester);
    // animateXY(1400, 1400, EaseInOutQuad) from onCreate.
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);

    expect(find.widgetWithText(AppBar, 'Radar Chart'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(await menuTitles(tester), _menu);
    // setBackgroundColor(Color.rgb(60, 65, 82))
    final slate = find.byWidgetPredicate(
      (widget) => widget is ColoredBox && widget.color == const Color.fromARGB(255, 60, 65, 82),
    );
    expect(find.ancestor(of: chartHosts, matching: slate), findsOneWidget);

    expect(chart.description.isEnabled, isFalse);
    expect(chart.webLineWidth, 1);
    expect(chart.webLineWidthInner, 1);
    expect(chart.webColor, const Color(0xFFCCCCCC));
    expect(chart.webColorInner, const Color(0xFFCCCCCC));
    expect(chart.webAlpha, 100);
    expect(chart.marker, isA<RadarMarkerView>());
    expect(chart.xAxis.textSize, 9);
    expect(chart.xAxis.textColor, const Color(0xFFFFFFFF));
    expect(chart.xAxis.valueFormatter.getFormattedValue(1, chart.xAxis), 'Steak');
    expect(chart.xAxis.valueFormatter.getFormattedValue(7, chart.xAxis), 'Salad');
    expect(chart.yAxis.labelCount, 5);
    expect(chart.yAxis.isDrawLabelsEnabled, isFalse);
    // The custom range stays after the chart has been laid out and drawn.
    expect(chart.yAxis.axisMinimum, 0);
    expect(chart.yAxis.axisMaximum, 80);
    expect(chart.legend.verticalAlignment, LegendVerticalAlignment.TOP);
    expect(chart.legend.horizontalAlignment, LegendHorizontalAlignment.CENTER);
    expect(chart.legend.orientation, LegendOrientation.HORIZONTAL);
    expect(chart.legend.xEntrySpace, 7);
    expect(chart.legend.yEntrySpace, 5);

    final data = chart.data!;
    final sets = data.dataSets.cast<RadarDataSet>();
    expect([for (final set in sets) set.label], ['Last Week', 'This Week']);
    expect([for (final set in sets) set.entryCount], [5, 5]);
    // (Math.random() * 80) + 20
    expect(ysOf(data), everyElement(inInclusiveRange(20, 100)));
    expect(sets[0].color, const Color.fromARGB(255, 103, 110, 129));
    expect(sets[1].fillColor, const Color.fromARGB(255, 121, 162, 175));
    for (final set in sets) {
      expect(set.isDrawFilledEnabled, isTrue);
      expect(set.fillAlpha, 180);
      expect(set.lineWidth, 2);
      expect(set.isDrawHighlightCircleEnabled, isTrue);
      expect(set.isVerticalHighlightIndicatorEnabled, isFalse);
      expect(set.isHorizontalHighlightIndicatorEnabled, isFalse);
      expect(set.isDrawValuesEnabled, isFalse);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const RadarChartPage());
    await tester.pumpAndSettle();
    final first = ysOf(chartOf<RadarChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const RadarChartPage());
    await tester.pumpAndSettle();
    expect(ysOf(chartOf<RadarChartView>(tester).data!), first);
  });

  testWidgets('a highlight draws the marker, and a rebuild of the page keeps the data', (tester) async {
    await pumpPage(tester, const RadarChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<RadarChartView>(tester);

    chart.highlightValue(2, 1);
    await tester.pump();
    expect(chart.highlighted, hasLength(1));
    expect(tester.takeException(), isNull);

    final shown = chart.data;
    tester.element(find.byType(RadarChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const RadarChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<RadarChartView>(tester);
    List<RadarDataSet> sets() => chart.data!.dataSets.cast<RadarDataSet>();

    await selectMenuItem(tester, 'Toggle Values');
    expect([for (final set in sets()) set.isDrawValuesEnabled], everyElement(isTrue));
    final data = chart.data;
    await selectMenuItem(tester, 'Toggle Icons');
    expect(chart.data, same(data));
    expect([for (final set in sets()) set.isDrawIconsEnabled], everyElement(isTrue));
    await selectMenuItem(tester, 'Toggle Filled');
    expect([for (final set in sets()) set.isDrawFilledEnabled], everyElement(isFalse));
    await selectMenuItem(tester, 'Toggle Highlight');
    expect(chart.data!.isHighlightEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Highlight Circle');
    expect([for (final set in sets()) set.isDrawHighlightCircleEnabled], everyElement(isFalse));
    await selectMenuItem(tester, 'Toggle Rotation');
    expect(chart.isRotationEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Y-Values');
    expect(chart.yAxis.isEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle X-Values');
    expect(chart.xAxis.isEnabled, isFalse);
    expect(chart.yAxis.axisMaximum, 80);

    // spin(2000, angle, angle + 360, EaseInOutCubic): the web turns once and stops where it started.
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
    await pumpPage(tester, const RadarChartPage());
    await tester.pumpAndSettle();
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}
