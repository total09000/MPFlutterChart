import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/demo_drawables.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';
import 'package:mp_flutter_chart_example/pages/candle_stick_chart_page.dart';

import '../support/pages.dart';

/// res/menu/candle.xml as CandleStickChartActivity shows it, without the items this app leaves out.
const List<String> _menu = [
  'Toggle Values',
  'Toggle Icons',
  'Toggle Highlight',
  'Toggle Shadow Color',
  'Toggle PinchZoom',
  'Toggle Auto Scale',
  'Animate X',
  'Animate Y',
  'Animate XY',
];

List<CandleEntry> _candles(CandleStickChartView chart) {
  final set = chart.data!.dataSets.single;
  return [for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i)];
}

/// Every candle as onProgressChanged builds it around `value = Math.random() * 40 + multi`: high and low 8 to 17 away,
/// open and close 1 to 7 away, falling for even indices and rising for odd ones.
void _expectCandles(List<CandleEntry> candles, double multi) {
  for (final (i, c) in candles.indexed) {
    expect(c.x, i);
    final even = i.isEven;
    expect(c.high, inInclusiveRange(multi + 8, multi + 40 + 17), reason: 'high $i');
    expect(c.low, inInclusiveRange(multi - 17, multi + 40 - 8), reason: 'low $i');
    expect(c.open > c.close, even, reason: 'candle $i falls when even');
    expect(c.high - c.low, inInclusiveRange(16, 34), reason: 'shadow $i');
  }
}

void main() {
  testWidgets('the page shows CandleStickChartActivity\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const CandleStickChartPage());

    expect(find.widgetWithText(AppBar, 'Candlestick'), findsOneWidget);
    expect(seekBars(tester), [40, 100]);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(await menuTitles(tester), _menu);
    // setBackgroundColor(Color.WHITE)
    final white = find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == demoChartBackground);
    expect(find.ancestor(of: chartHosts, matching: white), findsOneWidget);

    final chart = chartOf<CandleStickChartView>(tester);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.maxVisibleCount, 60);
    expect(chart.isPinchZoomEnabled, isFalse);
    expect(chart.xAxis.position, XAxisPosition.BOTTOM);
    expect(chart.xAxis.isDrawGridLinesEnabled, isFalse);
    expect(chart.axisLeft.labelCount, 7);
    expect(chart.axisLeft.isDrawGridLinesEnabled, isFalse);
    expect(chart.axisLeft.isDrawAxisLineEnabled, isFalse);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.legend.isEnabled, isFalse);

    final set = chart.data!.dataSets.single as CandleDataSet;
    expect(set.label, 'Data Set');
    expect(set.entryCount, 40);
    expect(set.isDrawIconsEnabled, isFalse);
    expect(set.getEntryForIndex(0).icon, same(starDrawable));
    expect(set.axisDependency, AxisDependency.LEFT);
    expect(set.shadowColor, const Color(0xFF444444));
    expect(set.shadowWidth, closeTo(0.7, 1e-6));
    expect(set.decreasingColor, const Color(0xFFFF0000));
    expect(set.decreasingPaintStyle, PaintStyle.FILL);
    expect(set.increasingColor, const Color.fromARGB(255, 122, 242, 84));
    expect(set.increasingPaintStyle, PaintStyle.STROKE);
    expect(set.neutralColor, const Color(0xFF0000FF));
    _expectCandles(_candles(chart), 101);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const CandleStickChartPage());
    final first = ysOf(chartOf<CandleStickChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const CandleStickChartPage());
    expect(ysOf(chartOf<CandleStickChartView>(tester).data!), first);
  });

  testWidgets('a seek bar sets new data, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const CandleStickChartPage());
    final chart = chartOf<CandleStickChartView>(tester);
    final before = chart.data;

    await setSeekBar(tester, 0, 300);
    expect(chart.data, isNot(same(before)));
    expect(_candles(chart), hasLength(300));
    expect(find.text('300'), findsOneWidget);

    await setSeekBar(tester, 1, 0);
    _expectCandles(_candles(chart), 1);
    expect(find.text('0'), findsOneWidget);

    final shown = chart.data;
    tester.element(find.byType(CandleStickChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const CandleStickChartPage());
    final chart = chartOf<CandleStickChartView>(tester);
    CandleDataSet set() => chart.data!.dataSets.single as CandleDataSet;

    await selectMenuItem(tester, 'Toggle Values');
    expect(set().isDrawValuesEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Icons');
    expect(set().isDrawIconsEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Highlight');
    expect(chart.data!.isHighlightEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Shadow Color');
    expect(set().shadowColorSameAsCandle, isTrue);
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
    await pumpPage(tester, const CandleStickChartPage());
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}
