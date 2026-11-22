// Not a port of a Kotlin test: MPChartCompose v4.0.1 has no test for its chart composables. Checks the RadarChart
// widget end to end through its ChartHostWidget: a tap near a spoke highlights its entry and shows the marker there, a
// drag around the center rotates the web, inside a vertical list a drag that starts on the web rotates it (also with
// the default deceleration) while one that starts outside the web scrolls the list, a new data instance animates in,
// and removing the widget mid-fling leaves no ticker behind.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/radar_chart.dart' as core;
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/radar_data.dart';
import 'package:mp_flutter_chart/src/data/radar_data_set.dart';
import 'package:mp_flutter_chart/src/data/radar_entry.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/listener/chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/listener/pie_radar_chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';
import 'package:mp_flutter_chart/src/widgets/chart_controller.dart';
import 'package:mp_flutter_chart/src/widgets/chart_render_box.dart';
import 'package:mp_flutter_chart/src/widgets/radar_chart_widget.dart';
import 'package:mp_flutter_chart/src/widgets/widget_marker.dart';

import '../support/pie_radar_gestures.dart';

/// One data set with one entry per value, 1 to 5 by default: five spokes 72 degrees apart.
RadarData _data([List<double> values = const [1, 2, 3, 4, 5]]) => RadarData([
  RadarDataSet([for (final v in values) RadarEntry(v)], 'a'),
]);

void main() {
  testWidgets('tappingNearASpokeHighlightsIt', (tester) async {
    final c = ChartController();
    late core.RadarChart chart;
    final built = <(Entry, Highlight)>[];
    const markerKey = Key('marker');
    await tester.pumpWidget(
      host(
        RadarChart(
          data: _data(),
          controller: c,
          marker: (entry, highlight) {
            built.add((entry, highlight));
            return SizedBox(
              key: markerKey,
              width: 40,
              height: 20,
              child: Text('${entry.y}'),
            );
          },
          setup: (it) => chart = it,
        ),
      ),
    );
    expect(chart.marker, isA<WidgetMarker>());
    expect(chart.width, 300);
    final entry = chart.data!.getDataSetByIndex(0)!.getEntryForIndex(2);
    expect(entry.y, 3);
    // The spoke of entry 2 and the distance of its corner from the center.
    final spoke = chart.rotationAngle + chart.sliceAngle * 2;
    final distance = (entry.y - chart.yChartMin) * chart.factor;
    expect(distance, inExclusiveRange(0, chart.radius));
    // 10 degrees off that spoke, at the corner's distance: the touch angle snaps to the nearest spoke, up to half the
    // 72 degrees between two spokes away.
    final point = pointAt(tester, chart, spoke + 10, distance);

    await tap(tester, point, 1000, 1050);
    expect(chart.highlighted, hasLength(1));
    final high = chart.highlighted.single;
    expect(high.x, 2);
    expect(high.y, 3);
    expect(high.dataSetIndex, 0);
    expect(c.selectedEntry, same(entry));
    expect(c.selectedHighlight, same(high));

    // The chart draws the highlight; the overlay builds the marker on the frame after, once, for that entry.
    await tester.pump();
    await tester.pump();
    expect(built, hasLength(1));
    expect(built.single.$1, same(entry));
    expect(built.single.$2, same(high));
    expect(find.text('3.0'), findsOneWidget);
    // The marker stands at the corner of entry 2 on the web, centered 12 dp above it.
    final corner = pointAt(tester, chart, spoke, distance);
    final topLeft = chartTopLeft(tester);
    expect(
      (chart.marker! as WidgetMarker).lastPosition! + topLeft,
      offsetMoreOrLessEquals(corner, epsilon: 1e-3),
    );
    final markerRect = tester.getRect(find.byKey(markerKey));
    expect(markerRect.center.dx, closeTo(corner.dx, 1e-3));
    expect(
      markerRect.bottom,
      closeTo(corner.dy - Utils.convertDpToPixel(12), 1e-3),
    );

    // A second single tap on the highlighted spoke clears the highlight, and the marker goes with it without being
    // built again.
    await tap(tester, point, 1500, 1550);
    expect(chart.highlighted, isEmpty);
    expect(c.selectedEntry, isNull);
    expect(c.selectedHighlight, isNull);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(markerKey), findsNothing);
    expect(built, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('draggingRotatesTheWeb', (tester) async {
    late core.RadarChart chart;
    await tester.pumpWidget(
      host(
        RadarChart(
          data: _data(),
          setup: (it) {
            chart = it;
            // No fling after the finger lifts, so the angle stays where the finger left it.
            it.isDragDecelerationEnabled = false;
          },
        ),
      ),
    );
    expect(chart.rotationAngle, 270);
    final start = pointAt(tester, chart, 0, chart.radius * 0.75);

    final gesture = await tester.startGesture(start);
    await moveAround(tester, gesture, chart, fromAngle: 0, sweep: 60);
    expect(chart.chartTouchListener.touchMode, ChartTouchListener.ROTATE);
    // The angle under the finger keeps its offset to the rotation: 270 + 60.
    expect(chart.rotationAngle, closeTo(330, 1e-4));
    await gesture.up();
    await tester.pump();
    expect(chart.chartTouchListener.touchMode, ChartTouchListener.NONE);
    expect(chart.rotationAngle, closeTo(330, 1e-4));
    expect(chart.highlighted, isEmpty);

    // A drag of 16 px, past the 8 dp rotation threshold but inside Flutter's 18 px touch slop, rotates
    // (the move to 12 px starts the rotation, the one to 16 px turns the web), and its up is not taken for a tap,
    // which would highlight entry 0 under the finger.
    final short = await tester.startGesture(start);
    await moveInSteps(short, const Offset(0, 16));
    expect(chart.chartTouchListener.touchMode, ChartTouchListener.ROTATE);
    expect(chart.rotationAngle, isNot(closeTo(330, 1)));
    await short.up();
    await tester.pump();
    expect(chart.chartTouchListener.touchMode, ChartTouchListener.NONE);
    expect(chart.highlighted, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('insideAListViewADragOnTheWebRotatesAndOutsideScrolls', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    late core.RadarChart chart;
    await tester.pumpWidget(
      inList(
        RadarChart(
          data: _data(),
          setup: (it) {
            chart = it;
            useFakeClock(tester, it);
          },
        ),
        controller,
      ),
    );
    expect(chart.isDragDecelerationEnabled, isTrue);

    Future<void> dragUp(Offset start) async {
      final gesture = await tester.startGesture(start);
      await moveInSteps(gesture, const Offset(0, -100));
      await gesture.up();
      await tester.pump();
    }

    Future<void> scrollBack() async {
      controller.jumpTo(0);
      await tester.pump();
    }

    // On the web the rotation claims the gesture at its 8 dp threshold, before the list's slop, which is Flutter's
    // default kTouchSlop of 18 px here (as on iOS); with an 8 dp list slop (Android) a straight swipe along the list
    // goes to the list, as the 8 dp cases of scroll_through_chart_test.dart show. With the default deceleration the
    // web keeps turning after the finger lifts, and the list stays where it is.
    var before = chart.rotationAngle;
    await dragUp(pointAt(tester, chart, 0, chart.radius * 0.75));
    expect(controller.offset, 0);
    final released = chart.rotationAngle;
    expect(released, isNot(closeTo(before, 1)));
    await tester.pump(ms(16));
    final turning = chart.rotationAngle;
    expect(turning, isNot(closeTo(released, 1e-3)));
    await tester.pump(ms(16));
    expect(chart.rotationAngle, isNot(closeTo(turning, 1e-3)));
    expect(controller.offset, 0);
    // From here on the web stands still between gestures, so each angle below is where the last finger left it.
    (chart.chartTouchListener as PieRadarChartTouchListener).stopDeceleration();
    chart.isDragDecelerationEnabled = false;

    // A radar has no hole: from the center the web rotates too.
    before = chart.rotationAngle;
    final center = chart.centerOffsets;
    await dragUp(chartTopLeft(tester) + Offset(center.x, center.y));
    expect(controller.offset, 0);
    expect(chart.rotationAngle, isNot(closeTo(before, 1)));

    // Just outside the web, though still on the chart, the chart does not rotate, so the list takes the gesture.
    before = chart.rotationAngle;
    final outside = pointAt(tester, chart, 0, chart.radius + 10);
    expect(
      tester.getRect(find.byType(ChartRenderBoxWidget)).contains(outside),
      isTrue,
    );
    await dragUp(outside);
    expect(controller.offset, greaterThan(0));
    expect(chart.rotationAngle, before);
    await scrollBack();

    // From a corner, farther from the center than the radius, the list takes the gesture too.
    expect(chart.distanceToCenter(10, 10), greaterThan(chart.radius));
    await dragUp(chartTopLeft(tester) + const Offset(10, 10));
    expect(controller.offset, greaterThan(0));
    expect(chart.rotationAngle, before);
    await scrollBack();

    // The web still rotates afterwards.
    await dragUp(pointAt(tester, chart, 0, chart.radius * 0.75));
    expect(controller.offset, 0);
    expect(chart.rotationAngle, isNot(closeTo(before, 1)));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('animateChangesAnimatesANewDataInstance', (tester) async {
    late core.RadarChart chart;
    final first = _data([1, 3, 2]);
    await tester.pumpWidget(
      host(
        RadarChart(
          data: first,
          animateChanges: true,
          setup: (it) => chart = it,
        ),
      ),
    );
    // A chart without data takes its first data at once.
    expect(chart.isAnimating, isFalse);
    expect(chart.data, same(first));
    expect(first.yMax, 3);
    final firstAxisMaximum = chart.yAxis.axisMaximum;
    expect(firstAxisMaximum, lessThan(4));

    final second = _data([3, 1, 6]);
    List<double> values() => [
      for (var i = 0; i < 3; i++)
        second.getDataSetByIndex(0)!.getEntryForIndex(i).y,
    ];
    await tester.pumpWidget(
      host(
        RadarChart(
          data: second,
          animateChanges: true,
          setup: (it) => chart = it,
        ),
      ),
    );
    expect(chart.isAnimating, isTrue);
    expect(chart.data, same(second));
    // The new entries start at the values they replace.
    expect(values(), [1, 3, 2]);
    expect(second.yMax, 3);

    await tester.pump();
    await tester.pump(ms(150));
    expect(chart.isAnimating, isTrue);
    // Halfway (linear over 300 ms): 1 -> 3, 3 -> 1 and 2 -> 6 are at 2, 2 and 4, and the data range and the y axis
    // follow them.
    expect(values(), [closeTo(2, 1e-4), closeTo(2, 1e-4), closeTo(4, 1e-4)]);
    expect(second.yMax, closeTo(4, 1e-4));
    expect(chart.yAxis.axisMaximum, greaterThanOrEqualTo(second.yMax));

    await tester.pump(ms(151));
    expect(chart.isAnimating, isFalse);
    expect(values(), [3, 1, 6]);
    expect(second.yMax, 6);
    expect(chart.yAxis.axisMaximum, greaterThanOrEqualTo(6));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disposingMidFlingIsClean', (tester) async {
    // The deceleration runs on the touch listener's ticker from the host's vsync.
    late core.RadarChart flung;
    await tester.pumpWidget(
      host(
        RadarChart(
          data: _data(),
          setup: (it) {
            flung = it;
            useFakeClock(tester, it);
          },
        ),
      ),
    );
    final gesture = await tester.startGesture(
      pointAt(tester, flung, 0, flung.radius * 0.75),
    );
    await moveAround(tester, gesture, flung, fromAngle: 0, sweep: 60);
    await gesture.up();
    final released = flung.rotationAngle;
    await tester.pump(ms(16));
    final decelerating = flung.rotationAngle;
    expect(decelerating, isNot(closeTo(released, 1e-3)));
    await tester.pump(ms(16));
    expect(flung.rotationAngle, isNot(closeTo(decelerating, 1e-3)));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    // The State that lends its vsync goes away in this frame; TickerProviderStateMixin asserts that none of its
    // tickers is still active.
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    expect(flung.host, isNull);
    expect(flung.animator.vsync, isNull);
    final stopped = flung.rotationAngle;
    await tester.pump(ms(16));
    expect(flung.rotationAngle, stopped);
    expect(tester.binding.transientCallbackCount, 0);
    // No timer is left to run out either: the rotation's cancel and the up both cancel the gesture
    // detector's long press timer, so the test binding's end-of-test check for pending timers passes as it is.
  });
}
