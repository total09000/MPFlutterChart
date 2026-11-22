// Ported from MPChartExample: fragments/SimpleChartDemo.kt, with res/layout/activity_awesomedesign.xml and
// res/menu/only_github.xml.
//
// Scrolling Charts / View Pager: five charts on the pages of a ViewPager, which is a PageView here, and a fragment is
// a widget (fragments/): sine and cosine, complexity, bars, scatter and pie, in PageAdapter's order. The dialog
// onCreate shows is a Material AlertDialog shown after the first frame.
//
// Not ported: the "View on GitHub" menu item (see notimportant/demo_base.dart), the only item of only_github.xml, so
// the page has no options menu. `offscreenPageLimit = 3` has no counterpart in PageView, which builds a page when it
// comes into view: instead a page is kept alive once it was built, so a fragment creates its chart and data once, as
// the retained fragments do, and each fragment has a generator of its own, seeded from its position, so its numbers do
// not depend on the order in which the pages are visited.
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Easing;

import '../design/nightfall.dart';
import '../fragments/bar_chart_frag.dart';
import '../fragments/complexity_fragment.dart';
import '../fragments/pie_chart_frag.dart';
import '../fragments/scatter_chart_frag.dart';
import '../fragments/sine_cosine_fragment.dart';
import '../notimportant/demo_base.dart';

/// SimpleChartDemo.
class SimpleChartDemoPage extends StatefulWidget {
  const SimpleChartDemoPage({super.key});

  @override
  State<SimpleChartDemoPage> createState() => _SimpleChartDemoPageState();
}

class _SimpleChartDemoPageState extends State<SimpleChartDemoPage> with DemoBase {
  /// PageAdapter's `getCount()`.
  static const int _count = 5;

  /// The `Math.random()` of the fragment at each position.
  late final List<math.Random> _randoms = [for (var i = 0; i < _count; i++) math.Random(randomSeed + i)];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('This is a ViewPager.'),
          content: const Text('Swipe left and right for more awesome design examples!'),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
    });
  }

  /// PageAdapter's `getItem(position)`.
  Widget _getItem(int position) {
    final random = _randoms[position];
    return switch (position) {
      0 => SineCosineFragment(random: random),
      1 => ComplexityFragment(random: random),
      2 => BarChartFrag(random: random),
      3 => ScatterChartFrag(random: random),
      _ => PieChartFrag(random: random),
    };
  }

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'View Pager',
    body: PageView.builder(
      dragStartBehavior: chartScrollDragStartBehavior,
      itemCount: _count,
      itemBuilder: (context, position) => _KeepAlive(key: ValueKey(position), child: _getItem(position)),
    ),
  );
}

/// Keeps a page of the PageView alive once it was built, as the ViewPager keeps its fragments.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({super.key, required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
