// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for utils/FileUtils.kt. Checks the assets
// loaders (the only ones ported) against the Kotlin source: "y#x" lines, lines with three or more values
// as stacked bars, read errors logged and yielding an empty list, malformed lines throwing.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/utils/file_utils.dart';

class _FakeBundle extends AssetBundle {
  _FakeBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw FlutterError('Unable to load asset: "$key".');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final text = files[key];
    if (text == null) throw FlutterError('Unable to load asset: "$key".');
    return text;
  }
}

void main() {
  test('loadEntriesFromAssets reads y#x lines', () async {
    final bundle = _FakeBundle({'data.txt': '10#0\n12.5#1\r\n-3#2\n'});
    final entries = await FileUtils.loadEntriesFromAssets(bundle, 'data.txt');
    expect(entries.length, 3);
    expect(entries[0].x, 0);
    expect(entries[0].y, 10);
    expect(entries[1].x, 1);
    expect(entries[1].y, closeTo(12.5, 1e-4));
    expect(entries[2].x, 2);
    expect(entries[2].y, -3);
  });

  test('loadEntriesFromAssets reads longer lines as stacked bars', () async {
    final bundle = _FakeBundle({'stacks.txt': '5#1\n1#2#3\n'});
    final entries = await FileUtils.loadEntriesFromAssets(bundle, 'stacks.txt');
    expect(entries.length, 2);
    expect(entries[0], isNot(isA<BarEntry>()));
    final stacked = entries[1] as BarEntry;
    expect(stacked.stackValues, [1, 2]);
    expect(stacked.x, 3);
    expect(stacked.y, 3);
  });

  test('the x of a stacked line must be a whole number', () async {
    await expectLater(
      FileUtils.loadEntriesFromAssets(
        _FakeBundle({'a.txt': '1#2#3.5'}),
        'a.txt',
      ),
      throwsFormatException,
    );
  });

  // Kotlin's `String.toInt()` takes an optional sign and decimal digits within the 32-bit `Int` range, and throws a
  // NumberFormatException for anything else; Dart's `int.parse` also trims whitespace and reads a 0x prefix.
  test('the x of a stacked line is read as Kotlin reads an Int', () async {
    Future<double> stackedX(String x) async {
      final entries = await FileUtils.loadEntriesFromAssets(
        _FakeBundle({'a.txt': '1#2#$x'}),
        'a.txt',
      );
      return entries.single.x;
    }

    expect(await stackedX('+3'), 3);
    expect(await stackedX('-3'), -3);
    expect(await stackedX('007'), 7);
    expect(await stackedX('2147483647'), 2147483647);
    expect(await stackedX('-2147483648'), -2147483648);

    for (final x in [
      ' 3',
      '3 ',
      '\t3',
      '0x3',
      '+',
      '-',
      '',
      '+-3',
      '3e2',
      '2147483648',
      '-2147483649',
      '99999999999999999999',
    ]) {
      await expectLater(
        stackedX(x),
        throwsFormatException,
        reason: 'x ${x.replaceAll('\t', r'\t')}',
      );
    }
  });

  test('loadBarEntriesFromAssets reads y#x lines as bars', () async {
    final bundle = _FakeBundle({'bars.txt': '1#0\n2#1\n'});
    final entries = await FileUtils.loadBarEntriesFromAssets(
      bundle,
      'bars.txt',
    );
    expect(entries.length, 2);
    expect(entries[0].x, 0);
    expect(entries[0].y, 1);
    expect(entries[1].x, 1);
    expect(entries[1].y, 2);
    expect(entries[1].isStacked, isFalse);

    // As in Kotlin, values after the second are ignored rather than stacked.
    final longer = await FileUtils.loadBarEntriesFromAssets(
      _FakeBundle({'longer.txt': '4#2#9'}),
      'longer.txt',
    );
    expect(longer.single.x, 2);
    expect(longer.single.y, 4);
    expect(longer.single.isStacked, isFalse);
  });

  test(
    'loadBarEntriesFromAssets logs a missing asset and throws on malformed lines',
    () async {
      final logged = <String?>[];
      final previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => logged.add(message);
      try {
        final entries = await FileUtils.loadBarEntriesFromAssets(
          _FakeBundle({}),
          'missing.txt',
        );
        expect(entries, isEmpty);
      } finally {
        debugPrint = previous;
      }
      expect(logged, hasLength(1));
      expect(logged.single, contains('MPChart-FileUtils'));

      await expectLater(
        FileUtils.loadBarEntriesFromAssets(
          _FakeBundle({'a.txt': 'abc#1'}),
          'a.txt',
        ),
        throwsFormatException,
      );
      await expectLater(
        FileUtils.loadBarEntriesFromAssets(
          _FakeBundle({'b.txt': '12'}),
          'b.txt',
        ),
        throwsRangeError,
      );
    },
  );

  test('a missing asset is logged and yields an empty list', () async {
    final logged = <String?>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logged.add(message);
    try {
      final entries = await FileUtils.loadEntriesFromAssets(
        _FakeBundle({}),
        'missing.txt',
      );
      expect(entries, isEmpty);
    } finally {
      debugPrint = previous;
    }
    expect(logged, hasLength(1));
    expect(logged.single, contains('MPChart-FileUtils'));
  });

  test('malformed lines throw', () async {
    await expectLater(
      FileUtils.loadEntriesFromAssets(_FakeBundle({'a.txt': 'abc#1'}), 'a.txt'),
      throwsFormatException,
    );
    await expectLater(
      FileUtils.loadEntriesFromAssets(_FakeBundle({'b.txt': '12'}), 'b.txt'),
      throwsRangeError,
    );
  });
}
