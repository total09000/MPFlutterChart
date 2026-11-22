// Pie Charts / Basic, modeled on MPChartExample's PieChartActivity and HalfPieChartActivity, in the Nightfall donut
// look of design/DesignCharts.kt (pie) and design/NightfallStyle.kt (nightfallDonut, nightfallSlices). Differences:
// the activities' option menu is a Spin button and two switches; the donut can be rotated (Nightfall turns rotation
// off) and draws its percentages (Nightfall hides them), so it keeps PieChartActivity's wider ring (hole radius 58
// instead of Nightfall's 72) and whole percentages; the legend sits below the pie instead of on its right, which leaves
// room for values outside the slices (PiePolylineChartActivity) on both sides; the center text is plain text, without
// the spans Kotlin's SpannableString applies; the half pie stays inside its card instead of being moved half off
// screen (HalfPieChartActivity.moveOffScreen), so the lower half of the chart area stays empty; in half-pie mode Spin
// does nothing and switching it on stops a fling that is still decelerating, so the half pie stays on its 9 to 3
// o'clock arc (the touch listener's computeScroll turns the pie with rotation disabled too, as in Kotlin); a selected
// slice grows by 6 dp (PieChartActivity.kt:114 uses 5, Nightfall keeps the default 9); the legend entries are 16 dp
// apart, as in Nightfall's radar legend (DesignCharts.kt:267; PieChartActivity.kt:83 uses 7); and the chart sits in a
// scrolling list between filler cards, to try its gestures inside a ListView.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/nightfall.dart';

/// Track of a switch that is off: a slate that stands out from the card, where the page background would not.
const Color _inactiveTrack = Color(0xFF334155);

/// Share of sessions per platform in percent, from Nightfall's pie card.
const List<(String, double)> _platforms = [
  ('Mobile', 44),
  ('Web', 28),
  ('Desktop', 18),
  ('Other', 10),
];

/// A donut [PieChart] inside a [ListView], with a Spin button and switches for a half pie and for values outside the
/// slices.
class PieChartPage extends StatefulWidget {
  const PieChartPage({super.key});

  @override
  State<PieChartPage> createState() => _PieChartPageState();
}

class _PieChartPageState extends State<PieChartPage> {
  final ChartController _controller = ChartController();
  final PieData _data = _pieData();

  /// The chart the [PieChart] widget shows, set in [_setup].
  PieChartView? _chart;

  /// The rotation the status line shows, in whole degrees. Only the status line listens to it, so a spin or a drag
  /// does not rebuild the page on every frame.
  final ValueNotifier<int> _shownAngle = ValueNotifier(0);

  bool _halfPie = false;
  bool _valuesOutside = false;

  @override
  void dispose() {
    _chart?.afterDrawListeners.remove(_onChartDrawn);
    _controller.dispose();
    _shownAngle.dispose();
    super.dispose();
  }

  /// Chart styling, run once before the data is set: Nightfall's donut, which can be rotated and draws its values.
  void _setup(PieChartView chart) {
    _chart = chart;
    // Before the status line is built, so nothing listens yet.
    _shownAngle.value = _angleOf(chart);
    chart.afterDrawListeners.add(_onChartDrawn);

    chart.description.isEnabled = false;
    chart.noDataTextColor = Nightfall.muted;
    chart.dragDecelerationFrictionCoef = 0.95;

    chart.isUsePercentValuesEnabled = true;
    chart.isDrawEntryLabelsEnabled = false;
    // PieChartActivity's hole: Nightfall's 72 leaves a ring too thin for the values drawn in it.
    chart.holeRadius = 58;
    chart.transparentCircleRadius = 0;
    chart.holeColor = Nightfall.card;
    chart.isDrawRoundedSlicesEnabled = true;
    chart.centerText = '44%\nMobile';
    chart.centerTextColor = Nightfall.text;
    chart.centerTextSize = 11;

    // Below the pie rather than Nightfall's right, so values outside the slices have room on both sides.
    chart.legend
      ..horizontalAlignment = LegendHorizontalAlignment.CENTER
      ..form = LegendForm.SQUARE
      ..formSize = 10
      ..textColor = Nightfall.text
      ..textSize = 12
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

  /// One full turn from the current angle, as PieChartActivity's "Spin" menu item. Does nothing on the half pie,
  /// which a spin would turn away from its arc, and whose rotation is disabled.
  void _spin() {
    final chart = _chart;
    if (chart == null || _halfPie) return;
    final angle = chart.rotationAngle;
    chart.spin(1200, angle, angle + 360, easing: Easing.EaseInOutCubic);
  }

  /// HalfPieChartActivity's setup when [on], the full donut starting at the top otherwise. A spin in progress ends
  /// first and a fling stops decelerating, so neither turns the half pie away: the touch listener keeps turning a
  /// fling with rotation disabled, as Kotlin's computeScroll does.
  void _setHalfPie(bool on) {
    final chart = _chart;
    if (chart == null) return;
    setState(() => _halfPie = on);
    chart.stopAnimations();
    final listener = chart.chartTouchListener;
    if (listener is PieRadarChartTouchListener) listener.stopDeceleration();
    chart
      ..maxAngle = on ? 180 : 360
      ..rotationAngle = on ? 180 : 270
      ..isRotationEnabled = !on
      ..setCenterTextOffset(0, on ? -20 : 0)
      // The slice angles follow maxAngle only when they are computed again.
      ..notifyDataSetChanged();
  }

  /// Draws the percentages outside the slices, joined to them by a line, when [outside] (as PiePolylineChartActivity),
  /// in the slices otherwise.
  void _setValuesOutside(bool outside) {
    final chart = _chart;
    if (chart == null) return;
    setState(() => _valuesOutside = outside);
    final position = outside
        ? ValuePosition.OUTSIDE_SLICE
        : ValuePosition.INSIDE_SLICE;
    (_data.dataSet! as PieDataSet)
      ..xValuePosition = position
      ..yValuePosition = position;
    // Dark text on the bright slices, light text on the dark card.
    _data.setValueTextColor(outside ? Nightfall.text : Nightfall.stage);
    // Room for the values around the pie, in dp. The pie's diameter subtracts the extra offsets a second time, as
    // Kotlin's getDiameter does, so they shrink it by twice their size.
    final side = outside ? 40.0 : 0.0;
    final edge = outside ? 16.0 : 0.0;
    chart
      ..setExtraOffsets(side, edge, side, edge)
      ..notifyDataSetChanged();
  }

  /// Rotation and selection of the chart.
  String _status() {
    final selected = _controller.selectedEntry;
    return 'rotation ${_shownAngle.value}° · '
        '${selected is PieEntry ? '${selected.label} selected' : 'tap a slice'}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Nightfall.stage,
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
          title: 'Sessions by platform',
          subtitle: 'Tap a slice; drag the ring to rotate it',
          children: [
            SizedBox(
              height: 320,
              child: PieChart(
                data: _data,
                controller: _controller,
                contentDescription: 'Donut chart of sessions by platform',
                marker: (entry, highlight) => Pill(
                  '${(entry as PieEntry).label} · ${entry.y.toStringAsFixed(0)}%',
                ),
                setup: _setup,
              ),
            ),
            ListenableBuilder(
              listenable: Listenable.merge([_controller, _shownAngle]),
              // The page's own status line: Nightfall's StatusLine shows the zoom and the visible x range of a
              // bar-line chart, where this one shows the rotation and the selected slice.
              builder: (context, _) => Text(
                _status(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Nightfall.muted, fontSize: 13),
              ),
            ),
            ExampleButton('Spin', Nightfall.accent, _spin),
            _Toggle('Half pie', _halfPie, _setHalfPie),
            _Toggle('Values outside', _valuesOutside, _setValuesOutside),
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
int _angleOf(PieChartView chart) => chart.rotationAngle.round() % 360;

/// The donut's data: one slice per platform in the Nightfall palette, percentages drawn with a value line for when
/// they are outside the slices.
PieData _pieData() {
  final slices =
      PieDataSet([
          for (final (label, share) in _platforms)
            PieEntry(share, label: label),
        ], '')
        ..sliceSpace = 3
        ..selectionShift = 6
        ..colors = [
          Nightfall.accent,
          Nightfall.coral,
          Nightfall.amber,
          Nightfall.violet,
        ]
        ..valueLineColor = Nightfall.muted
        ..valueLinePart1OffsetPercentage = 80
        ..valueLinePart1Length = 0.2
        ..valueLinePart2Length = 0.4;
  return PieData(slices)
    // Whole percentages, "44 %", so they fit in the ring.
    ..setValueFormatter(PercentFormatter(DecimalFormat('##0')))
    ..setValueTextSize(10)
    ..setValueTextColor(Nightfall.stage);
}

/// A switch with a [label], for one chart option.
class _Toggle extends StatelessWidget {
  const _Toggle(this.label, this.value, this.onChanged);

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(
      label,
      style: const TextStyle(color: Nightfall.text, fontSize: 14),
    ),
    value: value,
    onChanged: onChanged,
    activeThumbColor: Nightfall.stage,
    activeTrackColor: Nightfall.accent,
    inactiveThumbColor: Nightfall.muted,
    inactiveTrackColor: _inactiveTrack,
  );
}
