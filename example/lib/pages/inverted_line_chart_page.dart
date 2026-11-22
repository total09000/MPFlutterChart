// Ported from MPChartExample: InvertedLineChartActivity.kt, with res/layout/activity_linechart.xml and
// res/menu/line.xml.
//
// Line Charts / Inverted Axis: one data set of random x and y values, sorted by x, on an inverted left axis, with the
// value marker, a seek bar for the number of entries and one for their range. Every change of a seek bar sets new
// data. Not ported: the "View on GitHub" and "Save to Gallery" menu items (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/my_marker_view.dart';
import '../notimportant/demo_base.dart';

/// InvertedLineChartActivity.
class InvertedLineChartPage extends StatefulWidget {
  const InvertedLineChartPage({super.key});

  @override
  State<InvertedLineChartPage> createState() => _InvertedLineChartPageState();
}

class _InvertedLineChartPageState extends State<InvertedLineChartPage> with DemoBase {
  /// `binding.chart1`.
  final LineChartView _chart = LineChartView();

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 25;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 50;

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
      ..isTouchEnabled = true
      ..isDragEnabled = true
      ..isScaleEnabled = true
      ..isPinchZoomEnabled = true;

    final mv = MyMarkerView()..chartView = _chart;
    _chart.marker = mv;

    _chart.xAxis
      ..isAvoidFirstLastClippingEnabled = true
      ..axisMinimum = 0;

    _chart.axisLeft
      ..isInverted = true
      ..axisMinimum = 0;

    _chart.axisRight.isEnabled = false;

    // Setting the progress of the seek bars calls onProgressChanged, which sets the data.
    _onProgressChanged();

    _chart.legend.form = LegendForm.LINE;

    _chart.invalidate();
  }

  /// `onProgressChanged`: new random data for the progress of the two seek bars.
  void _onProgressChanged() {
    _setData(_seekBar1, _seekBar2.toDouble());
    _chart.invalidate();
  }

  /// `setData(count, range)`.
  void _setData(int count, double range) {
    final entries = <Entry>[];

    for (var i = 0; i < count; i++) {
      final xValue = mathRandom() * range;
      final yValue = mathRandom() * range;
      entries.add(Entry(x: xValue, y: yValue));
    }

    entries.sort(EntryXComparator().compare);

    final set1 = LineDataSet(entries, 'DataSet 1')
      ..lineWidth = 1.5
      ..circleRadius = 4;

    _chart.data = LineData([set1]);
  }

  /// res/menu/line.xml; an item `onOptionsItemSelected` has no branch for (the line modes among them) does nothing,
  /// as in Kotlin.
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
      for (final set in _chart.data?.dataSets.whereType<LineDataSet>() ?? const <LineDataSet>[]) {
        set.isDrawCirclesEnabled = !set.isDrawCirclesEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Cubic', () {}),
    DemoMenuItem('Toggle Stepped', () {}),
    DemoMenuItem('Toggle Horizontal Cubic', () {}),
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
    title: 'Inverted Axis',
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
