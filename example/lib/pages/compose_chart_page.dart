// Ported from MPChartExample: ComposeChartActivity.kt, which has no layout XML or menu: its content is the
// ComposeChartScreen composable.
//
// Jetpack Compose / Compose: a line, a pie and a bar chart driven by widget state, in the light Nightfall variant. The
// line chart takes points one by one and shows the selected one below it, "New data" gives all three charts data from
// the next seed, and the pie and bar charts animate new data in. The composables are the chart widgets of
// mp_flutter_chart (`LineChart`, `PieChart`, `BarChart`) and `rememberChartState()` is a [ChartController] owned by the
// State. `rememberSaveable` and `remember(key)` are fields of the State that a new seed rebuilds, a `LaunchedEffect`
// is a call made after the frame that built the chart for its key. Not ported:
// - the `background` of the colour scheme: Flutter's ColorScheme has none (it is deprecated); the page paints the stage
//   colour behind the cards itself, as the composable does.
// - `safeDrawingPadding()`: DemoScaffold keeps the body clear of the system bars.
// - the @Preview composable, which only Android Studio shows.
// Kotlin's unseeded `Random.nextInt(-9, 14)` in `nextRevenue` is DemoBase's seeded [DemoBase.random], so every run
// adds the same points.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/kotlin_random.dart';
import '../design/nightfall.dart';
import '../design/nightfall_style.dart';
import '../notimportant/demo_base.dart';

/// `Nightfall.light`, the theme of the screen.
const NightfallTheme _theme = Nightfall.light;

/// `nightfallColors`, `lightColorScheme(...)` of the Activity.
final ColorScheme _nightfallColors = ColorScheme.light(
  primary: Nightfall.accent,
  onPrimary: const Color(0xFF06181A),
  surface: _theme.card,
  onSurface: _theme.text,
  onSurfaceVariant: _theme.muted,
);

/// ComposeChartActivity.
class ComposeChartPage extends StatefulWidget {
  const ComposeChartPage({super.key});

  @override
  State<ComposeChartPage> createState() => _ComposeChartPageState();
}

/// ComposeChartScreen.
class _ComposeChartPageState extends State<ComposeChartPage> with DemoBase {
  /// `var seed by rememberSaveable { mutableIntStateOf(0) }`.
  int _seed = 0;

  /// `remember(seed) { revenueSet(seed) }`.
  late LineDataSet _lineSet;

  /// `remember(lineSet) { LineData(lineSet) }`.
  late LineData _lineData;

  /// `var pointCount by remember(lineSet) { mutableIntStateOf(lineSet.entryCount) }`.
  late int _pointCount;

  /// `remember(seed) { platformShare(seed) }`.
  late PieData _pieData;

  /// `remember(seed) { ordersPerQuarter(seed) }`.
  late BarData _barData;

  /// `rememberChartState()` of the line chart.
  final ChartController _lineState = ChartController();

  /// `rememberChartState()` of the bar chart.
  final ChartController _barState = ChartController();

  @override
  void initState() {
    super.initState();
    _remember();
  }

  @override
  void dispose() {
    _lineState.dispose();
    _barState.dispose();
    super.dispose();
  }

  /// The values remembered for [_seed], then the LaunchedEffects of their new keys.
  void _remember() {
    _lineSet = _revenueSet(_seed);
    _lineData = LineData([_lineSet]);
    _pointCount = _lineSet.entryCount;
    _pieData = _platformShare(_seed);
    _barData = _ordersPerQuarter(_seed);
    // LaunchedEffect(lineData) and LaunchedEffect(barData) run once the charts are attached to their states.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lineState.animateX(600);
      _barState.highlight(5);
    });
  }

  double _nextRevenue(double previous) => (previous + random.nextInt(23) - 9).clamp(18, 92).toDouble();

  void _addPoint() {
    _lineSet.addEntry(Entry(x: _pointCount.toDouble(), y: _nextRevenue(_lineSet.entries.last.y)));
    setState(() => _pointCount++);
    _lineState.highlight(_pointCount - 1);
  }

  void _newData() => setState(() {
    _seed++;
    _remember();
  });

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Compose',
    body: Theme(
      data: ThemeData(colorScheme: _nightfallColors),
      child: ColoredBox(
        color: _theme.stage,
        child: SingleChildScrollView(
          dragStartBehavior: chartScrollDragStartBehavior,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              _ChartCard(
                title: 'Revenue',
                subtitle: 'Driven by Compose state',
                children: [
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      data: _lineData,
                      controller: _lineState,
                      contentDescription: 'Revenue line chart',
                      marker: (entry, _) => _Pill('${months[entry.x.toInt() % 12]} · ${entry.y.round()}'),
                      setup: (chart) {
                        nightfallBase(chart, _theme);
                        chart.xAxis.valueFormatter = IAxisValueFormatter.fromFunction(
                          (value, _) => months[value.toInt() % 12],
                        );
                        chart.xAxis.axisMinimum = -0.5;
                        chart.xAxis.granularity = 1;
                        chart.axisLeft.axisMinimum = 0;
                        chart.axisLeft.axisMaximum = 100;
                        chart.axisLeft.labelCount = 5;
                        chart.axisLeft.isForceLabelsEnabled = true;
                      },
                      update: (chart) {
                        // The data changed in place, so the chart has to recompute its axes.
                        chart.xAxis.axisMaximum = _pointCount - 0.5;
                        chart.xAxis.labelCount = _pointCount < 12 ? _pointCount : 12;
                        chart.notifyDataSetChanged();
                      },
                    ),
                  ),
                  ListenableBuilder(
                    listenable: _lineState,
                    builder: (context, _) {
                      final selected = _lineState.selectedEntry;
                      return Text(
                        selected == null
                            ? 'Tap a point to select it'
                            : 'Selected ${months[selected.x.toInt() % 12]}: ${selected.y.round()}',
                        style: TextStyle(color: _theme.muted, fontSize: 13),
                      );
                    },
                  ),
                  Row(
                    spacing: 8,
                    children: [
                      _Button('Add point', Nightfall.accent, _addPoint),
                      _Button('New data', Nightfall.violet, _newData),
                    ],
                  ),
                ],
              ),
              _ChartCard(
                title: 'Sessions by platform',
                subtitle: 'New data animates in',
                children: [
                  SizedBox(
                    height: 220,
                    child: PieChart(
                      data: _pieData,
                      animateChanges: true,
                      contentDescription: 'Sessions pie chart',
                      setup: (chart) => nightfallDonut(chart, _theme),
                    ),
                  ),
                ],
              ),
              _ChartCard(
                title: 'Orders per quarter',
                subtitle: 'Rounded bars with a gradient',
                children: [
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      data: _barData,
                      animateChanges: true,
                      controller: _barState,
                      contentDescription: 'Orders bar chart',
                      marker: (entry, _) => _Pill('${entry.y.round()}'),
                      setup: (chart) {
                        nightfallBase(chart, _theme);
                        chart.xAxis.valueFormatter = IndexAxisValueFormatter(const [
                          'Q1', 'Q2', 'Q3', 'Q4', 'Q1', 'Q2', 'Q3', 'Q4', //
                        ]);
                        chart.axisLeft.axisMinimum = 0;
                        chart.axisLeft.axisMaximum = 100;
                        chart.axisLeft.labelCount = 5;
                        chart.axisLeft.isForceLabelsEnabled = true;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// `revenueSet(seed)`: twelve months of revenue, a random walk from 28 kept within 18 to 92.
LineDataSet _revenueSet(int seed) {
  final random = KotlinRandom(seed);
  var value = 28.0;
  final entries = List.generate(12, (i) {
    value = (value + random.nextIntRange(-5, 15)).clamp(18, 92).toDouble();
    return Entry(x: i.toDouble(), y: value);
  });
  final set = LineDataSet(entries, 'Revenue');
  nightfallLine(set, _theme);
  return set;
}

/// `ordersPerQuarter(seed)`: eight bars from 30 to 89, the sixth one in the selected colour.
BarData _ordersPerQuarter(int seed) {
  final random = KotlinRandom(seed);
  final entries = List.generate(8, (i) => BarEntry(x: i.toDouble(), y: random.nextIntRange(30, 90).toDouble()));
  final set = BarDataSet(entries, 'Orders');
  nightfallBars(set, selected: 5);
  return BarData([set])..barWidth = 0.55;
}

/// `platformShare(seed)`: four slices from 10 to 49.
PieData _platformShare(int seed) {
  final random = KotlinRandom(seed);
  final entries = [
    for (final label in ['Mobile', 'Web', 'Desktop', 'Other'])
      PieEntry(random.nextIntRange(10, 50).toDouble(), label: label),
  ];
  final set = PieDataSet(entries, '');
  nightfallSlices(set);
  return PieData(set);
}

/// The Activity's private `ChartCard`: a card in the light variant with a title and a subtitle above [children].
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.subtitle, required this.children});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: _theme.card, borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(title, style: TextStyle(color: _theme.text, fontWeight: FontWeight.bold, fontSize: 15)),
          Text(subtitle, style: TextStyle(color: _theme.muted, fontSize: 12)),
          ...children,
        ],
      ),
    ),
  );
}

/// The Activity's private `Pill`: the marker content in the light variant's pill colours.
class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: _theme.pillBackground, borderRadius: BorderRadius.circular(8)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(text, style: TextStyle(color: _theme.pillText, fontWeight: FontWeight.bold, fontSize: 12)),
    ),
  );
}

/// A Material 3 `Button` with `ButtonDefaults.buttonColors(containerColor = color)`: its text in onPrimary.
class _Button extends StatelessWidget {
  const _Button(this.label, this.color, this.onPressed);

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(backgroundColor: color),
    onPressed: onPressed,
    child: Text(label),
  );
}
