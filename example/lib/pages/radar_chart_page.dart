// Other Charts / Radar Chart, modeled on MPChartExample's RadarChartActivity (the five dishes on the x axis, the
// Animate menu item's animateXY with EaseInOutQuad, highlight circles without highlight lines) in the Nightfall look
// of design/DesignCharts.kt (radar: palette colours, faint muted web, hidden y labels, 0 to 100). Differences: the
// values are fixed instead of random, so every run shows the same shape; the y axis has no custom maximum (see
// _setup); the chart can be rotated (Nightfall turns rotation off); the marker is Nightfall's pill instead of
// RadarMarkerView; and the chart sits in a scrolling list between filler cards, to try its gestures inside a ListView.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/nightfall.dart';

/// The x axis labels, one per web spoke, from RadarChartActivity.
const List<String> _dishes = ['Burger', 'Steak', 'Salad', 'Pasta', 'Pizza'];

/// A [RadarChart] with two filled data sets inside a [ListView], with an Animate button.
class RadarChartPage extends StatefulWidget {
  const RadarChartPage({super.key});

  @override
  State<RadarChartPage> createState() => _RadarChartPageState();
}

class _RadarChartPageState extends State<RadarChartPage> {
  final ChartController _controller = ChartController();
  final RadarData _data = _radarData();

  /// The chart the [RadarChart] widget shows, set in [_setup].
  RadarChartView? _chart;

  /// The rotation the status line shows, in whole degrees. Only the status line listens to it, so a drag does not
  /// rebuild the page on every frame.
  final ValueNotifier<int> _shownAngle = ValueNotifier(0);

  @override
  void dispose() {
    _chart?.afterDrawListeners.remove(_onChartDrawn);
    _controller.dispose();
    _shownAngle.dispose();
    super.dispose();
  }

  /// Chart styling, run once before the data is set: Nightfall's radar, which can be rotated.
  void _setup(RadarChartView chart) {
    _chart = chart;
    // Before the status line is built, so nothing listens yet.
    _shownAngle.value = _angleOf(chart);
    chart.afterDrawListeners.add(_onChartDrawn);

    chart.description.isEnabled = false;
    chart.noDataTextColor = Nightfall.muted;

    // A faint web in the muted text colour, so it reads on the dark card.
    chart.webLineWidth = 1;
    chart.webLineWidthInner = 1;
    chart.webColor = Nightfall.muted;
    chart.webColorInner = Nightfall.muted;
    chart.webAlpha = 40;

    chart.xAxis
      ..valueFormatter = IndexAxisValueFormatter(_dishes)
      ..textColor = Nightfall.muted
      ..textSize = 10;

    // Without a custom maximum the web's outer ring is the first label above the highest value. With `spaceTop = 0`
    // and these values (up to 92, interval 20) the rings are 0, 20, ..., 100, so the web already ends on 100 and
    // Nightfall's `axisMaximum = 100` is left out. A custom 100 with four labels would draw rings at 0, 30, 60 and 90
    // only (roundToNextSignificant(25) is 30), with no ring at the outer edge.
    chart.yAxis
      ..isDrawLabelsEnabled = false
      ..axisMinimum = 0
      ..spaceTop = 0
      ..labelCount = 4;

    chart.legend
      ..horizontalAlignment = LegendHorizontalAlignment.CENTER
      ..form = LegendForm.SQUARE
      ..formSize = 10
      ..textColor = Nightfall.text
      ..textSize = 11
      ..xEntrySpace = 16;
  }

  /// Shows the chart's rotation in the status line. The chart calls this while it paints, when no widget may be
  /// marked for a rebuild, so the new angle is set at the end of the frame, and only when the shown angle changed:
  /// the status line then rebuilds on the next frame.
  void _onChartDrawn() {
    final chart = _chart;
    if (chart == null || _angleOf(chart) == _shownAngle.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shownAngle.value = _angleOf(chart);
    });
  }

  /// RadarChartActivity's animateXY: both axes over 1.4 s.
  void _animate() =>
      _controller.animateXY(1400, 1400, easingX: Easing.EaseInOutQuad);

  /// Rotation and selection of the chart.
  String _status() {
    final selected = _controller.selectedHighlight;
    final set = selected == null
        ? null
        : _data.getDataSetByIndex(selected.dataSetIndex);
    return 'rotation ${_shownAngle.value}° · '
        '${selected == null || set == null ? 'tap a point' : '${set.label}, ${_dish(selected.x)} selected'}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Nightfall.stage,
    appBar: AppBar(
      title: const Text('Radar Chart'),
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
          title: 'Dish ratings',
          subtitle: 'Tap a point; drag the web to rotate it',
          children: [
            SizedBox(
              height: 320,
              child: RadarChart(
                data: _data,
                controller: _controller,
                contentDescription: 'Radar chart of two weeks of dish ratings',
                marker: (entry, highlight) => Pill(
                  '${_data.getDataSetByIndex(highlight.dataSetIndex)?.label ?? ''}'
                  ' · ${_dish(highlight.x)} ${entry.y.toStringAsFixed(0)}',
                ),
                setup: _setup,
              ),
            ),
            ListenableBuilder(
              listenable: Listenable.merge([_controller, _shownAngle]),
              // The page's own status line: Nightfall's StatusLine shows the zoom and the visible x range of a
              // bar-line chart, where this one shows the rotation and the selected point.
              builder: (context, _) => Text(
                _status(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Nightfall.muted, fontSize: 13),
              ),
            ),
            ExampleButton('Animate', Nightfall.accent, _animate),
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

/// [chart]'s rotation rounded to whole degrees, 0 until 359.
int _angleOf(RadarChartView chart) => chart.rotationAngle.round() % 360;

/// The x axis label of the spoke at index [x].
String _dish(double x) => _dishes[x.toInt() % _dishes.length];

/// Two filled data sets, one value per dish from 0 to 100, in the Nightfall palette.
RadarData _radarData() {
  RadarDataSet set(List<double> values, String label, Color color) =>
      RadarDataSet([for (final value in values) RadarEntry(value)], label)
        ..color = color
        ..fillColor = color
        ..fillAlpha = 56
        ..isDrawFilledEnabled = true
        ..lineWidth = 2.5
        ..cornerRadius = 10
        ..isDrawValuesEnabled = false
        ..isDrawHighlightCircleEnabled = true
        ..setDrawHighlightIndicators(false);

  return RadarData([
    set([72, 48, 90, 64, 38], 'Last week', Nightfall.violet),
    set([55, 86, 60, 92, 70], 'This week', Nightfall.accent),
  ]);
}
