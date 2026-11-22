// Ported from MPChartExample: PieChartActivity.kt, with res/layout/activity_piechart.xml and res/menu/pie.xml.
//
// Pie Charts / Basic: a donut of "Election Results" with one slice per party in percent, a seek bar for the number of
// slices and one for their range, and the options menu of pie.xml. Not ported: the spans of the center text, a
// SpannableString in Kotlin (1.7 times the size on "MPAndroidChart", gray at 0.8 times the size on "developed by",
// italic holo blue on "Philipp Jahoda"), because `PieChart.centerText` is a String here and the whole text is drawn in
// the center text paint's tfLight; the "View on GitHub" and "Save to Gallery" menu items (see
// notimportant/demo_base.dart).
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../custom/demo_drawables.dart';
import '../notimportant/demo_base.dart';

/// PieChartActivity.
class PieChartPage extends StatefulWidget {
  const PieChartPage({super.key});

  @override
  State<PieChartPage> createState() => _PieChartPageState();
}

class _PieChartPageState extends State<PieChartPage> with DemoBase {
  /// `binding.chart1`.
  final PieChartView _chart = PieChartView();

  /// `binding.seekBar1.progress`.
  int _seekBar1 = 4;

  /// `binding.seekBar2.progress`.
  int _seekBar2 = 10;

  @override
  void initState() {
    super.initState();

    _chart
      ..isUsePercentValuesEnabled = true
      ..description.isEnabled = false
      ..setExtraOffsets(5, 10, 5, 5)
      ..dragDecelerationFrictionCoef = 0.95
      ..centerTextTypeface = tfLight
      ..centerText = _generateCenterText()
      ..isDrawHoleEnabled = true
      ..holeColor = const Color(0xFFFFFFFF)
      ..transparentCircleColor = const Color(0xFFFFFFFF)
      ..transparentCircleAlpha = 110
      ..holeRadius = 58
      ..transparentCircleRadius = 61
      ..isDrawCenterTextEnabled = true
      ..rotationAngle = 0
      ..isRotationEnabled = true
      ..isHighlightPerTapEnabled = true
      ..onValueSelected(
        (entry, highlight) => logI(
          'VAL SELECTED',
          'Value: ${entry.y}, index: ${highlight.x}, DataSet index: ${highlight.dataSetIndex}',
        ),
        onNothingSelected: () => logI('PieChart', 'nothing selected'),
      );

    // Setting the progress of the seek bars calls onProgressChanged, which sets the data.
    _onProgressChanged();

    // animateY(1400, Easing.EaseInOutQuad) runs in the host's setup, once the chart is shown.

    _chart.legend
      ..verticalAlignment = LegendVerticalAlignment.TOP
      ..horizontalAlignment = LegendHorizontalAlignment.RIGHT
      ..orientation = LegendOrientation.VERTICAL
      ..isDrawInsideEnabled = false
      ..xEntrySpace = 7
      ..yEntrySpace = 0
      ..yOffset = 0;

    _chart
      ..entryLabelColor = const Color(0xFFFFFFFF)
      ..entryLabelTypeface = tfRegular
      ..entryLabelTextSize = 12;
  }

  /// `onProgressChanged`: new data for the progress of the two seek bars.
  void _onProgressChanged() => _setData(_seekBar1, _seekBar2.toDouble());

  /// `setData(count, range)`.
  void _setData(int count, double range) {
    final entries = <PieEntry>[
      for (var i = 0; i < count; i++)
        PieEntry(mathRandom() * range + range / 5, label: parties[i % parties.length], icon: starDrawable),
    ];

    final dataSet = PieDataSet(entries, 'Election Results')
      ..isDrawIconsEnabled = false
      ..sliceSpace = 3
      ..iconsOffset = MPPointF(0, 40)
      ..selectionShift = 5
      ..colors = [
        ...ColorTemplate.VORDIPLOM_COLORS,
        ...ColorTemplate.JOYFUL_COLORS,
        ...ColorTemplate.COLORFUL_COLORS,
        ...ColorTemplate.LIBERTY_COLORS,
        ...ColorTemplate.PASTEL_COLORS,
        ColorTemplate.holoBlue,
      ];

    final data = PieData(dataSet)
      ..setValueFormatter(PercentFormatter())
      ..setValueTextSize(11)
      ..setValueTextColor(const Color(0xFFFFFFFF))
      ..setValueTypeface(tfLight);
    _chart.data = data;

    _chart.highlightValues([]);

    _chart.invalidate();
  }

  /// `generateCenterSpannableText()` without its spans.
  String _generateCenterText() => 'MPAndroidChart\ndeveloped by Philipp Jahoda';

  /// res/menu/pie.xml.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Toggle Y-Values', () {
      for (final set in _chart.data?.dataSets ?? const <IPieDataSet>[]) {
        set.isDrawValuesEnabled = !set.isDrawValuesEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle X-Values', () {
      _chart.isDrawEntryLabelsEnabled = !_chart.isDrawEntryLabelsEnabled;
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Icons', () {
      for (final set in _chart.data?.dataSets ?? const <IPieDataSet>[]) {
        set.isDrawIconsEnabled = !set.isDrawIconsEnabled;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Percent', () {
      _chart.isUsePercentValuesEnabled = !_chart.isUsePercentValuesEnabled;
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Minimum Angles', () {
      _chart.minAngleForSlices = _chart.minAngleForSlices == 0 ? 36 : 0;
      _chart.notifyDataSetChanged();
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Hole', () {
      _chart.isDrawHoleEnabled = !_chart.isDrawHoleEnabled;
      _chart.invalidate();
    }),
    DemoMenuItem('Toggle Curved Slices', () {
      final toSet = !_chart.isDrawRoundedSlicesEnabled || !_chart.isDrawHoleEnabled;
      _chart.isDrawRoundedSlicesEnabled = toSet;
      if (toSet && !_chart.isDrawHoleEnabled) {
        _chart.isDrawHoleEnabled = true;
      }
      if (toSet && _chart.isDrawSlicesUnderHoleEnabled) {
        _chart.isDrawSlicesUnderHoleEnabled = false;
      }
      _chart.invalidate();
    }),
    DemoMenuItem('Draw Center Text', () {
      _chart.isDrawCenterTextEnabled = !_chart.isDrawCenterTextEnabled;
      _chart.invalidate();
    }),
    DemoMenuItem(
      'Spin Animation',
      () => _chart.spin(1000, _chart.rotationAngle, _chart.rotationAngle + 360, easing: Easing.EaseInOutCubic),
    ),
    DemoMenuItem('Animate X', () => _chart.animateX(1400)),
    DemoMenuItem('Animate Y', () => _chart.animateY(1400)),
    DemoMenuItem('Animate XY', () => _chart.animateXY(1400, 1400)),
  ];

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Basic',
    menu: _menu,
    body: Column(
      children: [
        Expanded(
          child: ChartHostWidget<PieChartView, PieData>(
            chart: _chart,
            data: _chart.data,
            setup: (chart) => chart.animateY(1400, easing: Easing.EaseInOutQuad),
          ),
        ),
        DemoSeekBar(
          progress: _seekBar1,
          max: 25,
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
