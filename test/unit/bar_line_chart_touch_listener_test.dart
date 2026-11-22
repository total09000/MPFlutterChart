// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for its touch listeners. Drives the ported
// BarLineChartTouchListener state machine (and its stand-ins for Android's GestureDetector and VelocityTracker) with
// ChartTouchEvents, without a widget. The tests run in testWidgets only for its fake clock: Flutter's
// VelocityTracker reads the gesture binding's sampling clock, and the long press timer runs on fake time.
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show kLongPressTimeout, kTouchSlop;
import 'package:flutter/scheduler.dart'
    show Ticker, TickerCallback, TickerProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/bar_line_chart_base.dart';
import 'package:mp_flutter_chart/src/charts/chart_host.dart';
import 'package:mp_flutter_chart/src/charts/horizontal_bar_chart.dart';
import 'package:mp_flutter_chart/src/charts/line_chart.dart';
import 'package:mp_flutter_chart/src/components/y_axis_dependency.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/listener/bar_line_chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/listener/chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/listener/on_chart_gesture_listener.dart';
import 'package:mp_flutter_chart/src/widgets/chart_touch_event.dart';
import 'package:mp_flutter_chart/src/widgets/chart_velocity_tracker.dart';

/// Records the scroll requests of the touch listener; [vsync] is null unless a test drives the deceleration ticker.
class _FakeHost implements ChartHost {
  _FakeHost([this.vsync]);

  @override
  final TickerProvider? vsync;

  int paints = 0;
  int scrollDisables = 0;
  int scrollEnables = 0;

  @override
  void markNeedsPaint() => paints++;

  @override
  void postFrame(void Function() job) => job();

  @override
  void disableScroll() => scrollDisables++;

  @override
  void enableScroll() => scrollEnables++;
}

/// Hands out plain tickers and keeps them, so a test can see whether the deceleration ticker still runs.
class _RecordingVSync implements TickerProvider {
  final List<Ticker> tickers = [];

  @override
  Ticker createTicker(TickerCallback onTick) {
    final ticker = Ticker(onTick);
    tickers.add(ticker);
    return ticker;
  }
}

/// Counts the gesture callbacks.
class _Gestures extends OnChartGestureListener {
  final List<ChartTouchEvent> longPresses = [];
  final List<ChartTouchEvent> singleTaps = [];
  final List<ChartTouchEvent> doubleTaps = [];
  int flings = 0;

  @override
  void onChartLongPressed(ChartTouchEvent me) => longPresses.add(me);

  @override
  void onChartSingleTapped(ChartTouchEvent me) => singleTaps.add(me);

  @override
  void onChartDoubleTapped(ChartTouchEvent me) => doubleTaps.add(me);

  @override
  void onChartFling(
    ChartTouchEvent? me1,
    ChartTouchEvent me2,
    double velocityX,
    double velocityY,
  ) => flings++;
}

/// Ten entries on the line y = x for x = 0 .. 9.
LineData _data() => LineData([
  LineDataSet([
    for (var i = 0; i < 10; i++) Entry(x: i.toDouble(), y: i.toDouble()),
  ], 'a'),
]);

/// A 400 x 300 chart with ten entries, hosted by [host].
LineChart _chart(ChartHost host) {
  final chart = LineChart()..host = host;
  chart
    ..onSizeChanged(400, 300)
    ..data = _data();
  return chart;
}

/// A 400 x 300 horizontal bar chart with ten bars at x = 0 .. 9, `x + 1` long, hosted by [host]; [setup] runs before
/// the chart gets its data and size. A real chart, since the listener asks `chart is HorizontalBarChart`.
HorizontalBarChart _horizontalBarChart(
  ChartHost host, [
  void Function(HorizontalBarChart chart)? setup,
]) {
  final chart = HorizontalBarChart()..host = host;
  setup?.call(chart);
  chart
    ..onSizeChanged(400, 300)
    ..data = BarData([
      BarDataSet([
        for (var i = 0; i < 10; i++) BarEntry(x: i.toDouble(), y: i + 1.0),
      ], 'bars'),
    ]);
  return chart;
}

BarLineChartTouchListener _listener(BarLineChartBase chart) =>
    chart.chartTouchListener as BarLineChartTouchListener;

ChartTouchEvent _event(
  ChartTouchAction action,
  int time,
  List<ui.Offset> positions, {
  List<int>? ids,
  int actionIndex = 0,
}) => ChartTouchEvent(
  action: action,
  actionIndex: actionIndex,
  pointerIds: ids ?? [for (var i = 0; i < positions.length; i++) i],
  positions: positions,
  eventTimeMillis: time,
);

/// Sends one-finger events to a chart.
extension on BarLineChartBase {
  bool down(double x, double y, int time) =>
      onTouchEvent(_event(ChartTouchAction.down, time, [ui.Offset(x, y)]));

  bool move(double x, double y, int time) =>
      onTouchEvent(_event(ChartTouchAction.move, time, [ui.Offset(x, y)]));

  bool up(double x, double y, int time) =>
      onTouchEvent(_event(ChartTouchAction.up, time, [ui.Offset(x, y)]));

  /// Zooms by [scale] on both axes around the content center, so the chart can be dragged.
  void zoomBy(double scale) {
    final center = viewPortHandler.contentCenter;
    zoom(scale, scale, center.x, center.y);
  }
}

void main() {
  group('BarLineChartTouchListener', () {
    testWidgets(
      'fully zoomed out, a drag past the touch slop along x moves the highlight and leaves scrolling alone',
      (tester) async {
        final host = _FakeHost();
        final chart = _chart(host);
        final listener = _listener(chart);
        expect(chart.isFullyZoomedOut, isTrue);
        expect(chart.hasNoDragOffset, isTrue);

        expect(chart.down(100, 100, 0), isTrue);
        chart.move(104, 100, 16);
        // Past dragTriggerDist (3) but within kTouchSlop: no highlight drag yet.
        expect(listener.lastHighlighted, isNull);
        expect(chart.highlighted, isEmpty);

        chart.move(100 + kTouchSlop + 1, 100, 32);
        expect(listener.lastHighlighted, isNotNull);
        expect(chart.highlighted, hasLength(1));
        expect(listener.lastGesture, ChartGesture.DRAG);
        expect(listener.touchMode, ChartTouchListener.NONE);
        expect(host.scrollDisables, 0);

        // Once the highlight drag runs, a vertical move keeps it running and still does not claim the gesture.
        chart.move(100, 160, 48);
        expect(host.scrollDisables, 0);

        chart.up(100, 160, 64);
        expect(host.scrollEnables, 1);
        expect(listener.touchMode, ChartTouchListener.NONE);
      },
    );

    testWidgets(
      'zoomed in, the move past dragTriggerDist starts a drag and the next move claims the gesture and pans',
      (tester) async {
        final host = _FakeHost();
        final chart = _chart(host);
        final listener = _listener(chart);
        chart.zoomBy(2);
        expect(chart.isFullyZoomedOut, isFalse);
        final transYBefore = chart.viewPortHandler.transY;

        chart.down(100, 100, 0);
        chart.move(100, 104, 16);
        // Kotlin's MOVE branch is if / else-if: the move that crosses dragTriggerDist only enters DRAG.
        expect(listener.touchMode, ChartTouchListener.DRAG);
        expect(listener.lastGesture, ChartGesture.DRAG);
        expect(host.scrollDisables, 0);
        expect(chart.viewPortHandler.transY, transYBefore);

        chart.move(100, 110, 32);
        expect(host.scrollDisables, 1);
        expect(chart.viewPortHandler.transY, isNot(0));
        expect(chart.viewPortHandler.transY, closeTo(transYBefore + 10, 1e-3));

        chart.up(100, 110, 32);
        expect(listener.touchMode, ChartTouchListener.NONE);
        expect(host.scrollEnables, 1);
        listener.stopDeceleration();
      },
    );

    testWidgets(
      'two fingers spreading to twice their distance pinch zoom by 2',
      (tester) async {
        final host = _FakeHost();
        final chart = _chart(host)..isPinchZoomEnabled = true;
        final listener = _listener(chart);

        chart.down(150, 150, 0);
        chart.onTouchEvent(
          _event(ChartTouchAction.pointerDown, 8, [
            const ui.Offset(150, 150),
            const ui.Offset(250, 150),
          ], actionIndex: 1),
        );
        expect(listener.touchMode, ChartTouchListener.PINCH_ZOOM);
        expect(host.scrollDisables, 1);

        chart.onTouchEvent(
          _event(ChartTouchAction.move, 16, [
            const ui.Offset(100, 150),
            const ui.Offset(300, 150),
          ]),
        );
        expect(listener.touchMode, ChartTouchListener.PINCH_ZOOM);
        expect(listener.lastGesture, ChartGesture.PINCH_ZOOM);
        expect(chart.viewPortHandler.scaleX, closeTo(2, 1e-4));
        expect(chart.viewPortHandler.scaleY, closeTo(2, 1e-4));

        chart.onTouchEvent(
          _event(ChartTouchAction.pointerUp, 24, [
            const ui.Offset(100, 150),
            const ui.Offset(300, 150),
          ], actionIndex: 1),
        );
        expect(listener.touchMode, ChartTouchListener.POST_ZOOM);
        chart.up(100, 150, 32);
        expect(listener.touchMode, ChartTouchListener.NONE);
        expect(chart.viewPortHandler.scaleX, closeTo(2, 1e-4));
      },
    );

    testWidgets('a double tap zooms in by 1.4', (tester) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      final gestures = _Gestures();
      chart.onChartGestureListener = gestures;
      expect(chart.isDoubleTapToZoomEnabled, isTrue);

      chart.down(200, 150, 0);
      chart.up(200, 150, 50);
      // The first tap is a single tap.
      expect(gestures.singleTaps, hasLength(1));
      expect(chart.viewPortHandler.scaleX, 1);

      chart.down(200, 150, 150);
      expect(gestures.doubleTaps, hasLength(1));
      // Android calls onDoubleTap with the down event of the first tap.
      expect(gestures.doubleTaps.single.eventTimeMillis, 0);
      expect(listener.lastGesture, ChartGesture.DOUBLE_TAP);
      expect(chart.viewPortHandler.scaleX, closeTo(1.4, 1e-4));
      expect(chart.viewPortHandler.scaleY, closeTo(1.4, 1e-4));

      // The up of the second tap is no single tap.
      chart.up(200, 150, 200);
      expect(gestures.singleTaps, hasLength(1));
      expect(chart.viewPortHandler.scaleX, closeTo(1.4, 1e-4));
    });

    testWidgets(
      'a fling decelerates: computeScroll moves transX monotonically until the velocity reaches zero',
      (tester) async {
        final host = _FakeHost();
        final chart = _chart(host);
        final listener = _listener(chart);
        chart.zoomBy(4);
        var now = 10000;
        listener.clock = () => now;

        chart.down(100, 150, 0);
        chart.move(120, 150, 16);
        expect(listener.touchMode, ChartTouchListener.DRAG);
        chart.move(140, 150, 32);
        chart.move(160, 150, 48);
        final transXAfterDrag = chart.viewPortHandler.transX;
        chart.up(160, 150, 48);

        final xs = <double>[transXAfterDrag];
        var steps = 0;
        while (steps < 1000) {
          now += 16;
          final paints = host.paints;
          chart.computeScroll();
          steps++;
          if (host.paints == paints) break;
          xs.add(chart.viewPortHandler.transX);
        }
        // About 1250 px/s, multiplied by 0.9 per step until below 0.01.
        expect(steps, inExclusiveRange(50, 1000));
        expect(xs.last, greaterThan(transXAfterDrag + 50));
        for (var i = 1; i < xs.length; i++) {
          expect(xs[i], greaterThanOrEqualTo(xs[i - 1]));
        }
        expect(xs[1], greaterThan(xs[0]));

        // Stopped: further calls do nothing.
        final stoppedX = chart.viewPortHandler.transX;
        final stoppedPaints = host.paints;
        now += 16;
        chart.computeScroll();
        expect(chart.viewPortHandler.transX, stoppedX);
        expect(host.paints, stoppedPaints);
      },
    );

    testWidgets(
      'with a host vsync a ticker runs the deceleration and stops when it ends',
      (tester) async {
        final vsync = _RecordingVSync();
        final host = _FakeHost(vsync);
        final chart = _chart(host);
        final listener = _listener(chart);
        listener.clock = () =>
            tester.binding.clock.now().millisecondsSinceEpoch;
        chart.zoomBy(4);

        chart.down(100, 150, 0);
        chart.move(120, 150, 16);
        chart.move(140, 150, 32);
        chart.move(160, 150, 48);
        expect(vsync.tickers, isEmpty);
        final transXAfterDrag = chart.viewPortHandler.transX;
        chart.up(160, 150, 48);

        expect(vsync.tickers, hasLength(1));
        final ticker = vsync.tickers.single;
        expect(ticker.isActive, isTrue);

        var frames = 0;
        while (ticker.isActive && frames < 1000) {
          await tester.pump(const Duration(milliseconds: 16));
          frames++;
        }
        expect(ticker.isActive, isFalse);
        expect(frames, inExclusiveRange(50, 1000));
        expect(chart.viewPortHandler.transX, greaterThan(transXAfterDrag + 50));
        expect(vsync.tickers, hasLength(1));
      },
    );

    testWidgets(
      'a new touch and onDetachedFromWindow stop the deceleration ticker',
      (tester) async {
        final vsync = _RecordingVSync();
        final host = _FakeHost(vsync);
        final chart = _chart(host);
        final listener = _listener(chart);
        listener.clock = () =>
            tester.binding.clock.now().millisecondsSinceEpoch;
        chart.zoomBy(4);

        void fling(int t) {
          chart.down(100, 150, t);
          chart.move(120, 150, t + 16);
          chart.move(140, 150, t + 32);
          chart.move(160, 150, t + 48);
          chart.up(160, 150, t + 48);
        }

        fling(0);
        expect(vsync.tickers.single.isActive, isTrue);
        await tester.pump(const Duration(milliseconds: 16));

        // ACTION_DOWN stops the deceleration.
        chart.down(300, 150, 1000);
        expect(vsync.tickers.single.isActive, isFalse);
        chart.up(300, 150, 1010);
        expect(vsync.tickers, hasLength(1));

        fling(2000);
        expect(vsync.tickers, hasLength(2));
        expect(vsync.tickers.last.isActive, isTrue);
        await tester.pump(const Duration(milliseconds: 16));

        chart.onDetachedFromWindow();
        expect(vsync.tickers.last.isActive, isFalse);
        final x = chart.viewPortHandler.transX;
        await tester.pump(const Duration(milliseconds: 16));
        chart.computeScroll();
        expect(chart.viewPortHandler.transX, x);
      },
    );

    testWidgets(
      'a long press reports onChartLongPressed and its up is no single tap',
      (tester) async {
        final host = _FakeHost();
        final chart = _chart(host);
        final listener = _listener(chart);
        final gestures = _Gestures();
        chart.onChartGestureListener = gestures;

        chart.down(200, 150, 0);
        await tester.pump(kLongPressTimeout - const Duration(milliseconds: 1));
        expect(gestures.longPresses, isEmpty);
        await tester.pump(const Duration(milliseconds: 1));
        expect(gestures.longPresses, hasLength(1));
        expect(gestures.longPresses.single.action, ChartTouchAction.down);
        expect(listener.lastGesture, ChartGesture.LONG_PRESS);

        chart.up(200, 150, 600);
        expect(gestures.singleTaps, isEmpty);
        expect(chart.highlighted, isEmpty);
      },
    );

    testWidgets('no long press after an up before the timeout', (tester) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final gestures = _Gestures();
      chart.onChartGestureListener = gestures;

      chart.down(200, 150, 0);
      await tester.pump(const Duration(milliseconds: 200));
      chart.up(200, 150, 200);
      await tester.pump(kLongPressTimeout);
      expect(gestures.longPresses, isEmpty);
      expect(gestures.singleTaps, hasLength(1));
    });

    testWidgets(
      'no long press after a drag that the gesture detector did not see end (deliberate deviation)',
      (tester) async {
        final host = _FakeHost();
        final chart = _chart(host);
        final listener = _listener(chart);
        final gestures = _Gestures();
        chart.onChartGestureListener = gestures;
        chart.zoomBy(2);

        chart.down(100, 100, 0);
        // Within kTouchSlop, so the detector keeps its long press; the listener enters DRAG and feeds it no more.
        chart.move(104, 100, 16);
        chart.move(110, 100, 32);
        expect(listener.touchMode, ChartTouchListener.DRAG);
        chart.up(110, 100, 300);
        await tester.pump(kLongPressTimeout);
        expect(gestures.longPresses, isEmpty);
      },
    );

    testWidgets(
      'like Android, a drag that started within the touch slop and is still held reports a long press',
      (tester) async {
        final host = _FakeHost();
        final chart = _chart(host);
        final listener = _listener(chart);
        final gestures = _Gestures();
        chart.onChartGestureListener = gestures;
        chart.zoomBy(2);

        chart.down(100, 100, 0);
        chart.move(104, 100, 16);
        chart.move(150, 100, 32);
        expect(listener.touchMode, ChartTouchListener.DRAG);
        await tester.pump(kLongPressTimeout);
        expect(gestures.longPresses, hasLength(1));
        expect(listener.lastGesture, ChartGesture.LONG_PRESS);
        chart.up(150, 100, 600);
        expect(listener.touchMode, ChartTouchListener.NONE);
      },
    );

    testWidgets('a tap highlights the entry and a tap on it again clears it', (
      tester,
    ) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      final gestures = _Gestures();
      chart.onChartGestureListener = gestures;
      expect(chart.isHighlightPerTapEnabled, isTrue);
      final pixel = chart
          .getTransformer(AxisDependency.LEFT)
          .getPixelForValues(5, 5);

      chart.down(pixel.x, pixel.y, 0);
      chart.up(pixel.x, pixel.y, 50);
      expect(gestures.singleTaps, hasLength(1));
      expect(listener.lastGesture, ChartGesture.SINGLE_TAP);
      expect(chart.highlighted, hasLength(1));
      expect(chart.highlighted.single.x, 5);
      expect(listener.lastHighlighted, isNotNull);
      expect(listener.lastHighlighted!.x, 5);

      // Later than kDoubleTapTimeout, so a second single tap rather than a double tap.
      chart.down(pixel.x, pixel.y, 1000);
      chart.up(pixel.x, pixel.y, 1050);
      expect(gestures.singleTaps, hasLength(2));
      expect(gestures.doubleTaps, isEmpty);
      expect(chart.highlighted, isEmpty);
      expect(listener.lastHighlighted, isNull);
      expect(chart.viewPortHandler.scaleX, 1);
    });

    testWidgets(
      'a tap does nothing to the highlight while isHighlightPerTapEnabled is false',
      (tester) async {
        final host = _FakeHost();
        final chart = _chart(host)..isHighlightPerTapEnabled = false;
        final gestures = _Gestures();
        chart.onChartGestureListener = gestures;
        final pixel = chart
            .getTransformer(AxisDependency.LEFT)
            .getPixelForValues(5, 5);

        chart.down(pixel.x, pixel.y, 0);
        chart.up(pixel.x, pixel.y, 50);
        expect(gestures.singleTaps, hasLength(1));
        expect(chart.highlighted, isEmpty);
      },
    );

    testWidgets('a fast highlight drag ends in a fling', (tester) async {
      final host = _FakeHost();
      final chart = _chart(host);
      final listener = _listener(chart);
      final gestures = _Gestures();
      chart.onChartGestureListener = gestures;

      chart.down(100, 150, 0);
      chart.move(130, 150, 16);
      chart.move(160, 150, 32);
      chart.move(190, 150, 48);
      chart.up(190, 150, 48);
      expect(gestures.flings, 1);
      expect(listener.lastGesture, ChartGesture.FLING);
    });

    testWidgets(
      'without data onTouchEvent returns false and the listener sees nothing',
      (tester) async {
        final host = _FakeHost();
        final chart = LineChart()..host = host;
        chart.onSizeChanged(400, 300);
        final listener = _listener(chart);
        final gestures = _Gestures();
        chart.onChartGestureListener = gestures;

        expect(chart.down(200, 150, 0), isFalse);
        expect(chart.up(200, 150, 50), isFalse);
        expect(gestures.singleTaps, isEmpty);
        expect(listener.lastGesture, ChartGesture.NONE);

        chart.data = _data();
        expect(chart.down(200, 150, 1000), isTrue);
        expect(chart.up(200, 150, 1050), isTrue);
        expect(gestures.singleTaps, hasLength(1));
      },
    );

    testWidgets(
      'fully zoomed out, a HorizontalBarChart highlights on a drag past the touch slop along y, '
      'its x axis, and leaves scrolling alone',
      (tester) async {
        final host = _FakeHost();
        final chart = _horizontalBarChart(host);
        final listener = _listener(chart);
        expect(chart.isFullyZoomedOut, isTrue);
        final start = chart.getPixelForValues(1, 2, AxisDependency.LEFT);
        final target = chart.getPixelForValues(1, 5, AxisDependency.LEFT);
        expect(start.y - target.y, greaterThan(kTouchSlop));

        chart.down(start.x, start.y, 0);
        chart.move(start.x, target.y, 16);

        expect(listener.lastHighlighted, isNotNull);
        expect(listener.lastHighlighted!.x, 5);
        expect(chart.highlighted.single.x, 5);
        expect(listener.lastGesture, ChartGesture.DRAG);
        expect(listener.touchMode, ChartTouchListener.NONE);
        expect(host.scrollDisables, 0);

        chart.up(start.x, target.y, 32);
        expect(host.scrollEnables, 1);
      },
    );

    testWidgets(
      'fully zoomed out, a HorizontalBarChart whose parent intercepts the move along y keeps its highlight, '
      'and the gesture ends as NONE',
      (tester) async {
        // Android's list intercepts the move that passes its touch slop: the chart sees the down and a cancel only.
        final host = _FakeHost();
        final chart = _horizontalBarChart(host);
        final listener = _listener(chart);
        final ends = <ChartGesture>[];
        chart.onChartGestureListener = OnChartGestureListener.fromFunction(
          onChartGestureEnd: (me, lastPerformedGesture) =>
              ends.add(lastPerformedGesture),
        );
        chart.highlightValue(8, 0);
        final start = chart.getPixelForValues(1, 2, AxisDependency.LEFT);

        chart.down(start.x, start.y, 0);
        chart.onTouchEvent(
          _event(ChartTouchAction.cancel, 16, [ui.Offset(start.x, start.y)]),
        );

        expect(chart.highlighted.single.x, 8);
        expect(listener.lastHighlighted!.x, 8);
        expect(listener.lastGesture, ChartGesture.NONE);
        expect(ends, [ChartGesture.NONE]);
        expect(listener.touchMode, ChartTouchListener.NONE);
        expect(host.scrollDisables, 0);
        expect(host.scrollEnables, 1);
      },
    );

    testWidgets(
      'fully zoomed out, a drag along x on a HorizontalBarChart crosses its x axis and does not highlight',
      (tester) async {
        final host = _FakeHost();
        final chart = _horizontalBarChart(host);
        final listener = _listener(chart);
        final start = chart.getPixelForValues(1, 2, AxisDependency.LEFT);

        chart.down(start.x, start.y, 0);
        chart.move(start.x + kTouchSlop + 40, start.y, 16);

        expect(listener.lastHighlighted, isNull);
        expect(chart.highlighted, isEmpty);
        expect(listener.touchMode, ChartTouchListener.NONE);
        expect(host.scrollDisables, 0);
        chart.up(start.x + kTouchSlop + 40, start.y, 32);
      },
    );

    testWidgets(
      'dragging a zoomed in HorizontalBarChart on an inverted axis mirrors the horizontal move, '
      'not the vertical one',
      (tester) async {
        final host = _FakeHost();
        final chart = _horizontalBarChart(
          host,
          (chart) => chart.axisLeft.isInverted = true,
        );
        final listener = _listener(chart);
        chart.zoomBy(2);
        final transXBefore = chart.viewPortHandler.transX;
        final transYBefore = chart.viewPortHandler.transY;

        chart.down(200, 150, 0);
        chart.move(210, 150, 16);
        expect(listener.touchMode, ChartTouchListener.DRAG);
        chart.move(220, 160, 32);

        expect(host.scrollDisables, 1);
        expect(
          chart.viewPortHandler.transX,
          closeTo(transXBefore - 20, 1e-3),
        );
        expect(
          chart.viewPortHandler.transY,
          closeTo(transYBefore + 10, 1e-3),
        );

        chart.up(220, 160, 32);
        listener.stopDeceleration();
      },
    );

    test('distance is the straight line distance', () {
      expect(ChartTouchListener.distance(4, 1, 6, 2), closeTo(5, 1e-6));
    });
  });

  group('ChartVelocityTracker', () {
    /// Two fingers 100 px apart that move by [dx0] and [dx1] every 16 ms, then the second one lifts.
    ChartVelocityTracker trackPinch(double dx0, double dx1) {
      final tracker = ChartVelocityTracker();
      tracker.addMovement(
        _event(ChartTouchAction.down, 0, [const ui.Offset(100, 100)]),
      );
      tracker.addMovement(
        _event(ChartTouchAction.pointerDown, 8, [
          const ui.Offset(100, 100),
          const ui.Offset(200, 100),
        ], actionIndex: 1),
      );
      for (var i = 1; i <= 3; i++) {
        tracker.addMovement(
          _event(ChartTouchAction.move, 8 + 16 * i, [
            ui.Offset(100 + dx0 * i, 100),
            ui.Offset(200 + dx1 * i, 100),
          ]),
        );
      }
      final up = _event(ChartTouchAction.pointerUp, 56, [
        ui.Offset(100 + dx0 * 3, 100),
        ui.Offset(200 + dx1 * 3, 100),
      ], actionIndex: 1);
      tracker.addMovement(up);
      ChartVelocityTracker.pointerUpCleanUpIfNecessary(up, tracker);
      tracker.computeCurrentVelocity(1000);
      return tracker;
    }

    testWidgets(
      'pointerUpCleanUpIfNecessary clears the tracker when the lifted finger moved against another',
      (tester) async {
        final tracker = trackPinch(-10, 10);
        expect(tracker.getXVelocity(0), 0);
        expect(tracker.getXVelocity(1), 0);
      },
    );

    testWidgets(
      'pointerUpCleanUpIfNecessary keeps the tracker when the fingers moved together',
      (tester) async {
        final tracker = trackPinch(10, 10);
        // The first finger rested from its down to the second finger's down, so only its sign is certain.
        expect(tracker.getXVelocity(0), greaterThan(0));
        expect(tracker.getXVelocity(1), closeTo(625, 1));
        expect(tracker.getYVelocity(1), closeTo(0, 1e-6));
      },
    );

    testWidgets(
      'computeCurrentVelocity scales to units and clamps each axis to the maximum; unknown pointers are 0',
      (tester) async {
        final tracker = ChartVelocityTracker();
        for (var i = 0; i < 4; i++) {
          tracker.addMovement(
            _event(
              i == 0 ? ChartTouchAction.down : ChartTouchAction.move,
              16 * i,
              [ui.Offset(100 + 20.0 * i, 100 - 20.0 * i)],
            ),
          );
        }
        tracker.computeCurrentVelocity(1000);
        expect(tracker.getXVelocity(0), closeTo(1250, 1));
        expect(tracker.getYVelocity(0), closeTo(-1250, 1));
        expect(tracker.getXVelocity(7), 0);

        tracker.computeCurrentVelocity(1000, 1000);
        expect(tracker.getXVelocity(0), 1000);
        expect(tracker.getYVelocity(0), -1000);

        tracker.computeCurrentVelocity(1);
        expect(tracker.getXVelocity(0), closeTo(1.25, 1e-3));

        tracker.clear();
        tracker.computeCurrentVelocity(1000);
        expect(tracker.getXVelocity(0), 0);
      },
    );

    testWidgets(
      'an up adds no sample, and one long after the last move clears the velocity',
      (tester) async {
        ChartVelocityTracker moved() {
          final tracker = ChartVelocityTracker();
          for (var i = 0; i < 4; i++) {
            tracker.addMovement(
              _event(
                i == 0 ? ChartTouchAction.down : ChartTouchAction.move,
                16 * i,
                [ui.Offset(100 + 20.0 * i, 100)],
              ),
            );
          }
          return tracker;
        }

        final quick = moved()
          ..addMovement(
            _event(ChartTouchAction.up, 50, [const ui.Offset(300, 100)]),
          )
          ..computeCurrentVelocity(1000);
        expect(quick.getXVelocity(0), closeTo(1250, 1));

        final late = moved()
          ..addMovement(
            _event(ChartTouchAction.up, 100, [const ui.Offset(160, 100)]),
          )
          ..computeCurrentVelocity(1000);
        expect(late.getXVelocity(0), 0);

        // A new down starts over.
        final restarted = moved()
          ..addMovement(
            _event(ChartTouchAction.down, 60, [const ui.Offset(0, 0)]),
          )
          ..computeCurrentVelocity(1000);
        expect(restarted.getXVelocity(0), 0);
      },
    );
  });
}
