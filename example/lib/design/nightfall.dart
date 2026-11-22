// The Nightfall design of MPChartExample (design/Nightfall.kt): the dark and light variant ([Nightfall.dark],
// [Nightfall.light]), the series palette and withAlpha, plus the dark-only constants and widgets the chart pages share.
// The faithful ports of NightfallStyle.kt and PillMarkerView.kt are nightfall_style.dart and
// custom/pill_marker_view.dart, used by the "All chart types" pages. Unlike NightfallStyle's nightfallBase,
// nightfallSetup keeps drag, zoom, double-tap zoom and the legend, so the other pages can be used to try the gestures
// inside a scrolling list.
//
// Kotlin's `Nightfall` is both the variant (instance members `stage`, `card`, …) and its companion (`palette`, `dark`,
// `light`, `withAlpha`). Dart does not allow a static and an instance member of the same name in one class, and the
// pages use `Nightfall.stage` & co. as constants, so the variant is the class [NightfallTheme] and the companion is
// [Nightfall].
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

/// The drag start of a scrollable that hosts charts: a swipe that starts on a chart scrolls from the down, as one
/// from outside it does. The chart's recognizers join the gesture arena, so the list only wins at its touch slop, and
/// [DragStartBehavior.start] would drop the travel before it (about 21 px at 2.625).
const DragStartBehavior chartScrollDragStartBehavior = DragStartBehavior.down;

/// Colors of the Nightfall design in its dark or light variant, Kotlin's `Nightfall` instance. The two variants are
/// [Nightfall.dark] and [Nightfall.light].
class NightfallTheme {
  const NightfallTheme._({
    required this.isDark,
    required this.stage,
    required this.card,
    required this.text,
    required this.muted,
    required this.grid,
    required this.track,
    required this.pillBackground,
    required this.pillText,
  });

  final bool isDark;
  final Color stage;
  final Color card;
  final Color text;
  final Color muted;
  final Color grid;
  final Color track;
  final Color pillBackground;
  final Color pillText;
}

/// Kotlin's `Nightfall` companion: the series palette, the two variants and [withAlpha]; and, as constants for the
/// chart pages, the colours of the dark variant (equal to [dark]'s).
abstract final class Nightfall {
  static const Color stage = Color(0xFF0F172A);
  static const Color card = Color(0xFF111C33);
  static const Color text = Color(0xFFE2E8F0);
  static const Color muted = Color(0xFF94A3B8);
  static const Color grid = Color.fromARGB(36, 148, 163, 184);
  static const Color track = Color.fromARGB(26, 148, 163, 184);
  static const Color pillBackground = Color(0xFFE2E8F0);
  static const Color pillText = Color(0xFF0F172A);
  static const Color accent = Color(0xFF2FB4B6);
  static const Color coral = Color(0xFFF97066);
  static const Color amber = Color(0xFFF5B041);
  static const Color violet = Color(0xFF8B7CF6);
  static const Color green = Color(0xFF5DD39E);

  /// The series colours in order.
  static const List<Color> palette = [accent, coral, amber, violet, green];

  /// The dark variant.
  static const NightfallTheme dark = NightfallTheme._(
    isDark: true,
    stage: Color(0xFF0F172A),
    card: Color(0xFF111C33),
    text: Color(0xFFE2E8F0),
    muted: Color(0xFF94A3B8),
    grid: Color.fromARGB(36, 148, 163, 184),
    track: Color.fromARGB(26, 148, 163, 184),
    pillBackground: Color(0xFFE2E8F0),
    pillText: Color(0xFF0F172A),
  );

  /// The light variant.
  static const NightfallTheme light = NightfallTheme._(
    isDark: false,
    stage: Color(0xFFF8FAFC),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF0F172A),
    muted: Color(0xFF64748B),
    grid: Color(0xFFE2E8F0),
    track: Color(0xFFEEF2F7),
    pillBackground: Color(0xFF0F172A),
    pillText: Color(0xFFFFFFFF),
  );

  /// [color] with its alpha replaced by [alpha], 0 to 255: `Color.argb(alpha, red, green, blue)`.
  static Color withAlpha(Color color, int alpha) => color.withAlpha(alpha);
}

/// Chart styling, run once before the data is set: the Nightfall base look without its gesture restrictions, with the
/// legend in the text colour and a faint horizontal grid on the left axis only.
void nightfallSetup(BarLineChartBase chart) {
  chart.description.isEnabled = false;
  chart.noDataTextColor = Nightfall.muted;
  chart.isPinchZoomEnabled = true;
  chart.setExtraOffsets(0, 8, 8, 4);

  chart.legend.textColor = Nightfall.text;

  chart.xAxis
    ..position = XAxisPosition.BOTTOM
    ..isDrawAxisLineEnabled = false
    ..isDrawGridLinesEnabled = false
    ..textColor = Nightfall.muted
    ..textSize = 10
    ..yOffset = 8
    ..granularity = 1;

  chart.axisLeft
    ..isDrawAxisLineEnabled = false
    ..textColor = Nightfall.muted
    ..textSize = 10
    ..gridColor = Nightfall.grid
    ..gridLineWidth = 1
    ..xOffset = 10;

  chart.axisRight.isEnabled = false;
}

/// A rounded card with a title and a subtitle above [children].
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Nightfall.card,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Nightfall.text,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Nightfall.muted, fontSize: 12),
          ),
          ...children,
        ],
      ),
    ),
  );
}

/// The marker content: a rounded pill in the pill colours, as Nightfall's PillMarkerView.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Nightfall.pillBackground,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Nightfall.pillText,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    ),
  );
}

/// A filled button in one of the series colours.
class ExampleButton extends StatelessWidget {
  const ExampleButton(this.label, this.color, this.onPressed, {super.key});

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Nightfall.stage,
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}

/// Zoom, visible x range and selection of the chart, as [controller] reports them.
class StatusLine extends StatelessWidget {
  const StatusLine(this.controller, {super.key});

  final ChartController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Text(
      _status(controller),
      style: const TextStyle(color: Nightfall.muted, fontSize: 13),
    ),
  );

  static String _status(ChartController c) {
    final selected = c.selectedEntry;
    final zoom =
        'zoom ${c.zoomX.toStringAsFixed(2)} x ${c.zoomY.toStringAsFixed(2)}'
        ' · x ${c.lowestVisibleX.toStringAsFixed(1)}–${c.highestVisibleX.toStringAsFixed(1)}';
    return selected == null
        ? '$zoom · tap a point to select it'
        : '$zoom · selected x ${selected.x.toStringAsFixed(0)}: ${selected.y.toStringAsFixed(1)}';
  }
}

/// Plain content that makes the list scroll, so the chart's drags can be tried inside a list: on a bar-line chart a
/// vertical drag scrolls the list while the chart is fully zoomed out and pans the chart once it is zoomed in.
class Filler extends StatelessWidget {
  const Filler(this.label, {super.key, required this.height});

  final String label;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Nightfall.track,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Nightfall.muted, fontSize: 14),
    ),
  );
}
