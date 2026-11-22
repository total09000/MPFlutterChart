// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no test for the View host of a chart. Checks the render
// object that shows a chart: layout to onSizeChanged, the viewport jobs that wait for a size, paint, the
// frame clock and vsync it lends the chart, pointer routing to the recognizer and the release of the chart when the
// render object leaves the tree.
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/chart.dart';
import 'package:mp_flutter_chart/src/charts/line_chart.dart';
import 'package:mp_flutter_chart/src/components/y_axis.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/formatter/index_axis_value_formatter.dart';
import 'package:mp_flutter_chart/src/listener/bar_line_chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/widgets/chart_render_box.dart';
import 'package:mp_flutter_chart/src/widgets/chart_touch_event.dart';

/// Three entries: (0, 1), (1, 3), (2, 2).
LineData _data() => LineData([
  LineDataSet([
    Entry(x: 0, y: 1),
    Entry(x: 1, y: 3),
    Entry(x: 2, y: 2),
  ], 'a'),
]);

/// A line chart that counts its draws and host vsync changes and remembers the sizes it was given.
class _CountingLineChart extends LineChart {
  int draws = 0;
  int vsyncChanges = 0;
  final List<ui.Size> sizes = [];

  @override
  void onDraw(ui.Canvas canvas) {
    draws++;
    super.onDraw(canvas);
  }

  @override
  void onHostVsyncChanged() {
    vsyncChanges++;
    super.onHostVsyncChanged();
  }

  @override
  void onSizeChanged(double w, double h) {
    sizes.add(ui.Size(w, h));
    super.onSizeChanged(w, h);
  }
}

/// A chart of no BarLine type (as PieRadar charts will be) that only counts the host's vsync changes and checks that
/// the animator already runs on the new vsync when the host reports it.
class _PlainChart extends Chart<LineData> {
  int vsyncChanges = 0;
  final List<TickerProvider?> animatorVsyncs = [];

  @override
  void notifyDataSetChanged() {}

  @override
  void calculateOffsets() {}

  @override
  void calcMinMax() {}

  @override
  int get maxVisibleCount => 100;

  @override
  double get yChartMin => 0;

  @override
  double get yChartMax => 0;

  @override
  void onHostVsyncChanged() {
    vsyncChanges++;
    animatorVsyncs.add(animator.vsync);
    super.onHostVsyncChanged();
  }
}

/// Shows [chart] at 400 x 300 in the middle of the 800 x 600 test surface, so its top left corner is at (200, 150).
Widget _sized(
  Chart chart, {
  TickerProvider? vsync,
  GestureRecognizer? recognizer,
  double width = 400,
}) => Center(
  child: SizedBox(
    width: width,
    height: 300,
    child: ChartRenderBoxWidget(
      chart: chart,
      vsync: vsync,
      recognizer: recognizer,
    ),
  ),
);

/// Shows a chart with its own State as the vsync, the way the widget layer's host does.
class _VsyncHost extends StatefulWidget {
  const _VsyncHost({required this.chart});

  final Chart chart;

  @override
  State<_VsyncHost> createState() => _VsyncHostState();
}

class _VsyncHostState extends State<_VsyncHost> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 400,
      height: 300,
      child: ChartRenderBoxWidget(chart: widget.chart, vsync: this),
    ),
  );
}

/// Creates tickers that are muted: they count as active but never tick.
class _MutedVSync implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick)..muted = true;
}

/// Keeps the tickers it creates.
class _RecordingVSync implements TickerProvider {
  final List<Ticker> tickers = [];

  @override
  Ticker createTicker(TickerCallback onTick) {
    final ticker = Ticker(onTick);
    tickers.add(ticker);
    return ticker;
  }
}

/// Records the pointers it is given and the arena claims, without entering the arena.
class _FakeRecognizer extends OneSequenceGestureRecognizer
    implements ChartArenaRecognizer {
  final List<Offset> downs = [];
  int accepts = 0;

  @override
  void addPointer(PointerDownEvent event) => downs.add(event.localPosition);

  @override
  void acceptNow() => accepts++;

  @override
  void handleEvent(PointerEvent event) {}

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'fake chart recognizer';
}

Duration _ms(int millis) => Duration(milliseconds: millis);

ChartRenderBox _box(WidgetTester tester) =>
    tester.renderObject<ChartRenderBox>(find.byType(ChartRenderBoxWidget));

void main() {
  group('layout', () {
    testWidgets('the chart gets the size of the box', (tester) async {
      final chart = LineChart()..data = _data();
      await tester.pumpWidget(_sized(chart));

      expect(chart.width, 400);
      expect(chart.height, 300);
      expect(chart.viewPortHandler.hasChartDimens(), isTrue);
      expect(chart.host, same(_box(tester)));
    });

    testWidgets(
      'jobs queued before the first layout run after it, without throwing',
      (tester) async {
        final chart = LineChart()..data = _data();
        // At zoom 1 the viewport cannot move (centerViewPort clamps transX to 0), so zoom in first, also as a job.
        expect(() {
          chart.zoom(2, 1, 1, 0, AxisDependency.LEFT);
          chart.moveViewToX(1);
        }, returnsNormally);
        expect(chart.jobs, hasLength(2));
        expect(chart.viewPortHandler.transX, 0);

        await tester.pumpWidget(_sized(chart));

        expect(chart.jobs, isEmpty);
        expect(chart.viewPortHandler.transX, isNot(0));
        expect(chart.zoomX, closeTo(2, 1e-4));
        expect(chart.lowestVisibleX, closeTo(1, 1e-3));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a chart laid out at 0 x 0 keeps its jobs until it gets a size', (
      tester,
    ) async {
      final chart = LineChart()..data = _data();
      final vsync = TestVSync();
      Widget sized(double width, double height) => Center(
        child: SizedBox(
          width: width,
          height: height,
          child: ChartRenderBoxWidget(chart: chart, vsync: vsync),
        ),
      );

      await tester.pumpWidget(sized(0, 0));
      final box = _box(tester);
      expect(box.size, Size.zero);
      expect(chart.viewPortHandler.hasChartDimens(), isFalse);

      var ends = 0;
      expect(() {
        chart.zoom(2, 1, 1, 0, AxisDependency.LEFT);
        chart.moveViewToX(1);
        chart.animateX(100, onEnd: () => ends++);
      }, returnsNormally);
      expect(chart.jobs, hasLength(2));
      await tester.pump();
      await tester.pump(_ms(101));
      expect(tester.takeException(), isNull);
      expect(ends, 1);
      expect(chart.jobs, hasLength(2));

      await tester.pumpWidget(sized(400, 300));
      expect(_box(tester), same(box));
      expect(chart.width, 400);
      expect(chart.height, 300);
      expect(chart.jobs, isEmpty);
      expect(chart.zoomX, closeTo(2, 1e-4));
      expect(chart.lowestVisibleX, closeTo(1, 1e-3));
    });

    testWidgets('an unbounded height becomes 300', (tester) async {
      final chart = LineChart()..data = _data();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [ChartRenderBoxWidget(chart: chart)]),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(chart.height, 300);
      expect(chart.width, 800);
    });

    testWidgets('an unbounded width becomes 300', (tester) async {
      final chart = LineChart()..data = _data();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [ChartRenderBoxWidget(chart: chart)]),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(chart.width, 300);
      expect(chart.height, 600);
    });

    testWidgets('onSizeChanged runs only when the size changes', (
      tester,
    ) async {
      final chart = _CountingLineChart()..data = _data();
      Widget constrained(BoxConstraints constraints) => Center(
        child: ConstrainedBox(
          constraints: constraints,
          child: ChartRenderBoxWidget(chart: chart),
        ),
      );

      await tester.pumpWidget(
        constrained(BoxConstraints.tight(const Size(400, 300))),
      );
      final box = _box(tester);
      expect(chart.sizes, [const ui.Size(400, 300)]);

      // New, loose constraints that give the same size: laid out again, same size, no onSizeChanged.
      await tester.pumpWidget(
        constrained(const BoxConstraints(maxWidth: 400, maxHeight: 300)),
      );
      expect(_box(tester), same(box));
      expect(box.constraints.isTight, isFalse);
      expect(box.size, const Size(400, 300));
      expect(chart.sizes, [const ui.Size(400, 300)]);

      await tester.pumpWidget(
        constrained(BoxConstraints.tight(const Size(500, 300))),
      );
      expect(_box(tester), same(box));
      expect(chart.sizes, [const ui.Size(400, 300), const ui.Size(500, 300)]);
      expect(chart.width, 500);
    });
  });

  group('paint', () {
    testWidgets('draws once per frame that needs it', (tester) async {
      final chart = _CountingLineChart()..data = _data();
      await tester.pumpWidget(
        ColoredBox(color: const Color(0xFF000000), child: _sized(chart)),
      );
      expect(chart.draws, 1);

      // Nothing changed: no new frame draws the chart.
      await tester.pump();
      expect(chart.draws, 1);

      // Several redraw requests in one frame draw once.
      chart.invalidate();
      chart.invalidate();
      await tester.pump();
      expect(chart.draws, 2);

      // A repaint of the surroundings does not draw the chart again: it is a repaint boundary.
      final box = _box(tester);
      expect(box.isRepaintBoundary, isTrue);
      await tester.pumpWidget(
        ColoredBox(color: const Color(0xFFFFFFFF), child: _sized(chart)),
      );
      expect(_box(tester), same(box));
      expect(chart.draws, 2);
    });

    testWidgets('the chart is clipped to the box', (tester) async {
      // Without y axes the content starts 15 dp from the edges, so the long first and last x labels, centred on the
      // content edges, reach past the box on both sides.
      final chart = LineChart()..data = _data();
      chart.axisLeft.isEnabled = false;
      chart.axisRight.isEnabled = false;
      chart.xAxis
        ..granularity = 1
        ..valueFormatter = IndexAxisValueFormatter([
          'A very long first label',
          'A very long second label',
          'A very long third label',
        ]);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            key: boundary,
            child: SizedBox(
              width: 600,
              height: 300,
              child: Center(
                child: SizedBox(
                  width: 400,
                  height: 300,
                  child: ChartRenderBoxWidget(chart: chart),
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byType(ChartRenderBoxWidget),
        paints..clipRect(rect: Offset.zero & const Size(400, 300)),
      );

      // The chart box covers x 100 ..< 500 of the 600 x 300 image; nothing may be drawn left or right of it.
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundary),
      );
      final bytes = (await tester.runAsync(() async {
        final image = await render.toImage();
        try {
          return (await image.toByteData())!;
        } finally {
          image.dispose();
        }
      }))!;
      int alphaAt(int x, int y) => bytes.getUint8((y * 600 + x) * 4 + 3);
      var outside = 0;
      var inside = 0;
      for (var y = 0; y < 300; y++) {
        for (var x = 0; x < 600; x++) {
          if (alphaAt(x, y) == 0) continue;
          if (x < 100 || x >= 500) {
            outside++;
          } else {
            inside++;
          }
        }
      }
      expect(inside, greaterThan(0));
      expect(outside, 0);
    });

    testWidgets('the box is hit everywhere inside it', (tester) async {
      final chart = LineChart()..data = _data();
      await tester.pumpWidget(_sized(chart));
      final box = _box(tester);

      final result = BoxHitTestResult();
      expect(box.hitTest(result, position: const Offset(10, 10)), isTrue);
      expect(result.path.single.target, same(box));
      expect(
        box.hitTest(BoxHitTestResult(), position: const Offset(401, 10)),
        isFalse,
      );
    });
  });

  group('frame clock', () {
    testWidgets('post schedules a frame when idle and runs after it', (
      tester,
    ) async {
      final chart = LineChart()..data = _data();
      await tester.pumpWidget(_sized(chart));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);

      var ran = 0;
      chart.post(() => ran++);
      expect(ran, 0);
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pump();
      expect(ran, 1);

      await tester.pump();
      expect(ran, 1);
    });

    testWidgets('a viewport job on a laid out chart runs after the frame', (
      tester,
    ) async {
      final chart = _CountingLineChart()..data = _data();
      await tester.pumpWidget(_sized(chart));
      chart.zoom(2, 1, 1, 0, AxisDependency.LEFT);
      expect(chart.zoomX, 1);

      await tester.pump();
      expect(chart.zoomX, closeTo(2, 1e-4));
      // The job's redraw request draws in the next frame.
      final draws = chart.draws;
      await tester.pump();
      expect(chart.draws, draws + 1);
    });
  });

  group('vsync', () {
    testWidgets('animations tick on the vsync of the widget', (tester) async {
      final chart = _CountingLineChart()..data = _data();
      await tester.pumpWidget(_VsyncHost(chart: chart));
      final state = tester.state<_VsyncHostState>(find.byType(_VsyncHost));
      expect(chart.animator.vsync, same(state));
      expect(chart.host!.vsync, same(state));
      expect(chart.draws, 1);

      var ends = 0;
      chart.animateX(100, onEnd: () => ends++);
      expect(chart.isAnimating, isTrue);
      expect(chart.animator.phaseX, 0);

      await tester.pump();
      await tester.pump(_ms(50));
      expect(chart.animator.phaseX, closeTo(0.5, 1e-4));
      expect(chart.draws, 3);
      expect(ends, 0);

      await tester.pump(_ms(51));
      expect(chart.animator.phaseX, 1);
      expect(chart.isAnimating, isFalse);
      expect(ends, 1);
      expect(chart.draws, 4);

      await tester.pump(_ms(100));
      expect(chart.draws, 4);
      expect(ends, 1);
    });

    testWidgets('a new vsync ends the running animations', (tester) async {
      final chart = LineChart()..data = _data();
      final first = TestVSync();
      final second = TestVSync();
      await tester.pumpWidget(_sized(chart, vsync: first));
      expect(chart.animator.vsync, same(first));

      var ends = 0;
      chart.animateY(1000, onEnd: () => ends++);
      chart.moveViewToAnimated(1, 2, AxisDependency.LEFT, 1000);
      await tester.pump();
      await tester.pump(_ms(100));
      expect(chart.isAnimating, isTrue);
      expect(chart.runningViewPortJobs, hasLength(1));

      await tester.pumpWidget(_sized(chart, vsync: second));
      expect(chart.animator.vsync, same(second));
      expect(chart.host!.vsync, same(second));
      expect(chart.isAnimating, isFalse);
      expect(chart.animator.phaseY, 1);
      expect(ends, 1);
      expect(chart.runningViewPortJobs, isEmpty);
    });

    testWidgets('a new vsync stops a running fling deceleration', (
      tester,
    ) async {
      final chart = _CountingLineChart()..data = _data();
      final first = _RecordingVSync();
      await tester.pumpWidget(_sized(chart, vsync: first));
      chart.zoomToCenter(4, 4);
      final listener = chart.chartTouchListener as BarLineChartTouchListener;
      listener.clock = () => tester.binding.clock.now().millisecondsSinceEpoch;
      bool touch(ChartTouchAction action, double x, int time) =>
          chart.onTouchEvent(
            ChartTouchEvent(
              action: action,
              pointerIds: const [0],
              positions: [Offset(x, 150)],
              eventTimeMillis: time,
            ),
          );

      touch(ChartTouchAction.down, 100, 0);
      touch(ChartTouchAction.move, 120, 16);
      touch(ChartTouchAction.move, 140, 32);
      touch(ChartTouchAction.move, 160, 48);
      touch(ChartTouchAction.up, 160, 48);
      expect(first.tickers.single.isActive, isTrue);
      await tester.pump(_ms(16));

      // The deceleration ticks on the previous provider, which may be going away: it stops, like the animations, in
      // the chart's onHostVsyncChanged.
      expect(chart.vsyncChanges, 0);
      await tester.pumpWidget(_sized(chart, vsync: TestVSync()));
      expect(chart.vsyncChanges, 1);
      expect(first.tickers.single.isActive, isFalse);
      final transX = chart.viewPortHandler.transX;
      await tester.pump(_ms(16));
      expect(chart.viewPortHandler.transX, transX);
    });

    testWidgets('the host reports a new vsync to any chart, once per change', (
      tester,
    ) async {
      final chart = _PlainChart();
      final first = TestVSync();
      final second = TestVSync();
      await tester.pumpWidget(_sized(chart, vsync: first));
      expect(chart.vsyncChanges, 0);

      // The same provider again is no change.
      await tester.pumpWidget(_sized(chart, vsync: first));
      expect(chart.vsyncChanges, 0);

      await tester.pumpWidget(_sized(chart, vsync: second));
      expect(chart.vsyncChanges, 1);
      expect(chart.animatorVsyncs.single, same(second));

      await tester.pumpWidget(_sized(chart));
      expect(chart.vsyncChanges, 2);
      expect(chart.animatorVsyncs.last, isNull);

      // A box that does not host the chart (here: never attached) does not report to it.
      final box = ChartRenderBox(chart: chart, vsync: first)..vsync = second;
      expect(chart.vsyncChanges, 2);
      box.dispose();
      expect(chart.host, same(_box(tester)));
    });

    testWidgets('without a vsync animations end at once', (tester) async {
      final chart = LineChart()..data = _data();
      await tester.pumpWidget(_sized(chart));
      expect(chart.host!.vsync, isNull);

      var ends = 0;
      chart.animateX(1000, onEnd: () => ends++);
      expect(chart.isAnimating, isFalse);
      expect(ends, 1);
    });
  });

  group('removal', () {
    testWidgets(
      'removing the widget mid-animation ends the animations and releases the chart',
      (tester) async {
        final chart = LineChart()..data = _data();
        await tester.pumpWidget(_VsyncHost(chart: chart));

        var ends = 0;
        chart.animateXY(1000, 1000, onEnd: () => ends++);
        chart.moveViewToAnimated(1, 2, AxisDependency.LEFT, 1000);
        await tester.pump();
        await tester.pump(_ms(100));
        expect(chart.isAnimating, isTrue);
        expect(chart.runningViewPortJobs, hasLength(1));
        expect(chart.animator.phaseX, lessThan(1));

        // The State that lends its vsync goes away in the same frame; TickerProviderStateMixin asserts that none of
        // its tickers is still active then.
        await tester.pumpWidget(const SizedBox());

        expect(tester.takeException(), isNull);
        expect(chart.isAnimating, isFalse);
        expect(chart.animator.phaseX, 1);
        expect(chart.animator.phaseY, 1);
        expect(ends, 1);
        expect(chart.runningViewPortJobs, isEmpty);
        expect(chart.host, isNull);
        expect(chart.animator.vsync, isNull);
      },
    );

    testWidgets(
      'an onEnd that restarts its cancelled animation leaves no ticker behind',
      (tester) async {
        final logs = <String?>[];
        final previous = debugPrint;
        debugPrint = (message, {wrapWidth}) => logs.add(message);
        try {
          final chart = LineChart()..data = _data();
          await tester.pumpWidget(_VsyncHost(chart: chart));

          void loop() => chart.animateY(100, onEnd: loop);
          chart.animateY(100, onEnd: loop);
          await tester.pump();
          await tester.pump(_ms(50));

          // A second y animation while the loop runs: the cancelled one's onEnd starts the slot again.
          chart.animateY(100, onEnd: loop);
          expect(chart.animator.running, hasLength(1));
          await tester.pump();
          await tester.pump(_ms(50));

          // TickerProviderStateMixin asserts that none of its tickers is still active when its State goes away.
          await tester.pumpWidget(const SizedBox());
          expect(tester.takeException(), isNull);
          expect(chart.isAnimating, isFalse);
          expect(chart.host, isNull);
          expect(chart.animator.vsync, isNull);
        } finally {
          debugPrint = previous;
        }
      },
    );

    testWidgets(
      'moving the widget to another parent detaches and attaches the chart again',
      (tester) async {
        final key = GlobalKey();
        // Its tickers never tick, so nothing but the detach redraws the chart in the frame of the move.
        final vsync = _MutedVSync();
        final chart = _CountingLineChart()..data = _data();
        Widget at({required bool left}) {
          final view = ChartRenderBoxWidget(
            key: key,
            chart: chart,
            vsync: vsync,
          );
          return Row(
            textDirection: TextDirection.ltr,
            children: [
              SizedBox(width: 400, height: 300, child: left ? view : null),
              SizedBox(width: 400, height: 300, child: left ? null : view),
            ],
          );
        }

        await tester.pumpWidget(at(left: true));
        final box = _box(tester);
        var ends = 0;
        chart.animateX(1000, onEnd: () => ends++);
        await tester.pump();
        expect(chart.isAnimating, isTrue);
        expect(chart.animator.phaseX, 0);
        final draws = chart.draws;

        // Like a view moved to another parent on Android: onDetachedFromWindow ends the animation, then the same
        // render object hosts the chart again. The redraw the ending animation asked for while the box was detached
        // draws the end state: the box keeps its size and constraints, so without it the old layer would be reused.
        await tester.pumpWidget(at(left: false));
        expect(_box(tester), same(box));
        expect(chart.draws, draws + 1);
        expect(box.localToGlobal(Offset.zero), const Offset(400, 150));
        expect(chart.isAnimating, isFalse);
        expect(chart.animator.phaseX, 1);
        expect(ends, 1);
        expect(chart.host, same(box));
        expect(chart.animator.vsync, same(vsync));
      },
    );

    testWidgets('a job posted before the removal does not run after it', (
      tester,
    ) async {
      final chart = LineChart()..data = _data();
      await tester.pumpWidget(_sized(chart));

      var ran = false;
      chart.post(() => ran = true);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      expect(ran, isFalse);

      // Without a host a post runs at once.
      var ranLater = false;
      expect(() => chart.post(() => ranLater = true), returnsNormally);
      expect(ranLater, isTrue);
    });

    testWidgets('redraw requests after the removal are ignored', (
      tester,
    ) async {
      final chart = LineChart()..data = _data();
      await tester.pumpWidget(_sized(chart));
      final box = _box(tester);

      await tester.pumpWidget(const SizedBox());
      expect(box.attached, isFalse);
      expect(box.debugDisposed, isTrue);

      expect(box.markNeedsPaint, returnsNormally);
      expect(chart.invalidate, returnsNormally);
      expect(() => box.postFrame(() {}), returnsNormally);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a new chart replaces the old one, which is released', (
      tester,
    ) async {
      final vsync = TestVSync();
      final first = LineChart()..data = _data();
      final second = _CountingLineChart()..data = _data();
      await tester.pumpWidget(_sized(first, vsync: vsync));
      final box = _box(tester);

      var ends = 0;
      first.animateX(1000, onEnd: () => ends++);
      await tester.pump();
      expect(first.isAnimating, isTrue);

      await tester.pumpWidget(_sized(second, vsync: vsync));
      expect(_box(tester), same(box));
      expect(first.isAnimating, isFalse);
      expect(ends, 1);
      expect(first.host, isNull);
      expect(first.animator.vsync, isNull);

      expect(second.host, same(box));
      expect(second.animator.vsync, same(vsync));
      expect(second.sizes, [const ui.Size(400, 300)]);
      expect(second.draws, 1);
    });
  });

  group('gestures', () {
    testWidgets('a pointer down in the box goes to the recognizer', (
      tester,
    ) async {
      final recognizer = _FakeRecognizer();
      addTearDown(recognizer.dispose);
      final chart = LineChart()..data = _data();
      await tester.pumpWidget(_sized(chart, recognizer: recognizer));

      final inside = await tester.startGesture(const Offset(250, 200));
      await inside.moveBy(const Offset(10, 0));
      await inside.up();
      expect(recognizer.downs, [const Offset(50, 50)]);

      final outside = await tester.startGesture(const Offset(100, 100));
      await outside.up();
      expect(recognizer.downs, hasLength(1));
    });

    testWidgets(
      'disableScroll claims the gesture and enableScroll does nothing',
      (tester) async {
        final recognizer = _FakeRecognizer();
        addTearDown(recognizer.dispose);
        final chart = LineChart()..data = _data();
        await tester.pumpWidget(_sized(chart, recognizer: recognizer));

        chart.disableScroll();
        expect(recognizer.accepts, 1);
        chart.enableScroll();
        expect(recognizer.accepts, 1);
      },
    );

    testWidgets('without a recognizer scroll requests do nothing', (
      tester,
    ) async {
      final chart = LineChart()..data = _data();
      await tester.pumpWidget(_sized(chart));

      expect(chart.disableScroll, returnsNormally);
      expect(chart.enableScroll, returnsNormally);
      final gesture = await tester.startGesture(const Offset(250, 200));
      await gesture.up();
      expect(tester.takeException(), isNull);
    });
  });
}
