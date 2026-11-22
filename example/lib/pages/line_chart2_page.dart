// Ported from MPChartExample: LineChartActivity2.kt, with res/layout/activity_linechart.xml and res/menu/line.xml.
//
// Line Charts / Dual Axis: three data sets on a light grey chart, the first on the left axis (0 to 200), the other two
// on the right axis (-200 to 900), with a seek bar for the number of entries and one for their range. The sets are
// created once; the seek bars give them new entries. Selecting a value centers the view on it. Not ported: the "View
// on GitHub" and "Save to Gallery" menu items (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// LineChartActivity2.
class LineChart2Page extends StatefulWidget {
  const LineChart2Page({super.key});

  @override
  State<LineChart2Page> createState() => _LineChart2PageState();
}

class _LineChart2PageState extends State<LineChart2Page> with DemoBase {
  /// `binding.chart1`.
  final LineChartView _chart = LineChartView();

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 20;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 30;

  /// `lineSets`: the three sets, once `setData` created them.
  List<LineDataSet> _lineSets = const [];

  /// Android's `Color.LTGRAY`, the background of the chart.
  static const Color _lightGray = Color(0xFFCCCCCC);

  /// `Color.rgb(244, 117, 117)`.
  static const Color _highlightColor = Color.fromARGB(255, 244, 117, 117);

  @override
  void initState() {
    super.initState();

    _chart
      ..onChartValueSelectedListener = OnChartValueSelectedListener.fromFunction(
        onValueSelected: (e, h) {
          logI('Entry<*> selected', e.toString());

          final axis = _chart.data?.getDataSetByIndex(h.dataSetIndex)?.axisDependency;
          if (axis == null) return;
          _chart.centerViewToAnimated(e.x, e.y, axis, 500);
        },
        onNothingSelected: () => logI('Nothing selected', 'Nothing selected.'),
      )
      ..description.isEnabled = false
      ..isTouchEnabled = true
      ..dragDecelerationFrictionCoef = 0.9
      ..isDragEnabled = true
      ..isScaleEnabled = true
      ..isDrawGridBackgroundEnabled = false
      ..isHighlightPerDragEnabled = true
      ..isPinchZoomEnabled = true;

    // Setting the progress of the seek bars calls onProgressChanged, which sets the data.
    _onProgressChanged();

    _chart.legend
      ..form = LegendForm.LINE
      ..typeface = tfLight
      ..textSize = 11
      ..textColor = const Color(0xFFFFFFFF)
      ..verticalAlignment = LegendVerticalAlignment.BOTTOM
      ..horizontalAlignment = LegendHorizontalAlignment.LEFT
      ..orientation = LegendOrientation.HORIZONTAL
      ..isDrawInsideEnabled = false;

    _chart.xAxis
      ..typeface = tfLight
      ..textSize = 11
      ..textColor = const Color(0xFFFFFFFF)
      ..isDrawGridLinesEnabled = false
      ..isDrawAxisLineEnabled = false;

    _chart.axisLeft
      ..typeface = tfLight
      ..textColor = ColorTemplate.holoBlue
      ..axisMaximum = 200
      ..axisMinimum = 0
      ..isDrawGridLinesEnabled = true
      ..isGranularityEnabled = true;

    _chart.axisRight
      ..typeface = tfLight
      ..textColor = const Color(0xFFFF0000)
      ..axisMaximum = 900
      ..axisMinimum = -200
      ..isDrawGridLinesEnabled = false
      ..isDrawZeroLineEnabled = false
      ..isGranularityEnabled = false;
  }

  /// `onProgressChanged`: new data for the progress of the two seek bars.
  void _onProgressChanged() {
    _setData(_seekBar1, _seekBar2.toDouble());
    _chart.invalidate();
  }

  /// `setData(count, range)`.
  void _setData(int count, double range) {
    final values1 = <Entry>[];
    for (var i = 0; i < count; i++) {
      final value = mathRandom() * (range / 2) + 50;
      values1.add(Entry(x: i.toDouble(), y: value));
    }

    final values2 = <Entry>[];
    for (var i = 0; i < count; i++) {
      final value = mathRandom() * range + 450;
      values2.add(Entry(x: i.toDouble(), y: value));
    }

    final values3 = <Entry>[];
    for (var i = 0; i < count; i++) {
      final value = mathRandom() * range + 500;
      values3.add(Entry(x: i.toDouble(), y: value));
    }

    if (_lineSets.isNotEmpty) {
      _lineSets[0].entries = values1;
      _lineSets[1].entries = values2;
      _lineSets[2].entries = values3;
      _chart.notifyDataSetChanged();
    } else {
      final set1 = LineDataSet(values1, 'DataSet 1')
        ..axisDependency = AxisDependency.LEFT
        ..color = ColorTemplate.holoBlue
        ..circleColor = const Color(0xFFFFFFFF)
        ..lineWidth = 2
        ..circleRadius = 3
        ..fillAlpha = 65
        ..fillColor = ColorTemplate.holoBlue
        ..highlightColor = _highlightColor
        ..isDrawCircleHoleEnabled = false;

      final set2 = LineDataSet(values2, 'DataSet 2')
        ..axisDependency = AxisDependency.RIGHT
        ..color = const Color(0xFFFF0000)
        ..circleColor = const Color(0xFFFFFFFF)
        ..lineWidth = 2
        ..circleRadius = 3
        ..fillAlpha = 65
        ..fillColor = const Color(0xFFFF0000)
        ..isDrawCircleHoleEnabled = false
        ..highlightColor = _highlightColor;

      final set3 = LineDataSet(values3, 'DataSet 3')
        ..axisDependency = AxisDependency.RIGHT
        ..color = const Color(0xFFFFFF00)
        ..circleColor = const Color(0xFFFFFFFF)
        ..lineWidth = 2
        ..circleRadius = 3
        ..fillAlpha = 65
        ..fillColor = ColorTemplate.colorWithAlpha(const Color(0xFFFFFF00), 200)
        ..isDrawCircleHoleEnabled = false
        ..highlightColor = _highlightColor;

      final lineData = LineData([set1, set2, set3])
        ..setValueTextColor(const Color(0xFFFFFFFF))
        ..setValueTextSize(9);

      _lineSets = [set1, set2, set3];
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
    title: 'Dual Axis',
    menu: _menu,
    body: Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: _lightGray,
            child: ChartHostWidget<LineChartView, LineData>(
              chart: _chart,
              data: _chart.data,
              setup: (chart) => chart.animateX(1500),
            ),
          ),
        ),
        DemoSeekBar(
          progress: _seekBar1,
          max: 500,
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
