// Not a port of a Kotlin test: the touch and gesture helpers the pie and radar tests share, so that
// pie_chart_test.dart, radar_chart_test.dart, pie_radar_chart_touch_listener_test.dart, pie_chart_widget_test.dart and
// radar_chart_widget_test.dart do not each keep a copy. [event], [send] and [touch] feed ChartTouchEvents straight to a
// chart (HostileInputTest.touch on a round chart); the others drive a chart widget through the test binding's
// gestures. The file has no `_test` suffix, so the test runner does not run it on its own.
//
// None of the helpers sets the touch listener's clock: a test that wants the test binding's fake clock for the
// rotation velocity and deceleration opts in with [useFakeClock].
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/chart.dart';
import 'package:mp_flutter_chart/src/charts/pie_radar_chart_base.dart';
import 'package:mp_flutter_chart/src/listener/pie_radar_chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/widgets/chart_render_box.dart';
import 'package:mp_flutter_chart/src/widgets/chart_touch_event.dart';

/// A touch event of one finger per entry of [positions] (pointer ids 0, 1, …) at [time] ms; [actionIndex] is the
/// finger a pointerDown or pointerUp refers to.
ChartTouchEvent event(
  ChartTouchAction action,
  int time,
  List<ui.Offset> positions, {
  int actionIndex = 0,
}) => ChartTouchEvent(
  action: action,
  actionIndex: actionIndex,
  pointerIds: [for (var i = 0; i < positions.length; i++) i],
  positions: positions,
  eventTimeMillis: time,
);

/// Sends [chart] a one-finger [action] at ([x], [y]) at [time] ms.
void send(Chart chart, ChartTouchAction action, int time, double x, double y) =>
    chart.onTouchEvent(event(action, time, [ui.Offset(x, y)]));

/// HostileInputTest.touch on a round chart: a tap, a double tap, a drag, a pinch and a fling in the middle of the
/// chart, starting at [time] ms, then one `computeScroll`. Returns the time after the last event.
int touch(Chart chart, int time) {
  final w = math.max(chart.width, 1.0);
  final h = math.max(chart.height, 1.0);
  var t = time;
  // tap
  send(chart, ChartTouchAction.down, t, w / 2, h / 2);
  send(chart, ChartTouchAction.up, t + 50, w / 2, h / 2);
  t += 1000;
  // double tap
  send(chart, ChartTouchAction.down, t, w / 2, h / 2);
  send(chart, ChartTouchAction.up, t, w / 2, h / 2);
  send(chart, ChartTouchAction.down, t + 80, w / 2, h / 2);
  send(chart, ChartTouchAction.up, t + 80, w / 2, h / 2);
  t += 1000;
  // drag
  send(chart, ChartTouchAction.down, t, w / 2, h / 2);
  for (var i = 1; i <= 10; i++) {
    send(
      chart,
      ChartTouchAction.move,
      t + i * 30,
      w / 2 - i * 40.0,
      h / 2 + i * 10.0,
    );
  }
  send(chart, ChartTouchAction.up, t + 330, w / 2 - 400, h / 2 + 100);
  t += 1000;
  // pinch
  send(chart, ChartTouchAction.down, t, w / 2, h / 2);
  chart.onTouchEvent(
    event(ChartTouchAction.pointerDown, t + 10, [
      ui.Offset(w / 2, h / 2),
      ui.Offset(w / 2 + 20, h / 2 + 20),
    ], actionIndex: 1),
  );
  for (var i = 1; i <= 10; i++) {
    chart.onTouchEvent(
      event(ChartTouchAction.move, t + 10 + i * 20, [
        ui.Offset(w / 2 - i * 30.0, h / 2 - i * 30.0),
        ui.Offset(w / 2 + i * 30.0, h / 2 + i * 30.0),
      ]),
    );
  }
  chart.onTouchEvent(
    event(ChartTouchAction.pointerUp, t + 250, [
      ui.Offset(w / 2 - 300, h / 2 - 300),
      ui.Offset(w / 2 + 300, h / 2 + 300),
    ], actionIndex: 1),
  );
  send(chart, ChartTouchAction.up, t + 260, w / 2 - 300, h / 2 - 300);
  t += 1000;
  // fling
  send(chart, ChartTouchAction.down, t, w / 2 + 60, h / 2);
  for (var i = 1; i <= 5; i++) {
    send(
      chart,
      ChartTouchAction.move,
      t + i * 10,
      w / 2 + 60,
      h / 2 + i * 12.0,
    );
  }
  send(chart, ChartTouchAction.up, t + 60, w / 2 + 60, h / 2 + 60);
  chart.computeScroll();
  return t + 1000;
}

/// Uses the test binding's fake clock for the rotation velocity and the deceleration of [chart]'s touch listener,
/// instead of the wall clock. The fake clock stands still between pumps, so the samples of a drag sent without pumps
/// share one time, and the fling velocity is the swept angle over the listener's 0.1 s fallback.
void useFakeClock(WidgetTester tester, PieRadarChartBase chart) {
  (chart.chartTouchListener as PieRadarChartTouchListener).clock = () =>
      tester.binding.clock.now().millisecondsSinceEpoch;
}

/// Shows [chart] at 300 x 300 in the middle of the 800 x 600 test surface.
Widget host(Widget chart) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: SizedBox(width: 300, height: 300, child: chart)),
);

/// A vertical list with [chart], 300 x 300 and centered in its row, below 400 pixels of other content and above 2000
/// more: while the list is not scrolled the chart covers y 400 ..< 700 of the 800 x 600 screen, as in
/// chart_gesture_recognizer_test.dart. Its lower part is off the screen, so gestures there start at or above the
/// chart's center.
Widget inList(Widget chart, ScrollController controller) => Directionality(
  textDirection: TextDirection.ltr,
  child: ListView(
    controller: controller,
    children: [
      const SizedBox(height: 400),
      Center(child: SizedBox(width: 300, height: 300, child: chart)),
      const SizedBox(height: 2000),
    ],
  ),
);

/// [millis] milliseconds.
Duration ms(int millis) => Duration(milliseconds: millis);

/// The screen position of the chart's top left corner.
Offset chartTopLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byType(ChartRenderBoxWidget));

/// The screen position [distance] pixels out from [chart]'s center at [angle] degrees (0 at 3 o'clock, increasing
/// clockwise). The center is the content center the touch listener measures angles and distances from, which is also
/// the center of a pie's circle box.
Offset pointAt(
  WidgetTester tester,
  PieRadarChartBase chart,
  double angle,
  double distance,
) {
  final p = chart.getPosition(chart.centerOffsets, distance, angle);
  return chartTopLeft(tester) + Offset(p.x, p.y);
}

/// Moves [gesture] by [offset] in moves of 4 px, so that the chart sees a move past its 8 dp rotation
/// threshold, and the next one, before a list's drag recognizer sees one past its 18 px touch slop.
Future<void> moveInSteps(TestGesture gesture, Offset offset) async {
  final steps = (offset.distance / 4).ceil();
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(offset / steps.toDouble());
  }
}

/// Moves [gesture] along the circle [fraction] of [chart]'s radius around its center from [fromAngle] by [sweep]
/// degrees, in moves of about 4 px.
Future<void> moveAround(
  WidgetTester tester,
  TestGesture gesture,
  PieRadarChartBase chart, {
  required double fromAngle,
  required double sweep,
  double fraction = 0.75,
}) async {
  final distance = chart.radius * fraction;
  final arc = distance * sweep.abs() * math.pi / 180;
  final steps = (arc / 4).ceil();
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(
      pointAt(tester, chart, fromAngle + sweep * i / steps, distance),
    );
  }
}

/// Taps [point] with a finger that goes down at [downMillis] and lifts at [upMillis]. The gesture detector reads
/// these times for its double tap window, so taps meant as single taps lie more than 300 ms apart.
Future<void> tap(
  WidgetTester tester,
  Offset point,
  int downMillis,
  int upMillis,
) async {
  final gesture = await tester.createGesture();
  await gesture.down(point, timeStamp: ms(downMillis));
  await gesture.up(timeStamp: ms(upMillis));
}
