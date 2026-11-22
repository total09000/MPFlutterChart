// Android shim: Paint.measureText / StaticLayout text layout (cached) for MPAndroidChart v4.0.1 port
import 'dart:collection';

import 'package:flutter/painting.dart';

/// A least-recently-used cache of laid out [TextPainter]s, so drawing and measuring the same label every frame
/// does not lay it out again.
///
/// Every text measurement and every `drawText` of the port goes through [layout].
abstract final class TextMeasure {
  /// The maximum number of laid out texts that are kept.
  static const int maxEntries = 512;

  static final LinkedHashMap<(String, TextStyle, double?, int?), TextPainter>
  _cache = LinkedHashMap<(String, TextStyle, double?, int?), TextPainter>();

  /// The number of laid out texts currently cached.
  static int get cacheSize => _cache.length;

  /// Returns [text] in [style] laid out left to right, at most [maxWidth] wide (unbounded when null) and with at
  /// most [maxLines] lines (unlimited when null).
  ///
  /// Calls with an equal text, style, width and line limit return the same instance. The returned painter is shared:
  /// do not change or dispose it, and do not keep it past the current frame, because it may be evicted.
  static TextPainter layout(
    String text,
    TextStyle style, {
    double? maxWidth,
    int? maxLines,
  }) {
    final key = (text, style, maxWidth, maxLines);
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth ?? double.infinity);

    _cache[key] = painter;
    if (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    return painter;
  }

  /// Drops every cached layout.
  static void clearCache() => _cache.clear();
}
