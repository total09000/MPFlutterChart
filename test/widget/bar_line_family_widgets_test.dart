// Not a port of a Kotlin test: MPChartCompose v4.0.1 has no test for its chart composables. Checks the five bar-line
// chart widgets (BarChart, HorizontalBarChart, ScatterChart, CandleStickChart, BubbleChart) through the default entry
// point: each widget forwards its parameters to its ChartHostWidget, hands setup and update the right `*ChartView`,
// selects the tapped entry, builds the marker and animates a new data instance in.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/core.dart' as core;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

/// Shows [chart] at 400 x 300 with its top left corner at (200, 150) of the 800 x 600 test surface.
Widget _host(Widget chart) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: SizedBox(width: 400, height: 300, child: chart)),
);

Duration _ms(int millis) => Duration(milliseconds: millis);

Offset _chartTopLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byType(ChartRenderBoxWidget));

Offset _offset(MPPointD p) => Offset(p.x, p.y);

/// The parameters of one of the chart widgets, so that one set of tests builds all five.
typedef _WidgetBuilder<C, D> =
    Widget Function(
      D? data, {
      ChartController? controller,
      String? contentDescription,
      Widget Function(Entry entry, Highlight highlight)? marker,
      bool animateChanges,
      void Function(C chart)? setup,
      void Function(C chart)? update,
    });

/// One chart widget under test: [C] is the chart it shows, [D] its data. [data] makes three entries at x = 0, 1, 2, a
/// new instance of the same shape on every call; [pointOfSecond] is where the chart draws the entry at x = 1, in chart
/// pixels.
class _Family<
  C extends BarLineChartBase<D>,
  D extends BarLineScatterCandleBubbleData
> {
  const _Family({
    required this.name,
    required this.data,
    required this.widget,
    required this.isView,
    required this.pointOfSecond,
  });

  final String name;
  final D Function() data;
  final _WidgetBuilder<C, D> widget;

  /// Whether a chart is exactly the `*ChartView` this widget should create (not a subclass of it).
  final bool Function(core.Chart chart) isView;
  final Offset Function(C chart) pointOfSecond;

  /// The entry at x = 1 of the first data set of [chart].
  Entry secondEntry(C chart) =>
      chart.data!.getDataSetByIndex(0)!.getEntryForIndex(1);

  void defineTests() {
    group(name, () {
      testWidgets(
        'forwards controller, description, setup and update; setup runs once, before the data is set',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final c = ChartController();
          C? chart;
          var setups = 0;
          var updates = 0;
          D? dataInSetup = data();
          D? dataInUpdate;
          final shown = data();
          Widget build() => _host(
            widget(
              shown,
              controller: c,
              contentDescription: '$name of sales',
              setup: (it) {
                setups++;
                chart = it;
                dataInSetup = it.data;
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
          expect(isView(chart!), isTrue);
          expect(dataInSetup, isNull);
          expect(updates, 1);
          expect(dataInUpdate, same(shown));
          expect(chart!.data, same(shown));
          expect(chart!.width, 400);
          expect(find.bySemanticsLabel('$name of sales'), findsOneWidget);

          await tester.pumpWidget(build());
          expect(setups, 1);
          expect(updates, 2);

          await tester.pumpWidget(const SizedBox());
          expect(c.isAttached, isFalse);
          expect(chart!.host, isNull);
          semantics.dispose();
        },
      );

      testWidgets(
        'a tap on the second entry selects it and builds the marker once',
        (tester) async {
          final c = ChartController();
          late C chart;
          final built = <(Entry, Highlight)>[];
          await tester.pumpWidget(
            _host(
              widget(
                data(),
                controller: c,
                marker: (entry, highlight) {
                  built.add((entry, highlight));
                  return const SizedBox(
                    width: 40,
                    height: 20,
                    child: Text('m'),
                  );
                },
                setup: (it) => chart = it,
              ),
            ),
          );
          expect(chart.marker, isA<WidgetMarker>());

          await tester.tapAt(_chartTopLeft(tester) + pointOfSecond(chart));
          expect(c.selectedEntry, same(secondEntry(chart)));
          expect(c.selectedEntry?.x, 1);
          expect(c.selectedHighlight, same(chart.highlighted.single));

          // The chart draws the highlight; the overlay builds the marker on the frame after.
          await tester.pump();
          await tester.pump();
          expect(built, hasLength(1));
          expect(built.single.$1, same(c.selectedEntry));
          expect(built.single.$2, same(c.selectedHighlight));
          expect(find.text('m'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
      );

      testWidgets('a new data instance animates in with animateChanges', (
        tester,
      ) async {
        late C chart;
        final first = data();
        Widget build(D shown) => _host(
          widget(shown, animateChanges: true, setup: (it) => chart = it),
        );

        await tester.pumpWidget(build(first));
        // A chart without data takes its first data at once.
        expect(chart.isAnimating, isFalse);
        expect(chart.data, same(first));

        final second = data();
        await tester.pumpWidget(build(second));
        expect(chart.isAnimating, isTrue);
        expect(chart.data, same(second));

        await tester.pump();
        await tester.pump(_ms(301));
        expect(chart.isAnimating, isFalse);
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}

final _families = <void Function()>[
  _Family<BarChartView, BarData>(
    name: 'BarChart',
    data: () => BarData([
      BarDataSet([
        BarEntry(x: 0, y: 1),
        BarEntry(x: 1, y: 3),
        BarEntry(x: 2, y: 2),
      ], 'a'),
    ]),
    widget:
        (
          data, {
          controller,
          contentDescription,
          marker,
          animateChanges = false,
          setup,
          update,
        }) => BarChart(
          data: data,
          controller: controller,
          contentDescription: contentDescription,
          marker: marker,
          animateChanges: animateChanges,
          setup: setup,
          update: update,
        ),
    isView: (chart) => chart.runtimeType == BarChartView,
    pointOfSecond: (chart) =>
        _offset(chart.getPixelForValues(1, 3, AxisDependency.LEFT)),
  ).defineTests,
  _Family<HorizontalBarChartView, BarData>(
    name: 'HorizontalBarChart',
    data: () => BarData([
      BarDataSet([
        BarEntry(x: 0, y: 1),
        BarEntry(x: 1, y: 3),
        BarEntry(x: 2, y: 2),
      ], 'a'),
    ]),
    widget:
        (
          data, {
          controller,
          contentDescription,
          marker,
          animateChanges = false,
          setup,
          update,
        }) => HorizontalBarChart(
          data: data,
          controller: controller,
          contentDescription: contentDescription,
          marker: marker,
          animateChanges: animateChanges,
          setup: setup,
          update: update,
        ),
    isView: (chart) => chart.runtimeType == HorizontalBarChartView,
    // The value runs along the width and x along the height: getPosition transposes.
    pointOfSecond: (chart) {
      final e = chart.data!.getDataSetByIndex(0)!.getEntryForIndex(1);
      final p = chart.getPosition(e, AxisDependency.LEFT)!;
      return Offset(p.x, p.y);
    },
  ).defineTests,
  _Family<ScatterChartView, ScatterData>(
    name: 'ScatterChart',
    data: () => ScatterData([
      ScatterDataSet([
        Entry(x: 0, y: 1),
        Entry(x: 1, y: 3),
        Entry(x: 2, y: 2),
      ], 'a'),
    ]),
    widget:
        (
          data, {
          controller,
          contentDescription,
          marker,
          animateChanges = false,
          setup,
          update,
        }) => ScatterChart(
          data: data,
          controller: controller,
          contentDescription: contentDescription,
          marker: marker,
          animateChanges: animateChanges,
          setup: setup,
          update: update,
        ),
    isView: (chart) => chart.runtimeType == ScatterChartView,
    pointOfSecond: (chart) =>
        _offset(chart.getPixelForValues(1, 3, AxisDependency.LEFT)),
  ).defineTests,
  _Family<CandleStickChartView, CandleData>(
    name: 'CandleStickChart',
    data: () => CandleData([
      CandleDataSet([
        CandleEntry(x: 0, high: 4, low: 1, open: 2, close: 3),
        CandleEntry(x: 1, high: 6, low: 2, open: 5, close: 3),
        CandleEntry(x: 2, high: 5, low: 2, open: 3, close: 4),
      ], 'a'),
    ]),
    widget:
        (
          data, {
          controller,
          contentDescription,
          marker,
          animateChanges = false,
          setup,
          update,
        }) => CandleStickChart(
          data: data,
          controller: controller,
          contentDescription: contentDescription,
          marker: marker,
          animateChanges: animateChanges,
          setup: setup,
          update: update,
        ),
    isView: (chart) => chart.runtimeType == CandleStickChartView,
    // A candle is highlighted at its y, the middle of its shadow: (6 + 2) / 2.
    pointOfSecond: (chart) {
      final e = chart.data!.getDataSetByIndex(0)!.getEntryForIndex(1);
      expect(e.y, 4);
      return _offset(chart.getPixelForValues(1, e.y, AxisDependency.LEFT));
    },
  ).defineTests,
  _Family<BubbleChartView, BubbleData>(
    name: 'BubbleChart',
    data: () => BubbleData([
      BubbleDataSet([
        BubbleEntry(x: 0, y: 1, size: 1),
        BubbleEntry(x: 1, y: 3, size: 2),
        BubbleEntry(x: 2, y: 2, size: 1),
      ], 'a'),
    ]),
    widget:
        (
          data, {
          controller,
          contentDescription,
          marker,
          animateChanges = false,
          setup,
          update,
        }) => BubbleChart(
          data: data,
          controller: controller,
          contentDescription: contentDescription,
          marker: marker,
          animateChanges: animateChanges,
          setup: setup,
          update: update,
        ),
    isView: (chart) => chart.runtimeType == BubbleChartView,
    // The centre of the bubble.
    pointOfSecond: (chart) =>
        _offset(chart.getPixelForValues(1, 3, AxisDependency.LEFT)),
  ).defineTests,
];

void main() {
  test(
    'the default entry point has the widgets, core.dart the chart classes',
    () {
      final widgets = <Widget>[
        BarChart(data: null),
        HorizontalBarChart(data: null),
        ScatterChart(data: null),
        CandleStickChart(data: null),
        BubbleChart(data: null),
      ];
      for (final widget in widgets) {
        expect(widget, isA<StatefulWidget>());
      }

      final BarChartView bar = core.BarChart();
      final HorizontalBarChartView horizontalBar = core.HorizontalBarChart();
      final ScatterChartView scatter = core.ScatterChart();
      final CandleStickChartView candle = core.CandleStickChart();
      final BubbleChartView bubble = core.BubbleChart();
      for (final view in [bar, horizontalBar, scatter, candle, bubble]) {
        expect(view, isA<core.BarLineChartBase>());
      }
      expect(BarChartView == core.BarChart, isTrue);
      expect(HorizontalBarChartView == core.HorizontalBarChart, isTrue);
      expect(ScatterChartView == core.ScatterChart, isTrue);
      expect(CandleStickChartView == core.CandleStickChart, isTrue);
      expect(BubbleChartView == core.BubbleChart, isTrue);
    },
  );

  for (final defineTests in _families) {
    defineTests();
  }
}
