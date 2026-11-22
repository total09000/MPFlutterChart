// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no test for the touch delivery of its View. Checks the
// gesture recognizer that folds Flutter's pointer events into Android-shaped ChartTouchEvents for the chart's touch
// listener, and that takes the gesture over from a scrolling parent at the moment the listener calls
// Chart.disableScroll, Android's requestDisallowInterceptTouchEvent(true).
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/chart.dart';
import 'package:mp_flutter_chart/src/charts/line_chart.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/listener/chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/listener/on_chart_gesture_listener.dart';
import 'package:mp_flutter_chart/src/widgets/chart_gesture_recognizer.dart';
import 'package:mp_flutter_chart/src/widgets/chart_render_box.dart';
import 'package:mp_flutter_chart/src/widgets/chart_touch_event.dart';

/// Five entries with x 0 ..< 5.
LineData _data() => LineData([
  LineDataSet([
    Entry(x: 0, y: 1),
    Entry(x: 1, y: 3),
    Entry(x: 2, y: 2),
    Entry(x: 3, y: 4),
    Entry(x: 4, y: 0),
  ], 'a'),
]);

/// A line chart that counts its scroll requests and the ends of its gestures.
class _LineChart extends LineChart {
  _LineChart() {
    data = _data();
    gestureListeners.add(
      OnChartGestureListener.fromFunction(
        onChartGestureEnd: (me, lastPerformedGesture) =>
            gestureEnds.add(lastPerformedGesture),
      ),
    );
  }

  int scrollDisables = 0;
  int scrollEnables = 0;
  final List<ChartGesture> gestureEnds = [];

  int get touchMode => chartTouchListener.touchMode;

  @override
  void disableScroll() {
    scrollDisables++;
    super.disableScroll();
  }

  @override
  void enableScroll() {
    scrollEnables++;
    super.enableScroll();
  }
}

/// Shows [chart] the way the widget layer's host does: its State lends the vsync and owns the chart's gesture
/// recognizer, which it disposes. [events] records every touch event the recognizer hands the chart, and [onEvent]
/// hears of each one as it is handed on.
class _ChartHost extends StatefulWidget {
  const _ChartHost({required this.chart, this.events, this.onEvent});

  final Chart chart;
  final List<ChartTouchEvent>? events;
  final void Function(ChartTouchEvent event)? onEvent;

  @override
  State<_ChartHost> createState() => _ChartHostState();
}

class _ChartHostState extends State<_ChartHost> with TickerProviderStateMixin {
  late final ChartGestureRecognizer recognizer = ChartGestureRecognizer(
    debugOwner: this,
    onTouch: (event) {
      widget.events?.add(event);
      widget.onEvent?.call(event);
      return widget.chart.onTouchEvent(event);
    },
  );

  @override
  void dispose() {
    recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChartRenderBoxWidget(
    chart: widget.chart,
    recognizer: recognizer,
    vsync: this,
  );
}

/// A vertical list with [host], 300 high, below 400 pixels of other content and above 2000 more: while the list is not
/// scrolled the chart covers y 400 ..< 700 of the 800 x 600 screen.
Widget _inList(Widget host, ScrollController controller) => Directionality(
  textDirection: TextDirection.ltr,
  child: ListView(
    controller: controller,
    children: [
      const SizedBox(height: 400),
      SizedBox(height: 300, child: host),
      const SizedBox(height: 2000),
    ],
  ),
);

/// [host] at 400 x 300 with its top left corner at (50, 100), in a column.
Widget _offset(Widget host) => Directionality(
  textDirection: TextDirection.ltr,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 100),
      Padding(
        padding: const EdgeInsets.only(left: 50),
        child: SizedBox(width: 400, height: 300, child: host),
      ),
    ],
  ),
);

/// Zooms [chart] in by 2 on both axes, with the view at the end of its vertical range that leaves room for a drag up by
/// 200 px (the y translation is at its largest).
void _zoomIn(LineChart chart) {
  chart.zoom(2, 2, 0, chart.height);
  expect(chart.isFullyZoomedOut, isFalse);
}

Offset _chartCenter(WidgetTester tester) =>
    tester.getCenter(find.byType(ChartRenderBoxWidget));

Duration _ms(int millis) => Duration(milliseconds: millis);

/// Moves [gesture] by [offset] in [steps] equal moves, the way a finger's movement arrives on a device: in small
/// steps (4 px for the default 200 px), so that the chart sees a move past its 3 dp drag trigger, and the next one,
/// before the list's drag recognizer sees one past its 18 px touch slop.
Future<void> _moveInSteps(
  TestGesture gesture,
  Offset offset, {
  int steps = 50,
}) async {
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(offset / steps.toDouble());
  }
}

/// Drags a finger from [start] by [offset] in small steps (see [_moveInSteps]) and lifts it.
Future<void> _drag(
  WidgetTester tester,
  Offset start,
  Offset offset, {
  int steps = 50,
}) async {
  final gesture = await tester.startGesture(start);
  await _moveInSteps(gesture, offset, steps: steps);
  await gesture.up();
  await tester.pump();
}

List<ChartTouchAction> _actions(List<ChartTouchEvent> events) => [
  for (final event in events) event.action,
];

int _cancels(List<ChartTouchEvent> events) =>
    events.where((e) => e.action == ChartTouchAction.cancel).length;

/// Joins every gesture arena it is given a pointer for and never claims one; records how each arena ends.
class _ArenaProbe extends OneSequenceGestureRecognizer {
  final List<int> accepted = [];
  final List<int> rejected = [];

  @override
  void handleEvent(PointerEvent event) =>
      stopTrackingIfPointerNoLongerDown(event);

  @override
  void acceptGesture(int pointer) => accepted.add(pointer);

  @override
  void rejectGesture(int pointer) {
    rejected.add(pointer);
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'arena probe';
}

/// Joins every gesture arena it is given a pointer for, never claims one, and logs each pointer event it gets.
class _OrderProbe extends OneSequenceGestureRecognizer {
  _OrderProbe(this.log);

  final List<String> log;

  @override
  void handleEvent(PointerEvent event) {
    log.add(switch (event) {
      PointerDownEvent() => 'probe down',
      PointerMoveEvent() => 'probe move',
      PointerUpEvent() => 'probe up',
      _ => 'probe ${event.runtimeType}',
    });
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'order probe';
}

void main() {
  group('in a vertical list', () {
    late ScrollController controller;
    late _LineChart chart;
    late List<ChartTouchEvent> events;

    Future<void> pumpList(WidgetTester tester) async {
      controller = ScrollController();
      addTearDown(controller.dispose);
      events = [];
      await tester.pumpWidget(
        _inList(_ChartHost(chart: chart, events: events), controller),
      );
    }

    testWidgets('a vertical drag on a fully zoomed out chart scrolls the list', (
      tester,
    ) async {
      chart = _LineChart();
      await pumpList(tester);
      expect(chart.isFullyZoomedOut, isTrue);

      await _drag(tester, _chartCenter(tester), const Offset(0, -200));

      expect(controller.offset, greaterThan(0));
      expect(chart.viewPortHandler.transY, 0);
      expect(chart.highlighted, isEmpty);
      // The list took the gesture over: the chart got Android's ACTION_CANCEL.
      expect(events.first.action, ChartTouchAction.down);
      expect(events.last.action, ChartTouchAction.cancel);
      expect(_cancels(events), 1);
      expect(chart.scrollDisables, 0);
      expect(chart.touchMode, ChartTouchListener.NONE);
    });

    testWidgets(
      'a vertical drag on a zoomed in chart drags the chart, not the list',
      (tester) async {
        chart = _LineChart();
        await pumpList(tester);
        _zoomIn(chart);
        final transY = chart.viewPortHandler.transY;
        expect(transY, greaterThan(200));

        await _drag(tester, _chartCenter(tester), const Offset(0, -200));

        expect(controller.offset, 0);
        expect(chart.viewPortHandler.transY, isNot(0));
        expect(chart.viewPortHandler.transY, closeTo(transY - 200, 1e-3));
        expect(chart.scrollDisables, greaterThan(0));
        expect(events.last.action, ChartTouchAction.up);
        expect(_cancels(events), 0);
        expect(chart.gestureEnds, [ChartGesture.DRAG]);
      },
    );

    testWidgets(
      'a horizontal drag on a fully zoomed out chart highlights, the list stays',
      (tester) async {
        chart = _LineChart();
        await pumpList(tester);

        await _drag(
          tester,
          _chartCenter(tester),
          const Offset(100, 0),
          steps: 25,
        );

        expect(chart.highlighted, isNotEmpty);
        expect(controller.offset, 0);
        expect(events.last.action, ChartTouchAction.up);
        expect(_cancels(events), 0);
      },
    );

    testWidgets(
      'a first move past the list slop goes to the list and cancels the drag of the chart',
      (tester) async {
        chart = _LineChart();
        await pumpList(tester);
        _zoomIn(chart);
        final transY = chart.viewPortHandler.transY;

        // tester.dragFrom moves 20 px at once first. The list's drag recognizer sees that move before the chart, passes
        // its 18 px slop and wins, so the chart gets a cancel instead of the move, as Android's list intercepts a first
        // move past its slop before the chart sees it. The chart never entered its drag mode: the gesture ends with
        // Kotlin's lastGesture as it was, NONE.
        await tester.dragFrom(_chartCenter(tester), const Offset(0, -200));
        await tester.pump();

        expect(controller.offset, greaterThan(0));
        expect(_actions(events), [
          ChartTouchAction.down,
          ChartTouchAction.cancel,
        ]);
        expect(chart.touchMode, ChartTouchListener.NONE);
        expect(chart.scrollDisables, 0);
        expect(chart.scrollEnables, 1);
        expect(chart.gestureEnds, [ChartGesture.NONE]);
        expect(chart.viewPortHandler.transY, transY);
      },
    );

    testWidgets(
      'a zoomed in chart whose claiming move also passes the list slop loses the gesture to the list',
      (tester) async {
        chart = _LineChart();
        await pumpList(tester);
        _zoomIn(chart);
        final transY = chart.viewPortHandler.transY;

        // The 4 px move passes the 3 dp drag trigger: the chart enters its drag mode and would claim the gesture on
        // its next move. That move reaches 20 px, past the list's 18 px slop, and the list sees it first and wins,
        // as Android's list intercepts that move before the chart calls requestDisallowInterceptTouchEvent.
        final gesture = await tester.startGesture(_chartCenter(tester));
        await gesture.moveBy(const Offset(0, -4));
        expect(chart.touchMode, ChartTouchListener.DRAG);
        await gesture.moveBy(const Offset(0, -16));
        await _moveInSteps(gesture, const Offset(0, -100), steps: 25);
        await gesture.up();
        await tester.pump();

        expect(_actions(events), [
          ChartTouchAction.down,
          ChartTouchAction.move,
          ChartTouchAction.cancel,
        ]);
        expect(chart.scrollDisables, 0);
        expect(chart.viewPortHandler.transY, transY);
        expect(controller.offset, greaterThan(0));
        expect(chart.gestureEnds, [ChartGesture.DRAG]);
      },
    );

    testWidgets('a two finger pinch zooms the chart, the list stays', (
      tester,
    ) async {
      chart = _LineChart()..isPinchZoomEnabled = true;
      await pumpList(tester);
      final center = _chartCenter(tester);

      // The fingers spread vertically from 40 to 80 px apart.
      final first = await tester.startGesture(center + const Offset(0, -20));
      final second = await tester.startGesture(center + const Offset(0, 20));
      await first.moveBy(const Offset(0, -20));
      await second.moveBy(const Offset(0, 20));
      await first.up();
      await second.up();
      await tester.pump();

      expect(chart.viewPortHandler.scaleX, closeTo(2, 1e-4));
      expect(chart.viewPortHandler.scaleY, closeTo(2, 1e-4));
      expect(controller.offset, 0);
      expect(_actions(events), [
        ChartTouchAction.down,
        ChartTouchAction.pointerDown,
        ChartTouchAction.move,
        ChartTouchAction.move,
        ChartTouchAction.pointerUp,
        ChartTouchAction.up,
      ]);
    });

    testWidgets('a double tap zooms the chart in by 1.4', (tester) async {
      chart = _LineChart();
      await pumpList(tester);
      final center = _chartCenter(tester);

      // Android's double tap: the second down at least 40 ms after the first up, within 300 ms of the first down.
      Future<void> tap(int downMillis, int upMillis) async {
        final gesture = await tester.createGesture();
        await gesture.down(center, timeStamp: _ms(downMillis));
        await gesture.up(timeStamp: _ms(upMillis));
      }

      await tap(1000, 1050);
      await tap(1150, 1200);
      await tester.pump();

      expect(chart.viewPortHandler.scaleX, closeTo(1.4, 1e-4));
      expect(chart.viewPortHandler.scaleY, closeTo(1.4, 1e-4));
      expect(controller.offset, 0);
    });

    testWidgets('a chart in a scrolled list gets its own coordinates', (
      tester,
    ) async {
      chart = _LineChart();
      await pumpList(tester);
      controller.jumpTo(100);
      await tester.pump();
      expect(_chartCenter(tester), const Offset(400, 450));

      final gesture = await tester.startGesture(const Offset(300, 350));
      await gesture.up();
      await tester.pump();

      expect(events.first.positions, [const Offset(300, 50)]);
    });

    testWidgets(
      'a down the chart does not consume leaves the gesture to the list',
      (tester) async {
        // Android: a view whose onTouchEvent returns false for ACTION_DOWN gets no more events of the gesture.
        chart = _LineChart()..isTouchEnabled = false;
        await pumpList(tester);
        _zoomIn(chart);
        final transY = chart.viewPortHandler.transY;

        await _drag(tester, _chartCenter(tester), const Offset(0, -200));

        expect(_actions(events), [ChartTouchAction.down]);
        expect(controller.offset, greaterThan(0));
        expect(chart.viewPortHandler.transY, transY);
      },
    );

    testWidgets('disableScroll outside a gesture does not claim the next one', (
      tester,
    ) async {
      // Android resets requestDisallowInterceptTouchEvent at every ACTION_DOWN.
      chart = _LineChart();
      await pumpList(tester);
      chart.disableScroll();

      await _drag(tester, _chartCenter(tester), const Offset(0, -200));

      expect(controller.offset, greaterThan(0));
      expect(events.last.action, ChartTouchAction.cancel);
    });

    testWidgets(
      'removing the chart during a drag it claimed cancels the drag once',
      (tester) async {
        chart = _LineChart();
        await pumpList(tester);
        _zoomIn(chart);

        final gesture = await tester.startGesture(_chartCenter(tester));
        await _moveInSteps(gesture, const Offset(0, -40), steps: 10);
        expect(chart.touchMode, ChartTouchListener.DRAG);
        expect(chart.scrollDisables, greaterThan(0));

        // Android's ViewGroup sends ACTION_CANCEL to a child that is removed during a gesture.
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
        expect(events.last.action, ChartTouchAction.cancel);
        expect(_cancels(events), 1);
        expect(chart.touchMode, ChartTouchListener.NONE);
        expect(chart.scrollEnables, 1);
        expect(chart.gestureEnds, [ChartGesture.DRAG]);

        final count = events.length;
        await gesture.moveBy(const Offset(0, -20));
        await gesture.up();
        await tester.pump(kLongPressTimeout);
        expect(events, hasLength(count));
      },
    );

    testWidgets(
      'removing the chart during a gesture it has not claimed cancels it once',
      (tester) async {
        chart = _LineChart();
        await pumpList(tester);

        final gesture = await tester.startGesture(_chartCenter(tester));
        await _moveInSteps(gesture, const Offset(0, -8), steps: 2);
        expect(chart.scrollDisables, 0);

        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
        expect(_actions(events), [
          ChartTouchAction.down,
          ChartTouchAction.move,
          ChartTouchAction.move,
          ChartTouchAction.cancel,
        ]);
        expect(chart.scrollEnables, 1);

        await gesture.up();
        await tester.pump(kLongPressTimeout);
        expect(events, hasLength(4));
      },
    );
  });

  group('touch events', () {
    testWidgets(
      "pointer events become Android-shaped touch events in the chart's coordinates",
      (tester) async {
        final chart = _LineChart();
        final events = <ChartTouchEvent>[];
        await tester.pumpWidget(
          _offset(_ChartHost(chart: chart, events: events)),
        );

        final a = await tester.createGesture();
        await a.down(const Offset(150, 200), timeStamp: _ms(10));
        final b = await tester.createGesture();
        await b.down(const Offset(250, 220), timeStamp: _ms(20));
        await a.moveTo(const Offset(140, 210), timeStamp: _ms(30));
        await a.up(timeStamp: _ms(40));
        await b.moveTo(const Offset(260, 230), timeStamp: _ms(50));
        await b.up(timeStamp: _ms(60));
        await tester.pump();

        expect(_actions(events), [
          ChartTouchAction.down,
          ChartTouchAction.pointerDown,
          ChartTouchAction.move,
          ChartTouchAction.pointerUp,
          ChartTouchAction.move,
          ChartTouchAction.up,
        ]);
        final idA = events[0].pointerIds.single;
        final idB = events[1].pointerIds[1];
        expect(idB, isNot(idA));

        // The chart's top left corner is at (50, 100).
        expect(events[0].pointerIds, [idA]);
        expect(events[0].positions, [const Offset(100, 100)]);

        expect(events[1].pointerIds, [idA, idB]);
        expect(events[1].actionIndex, 1);
        expect(events[1].positions, [
          const Offset(100, 100),
          const Offset(200, 120),
        ]);

        expect(events[2].pointerIds, [idA, idB]);
        expect(events[2].positions, [
          const Offset(90, 110),
          const Offset(200, 120),
        ]);

        // Android's ACTION_POINTER_UP still holds the pointer that lifts.
        expect(events[3].pointerIds, [idA, idB]);
        expect(events[3].actionIndex, 0);
        expect(events[3].positions, [
          const Offset(90, 110),
          const Offset(200, 120),
        ]);

        expect(events[4].pointerIds, [idB]);
        expect(events[4].positions, [const Offset(210, 130)]);

        expect(events[5].pointerIds, [idB]);
        expect(events[5].actionIndex, 0);
        expect(events[5].positions, [const Offset(210, 130)]);

        expect(
          [for (final e in events) e.eventTimeMillis],
          [10, 20, 30, 40, 50, 60],
        );

        // The listener keeps events: no two share their lists.
        for (var i = 0; i < events.length; i++) {
          for (var j = i + 1; j < events.length; j++) {
            expect(
              identical(events[i].positions, events[j].positions),
              isFalse,
            );
            expect(
              identical(events[i].pointerIds, events[j].pointerIds),
              isFalse,
            );
          }
        }
      },
    );

    testWidgets(
      'a recognizer around the chart sees each event of a finger before the chart, after the down',
      (tester) async {
        // Android's parent sees each MotionEvent in onInterceptTouchEvent before the chart's onTouchEvent.
        final chart = _LineChart();
        final log = <String>[];
        final probe = _OrderProbe(log);
        addTearDown(probe.dispose);
        await tester.pumpWidget(
          _offset(
            Listener(
              onPointerDown: probe.addPointer,
              child: _ChartHost(
                chart: chart,
                onEvent: (event) => log.add('chart ${event.action.name}'),
              ),
            ),
          ),
        );

        final gesture = await tester.startGesture(const Offset(250, 250));
        await gesture.moveBy(const Offset(10, 0));
        await gesture.moveBy(const Offset(10, 0));
        await gesture.up();
        await tester.pump();

        // The chart gets the down first (it is the innermost) and then hands every later event to the others first.
        expect(log, [
          'chart down',
          'probe down',
          'probe move',
          'chart move',
          'probe move',
          'chart move',
          'probe up',
          'chart up',
        ]);
      },
    );

    testWidgets("a cancelled pointer cancels the chart's gesture once", (
      tester,
    ) async {
      final chart = _LineChart();
      final events = <ChartTouchEvent>[];
      await tester.pumpWidget(
        _offset(_ChartHost(chart: chart, events: events)),
      );
      _zoomIn(chart);

      final gesture = await tester.startGesture(const Offset(250, 250));
      await _moveInSteps(gesture, const Offset(0, -40), steps: 10);
      expect(chart.touchMode, ChartTouchListener.DRAG);

      await gesture.cancel();
      await tester.pump();

      expect(events.last.action, ChartTouchAction.cancel);
      expect(_cancels(events), 1);
      expect(chart.touchMode, ChartTouchListener.NONE);
      expect(chart.scrollEnables, 1);
      expect(chart.gestureEnds, [ChartGesture.DRAG]);
    });

    testWidgets(
      'a finger that goes down after the chart claimed the gesture is claimed at once',
      (tester) async {
        // Without scaling the listener does not ask again on the second finger. Once a view asked its parent not to
        // intercept, Android keeps every later finger of the gesture with it.
        final chart = _LineChart()..isScaleEnabled = false;
        final events = <ChartTouchEvent>[];
        final probe = _ArenaProbe();
        addTearDown(probe.dispose);
        await tester.pumpWidget(
          _offset(
            Listener(
              onPointerDown: probe.addPointer,
              child: _ChartHost(chart: chart, events: events),
            ),
          ),
        );
        _zoomIn(chart);

        final first = await tester.startGesture(const Offset(250, 250));
        expect(probe.rejected, isEmpty);
        await _moveInSteps(first, const Offset(0, -8), steps: 2);
        expect(chart.scrollDisables, 1);
        expect(probe.rejected, hasLength(1));

        final second = await tester.startGesture(const Offset(300, 250));
        expect(events.last.action, ChartTouchAction.pointerDown);
        expect(chart.scrollDisables, 1);
        expect(probe.rejected, hasLength(2));
        expect(probe.accepted, isEmpty);

        await second.up();
        await first.up();
        await tester.pump();
        expect(probe.accepted, isEmpty);
      },
    );

    testWidgets('a mouse drags the chart with its primary button only', (
      tester,
    ) async {
      final chart = _LineChart();
      final events = <ChartTouchEvent>[];
      await tester.pumpWidget(
        _offset(_ChartHost(chart: chart, events: events)),
      );
      _zoomIn(chart);
      final transY = chart.viewPortHandler.transY;

      final secondary = await tester.startGesture(
        const Offset(250, 250),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await _moveInSteps(secondary, const Offset(0, -40), steps: 10);
      await secondary.up();
      await tester.pump();
      expect(events, isEmpty);
      expect(chart.viewPortHandler.transY, transY);

      final primary = await tester.startGesture(
        const Offset(250, 250),
        kind: PointerDeviceKind.mouse,
      );
      await _moveInSteps(primary, const Offset(0, -40), steps: 10);
      await primary.up();
      await tester.pump();
      expect(events.first.action, ChartTouchAction.down);
      expect(events.last.action, ChartTouchAction.up);
      expect(chart.viewPortHandler.transY, closeTo(transY - 40, 1e-3));
    });

    testWidgets('trackpad pan and zoom gestures do not reach the chart', (
      tester,
    ) async {
      final chart = _LineChart();
      final events = <ChartTouchEvent>[];
      await tester.pumpWidget(
        _offset(_ChartHost(chart: chart, events: events)),
      );

      final trackpad = await tester.startGesture(
        const Offset(250, 250),
        kind: PointerDeviceKind.trackpad,
      );
      await trackpad.panZoomUpdate(
        const Offset(250, 250),
        pan: const Offset(30, 10),
        scale: 2,
      );
      await trackpad.panZoomEnd();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(events, isEmpty);
      expect(chart.viewPortHandler.scaleX, 1);
      expect(chart.highlighted, isEmpty);
    });
  });
}
