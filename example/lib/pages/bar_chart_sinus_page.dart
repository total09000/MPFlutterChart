// Ported from MPChartExample: BarChartActivitySinus.kt, with res/layout/activity_barchart_sinus.xml and
// res/menu/bar.xml.
//
// Bar Charts / Sine: the first values of a sine wave read from assets/othersine.txt as bars, with a seek bar for how
// many of the 8000 values are shown. Not ported: the "View on GitHub" and "Save to Gallery" menu items (see
// notimportant/demo_base.dart). The asset is read asynchronously, so the chart shows without data until it is loaded,
// and the animateXY of onCreate may already run before the data arrives; Kotlin reads it before the chart is set up.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// BarChartActivitySinus.
class BarChartSinusPage extends StatefulWidget {
  const BarChartSinusPage({super.key});

  @override
  State<BarChartSinusPage> createState() => _BarChartSinusPageState();
}

class _BarChartSinusPageState extends State<BarChartSinusPage> with DemoBase {
  /// `binding.chart1`.
  final BarChartView _chart = BarChartView();

  /// `barSet`: the data set, created by the first call of [_setData].
  BarDataSet? _barSet;

  /// `data`, the entries of othersine.txt; null until the asset is loaded.
  List<BarEntry>? _data;

  /// `binding.seekbarValues.progress`.
  int _seekbarValues = 150;

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _chart
      ..isDrawBarShadowEnabled = false
      ..isDrawValueAboveBarEnabled = true
      ..description.isEnabled = false
      ..maxVisibleCount = 60
      ..isPinchZoomEnabled = false
      ..isDrawGridBackgroundEnabled = false
      ..xAxis.isEnabled = false;

    _chart.axisLeft
      ..typeface = tfLight
      ..labelCount = 6
      ..axisMinimum = -2.5
      ..axisMaximum = 2.5
      ..isGranularityEnabled = true
      ..granularity = 0.1;

    _chart.axisRight
      ..isDrawGridLinesEnabled = false
      ..typeface = tfLight
      ..labelCount = 6
      ..axisMinimum = -2.5
      ..axisMaximum = 2.5
      ..granularity = 0.1;

    _chart.legend
      ..verticalAlignment = LegendVerticalAlignment.BOTTOM
      ..horizontalAlignment = LegendHorizontalAlignment.LEFT
      ..orientation = LegendOrientation.HORIZONTAL
      ..isDrawInsideEnabled = false
      ..form = LegendForm.SQUARE
      ..formSize = 9
      ..textSize = 11
      ..xEntrySpace = 4;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) return;
    _loading = true;
    // `FileUtils.loadBarEntriesFromAssets(assets, "othersine.txt")`; setting the seek bar's progress in onCreate
    // then calls onProgressChanged, which sets the data.
    FileUtils.loadBarEntriesFromAssets(DefaultAssetBundle.of(context), 'assets/othersine.txt').then((entries) {
      if (!mounted) return;
      setState(() {
        _data = entries;
        _onProgressChanged();
      });
    });
  }

  /// `setData`: the first [count] entries of the asset in one data set.
  void _setData(int count) {
    final data = _data;
    if (data == null) return;
    final entries = <BarEntry>[for (var i = 0; i < count && i < data.length; i++) data[i]];

    final existing = _barSet;
    final BarDataSet set;
    if (existing != null) {
      set = existing..entries = entries;
    } else {
      set = BarDataSet(entries, 'Sinus Function')..color = const Color.fromARGB(255, 240, 120, 124);
      _barSet = set;
    }

    final barData = BarData([set])
      ..setValueTextSize(10)
      ..setValueTypeface(tfLight)
      ..setDrawValues(false)
      ..barWidth = 0.8;

    _chart.data = barData;
  }

  /// `onProgressChanged`.
  void _onProgressChanged() {
    _setData(_seekbarValues);
    _chart.invalidate();
  }

  List<IBarDataSet> get _dataSets => _chart.data?.dataSets ?? const <IBarDataSet>[];

  /// res/menu/bar.xml; an item `onOptionsItemSelected` has no branch for (Toggle Rounded Sections, Toggle Icons) does
  /// nothing, as in Kotlin.
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
    title: 'Sine',
    menu: _menu,
    body: Column(
      children: [
        Expanded(
          child: ChartHostWidget<BarChartView, BarData>(
            chart: _chart,
            data: _chart.data,
            setup: (chart) => chart.animateXY(1500, 1500),
          ),
        ),
        DemoSeekBar(
          progress: _seekbarValues,
          max: 8000,
          textWidth: 60,
          onProgressChanged: (progress) => setState(() {
            _seekbarValues = progress;
            _onProgressChanged();
          }),
        ),
      ],
    ),
  );
}
