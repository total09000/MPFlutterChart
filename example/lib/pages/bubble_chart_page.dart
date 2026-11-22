// Ported from MPChartExample: BubbleChartActivity.kt, with res/layout/activity_bubblechart.xml and
// res/menu/bubble.xml.
//
// Other Charts / Bubble Chart: three data sets of bubbles with random values and sizes on a white chart, with a seek
// bar for the number of entries and one for their range. Not ported: the "View on GitHub" and "Save to Gallery" menu
// items (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/demo_drawables.dart';
import '../notimportant/demo_base.dart';

/// BubbleChartActivity.
class BubbleChartPage extends StatefulWidget {
  const BubbleChartPage({super.key});

  @override
  State<BubbleChartPage> createState() => _BubbleChartPageState();
}

class _BubbleChartPageState extends State<BubbleChartPage> with DemoBase {
  /// `binding.chart1`.
  final BubbleChartView _chart = BubbleChartView();

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 10;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 50;

  @override
  void initState() {
    super.initState();

    _chart
      ..description.isEnabled = false
      ..onChartValueSelectedListener = OnChartValueSelectedListener.fromFunction(
        onValueSelected: (e, h) =>
            logI('VAL SELECTED', 'Value: ${e.y}, xIndex: ${e.x}, DataSet index: ${h.dataSetIndex}'),
        onNothingSelected: () {},
      )
      ..isDrawGridBackgroundEnabled = false
      ..isTouchEnabled = true
      ..isDragEnabled = true
      ..isScaleEnabled = true
      ..maxVisibleCount = 200
      ..isPinchZoomEnabled = true;

    // Setting the progress of the seek bars calls onProgressChanged, which sets the data.
    _onProgressChanged();

    _chart.legend
      ..verticalAlignment = LegendVerticalAlignment.TOP
      ..horizontalAlignment = LegendHorizontalAlignment.RIGHT
      ..orientation = LegendOrientation.VERTICAL
      ..isDrawInsideEnabled = false
      ..typeface = tfLight;

    _chart.axisLeft
      ..typeface = tfLight
      ..spaceTop = 30
      ..spaceBottom = 30
      ..isDrawZeroLineEnabled = false;

    _chart.axisRight.isEnabled = false;

    _chart.xAxis
      ..position = XAxisPosition.BOTTOM
      ..typeface = tfLight;
  }

  /// `onProgressChanged`: new random data for the progress of the two seek bars.
  void _onProgressChanged() {
    final count = _seekBar1;
    final range = _seekBar2;

    final values1 = <BubbleEntry>[];
    final values2 = <BubbleEntry>[];
    final values3 = <BubbleEntry>[];

    for (var i = 0; i < count; i++) {
      values1.add(
        BubbleEntry(x: i.toDouble(), y: mathRandom() * range, size: mathRandom() * range, icon: starDrawable),
      );
      values2.add(
        BubbleEntry(x: i.toDouble(), y: mathRandom() * range, size: mathRandom() * range, icon: starDrawable),
      );
      values3.add(BubbleEntry(x: i.toDouble(), y: mathRandom() * range, size: mathRandom() * range));
    }

    final set1 = BubbleDataSet(values1, 'DS 1')
      ..isDrawIconsEnabled = false
      ..setColor(ColorTemplate.COLORFUL_COLORS[0], 130)
      ..isDrawValuesEnabled = true;

    final set2 = BubbleDataSet(values2, 'DS 2')
      ..isDrawIconsEnabled = false
      ..iconsOffset = MPPointF(0, 15)
      ..setColor(ColorTemplate.COLORFUL_COLORS[1], 130)
      ..isDrawValuesEnabled = true;

    final set3 = BubbleDataSet(values3, 'DS 3')
      ..setColor(ColorTemplate.COLORFUL_COLORS[2], 130)
      ..isDrawValuesEnabled = true;

    final data = BubbleData([set1, set2, set3])
      ..setDrawValues(false)
      ..setValueTypeface(tfLight)
      ..setValueTextSize(8)
      ..setValueTextColor(const Color(0xFFFFFFFF))
      ..setHighlightCircleWidth(1.5);

    _chart.data = data;
    _chart.invalidate();
  }

  /// res/menu/bubble.xml.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Toggle Values', () {
      for (final set in _chart.data?.dataSets ?? const <IBubbleDataSet>[]) {
        set.isDrawValuesEnabled = !set.isDrawValuesEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Icons', () {
      for (final set in _chart.data?.dataSets ?? const <IBubbleDataSet>[]) {
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
    title: 'Bubble Chart',
    menu: _menu,
    body: Column(
      children: [
        Expanded(
          // android:background="@android:color/white"
          child: ColoredBox(
            color: demoChartBackground,
            child: ChartHostWidget<BubbleChartView, BubbleData>(chart: _chart, data: _chart.data),
          ),
        ),
        DemoSeekBar(
          progress: _seekBar1,
          max: 100,
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
