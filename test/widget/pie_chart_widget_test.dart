// Not a port of a Kotlin test: MPChartCompose v4.0.1 has no test for its chart composables. Checks the PieChart widget
// end to end through its ChartHostWidget: a tap selects a slice and shows the marker, a drag around the center rotates,
// inside a vertical list the ring keeps its rotation (also with the default deceleration) while the hole and the
// corners scroll the list, a new data instance animates in, and removing the widget mid-spin or mid-fling leaves no
// animation or ticker behind.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/pie_chart.dart' as core;
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/pie_data.dart';
import 'package:mp_flutter_chart/src/data/pie_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_entry.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/listener/chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/widgets/chart_controller.dart';
import 'package:mp_flutter_chart/src/widgets/pie_chart_widget.dart';
import 'package:mp_flutter_chart/src/widgets/widget_marker.dart';

import '../support/pie_radar_gestures.dart';

/// One slice per value, 1, 2 and 3 by default, so slice 0 spans 60 degrees.
PieData _data([List<double> values = const [1, 2, 3]]) =>
    PieData(PieDataSet([for (final v in values) PieEntry(v)], 'a'));

/// The screen position of the middle of slice [index]: on its bisector, three quarters of the radius out, which is
/// outside the default hole of half the radius.
Offset _sliceMiddle(WidgetTester tester, core.PieChart chart, int index) =>
    pointAt(
      tester,
      chart,
      chart.rotationAngle +
          chart.absoluteAngles[index] -
          chart.drawAngles[index] / 2,
      chart.radius * 0.75,
    );

void main() {
  testWidgets('tappingASliceSelectsIt', (tester) async {
    final c = ChartController();
    late core.PieChart chart;
    final built = <(Entry, Highlight)>[];
    await tester.pumpWidget(
      host(
        PieChart(
          data: _data(),
          controller: c,
          marker: (entry, highlight) {
            built.add((entry, highlight));
            return SizedBox(width: 40, height: 20, child: Text('${entry.y}'));
          },
          setup: (it) => chart = it,
        ),
      ),
    );
    expect(chart.marker, isA<WidgetMarker>());
    expect(chart.width, 300);
    final point = _sliceMiddle(tester, chart, 0);

    await tap(tester, point, 1000, 1050);
    expect(chart.highlighted, hasLength(1));
    expect(chart.highlighted.single.x, 0);
    expect(c.selectedEntry, same(chart.data!.dataSet!.getEntryForIndex(0)));
    expect(c.selectedHighlight, same(chart.highlighted.single));

    // The chart draws the highlight; the overlay builds the marker on the frame after.
    await tester.pump();
    await tester.pump();
    expect(built, hasLength(1));
    expect(built.single.$1, same(c.selectedEntry));
    expect(built.single.$2, same(chart.highlighted.single));
    expect(find.text('1.0'), findsOneWidget);

    // A second single tap on the highlighted slice clears the highlight, and the marker goes with it without being
    // built again.
    await tap(tester, point, 1500, 1550);
    expect(chart.highlighted, isEmpty);
    expect(c.selectedEntry, isNull);
    expect(c.selectedHighlight, isNull);
    await tester.pump();
    await tester.pump();
    expect(find.text('1.0'), findsNothing);
    expect(built, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('draggingAroundTheCenterRotates', (tester) async {
    late core.PieChart chart;
    await tester.pumpWidget(
      host(
        PieChart(
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

    final gesture = await tester.startGesture(
      pointAt(tester, chart, 0, chart.radius * 0.75),
    );
    await moveAround(tester, gesture, chart, fromAngle: 0, sweep: 60);
    expect(chart.chartTouchListener.touchMode, ChartTouchListener.ROTATE);
    // The angle under the finger keeps its offset to the rotation: 270 + 60.
    expect(chart.rotationAngle, closeTo(330, 1e-4));
    await gesture.up();
    await tester.pump();
    expect(chart.chartTouchListener.touchMode, ChartTouchListener.NONE);
    expect(chart.rotationAngle, closeTo(330, 1e-4));
    expect(chart.highlighted, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('insideAListViewTheRingRotatesWhileTheHoleAndCornersScroll', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    late core.PieChart chart;
    await tester.pumpWidget(
      inList(
        PieChart(
          data: _data(),
          setup: (it) {
            chart = it;
            it.isDragDecelerationEnabled = false;
          },
        ),
        controller,
      ),
    );

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

    // On the ring the rotation claims the gesture at its 8 dp threshold, before the list's slop. That holds for the
    // slop inList's list has, Flutter's default kTouchSlop of 18 px (as on iOS); with an 8 dp list slop (Android) a
    // straight swipe along the list goes to the list, as the 8 dp cases of scroll_through_chart_test.dart show.
    var before = chart.rotationAngle;
    await dragUp(pointAt(tester, chart, 0, chart.radius * 0.75));
    expect(controller.offset, 0);
    expect(chart.rotationAngle, isNot(closeTo(before, 1)));

    // From the hole the chart does not rotate, so the list takes the gesture.
    before = chart.rotationAngle;
    final center = chart.centerCircleBox;
    await dragUp(chartTopLeft(tester) + Offset(center.x, center.y));
    expect(controller.offset, greaterThan(0));
    expect(chart.rotationAngle, before);
    await scrollBack();

    // From a corner, farther from the center than the radius, the list takes the gesture too.
    expect(chart.distanceToCenter(10, 10), greaterThan(chart.radius));
    await dragUp(chartTopLeft(tester) + const Offset(10, 10));
    expect(controller.offset, greaterThan(0));
    expect(chart.rotationAngle, before);
    await scrollBack();

    // The ring still rotates afterwards.
    await dragUp(pointAt(tester, chart, 0, chart.radius * 0.75));
    expect(controller.offset, 0);
    expect(chart.rotationAngle, isNot(closeTo(before, 1)));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('insideAListViewARingFlingTurnsOnWithoutScrolling', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    late core.PieChart chart;
    await tester.pumpWidget(
      inList(
        PieChart(
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

    // On the ring the rotation claims the gesture at its 8 dp threshold, before the list's slop, which is Flutter's
    // default kTouchSlop of 18 px here (as on iOS); with an 8 dp list slop (Android) a straight swipe along the list
    // goes to the list, as the 8 dp cases of scroll_through_chart_test.dart show. With the default deceleration the
    // pie keeps turning after the finger lifts, and the list stays where it is.
    final before = chart.rotationAngle;
    final gesture = await tester.startGesture(
      pointAt(tester, chart, 0, chart.radius * 0.75),
    );
    await moveInSteps(gesture, const Offset(0, -100));
    await gesture.up();
    await tester.pump();
    expect(controller.offset, 0);
    final released = chart.rotationAngle;
    expect(released, isNot(closeTo(before, 1)));
    await tester.pump(ms(16));
    final turning = chart.rotationAngle;
    expect(turning, isNot(closeTo(released, 1e-3)));
    await tester.pump(ms(16));
    expect(chart.rotationAngle, isNot(closeTo(turning, 1e-3)));
    expect(controller.offset, 0);

    // Removing the list mid-fling stops the deceleration's ticker with it.
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    await tester.pump(ms(16));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('animateChangesAnimatesANewDataInstance', (tester) async {
    late core.PieChart chart;
    final first = _data([1, 3]);
    await tester.pumpWidget(
      host(
        PieChart(data: first, animateChanges: true, setup: (it) => chart = it),
      ),
    );
    // A chart without data takes its first data at once.
    expect(chart.isAnimating, isFalse);
    expect(chart.data, same(first));
    expect(chart.drawAngles[0], closeTo(90, 1e-4));

    final second = _data([3, 1]);
    await tester.pumpWidget(
      host(
        PieChart(data: second, animateChanges: true, setup: (it) => chart = it),
      ),
    );
    expect(chart.isAnimating, isTrue);
    expect(chart.data, same(second));
    final slice = second.dataSet!.getEntryForIndex(0);
    // The new entries start at the values they replace.
    expect(slice.y, 1);

    await tester.pump();
    await tester.pump(ms(150));
    expect(chart.isAnimating, isTrue);
    // Halfway (linear over 300 ms): 1 -> 3 and 3 -> 1 are both at 2, so the slices are two halves.
    expect(slice.y, closeTo(2, 1e-4));
    expect(second.dataSet!.getEntryForIndex(1).y, closeTo(2, 1e-4));
    expect(chart.drawAngles[0], closeTo(180, 1e-4));

    await tester.pump(ms(151));
    expect(chart.isAnimating, isFalse);
    expect(slice.y, 3);
    expect(second.dataSet!.getEntryForIndex(1).y, 1);
    expect(chart.drawAngles[0], closeTo(270, 1e-4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disposingMidSpinAndMidFlingIsClean', (tester) async {
    // Mid-spin: the spin runs on the ChartAnimator with the host's vsync.
    late core.PieChart spun;
    await tester.pumpWidget(
      host(PieChart(data: _data(), setup: (it) => spun = it)),
    );
    var spinEnds = 0;
    spun.spin(2000, 0, 360, onEnd: () => spinEnds++);
    await tester.pump();
    await tester.pump(ms(1000));
    expect(spun.isAnimating, isTrue);
    expect(spun.rotationAngle, closeTo(180, 1e-4));

    // The State that lends its vsync goes away in this frame; TickerProviderStateMixin asserts that none of its
    // tickers is still active.
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    expect(spun.isAnimating, isFalse);
    expect(spinEnds, 1);
    // Ended at its final state: 360 degrees, normalized to 0.
    expect(spun.rotationAngle, closeTo(0, 1e-4));
    expect(spun.animator.vsync, isNull);
    expect(spun.host, isNull);
    await tester.pump(ms(16));
    expect(tester.binding.transientCallbackCount, 0);

    // Mid-fling: the deceleration runs on the touch listener's ticker from the host's vsync. The listener measures
    // with the test's fake clock, which stands still during the moves, so the velocity is the swept angle over the
    // listener's 0.1 s fallback.
    late core.PieChart flung;
    await tester.pumpWidget(
      host(
        PieChart(
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
