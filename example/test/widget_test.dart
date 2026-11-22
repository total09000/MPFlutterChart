// Not a port of a Kotlin test: MPChartExample has no tests. Checks the home list against MainActivity.kt and that
// every entry opens its page; what a page does is checked by its own test under test/pages/ (the All chart types
// pages by design_test.dart).
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart_example/main.dart';
import 'package:mp_flutter_chart_example/pages.dart';

import 'support/pages.dart';

/// The home list as MPChartExample's MainActivity.kt:72-125 writes it: a section is `(name, null)`, an entry
/// `(name, description)`. Two entries are left out: Combined Chart (first in Other Charts), since CombinedChart is not
/// ported, and From Java (last in Line Charts), which has no counterpart in Dart.
const List<(String, String?)> _home = [
  ('All chart types', null),
  ('Dark style', 'Every chart type in one consistent dark style.'),
  ('Light style', 'The same charts on a light background.'),
  ('Jetpack Compose', null),
  ('Compose', 'Line, pie and bar charts driven by Compose state.'),
  ('Compose list', 'A chart per row in a LazyColumn.'),
  ('Performance', null),
  ('Line chart', 'Pan and zoom a line chart while a readout shows what each draw costs.'),
  ('Bar chart', 'Pan and zoom a bar chart while a readout shows what each draw costs.'),
  ('Line Charts', null),
  ('Basic', 'Simple line chart.'),
  ('Multiple', 'Show multiple data sets.'),
  ('Dual Axis', 'Line chart with dual y-axes.'),
  ('Inverted Axis', 'Inverted y-axis.'),
  ('Cubic', 'Line chart with a cubic line shape.'),
  ('Colorful', 'Colorful line chart.'),
  ('Performance', 'Render 30.000 data points smoothly.'),
  ('Filled', 'Colored area between two lines.'),
  ('Bar Charts', null),
  ('Basic', 'Simple bar chart.'),
  ('Basic 2', 'Variation of the simple bar chart.'),
  ('Multiple', 'Show multiple data sets.'),
  ('Horizontal', 'Render bar chart horizontally.'),
  ('Stacked', 'Stacked bar chart.'),
  ('Negative', 'Positive and negative values with unique colors.'),
  ('Negative Horizontal', 'demonstrates how to create a HorizontalBarChart with positive and negative values.'),
  ('Stacked 2', 'Stacked bar chart with negative values.'),
  ('Sine', 'Sine function in bar chart format.'),
  ('Custom renderer', 'Bar values drawn on a badge by a renderer of your own.'),
  ('Pie Charts', null),
  ('Basic', 'Simple pie chart.'),
  ('Value Lines', 'Stylish lines drawn outward from slices.'),
  ('Half Pie', '180° (half) pie chart.'),
  ('Other Charts', null),
  ('Scatter Plot', 'Simple scatter plot.'),
  ('Bubble Chart', 'Simple bubble chart.'),
  ('Candlestick', 'Simple financial chart.'),
  ('Radar Chart', 'Simple web chart.'),
  ('Scrolling Charts', null),
  ('Multiple', 'Various types of charts as fragments.'),
  ('View Pager', 'Swipe through different charts.'),
  ('Tall Bar Chart', 'Bars bigger than your screen!'),
  ('Many Bar Charts', 'More bars than your screen can handle!'),
  ('Even More Line Charts', null),
  ('Dynamic', 'Build a line chart by adding points and sets.'),
  ('Realtime', 'Add data points in realtime.'),
  ('Hourly', 'Uses the current time to add a data point for each hour.'),
  ('Animation', null),
  ('All animations', 'X, Y, XY, spin, new data and single values with every easing curve, plus stop and onEnd.'),
  ('Animated data changes', 'Randomize, add or remove values, or tap a bar, and watch the values move.'),
];

/// The titles of the All chart types pages, DesignActivity's, by the description of their entry; every other page is
/// titled with the name of its entry.
const Map<String, String> _designTitles = {
  'Every chart type in one consistent dark style.': 'All chart types, dark',
  'The same charts on a light background.': 'All chart types, light',
};

/// The surface of the page tests, big enough for a whole page.
const Size _pageSurface = Size(800, 1600);

/// A surface tall enough for every row of the home list, which builds its rows lazily.
const Size _listSurface = Size(800, 6000);

/// Shows the home list on a surface of [size], with the example's assets from [TestAssetBundle].
Future<void> _pumpHome(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(DefaultAssetBundle(bundle: TestAssetBundle(), child: const ExampleApp()));
  await tester.pump();
}

/// The rows the home list shows, from top to bottom, in the shape of [_home].
List<(String, String?)> _shownRows(WidgetTester tester) {
  final rows = <(double, (String, String?))>[];
  final list = find.byType(ListView);
  for (final element in find.descendant(of: list, matching: find.byType(ListTile)).evaluate()) {
    final tile = element.widget as ListTile;
    rows.add((
      tester.getTopLeft(find.byWidget(tile)).dy,
      ((tile.title! as Text).data!, (tile.subtitle! as Text).data),
    ));
  }
  for (final element in find.descendant(of: list, matching: find.byType(Text)).evaluate()) {
    if (element.findAncestorWidgetOfExactType<ListTile>() != null) continue;
    final text = element.widget as Text;
    rows.add((tester.getTopLeft(find.byWidget(text)).dy, (text.data!, null)));
  }
  rows.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, row) in rows) row];
}

/// Opens the [index]th entry of the home list, counted over the entries only, by scrolling to its row and tapping it.
/// The page's first frames are pumped; a page with a timer never settles, so the route's transition is pumped by time.
Future<DemoEntry> _openEntry(WidgetTester tester, int index) async {
  final entry = examplePages.whereType<DemoEntry>().elementAt(index);
  // The row's key is its index in the registry; two entries have the same name and description.
  final row = find.byKey(ValueKey<int>(examplePages.indexOf(entry)));
  await tester.scrollUntilVisible(row, 300, scrollable: find.byType(Scrollable).first);
  await tester.tap(row);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
  return entry;
}

/// Leaves the open page, and a dialog it may show, and lets the route's transition end, so the page is disposed.
Future<void> _closePage(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator)).popUntil((route) => route.isFirst);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

void main() {
  test('the registry has MainActivity\'s sections and entries in order', () {
    expect([
      for (final item in examplePages)
        switch (item) {
          DemoSection(:final name) => (name, null),
          DemoEntry(:final name, :final description) => (name, description),
        },
    ], _home);
  });

  testWidgets('the home list shows the MainActivity sections and entries in order', (tester) async {
    await _pumpHome(tester, _listSurface);

    expect(_shownRows(tester), _home);
    expect(find.byType(ListTile), findsNWidgets(40));
    expect(tester.takeException(), isNull);
  });

  final entries = examplePages.whereType<DemoEntry>().toList();
  for (var i = 0; i < entries.length; i++) {
    final section = examplePages.take(examplePages.indexOf(entries[i])).whereType<DemoSection>().last.name;
    final name = '$section / ${entries[i].name}';

    testWidgets('$name opens a page titled with its name that shows a chart', (tester) async {
      await _pumpHome(tester, _pageSurface);
      final entry = await _openEntry(tester, i);

      expect(
        find.widgetWithText(AppBar, _designTitles[entry.description] ?? entry.name),
        findsOneWidget,
      );
      expect(chartHosts, findsWidgets);
      expect(tester.takeException(), isNull);

      await _closePage(tester);
      expect(chartHosts, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name scrolls a swipe that starts on a chart from the down', (tester) async {
      await _pumpHome(tester, _pageSurface);
      await _openEntry(tester, i);

      final hosts = chartHosts;
      for (var chart = 0; chart < hosts.evaluate().length; chart++) {
        final scrollables = find.ancestor(of: hosts.at(chart), matching: find.byType(Scrollable));
        for (final scrollable in tester.widgetList<Scrollable>(scrollables)) {
          expect(scrollable.dragStartBehavior, DragStartBehavior.down, reason: 'chart $chart');
        }
      }

      await _closePage(tester);
    });
  }

  testWidgets('the All chart types entries open the dark and the light design page', (tester) async {
    await _pumpHome(tester, _pageSurface);

    for (var i = 0; i < 2; i++) {
      await _openEntry(tester, i);
      await tester.pumpAndSettle();

      expect(chartHosts, findsNWidgets(10), reason: entries[i].name);
      expect(tester.takeException(), isNull, reason: entries[i].name);

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
