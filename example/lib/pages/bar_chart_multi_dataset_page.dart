// Ported from MPChartExample: BarChartActivityMultiDataset.kt, with res/layout/activity_barchart.xml and
// res/menu/bar.xml.
//
// Bar Charts / Multiple: four companies' bars grouped side by side, one group per year from 1980, with large values
// (LargeValueFormatter) and MyMarkerView, a seek bar for the number of years and one for the range of the values.
// Not ported: the "View on GitHub" and "Save to Gallery" menu items (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/my_marker_view.dart';
import '../notimportant/demo_base.dart';

/// BarChartActivityMultiDataset.
class BarChartMultiDatasetPage extends StatefulWidget {
  const BarChartMultiDatasetPage({super.key});

  @override
  State<BarChartMultiDatasetPage> createState() => _BarChartMultiDatasetPageState();
}

class _BarChartMultiDatasetPageState extends State<BarChartMultiDatasetPage> with DemoBase {
  /// `binding.chart1`.
  final BarChartView _chart = BarChartView();

  /// `barSets`: the four data sets onProgressChanged creates once and then gives new entries.
  List<BarDataSet> _barSets = const [];

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 10;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 100;

  /// `binding.tvXMax.text`.
  String _tvXMax = '-';

  @override
  void initState() {
    super.initState();

    final mv = MyMarkerView()..chartView = _chart;
    _chart
      ..onChartValueSelectedListener = OnChartValueSelectedListener.fromFunction(
        onValueSelected: (e, h) => logI('Activity', 'Selected: $e, dataSet: ${h.dataSetIndex}'),
        onNothingSelected: () => logI('Activity', 'Nothing selected.'),
      )
      ..description.isEnabled = false
      ..isPinchZoomEnabled = false
      ..isDrawBarShadowEnabled = false
      ..isDrawGridBackgroundEnabled = false
      ..marker = mv;

    // Setting the progress of the seek bars calls onProgressChanged, which sets the data.
    _onProgressChanged();

    _chart.legend
      ..verticalAlignment = LegendVerticalAlignment.TOP
      ..horizontalAlignment = LegendHorizontalAlignment.RIGHT
      ..orientation = LegendOrientation.VERTICAL
      ..isDrawInsideEnabled = true
      ..typeface = tfLight
      ..yOffset = 0
      ..xOffset = 10
      ..yEntrySpace = 0
      ..textSize = 8;

    _chart.xAxis
      ..typeface = tfLight
      ..granularity = 1
      ..isCenterAxisLabelsEnabled = true
      ..valueFormatter = IAxisValueFormatter.fromFunction((value, _) => value.toInt().toString());

    _chart.axisLeft
      ..typeface = tfLight
      ..valueFormatter = LargeValueFormatter()
      ..isDrawGridLinesEnabled = false
      ..spaceTop = 35
      ..axisMinimum = 0;

    _chart.axisRight.isEnabled = false;
  }

  /// `onProgressChanged`: a group of four bars per year for the progress of the two seek bars.
  void _onProgressChanged() {
    const groupSpace = 0.08;
    const barSpace = 0.03;
    const barWidth = 0.2;

    final groupCount = _seekBar1 + 1;
    const startYear = 1980;
    final endYear = startYear + groupCount;

    _tvXMax = '$startYear-$endYear';

    final values1 = <BarEntry>[];
    final values2 = <BarEntry>[];
    final values3 = <BarEntry>[];
    final values4 = <BarEntry>[];

    final randomMultiplier = _seekBar2 * 100000.0;

    for (var i = startYear; i < endYear; i++) {
      values1.add(BarEntry(x: i.toDouble(), y: mathRandom() * randomMultiplier));
      values2.add(BarEntry(x: i.toDouble(), y: mathRandom() * randomMultiplier));
      values3.add(BarEntry(x: i.toDouble(), y: mathRandom() * randomMultiplier));
      values4.add(BarEntry(x: i.toDouble(), y: mathRandom() * randomMultiplier));
    }

    final chart = _chart;
    if (_barSets.isNotEmpty) {
      _barSets[0].entries = values1;
      _barSets[1].entries = values2;
      _barSets[2].entries = values3;
      _barSets[3].entries = values4;
      chart.notifyDataSetChanged();
    } else {
      final set1 = BarDataSet(values1, 'Company A')..color = const Color.fromARGB(255, 104, 241, 175);
      final set2 = BarDataSet(values2, 'Company B')..color = const Color.fromARGB(255, 164, 228, 251);
      final set3 = BarDataSet(values3, 'Company C')..color = const Color.fromARGB(255, 242, 247, 158);
      final set4 = BarDataSet(values4, 'Company D')..color = const Color.fromARGB(255, 255, 102, 0);

      final data = BarData([set1, set2, set3, set4])
        ..setValueFormatter(LargeValueFormatter())
        ..setValueTypeface(tfLight);

      _barSets = [set1, set2, set3, set4];
      chart.data = data;
    }

    final barData = chart.barData;
    if (barData == null) return;
    barData.barWidth = barWidth;

    chart.xAxis.axisMinimum = startYear.toDouble();
    chart.xAxis.axisMaximum = startYear + barData.getGroupWidth(groupSpace, barSpace) * groupCount;
    chart.groupBars(startYear.toDouble(), groupSpace, barSpace);
    chart.invalidate();
  }

  /// res/menu/bar.xml; "Toggle Rounded Sections" and "Toggle Icons" have no branch in `onOptionsItemSelected` and do
  /// nothing.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Toggle Bar Borders', () {
      for (final set in _chart.data?.dataSets ?? const <IBarDataSet>[]) {
        (set as BarDataSet).barBorderWidth = set.barBorderWidth == 1 ? 0 : 1;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Rounded Sections', () {}),
    DemoMenuItem('Toggle Values', () {
      for (final set in _chart.data?.dataSets ?? const <IBarDataSet>[]) {
        set.isDrawValuesEnabled = !set.isDrawValuesEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Icons', () {}),
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
    title: 'Multiple',
    menu: _menu,
    body: Column(
      children: [
        Expanded(child: ChartHostWidget<BarChartView, BarData>(chart: _chart, data: _chart.data)),
        DemoSeekBar(
          progress: _seekBar1,
          max: 50,
          text: _tvXMax,
          textWidth: 60,
          textSize: 10,
          onProgressChanged: (progress) => setState(() {
            _seekBar1 = progress;
            _onProgressChanged();
          }),
        ),
        DemoSeekBar(
          progress: _seekBar2,
          max: 200,
          text: '$_seekBar2',
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
