// Bar Charts / Stacked (MPChartExample's StackedBarActivity): one data set of bars with three stacked values each, in
// the Nightfall style, labelled with only the stack total on top of each bar (StackedValueFormatter(false, '', 0)).
// The data is generated as the Activity's onProgressChanged generates it at the seek bars' initial values, from a
// seeded Random; the star icons are left out, as the Activity does not draw them.
import 'dart:math' as math;

// Material has its own `Easing`; the chart's is MPAndroidChart's Easing.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/nightfall.dart';

/// Number of bars, the Activity's seekBar1 initial value.
const int _count = 12;

/// Upper end of each stack value before the offset, the Activity's seekBar2 initial value plus one.
const double _mul = 100 + 1;

/// Names of the three stack values, bottom to top.
const List<String> _stackLabels = ['Births', 'Divorces', 'Marriages'];

/// A [BarChart] of stacked bars inside a [ListView], with buttons that drive it through a [ChartController] and toggle
/// the bar shadow and the rounded bar corners.
class StackedBarPage extends StatefulWidget {
  const StackedBarPage({super.key});

  @override
  State<StackedBarPage> createState() => _StackedBarPageState();
}

class _StackedBarPageState extends State<StackedBarPage> {
  final ChartController _controller = ChartController();
  int _seed = 0;
  late BarData _data = stackedBarData(_seed);
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
      title: const Text('Stacked'),
      backgroundColor: Nightfall.card,
      foregroundColor: Nightfall.text,
    ),
    body: ListView(
      dragStartBehavior: chartScrollDragStartBehavior,
      padding: const EdgeInsets.all(14),
      children: [
        ChartCard(
          title: 'Statistics Vienna 2014',
          subtitle: 'Drag, pinch or double-tap the chart; tap a stack value',
          children: [
            SizedBox(
              height: 300,
              child: BarChart(
                data: _data,
                controller: _controller,
                animateChanges: true,
                contentDescription:
                    'Stacked bar chart with three values per bar',
                marker: (entry, highlight) =>
                    Pill(_stackText(entry, highlight)),
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
                  () => setState(() => _data = stackedBarData(++_seed)),
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

/// The highlighted stack value with its name, or the bar's total when no single value is highlighted.
String _stackText(Entry entry, Highlight highlight) {
  final stack = entry is BarEntry ? entry.stackValues : null;
  final index = highlight.stackIndex;
  if (stack == null || index < 0 || index >= stack.length) {
    return 'total ${entry.y.toStringAsFixed(0)}';
  }
  return '${_stackLabels[index]} · ${stack[index].toStringAsFixed(0)}';
}

/// The Activity's chart, axis and legend settings on top of the Nightfall styling; the legend wraps, as its four
/// entries do not fit on one line of a phone.
void _setup(BarChartView chart) {
  nightfallSetup(chart);
  chart.maxVisibleCount = 40;
  chart.isDrawValueAboveBarEnabled = false;
  chart.isHighlightFullBarEnabled = false;
  chart.isFitBarsEnabled = true;
  chart.axisLeft.axisMinimum = 0;
  chart.legend
    ..verticalAlignment = LegendVerticalAlignment.BOTTOM
    ..horizontalAlignment = LegendHorizontalAlignment.RIGHT
    ..orientation = LegendOrientation.HORIZONTAL
    ..isDrawInsideEnabled = false
    ..formSize = 8
    ..formToTextSpace = 4
    ..xEntrySpace = 6
    ..isWordWrapEnabled = true;
}

/// [_count] bars from x 0, each a stack of three values from [_mul] / 3 to [_mul] * 4 / 3, as the Activity's
/// onProgressChanged, with the totals in the dark stage colour, as they are drawn inside the top section. The values
/// depend on [seed] only, and every seed has the same shape, so switching between them animates.
BarData stackedBarData(int seed) {
  final random = math.Random(seed);
  final values = <BarEntry>[];
  for (var i = 0; i < _count; i++) {
    final val1 = random.nextDouble() * _mul + _mul / 3;
    final val2 = random.nextDouble() * _mul + _mul / 3;
    final val3 = random.nextDouble() * _mul + _mul / 3;
    values.add(
      BarEntry.stacked(x: i.toDouble(), stackValues: [val1, val2, val3]),
    );
  }

  final set1 = BarDataSet(values, 'Statistics Vienna 2014')
    ..isDrawIconsEnabled = false
    ..setColors(const [Nightfall.accent, Nightfall.coral, Nightfall.amber])
    ..stackLabels = _stackLabels
    ..barShadowColor = Nightfall.muted.withAlpha(50)
    ..highlightColor = Nightfall.text
    ..highlightAlpha = 90;

  return BarData([set1])
    ..setValueFormatter(StackedValueFormatter(false, '', 0))
    ..setValueTextColor(Nightfall.stage);
}
