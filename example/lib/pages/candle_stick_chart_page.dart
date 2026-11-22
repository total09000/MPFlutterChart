// Ported from MPChartExample: CandleStickChartActivity.kt, with res/layout/activity_candlechart.xml and
// res/menu/candle.xml.
//
// Other Charts / Candlestick: random candles on a white chart, falling ones filled red and rising ones outlined green,
// with a seek bar for the number of candles and one for their base value. Not ported: the "View on GitHub" and "Save
// to Gallery" menu items (see notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/demo_drawables.dart';
import '../notimportant/demo_base.dart';

/// CandleStickChartActivity.
class CandleStickChartPage extends StatefulWidget {
  const CandleStickChartPage({super.key});

  @override
  State<CandleStickChartPage> createState() => _CandleStickChartPageState();
}

class _CandleStickChartPageState extends State<CandleStickChartPage> with DemoBase {
  /// `binding.chart1`.
  final CandleStickChartView _chart = CandleStickChartView();

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 40;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 100;

  @override
  void initState() {
    super.initState();

    // setBackgroundColor(Color.WHITE) is the ColoredBox in build.
    _chart
      ..description.isEnabled = false
      ..maxVisibleCount = 60
      ..isPinchZoomEnabled = false
      ..isDrawGridBackgroundEnabled = false;

    _chart.xAxis
      ..position = XAxisPosition.BOTTOM
      ..isDrawGridLinesEnabled = false;

    _chart.axisLeft
      ..labelCount = 7
      ..isDrawGridLinesEnabled = false
      ..isDrawAxisLineEnabled = false;

    _chart.axisRight.isEnabled = false;

    // Setting the progress of the seek bars calls onProgressChanged, which sets the data.
    _onProgressChanged();

    _chart.legend.isEnabled = false;
  }

  /// `onProgressChanged`: new random candles for the progress of the two seek bars.
  void _onProgressChanged() {
    final count = _seekBar1;

    _chart.resetTracking();

    final values = <CandleEntry>[];

    for (var i = 0; i < count; i++) {
      final multi = (_seekBar2 + 1).toDouble();
      final value = mathRandom() * 40 + multi;

      final high = mathRandom() * 9 + 8;
      final low = mathRandom() * 9 + 8;

      final open = mathRandom() * 6 + 1;
      final close = mathRandom() * 6 + 1;

      final even = i % 2 == 0;

      values.add(
        CandleEntry(
          x: i.toDouble(),
          high: value + high,
          low: value - low,
          open: even ? value + open : value - open,
          close: even ? value - close : value + close,
          icon: starDrawable,
        ),
      );
    }

    final set1 = CandleDataSet(values, 'Data Set')
      ..isDrawIconsEnabled = false
      ..axisDependency = AxisDependency.LEFT
      ..shadowColor = const Color(0xFF444444)
      ..shadowWidth = 0.7
      ..decreasingColor = const Color(0xFFFF0000)
      ..decreasingPaintStyle = PaintStyle.FILL
      ..increasingColor = const Color.fromARGB(255, 122, 242, 84)
      ..increasingPaintStyle = PaintStyle.STROKE
      ..neutralColor = const Color(0xFF0000FF);

    final data = CandleData([set1]);

    _chart.data = data;
    _chart.invalidate();
  }

  /// res/menu/candle.xml.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Toggle Values', () {
      for (final set in _chart.data?.dataSets ?? const <ICandleDataSet>[]) {
        set.isDrawValuesEnabled = !set.isDrawValuesEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Icons', () {
      for (final set in _chart.data?.dataSets ?? const <ICandleDataSet>[]) {
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
    DemoMenuItem('Toggle Shadow Color', () {
      for (final set in _chart.data?.dataSets ?? const <ICandleDataSet>[]) {
        (set as CandleDataSet).shadowColorSameAsCandle = !set.shadowColorSameAsCandle;
      }
      _chart.invalidate();
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
    title: 'Candlestick',
    menu: _menu,
    body: Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: demoChartBackground,
            child: ChartHostWidget<CandleStickChartView, CandleData>(chart: _chart, data: _chart.data),
          ),
        ),
        DemoSeekBar(
          progress: _seekBar1,
          max: 3000,
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
