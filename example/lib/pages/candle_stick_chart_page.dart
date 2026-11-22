// Other Charts / Candlestick (MPChartExample's CandleStickChartActivity): thirty candles in the Nightfall style, rising
// candles hollow, falling ones filled and one flat candle in the neutral colour. The data is generated as the
// Activity's onProgressChanged generates it, from a seeded Random, for 30 candles instead of the seek bar's 40; one
// candle is made flat, since the Activity's even/odd scheme never produces an open equal to the close. The shadows are
// in the muted colour instead of dark grey, which would not show on the card, and the value labels are off.
import 'dart:math' as math;

// Material has its own `Easing`; the chart's is MPAndroidChart's Easing.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/nightfall.dart';

/// Number of candles.
const int _count = 30;

/// Base of the values, the Activity's seekBar2 initial value plus one.
const double _multi = 100 + 1;

/// Index of the candle whose close is set to its open, so it is drawn in the neutral colour.
const int _neutralIndex = 5;

/// A [CandleStickChart] inside a [ListView], with buttons that drive it through a [ChartController] and toggle the
/// candle bodies and the shadow colour.
class CandleStickChartPage extends StatefulWidget {
  const CandleStickChartPage({super.key});

  @override
  State<CandleStickChartPage> createState() => _CandleStickChartPageState();
}

class _CandleStickChartPageState extends State<CandleStickChartPage> {
  final ChartController _controller = ChartController();
  int _seed = 0;
  late CandleData _data = candleStickChartData(_seed);
  bool _showCandleBar = true;
  bool _shadowColorSameAsCandle = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Candlestick'),
      backgroundColor: Nightfall.card,
      foregroundColor: Nightfall.text,
    ),
    body: ListView(
      dragStartBehavior: chartScrollDragStartBehavior,
      padding: const EdgeInsets.all(14),
      children: [
        ChartCard(
          title: 'Data Set',
          subtitle: 'Drag, pinch or double-tap the chart; tap a candle',
          children: [
            SizedBox(
              height: 300,
              child: CandleStickChart(
                data: _data,
                controller: _controller,
                animateChanges: true,
                contentDescription: 'Candle stick chart with thirty candles',
                marker: (entry, highlight) => Pill(_candleText(entry)),
                setup: _setup,
                update: (chart) {
                  for (final set in _data.dataSets.cast<CandleDataSet>()) {
                    set
                      ..showCandleBar = _showCandleBar
                      ..shadowColorSameAsCandle = _shadowColorSameAsCandle;
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
                  () => setState(() => _data = candleStickChartData(++_seed)),
                ),
                ExampleButton(
                  'toggle candle bar',
                  Nightfall.green,
                  () => setState(() => _showCandleBar = !_showCandleBar),
                ),
                ExampleButton(
                  'toggle shadow colour',
                  Nightfall.accent,
                  () => setState(
                    () => _shadowColorSameAsCandle = !_shadowColorSameAsCandle,
                  ),
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

/// Open, high, low and close of the highlighted candle.
String _candleText(Entry entry) {
  if (entry is! CandleEntry) return entry.y.toStringAsFixed(1);
  return 'O ${entry.open.toStringAsFixed(1)} · H ${entry.high.toStringAsFixed(1)}'
      ' · L ${entry.low.toStringAsFixed(1)} · C ${entry.close.toStringAsFixed(1)}';
}

/// The Activity's chart and axis settings on top of the Nightfall styling.
void _setup(CandleStickChartView chart) {
  nightfallSetup(chart);
  chart.maxVisibleCount = 60;
  chart.axisLeft.labelCount = 7;
}

/// [_count] candles from x 0, as the Activity's onProgressChanged: even candles fall from open to close, odd ones rise,
/// and the candle at [_neutralIndex] closes at its open. The values depend on [seed] only, and every seed has the same
/// shape, so switching between them animates.
CandleData candleStickChartData(int seed) {
  final random = math.Random(seed);
  final values = <CandleEntry>[];
  for (var i = 0; i < _count; i++) {
    final value = random.nextDouble() * 40 + _multi;

    final high = random.nextDouble() * 9 + 8;
    final low = random.nextDouble() * 9 + 8;

    final open = random.nextDouble() * 6 + 1;
    final close = random.nextDouble() * 6 + 1;

    final even = i % 2 == 0;
    final openValue = even ? value + open : value - open;
    final closeValue = even ? value - close : value + close;

    values.add(
      CandleEntry(
        x: i.toDouble(),
        high: value + high,
        low: value - low,
        open: openValue,
        close: i == _neutralIndex ? openValue : closeValue,
      ),
    );
  }

  final set1 = CandleDataSet(values, 'Data Set')
    ..isDrawIconsEnabled = false
    ..axisDependency = AxisDependency.LEFT
    ..shadowColor = Nightfall.muted
    ..shadowWidth = 1
    ..decreasingColor = Nightfall.coral
    ..decreasingPaintStyle = PaintStyle.FILL
    ..increasingColor = Nightfall.green
    ..increasingPaintStyle = PaintStyle.STROKE
    ..neutralColor = Nightfall.amber
    ..isDrawValuesEnabled = false
    ..highlightColor = Nightfall.text
    ..highlightLineWidth = 1;

  return CandleData([set1]);
}
