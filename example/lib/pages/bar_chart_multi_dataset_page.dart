// Bar Charts / Multiple (MPChartExample's BarChartActivityMultiDataset): two data sets whose bars are grouped side by
// side, one group per year, in the Nightfall style. The data is generated as the Activity's onProgressChanged
// generates it at the seek bars' initial values, from a seeded Random, with two companies instead of four; the bar
// width is chosen so a group is one x unit wide, as the Activity's four bars of 0.2 are. The value labels are off, as
// in Nightfall's bars: 22 labels do not fit above bars this narrow on a phone.
import 'dart:math' as math;

// Material has its own `Easing`; the chart's is MPAndroidChart's Easing.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/nightfall.dart';

/// Number of groups, the Activity's seekBar1 initial value plus one.
const int _groupCount = 11;

/// x value of the first group.
const int _startYear = 1980;

/// Upper end of the values, the Activity's seekBar2 initial value times 100000.
const double _randomMultiplier = 100 * 100000;

const double _groupSpace = 0.08;
const double _barSpace = 0.03;

/// (0.43 + 0.03) * 2 + 0.08 = 1, the width of a group.
const double _barWidth = 0.43;

/// A [BarChart] of two grouped data sets inside a [ListView], with buttons that drive it through a [ChartController]
/// and toggle the bar shadow and the rounded bar corners.
class BarChartMultiDatasetPage extends StatefulWidget {
  const BarChartMultiDatasetPage({super.key});

  @override
  State<BarChartMultiDatasetPage> createState() =>
      _BarChartMultiDatasetPageState();
}

class _BarChartMultiDatasetPageState extends State<BarChartMultiDatasetPage> {
  final ChartController _controller = ChartController();
  int _seed = 0;
  late BarData _data = barChartMultiDatasetData(_seed);
  bool _shadow = false;
  bool _rounded = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Multiple'),
      backgroundColor: Nightfall.card,
      foregroundColor: Nightfall.text,
    ),
    body: ListView(
      dragStartBehavior: chartScrollDragStartBehavior,
      padding: const EdgeInsets.all(14),
      children: [
        ChartCard(
          title: 'Two companies, grouped by year',
          subtitle: 'Drag, pinch or double-tap the chart; tap a bar',
          children: [
            SizedBox(
              height: 300,
              child: BarChart(
                data: _data,
                controller: _controller,
                animateChanges: true,
                contentDescription: 'Bar chart with two grouped data sets',
                marker: (entry, highlight) => Pill(
                  '${_data.getDataSetByIndex(highlight.dataSetIndex)?.label ?? ''}'
                  ' · ${(entry.y / 1000000).toStringAsFixed(2)}m',
                ),
                setup: _setup,
                update: (chart) {
                  chart.isDrawBarShadowEnabled = _shadow;
                  for (final set in _data.dataSets.cast<BarDataSet>()) {
                    set.barCornerRadius = _rounded ? 7 : 0;
                  }
                },
              ),
            ),
            StatusLine(_controller),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ExampleButton(
                  'animateY',
                  Nightfall.accent,
                  () => _controller.animateY(1500),
                ),
                ExampleButton('zoomIn', Nightfall.coral, _controller.zoomIn),
                ExampleButton(
                  'fitScreen',
                  Nightfall.amber,
                  _controller.fitScreen,
                ),
                ExampleButton(
                  'switch data',
                  Nightfall.violet,
                  () =>
                      setState(() => _data = barChartMultiDatasetData(++_seed)),
                ),
                ExampleButton(
                  'toggle shadow',
                  Nightfall.green,
                  () => setState(() => _shadow = !_shadow),
                ),
                ExampleButton(
                  'toggle corners',
                  Nightfall.accent,
                  () => setState(() => _rounded = !_rounded),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Filler('Scroll area below the chart', height: 480),
      ],
    ),
  );
}

/// The Activity's legend and axis settings on top of the Nightfall styling. The x axis spans the groups, as the
/// Activity sets it after grouping; every seed has the same number of groups, so it is set once here.
void _setup(BarChartView chart) {
  nightfallSetup(chart);
  chart.legend
    ..verticalAlignment = LegendVerticalAlignment.TOP
    ..horizontalAlignment = LegendHorizontalAlignment.RIGHT
    ..orientation = LegendOrientation.VERTICAL
    ..isDrawInsideEnabled = true
    ..yOffset = 0
    ..xOffset = 10
    ..yEntrySpace = 0
    ..textSize = 8;
  chart.xAxis
    ..isCenterAxisLabelsEnabled = true
    ..valueFormatter = IAxisValueFormatter.fromFunction(
      (value, _) => value.toInt().toString(),
    )
    ..axisMinimum = _startYear.toDouble()
    ..axisMaximum =
        _startYear + ((_barWidth + _barSpace) * 2 + _groupSpace) * _groupCount;
  chart.axisLeft
    ..valueFormatter = LargeValueFormatter()
    ..spaceTop = 35
    ..axisMinimum = 0;
}

/// Two data sets of [_groupCount] bars, one per year from [_startYear], with values from 0 to [_randomMultiplier], as
/// the Activity's onProgressChanged, grouped with [BarData.groupBars]. The values depend on [seed] only, and every
/// seed has the same shape, so switching between them animates.
BarData barChartMultiDatasetData(int seed) {
  final random = math.Random(seed);
  final values1 = <BarEntry>[];
  final values2 = <BarEntry>[];
  for (var i = _startYear; i < _startYear + _groupCount; i++) {
    values1.add(
      BarEntry(x: i.toDouble(), y: random.nextDouble() * _randomMultiplier),
    );
    values2.add(
      BarEntry(x: i.toDouble(), y: random.nextDouble() * _randomMultiplier),
    );
  }

  BarDataSet company(List<BarEntry> values, String label, Color color) =>
      BarDataSet(values, label)
        ..fills = [Fill.ofColors(color, color.withAlpha(90))]
        ..color = color
        ..barShadowColor = Nightfall.muted.withAlpha(50)
        ..highlightColor = Nightfall.text
        ..highlightAlpha = 90;

  return BarData([
      company(values1, 'Company A', Nightfall.accent),
      company(values2, 'Company B', Nightfall.coral),
    ])
    ..setDrawValues(false)
    ..barWidth = _barWidth
    ..groupBars(_startYear.toDouble(), _groupSpace, _barSpace);
}
