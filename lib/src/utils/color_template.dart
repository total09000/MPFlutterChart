// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/utils/ColorTemplate.kt
import 'dart:ui';

/// Ready-made color lists for data sets and small color helpers.
///
/// The templates are plain lists of colors, so you can pass them to a data set's `colors`
/// directly or build your own list with as many colors as you like.
///
/// Kotlin's colors are ARGB ints; here they are `dart:ui` [Color]s. `createColors(Resources, List<Int>)`
/// is not ported: there are no Android color resources in Flutter.
abstract final class ColorTemplate {
  /// Sentinel meaning "no color set". Renderers that see it fall back to the data set color or
  /// skip drawing the element, for example candle colors, the line circle hole or the radar highlight stroke.
  static const Color COLOR_NONE = Color(0x00112233);

  /// Sentinel used in legend entries to skip drawing the form for that entry.
  static const Color COLOR_SKIP = Color(0x00112234);

  /// Five light blue and teal tones.
  static const List<Color> LIBERTY_COLORS = [
    Color.fromARGB(255, 207, 248, 246),
    Color.fromARGB(255, 148, 212, 212),
    Color.fromARGB(255, 136, 180, 187),
    Color.fromARGB(255, 118, 174, 175),
    Color.fromARGB(255, 42, 109, 130),
  ];

  /// Five strong pink, orange, yellow, green and cyan tones.
  static const List<Color> JOYFUL_COLORS = [
    Color.fromARGB(255, 217, 80, 138),
    Color.fromARGB(255, 254, 149, 7),
    Color.fromARGB(255, 254, 247, 120),
    Color.fromARGB(255, 106, 167, 134),
    Color.fromARGB(255, 53, 194, 209),
  ];

  /// Five muted blue, green, beige, rose and red tones.
  static const List<Color> PASTEL_COLORS = [
    Color.fromARGB(255, 64, 89, 128),
    Color.fromARGB(255, 149, 165, 124),
    Color.fromARGB(255, 217, 184, 162),
    Color.fromARGB(255, 191, 134, 134),
    Color.fromARGB(255, 179, 48, 80),
  ];

  /// Five saturated red, orange, yellow, green and brown tones.
  static const List<Color> COLORFUL_COLORS = [
    Color.fromARGB(255, 193, 37, 82),
    Color.fromARGB(255, 255, 102, 0),
    Color.fromARGB(255, 245, 199, 0),
    Color.fromARGB(255, 106, 150, 31),
    Color.fromARGB(255, 179, 100, 53),
  ];

  /// Five light green, yellow, orange, blue and pink tones.
  static const List<Color> VORDIPLOM_COLORS = [
    Color.fromARGB(255, 192, 255, 140),
    Color.fromARGB(255, 255, 247, 140),
    Color.fromARGB(255, 255, 208, 140),
    Color.fromARGB(255, 140, 234, 255),
    Color.fromARGB(255, 255, 140, 157),
  ];

  /// Four material design tones: green, yellow, red and blue.
  static final List<Color> MATERIAL_COLORS = List<Color>.unmodifiable([
    rgb('#2ecc71'),
    rgb('#f1c40f'),
    rgb('#e74c3c'),
    rgb('#3498db'),
  ]);

  /// Parses a hex color string such as "#2ecc71" or "2ecc71" into an opaque color.
  ///
  /// Throws a [FormatException] (Kotlin: `NumberFormatException`) if [hex] is not a hexadecimal number.
  static Color rgb(String hex) {
    final color = int.parse(hex.replaceAll('#', ''), radix: 16);
    final r = (color >> 16) & 0xFF;
    final g = (color >> 8) & 0xFF;
    final b = color & 0xFF;
    return Color.fromARGB(255, r, g, b);
  }

  /// The light holo blue from Android 4, rgb(51, 181, 229).
  static Color get holoBlue => const Color.fromARGB(255, 51, 181, 229);

  /// Returns [color] with its alpha channel replaced by [alpha].
  ///
  /// [alpha] is 0 for fully transparent to 255 for fully opaque; like Kotlin, only its low byte is used.
  static Color colorWithAlpha(Color color, int alpha) {
    return color.withAlpha(alpha & 0xff);
  }
}
