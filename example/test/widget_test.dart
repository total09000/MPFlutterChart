import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/design/nightfall.dart';
import 'package:mp_flutter_chart_example/main.dart';
import 'package:mp_flutter_chart_example/pages.dart';
import 'package:mp_flutter_chart_example/pages/bar_chart_multi_dataset_page.dart';
import 'package:mp_flutter_chart_example/pages/bar_chart_page.dart';
import 'package:mp_flutter_chart_example/pages/bubble_chart_page.dart';
import 'package:mp_flutter_chart_example/pages/candle_stick_chart_page.dart';
import 'package:mp_flutter_chart_example/pages/horizontal_bar_chart_page.dart';
import 'package:mp_flutter_chart_example/pages/line_chart_page.dart';
import 'package:mp_flutter_chart_example/pages/scatter_chart_page.dart';
import 'package:mp_flutter_chart_example/pages/stacked_bar_page.dart';

/// The home list as MPChartExample's MainActivity.kt:72-125 writes it, for the sections and entries this app has: a
/// section is `(name, null)`, an entry `(name, description)`.
const List<(String, String?)> _home = [
  ('All chart types', null),
  ('Dark style', 'Every chart type in one consistent dark style.'),
  ('Light style', 'The same charts on a light background.'),
  ('Line Charts', null),
  ('Basic', 'Simple line chart.'),
  ('Bar Charts', null),
  ('Basic', 'Simple bar chart.'),
  ('Multiple', 'Show multiple data sets.'),
  ('Horizontal', 'Render bar chart horizontally.'),
  ('Stacked', 'Stacked bar chart.'),
  ('Pie Charts', null),
  ('Basic', 'Simple pie chart.'),
  ('Other Charts', null),
  ('Scatter Plot', 'Simple scatter plot.'),
  ('Bubble Chart', 'Simple bubble chart.'),
  ('Candlestick', 'Simple financial chart.'),
  ('Radar Chart', 'Simple web chart.'),
];

const List<String> _barButtons = [
  'animateY',
  'zoomIn',
  'fitScreen',
  'switch data',
  'toggle shadow',
  'toggle corners',
];

const List<String> _viewportButtons = [
  'animateY',
  'zoomIn',
  'fitScreen',
  'switch data',
];

/// What the All chart types entries open: their home-list description and the page title.
const List<(String, String)> _designPages = [
  ('Every chart type in one consistent dark style.', 'All chart types, dark'),
  ('The same charts on a light background.', 'All chart types, light'),
];

/// What each other entry opens: its home-list description, the page title, the chart widget and the button labels.
const List<(String, String, Type, List<String>)> _pages = [
  (
    'Simple line chart.',
    'Basic',
    LineChart,
    ['animateX', 'zoomIn', 'fitScreen', 'switch data'],
  ),
  ('Simple bar chart.', 'Basic', BarChart, _barButtons),
  ('Show multiple data sets.', 'Multiple', BarChart, _barButtons),
  (
    'Render bar chart horizontally.',
    'Horizontal',
    HorizontalBarChart,
    [..._barButtons, 'toggle above bar'],
  ),
  ('Stacked bar chart.', 'Stacked', BarChart, _barButtons),
  // The pie page's Half pie and Values outside are switches, not buttons.
  ('Simple pie chart.', 'Basic', PieChart, ['Spin']),
  ('Simple scatter plot.', 'Scatter Plot', ScatterChart, _viewportButtons),
  (
    'Simple bubble chart.',
    'Bubble Chart',
    BubbleChart,
    [..._viewportButtons, 'toggle normalize', 'highlight size 0'],
  ),
  (
    'Simple financial chart.',
    'Candlestick',
    CandleStickChart,
    [..._viewportButtons, 'toggle candle bar', 'toggle shadow colour'],
  ),
  ('Simple web chart.', 'Radar Chart', RadarChart, ['Animate']),
];

/// A surface tall enough for the whole home list and a whole page, so every row and button is built and on screen.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Shows the home list and opens the entry whose description is [description].
Future<void> _openPage(WidgetTester tester, String description) async {
  _useTallSurface(tester);
  await tester.pumpWidget(const ExampleApp());
  await tester.pump();
  await tester.tap(find.widgetWithText(ListTile, description));
  await tester.pumpAndSettle();
}

/// The core chart the open page shows.
Chart _chart(WidgetTester tester) => tester
    .widget<ChartHostWidget>(
      find.byWidgetPredicate((widget) => widget is ChartHostWidget),
    )
    .chart;

Future<void> _tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(ExampleButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

List<double> _ys(ChartData data) => [
  for (final set in data.dataSets)
    for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i).y,
];

void main() {
  testWidgets(
    'the home list shows the MainActivity sections and entries in order',
    (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(const ExampleApp());
      await tester.pump();

      var previousTop = double.negativeInfinity;
      for (final (name, description) in _home) {
        final Finder row;
        if (description == null) {
          row = find.text(name);
          expect(row, findsOneWidget, reason: 'section $name');
        } else {
          row = find.widgetWithText(ListTile, description);
          expect(row, findsOneWidget, reason: 'entry $description');
          expect(
            find.descendant(of: row, matching: find.text(name)),
            findsOneWidget,
            reason: 'name of $description',
          );
        }
        final top = tester.getTopLeft(row).dy;
        expect(
          top,
          greaterThan(previousTop),
          reason: '$name comes after the row before it',
        );
        previousTop = top;
      }
      expect(find.byType(ListTile), findsNWidgets(12));

      final sections = [
        for (final (name, description) in _home)
          if (description == null) name,
      ];
      expect([
        for (final section in examplePages.whereType<DemoSection>())
          section.name,
      ], sections);
      // The header rows: the list's texts that are not part of an entry.
      expect([
        for (final element
            in find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Text),
                )
                .evaluate())
          if (element.findAncestorWidgetOfExactType<ListTile>() == null)
            (element.widget as Text).data,
      ], sections);
    },
  );

  testWidgets(
    'each entry opens a page titled with its name that shows its chart',
    (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(const ExampleApp());
      await tester.pump();

      for (final (description, name, chart, buttons) in _pages) {
        await tester.tap(find.widgetWithText(ListTile, description));
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(AppBar, name),
          findsOneWidget,
          reason: description,
        );
        expect(find.byType(chart), findsOneWidget, reason: description);
        expect(
          [
            for (final button in tester.widgetList<ExampleButton>(
              find.byType(ExampleButton),
            ))
              button.label,
          ],
          buttons,
          reason: description,
        );
        expect(tester.takeException(), isNull, reason: description);

        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('the All chart types entries open the dark and the light '
      'design page', (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    for (final (description, title) in _designPages) {
      await tester.tap(find.widgetWithText(ListTile, description));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(AppBar, title),
        findsOneWidget,
        reason: description,
      );
      expect(
        find.byWidgetPredicate((widget) => widget is ChartHostWidget),
        findsNWidgets(10),
        reason: description,
      );
      expect(tester.takeException(), isNull, reason: description);

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  for (final entry in examplePages.whereType<DemoEntry>()) {
    testWidgets('every button of the "${entry.description}" page can be tapped '
        'twice', (tester) async {
      await _openPage(tester, entry.description);
      final count = find.byType(ExampleButton).evaluate().length;
      // The All chart types pages have no buttons; design_test.dart taps their menu.
      if (count == 0) return;

      for (var i = 0; i < count; i++) {
        for (var round = 0; round < 2; round++) {
          final button = find.byType(ExampleButton).at(i);
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'button $i, tap ${round + 1}',
          );
        }
      }
    });
  }

  for (final entry in examplePages.whereType<DemoEntry>()) {
    testWidgets('the "${entry.description}" page scrolls a swipe that starts '
        'on a chart from the down', (tester) async {
      await _openPage(tester, entry.description);
      final hosts = find.byWidgetPredicate((w) => w is ChartHostWidget);
      expect(hosts, findsWidgets);

      for (var i = 0; i < hosts.evaluate().length; i++) {
        final scrollables = find.ancestor(
          of: hosts.at(i),
          matching: find.byType(Scrollable),
        );
        expect(scrollables, findsWidgets, reason: 'chart $i');
        for (final scrollable in tester.widgetList<Scrollable>(scrollables)) {
          expect(
            scrollable.dragStartBehavior,
            DragStartBehavior.down,
            reason: 'chart $i',
          );
        }
      }
    });
  }

  group('the line page keeps its behaviour', () {
    testWidgets('the page shows the line chart and its buttons', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LineChartPage()));
      await tester.pump();

      expect(find.byType(LineChart), findsOneWidget);
      for (final label in ['animateX', 'zoomIn', 'fitScreen', 'switch data']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('switch data animates the new values in', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LineChartPage()));
      await tester.pump();

      await tester.ensureVisible(find.text('switch data'));
      await tester.pump();
      await tester.tap(find.text('switch data'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final chart = tester
          .widget<ChartHostWidget<LineChartView, LineData>>(
            find.byType(ChartHostWidget<LineChartView, LineData>),
          )
          .chart;
      expect(chart.isAnimating, isTrue);

      await tester.pumpAndSettle();
      expect(chart.isAnimating, isFalse);
    });
  });

  group('page toggles', () {
    List<double> cornerRadii(Chart chart) => [
      for (final set in (chart as BarChartView).barData!.dataSets)
        set.barCornerRadius,
    ];

    // The page's description, the button, and what the button changes on the chart.
    final toggles = <(String, String, Object Function(Chart chart))>[
      (
        'Simple bar chart.',
        'toggle shadow',
        (chart) => (chart as BarChartView).isDrawBarShadowEnabled,
      ),
      ('Simple bar chart.', 'toggle corners', cornerRadii),
      (
        'Show multiple data sets.',
        'toggle shadow',
        (chart) => (chart as BarChartView).isDrawBarShadowEnabled,
      ),
      ('Show multiple data sets.', 'toggle corners', cornerRadii),
      (
        'Render bar chart horizontally.',
        'toggle shadow',
        (chart) => (chart as HorizontalBarChartView).isDrawBarShadowEnabled,
      ),
      ('Render bar chart horizontally.', 'toggle corners', cornerRadii),
      (
        'Render bar chart horizontally.',
        'toggle above bar',
        (chart) => (
          (chart as HorizontalBarChartView).isDrawValueAboveBarEnabled,
          chart.barData!.dataSets.single.valueTextColor,
        ),
      ),
      (
        'Stacked bar chart.',
        'toggle shadow',
        (chart) => (chart as BarChartView).isDrawBarShadowEnabled,
      ),
      ('Stacked bar chart.', 'toggle corners', cornerRadii),
      (
        'Simple financial chart.',
        'toggle candle bar',
        (chart) => (chart as CandleStickChartView).candleData!.dataSets
            .map((set) => set.showCandleBar)
            .toList(),
      ),
      (
        'Simple financial chart.',
        'toggle shadow colour',
        (chart) => (chart as CandleStickChartView).candleData!.dataSets
            .map((set) => set.shadowColorSameAsCandle)
            .toList(),
      ),
      (
        'Simple bubble chart.',
        'toggle normalize',
        (chart) => (chart as BubbleChartView).bubbleData!.dataSets
            .map((set) => set.isNormalizeSizeEnabled)
            .toList(),
      ),
    ];

    for (final (page, button, read) in toggles) {
      testWidgets(
        '"$button" on the "$page" page changes the chart both ways, and '
        'each state survives a data switch',
        (tester) async {
          await _openPage(tester, page);
          final chart = _chart(tester);
          final before = read(chart);

          await _tapButton(tester, button);
          final toggled = read(chart);
          expect(toggled, isNot(equals(before)));

          var data = chart.data;
          await _tapButton(tester, 'switch data');
          expect(chart.data, isNot(same(data)));
          expect(read(chart), equals(toggled));

          await _tapButton(tester, button);
          expect(read(chart), equals(before));

          data = chart.data;
          await _tapButton(tester, 'switch data');
          expect(chart.data, isNot(same(data)));
          expect(read(chart), equals(before));
        },
      );
    }

    testWidgets('the horizontal bar labels are dark inside the bars and light '
        'above them', (tester) async {
      await _openPage(tester, 'Render bar chart horizontally.');
      final chart = _chart(tester) as HorizontalBarChartView;
      Color labelColor() => chart.barData!.dataSets.single.valueTextColor;
      expect(chart.isDrawValueAboveBarEnabled, isTrue);
      expect(labelColor(), Nightfall.muted);

      await _tapButton(tester, 'toggle above bar');
      expect(chart.isDrawValueAboveBarEnabled, isFalse);
      expect(labelColor(), Nightfall.stage);

      await _tapButton(tester, 'switch data');
      expect(labelColor(), Nightfall.stage);
    });

    testWidgets('"highlight size 0" highlights the bubble of size 0', (
      tester,
    ) async {
      await _openPage(tester, 'Simple bubble chart.');
      final chart = _chart(tester);

      await _tapButton(tester, 'highlight size 0');
      final highlight = chart.highlighted.single;
      final entry = chart.data!.getEntryForHighlight(highlight);
      expect(highlight.dataSetIndex, 0);
      expect(entry, isA<BubbleEntry>());
      expect((entry! as BubbleEntry).size, 0);
      expect(find.byType(Pill), findsOneWidget);
      expect(find.textContaining('selected x 3: '), findsOneWidget);
    });
  });

  group('page data', () {
    final generators = <String, ChartData Function(int seed)>{
      'bar': barChartData,
      'multiple': barChartMultiDatasetData,
      'horizontal': horizontalBarChartData,
      'stacked': stackedBarData,
      'scatter': scatterChartData,
      'bubble': bubbleChartData,
      'candle': candleStickChartData,
    };

    test('depends on the seed only', () {
      generators.forEach((name, generate) {
        expect(_ys(generate(0)), _ys(generate(0)), reason: name);
        expect(_ys(generate(1)), isNot(_ys(generate(0))), reason: name);
      });
    });

    test('of the multiple page is two data sets grouped one x unit apart', () {
      final data = barChartMultiDatasetData(0);
      expect(data.dataSetCount, 2);
      expect(data.getGroupWidth(0.08, 0.03), closeTo(1, 1e-9));
      // groupBars from 1980: half the group space, then half a bar space and half a bar per bar.
      expect(data.dataSets[0].getEntryForIndex(0).x, closeTo(1980.27, 1e-9));
      expect(data.dataSets[1].getEntryForIndex(0).x, closeTo(1980.73, 1e-9));
      expect(data.dataSets[0].getEntryForIndex(10).x, closeTo(1990.27, 1e-9));
    });

    test('of the horizontal page has negative and positive values', () {
      final data = horizontalBarChartData(0);
      expect(data.dataSetCount, 1);
      expect(data.yMin, lessThan(0));
      expect(data.yMax, greaterThan(0));
    });

    test('of the stacked page is labelled stacks of three with the total on '
        'top', () {
      final data = stackedBarData(0);
      final set = data.dataSets.single as BarDataSet;
      expect(set.stackSize, 3);
      expect(set.stackLabels, ['Births', 'Divorces', 'Marriages']);
      expect(set.valueFormatter, isA<StackedValueFormatter>());
      // Drawn inside the top section, so dark.
      expect(set.valueTextColor, Nightfall.stage);
    });

    test('of the scatter page has one data set per shape and a circle with '
        'a hole', () {
      final data = scatterChartData(0);
      expect(data.dataSetCount, ScatterShape.values.length);
      for (final shape in ScatterShape.values) {
        final set = data.dataSets[shape.index] as ScatterDataSet;
        expect(set.label, shape.toString());
        expect(
          set.shapeRenderer.runtimeType,
          ScatterDataSet.getRendererForShape(shape).runtimeType,
          reason: '$shape',
        );
        expect(
          set.scatterShapeHoleRadius > 0,
          shape == ScatterShape.CIRCLE,
          reason: '$shape',
        );
      }
      expect(
        data.dataSets.map((set) => set.shapeRenderer.runtimeType).toSet(),
        hasLength(7),
      );
    });

    test('of the candle page has rising, falling and one flat candle', () {
      for (final seed in [0, 1]) {
        final set = candleStickChartData(seed).dataSets.single;
        final entries = [
          for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i),
        ];
        expect(entries, hasLength(30));
        expect(entries.where((e) => e.close > e.open), isNotEmpty);
        expect(entries.where((e) => e.close < e.open), isNotEmpty);
        expect(
          [
            for (final e in entries)
              if (e.close == e.open) e.x,
          ],
          [5],
          reason: 'seed $seed',
        );
      }
    });

    test('of the bubble page has a bubble of size 0 next to one of size 4', () {
      for (final seed in [0, 1]) {
        final set = bubbleChartData(seed).dataSets.first;
        final zero = set.getEntryForIndex(bubbleChartZeroSizeX);
        final four = set.getEntryForIndex(bubbleChartZeroSizeX + 1);
        expect(zero.x, bubbleChartZeroSizeX);
        expect(zero.size, 0, reason: 'seed $seed');
        expect(four.size, 4, reason: 'seed $seed');
        expect(four.y, zero.y, reason: 'seed $seed');
      }
    });
  });
}
