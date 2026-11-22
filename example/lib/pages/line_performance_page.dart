// Ported from MPChartExample: LinePerformanceActivity.kt, with res/layout/activity_line_performance.xml.
//
// Performance / Line chart: a line chart of 1k to 500k entries you can pan and zoom by hand while a readout shows what
// each draw of the chart costs, with controls for the entry count, the line shape, decimation, value labels, the label
// limit, circles, the fill and a colour per segment. The Activity has no options menu. Not ported:
// - the single-thread executor that builds the data: the data is built in a `Timer(Duration.zero)` on the UI isolate
//   (the example uses no isolates), so the "Building … entries..." text shows first; a build a newer one superseded is
//   dropped, as the Activity's generation check does.
// - `System.nanoTime()` is [LinePerformancePage.nanoTime], so a test can fix the time.
// The Activity's quirk is kept: the Decimation switch starts checked while the chart's decimation stays off (its
// default), because the switch's listener only runs on a change.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/frame_times.dart';
import '../custom/performance_controls.dart';
import '../custom/timed_line_chart.dart';
import '../notimportant/demo_base.dart';

/// LinePerformanceActivity.
class LinePerformancePage extends StatefulWidget {
  const LinePerformancePage({super.key, this.nanoTime = FrameTimes.systemNanoTime});

  /// `System.nanoTime()`, the clock of the chart's [FrameTimes].
  final int Function() nanoTime;

  @override
  State<LinePerformancePage> createState() => _LinePerformancePageState();
}

/// The line shapes of the `lineShape` radio group.
enum _LineShape { linear, stepped, cubic }

class _LinePerformancePageState extends State<LinePerformancePage> with DemoBase {
  static const Duration _readoutInterval = Duration(milliseconds: 200);
  static const Color _singleColor = Color.fromARGB(255, 28, 88, 154);
  static const List<Color> _segmentColors = [
    Color.fromARGB(255, 28, 88, 154),
    Color.fromARGB(255, 217, 80, 48),
    Color.fromARGB(255, 106, 167, 79),
    Color.fromARGB(255, 233, 168, 41),
    Color.fromARGB(255, 123, 82, 171),
  ];

  /// `binding.chart`.
  late final TimedLineChart _chart = TimedLineChart(frameTimes: FrameTimes(nanoTime: widget.nanoTime));

  int _build = 0;
  int? _buildingCount;
  LineDataSet? _lineSet;

  /// The pending builds, `dataBuilder`'s queue.
  final Set<Timer> _builds = {};

  /// `readoutTick`.
  Timer? _readoutTick;

  /// `binding.readout.text`.
  String _readout = 'Waiting for a frame';

  /// `binding.entryCount`'s checked button: 10k.
  int _entryCount = 10000;

  /// `binding.lineShape`'s checked button: Linear.
  _LineShape _lineShape = _LineShape.linear;

  /// The `isChecked` of the switches, as the layout sets them.
  bool _decimation = true;
  bool _valueLabels = false;
  bool _circles = false;
  bool _fill = false;
  bool _multiColor = false;

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
      ..maxVisibleCount = _labelLimit
      ..axisRight.isEnabled = false
      ..axisLeft.typeface = tfLight
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
    _build++;
    final generation = _build;

    _buildingCount = count;
    _lineSet = null;
    _chart.noDataText = 'Building ${grouped(count)} entries...';
    _chart.data = null;
    _chart.frameTimes.clear();
    _showReadout();

    late final Timer build;
    build = Timer(Duration.zero, () {
      _builds.remove(build);
      final built = _buildSet(count);
      if (generation != _build || !mounted) return;
      setState(() => _show(built));
    });
    _builds.add(build);
  }

  /// `buildSet(count)`, with `java.util.Random(count)` and the Float arithmetic of Kotlin, so the values equal
  /// Android's.
  static LineDataSet _buildSet(int count) {
    final random = JavaRandom(count);
    final values = <Entry>[];
    final step = kotlinFloat(0.002);
    for (var i = 0; i < count; i++) {
      final wave = kotlinFloat(kotlinFloat(math.sin(kotlinFloat(i * step))) * 40);
      values.add(Entry(x: i.toDouble(), y: kotlinFloat(wave + kotlinFloat(random.nextFloat() * 20))));
    }
    return LineDataSet(values, '${grouped(count)} entries');
  }

  void _show(LineDataSet built) {
    built
      ..lineWidth = 1
      ..circleRadius = 2
      ..isDrawCircleHoleEnabled = false
      ..circleColors = [_singleColor]
      ..fillColor = _singleColor
      ..valueTextSize = 8
      ..mode = _selectedMode()
      ..isDrawCirclesEnabled = _circles
      ..isDrawValuesEnabled = _valueLabels
      ..isDrawFilledEnabled = _fill
      ..colors = _multiColor ? _segmentColors.toList() : [_singleColor];

    _lineSet = built;
    _buildingCount = null;
    _chart.data = LineData([built]);
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
    final total = _lineSet?.entryCount ?? 0;

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
    final set = _lineSet;
    if (set == null) return 0;
    if (set.entryCount == 0) return 0;

    final from = math.max(0, set.getEntryIndex(_chart.lowestVisibleX, double.nan, Rounding.DOWN));
    final to = math.max(0, set.getEntryIndex(_chart.highestVisibleX, double.nan, Rounding.UP));
    return math.max(0, to - from) + 1;
  }

  LineDataSetMode _selectedMode() => switch (_lineShape) {
    _LineShape.stepped => LineDataSetMode.STEPPED,
    _LineShape.cubic => LineDataSetMode.CUBIC_BEZIER,
    _LineShape.linear => LineDataSetMode.LINEAR,
  };

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Line chart',
    body: Column(
      children: [
        Expanded(
          flex: 3,
          child: ChartHostWidget<LineChartView, LineData>(chart: _chart, data: _chart.data),
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
                const Text('Line shape', style: TextStyle(fontSize: 13)),
                RadioGroup<_LineShape>(
                  groupValue: _lineShape,
                  onChanged: (shape) {
                    if (shape == null) return;
                    setState(() => _lineShape = shape);
                    _lineSet?.mode = _selectedMode();
                    _chart.invalidate();
                  },
                  child: const Row(
                    children: [
                      PerformanceRadioButton(_LineShape.linear, 'Linear'),
                      PerformanceRadioButton(_LineShape.stepped, 'Stepped'),
                      PerformanceRadioButton(_LineShape.cubic, 'Cubic'),
                    ],
                  ),
                ),
                PerformanceSwitch('Decimation', _decimation, (on) {
                  setState(() => _decimation = on);
                  _chart.isDecimationEnabled = on;
                  _chart.invalidate();
                }),
                PerformanceSwitch('Value labels', _valueLabels, (on) {
                  setState(() => _valueLabels = on);
                  _lineSet?.isDrawValuesEnabled = on;
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
                PerformanceSwitch('A circle at every point', _circles, (on) {
                  setState(() => _circles = on);
                  _lineSet?.isDrawCirclesEnabled = on;
                  _chart.invalidate();
                }),
                PerformanceSwitch('Fill under the line', _fill, (on) {
                  setState(() => _fill = on);
                  _lineSet?.isDrawFilledEnabled = on;
                  _chart.invalidate();
                }),
                PerformanceSwitch('A color per line segment', _multiColor, (on) {
                  setState(() => _multiColor = on);
                  _lineSet?.colors = on ? _segmentColors.toList() : [_singleColor];
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
