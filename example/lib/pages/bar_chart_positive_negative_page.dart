// Ported from MPChartExample: BarChartPositiveNegative.kt, with res/layout/activity_barchart_noseekbar.xml and
// res/menu/only_github.xml.
//
// Bar Charts / Negative: five fixed values, the positive bars red and the negative ones green, each labelled with its
// value in the bar's colour, a dated x axis and a zero line instead of y axis labels. Not ported: the "View on GitHub"
// menu item, the only item of the menu, so the page has no overflow menu (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// Android's `Color.LTGRAY`.
const Color _lightGray = Color(0xFFCCCCCC);

/// Android's `Color.GRAY`.
const Color _gray = Color(0xFF888888);

/// BarChartPositiveNegative.
class BarChartPositiveNegativePage extends StatefulWidget {
  const BarChartPositiveNegativePage({super.key});

  @override
  State<BarChartPositiveNegativePage> createState() => _BarChartPositiveNegativePageState();
}

class _BarChartPositiveNegativePageState extends State<BarChartPositiveNegativePage> with DemoBase {
  /// `binding.chart1`.
  final BarChartView _chart = BarChartView();

  /// `barSet`: the data set, created by the first call of [_setData].
  BarDataSet? _barSet;

  @override
  void initState() {
    super.initState();

    final data = [
      const _Data(0, -224.1, '12-29'),
      const _Data(1, 238.5, '12-30'),
      const _Data(2, 1280.1, '12-31'),
      const _Data(3, -442.3, '01-01'),
      const _Data(4, -2280.1, '01-02'),
    ];

    _chart
      ..extraTopOffset = -30
      ..extraBottomOffset = 10
      ..extraLeftOffset = 70
      ..extraRightOffset = 70
      ..isDrawBarShadowEnabled = false
      ..isDrawValueAboveBarEnabled = true
      ..description.isEnabled = false
      ..isPinchZoomEnabled = false
      ..isDrawGridBackgroundEnabled = false;

    _chart.xAxis
      ..position = XAxisPosition.BOTTOM
      ..typeface = tfRegular
      ..isDrawGridLinesEnabled = false
      ..isDrawAxisLineEnabled = false
      ..textColor = _lightGray
      ..textSize = 13
      ..labelCount = 5
      ..isCenterAxisLabelsEnabled = true
      ..granularity = 1
      ..valueFormatter = IAxisValueFormatter.fromFunction(
        (value, _) => data[value.toInt().clamp(0, data.length - 1)].xAxisValue,
      );

    _chart.axisLeft
      ..isDrawLabelsEnabled = false
      ..spaceTop = 25
      ..spaceBottom = 25
      ..isDrawAxisLineEnabled = false
      ..isDrawGridLinesEnabled = false
      ..isDrawZeroLineEnabled = true
      ..zeroLineColor = _gray
      ..zeroLineWidth = 0.7;
    _chart.axisRight.isEnabled = false;
    _chart.legend.isEnabled = false;

    _setData(data);
  }

  /// `setData`: a bar per item of [dataList], red when its value is positive or zero and green when negative.
  void _setData(List<_Data> dataList) {
    final values = <BarEntry>[];
    final colors = <Color>[];

    const green = Color.fromARGB(255, 110, 190, 102);
    const red = Color.fromARGB(255, 211, 74, 88);

    for (final d in dataList) {
      values.add(BarEntry(x: d.xValue, y: d.yValue));
      colors.add(d.yValue >= 0 ? red : green);
    }

    final existing = _barSet;
    if (existing != null) {
      existing.entries = values;
      _chart.notifyDataSetChanged();
    } else {
      final set = BarDataSet(values, 'Values');
      _barSet = set;
      set
        ..colors = colors
        ..valueTextColors = colors;

      final data = BarData([set])
        ..setValueTextSize(13)
        ..setValueTypeface(tfRegular)
        ..setValueFormatter(_ValueFormatter())
        ..barWidth = 0.8;

      _chart.data = data;
      _chart.invalidate();
    }
  }

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Negative',
    body: ColoredBox(
      color: demoChartBackground,
      child: ChartHostWidget<BarChartView, BarData>(chart: _chart, data: _chart.data),
    ),
  );
}

/// BarChartPositiveNegative's `Data`: the x value, the y value and the x axis label of a bar.
class _Data {
  const _Data(this.xValue, this.yValue, this.xAxisValue);

  final double xValue;
  final double yValue;
  final String xAxisValue;
}

/// BarChartPositiveNegative's `ValueFormatter`: the value with one decimal.
class _ValueFormatter extends IValueFormatter {
  final DecimalFormat _format = DecimalFormat('######.0');

  @override
  String getFormattedValue(double value, Entry entry, int dataSetIndex, ViewPortHandler viewPortHandler) =>
      _format.format(value);
}
