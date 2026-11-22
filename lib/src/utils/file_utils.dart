// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/utils/FileUtils.kt
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show AssetBundle;

import '../data/bar_entry.dart';
import '../data/entry.dart';

/// Loads entries from simple text assets, one entry per line with values separated by "#".
///
/// Read errors are logged and yield an empty or partial list instead of an exception.
/// Malformed lines are not tolerated and throw while parsing.
///
/// Only the assets loaders are ported: Kotlin's `loadEntriesFromFile` and `saveToSdCard` work on
/// external storage, which has no counterpart here. Assets are read through an [AssetBundle], for example
/// `rootBundle` or `DefaultAssetBundle.of(context)`, so loading is asynchronous.
abstract final class FileUtils {
  static const String _LOG = 'MPChart-FileUtils';

  /// Reads entries from an asset file, expecting "y#x" per line. Lines with three or more values
  /// become a `BarEntry` whose last value is the x value and the others are stack values.
  ///
  /// [am] is the bundle to read from and [path] the asset key. Throws a [FormatException] if a value is not a
  /// number, or the x of a stacked line not a whole number as Kotlin's `toInt()` reads one, and a [RangeError] if a
  /// line has no "#".
  static Future<List<Entry>> loadEntriesFromAssets(
    AssetBundle am,
    String path,
  ) async {
    final entries = <Entry>[];
    final String text;
    try {
      text = await am.loadString(path);
    } catch (e) {
      debugPrint('$_LOG: $e');
      return entries;
    }
    for (final line in const LineSplitter().convert(text)) {
      entries.add(_parseEntry(line, swapped: true));
    }
    return entries;
  }

  static Entry _parseEntry(String line, {required bool swapped}) {
    final split = line.split('#');
    if (split.length <= 2) {
      if (swapped) {
        return Entry(x: double.parse(split[1]), y: double.parse(split[0]));
      } else {
        return Entry(x: double.parse(split[0]), y: _toInt(split[1]).toDouble());
      }
    }
    final vals = List.generate(split.length - 1, (i) => double.parse(split[i]));
    return BarEntry.stacked(
      x: _toInt(split[split.length - 1]).toDouble(),
      stackValues: vals,
    );
  }

  /// Kotlin's `String.toInt()`: an optional `+` or `-` followed by decimal digits, within the 32-bit `Int` range.
  /// Throws a [FormatException] where Kotlin throws a `NumberFormatException`, which `int.parse` alone would not do
  /// for surrounding whitespace, a `0x` prefix or a value beyond the `Int` range. Only ASCII digits are read; the
  /// JVM's `Character.digit` would also read other Unicode decimal digits.
  static int _toInt(String s) {
    final value = _intPattern.hasMatch(s) ? int.tryParse(s) : null;
    if (value == null || value < _intMin || value > _intMax) {
      throw FormatException('Invalid number format', s);
    }
    return value;
  }

  static final RegExp _intPattern = RegExp(r'^[+-]?[0-9]+$');
  static const int _intMin = -0x80000000;
  static const int _intMax = 0x7fffffff;

  /// Reads bar entries from an asset file, expecting "y#x" per line.
  ///
  /// [am] is the bundle to read from and [path] the asset key. Throws a [FormatException] if a value is not a
  /// number and a [RangeError] if a line has no "#".
  static Future<List<BarEntry>> loadBarEntriesFromAssets(
    AssetBundle am,
    String path,
  ) async {
    final entries = <BarEntry>[];
    final String text;
    try {
      text = await am.loadString(path);
    } catch (e) {
      debugPrint('$_LOG: $e');
      return entries;
    }
    for (final line in const LineSplitter().convert(text)) {
      final split = line.split('#');
      entries.add(
        BarEntry(x: double.parse(split[1]), y: double.parse(split[0])),
      );
    }
    return entries;
  }
}
