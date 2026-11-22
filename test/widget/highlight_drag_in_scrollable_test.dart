// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no test for a chart inside a scrolling parent. Checks that a
// highlight drag on a fully zoomed out bar chart gives way to an enclosing scrollable that scrolls along the chart's x
// axis, as on Android, where the parent intercepts the move that passes the touch slop before the chart sees it
// (T18 HB4); and that without such a scrollable the highlight follows the finger bar by bar.
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

/// Ten bars at x = 0 .. 9, `x + 1` long.
BarData _data() => BarData([
  BarDataSet([
    for (var i = 0; i < 10; i++) BarEntry(x: i.toDouble(), y: i + 1.0),
  ], 'bars'),
]);

/// Where [chart] draws bar [x] at the value 0.5, in chart pixels. A horizontal bar chart's transformer takes the value
/// first and x second.
Offset _barPoint(BarLineChartBase chart, double x) {
  final p = chart is HorizontalBarChartView
      ? chart.getPixelForValues(0.5, x, AxisDependency.LEFT)
      : chart.getPixelForValues(x, 0.5, AxisDependency.LEFT);
  return Offset(p.x, p.y);
}

/// How far the list is scrolled before each test, so that a swipe either way moves it.
const double _listOffset = 50;

Offset _chartTopLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byType(ChartRenderBoxWidget));

/// [chart] at 400 x 300: centred on the screen when [axis] is null, otherwise in a list that scrolls along [axis],
/// behind 100 pixels of other content and before 2000 more.
Widget _scene(Widget chart, Axis? axis, ScrollController controller) {
  final sized = Center(child: SizedBox(width: 400, height: 300, child: chart));
  Widget gap(double extent) => axis == Axis.vertical
      ? SizedBox(height: extent)
      : SizedBox(width: extent);
  return Directionality(
    textDirection: TextDirection.ltr,
    child: axis == null
        ? sized
        : ListView(
            controller: controller,
            scrollDirection: axis,
            children: [gap(100), sized, gap(2000)],
          ),
  );
}

/// Drags a finger over [chart] from [from] to [to], in chart pixels, in moves of about 4 px, the way a finger's
/// movement arrives on a device, and lifts it. Returns the x of the chart's highlight after each move.
Future<List<double?>> _drag(
  WidgetTester tester,
  BarLineChartBase chart,
  Offset from,
  Offset to,
) async {
  final steps = ((to - from).distance / 4).ceil();
  final step = (to - from) / steps.toDouble();
  final gesture = await tester.startGesture(_chartTopLeft(tester) + from);
  final seen = <double?>[];
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(step);
    seen.add(chart.highlighted.singleOrNull?.x);
  }
  await gesture.up();
  await tester.pump();
  return seen;
}

/// The x of the highlight after each move of [_drag] from [from] to [to] when the chart keeps the gesture: [selected]
/// until the finger is past the touch slop, then the bar under the finger.
List<double?> _followingHighlight(
  BarLineChartBase chart,
  Offset from,
  Offset to,
  double selected,
) {
  final steps = ((to - from).distance / 4).ceil();
  final step = (to - from) / steps.toDouble();
  return [
    for (var i = 1; i <= steps; i++)
      (step * i.toDouble()).distance > kTouchSlop
          ? chart
                .getHighlightByTouchPoint(
                  from.dx + step.dx * i,
                  from.dy + step.dy * i,
                )!
                .x
          : selected,
  ];
}

/// Where the list in [_scene] scrolls, relative to the chart's x axis.
enum _Scroller { none, alongX, acrossX }

/// One chart widget under test. [xAxis] is the direction its x axis runs on screen.
class _Kind {
  const _Kind(this.name, this.xAxis, this.widget);

  final String name;
  final Axis xAxis;
  final Widget Function(
    ChartController controller,
    void Function(BarLineChartBase chart) setup,
  )
  widget;

  Axis? scrollAxis(_Scroller scroller) => switch (scroller) {
    _Scroller.none => null,
    _Scroller.alongX => xAxis,
    _Scroller.acrossX =>
      xAxis == Axis.vertical ? Axis.horizontal : Axis.vertical,
  };
}

final _kinds = [
  _Kind(
    'HorizontalBarChart',
    Axis.vertical,
    (controller, setup) =>
        HorizontalBarChart(data: _data(), controller: controller, setup: setup),
  ),
  _Kind(
    'BarChart',
    Axis.horizontal,
    (controller, setup) =>
        BarChart(data: _data(), controller: controller, setup: setup),
  ),
];

void main() {
  for (final kind in _kinds) {
    group('${kind.name}, fully zoomed out, with bar 8 selected', () {
      late ChartController controller;
      late ScrollController scroll;
      late BarLineChartBase chart;

      Future<void> pumpScene(WidgetTester tester, _Scroller scroller) async {
        controller = ChartController();
        scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          _scene(
            kind.widget(controller, (it) => chart = it),
            kind.scrollAxis(scroller),
            scroll,
          ),
        );
        if (scroller != _Scroller.none) {
          scroll.jumpTo(_listOffset);
          await tester.pump();
        }
        expect(chart.isFullyZoomedOut, isTrue);
        expect(chart.isHighlightPerDragEnabled, isTrue);

        await tester.tapAt(_chartTopLeft(tester) + _barPoint(chart, 8));
        await tester.pump(const Duration(seconds: 1));
        expect(controller.selectedEntry?.x, 8);
      }

      testWidgets(
        'a swipe along its x axis in a list that scrolls that way scrolls the list and keeps the selection',
        (tester) async {
          await pumpScene(tester, _Scroller.alongX);
          final from = _barPoint(chart, 2);
          final to = _barPoint(chart, 7);
          // Without the list, the chart would highlight another bar on the move that passes the touch slop.
          final following = _followingHighlight(chart, from, to, 8);
          expect(following.toSet(), containsAll([3.0, 7.0]));

          final seen = await _drag(tester, chart, from, to);

          expect(scroll.offset, isNot(_listOffset));
          expect(seen, everyElement(8));
          expect(controller.selectedEntry?.x, 8);
          expect(chart.highlighted.single.x, 8);
          expect(chart.isFullyZoomedOut, isTrue);
        },
      );

      if (kind.xAxis == Axis.vertical) {
        testWidgets(
          'two moves along its x axis in one batch, the second past the touch slop, then a cancel keep the '
          'selection in a list that scrolls that way',
          (tester) async {
            // Several pointer events can arrive in one platform packet and are dispatched in one go.
            await pumpScene(tester, _Scroller.alongX);
            final from = _barPoint(chart, 2);
            final along = _barPoint(chart, 7) - from;
            final unit = along / along.distance;
            expect(
              chart
                  .getHighlightByTouchPoint(
                    from.dx + unit.dx * 24,
                    from.dy + unit.dy * 24,
                  )!
                  .x,
              isNot(8),
            );
            final origin = _chartTopLeft(tester);
            final pointer = TestPointer(7);
            await tester.sendEventToBinding(pointer.down(origin + from));

            tester.binding
              ..handlePointerEvent(pointer.move(origin + from + unit * 12))
              ..handlePointerEvent(pointer.move(origin + from + unit * 24))
              ..handlePointerEvent(pointer.cancel());
            await tester.pump();

            expect(controller.selectedEntry?.x, 8);
            expect(chart.highlighted.single.x, 8);
            expect(chart.isFullyZoomedOut, isTrue);
          },
        );
      }

      for (final scroller in [_Scroller.none, _Scroller.acrossX]) {
        testWidgets(
          scroller == _Scroller.none
              ? 'a drag along its x axis moves the highlight bar by bar'
              : 'a drag along its x axis in a list that scrolls across it moves the highlight bar by bar, '
                    'the list stays',
          (tester) async {
            await pumpScene(tester, scroller);
            final from = _barPoint(chart, 2);
            final to = _barPoint(chart, 7);
            final following = _followingHighlight(chart, from, to, 8);
            expect(following.toSet(), containsAll([3.0, 4.0, 5.0, 6.0, 7.0]));

            final seen = await _drag(tester, chart, from, to);

            expect(seen, following);
            expect(controller.selectedEntry?.x, 7);
            if (scroller == _Scroller.acrossX) {
              expect(scroll.offset, _listOffset);
            }
          },
        );
      }
    });
  }
}
