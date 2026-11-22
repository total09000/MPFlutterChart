// Other Charts / Scatter Plot (MPChartExample's ScatterChartActivity): one data set per ScatterShape, all seven on
// screen at once, in the Nightfall style; the CIRCLE set has a hole, as the Activity's second set. The data is
// generated as the Activity's onProgressChanged generates it, from a seeded Random, with seven sets of 15 entries
// instead of three of 45 (about the same number of points) and the sets' x offsets spread over one x unit as the
// Activity's 0, 0.33 and 0.66 are; shape size and hole are enlarged so each shape can be told apart, and the value
// labels are off.
import 'dart:math' as math;

// Material has its own `Easing`; the chart's is MPAndroidChart's Easing.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/nightfall.dart';

/// Entries per data set.
const int _count = 15;

/// Upper end of the values before the offset, the Activity's seekBar2 initial value.
const double _range = 100;

/// A [ScatterChart] with one data set per [ScatterShape] inside a [ListView], with buttons that drive it through a
/// [ChartController].
class ScatterChartPage extends StatefulWidget {
  const ScatterChartPage({super.key});

  @override
  State<ScatterChartPage> createState() => _ScatterChartPageState();
}

class _ScatterChartPageState extends State<ScatterChartPage> {
  final ChartController _controller = ChartController();
  int _seed = 0;
  late ScatterData _data = scatterChartData(_seed);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Scatter Plot'),
      backgroundColor: Nightfall.card,
      foregroundColor: Nightfall.text,
    ),
    body: ListView(
      dragStartBehavior: chartScrollDragStartBehavior,
      padding: const EdgeInsets.all(14),
      children: [
        ChartCard(
          title: 'Seven scatter shapes',
          subtitle: 'Drag, pinch or double-tap the chart; tap a point',
          children: [
            SizedBox(
              height: 300,
              child: ScatterChart(
                data: _data,
                controller: _controller,
                animateChanges: true,
                contentDescription: 'Scatter chart with one data set per shape',
                marker: (entry, highlight) => Pill(
                  '${_data.getDataSetByIndex(highlight.dataSetIndex)?.label ?? ''}'
                  ' · x ${entry.x.toStringAsFixed(2)} · ${entry.y.toStringAsFixed(1)}',
                ),
                setup: _setup,
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
                  () => setState(() => _data = scatterChartData(++_seed)),
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

/// The Activity's chart and axis settings on top of the Nightfall styling; the legend of seven entries wraps below
/// the chart instead of standing in a column on its right.
void _setup(ScatterChartView chart) {
  nightfallSetup(chart);
  chart.maxHighlightDistance = 50;
  chart.maxVisibleCount = 200;
  chart.axisLeft.axisMinimum = 0;
  chart.legend.isWordWrapEnabled = true;
}

/// One data set per [ScatterShape], labelled with the shape's name, of [_count] entries with values from 3 to
/// [_range] + 3, as the Activity's onProgressChanged. Set k is offset by k / 7 on the x axis. The values depend on
/// [seed] only, and every seed has the same shape, so switching between them animates.
ScatterData scatterChartData(int seed) {
  final random = math.Random(seed);
  const shapes = ScatterShape.values;
  final sets = [
    for (var k = 0; k < shapes.length; k++)
      ScatterDataSet([
          for (var i = 0; i < _count; i++)
            Entry(
              x: i + k / shapes.length,
              y: random.nextDouble() * _range + 3,
            ),
        ], shapes[k].toString())
        ..setScatterShape(shapes[k])
        ..color = Nightfall.palette[k % Nightfall.palette.length]
        ..scatterShapeSize = 10
        ..isDrawValuesEnabled = false
        ..highlightColor = Nightfall.text
        ..highlightLineWidth = 1,
  ];
  // The Activity's second set: a circle with a hole.
  sets[ScatterShape.CIRCLE.index]
    ..scatterShapeHoleRadius = 3
    ..scatterShapeHoleColor = Nightfall.card;
  return ScatterData(sets);
}
