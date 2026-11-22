import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/design/easing_curve_view.dart';
import 'package:mp_flutter_chart_example/design/nightfall.dart';
import 'package:mp_flutter_chart_example/pages/animation_playground_page.dart';

import '../support/pages.dart';

/// The page polls `isAnimating` every 80 ms and never settles, so the tests pump fixed steps.
const Duration _step = Duration(milliseconds: 100);

/// The three charts, offstage ones included, in the order line, bar, donut.
(LineChartView, BarChartView, PieChartView) _charts(WidgetTester tester) {
  final hosts = tester
      .widgetList<ChartHostWidget>(find.byWidgetPredicate((widget) => widget is ChartHostWidget, skipOffstage: false))
      .toList();
  expect(hosts, hasLength(3));
  return (hosts[0].chart as LineChartView, hosts[1].chart as BarChartView, hosts[2].chart as PieChartView);
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Runs the animation the last tap started to its end: [millis] of it plus a poll of the status chip.
Future<void> _runOut(WidgetTester tester, [int millis = 1500]) async {
  await tester.pump(Duration(milliseconds: millis + 50));
  await tester.pump(_step);
  await tester.pump(_step);
}

String _status(WidgetTester tester) =>
    find.textContaining('●').evaluate().map((e) => (e.widget as Text).data!).single;

void main() {
  testWidgets('the page shows AnimationPlaygroundActivity\'s charts and controls', (tester) async {
    await pumpPage(tester, const AnimationPlaygroundPage());

    expect(find.widgetWithText(AppBar, 'All animations'), findsOneWidget);
    // The Activity has no options menu.
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text('Animations'), findsOneWidget);
    expect(find.text('animateX draws it, animateY grows it'), findsOneWidget);
    expect(_status(tester), '●  Idle');
    expect(find.text('onEnd has not run yet'), findsOneWidget);
    expect(find.text('EaseInOutCubic'), findsOneWidget);
    expect(find.text('InOutCubic'), findsOneWidget);
    expect(find.text('Linear', skipOffstage: false), findsOneWidget);
    expect(find.text('InOutBounce', skipOffstage: false), findsOneWidget);
    expect(tester.widget<EasingCurveView>(find.byType(EasingCurveView)).easing, same(Easing.EaseInOutCubic));
    expect(seekBars(tester), [1500]);
    expect(tester.widget<Slider>(find.byType(Slider)).max, 4000);
    expect(find.text('1500 ms'), findsOneWidget);
    const labels = ['Line', 'Bars', 'Donut', 'Draw X', 'Grow Y', 'Both', 'Spin', 'New data', 'One value', 'Stop'];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    // Only the line chart is shown; the other two are offstage, as View.GONE.
    expect(chartHosts, findsOneWidget);
    expect(chartOf<Chart>(tester), isA<LineChartView>());
    final (line, bar, pie) = _charts(tester);

    expect(line.description.isEnabled, isFalse);
    expect(line.legend.isEnabled, isFalse);
    expect(line.isScaleEnabled, isFalse);
    expect(line.axisRight.isEnabled, isFalse);
    expect(line.axisLeft.axisMinimum, 0);
    expect(line.axisLeft.axisMaximum, 110);
    expect(line.xAxis.axisMinimum, 0);
    expect(line.xAxis.axisMaximum, 11);
    final lineSet = line.data!.dataSets.single as LineDataSet;
    expect(lineSet.label, 'Values');
    expect(lineSet.entryCount, 12);
    expect(lineSet.mode, LineDataSetMode.CUBIC_BEZIER);
    expect(lineSet.isDrawCirclesEnabled, isTrue);
    expect(lineSet.circleRadius, 3.5);
    expect(lineSet.circleHoleRadius, 1.8);
    expect(lineSet.getCircleColor(0), Nightfall.accent);

    expect(bar.axisLeft.axisMinimum, 0);
    expect(bar.axisLeft.axisMaximum, 110);
    expect(bar.xAxis.axisMinimum, -0.5);
    expect(bar.xAxis.axisMaximum, 7.5);
    expect(bar.data!.barWidth, 0.6);
    expect(bar.data!.dataSets.single.entryCount, 8);
    expect((bar.data!.dataSets.single as BarDataSet).barCornerRadius, 7);

    expect(pie.holeRadius, 62);
    expect(pie.isDrawRoundedSlicesEnabled, isTrue);
    expect(pie.legend.isEnabled, isTrue);
    final pieSet = pie.data!.dataSets.single;
    expect(pieSet.entryCount, 5);
    expect([for (var i = 0; i < 5; i++) pieSet.getEntryForIndex(i).label], [
      'Part 1', 'Part 2', 'Part 3', 'Part 4', 'Part 5', //
    ]);
    expect(pieSet.colors, Nightfall.palette);

    // Random.nextInt(15, 100)
    for (final ChartData data in [line.data!, bar.data!, pie.data!]) {
      final ys = ysOf(data);
      expect(ys, everyElement(inInclusiveRange(15, 99)));
      expect(ys.every((y) => y == y.roundToDouble()), isTrue);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const AnimationPlaygroundPage());
    final (line, bar, pie) = _charts(tester);
    final first = [ysOf(line.data!), ysOf(bar.data!), ysOf(pie.data!)];

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const AnimationPlaygroundPage());
    final (line2, bar2, pie2) = _charts(tester);
    expect([ysOf(line2.data!), ysOf(bar2.data!), ysOf(pie2.data!)], first);
  });

  testWidgets('the tabs show one chart and stop the animation of the one they hide', (tester) async {
    await pumpPage(tester, const AnimationPlaygroundPage());
    final (line, bar, pie) = _charts(tester);
    // Spin is disabled off the donut tab.
    await _tap(tester, 'Spin');
    expect(pie.isAnimating, isFalse);

    await _tap(tester, 'Draw X');
    expect(line.isAnimating, isTrue);
    await _tap(tester, 'Bars');
    expect(line.isAnimating, isFalse);
    expect(chartOf<Chart>(tester), same(bar));
    expect(find.text('tap New data to grow, shrink and move bars'), findsOneWidget);
    // select() stopped the line chart's animateX, whose onEnd ran.
    await tester.pump(_step);
    expect(find.text('onEnd ran once, for animateX'), findsOneWidget);

    await _tap(tester, 'Donut');
    expect(chartOf<Chart>(tester), same(pie));
    expect(find.text('animateX sweeps the slices, Spin turns it'), findsOneWidget);
    await _tap(tester, 'Line');
    expect(chartOf<Chart>(tester), same(line));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Draw X, Grow Y and Both animate the shown chart and count their onEnd', (tester) async {
    await pumpPage(tester, const AnimationPlaygroundPage());
    final (line, _, _) = _charts(tester);

    await _tap(tester, 'Draw X');
    expect(line.isAnimating, isTrue);
    await tester.pump(_step);
    await tester.pump(_step);
    expect(_status(tester), '●  Running');
    expect(line.animator.phaseX, inExclusiveRange(0, 1));
    await _runOut(tester);
    expect(line.isAnimating, isFalse);
    expect(_status(tester), '●  Idle');
    expect(find.text('onEnd ran once, for animateX'), findsOneWidget);

    await _tap(tester, 'Grow Y');
    await tester.pump(_step);
    expect(line.animator.phaseY, inExclusiveRange(0, 1));
    await _runOut(tester);
    expect(find.text('onEnd ran 2 times, last for animateY'), findsOneWidget);

    await _tap(tester, 'Both');
    await tester.pump(_step);
    expect(line.animator.phaseX, inExclusiveRange(0, 1));
    expect(line.animator.phaseY, inExclusiveRange(0, 1));
    await _runOut(tester);
    expect(find.text('onEnd ran 3 times, last for animateXY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Stop ends the animation at once and runs its onEnd', (tester) async {
    await pumpPage(tester, const AnimationPlaygroundPage());
    final (line, _, _) = _charts(tester);

    await _tap(tester, 'Draw X');
    await tester.pump(_step);
    expect(line.isAnimating, isTrue);
    await _tap(tester, 'Stop');
    expect(line.isAnimating, isFalse);
    expect(line.animator.phaseX, 1);
    expect(find.text('onEnd ran once, for animateX'), findsOneWidget);
    await tester.pump(_step);
    expect(_status(tester), '●  Idle');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spin turns the donut a full turn', (tester) async {
    await pumpPage(tester, const AnimationPlaygroundPage());
    final (_, _, pie) = _charts(tester);
    await _tap(tester, 'Donut');
    final start = pie.rotationAngle;

    await _tap(tester, 'Spin');
    expect(pie.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 700));
    expect(pie.rotationAngle, isNot(closeTo(start, 1e-6)));
    await _runOut(tester);
    expect(pie.isAnimating, isFalse);
    expect(pie.rotationAngle, closeTo(start, 1e-3));
    expect(find.text('onEnd ran once, for spin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('New data animates in data of another size on each chart', (tester) async {
    await pumpPage(tester, const AnimationPlaygroundPage());
    final (line, bar, pie) = _charts(tester);

    final oldLine = line.data;
    await _tap(tester, 'New data');
    expect(line.data, isNot(same(oldLine)));
    expect(line.isAnimating, isTrue);
    await _runOut(tester);
    // Random.nextInt(6, 18) entries, the x axis spread over them.
    final lineCount = line.data!.dataSets.single.entryCount;
    expect(lineCount, inInclusiveRange(6, 17));
    expect(line.xAxis.axisMaximum, lineCount - 1);
    expect(ysOf(line.data!), everyElement(inInclusiveRange(15, 99)));
    expect(find.text('onEnd ran once, for animateDataChange'), findsOneWidget);

    await _tap(tester, 'Bars');
    await _tap(tester, 'New data');
    await _runOut(tester);
    final barCount = bar.data!.dataSets.single.entryCount;
    expect(barCount, inInclusiveRange(4, 11));
    expect(bar.xAxis.axisMaximum, barCount - 0.5);
    expect(bar.data!.barWidth, 0.6);

    await _tap(tester, 'Donut');
    await _tap(tester, 'New data');
    await _runOut(tester);
    expect(pie.data!.dataSets.single.entryCount, inInclusiveRange(3, 5));
    expect(find.text('onEnd ran 3 times, last for animateDataChange'), findsOneWidget);

    // A rebuild of the page hands the hosts the charts' own data, so they leave it alone.
    final shown = [line.data, bar.data, pie.data];
    tester.element(find.byType(AnimationPlaygroundPage)).markNeedsBuild();
    await tester.pump();
    expect(line.data, same(shown[0]));
    expect(bar.data, same(shown[1]));
    expect(pie.data, same(shown[2]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('One value animates a single entry to a new value', (tester) async {
    await pumpPage(tester, const AnimationPlaygroundPage());
    final (line, _, _) = _charts(tester);
    final data = line.data;
    final before = ysOf(line.data!);

    await _tap(tester, 'One value');
    expect(line.isAnimating, isTrue);
    await _runOut(tester);
    expect(line.data, same(data));
    final after = ysOf(line.data!);
    var changed = 0;
    for (var i = 0; i < before.length; i++) {
      if (after[i] != before[i]) changed++;
    }
    expect(changed, lessThanOrEqualTo(1));
    expect(after, everyElement(inInclusiveRange(15, 99)));
    expect(find.text('onEnd ran once, for animateValue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the easing chips and the duration seek bar set what the animations use', (tester) async {
    await pumpPage(tester, const AnimationPlaygroundPage());
    final (line, _, _) = _charts(tester);

    await _tap(tester, 'InQuad');
    expect(find.text('EaseInQuad'), findsOneWidget);
    expect(tester.widget<EasingCurveView>(find.byType(EasingCurveView)).easing, same(Easing.EaseInQuad));
    await _tap(tester, 'OutBounce');
    expect(find.text('EaseOutBounce'), findsOneWidget);
    expect(tester.widget<EasingCurveView>(find.byType(EasingCurveView)).easing, same(Easing.EaseOutBounce));
    await _tap(tester, 'Linear');
    expect(tester.widget<EasingCurveView>(find.byType(EasingCurveView)).easing, same(Easing.Linear));

    // Linear over 1000 ms is half way after 500 ms.
    await setSeekBar(tester, 0, 1000);
    expect(find.text('1000 ms'), findsOneWidget);
    await _tap(tester, 'Draw X');
    await tester.pump(const Duration(milliseconds: 500));
    expect(line.animator.phaseX, closeTo(0.5, 0.05));
    await _runOut(tester, 1000);

    // durationMillis = progress.coerceAtLeast(100)
    await setSeekBar(tester, 0, 30);
    expect(seekBars(tester), [30]);
    expect(find.text('100 ms'), findsOneWidget);
    await _tap(tester, 'Draw X');
    expect(line.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 120));
    expect(line.isAnimating, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving the page while it animates is safe', (tester) async {
    await pumpPage(tester, const AnimationPlaygroundPage());
    await _tap(tester, 'Draw X');
    await _tap(tester, 'New data');
    await tester.pump(_step);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(_step);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every button can be tapped twice on every tab', (tester) async {
    await pumpPage(tester, const AnimationPlaygroundPage());
    for (final tab in ['Line', 'Bars', 'Donut']) {
      await _tap(tester, tab);
      for (final label in ['Draw X', 'Grow Y', 'Both', 'Spin', 'New data', 'One value', 'Stop']) {
        for (var round = 0; round < 2; round++) {
          await _tap(tester, label);
          await tester.pump(_step);
          expect(tester.takeException(), isNull, reason: '$tab, $label, round ${round + 1}');
        }
      }
      await _runOut(tester);
    }
    expect(tester.takeException(), isNull);
  });
}
