// Other Charts / Bubble Chart (MPChartExample's BubbleChartActivity): three data sets of bubbles of very different
// sizes, in the Nightfall style. The data is generated as the Activity's onProgressChanged generates it at the seek
// bars' initial values, from a seeded Random; the star icons are left out, as the Activity does not draw them. Two
// neighbouring bubbles of the first set are given the sizes 0 and 4, so a device check can highlight a bubble of size
// 0 next to a small one.
import 'dart:math' as math;

// Material has its own `Easing`; the chart's is MPAndroidChart's Easing.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/nightfall.dart';

/// Entries per data set, the Activity's seekBar1 initial value.
const int _count = 10;

/// Upper end of the values and sizes, the Activity's seekBar2 initial value.
const double _range = 50;

/// x of the size-0 bubble in the first data set; the bubble at the next x has size 4 and the same y.
const int bubbleChartZeroSizeX = 3;

/// A [BubbleChart] of three data sets inside a [ListView], with buttons that drive it through a [ChartController],
/// toggle the size normalization and highlight the bubble of size 0.
class BubbleChartPage extends StatefulWidget {
  const BubbleChartPage({super.key});

  @override
  State<BubbleChartPage> createState() => _BubbleChartPageState();
}

class _BubbleChartPageState extends State<BubbleChartPage> {
  final ChartController _controller = ChartController();
  int _seed = 0;
  late BubbleData _data = bubbleChartData(_seed);
  bool _normalizeSize = true;

  /// The chart, kept from setup for [_highlightZeroSize].
  BubbleChartView? _chart;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Highlights the bubble of size 0 as a tap on it would. ChartController.highlight cannot: it highlights with a y of
  /// NaN, and BubbleChartRenderer.drawHighlighted, as Kotlin's, skips a highlight whose y is not the entry's, so
  /// neither the highlight ring nor the marker would be drawn.
  void _highlightZeroSize() {
    final entry = _data.dataSets.first.getEntryForIndex(bubbleChartZeroSizeX);
    _chart?.highlightValue(entry.x, 0, y: entry.y);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Bubble Chart'),
      backgroundColor: Nightfall.card,
      foregroundColor: Nightfall.text,
    ),
    body: ListView(
      dragStartBehavior: chartScrollDragStartBehavior,
      padding: const EdgeInsets.all(14),
      children: [
        ChartCard(
          title: 'Three bubble series',
          subtitle: 'Drag, pinch or double-tap the chart; tap a bubble',
          children: [
            SizedBox(
              height: 300,
              child: BubbleChart(
                data: _data,
                controller: _controller,
                animateChanges: true,
                contentDescription: 'Bubble chart with three data sets',
                marker: (entry, highlight) => Pill(
                  '${_data.getDataSetByIndex(highlight.dataSetIndex)?.label ?? ''}'
                  ' · x ${entry.x.toStringAsFixed(0)} · ${entry.y.toStringAsFixed(1)}'
                  ' · size ${entry is BubbleEntry ? entry.size.toStringAsFixed(1) : '-'}',
                ),
                setup: (chart) {
                  _chart = chart;
                  _setup(chart);
                },
                update: (chart) {
                  for (final set in _data.dataSets.cast<BubbleDataSet>()) {
                    set.isNormalizeSizeEnabled = _normalizeSize;
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
                  () => setState(() => _data = bubbleChartData(++_seed)),
                ),
                ExampleButton(
                  'toggle normalize',
                  Nightfall.green,
                  () => setState(() => _normalizeSize = !_normalizeSize),
                ),
                ExampleButton(
                  'highlight size 0',
                  Nightfall.accent,
                  _highlightZeroSize,
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

/// The Activity's chart, axis and legend settings on top of the Nightfall styling, with half an x unit of space before
/// the first and after the last bubble, so a normalized bubble, at most one x unit wide, is not cut off at the edge.
void _setup(BubbleChartView chart) {
  nightfallSetup(chart);
  chart.maxVisibleCount = 200;
  chart.legend
    ..verticalAlignment = LegendVerticalAlignment.TOP
    ..horizontalAlignment = LegendHorizontalAlignment.RIGHT
    ..orientation = LegendOrientation.VERTICAL
    ..isDrawInsideEnabled = false;
  chart.xAxis
    ..spaceMin = 0.5
    ..spaceMax = 0.5;
  chart.axisLeft
    ..spaceTop = 30
    ..spaceBottom = 30
    ..isDrawZeroLineEnabled = false;
}

/// Three data sets of [_count] bubbles from x 0, with values and sizes from 0 to [_range], as the Activity's
/// onProgressChanged. In the first set the bubble at [bubbleChartZeroSizeX] has size 0 and the next one size 4, at the
/// same y. The values depend on [seed] only, and every seed has the same shape, so switching between them animates.
BubbleData bubbleChartData(int seed) {
  final random = math.Random(seed);
  final values1 = <BubbleEntry>[];
  final values2 = <BubbleEntry>[];
  final values3 = <BubbleEntry>[];
  BubbleEntry bubble(int i) => BubbleEntry(
    x: i.toDouble(),
    y: random.nextDouble() * _range,
    size: random.nextDouble() * _range,
  );
  for (var i = 0; i < _count; i++) {
    values1.add(bubble(i));
    values2.add(bubble(i));
    values3.add(bubble(i));
  }
  values1[bubbleChartZeroSizeX].size = 0;
  values1[bubbleChartZeroSizeX + 1]
    ..size = 4
    ..y = values1[bubbleChartZeroSizeX].y;

  BubbleDataSet series(List<BubbleEntry> values, String label, Color color) =>
      BubbleDataSet(values, label)
        ..isDrawIconsEnabled = false
        ..setColor(color, 130);

  return BubbleData([
      series(values1, 'DS 1', Nightfall.accent),
      series(values2, 'DS 2', Nightfall.coral),
      series(values3, 'DS 3', Nightfall.amber),
    ])
    ..setDrawValues(false)
    ..setValueTextSize(8)
    ..setValueTextColor(Nightfall.text)
    ..setHighlightCircleWidth(1.5);
}
