// Ported from MPChartExample: StackedBarActivity.kt, with res/layout/activity_barchart.xml and res/menu/bar.xml.
//
// Bar Charts / Stacked: one data set of bars with three stacked values each (Births, Divorces, Marriages), white
// value labels inside the stacks, the x axis on top, with a seek bar for the number of bars and one for the range of
// the values. Not ported: the "View on GitHub" and "Save to Gallery" menu items (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/demo_drawables.dart';
import '../custom/my_axis_value_formatter.dart';
import '../custom/my_value_formatter.dart';
import '../notimportant/demo_base.dart';

/// StackedBarActivity.
class StackedBarPage extends StatefulWidget {
  const StackedBarPage({super.key});

  @override
  State<StackedBarPage> createState() => _StackedBarPageState();
}

class _StackedBarPageState extends State<StackedBarPage> with DemoBase {
  /// `binding.chart1`.
  final BarChartView _chart = BarChartView();

  /// `barSet`: the data set onProgressChanged creates once and then gives new entries.
  BarDataSet? _barSet;

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 12;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 100;

  @override
  void initState() {
    super.initState();

    _chart
      ..onChartValueSelectedListener = OnChartValueSelectedListener.fromFunction(
        onValueSelected: (e, h) {
          final stackValues = (e as BarEntry).stackValues;
          if (stackValues != null) {
            logI('VAL SELECTED', 'Value: ${stackValues[h.stackIndex]}');
          } else {
            logI('VAL SELECTED', 'Value: ${e.y}');
          }
        },
        onNothingSelected: () {},
      )
      ..description.isEnabled = false
      ..maxVisibleCount = 40
      ..isPinchZoomEnabled = false
      ..isDrawGridBackgroundEnabled = false
      ..isDrawBarShadowEnabled = false
      ..isDrawValueAboveBarEnabled = false
      ..isHighlightFullBarEnabled = false;

    _chart.axisLeft
      ..valueFormatter = MyAxisValueFormatter()
      ..axisMinimum = 0;
    _chart.axisRight.isEnabled = false;

    _chart.xAxis.position = XAxisPosition.TOP;

    // Setting the progress of the seek bars calls onProgressChanged, which sets the data.
    _onProgressChanged();

    _chart.legend
      ..verticalAlignment = LegendVerticalAlignment.BOTTOM
      ..horizontalAlignment = LegendHorizontalAlignment.RIGHT
      ..orientation = LegendOrientation.HORIZONTAL
      ..isDrawInsideEnabled = false
      ..formSize = 8
      ..formToTextSpace = 4
      ..xEntrySpace = 6;
  }

  /// `onProgressChanged`: a stack of three values per bar for the progress of the two seek bars.
  void _onProgressChanged() {
    final values = <BarEntry>[];
    for (var i = 0; i < _seekBar1; i++) {
      final mul = (_seekBar2 + 1).toDouble();
      final val1 = mathRandom() * mul + mul / 3;
      final val2 = mathRandom() * mul + mul / 3;
      final val3 = mathRandom() * mul + mul / 3;

      values.add(BarEntry.stacked(x: i.toDouble(), stackValues: [val1, val2, val3], icon: starDrawable));
    }

    final existing = _barSet;
    if (existing != null) {
      existing.entries = values;
      _chart.notifyDataSetChanged();
    } else {
      final set1 = BarDataSet(values, 'Statistics Vienna 2014')
        ..isDrawIconsEnabled = false
        ..colors = _getColors()
        ..stackLabels = const ['Births', 'Divorces', 'Marriages'];

      final data = BarData([set1])
        ..setValueFormatter(MyValueFormatter())
        ..setValueTextColor(const Color(0xFFFFFFFF));

      _barSet = set1;
      _chart.data = data;
    }

    _chart.isFitBarsEnabled = true;
    _chart.invalidate();
  }

  /// `getColors()`: the first three of ColorTemplate.MATERIAL_COLORS.
  List<Color> _getColors() => ColorTemplate.MATERIAL_COLORS.take(3).toList();

  /// res/menu/bar.xml.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Toggle Bar Borders', () {
      for (final set in _chart.data?.dataSets ?? const <IBarDataSet>[]) {
        (set as BarDataSet).barBorderWidth = set.barBorderWidth == 1 ? 0 : 1;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Rounded Sections', () {
      for (final dataSet in _chart.data?.dataSets ?? const <IBarDataSet>[]) {
        final set = dataSet as BarDataSet;
        set.isStackSectionsRounded = !set.isStackSectionsRounded;
        set.barCornerRadius = set.isStackSectionsRounded ? 6 : 0;
      }
      _chart.invalidate();
    }),
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
    title: 'Stacked',
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
