// Bar Charts / Basic (MPChartExample's BarChartActivity): one data set of bars with a gradient fill per bar, drawn
// in the Nightfall style. The data is generated as BarChartActivity.setData generates it at the seek bars' initial
// values, from a seeded Random; the star icons are left out, as the Activity does not draw them.
import 'dart:math' as math;

// Material has its own `Easing`; the chart's is MPAndroidChart's Easing.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/nightfall.dart';

/// Number of bars, the Activity's seekBar1 initial value.
const int _count = 12;

/// Upper end of the values, the Activity's seekBar2 initial value.
const double _range = 50;

/// A [BarChart] of one data set inside a [ListView], with buttons that drive it through a [ChartController] and toggle
/// the bar shadow and the rounded bar corners.
class BarChartPage extends StatefulWidget {
  const BarChartPage({super.key});

  @override
  State<BarChartPage> createState() => _BarChartPageState();
}

class _BarChartPageState extends State<BarChartPage> {
  final ChartController _controller = ChartController();
  int _seed = 0;
  late BarData _data = barChartData(_seed);
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
      title: const Text('Basic'),
      backgroundColor: Nightfall.card,
      foregroundColor: Nightfall.text,
    ),
    body: ListView(
      dragStartBehavior: chartScrollDragStartBehavior,
      padding: const EdgeInsets.all(14),
      children: [
        ChartCard(
          title: 'The year 2017',
          subtitle: 'Drag, pinch or double-tap the chart; tap a bar',
          children: [
            SizedBox(
              height: 300,
              child: BarChart(
                data: _data,
                controller: _controller,
                animateChanges: true,
                contentDescription: 'Bar chart with one data set',
                marker: (entry, highlight) => Pill(
                  'x ${entry.x.toStringAsFixed(0)} · ${entry.y.toStringAsFixed(1)}',
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
                  () => setState(() => _data = barChartData(++_seed)),
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

/// The Activity's chart and axis settings on top of the Nightfall styling.
void _setup(BarChartView chart) {
  nightfallSetup(chart);
  chart.isDrawValueAboveBarEnabled = true;
  chart.maxVisibleCount = 60;
  chart.xAxis.labelCount = 7;
  chart.axisLeft
    ..labelCount = 8
    ..spaceTop = 15
    ..axisMinimum = 0;
  chart.legend
    ..form = LegendForm.SQUARE
    ..formSize = 9
    ..textSize = 11
    ..xEntrySpace = 4;
}

/// [_count] bars at x 1 to [_count] with values from 0 to [_range] + 1, as BarChartActivity.setData; the values depend
/// on [seed] only, and every seed has the same shape, so switching between them animates.
BarData barChartData(int seed) {
  final random = math.Random(seed);
  const start = 1;
  final values = [
    for (var i = start; i < start + _count; i++)
      BarEntry(x: i.toDouble(), y: random.nextDouble() * (_range + 1)),
  ];

  final set1 = BarDataSet(values, 'The year 2017')
    ..isDrawIconsEnabled = false
    ..fills = [
      for (final color in Nightfall.palette)
        Fill.ofColors(color, color.withAlpha(90)),
    ]
    ..color = Nightfall.accent
    ..barShadowColor = Nightfall.muted.withAlpha(50)
    ..highlightColor = Nightfall.text
    ..highlightAlpha = 90;

  return BarData([set1])
    ..setValueTextSize(10)
    ..setValueTextColor(Nightfall.muted)
    ..barWidth = 0.9;
}
