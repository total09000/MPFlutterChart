// Bar Charts / Horizontal (MPChartExample's HorizontalBarChartActivity): one data set drawn as horizontal bars, in the
// Nightfall style: the x axis runs down the left side and the y axis along the top. The data is generated as the
// Activity's setData generates it at the seek bars' initial values, from a seeded Random, but shifted down by a third
// of the range so some values are negative; for that the Activity's axis minimum of 0 is left out.
import 'dart:math' as math;

// Material has its own `Easing`; the chart's is MPAndroidChart's Easing.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/nightfall.dart';

/// Number of bars, the Activity's seekBar1 initial value.
const int _count = 12;

/// Width of the value range, the Activity's seekBar2 initial value.
const double _range = 50;

/// x distance between two bars.
const double _spaceForBar = 10;

/// A [HorizontalBarChart] of one data set with negative values inside a [ListView], with buttons that drive it
/// through a [ChartController] and toggle the bar shadow, the rounded bar corners and where the value labels sit.
class HorizontalBarChartPage extends StatefulWidget {
  const HorizontalBarChartPage({super.key});

  @override
  State<HorizontalBarChartPage> createState() => _HorizontalBarChartPageState();
}

class _HorizontalBarChartPageState extends State<HorizontalBarChartPage> {
  final ChartController _controller = ChartController();
  int _seed = 0;
  late BarData _data = horizontalBarChartData(_seed);
  bool _shadow = false;
  bool _rounded = true;
  bool _valueAboveBar = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Horizontal'),
      backgroundColor: Nightfall.card,
      foregroundColor: Nightfall.text,
    ),
    body: ListView(
      dragStartBehavior: chartScrollDragStartBehavior,
      padding: const EdgeInsets.all(14),
      children: [
        ChartCard(
          title: 'DataSet 1',
          subtitle: 'Drag, pinch or double-tap the chart; tap a bar',
          children: [
            SizedBox(
              height: 300,
              child: HorizontalBarChart(
                data: _data,
                controller: _controller,
                animateChanges: true,
                contentDescription: 'Horizontal bar chart with one data set',
                marker: (entry, highlight) => Pill(
                  'x ${entry.x.toStringAsFixed(0)} · ${entry.y.toStringAsFixed(1)}',
                ),
                setup: _setup,
                update: (chart) {
                  chart.isDrawBarShadowEnabled = _shadow;
                  chart.isDrawValueAboveBarEnabled = _valueAboveBar;
                  // Dark labels inside the bars, the light muted colour above them on the card.
                  _data.setValueTextColor(
                    _valueAboveBar ? Nightfall.muted : Nightfall.stage,
                  );
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
                  () => setState(() => _data = horizontalBarChartData(++_seed)),
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
                ExampleButton(
                  'toggle above bar',
                  Nightfall.coral,
                  () => setState(() => _valueAboveBar = !_valueAboveBar),
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

/// The Activity's chart, axis and legend settings on top of the Nightfall styling.
void _setup(HorizontalBarChartView chart) {
  nightfallSetup(chart);
  chart.maxVisibleCount = 60;
  chart.isFitBarsEnabled = true;
  chart.xAxis.granularity = 10;
  chart.legend
    ..verticalAlignment = LegendVerticalAlignment.BOTTOM
    ..horizontalAlignment = LegendHorizontalAlignment.LEFT
    ..orientation = LegendOrientation.HORIZONTAL
    ..isDrawInsideEnabled = false
    ..formSize = 8
    ..xEntrySpace = 4;
}

/// [_count] bars [_spaceForBar] apart from x 0, with values from -[_range] / 3 to [_range] * 2 / 3: the Activity's
/// values from 0 to [_range], shifted down. The values depend on [seed] only, and every seed has the same shape, so
/// switching between them animates.
BarData horizontalBarChartData(int seed) {
  final random = math.Random(seed);
  final values = [
    for (var i = 0; i < _count; i++)
      BarEntry(
        x: i * _spaceForBar,
        y: random.nextDouble() * _range - _range / 3,
      ),
  ];

  final set1 = BarDataSet(values, 'DataSet 1')
    ..isDrawIconsEnabled = false
    ..setGradientColor(Nightfall.accent, Nightfall.accent.withAlpha(90))
    ..color = Nightfall.accent
    ..barShadowColor = Nightfall.muted.withAlpha(50)
    ..highlightColor = Nightfall.text
    ..highlightAlpha = 90;

  return BarData([set1])
    ..setValueTextSize(10)
    ..setValueTextColor(Nightfall.muted)
    ..barWidth = 9;
}
