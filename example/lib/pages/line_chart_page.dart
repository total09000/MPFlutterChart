// Ported from MPChartExample: LineChartActivity1.kt, with res/layout/activity_linechart.xml and res/menu/line.xml.
//
// Line Charts / Basic: one dashed black line of random values filled with the fade_red gradient down to the axis
// minimum, two dashed limit lines, a dashed grid and MyMarkerView, with a seek bar for the number of entries and one
// for their range. Not ported: the "View on GitHub" and "Save to Gallery" menu items (see
// notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/demo_drawables.dart';
import '../custom/my_marker_view.dart';
import '../notimportant/demo_base.dart';

/// LineChartActivity1.
class LineChartPage extends StatefulWidget {
  const LineChartPage({super.key});

  @override
  State<LineChartPage> createState() => _LineChartPageState();
}

class _LineChartPageState extends State<LineChartPage> with DemoBase {
  /// `binding.chart1`.
  final LineChartView _chart = LineChartView();

  /// `lineSet`: the data set setData creates once and then gives new entries.
  LineDataSet? _lineSet;

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 45;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 180;

  @override
  void initState() {
    super.initState();

    final mv = MyMarkerView()..chartView = _chart;
    _chart
      ..description.isEnabled = false
      ..isTouchEnabled = true
      ..onChartValueSelectedListener = OnChartValueSelectedListener.fromFunction(
        onValueSelected: (entry, _) {
          logI('Entry<*> selected', entry.toString());
          logI('LOW HIGH', 'low: ${_chart.lowestVisibleX}, high: ${_chart.highestVisibleX}');
          logI(
            'MIN MAX',
            'xMin: ${_chart.xChartMin}, xMax: ${_chart.xChartMax}, '
                'yMin: ${_chart.yChartMin}, yMax: ${_chart.yChartMax}',
          );
        },
        onNothingSelected: () => logI('Nothing selected', 'Nothing selected.'),
      )
      ..isDrawGridBackgroundEnabled = false
      ..marker = mv
      ..isDragEnabled = true
      ..isScaleEnabled = true
      ..isPinchZoomEnabled = true;

    final xAxis = _chart.xAxis..enableGridDashedLine(10, 10, 0);

    final yAxis = _chart.axisLeft;
    _chart.axisRight.isEnabled = false;
    yAxis
      ..enableGridDashedLine(10, 10, 0)
      ..axisMaximum = 200
      ..axisMinimum = -50;

    final ll1 = LimitLine(150, 'Upper Limit')
      ..lineWidth = 4
      ..enableDashedLine(10, 10, 0)
      ..labelPosition = LimitLabelPosition.RIGHT_TOP
      ..textSize = 10
      ..typeface = tfRegular;

    final ll2 = LimitLine(-30, 'Lower Limit')
      ..lineWidth = 4
      ..enableDashedLine(10, 10, 0)
      ..labelPosition = LimitLabelPosition.RIGHT_BOTTOM
      ..textSize = 10
      ..typeface = tfRegular;

    yAxis.isDrawLimitLinesBehindDataEnabled = true;
    xAxis.isDrawLimitLinesBehindDataEnabled = true;

    yAxis
      ..addLimitLine(ll1)
      ..addLimitLine(ll2);

    // Setting the progress of the seek bars calls onProgressChanged, and onCreate calls setData(45, 180f) itself;
    // each call ends with the same data shape, so one call loads it here. animateX(1500) is in the host's setup.
    _setData(_seekBar1, _seekBar2.toDouble());

    _chart.legend.form = LegendForm.LINE;
  }

  /// `setData(count, range)`.
  void _setData(int count, double range) {
    final values = <Entry>[];

    for (var i = 0; i < count; i++) {
      final value = mathRandom() * range - 30;
      values.add(Entry(x: i.toDouble(), y: value, icon: starDrawable));
    }

    final existing = _lineSet;
    if (existing != null) {
      existing.entries = values;
      _chart.notifyDataSetChanged();
    } else {
      final set1 = LineDataSet(values, 'DataSet 1')
        ..isDrawIconsEnabled = false
        ..enableDashedLine(10, 5, 0)
        ..color = const Color(0xFF000000)
        ..circleColor = const Color(0xFF000000)
        ..lineWidth = 1
        ..circleRadius = 3
        ..isDrawCircleHoleEnabled = false
        ..formLineWidth = 1
        ..formLineDashEffect = DashPathEffect([10, 5], 0)
        ..formSize = 15
        ..valueTextSize = 9
        ..enableDashedHighlightLine(10, 5, 0)
        ..isDrawFilledEnabled = true
        ..fillFormatter = IFillFormatter.fromFunction((_, _) => _chart.axisLeft.axisMinimum)
        ..fillDrawable = fadeRedDrawable;

      _lineSet = set1;
      _chart.data = LineData([set1]);
    }
  }

  /// `onProgressChanged`: the texts follow the seek bars, then new data for their progress.
  void _onProgressChanged() {
    _setData(_seekBar1, _seekBar2.toDouble());
    _chart.invalidate();
  }

  Iterable<LineDataSet> get _lineDataSets => _chart.data?.dataSets.whereType<LineDataSet>() ?? const [];

  void _toggleMode(LineDataSetMode mode) {
    for (final set in _lineDataSets) {
      set.mode = set.mode == mode ? LineDataSetMode.LINEAR : mode;
    }
    _chart.invalidate();
  }

  /// res/menu/line.xml.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Toggle Values', () {
      for (final set in _chart.data?.dataSets ?? const <ILineDataSet>[]) {
        set.isDrawValuesEnabled = !set.isDrawValuesEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Highlight Line Span', () {
      for (final set in _lineDataSets) {
        set.verticalHighlightIndicatorSpan = switch (set.verticalHighlightIndicatorSpan) {
          HighlightLineSpan.FULL => HighlightLineSpan.TO_ENTRY,
          HighlightLineSpan.TO_ENTRY => HighlightLineSpan.FROM_ENTRY,
          HighlightLineSpan.FROM_ENTRY => HighlightLineSpan.FULL,
        };
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Icons', () {
      for (final set in _chart.data?.dataSets ?? const <ILineDataSet>[]) {
        set.isDrawIconsEnabled = !set.isDrawIconsEnabled;
      }
      _chart.invalidate();
    }),
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
    DemoMenuItem('Animate Y', () => _chart.animateY(2000, easing: Easing.EaseInCubic)),
    DemoMenuItem('Animate XY', () => _chart.animateXY(2000, 2000)),
  ];

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Basic',
    menu: _menu,
    body: Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: demoChartBackground,
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
          max: 180,
          onProgressChanged: (progress) => setState(() {
            _seekBar2 = progress;
            _onProgressChanged();
          }),
        ),
      ],
    ),
  );
}
