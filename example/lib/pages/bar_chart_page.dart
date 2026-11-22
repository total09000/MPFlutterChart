// Ported from MPChartExample: BarChartActivity.kt, with res/layout/activity_barchart.xml and res/menu/bar.xml.
//
// Bar Charts / Basic: one data set of bars with a gradient fill per bar, days on the x axis (DayAxisValueFormatter),
// dollar values on both y axes and XYMarkerView, with a seek bar for the number of bars and one for their range.
// Not ported: the "View on GitHub" and "Save to Gallery" menu items (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/day_axis_value_formatter.dart';
import '../custom/demo_drawables.dart';
import '../custom/my_axis_value_formatter.dart';
import '../custom/my_marker_view.dart';
import '../notimportant/demo_base.dart';

/// `android.R.color.holo_orange_light`.
const Color _holoOrangeLight = Color(0xFFFFBB33);

/// `android.R.color.holo_blue_light`.
const Color _holoBlueLight = Color(0xFF33B5E5);

/// `android.R.color.holo_green_light`.
const Color _holoGreenLight = Color(0xFF99CC00);

/// `android.R.color.holo_red_light`.
const Color _holoRedLight = Color(0xFFFF4444);

/// `android.R.color.holo_blue_dark`.
const Color _holoBlueDark = Color(0xFF0099CC);

/// `android.R.color.holo_purple`.
const Color _holoPurple = Color(0xFFAA66CC);

/// `android.R.color.holo_green_dark`.
const Color _holoGreenDark = Color(0xFF669900);

/// `android.R.color.holo_red_dark`.
const Color _holoRedDark = Color(0xFFCC0000);

/// `android.R.color.holo_orange_dark`.
const Color _holoOrangeDark = Color(0xFFFF8800);

/// BarChartActivity.
class BarChartPage extends StatefulWidget {
  const BarChartPage({super.key});

  @override
  State<BarChartPage> createState() => _BarChartPageState();
}

class _BarChartPageState extends State<BarChartPage> with DemoBase {
  /// `binding.chart1`.
  final BarChartView _chart = BarChartView();

  /// `barSet`: the data set setData creates once and then gives new entries.
  BarDataSet? _barSet;

  /// `onValueSelectedRectF`.
  final MutableRect _onValueSelectedRectF = MutableRect();

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 12;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 50;

  @override
  void initState() {
    super.initState();

    final xAxisFormatter = DayAxisValueFormatter(_chart);
    final custom = MyAxisValueFormatter();

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
      ..isDrawGridLinesEnabled = false
      ..granularity = 1
      ..labelCount = 7
      ..valueFormatter = xAxisFormatter;

    _chart.axisLeft
      ..typeface = tfLight
      ..labelCount = 8
      ..valueFormatter = custom
      ..labelPosition = YAxisLabelPosition.OUTSIDE_CHART
      ..spaceTop = 15
      ..axisMinimum = 0;

    _chart.axisRight
      ..isDrawGridLinesEnabled = false
      ..typeface = tfLight
      ..labelCount = 8
      ..valueFormatter = custom
      ..spaceTop = 15
      ..axisMinimum = 0;

    _chart.legend
      ..verticalAlignment = LegendVerticalAlignment.BOTTOM
      ..horizontalAlignment = LegendHorizontalAlignment.LEFT
      ..orientation = LegendOrientation.HORIZONTAL
      ..isDrawInsideEnabled = false
      ..form = LegendForm.SQUARE
      ..formSize = 9
      ..textSize = 11
      ..xEntrySpace = 4;

    final mv = XYMarkerView(xAxisFormatter)..chartView = _chart;
    _chart.marker = mv;

    // Setting the progress of the seek bars calls onProgressChanged, which sets the data.
    _onProgressChanged();
  }

  /// `setData(count, range)`.
  void _setData(int count, double range) {
    const start = 1;
    final values = <BarEntry>[];

    for (var i = start; i < start + count; i++) {
      final value = mathRandom() * (range + 1);
      if (mathRandom() * 100 < 25) {
        values.add(BarEntry(x: i.toDouble(), y: value, icon: starDrawable));
      } else {
        values.add(BarEntry(x: i.toDouble(), y: value));
      }
    }

    final existing = _barSet;
    if (existing != null) {
      existing.entries = values;
      _chart.notifyDataSetChanged();
    } else {
      final set1 = BarDataSet(values, 'The year 2017')..isDrawIconsEnabled = false;

      set1.fills = [
        Fill.ofColors(_holoOrangeLight, _holoBlueDark),
        Fill.ofColors(_holoBlueLight, _holoPurple),
        Fill.ofColors(_holoOrangeLight, _holoGreenDark),
        Fill.ofColors(_holoGreenLight, _holoRedDark),
        Fill.ofColors(_holoRedLight, _holoOrangeDark),
      ];

      final data = BarData([set1])
        ..setValueTextSize(10)
        ..setValueTypeface(tfLight)
        ..barWidth = 0.9;

      _barSet = set1;
      _chart.data = data;
    }
  }

  /// `onProgressChanged`: new data for the progress of the two seek bars.
  void _onProgressChanged() {
    _setData(_seekBar1, _seekBar2.toDouble());
    _chart.invalidate();
  }

  /// `onValueSelected`.
  void _onValueSelected(Entry e, Highlight h) {
    final bounds = _onValueSelectedRectF;
    _chart.getBarBounds(e as BarEntry, bounds);
    final position = _chart.getPosition(e, AxisDependency.LEFT);

    logI('bounds', bounds.toString());
    logI('position', position.toString());
    logI('x-index', 'low: ${_chart.lowestVisibleX}, high: ${_chart.highestVisibleX}');

    if (position != null) MPPointF.recycleInstance(position);
  }

  /// res/menu/bar.xml; "Toggle Rounded Sections" has no branch in `onOptionsItemSelected` and does nothing.
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
    DemoMenuItem('Toggle Icons', () {
      for (final set in _chart.data?.dataSets ?? const <IBarDataSet>[]) {
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
    title: 'Basic',
    menu: _menu,
    body: Column(
      children: [
        Expanded(child: ChartHostWidget<BarChartView, BarData>(chart: _chart, data: _chart.data)),
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
