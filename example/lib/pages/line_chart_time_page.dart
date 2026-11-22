// Ported from MPChartExample: LineChartTime.kt, with res/layout/activity_linechart_time.xml and res/menu/line.xml.
//
// Line Charts / Hourly: one value per hour from the current hour on, with the date and hour of each label inside the
// top of the chart and a seek bar for the number of hours. The clock is [LineChartTimePage.now], `DateTime.now` unless
// a test passes another. The x axis labels are `SimpleDateFormat("dd MMM HH:mm", Locale.ENGLISH)` written out by
// hand: a two-digit day, the English month abbreviation and a 24-hour time, in the device's time zone as on Android;
// with the English locale fixed in Kotlin, the text is the same on every device. Not ported: the "View on GitHub" and
// "Save to Gallery" menu items (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// LineChartTime.
class LineChartTimePage extends StatefulWidget {
  const LineChartTimePage({super.key, this.now = DateTime.now});

  /// `System.currentTimeMillis()`.
  final DateTime Function() now;

  @override
  State<LineChartTimePage> createState() => _LineChartTimePageState();
}

/// The x axis formatter of LineChartTime: the x value is a number of hours since the epoch.
class _HourAxisValueFormatter implements IAxisValueFormatter {
  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  String getFormattedValue(double value, AxisBase axis) {
    // TimeUnit.HOURS.toMillis(value.toLong())
    final millis = value.toInt() * Duration.millisecondsPerHour;
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${_twoDigits(date.day)} ${months[date.month - 1]} ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
  }
}

class _LineChartTimePageState extends State<LineChartTimePage> with DemoBase {
  /// `binding.chart1`.
  final LineChartView _chart = LineChartView();

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 100;

  @override
  void initState() {
    super.initState();

    _chart
      ..description.isEnabled = false
      ..isTouchEnabled = true
      ..dragDecelerationFrictionCoef = 0.9
      ..isDragEnabled = true
      ..isScaleEnabled = true
      ..isDrawGridBackgroundEnabled = false
      ..isHighlightPerDragEnabled = true
      ..setViewPortOffsets(0, 0, 0, 0);

    // Setting the progress of the seek bar calls onProgressChanged, which sets the data.
    _onProgressChanged();

    _chart.legend.isEnabled = false;

    _chart.xAxis
      ..position = XAxisPosition.TOP_INSIDE
      ..typeface = tfLight
      ..textSize = 10
      ..textColor = const Color(0xFFFFFFFF)
      ..isDrawAxisLineEnabled = false
      ..isDrawGridLinesEnabled = true
      ..textColor = const Color.fromARGB(255, 255, 192, 56)
      ..isCenterAxisLabelsEnabled = true
      ..granularity = 1
      ..valueFormatter = _HourAxisValueFormatter();

    _chart.axisLeft
      ..labelPosition = YAxisLabelPosition.INSIDE_CHART
      ..typeface = tfLight
      ..textColor = ColorTemplate.holoBlue
      ..isDrawGridLinesEnabled = true
      ..isGranularityEnabled = true
      ..axisMinimum = 0
      ..axisMaximum = 170
      ..yOffset = -9
      ..textColor = const Color.fromARGB(255, 255, 192, 56);

    _chart.axisRight.isEnabled = false;
  }

  void _setData(int count, double range) {
    // TimeUnit.MILLISECONDS.toHours(System.currentTimeMillis())
    final now = widget.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerHour;

    final values = <Entry>[];

    final to = (now + count).toDouble();

    for (var x = now.toDouble(); x < to; x++) {
      final y = getRandom(range, 50);
      values.add(Entry(x: x, y: y));
    }

    final set1 = LineDataSet(values, 'DataSet 1')
      ..axisDependency = AxisDependency.LEFT
      ..color = ColorTemplate.holoBlue
      ..valueTextColor = ColorTemplate.holoBlue
      ..lineWidth = 1.5
      ..isDrawCirclesEnabled = false
      ..isDrawValuesEnabled = false
      ..fillAlpha = 65
      ..fillColor = ColorTemplate.holoBlue
      ..highlightColor = const Color.fromARGB(255, 244, 117, 117)
      ..isDrawCircleHoleEnabled = false;

    final data = LineData([set1])
      ..setValueTextColor(const Color(0xFFFFFFFF))
      ..setValueTextSize(9);

    _chart.data = data;
  }

  /// `onProgressChanged`: new data for the progress of the seek bar.
  void _onProgressChanged() {
    _setData(_seekBar1, 50);

    _chart.invalidate();
  }

  Iterable<LineDataSet> get _lineDataSets => _chart.data?.dataSets.whereType<LineDataSet>() ?? const [];

  void _toggleMode(LineDataSetMode mode) {
    for (final set in _lineDataSets) {
      set.mode = set.mode == mode ? LineDataSetMode.LINEAR : mode;
    }
    _chart.invalidate();
  }

  /// res/menu/line.xml; an item `onOptionsItemSelected` has no branch for does nothing, as in Kotlin.
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
      for (final set in _lineDataSets) {
        set.isDrawCirclesEnabled = !set.isDrawCirclesEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Cubic', () => _toggleMode(LineDataSetMode.CUBIC_BEZIER)),
    DemoMenuItem('Toggle Stepped', () => _toggleMode(LineDataSetMode.STEPPED)),
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
    title: 'Hourly',
    menu: _menu,
    body: Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: demoChartBackground,
            child: ChartHostWidget<LineChartView, LineData>(chart: _chart, data: _chart.data),
          ),
        ),
        DemoSeekBar(
          progress: _seekBar1,
          max: 1500,
          onProgressChanged: (progress) => setState(() {
            _seekBar1 = progress;
            _onProgressChanged();
          }),
        ),
      ],
    ),
  );
}
