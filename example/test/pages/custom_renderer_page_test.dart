import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/badge_bar_renderer.dart';
import 'package:mp_flutter_chart_example/design/nightfall.dart';
import 'package:mp_flutter_chart_example/pages/custom_renderer_page.dart';

import '../support/pages.dart';

void main() {
  testWidgets('the page shows CustomRendererActivity\'s chart with the badge renderer and no menu', (tester) async {
    await pumpPage(tester, const CustomRendererPage());

    expect(find.widgetWithText(AppBar, 'Custom renderer'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);

    final chart = chartOf<BarChartView>(tester);
    expect(chart.renderer, isA<BadgeBarRenderer>());
    // animateY(900) from onCreate.
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);

    expect(chart.description.isEnabled, isFalse);
    expect(chart.legend.isEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.extraLeftOffset, 8);
    expect(chart.extraTopOffset, 24);
    expect(chart.extraRightOffset, 8);
    expect(chart.extraBottomOffset, 8);
    expect(chart.xAxis.position, XAxisPosition.BOTTOM);
    expect(chart.xAxis.isDrawGridLinesEnabled, isFalse);
    expect([for (var x = 0; x < 8; x++) chart.xAxis.valueFormatter.getFormattedValue(x.toDouble(), chart.xAxis)], [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Mon', //
    ]);
    expect(chart.axisLeft.isEnabled, isFalse);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.axisLeft.axisMinimum, 0);

    final data = chart.data!;
    expect(data.barWidth, 0.55);
    final set = data.dataSets.single as BarDataSet;
    expect(set.label, 'Sessions');
    expect(set.color, Nightfall.accent);
    expect(set.barCornerRadius, 8);
    expect(set.valueTextColor, const Color(0xFFFFFFFF));
    expect(set.valueTextSize, 11);
    expect([for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i).x], [0, 1, 2, 3, 4, 5, 6]);
    expect(ysOf(data), [42, 55, 48, 71, 66, 34, 29]);
    expect(set.valueFormatter.getFormattedValue(41.5, set.getEntryForIndex(0), 0, chart.viewPortHandler), '42');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the renderer and the data survive a rebuild of the page', (tester) async {
    await pumpPage(tester, const CustomRendererPage());
    await tester.pumpAndSettle();
    final chart = chartOf<BarChartView>(tester);
    final renderer = chart.renderer;
    final shown = chart.data;

    tester.element(find.byType(CustomRendererPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.renderer, same(renderer));
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the badge renderer draws a badge under each value label', (tester) async {
    await pumpPage(tester, const CustomRendererPage());
    await tester.pumpAndSettle();

    // The bars are clipped rectangles; the only rounded rectangles are the seven badges.
    final box = tester.renderObject<ChartRenderBox>(find.byType(ChartRenderBoxWidget));
    expect(box, paintsExactlyCountTimes(#drawRRect, 7));
    expect(box, paints..rrect(color: Nightfall.dark.card));
    expect(tester.takeException(), isNull);
  });
}
