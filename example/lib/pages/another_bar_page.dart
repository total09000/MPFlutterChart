// Ported from MPChartExample: AnotherBarActivity.kt, with res/layout/activity_barchart.xml and res/menu/bar.xml.
//
// Bar Charts / Basic 2: one data set of bars in the VORDIPLOM colours without value labels or legend, with a seek bar
// for the number of bars and one for their range. Not ported: the "View on GitHub" and "Save to Gallery" menu items
// (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// AnotherBarActivity.
class AnotherBarPage extends StatefulWidget {
  const AnotherBarPage({super.key});

  @override
  State<AnotherBarPage> createState() => _AnotherBarPageState();
}

class _AnotherBarPageState extends State<AnotherBarPage> with DemoBase {
  /// `binding.chart1`.
  final BarChartView _chart = BarChartView();

  /// `barSet`: the data set, created by the first call of [_onProgressChanged].
  BarDataSet? _barSet;

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 0;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 0;

  @override
  void initState() {
    super.initState();

    _chart
      ..description.isEnabled = false
      ..maxVisibleCount = 60
      ..isPinchZoomEnabled = false
      ..isDrawBarShadowEnabled = false
      ..isDrawGridBackgroundEnabled = false
      ..xAxis.position = XAxisPosition.BOTTOM
      ..xAxis.isDrawGridLinesEnabled = false
      ..axisLeft.isDrawGridLinesEnabled = false;

    // Setting the progress of each seek bar calls onProgressChanged, seekBar1 first.
    _seekBar1 = 10;
    _onProgressChanged();
    _seekBar2 = 100;
    _onProgressChanged();

    _chart.legend.isEnabled = false;
  }

  /// `onProgressChanged`: new random values for the progress of the two seek bars, put into the one data set.
  void _onProgressChanged() {
    final values = <BarEntry>[];
    for (var i = 0; i < _seekBar1; i++) {
      final multi = (_seekBar2 + 1).toDouble();
      final value = mathRandom() * multi + multi / 3;
      values.add(BarEntry(x: i.toDouble(), y: value));
    }

    final existing = _barSet;
    if (existing != null) {
      existing.entries = values;
      _chart.notifyDataSetChanged();
    } else {
      final set1 = BarDataSet(values, 'Data Set')
        ..colors = ColorTemplate.VORDIPLOM_COLORS.toList()
        ..isDrawValuesEnabled = false;

      _barSet = set1;
      _chart.data = BarData([set1]);
      _chart.isFitBarsEnabled = true;
    }

    _chart.invalidate();
  }

  List<IBarDataSet> get _dataSets => _chart.data?.dataSets ?? const <IBarDataSet>[];

  /// res/menu/bar.xml without actionToggleIcons, which `onCreateOptionsMenu` removes; an item `onOptionsItemSelected`
  /// has no branch for does nothing, as in Kotlin.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Toggle Bar Borders', () {
      for (final set in _dataSets) {
        (set as BarDataSet).barBorderWidth = set.barBorderWidth == 1 ? 0 : 1;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Rounded Sections', () {}),
    DemoMenuItem('Toggle Values', () {
      for (final set in _dataSets) {
        set.isDrawValuesEnabled = !set.isDrawValuesEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Highlight', () {
      final data = _chart.data;
      if (data != null) {
        data.isHighlightEnabled = !data.isHighlightEnabled;
        _chart.invalidate();
      }
    }),
    DemoMenuItem('Toggle PinchZoom', () {
      _chart.isPinchZoomEnabled = !_chart.isPinchZoomEnabled;
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Auto Scale', () {
      _chart.isAutoScaleMinMaxEnabled = !_chart.isAutoScaleMinMaxEnabled;
      _chart.notifyDataSetChanged();
    }),
    DemoMenuItem('Animate X', () => _chart.animateX(2000)),
    DemoMenuItem('Animate Y', () => _chart.animateY(2000)),
    DemoMenuItem('Animate XY', () => _chart.animateXY(2000, 2000)),
  ];

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Basic 2',
    menu: _menu,
    body: Column(
      children: [
        Expanded(
          child: ChartHostWidget<BarChartView, BarData>(
            chart: _chart,
            data: _chart.data,
            setup: (chart) => chart.animateY(1500),
          ),
        ),
        DemoSeekBar(
          progress: _seekBar1,
          max: 1500,
          textWidth: 60,
          textSize: 14,
          onProgressChanged: (progress) => setState(() {
            _seekBar1 = progress;
            _onProgressChanged();
          }),
        ),
        DemoSeekBar(
          progress: _seekBar2,
          max: 200,
          textWidth: 60,
          textSize: 14,
          onProgressChanged: (progress) => setState(() {
            _seekBar2 = progress;
            _onProgressChanged();
          }),
        ),
      ],
    ),
  );
}
