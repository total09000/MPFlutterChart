// Ported from MPChartExample: MultiLineChartActivity.kt, with res/layout/activity_linechart.xml and res/menu/line.xml.
//
// Line Charts / Multiple: three data sets, the first one dashed and in a colour per entry, with a seek bar for the
// number of entries and one for their range. Not ported: the "View on GitHub" and "Save to Gallery" menu items (see
// notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// MultiLineChartActivity.
class MultiLineChartPage extends StatefulWidget {
  const MultiLineChartPage({super.key});

  @override
  State<MultiLineChartPage> createState() => _MultiLineChartPageState();
}

class _MultiLineChartPageState extends State<MultiLineChartPage> with DemoBase {
  /// `binding.chart1`.
  final LineChartView _chart = LineChartView();

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 20;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 100;

  static final List<Color> _colors = [
    ColorTemplate.VORDIPLOM_COLORS[0],
    ColorTemplate.VORDIPLOM_COLORS[1],
    ColorTemplate.VORDIPLOM_COLORS[2],
  ];

  @override
  void initState() {
    super.initState();

    _chart
      ..onChartValueSelectedListener = OnChartValueSelectedListener.fromFunction(
        onValueSelected: (e, h) =>
            logI('VAL SELECTED', 'Value: ${e.y}, xIndex: ${e.x}, DataSet index: ${h.dataSetIndex}'),
        onNothingSelected: () {},
      )
      ..isDrawGridBackgroundEnabled = false
      ..description.isEnabled = false
      ..isDrawBordersEnabled = false
      ..axisLeft.isEnabled = false
      ..axisRight.isDrawAxisLineEnabled = false
      ..axisRight.isDrawGridLinesEnabled = false
      ..xAxis.isDrawAxisLineEnabled = false
      ..xAxis.isDrawGridLinesEnabled = false
      ..isTouchEnabled = true
      ..isDragEnabled = true
      ..isScaleEnabled = true
      ..isPinchZoomEnabled = false;

    _chart.legend
      ..verticalAlignment = LegendVerticalAlignment.TOP
      ..horizontalAlignment = LegendHorizontalAlignment.RIGHT
      ..orientation = LegendOrientation.VERTICAL
      ..isDrawInsideEnabled = false;

    // Setting the progress of the seek bars calls onProgressChanged, which sets the data.
    _onProgressChanged();
  }

  /// `onProgressChanged`: new random data for the progress of the two seek bars.
  void _onProgressChanged() {
    _chart.resetTracking();

    final count = _seekBar1;
    final dataSets = <ILineDataSet>[];

    for (var z = 0; z < 3; z++) {
      final values = <Entry>[];

      for (var i = 0; i < count; i++) {
        final value = mathRandom() * _seekBar2 + 3;
        values.add(Entry(x: i.toDouble(), y: value));
      }

      final color = _colors[z % _colors.length];
      dataSets.add(
        LineDataSet(values, 'DataSet ${z + 1}')
          ..lineWidth = 2.5
          ..circleRadius = 4
          ..color = color
          ..circleColor = color,
      );
    }

    (dataSets[0] as LineDataSet)
      ..enableDashedLine(10, 10, 0)
      ..colors = ColorTemplate.VORDIPLOM_COLORS.toList()
      ..circleColors = ColorTemplate.VORDIPLOM_COLORS.toList();

    _chart.data = LineData(dataSets);
    _chart.invalidate();
  }

  Iterable<LineDataSet> get _lineDataSets => _chart.data?.dataSets.whereType<LineDataSet>() ?? const [];

  void _toggleMode(LineDataSetMode mode) {
    for (final set in _lineDataSets) {
      set.mode = set.mode == mode ? LineDataSetMode.LINEAR : mode;
    }
    _chart.invalidate();
  }

  /// res/menu/line.xml without actionToggleIcons, which `onCreateOptionsMenu` removes; an item `onOptionsItemSelected`
  /// has no branch for does nothing, as in Kotlin.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Toggle Values', () {
      for (final set in _chart.data?.dataSets ?? const <ILineDataSet>[]) {
        set.isDrawValuesEnabled = !set.isDrawValuesEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Highlight Line Span', () {}),
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
    title: 'Multiple',
    menu: _menu,
    body: Column(
      children: [
        Expanded(child: ChartHostWidget<LineChartView, LineData>(chart: _chart, data: _chart.data)),
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
