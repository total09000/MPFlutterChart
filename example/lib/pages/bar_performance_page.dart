// Ported from MPChartExample: BarPerformanceActivity.kt, with res/layout/activity_bar_performance.xml.
//
// Performance / Bar chart: a bar chart of 1k to 500k entries you can pan and zoom by hand while a readout shows what
// each draw of the chart costs, with controls for the entry count, decimation, value labels, the label limit, stacked
// bars, rounded corners and bar shadows. The Activity has no options menu. Not ported:
// - the single-thread executor that builds the data: the data is built in a `Timer(Duration.zero)` on the UI isolate
//   (the example uses no isolates), so the "Building … entries..." text shows first; a build a newer one superseded is
//   dropped, as the Activity's generation check does.
// - `System.nanoTime()` is [BarPerformancePage.nanoTime], so a test can fix the time.
// The Activity's quirk is kept: the Decimation switch starts checked while the chart's decimation stays off (its
// default), because the switch's listener only runs on a change.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/frame_times.dart';
import '../custom/performance_controls.dart';
import '../custom/timed_bar_chart.dart';
import '../notimportant/demo_base.dart';

/// BarPerformanceActivity.
class BarPerformancePage extends StatefulWidget {
  const BarPerformancePage({super.key, this.nanoTime = FrameTimes.systemNanoTime});

  /// `System.nanoTime()`, the clock of the chart's [FrameTimes].
  final int Function() nanoTime;

  @override
  State<BarPerformancePage> createState() => _BarPerformancePageState();
}

class _BarPerformancePageState extends State<BarPerformancePage> with DemoBase {
  static const Duration _readoutInterval = Duration(milliseconds: 200);
  static const double _cornerRadiusDp = 4;
  static const List<Color> _stackColors = [
    Color.fromARGB(255, 28, 88, 154),
    Color.fromARGB(255, 106, 167, 79),
    Color.fromARGB(255, 233, 168, 41),
  ];

  /// `binding.chart`.
  late final TimedBarChart _chart = TimedBarChart(frameTimes: FrameTimes(nanoTime: widget.nanoTime));

  int _build = 0;
  int? _buildingCount;
  BarDataSet? _barSet;

  /// The pending builds, `dataBuilder`'s queue.
  final Set<Timer> _builds = {};

  /// `readoutTick`.
  Timer? _readoutTick;

  /// `binding.readout.text`.
  String _readout = 'Waiting for a frame';

  /// `binding.entryCount`'s checked button: 10k.
  int _entryCount = 10000;

  /// The `isChecked` of the switches, as the layout sets them.
  bool _decimation = true;
  bool _valueLabels = false;
  bool _stacked = false;
  bool _roundedCorners = false;
  bool _barShadows = false;

  /// `binding.labelLimit.progress`.
  int _labelLimit = 100;

  @override
  void initState() {
    super.initState();

    _chart
      ..description.isEnabled = false
      ..legend.isEnabled = false
      ..isDrawGridBackgroundEnabled = false
      ..isPinchZoomEnabled = true
      ..isHighlightPerTapEnabled = false
      ..isHighlightPerDragEnabled = false
      ..isDrawValueAboveBarEnabled = true
      ..maxVisibleCount = _labelLimit
      ..axisRight.isEnabled = false
      ..axisLeft.typeface = tfLight
      ..axisLeft.axisMinimum = 0
      ..xAxis.typeface = tfLight
      ..xAxis.position = XAxisPosition.BOTTOM
      ..xAxis.isDrawGridLinesEnabled = false;

    _rebuild();

    // onResume posts the readout tick, which shows the readout and posts itself again every 200 ms.
    _readoutTick = Timer.periodic(_readoutInterval, (_) => _showReadout());
  }

  @override
  void dispose() {
    _readoutTick?.cancel();
    for (final build in _builds) {
      build.cancel();
    }
    _builds.clear();
    super.dispose();
  }

  void _rebuild() {
    final count = _entryCount;
    final stacked = _stacked;
    _build++;
    final generation = _build;

    _buildingCount = count;
    _barSet = null;
    _chart.noDataText = 'Building ${grouped(count)} entries...';
    _chart.data = null;
    _chart.frameTimes.clear();
    _showReadout();

    late final Timer build;
    build = Timer(Duration.zero, () {
      _builds.remove(build);
      final built = _buildSet(count, stacked);
      if (generation != _build || !mounted) return;
      setState(() => _show(built, stacked));
    });
    _builds.add(build);
  }

  /// `buildSet(count, stacked)`, with `java.util.Random(count)` and the Float arithmetic of Kotlin, so the values
  /// equal Android's.
  static BarDataSet _buildSet(int count, bool stacked) {
    final random = JavaRandom(count);
    final values = <BarEntry>[];
    final step = kotlinFloat(0.01);
    for (var i = 0; i < count; i++) {
      final wave = kotlinFloat(30 + kotlinFloat(kotlinFloat(math.sin(kotlinFloat(i * step))) * 20));
      final height = kotlinFloat(wave + kotlinFloat(random.nextFloat() * 15));
      if (stacked) {
        values.add(
          BarEntry.stacked(
            x: i.toDouble(),
            stackValues: [
              kotlinFloat(height * kotlinFloat(0.5)),
              kotlinFloat(height * kotlinFloat(0.3)),
              kotlinFloat(height * kotlinFloat(0.2)),
            ],
          ),
        );
      } else {
        values.add(BarEntry(x: i.toDouble(), y: height));
      }
    }
    return BarDataSet(values, '${grouped(count)} entries');
  }

  void _show(BarDataSet built, bool stacked) {
    built
      ..isDrawIconsEnabled = false
      ..valueTextSize = 8
      ..barShadowColor = const Color.fromARGB(255, 226, 226, 226)
      ..barCornerRadius = _roundedCorners ? _cornerRadiusDp : 0
      ..isDrawValuesEnabled = _valueLabels
      ..colors = stacked ? _stackColors.toList() : [_stackColors.first];

    _barSet = built;
    _buildingCount = null;
    _chart.data = BarData([built])..barWidth = 0.9;
    _chart.fitScreen();
    _chart.frameTimes.clear();
  }

  /// `showReadout()`: rebuilds the page only when the text changed.
  void _showReadout() {
    final text = _readoutText();
    if (text == _readout || !mounted) return;
    setState(() => _readout = text);
  }

  String _readoutText() {
    final building = _buildingCount;
    if (building != null) return 'Building ${grouped(building)} entries...';

    final frameTimes = _chart.frameTimes;
    final recent = frameTimes.recentMillis;
    final worst = frameTimes.worstMillisLastSecond;
    final total = _barSet?.entryCount ?? 0;

    return [
      if (recent > 0)
        '${recent.toStringAsFixed(1)} ms per frame, ${(1000 / recent).toStringAsFixed(0)} fps'
      else
        'Waiting for a frame',
      if (worst > 0) 'worst frame in the last second ${worst.toStringAsFixed(1)} ms' else 'no frame in the last second',
      '${grouped(_visibleEntries())} of ${grouped(total)} entries on screen',
    ].join('\n');
  }

  int _visibleEntries() {
    final set = _barSet;
    if (set == null) return 0;
    if (set.entryCount == 0) return 0;

    final from = math.max(0, set.getEntryIndex(_chart.lowestVisibleX, double.nan, Rounding.DOWN));
    final to = math.max(0, set.getEntryIndex(_chart.highestVisibleX, double.nan, Rounding.UP));
    return math.max(0, to - from) + 1;
  }

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Bar chart',
    body: Column(
      children: [
        Expanded(
          flex: 3,
          child: ChartHostWidget<BarChartView, BarData>(chart: _chart, data: _chart.data),
        ),
        PerformanceReadout(_readout),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Entries', style: TextStyle(fontSize: 13)),
                EntryCountGroup(
                  count: _entryCount,
                  onChanged: (count) {
                    setState(() => _entryCount = count);
                    _rebuild();
                  },
                ),
                PerformanceSwitch('Decimation', _decimation, (on) {
                  setState(() => _decimation = on);
                  _chart.isDecimationEnabled = on;
                  _chart.invalidate();
                }),
                PerformanceSwitch('Value labels', _valueLabels, (on) {
                  setState(() => _valueLabels = on);
                  _barSet?.isDrawValuesEnabled = on;
                  _chart.invalidate();
                }),
                LabelLimit(
                  progress: _labelLimit,
                  onProgressChanged: (progress) {
                    setState(() => _labelLimit = progress);
                    _chart.maxVisibleCount = progress;
                    _chart.invalidate();
                  },
                ),
                PerformanceSwitch('Stacked bars', _stacked, (on) {
                  setState(() => _stacked = on);
                  _rebuild();
                }),
                PerformanceSwitch('Rounded bar corners', _roundedCorners, (on) {
                  setState(() => _roundedCorners = on);
                  _barSet?.barCornerRadius = on ? _cornerRadiusDp : 0;
                  _chart.invalidate();
                }),
                PerformanceSwitch('Bar shadows', _barShadows, (on) {
                  setState(() => _barShadows = on);
                  _chart.isDrawBarShadowEnabled = on;
                  _chart.invalidate();
                }),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
