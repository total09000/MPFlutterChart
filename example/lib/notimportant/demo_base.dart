// Ported from MPChartExample: notimportant/DemoBase.kt, the base class of the chart Activities, with what their
// layouts and menus share.
//
// An Activity is a page here: a StatefulWidget whose State mixes in [DemoBase], owns its chart (a `LineChartView`,
// `BarChartView`, …) and builds a [DemoScaffold]. `onCreate` is `initState`, which configures the chart and sets its
// data, and the page shows the chart with a `ChartHostWidget` that gets `data: chart.data`, so the widget leaves the
// data the page set alone. An animation `onCreate` starts goes into the host's `setup`, because a chart animates only
// once a widget shows it. The options menu is [DemoScaffold.menu], a SeekBar with its value text a [DemoSeekBar].
//
// Not ported: the "View on GitHub" and "Save to Gallery" menu items, with `saveToGallery` and the storage permission
// (they need a URL launcher and a gallery plugin), the hidden status bar and the Activity transitions. `Math.random()`
// is [DemoBase.random], a generator with a fixed seed, so every run of a page shows the same data. `Log.i` is
// [logI].
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/nightfall.dart';

/// DemoBase's `months`.
const List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// DemoBase's `parties`.
const List<String> parties = [
  'Party A', 'Party B', 'Party C', 'Party D', 'Party E', 'Party F', 'Party G', 'Party H', //
  'Party I', 'Party J', 'Party K', 'Party L', 'Party M', 'Party N', 'Party O', 'Party P', //
  'Party Q', 'Party R', 'Party S', 'Party T', 'Party U', 'Party V', 'Party W', 'Party X', //
  'Party Y', 'Party Z',
];

/// The font family of the Open Sans faces in `assets/fonts/`.
const String openSans = 'OpenSans';

/// DemoBase's `tfRegular`, `Typeface.createFromAsset(assets, "OpenSans-Regular.ttf")`.
const Typeface tfRegular = Typeface(fontFamily: openSans);

/// DemoBase's `tfLight`, `Typeface.createFromAsset(assets, "OpenSans-Light.ttf")`.
const Typeface tfLight = Typeface(fontFamily: openSans, weight: FontWeight.w300);

/// `Typeface.createFromAsset(assets, "OpenSans-Bold.ttf")`.
const Typeface tfBold = Typeface(fontFamily: openSans, weight: FontWeight.w700);

/// Android's `Color.WHITE`, the background most Activities give their chart.
const Color demoChartBackground = Color(0xFFFFFFFF);

/// The window background of the Activities' theme, Theme.AppCompat.Light.
const Color demoWindowBackground = Color(0xFFFAFAFA);

/// `Log.i(tag, message)`: a line in the developer log, which a debugger shows and tests do not print.
void logI(String tag, String message) => developer.log(message, name: tag);

/// What the State of a page takes from DemoBase.
mixin DemoBase<T extends StatefulWidget> on State<T> {
  /// The generator behind `Math.random()` and [getRandom], seeded with [randomSeed].
  late final math.Random random = math.Random(randomSeed);

  /// The seed of [random]; a page overrides it to get other numbers.
  int get randomSeed => 0;

  /// `Math.random()`: a value from 0 inclusive to 1 exclusive.
  double mathRandom() => random.nextDouble();

  /// DemoBase's `getRandom(range, start)`.
  double getRandom(double range, double start) => mathRandom() * range + start;

  /// `Toast.makeText(applicationContext, message, Toast.LENGTH_SHORT).show()`, as a snack bar.
  void toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }
}

/// An item of an Activity's options menu: its title from res/values/strings.xml and what
/// `onOptionsItemSelected` does for it.
class DemoMenuItem {
  const DemoMenuItem(this.title, this.onSelected);

  /// The text of the item.
  final String title;

  /// Runs when the item is chosen.
  final VoidCallback onSelected;
}

/// The frame of a page: the action bar with [title] and the overflow menu of [menu], above [body] on the light
/// window background of the Activities.
class DemoScaffold extends StatelessWidget {
  const DemoScaffold({super.key, required this.title, this.menu = const [], required this.body});

  /// The title in the action bar: the name of the page's entry in the home list.
  final String title;

  /// The options menu, in the order of the Activity's res/menu file; empty for no overflow button.
  final List<DemoMenuItem> menu;

  /// The Activity's layout.
  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: demoWindowBackground,
    appBar: AppBar(
      title: Text(title),
      backgroundColor: Nightfall.card,
      foregroundColor: Nightfall.text,
      actions: [
        if (menu.isNotEmpty)
          PopupMenuButton<DemoMenuItem>(
            icon: const Icon(Icons.more_vert),
            onSelected: (item) => item.onSelected(),
            itemBuilder: (context) => [for (final item in menu) PopupMenuItem(value: item, child: Text(item.title))],
          ),
      ],
    ),
    body: Theme(
      data: ThemeData(brightness: Brightness.light, colorSchemeSeed: Nightfall.accent),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Color(0xFF212121)),
        child: SafeArea(child: body),
      ),
    ),
  );
}

/// A SeekBar with the TextView to its right that shows its value, as the Activities' layouts pair them (`seekBar1`
/// with `tvXMax`, `seekBar2` with `tvYMax`).
class DemoSeekBar extends StatelessWidget {
  const DemoSeekBar({
    super.key,
    required this.progress,
    required this.max,
    required this.onProgressChanged,
    this.text,
    this.textWidth = 50,
    this.textSize = 18,
  });

  /// `SeekBar.progress`, from 0 to [max].
  final int progress;

  /// `SeekBar.max`.
  final int max;

  /// `OnSeekBarChangeListener.onProgressChanged` for a change by the user, with the new progress.
  final ValueChanged<int> onProgressChanged;

  /// The text of the TextView; the progress when null.
  final String? text;

  /// The `layout_width` of the TextView, 50dp in most layouts.
  final double textWidth;

  /// The text size of the TextView: 18sp for `textAppearanceMedium`, which most layouts use, 14sp for
  /// `textAppearanceSmall`.
  final double textSize;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Slider(
          value: progress.clamp(0, max).toDouble(),
          max: max.toDouble(),
          onChanged: (value) {
            final next = value.round();
            if (next != progress) onProgressChanged(next);
          },
        ),
      ),
      SizedBox(
        width: textWidth,
        child: Text(text ?? '$progress', textAlign: TextAlign.right, style: TextStyle(fontSize: textSize)),
      ),
      const SizedBox(width: 10),
    ],
  );
}
