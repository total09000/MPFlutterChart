// Ported from MPChartExample: HorizontalBarNegativeChartActivity.kt, with res/layout/activity_horizontalbarchart.xml
// and res/menu/bar.xml.
//
// Bar Charts / Negative Horizontal: one data set of horizontal bars 10 apart with values around zero, each entry
// carrying the star icon (hidden until "Toggle Icons"), with a seek bar for the number of bars and one for their
// range. A selected bar logs its bounds and position. Not ported: the "View on GitHub" and "Save to Gallery" menu
// items (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/demo_drawables.dart';
import '../notimportant/demo_base.dart';

/// HorizontalBarNegativeChartActivity.
class HorizontalBarNegativeChartPage extends StatefulWidget {
  const HorizontalBarNegativeChartPage({super.key});

  @override
  State<HorizontalBarNegativeChartPage> createState() => _HorizontalBarNegativeChartPageState();
}

class _HorizontalBarNegativeChartPageState extends State<HorizontalBarNegativeChartPage> with DemoBase {
  /// `binding.chart1`.
  final HorizontalBarChartView _chart = HorizontalBarChartView();

  /// `barSet`: the data set, created by the first call of [_setData].
  BarDataSet? _barSet;

  /// `onValueSelectedRectF`.
  final MutableRect _onValueSelectedRectF = MutableRect();

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 0;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 0;

  @override
  void initState() {
    super.initState();

    _chart
      ..onChartValueSelectedListener = OnChartValueSelectedListener.fromFunction(
        onValueSelected: _onValueSelected,
        onNothingSelected: () {},
      )
      ..isDrawBarShadowEnabled = false
      ..isDrawValueAboveBarEnabled = true
      ..description.isEnabled = false
      ..maxVisibleCount = 60
      ..isPinchZoomEnabled = false
      ..isDrawGridBackgroundEnabled = false;

    _chart.xAxis
      ..position = XAxisPosition.BOTTOM
      ..typeface = tfLight
      ..isDrawAxisLineEnabled = true
      ..isDrawGridLinesEnabled = false
      ..granularity = 10;

    _chart.axisLeft
      ..typeface = tfLight
      ..isDrawAxisLineEnabled = true
      ..isDrawGridLinesEnabled = true;

    _chart.axisRight
      ..typeface = tfLight
      ..isDrawAxisLineEnabled = true
      ..isDrawGridLinesEnabled = false;

    _chart.isFitBarsEnabled = true;

    // Setting the progress of each seek bar calls onProgressChanged, seekBar2 first.
    _seekBar2 = 50;
    _onProgressChanged();
    _seekBar1 = 12;
    _onProgressChanged();

    _chart.legend
      ..verticalAlignment = LegendVerticalAlignment.BOTTOM
      ..horizontalAlignment = LegendHorizontalAlignment.LEFT
      ..orientation = LegendOrientation.HORIZONTAL
      ..isDrawInsideEnabled = false
      ..formSize = 8
      ..xEntrySpace = 4;
  }

  /// `setData`: [count] bars 10 apart with random values from -[range] / 2 to [range] / 2.
  void _setData(int count, double range) {
    const barWidth = 9.0;
    const spaceForBar = 10.0;
    final values = <BarEntry>[];

    for (var i = 0; i < count; i++) {
      final value = mathRandom() * range - range / 2;
      values.add(BarEntry(x: i * spaceForBar, y: value, icon: starDrawable));
    }

    final existing = _barSet;
    if (existing != null) {
      existing.entries = values;
      _chart.notifyDataSetChanged();
    } else {
      final set1 = BarDataSet(values, 'DataSet 1')..isDrawIconsEnabled = false;

      final data = BarData([set1])
        ..setValueTextSize(10)
        ..setValueTypeface(tfLight)
        ..barWidth = barWidth;
      _barSet = set1;
      _chart.data = data;
    }
  }

  /// `onProgressChanged`.
  void _onProgressChanged() {
    _setData(_seekBar1, _seekBar2.toDouble());
    _chart.isFitBarsEnabled = true;
    _chart.invalidate();
  }

  /// `onValueSelected`: logs the bounds and the position of the selected bar.
  void _onValueSelected(Entry e, Highlight h) {
    final bounds = _onValueSelectedRectF;
    _chart.getBarBounds(e as BarEntry, bounds);

    final axis = _chart.data?.getDataSetByIndex(h.dataSetIndex)?.axisDependency;
    if (axis == null) return;
    final position = _chart.getPosition(e, axis);

    logI('bounds', '$bounds');
    logI('position', '$position');
  }

  List<IBarDataSet> get _dataSets => _chart.data?.dataSets ?? const <IBarDataSet>[];

  /// res/menu/bar.xml; an item `onOptionsItemSelected` has no branch for does nothing, as in Kotlin.
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
    DemoMenuItem('Toggle Icons', () {
      for (final set in _dataSets) {
        set.isDrawIconsEnabled = !set.isDrawIconsEnabled;
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
    title: 'Negative Horizontal',
    menu: _menu,
    body: Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: demoChartBackground,
            child: ChartHostWidget<HorizontalBarChartView, BarData>(
              chart: _chart,
              data: _chart.data,
              setup: (chart) => chart.animateY(2500),
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
          max: 200,
          onProgressChanged: (progress) => setState(() {
            _seekBar2 = progress;
            _onProgressChanged();
          }),
        ),
      ],
    ),
  );
}
