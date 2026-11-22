// Ported from MPChartExample: fragments/SimpleFragment.kt.
//
// The base of the pages of Scrolling Charts / View Pager: the data generators the fragments share. A fragment is a
// StatefulWidget here and its State extends [SimpleFragmentState], which has the generators. `Math.random()` is the
// fragment's [SimpleFragment.random], a seeded generator the page hands it, so every run shows the same numbers. The
// assets are read through `DefaultAssetBundle.of(context)`, so [SimpleFragmentState.generateLineData] and
// [SimpleFragmentState.getComplexity] complete later; a fragment calls them once, from `didChangeDependencies`.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// SimpleFragment.
abstract class SimpleFragment extends StatefulWidget {
  const SimpleFragment({super.key, required this.random});

  /// The generator behind `Math.random()` in the generators.
  final math.Random random;
}

/// The State of a [SimpleFragment], with SimpleFragment's generators.
abstract class SimpleFragmentState<T extends SimpleFragment> extends State<T> {
  /// `Typeface.createFromAsset(requireContext().assets, "OpenSans-Regular.ttf")`.
  final Typeface _tf = tfRegular;

  static const List<String> _labels = ['Company A', 'Company B', 'Company C', 'Company D', 'Company E', 'Company F'];

  /// `Math.random()`.
  double _mathRandom() => widget.random.nextDouble();

  @protected
  BarData generateBarData(int dataSets, double range, int count) {
    final sets = <IBarDataSet>[];
    for (var i = 0; i < dataSets; i++) {
      final entries = <BarEntry>[];
      for (var j = 0; j < count; j++) {
        entries.add(BarEntry(x: j.toDouble(), y: _mathRandom() * range + range / 4));
      }
      final ds = BarDataSet(entries, _labels[i])..colors = ColorTemplate.VORDIPLOM_COLORS.toList();
      sets.add(ds);
    }
    return BarData(sets)..setValueTypeface(_tf);
  }

  @protected
  ScatterData generateScatterData(int dataSets, double range, int count) {
    final sets = <IScatterDataSet>[];
    const shapes = ScatterShape.values;
    for (var i = 0; i < dataSets; i++) {
      final entries = <Entry>[];
      for (var j = 0; j < count; j++) {
        entries.add(Entry(x: j.toDouble(), y: _mathRandom() * range + range / 4));
      }
      final ds = ScatterDataSet(entries, _labels[i])
        ..scatterShapeSize = 6
        ..setScatterShape(shapes[i % shapes.length])
        ..colors = ColorTemplate.COLORFUL_COLORS.toList()
        ..scatterShapeSize = 4.5;
      sets.add(ds);
    }
    return ScatterData(sets)..setValueTypeface(_tf);
  }

  @protected
  PieData generatePieData() {
    const count = 4;
    final entries1 = <PieEntry>[];
    for (var i = 0; i < count; i++) {
      entries1.add(PieEntry(_mathRandom() * 60 + 40, label: 'Quarter ${i + 1}'));
    }
    final ds1 = PieDataSet(entries1, 'Quarterly Revenues 2015')
      ..colors = ColorTemplate.VORDIPLOM_COLORS.toList()
      ..sliceSpace = 2
      ..valueTextColor = const Color(0xFFFFFFFF)
      ..valueTextSize = 12;
    return PieData(ds1)..setValueTypeface(_tf);
  }

  @protected
  Future<LineData> generateLineData() async {
    final assets = DefaultAssetBundle.of(context);
    final sine = FileUtils.loadEntriesFromAssets(assets, 'assets/sine.txt');
    final cosine = FileUtils.loadEntriesFromAssets(assets, 'assets/cosine.txt');
    final ds1 = LineDataSet(await sine, 'Sine function')
      ..lineWidth = 2
      ..isDrawCirclesEnabled = false
      ..color = ColorTemplate.VORDIPLOM_COLORS[0];
    final ds2 = LineDataSet(await cosine, 'Cosine function')
      ..lineWidth = 2
      ..isDrawCirclesEnabled = false
      ..color = ColorTemplate.VORDIPLOM_COLORS[1];
    final sets = <ILineDataSet>[ds1, ds2];
    return LineData(sets)..setValueTypeface(_tf);
  }

  @protected
  Future<LineData> getComplexity() async {
    final assets = DefaultAssetBundle.of(context);
    const files = ['n.txt', 'nlogn.txt', 'square.txt', 'three.txt'];
    const names = ['O(n)', 'O(nlogn)', 'O(n²)', 'O(n³)'];
    final loads = [for (final file in files) FileUtils.loadEntriesFromAssets(assets, 'assets/$file')];
    final sets = <ILineDataSet>[];
    for (var i = 0; i < files.length; i++) {
      sets.add(
        LineDataSet(await loads[i], names[i])
          ..color = ColorTemplate.VORDIPLOM_COLORS[i]
          ..circleColor = ColorTemplate.VORDIPLOM_COLORS[i]
          ..lineWidth = 2.5
          ..circleRadius = 3,
      );
    }
    return LineData(sets)..setValueTypeface(_tf);
  }
}
