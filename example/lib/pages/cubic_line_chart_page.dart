// Ported from MPChartExample: CubicLineChartActivity.kt, with res/layout/activity_linechart.xml and
// res/menu/line.xml.
//
// Line Charts / Cubic: one filled cubic bezier data set in white on a green chart without margins, its left axis
// labels inside the chart, with a seek bar for the number of entries (up to 700) and one for their range. The set is
// created once; the seek bars give it new entries. Not ported: the "View on GitHub" and "Save to Gallery" menu items
// (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// CubicLineChartActivity.
class CubicLineChartPage extends StatefulWidget {
  const CubicLineChartPage({super.key});

  @override
  State<CubicLineChartPage> createState() => _CubicLineChartPageState();
}

class _CubicLineChartPageState extends State<CubicLineChartPage> with DemoBase {
  /// `binding.chart1`.
  final LineChartView _chart = LineChartView();

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 45;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 100;

  /// `lineSet`: the set, once `setData` created it.
  LineDataSet? _lineSet;

  /// `Color.rgb(104, 241, 175)`, the background of the chart.
  static const Color _background = Color.fromARGB(255, 104, 241, 175);

  @override
  void initState() {
    super.initState();

    _chart
      ..setViewPortOffsets(0, 0, 0, 0)
      ..description.isEnabled = false
      ..isTouchEnabled = true
      ..isDragEnabled = true
      ..isScaleEnabled = true
      ..isPinchZoomEnabled = false
      ..isDrawGridBackgroundEnabled = false
      ..maxHighlightDistance = 300;

    _chart.xAxis.isEnabled = false;

    _chart.axisLeft
      ..typeface = tfLight
      ..labelCount = 6
      ..textColor = const Color(0xFFFFFFFF)
      ..labelPosition = YAxisLabelPosition.INSIDE_CHART
      ..isDrawGridLinesEnabled = false
      ..axisLineColor = const Color(0xFFFFFFFF);

    _chart.axisRight.isEnabled = false;

    // Setting the progress of the seek bars calls onProgressChanged, which sets the data.
    _onProgressChanged();

    _chart.legend.isEnabled = false;

    _chart.invalidate();
  }

  /// `onProgressChanged`: new random data for the progress of the two seek bars.
  void _onProgressChanged() {
    _setData(_seekBar1, _seekBar2.toDouble());
    _chart.invalidate();
  }

  /// `setData(count, range)`.
  void _setData(int count, double range) {
    final values = <Entry>[];

    for (var i = 0; i < count; i++) {
      final value = mathRandom() * (range + 1) + 20;
      values.add(Entry(x: i.toDouble(), y: value));
    }

    final existing = _lineSet;
    if (existing != null) {
      existing.entries = values;
      _chart.notifyDataSetChanged();
    } else {
      final set1 = LineDataSet(values, 'DataSet 1')
        ..mode = LineDataSetMode.CUBIC_BEZIER
        ..cubicIntensity = 0.2
        ..isDrawFilledEnabled = true
        ..isDrawCirclesEnabled = false
        ..lineWidth = 1.8
        ..circleRadius = 4
        ..circleColor = const Color(0xFFFFFFFF)
        ..highlightColor = const Color.fromARGB(255, 244, 117, 117)
        ..color = const Color(0xFFFFFFFF)
        ..fillColor = const Color(0xFFFFFFFF)
        ..fillAlpha = 100
        ..isHorizontalHighlightIndicatorEnabled = false
        ..fillFormatter = IFillFormatter.fromFunction((_, _) => _chart.axisLeft.axisMinimum);

      final lineData = LineData([set1])
        ..setValueTypeface(tfLight)
        ..setValueTextSize(9)
        ..setDrawValues(false);

      _lineSet = set1;
      _chart.data = lineData;
    }
  }

  Iterable<LineDataSet> get _lineDataSets => _chart.data?.dataSets.whereType<LineDataSet>() ?? const [];

  void _toggleMode(LineDataSetMode mode) {
    for (final set in _lineDataSets) {
      set.mode = set.mode == mode ? LineDataSetMode.LINEAR : mode;
    }
    _chart.invalidate();
  }

  /// res/menu/line.xml; an item `onOptionsItemSelected` has no branch for does nothing, as in Kotlin.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Toggle Values', () {
      for (final set in _chart.data?.dataSets ?? const <ILineDataSet>[]) {
        set.isDrawValuesEnabled = !set.isDrawValuesEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Highlight Line Span', () {}),
    DemoMenuItem('Toggle Icons', () {}),
    DemoMenuItem('Toggle Filled', () {
      for (final set in _chart.data?.dataSets ?? const <ILineDataSet>[]) {
        set.isDrawFilledEnabled = !set.isDrawFilledEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Circles', () {
      for (final set in _lineDataSets) {
        set.isDrawCirclesEnabled = !set.isDrawCirclesEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Cubic', () => _toggleMode(LineDataSetMode.CUBIC_BEZIER)),
    DemoMenuItem('Toggle Stepped', () => _toggleMode(LineDataSetMode.STEPPED)),
    DemoMenuItem('Toggle Horizontal Cubic', () => _toggleMode(LineDataSetMode.HORIZONTAL_BEZIER)),
    DemoMenuItem('Toggle PinchZoom', () {
      _chart.isPinchZoomEnabled = !_chart.isPinchZoomEnabled;
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Auto Scale', () {
      _chart.isAutoScaleMinMaxEnabled = !_chart.isAutoScaleMinMaxEnabled;
      _chart.notifyDataSetChanged();
    }),
    DemoMenuItem('Toggle Highlight', () {
      final data = _chart.data;
      if (data != null) {
        data.isHighlightEnabled = !data.isHighlightEnabled;
        _chart.invalidate();
      }
    }),
    DemoMenuItem('Animate X', () => _chart.animateX(2000)),
    DemoMenuItem('Animate Y', () => _chart.animateY(2000)),
    DemoMenuItem('Animate XY', () => _chart.animateXY(2000, 2000)),
  ];

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Cubic',
    menu: _menu,
    body: Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: _background,
            child: ChartHostWidget<LineChartView, LineData>(
              chart: _chart,
              data: _chart.data,
              setup: (chart) => chart.animateXY(2000, 2000),
            ),
          ),
        ),
        DemoSeekBar(
          progress: _seekBar1,
          max: 700,
          onProgressChanged: (progress) => setState(() {
            _seekBar1 = progress;
            _onProgressChanged();
          }),
        ),
        DemoSeekBar(
          progress: _seekBar2,
          max: 150,
          onProgressChanged: (progress) => setState(() {
            _seekBar2 = progress;
            _onProgressChanged();
          }),
        ),
      ],
    ),
  );
}
