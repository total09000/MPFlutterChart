// Line Charts / Basic (MPChartExample's LineChartActivity1): a LineChart in a ListView with three
// data sets in the Nightfall style. The chart keeps drag, zoom and double-tap zoom enabled so the page can be used to
// try the gestures inside a scrolling list.
import 'dart:math' as math;

// Material has its own `Easing`; the chart's is MPAndroidChart's Easing.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/nightfall.dart';

/// Entries per data set.
const int _pointCount = 24;

/// A [LineChart] with three data sets inside a [ListView], with buttons that drive it through a [ChartController].
class LineChartPage extends StatefulWidget {
  const LineChartPage({super.key});

  @override
  State<LineChartPage> createState() => _LineChartPageState();
}

class _LineChartPageState extends State<LineChartPage> {
  final ChartController _controller = ChartController();
  int _seed = 0;
  late LineData _data = _lineData(_seed);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _switchData() => setState(() => _data = _lineData(++_seed));

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
        const Filler('Scroll area above the chart', height: 160),
        const SizedBox(height: 14),
        ChartCard(
          title: 'Three series',
          subtitle: 'Drag, pinch or double-tap the chart; tap a point',
          children: [
            SizedBox(
              height: 300,
              child: LineChart(
                data: _data,
                controller: _controller,
                animateChanges: true,
                contentDescription: 'Line chart with three series',
                marker: (entry, highlight) => Pill(
                  '${_data.getDataSetByIndex(highlight.dataSetIndex)?.label ?? ''}'
                  ' · x ${entry.x.toStringAsFixed(0)} · ${entry.y.toStringAsFixed(1)}',
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
                  'animateX',
                  Nightfall.accent,
                  () => _controller.animateX(1500),
                ),
                ExampleButton('zoomIn', Nightfall.coral, _controller.zoomIn),
                ExampleButton(
                  'fitScreen',
                  Nightfall.amber,
                  _controller.fitScreen,
                ),
                ExampleButton('switch data', Nightfall.violet, _switchData),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Filler('Scroll area below the chart', height: 320),
        const SizedBox(height: 14),
        const Filler('End of the list', height: 320),
      ],
    ),
  );
}

/// The shared Nightfall styling with line-shaped legend forms.
void _setup(LineChartView chart) {
  nightfallSetup(chart);
  chart.legend.form = LegendForm.LINE;
}

/// Three series of [_pointCount] entries with values that depend on [seed] only; every seed has the same shape, so
/// switching between them animates.
LineData _lineData(int seed) {
  final random = math.Random(seed);
  List<Entry> walk(double start, double step) {
    var y = start;
    return [
      for (var x = 0; x < _pointCount; x++)
        Entry(
          x: x.toDouble(),
          y: y = (y + (random.nextDouble() - 0.5) * step).clamp(5, 95),
        ),
    ];
  }

  final revenue = LineDataSet(walk(60, 18), 'Revenue')
    ..mode = LineDataSetMode.CUBIC_BEZIER
    ..cubicIntensity = 0.18
    ..color = Nightfall.accent
    ..lineWidth = 3
    ..isDrawCirclesEnabled = false
    ..isDrawValuesEnabled = false
    ..isDrawFilledEnabled = true
    ..fillColor = Nightfall.accent
    ..fillAlpha = 60
    ..highlightColor = Nightfall.accent
    ..highlightLineWidth = 1
    ..isHorizontalHighlightIndicatorEnabled = false
    ..isDrawHighlightCircleEnabled = true
    ..circleHoleColor = Nightfall.card
    ..enableDashedHighlightLine(8, 8, 0);

  final orders = LineDataSet(walk(40, 22), 'Orders')
    ..mode = LineDataSetMode.LINEAR
    ..color = Nightfall.coral
    ..lineWidth = 2
    ..circleColor = Nightfall.coral
    ..circleRadius = 3.5
    ..circleHoleRadius = 1.8
    ..circleHoleColor = Nightfall.card
    ..isDrawValuesEnabled = false
    ..highlightColor = Nightfall.coral
    ..highlightLineWidth = 1;

  final visits = LineDataSet(walk(25, 14), 'Visits')
    ..mode = LineDataSetMode.HORIZONTAL_BEZIER
    ..color = Nightfall.violet
    ..lineWidth = 2
    ..isDrawCirclesEnabled = false
    ..isDrawValuesEnabled = false
    ..highlightColor = Nightfall.violet
    ..highlightLineWidth = 1;

  return LineData([revenue, orders, visits]);
}
