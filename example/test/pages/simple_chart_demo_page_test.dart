import 'dart:io';

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/my_marker_view.dart';
import 'package:mp_flutter_chart_example/design/nightfall.dart';
import 'package:mp_flutter_chart_example/fragments/bar_chart_frag.dart';
import 'package:mp_flutter_chart_example/fragments/complexity_fragment.dart';
import 'package:mp_flutter_chart_example/fragments/pie_chart_frag.dart';
import 'package:mp_flutter_chart_example/fragments/scatter_chart_frag.dart';
import 'package:mp_flutter_chart_example/fragments/sine_cosine_fragment.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';
import 'package:mp_flutter_chart_example/pages/simple_chart_demo_page.dart';

import '../support/pages.dart';

/// Shows the page, lets the assets load and dismisses the dialog onCreate shows.
Future<void> pumpDemo(WidgetTester tester) async {
  await pumpPage(tester, const SimpleChartDemoPage());
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'OK'));
  await tester.pumpAndSettle();
}

/// Shows the page at [index] of the PageView.
Future<void> showPage(WidgetTester tester, int index) async {
  final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
  position.jumpTo(index * position.viewportDimension);
  await tester.pumpAndSettle();
}

/// The chart of the [fragment] of the page, which must be built.
C fragmentChart<C extends Chart>(WidgetTester tester, Type fragment) => tester
    .widget<ChartHostWidget>(find.descendant(of: find.byType(fragment), matching: chartHosts))
    .chart as C;

int lines(String file) => File('assets/$file').readAsLinesSync().where((line) => line.isNotEmpty).length;

void main() {
  testWidgets('the page shows SimpleChartDemo\'s dialog, which OK dismisses', (tester) async {
    await pumpPage(tester, const SimpleChartDemoPage());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'View Pager'), findsOneWidget);
    // only_github.xml has nothing but "View on GitHub", which is not ported.
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.widgetWithText(AlertDialog, 'This is a ViewPager.'), findsOneWidget);
    expect(find.text('Swipe left and right for more awesome design examples!'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.widget<PageView>(find.byType(PageView)).dragStartBehavior, chartScrollDragStartBehavior);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the first page is SineCosineFragment with the sine and cosine assets', (tester) async {
    await pumpPage(tester, const SimpleChartDemoPage());
    final chart = fragmentChart<LineChartView>(tester, SineCosineFragment);
    // The assets are loaded; onCreateView's animateX(3000) runs with the data.
    expect(chart.data, isNotNull);
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();

    expect(chart.description.isEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.legend.typeface, tfLight);
    expect(chart.axisLeft.axisMaximum, 1.2);
    expect(chart.axisLeft.axisMinimum, -1.2);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.xAxis.isEnabled, isFalse);

    final data = chart.data!;
    expect([for (final set in data.dataSets) set.label], ['Sine function', 'Cosine function']);
    expect([for (final set in data.dataSets) set.entryCount], [lines('sine.txt'), lines('cosine.txt')]);
    expect([for (final set in data.dataSets.cast<LineDataSet>()) set.isDrawCirclesEnabled], [false, false]);
    expect([for (final set in data.dataSets) set.color], ColorTemplate.VORDIPLOM_COLORS.sublist(0, 2));
    expect(ysOf(data), everyElement(inInclusiveRange(-1, 1)));

    // A rebuild of the page keeps the data.
    tester.element(find.byType(SimpleChartDemoPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(data));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the second page is ComplexityFragment with the four complexity assets', (tester) async {
    await pumpDemo(tester);
    await showPage(tester, 1);

    final chart = fragmentChart<LineChartView>(tester, ComplexityFragment);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.xAxis.isEnabled, isFalse);
    final data = chart.data!;
    expect([for (final set in data.dataSets) set.label], ['O(n)', 'O(nlogn)', 'O(n²)', 'O(n³)']);
    expect(
      [for (final set in data.dataSets) set.entryCount],
      [for (final file in ['n.txt', 'nlogn.txt', 'square.txt', 'three.txt']) lines(file)],
    );
    expect([for (final set in data.dataSets.cast<LineDataSet>()) set.circleRadius], everyElement(3));
    expect([for (final set in data.dataSets) set.color], ColorTemplate.VORDIPLOM_COLORS.sublist(0, 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the third page is BarChartFrag, whose gesture end clears the highlight', (tester) async {
    await pumpDemo(tester);
    await showPage(tester, 2);

    final chart = fragmentChart<BarChartView>(tester, BarChartFrag);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.marker, isA<MyMarkerView>());
    expect(chart.axisLeft.axisMinimum, 0);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.xAxis.isEnabled, isFalse);
    final data = chart.data!;
    expect(data.dataSets.single.label, 'Company A');
    expect(data.dataSets.single.entryCount, 12);
    // Math.random() * 20000 + 20000 / 4
    expect(ysOf(data), everyElement(inInclusiveRange(5000, 25000)));

    chart.highlightValue(3, 0);
    expect(chart.highlighted, isNotEmpty);
    await tester.dragFrom(tester.getCenter(chartHosts.hitTestable()), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(chart.highlighted, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the fourth page is ScatterChartFrag', (tester) async {
    await pumpDemo(tester);
    await showPage(tester, 3);

    final chart = fragmentChart<ScatterChartView>(tester, ScatterChartFrag);
    expect(chart.marker, isA<MyMarkerView>());
    expect(chart.xAxis.position, XAxisPosition.BOTTOM);
    expect(chart.axisRight.isDrawGridLinesEnabled, isFalse);
    expect(chart.legend.isWordWrapEnabled, isTrue);
    expect(chart.legend.formSize, 14);
    expect(chart.extraBottomOffset, 16);
    final data = chart.data!;
    expect([for (final set in data.dataSets) set.label], [
      'Company A', 'Company B', 'Company C', 'Company D', 'Company E', 'Company F', //
    ]);
    expect([for (final set in data.dataSets) set.entryCount], everyElement(200));
    expect([for (final set in data.dataSets) set.scatterShapeSize], everyElement(4.5));
    // Math.random() * 10000 + 10000 / 4
    expect(ysOf(data), everyElement(inInclusiveRange(2500, 12500)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the last page, far down the pager, is PieChartFrag', (tester) async {
    await pumpDemo(tester);
    await showPage(tester, 4);

    final chart = fragmentChart<PieChartView>(tester, PieChartFrag);
    expect(chart.centerText, 'Revenues\nQuarters 2015');
    expect(chart.centerTextSize, 10);
    expect(chart.holeRadius, 45);
    expect(chart.transparentCircleRadius, 50);
    expect(chart.legend.orientation, LegendOrientation.VERTICAL);
    final set = chart.data!.dataSets.single;
    expect(set.label, 'Quarterly Revenues 2015');
    expect(set.entryCount, 4);
    expect(set.valueTextColor, const Color(0xFFFFFFFF));
    // Math.random() * 60 + 40
    expect(ysOf(chart.data!), everyElement(inInclusiveRange(40, 100)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a swipe that starts on a chart turns the page', (tester) async {
    await pumpDemo(tester);
    expect(find.byType(ComplexityFragment).hitTestable(), findsNothing);

    await tester.fling(chartHosts.hitTestable().first, const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(ComplexityFragment).hitTestable(), findsOneWidget);
    expect(find.byType(SineCosineFragment).hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page keeps its chart and data when it is shown again', (tester) async {
    await pumpDemo(tester);
    await showPage(tester, 2);
    final bar = fragmentChart<BarChartView>(tester, BarChartFrag);
    final data = bar.data;

    await showPage(tester, 4);
    await showPage(tester, 2);
    expect(fragmentChart<BarChartView>(tester, BarChartFrag), same(bar));
    expect(bar.data, same(data));
  });

  testWidgets('two runs show the same values, whichever page is visited first', (tester) async {
    await pumpDemo(tester);
    await showPage(tester, 4);
    final pie = ysOf(fragmentChart<PieChartView>(tester, PieChartFrag).data!);
    await showPage(tester, 2);
    final bar = ysOf(fragmentChart<BarChartView>(tester, BarChartFrag).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpDemo(tester);
    await showPage(tester, 1);
    await showPage(tester, 2);
    expect(ysOf(fragmentChart<BarChartView>(tester, BarChartFrag).data!), bar);
    await showPage(tester, 3);
    await showPage(tester, 4);
    expect(ysOf(fragmentChart<PieChartView>(tester, PieChartFrag).data!), pie);
  });
}
