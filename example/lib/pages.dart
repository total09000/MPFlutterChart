// The home list's registry, in MPChartExample's MainActivity order (notimportant/MainActivity.kt): its section() and
// item() calls are DemoSection and DemoEntry here, with the same text. Only the pages this app has are listed; a new
// page is one DemoEntry line under its section (Jetpack Compose and Performance go between All chart types and Line
// Charts, Combined Chart first in Other Charts).
import 'package:flutter/widgets.dart';

import 'pages/bar_chart_multi_dataset_page.dart';
import 'pages/bar_chart_page.dart';
import 'pages/bubble_chart_page.dart';
import 'pages/candle_stick_chart_page.dart';
import 'pages/design_page.dart';
import 'pages/horizontal_bar_chart_page.dart';
import 'pages/line_chart_page.dart';
import 'pages/pie_chart_page.dart';
import 'pages/radar_chart_page.dart';
import 'pages/scatter_chart_page.dart';
import 'pages/stacked_bar_page.dart';

/// A row of the home list: a [DemoSection] header or a [DemoEntry] that opens a page.
sealed class DemoItem {
  const DemoItem(this.name);

  /// The text of the row, MainActivity's `name`.
  final String name;
}

/// A section header, MainActivity's `section(name)`.
class DemoSection extends DemoItem {
  const DemoSection(super.name);
}

/// An entry that opens the page [builder] creates, MainActivity's `item(name, description, activity)`. The page shows
/// [name] as its title.
class DemoEntry extends DemoItem {
  const DemoEntry(super.name, this.description, this.builder);

  /// The second line of the row.
  final String description;

  /// Creates the page.
  final Widget Function() builder;
}

/// Every row of the home list, in order.
const List<DemoItem> examplePages = [
  DemoSection('All chart types'),
  DemoEntry(
    'Dark style',
    'Every chart type in one consistent dark style.',
    DesignPage.darkStyle,
  ),
  DemoEntry(
    'Light style',
    'The same charts on a light background.',
    DesignPage.lightStyle,
  ),
  DemoSection('Line Charts'),
  DemoEntry('Basic', 'Simple line chart.', LineChartPage.new),
  DemoSection('Bar Charts'),
  DemoEntry('Basic', 'Simple bar chart.', BarChartPage.new),
  DemoEntry(
    'Multiple',
    'Show multiple data sets.',
    BarChartMultiDatasetPage.new,
  ),
  DemoEntry(
    'Horizontal',
    'Render bar chart horizontally.',
    HorizontalBarChartPage.new,
  ),
  DemoEntry('Stacked', 'Stacked bar chart.', StackedBarPage.new),
  DemoSection('Pie Charts'),
  DemoEntry('Basic', 'Simple pie chart.', PieChartPage.new),
  DemoSection('Other Charts'),
  DemoEntry('Scatter Plot', 'Simple scatter plot.', ScatterChartPage.new),
  DemoEntry('Bubble Chart', 'Simple bubble chart.', BubbleChartPage.new),
  DemoEntry('Candlestick', 'Simple financial chart.', CandleStickChartPage.new),
  DemoEntry('Radar Chart', 'Simple web chart.', RadarChartPage.new),
];
