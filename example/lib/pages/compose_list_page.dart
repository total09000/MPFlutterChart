// Ported from MPChartExample: ComposeListActivity.kt, which has no layout XML or menu: its content is the RegionList
// composable.
//
// Jetpack Compose / Compose list: a card per region with a line chart, 21 rows in a lazy list, in the light Nightfall
// variant. The LazyColumn is a [ListView.builder] whose rows keep the region's name as their key, and the regions are
// built once, so scrolling never rebuilds a data set. The `LineChart` composable is the chart widget of
// mp_flutter_chart.
// Not ported:
// - the `background` of the colour scheme: Flutter's ColorScheme has none (it is deprecated); the page paints the stage
//   colour behind the list itself, as the composable does.
// - `safeDrawingPadding()`: DemoScaffold keeps the body clear of the system bars.
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/kotlin_random.dart';
import '../design/nightfall.dart';
import '../design/nightfall_style.dart';
import '../notimportant/demo_base.dart';

/// `Nightfall.light`, the theme of the list.
const NightfallTheme _theme = Nightfall.light;

/// `listColors`, `lightColorScheme(...)` of the Activity.
final ColorScheme _listColors = ColorScheme.light(
  primary: Nightfall.accent,
  surface: _theme.card,
  onSurface: _theme.text,
  onSurfaceVariant: _theme.muted,
);

/// ComposeListActivity.
class ComposeListPage extends StatefulWidget {
  const ComposeListPage({super.key});

  @override
  State<ComposeListPage> createState() => _ComposeListPageState();
}

/// A row of the list: the region's [name], its line [data] and its [change] over the quarter in percent.
class _Region {
  const _Region(this.name, this.data, this.change);

  final String name;
  final LineData data;
  final int change;
}

/// RegionList.
class _ComposeListPageState extends State<ComposeListPage> with DemoBase {
  /// `remember { regions() }`: built once and remembered, so scrolling never rebuilds a data set.
  final List<_Region> _regions = _buildRegions();

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Compose list',
    body: Theme(
      data: ThemeData(colorScheme: _listColors),
      child: ColoredBox(
        color: _theme.stage,
        child: ListView.builder(
          dragStartBehavior: chartScrollDragStartBehavior,
          padding: const EdgeInsets.all(14),
          itemCount: _regions.length,
          itemBuilder: (context, index) {
            final region = _regions[index];
            return Padding(
              key: ValueKey(region.name),
              // verticalArrangement = Arrangement.spacedBy(14.dp)
              padding: EdgeInsets.only(top: index == 0 ? 0 : 14),
              child: _RegionCard(region),
            );
          },
        ),
      ),
    ),
  );
}

/// RegionCard.
class _RegionCard extends StatelessWidget {
  const _RegionCard(this.region);

  final _Region region;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: _theme.card, borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(region.name, style: TextStyle(color: _theme.text, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(
            region.change >= 0 ? '+${region.change}% this quarter' : '${region.change}% this quarter',
            style: TextStyle(color: _theme.muted, fontSize: 13),
          ),
          // A fixed height keeps the row measurable while the list is scrolling.
          SizedBox(
            width: double.infinity,
            height: 120,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: LineChart(
                data: region.data,
                contentDescription: '${region.name}, ${region.change} percent this quarter',
                setup: (chart) {
                  nightfallBase(chart, _theme);
                  nightfallFullWidthX(chart, region.data.entryCount);
                  chart.axisLeft.isEnabled = false;
                  chart.axisRight.isEnabled = false;
                  chart.xAxis.isEnabled = false;
                  chart.legend.isEnabled = false;
                  // Leave the vertical gesture to the list; a tap still selects a point.
                  chart.isDragEnabled = false;
                  chart.isScaleEnabled = false;
                  chart.isHighlightPerDragEnabled = false;
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

const List<String> _names = [
  'Vienna', 'Graz', 'Linz', 'Salzburg', 'Innsbruck', 'Klagenfurt', 'Villach', 'Wels', //
  'Sankt Pölten', 'Dornbirn', 'Wiener Neustadt', 'Steyr', 'Feldkirch', 'Bregenz', 'Leonding', 'Klosterneuburg', //
  'Baden', 'Leoben', 'Krems', 'Eisenstadt', 'Freistadt',
];

/// `regions()`: per region a random walk of 24 values within 12 to 100 from a start of 40 to 79, all from
/// `Random(7)`, in a colour of the palette in turn.
List<_Region> _buildRegions() {
  final random = KotlinRandom(7);
  return [
    for (final name in _names) _region(name, random),
  ];
}

_Region _region(String name, KotlinRandom random) {
  var value = random.nextIntRange(40, 80).toDouble();
  final entries = List.generate(24, (index) {
    value = (value + random.nextIntRange(-8, 11)).clamp(12, 100).toDouble();
    return Entry(x: index.toDouble(), y: value);
  });
  final color = Nightfall.palette[_names.indexOf(name) % Nightfall.palette.length];
  final set = LineDataSet(entries, name);
  nightfallLine(set, _theme, color);
  set
    ..isDrawCirclesEnabled = false
    ..isDrawValuesEnabled = false;
  final first = entries.first.y;
  // ((last - first) / first * 100).roundToInt() in Float: Math.round, which rounds a half up.
  final change = (_f(_f(_f(entries.last.y - first) / first) * 100) + 0.5).floor();
  return _Region(name, LineData([set]), change);
}

final Float32List _float = Float32List(1);

/// [value] rounded to a Kotlin `Float`.
double _f(double value) {
  _float[0] = value;
  return _float[0];
}
