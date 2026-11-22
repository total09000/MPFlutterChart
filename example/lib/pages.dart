// The home list's registry, in MPChartExample's MainActivity order (notimportant/MainActivity.kt): its section() and
// item() calls are DemoSection and DemoEntry here, with the same text. Two of MainActivity's entries have no page:
// Other Charts / Combined Chart, because CombinedChart is not ported (it goes first in Other Charts), and Line Charts /
// From Java, the Basic line chart written in Java, which has no counterpart in a Dart package (it goes last in Line
// Charts).
import 'package:flutter/widgets.dart';

import 'pages/animated_changes_page.dart';
import 'pages/animation_playground_page.dart';
import 'pages/another_bar_page.dart';
import 'pages/bar_chart_multi_dataset_page.dart';
import 'pages/bar_chart_page.dart';
import 'pages/bar_chart_positive_negative_page.dart';
import 'pages/bar_chart_sinus_page.dart';
import 'pages/bar_performance_page.dart';
import 'pages/bubble_chart_page.dart';
import 'pages/candle_stick_chart_page.dart';
import 'pages/compose_chart_page.dart';
import 'pages/compose_list_page.dart';
import 'pages/cubic_line_chart_page.dart';
import 'pages/custom_renderer_page.dart';
import 'pages/design_page.dart';
import 'pages/dynamical_adding_page.dart';
import 'pages/filled_line_page.dart';
import 'pages/half_pie_chart_page.dart';
import 'pages/horizontal_bar_chart_page.dart';
import 'pages/horizontal_bar_negative_chart_page.dart';
import 'pages/inverted_line_chart_page.dart';
import 'pages/line_chart2_page.dart';
import 'pages/line_chart_colored_page.dart';
import 'pages/line_chart_page.dart';
import 'pages/line_chart_time_page.dart';
import 'pages/line_performance_page.dart';
import 'pages/list_view_bar_chart_page.dart';
import 'pages/list_view_multi_chart_page.dart';
import 'pages/multi_line_chart_page.dart';
import 'pages/performance_line_chart_page.dart';
import 'pages/pie_chart_page.dart';
import 'pages/pie_polyline_chart_page.dart';
import 'pages/radar_chart_page.dart';
import 'pages/realtime_line_chart_page.dart';
import 'pages/scatter_chart_page.dart';
import 'pages/scroll_view_page.dart';
import 'pages/simple_chart_demo_page.dart';
import 'pages/stacked_bar_negative_page.dart';
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
/// [name] as its title, where the Activity shows its class name; the All chart types pages have DesignActivity's
/// titles.
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
  DemoEntry('Dark style', 'Every chart type in one consistent dark style.', DesignPage.darkStyle),
  DemoEntry('Light style', 'The same charts on a light background.', DesignPage.lightStyle),
  DemoSection('Jetpack Compose'),
  DemoEntry('Compose', 'Line, pie and bar charts driven by Compose state.', ComposeChartPage.new),
  DemoEntry('Compose list', 'A chart per row in a LazyColumn.', ComposeListPage.new),
  DemoSection('Performance'),
  DemoEntry(
    'Line chart',
    'Pan and zoom a line chart while a readout shows what each draw costs.',
    LinePerformancePage.new,
  ),
  DemoEntry(
    'Bar chart',
    'Pan and zoom a bar chart while a readout shows what each draw costs.',
    BarPerformancePage.new,
  ),
  DemoSection('Line Charts'),
  DemoEntry('Basic', 'Simple line chart.', LineChartPage.new),
  DemoEntry('Multiple', 'Show multiple data sets.', MultiLineChartPage.new),
  DemoEntry('Dual Axis', 'Line chart with dual y-axes.', LineChart2Page.new),
  DemoEntry('Inverted Axis', 'Inverted y-axis.', InvertedLineChartPage.new),
  DemoEntry('Cubic', 'Line chart with a cubic line shape.', CubicLineChartPage.new),
  DemoEntry('Colorful', 'Colorful line chart.', LineChartColoredPage.new),
  DemoEntry('Performance', 'Render 30.000 data points smoothly.', PerformanceLineChartPage.new),
  DemoEntry('Filled', 'Colored area between two lines.', FilledLinePage.new),
  DemoSection('Bar Charts'),
  DemoEntry('Basic', 'Simple bar chart.', BarChartPage.new),
  DemoEntry('Basic 2', 'Variation of the simple bar chart.', AnotherBarPage.new),
  DemoEntry('Multiple', 'Show multiple data sets.', BarChartMultiDatasetPage.new),
  DemoEntry('Horizontal', 'Render bar chart horizontally.', HorizontalBarChartPage.new),
  DemoEntry('Stacked', 'Stacked bar chart.', StackedBarPage.new),
  DemoEntry('Negative', 'Positive and negative values with unique colors.', BarChartPositiveNegativePage.new),
  DemoEntry(
    'Negative Horizontal',
    'demonstrates how to create a HorizontalBarChart with positive and negative values.',
    HorizontalBarNegativeChartPage.new,
  ),
  DemoEntry('Stacked 2', 'Stacked bar chart with negative values.', StackedBarNegativePage.new),
  DemoEntry('Sine', 'Sine function in bar chart format.', BarChartSinusPage.new),
  DemoEntry('Custom renderer', 'Bar values drawn on a badge by a renderer of your own.', CustomRendererPage.new),
  DemoSection('Pie Charts'),
  DemoEntry('Basic', 'Simple pie chart.', PieChartPage.new),
  DemoEntry('Value Lines', 'Stylish lines drawn outward from slices.', PiePolylineChartPage.new),
  DemoEntry('Half Pie', '180° (half) pie chart.', HalfPieChartPage.new),
  DemoSection('Other Charts'),
  DemoEntry('Scatter Plot', 'Simple scatter plot.', ScatterChartPage.new),
  DemoEntry('Bubble Chart', 'Simple bubble chart.', BubbleChartPage.new),
  DemoEntry('Candlestick', 'Simple financial chart.', CandleStickChartPage.new),
  DemoEntry('Radar Chart', 'Simple web chart.', RadarChartPage.new),
  DemoSection('Scrolling Charts'),
  DemoEntry('Multiple', 'Various types of charts as fragments.', ListViewMultiChartPage.new),
  DemoEntry('View Pager', 'Swipe through different charts.', SimpleChartDemoPage.new),
  DemoEntry('Tall Bar Chart', 'Bars bigger than your screen!', ScrollViewPage.new),
  DemoEntry('Many Bar Charts', 'More bars than your screen can handle!', ListViewBarChartPage.new),
  DemoSection('Even More Line Charts'),
  DemoEntry('Dynamic', 'Build a line chart by adding points and sets.', DynamicalAddingPage.new),
  DemoEntry('Realtime', 'Add data points in realtime.', RealtimeLineChartPage.new),
  DemoEntry('Hourly', 'Uses the current time to add a data point for each hour.', LineChartTimePage.new),
  DemoSection('Animation'),
  DemoEntry(
    'All animations',
    'X, Y, XY, spin, new data and single values with every easing curve, plus stop and onEnd.',
    AnimationPlaygroundPage.new,
  ),
  DemoEntry(
    'Animated data changes',
    'Randomize, add or remove values, or tap a bar, and watch the values move.',
    AnimatedChangesPage.new,
  ),
];
