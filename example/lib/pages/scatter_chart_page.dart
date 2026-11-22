// Ported from MPChartExample: ScatterChartActivity.kt, with res/layout/activity_scatterchart.xml and
// res/menu/scatter.xml.
//
// Other Charts / Scatter Plot: three data sets, squares, circles with a hole and the diagonal lines of
// CustomScatterShapeRenderer, offset by a third of an x unit each, with a seek bar for the number of entries and one
// for their range. Not ported: the "View on GitHub" and "Save to Gallery" menu items (see
// notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/custom_scatter_shape_renderer.dart';
import '../notimportant/demo_base.dart';

/// ScatterChartActivity.
class ScatterChartPage extends StatefulWidget {
  const ScatterChartPage({super.key});

  @override
  State<ScatterChartPage> createState() => _ScatterChartPageState();
}

class _ScatterChartPageState extends State<ScatterChartPage> with DemoBase {
  /// `binding.chart1`.
  final ScatterChartView _chart = ScatterChartView();

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 45;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 100;

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
      ..maxHighlightDistance = 50
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
      ..typeface = tfLight
      ..xOffset = 5;

    _chart.axisLeft
      ..typeface = tfLight
      ..axisMinimum = 0;

    _chart.axisRight.isEnabled = false;

    _chart.xAxis
      ..typeface = tfLight
      ..isDrawGridLinesEnabled = false;
  }

  /// `onProgressChanged`: new random data for the progress of the two seek bars.
  void _onProgressChanged() {
    final count = _seekBar1;
    final range = _seekBar2;

    final values1 = <Entry>[
      for (var i = 0; i < count; i++) Entry(x: i.toDouble(), y: mathRandom() * range + 3),
    ];
    final values2 = <Entry>[
      for (var i = 0; i < count; i++) Entry(x: i + 0.33, y: mathRandom() * range + 3),
    ];
    final values3 = <Entry>[
      for (var i = 0; i < count; i++) Entry(x: i + 0.66, y: mathRandom() * range + 3),
    ];

    final set1 = ScatterDataSet(values1, 'DS 1')
      ..setScatterShape(ScatterShape.SQUARE)
      ..color = ColorTemplate.COLORFUL_COLORS[0];
    final set2 = ScatterDataSet(values2, 'DS 2')
      ..setScatterShape(ScatterShape.CIRCLE)
      ..scatterShapeHoleColor = ColorTemplate.COLORFUL_COLORS[3]
      ..scatterShapeHoleRadius = 1.5
      ..color = ColorTemplate.COLORFUL_COLORS[1];
    final set3 = ScatterDataSet(values3, 'DS 3')
      ..shapeRenderer = CustomScatterShapeRenderer()
      ..color = ColorTemplate.COLORFUL_COLORS[2];

    set1.scatterShapeSize = 4;
    set2.scatterShapeSize = 4;
    set3.scatterShapeSize = 4;

    final data = ScatterData([set1, set2, set3])..setValueTypeface(tfLight);

    _chart.data = data;
    _chart.invalidate();
  }

  /// res/menu/scatter.xml; an item `onOptionsItemSelected` has no branch for does nothing, as in Kotlin.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Toggle Values', () {
      for (final set in _chart.data?.dataSets ?? const <IScatterDataSet>[]) {
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
    DemoMenuItem('Animate X', () => _chart.animateX(3000)),
    DemoMenuItem('Animate Y', () => _chart.animateY(3000)),
    DemoMenuItem('Animate XY', () => _chart.animateXY(3000, 3000)),
    DemoMenuItem('Toggle PinchZoom', () {
      _chart.isPinchZoomEnabled = !_chart.isPinchZoomEnabled;
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Auto Scale', () {
      _chart.isAutoScaleMinMaxEnabled = !_chart.isAutoScaleMinMaxEnabled;
      _chart.notifyDataSetChanged();
    }),
  ];

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Scatter Plot',
    menu: _menu,
    body: Column(
      children: [
        Expanded(child: ChartHostWidget<ScatterChartView, ScatterData>(chart: _chart, data: _chart.data)),
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
