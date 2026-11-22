// Not a port of a Kotlin test: MPChartCompose v4.0.1 has no test for its chart composables or ChartView. Checks the
// widget layer of spec §6.5 through the default entry point: the LineChart widget, its ChartHostWidget (setup, update,
// data changes, the vsync it lends the chart, removal), the ChartController it reports to and the WidgetMarker overlay.
import 'package:flutter/foundation.dart'
    show FlutterMemoryAllocations, ObjectCreated, ObjectDisposed, ObjectEvent;
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/core.dart' as core;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../recording/recording_canvas.dart';

/// Three entries: (0, 1), (1, 3), (2, 2).
LineData _data() => LineData([
  LineDataSet([Entry(x: 0, y: 1), Entry(x: 1, y: 3), Entry(x: 2, y: 2)], 'a'),
]);

/// Shows [chart] at 400 x 300 with its top left corner at (200, 150) of the 800 x 600 test surface. When [controller]
/// is given, a [ListenableBuilder] on it is built before the chart and counts its rebuilds in [listenerBuilds].
Widget _host(Widget chart, {ChartController? controller}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Stack(
    children: [
      if (controller != null)
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            listenerBuilds++;
            return Text('zoom ${controller.zoomX.toStringAsFixed(1)}');
          },
        ),
      Center(child: SizedBox(width: 400, height: 300, child: chart)),
    ],
  ),
);

int listenerBuilds = 0;

Duration _ms(int millis) => Duration(milliseconds: millis);

Offset _chartTopLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byType(ChartRenderBoxWidget));

/// The screen position of the value ([x], [y]) of [chart].
Offset _pointOf(WidgetTester tester, LineChartView chart, double x, double y) {
  final pixel = chart.getPixelForValues(x, y, AxisDependency.LEFT);
  return _chartTopLeft(tester) + Offset(pixel.x, pixel.y);
}

/// The top left corner ComposeMarker puts content of [size] at for the point [p], all in chart pixels: centered above
/// the point with a 12 dp gap, moved inside the chart of [chartSize] where it would leave it.
Offset _markerTopLeft(Offset p, Size size, Size chartSize) {
  var dx = -size.width / 2;
  var dy = -size.height - 12;
  if (p.dx + dx < 0) {
    dx = -p.dx;
  } else if (p.dx + size.width + dx > chartSize.width) {
    dx = chartSize.width - p.dx - size.width;
  }
  if (p.dy + dy < 0) {
    dy = -p.dy;
  } else if (p.dy + size.height + dy > chartSize.height) {
    dy = chartSize.height - p.dy - size.height;
  }
  return p + Offset(dx, dy);
}

void main() {
  setUp(() => listenerBuilds = 0);

  test('the default entry point has the widget, core.dart the chart class', () {
    final Widget widget = LineChart(data: _data());
    expect(widget, isA<StatefulWidget>());

    final LineChartView view = core.LineChart();
    expect(view, isA<core.Chart>());
    expect(view, isA<Chart>());
    expect(LineChartView == core.LineChart, isTrue);
  });

  group('setup and update', () {
    testWidgets(
      'attaches the controller and runs setup once, before the data is set',
      (tester) async {
        final c = ChartController();
        LineChartView? chart;
        var setups = 0;
        var updates = 0;
        LineData? dataInSetup = _data();
        LineData? dataInUpdate;
        final data = _data();
        Widget build() => _host(
          LineChart(
            data: data,
            controller: c,
            setup: (it) {
              setups++;
              chart = it;
              dataInSetup = it.data;
              it.axisRight.isEnabled = false;
            },
            update: (it) {
              updates++;
              dataInUpdate = it.data;
            },
          ),
        );

        await tester.pumpWidget(build());
        expect(c.isAttached, isTrue);
        expect(c.zoomX, 1);
        expect(setups, 1);
        expect(dataInSetup, isNull);
        // update runs on the first build too, after the data was set.
        expect(updates, 1);
        expect(dataInUpdate, same(data));
        expect(chart!.axisRight.isEnabled, isFalse);
        expect(chart!.data, same(data));
        expect(chart!.width, 400);

        await tester.pumpWidget(build());
        expect(setups, 1);
        expect(updates, 2);

        await tester.pumpWidget(const SizedBox());
        expect(c.isAttached, isFalse);
        expect(chart!.host, isNull);
      },
    );

    testWidgets('a new controller replaces the old one', (tester) async {
      final first = ChartController();
      final second = ChartController();
      final data = _data();
      await tester.pumpWidget(_host(LineChart(data: data, controller: first)));
      expect(first.isAttached, isTrue);

      await tester.pumpWidget(_host(LineChart(data: data, controller: second)));
      expect(first.isAttached, isFalse);
      expect(second.isAttached, isTrue);

      await tester.pumpWidget(_host(LineChart(data: data)));
      expect(second.isAttached, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'a new chart instance in a ChartHostWidget is set up and hosted, the old one released',
      (tester) async {
        final c = ChartController();
        final first = core.LineChart();
        final second = core.LineChart();
        final setUpCharts = <core.LineChart>[];
        final data = _data();
        Widget build(core.LineChart chart) => _host(
          ChartHostWidget<core.LineChart, LineData>(
            chart: chart,
            data: data,
            controller: c,
            setup: setUpCharts.add,
          ),
        );

        await tester.pumpWidget(build(first));
        first.animateX(1000);
        await tester.pump();
        expect(first.isAnimating, isTrue);

        await tester.pumpWidget(build(second));
        expect(setUpCharts, [first, second]);
        expect(first.isAnimating, isFalse);
        expect(first.host, isNull);
        expect(first.animator.vsync, isNull);
        expect(second.host, isNotNull);
        expect(second.animator.vsync, isNotNull);
        expect(second.data, same(data));
        c.highlight(1);
        expect(second.highlighted, hasLength(1));
        expect(first.highlighted, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('data', () {
    testWidgets('a new data instance animates in with animateChanges', (
      tester,
    ) async {
      late LineChartView chart;
      final first = _data();
      await tester.pumpWidget(
        _host(
          LineChart(
            data: first,
            animateChanges: true,
            setup: (it) => chart = it,
          ),
        ),
      );
      // A chart without data takes its first data at once.
      expect(chart.isAnimating, isFalse);
      expect(chart.data, same(first));

      final second = _data();
      await tester.pumpWidget(
        _host(
          LineChart(
            data: second,
            animateChanges: true,
            setup: (it) => chart = it,
          ),
        ),
      );
      expect(chart.isAnimating, isTrue);
      expect(chart.data, same(second));

      await tester.pump();
      await tester.pump(_ms(299));
      expect(chart.isAnimating, isTrue);
      await tester.pump(_ms(2));
      expect(chart.isAnimating, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'without animateChanges new data is set at once, the same instance left alone',
      (tester) async {
        late LineChartView chart;
        final first = _data();
        await tester.pumpWidget(
          _host(LineChart(data: first, setup: (it) => chart = it)),
        );
        // Changed in place: the same instance is not applied again.
        first.dataSets[0].addEntry(Entry(x: 3, y: 5));
        await tester.pumpWidget(
          _host(LineChart(data: first, setup: (it) => chart = it)),
        );
        expect(chart.xAxis.axisMaximum, 2);

        final second = _data();
        await tester.pumpWidget(
          _host(LineChart(data: second, setup: (it) => chart = it)),
        );
        expect(chart.isAnimating, isFalse);
        expect(chart.data, same(second));

        await tester.pumpWidget(
          _host(LineChart(data: null, setup: (it) => chart = it)),
        );
        expect(chart.data, isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('controller', () {
    testWidgets('a tap selects the entry and the marker is built once', (
      tester,
    ) async {
      final c = ChartController();
      late LineChartView chart;
      final built = <(Entry, Highlight)>[];
      await tester.pumpWidget(
        _host(
          LineChart(
            data: _data(),
            controller: c,
            marker: (entry, highlight) {
              built.add((entry, highlight));
              return SizedBox(width: 40, height: 20, child: Text(entry.y.toStringAsFixed(1)));
            },
            setup: (it) {
              chart = it;
              it.axisRight.isEnabled = false;
            },
          ),
        ),
      );
      expect(chart.marker, isA<WidgetMarker>());

      final point = _pointOf(tester, chart, 1, 3);
      await tester.tapAt(point);
      expect(c.selectedEntry?.x, 1);
      expect(c.selectedHighlight, same(chart.highlighted.single));

      // The chart draws the highlight; the overlay builds the marker on the frame after.
      await tester.pump();
      await tester.pump();
      expect(built, hasLength(1));
      expect(built.single.$1, same(c.selectedEntry));
      expect(built.single.$2, same(c.selectedHighlight));
      expect(find.text('3.0'), findsOneWidget);

      final topLeft = _chartTopLeft(tester);
      final markerRect = tester.getRect(
        find
            .ancestor(of: find.text('3.0'), matching: find.byType(SizedBox))
            .first,
      );
      expect(
        markerRect.topLeft,
        topLeft +
            _markerTopLeft(
              point - topLeft,
              const Size(40, 20),
              const Size(400, 300),
            ),
      );

      // More frames with the same highlight build nothing.
      await tester.pump();
      await tester.pump();
      expect(built, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'the marker stays inside the chart, moves with the point and goes with the highlight',
      (tester) async {
        final c = ChartController();
        late LineChartView chart;
        var builds = 0;
        await tester.pumpWidget(
          _host(
            LineChart(
              data: _data(),
              controller: c,
              marker: (entry, highlight) {
                builds++;
                return const SizedBox(width: 120, height: 40, child: Text('m'));
              },
              setup: (it) => chart = it,
            ),
          ),
        );
        final topLeft = _chartTopLeft(tester);
        Rect markerRect() => tester.getRect(
          find
              .ancestor(of: find.text('m'), matching: find.byType(SizedBox))
              .first,
        );

        // The last entry is at the right edge of the content: the marker is moved left to end at the chart's edge.
        c.highlight(2);
        await tester.pump();
        await tester.pump();
        expect(builds, 1);
        expect(markerRect().right, topLeft.dx + 400);
        final point = _pointOf(tester, chart, 2, 2);
        expect(markerRect().bottom, point.dy - 12);

        // A marker taller than the room above the point is moved down to the chart's top.
        c.highlight(1);
        await tester.pump();
        await tester.pump();
        final high = _pointOf(tester, chart, 1, 3);
        expect(
          markerRect().topLeft,
          topLeft +
              _markerTopLeft(
                high - topLeft,
                const Size(120, 40),
                const Size(400, 300),
              ),
        );

        // The marker follows the highlighted point when the view moves (zoomed about the left edge, so it stays in view).
        final before = markerRect();
        chart.zoom(1.4, 1, 0, 0);
        await tester.pump();
        await tester.pump();
        expect(markerRect(), isNot(before));
        final moved = _pointOf(tester, chart, 1, 3);
        expect(
          markerRect().topLeft,
          topLeft +
              _markerTopLeft(
                moved - topLeft,
                const Size(120, 40),
                const Size(400, 300),
              ),
        );

        c.clearHighlight();
        await tester.pump();
        await tester.pump();
        expect(find.text('m'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('a tap on the marker reaches the chart', (tester) async {
      final c = ChartController();
      late LineChartView chart;
      var taps = 0;
      await tester.pumpWidget(
        _host(
          LineChart(
            data: _data(),
            controller: c,
            marker: (entry, highlight) =>
                const SizedBox(width: 60, height: 30, child: Text('m')),
            setup: (it) {
              chart = it;
              it.onChartGestureListener = OnChartGestureListener.fromFunction(
                onChartSingleTapped: (_) => taps++,
              );
            },
          ),
        ),
      );
      c.highlight(0);
      await tester.pump();
      await tester.pump();
      expect(find.text('m'), findsOneWidget);

      // Tapping next to the highlighted entry again clears the highlight, as on Android.
      await tester.tapAt(tester.getCenter(find.text('m')));
      expect(taps, 1);
      expect(chart.highlighted, isEmpty);
      expect(c.selectedEntry, isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'zoomIn zooms by 1.4 and the controller notifies its listeners',
      (tester) async {
        final c = ChartController();
        await tester.pumpWidget(
          _host(
            LineChart(data: _data(), controller: c),
            controller: c,
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.pump();
        final builds = listenerBuilds;
        expect(find.text('zoom 1.0'), findsOneWidget);

        c.zoomIn();
        await tester.pump();
        expect(c.zoomX, closeTo(1.4, 1e-4));
        expect(c.zoomY, closeTo(1.4, 1e-4));
        await tester.pump();
        expect(listenerBuilds, builds + 1);
        expect(find.text('zoom 1.4'), findsOneWidget);

        // Frames that change nothing do not notify.
        await tester.pump();
        await tester.pump();
        expect(listenerBuilds, builds + 1);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'a restored controller zooms, scrolls and highlights the chart once it has its size',
      (tester) async {
        final saving = ChartController();
        await tester.pumpWidget(
          _host(LineChart(data: _data(), controller: saving)),
        );
        saving.zoomIn();
        saving.highlight(1);
        await tester.pump();
        final saved = saving.toJson();
        await tester.pumpWidget(const SizedBox());

        final restored = ChartController.fromJson(saved);
        late LineChartView chart;
        await tester.pumpWidget(
          _host(
            LineChart(
              data: _data(),
              controller: restored,
              setup: (it) => chart = it,
            ),
          ),
        );
        await tester.pump();
        expect(chart.zoomX, closeTo(1.4, 1e-4));
        expect(chart.lowestVisibleX, closeTo(saving.lowestVisibleX, 1e-4));
        expect(chart.highlighted.single.x, 1);
        expect(restored.selectedEntry?.x, 1);
        expect(restored.zoomX, closeTo(1.4, 1e-4));
        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('marker disposal', () {
    testWidgets(
      'a marker that goes away disposes its position notifier, as leak_tracker expects',
      (tester) async {
        // What leak_tracker sees (it is not a dependency here): the objects that report their creation and disposal
        // to FlutterMemoryAllocations in debug builds. Every marker position notifier created must be disposed.
        final undisposed = Set<Object>.identity();
        void track(ObjectEvent event) {
          if (event.object is! ValueNotifier<(Offset, Entry, Highlight)?>) {
            return;
          }
          if (event is ObjectCreated) undisposed.add(event.object);
          if (event is ObjectDisposed) undisposed.remove(event.object);
        }

        FlutterMemoryAllocations.instance.addListener(track);
        addTearDown(
          () => FlutterMemoryAllocations.instance.removeListener(track),
        );

        late LineChartView chart;
        Widget marker(Entry entry, Highlight highlight) =>
            SizedBox(width: 40, height: 20, child: Text(entry.y.toStringAsFixed(1)));
        Widget build({required bool withMarker}) => _host(
          LineChart(
            data: _data(),
            marker: withMarker ? marker : null,
            setup: (it) => chart = it,
          ),
        );

        await tester.pumpWidget(build(withMarker: true));
        final first = chart.marker! as WidgetMarker;
        expect(undisposed, hasLength(1));
        await tester.tapAt(_pointOf(tester, chart, 1, 3));
        await tester.pump();
        await tester.pump();
        expect(find.text('3.0'), findsOneWidget);

        // The marker builder goes away while its overlay shows: the overlay leaves with it, nothing throws.
        await tester.pumpWidget(build(withMarker: false));
        expect(tester.takeException(), isNull);
        expect(find.text('3.0'), findsNothing);
        expect(
          () => ChangeNotifier.debugAssertNotDisposed(first.position),
          throwsFlutterError,
        );
        expect(undisposed, isEmpty);

        // A new marker, then the chart widget leaves the tree.
        await tester.pumpWidget(build(withMarker: true));
        final second = chart.marker! as WidgetMarker;
        expect(second, isNot(same(first)));
        expect(undisposed, hasLength(1));
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
        expect(undisposed, isEmpty);
      },
    );

    testWidgets('detach disposes the position once and can be called again', (
      tester,
    ) async {
      final chart = core.LineChart()..data = _data();
      final marker = WidgetMarker(chart, (entry, highlight) => const Text(''));
      chart.marker = marker;
      ChangeNotifier.debugAssertNotDisposed(marker.position);

      marker.detach();
      expect(chart.marker, isNull);
      expect(
        () => ChangeNotifier.debugAssertNotDisposed(marker.position),
        throwsFlutterError,
      );
      marker.detach();
      expect(tester.takeException(), isNull);

      // Set again by mistake and drawn with a highlight: the detached marker no longer publishes to the disposed
      // notifier.
      chart.marker = marker;
      chart.onSizeChanged(400, 300);
      chart.highlightValue(1, 0);
      chart.onDraw(RecordingCanvas());
      expect(marker.lastPosition, isNotNull);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('removal', () {
    testWidgets(
      'animateX then removing the chart ends the animations once and throws nothing',
      (tester) async {
        final c = ChartController();
        late LineChartView chart;
        await tester.pumpWidget(
          _host(
            LineChart(data: _data(), controller: c, setup: (it) => chart = it),
            controller: c,
          ),
        );
        var ends = 0;
        c.animateX(1000);
        c.animateDataChange(_data(), 1000, onEnd: () => ends++);
        await tester.pump();
        await tester.pump(_ms(100));
        expect(chart.isAnimating, isTrue);
        expect(chart.animator.phaseX, lessThan(1));

        // The State that lends its vsync goes away in this frame; TickerProviderStateMixin asserts that none of its
        // tickers is still active, and the controller's listener must not be rebuilt while the tree is being built.
        await tester.pumpWidget(_host(const SizedBox(), controller: c));
        expect(tester.takeException(), isNull);
        expect(chart.isAnimating, isFalse);
        expect(chart.animator.phaseX, 1);
        expect(ends, 1);
        expect(chart.animator.vsync, isNull);
        expect(chart.host, isNull);
        expect(c.isAttached, isFalse);

        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'an animation started in setup runs on the widget vsync and ends once on removal',
      (tester) async {
        late LineChartView chart;
        var ends = 0;
        await tester.pumpWidget(
          _host(
            LineChart(
              data: _data(),
              setup: (it) {
                chart = it;
                it.animateX(1000, onEnd: () => ends++);
              },
            ),
          ),
        );
        // Mounting the chart's render object did not end it: setup ran with the same vsync the host lends.
        expect(chart.isAnimating, isTrue);
        expect(chart.animator.vsync, same(chart.host!.vsync));
        await tester.pump(_ms(100));
        expect(chart.animator.phaseX, greaterThan(0));
        expect(chart.animator.phaseX, lessThan(1));
        expect(ends, 0);

        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
        expect(chart.isAnimating, isFalse);
        expect(ends, 1);
      },
    );

    testWidgets(
      'removing the chart during a drag cancels the touch and leaves no timer',
      (tester) async {
        late LineChartView chart;
        await tester.pumpWidget(
          _host(LineChart(data: _data(), setup: (it) => chart = it)),
        );
        chart.zoom(2, 2, 0, 0);
        final gesture = await tester.startGesture(
          _pointOf(tester, chart, 0.5, 2),
        );
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(4, 0));
        }
        expect(chart.chartTouchListener.touchMode, ChartTouchListener.DRAG);

        await tester.pumpWidget(const SizedBox());
        expect(chart.chartTouchListener.touchMode, ChartTouchListener.NONE);
        await gesture.moveBy(const Offset(20, 0));
        await gesture.up();
        await tester.pump(kLongPressTimeout);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets(
    'a change of the system fonts drops the cached text layouts and redraws',
    (tester) async {
      var draws = 0;
      await tester.pumpWidget(
        _host(
          LineChart(
            data: _data(),
            setup: (it) => it.afterDrawListeners.add(() => draws++),
          ),
        ),
      );
      const style = TextStyle(fontSize: 99);
      final cached = TextMeasure.layout('cached', style);
      expect(TextMeasure.layout('cached', style), same(cached));
      final drawsBefore = draws;

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.system.name,
        SystemChannels.system.codec.encodeMessage(<String, Object?>{
          'type': 'fontsChange',
        }),
        (_) {},
      );
      expect(TextMeasure.layout('cached', style), isNot(same(cached)));
      await tester.pump();
      expect(draws, drawsBefore + 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
