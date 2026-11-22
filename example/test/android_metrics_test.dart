// Android's layout rounding as the "All chart types" pages emulate it: the dp → px pairs and the TextView line boxes
// measured on the Pixel 8 emulator (420 dpi, 2.625 px per dp) in the C2 comparison walk.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart_example/design/android_metrics.dart';

import 'support/baseline.dart';

/// The Pixel 8 emulator's density, 420 dpi / 160.
const double _dpr = 2.625;

void main() {
  group('androidDimensionPx', () {
    // Resources.getDimensionPixelSize at 2.625: (int) (dp * density + 0.5f).
    const pairs = <(double, int)>[
      (4, 11),
      (6, 16),
      (8, 21),
      (10, 26),
      (12, 32),
      (14, 37),
      (230, 604),
    ];
    for (final (dp, px) in pairs) {
      test('${dp.toInt()} dp is $px px at 2.625', () {
        expect(androidDimensionPixelSize(dp, _dpr), px);
        expect(androidDimensionPx(dp, _dpr) * _dpr, closeTo(px, 1e-9));
      });
    }

    test('rounds half up, as the cast of value + 0.5f does', () {
      // 1 dp is 2.625 px, 2 dp is 5.25 px and 6 dp is 15.75 px.
      expect(androidDimensionPixelSize(1, _dpr), 3);
      expect(androidDimensionPixelSize(2, _dpr), 5);
      expect(androidDimensionPixelSize(6, _dpr), 16);
      expect(androidDimensionPixelSize(1, 2.5), 3);
    });

    test('is at least 1 px for a non-zero value and 0 for zero', () {
      expect(androidDimensionPixelSize(0.1, _dpr), 1);
      expect(androidDimensionPixelSize(-0.1, _dpr), -1);
      expect(androidDimensionPixelSize(0, _dpr), 0);
      expect(androidDimensionPx(0.1, _dpr), closeTo(1 / _dpr, 1e-12));
    });

    test('is the dp unchanged at a whole density', () {
      for (final dp in [4.0, 6.0, 8.0, 10.0, 12.0, 14.0, 230.0]) {
        expect(androidDimensionPx(dp, 3), closeTo(dp, 1e-12), reason: '$dp');
      }
    });
  });

  group('androidTextViewLineHeight', () {
    test('15 sp is a 53 px line with its baseline 42 px down at 2.625', () {
      expect(androidTextViewLineHeight(15, _dpr) * _dpr, closeTo(53, 1e-9));
      expect(androidTextViewBaseline(15, _dpr) * _dpr, closeTo(42, 1e-9));
    });

    test('12 sp is a 43 px line with its baseline 34 px down at 2.625', () {
      expect(androidTextViewLineHeight(12, _dpr) * _dpr, closeTo(43, 1e-9));
      expect(androidTextViewBaseline(12, _dpr) * _dpr, closeTo(34, 1e-9));
    });

    test('the text size is android:textSize in whole px', () {
      // TextView reads android:textSize with getDimensionPixelSize: 15 sp is 39 px, 12 sp is 32 px.
      expect(androidTextSize(15, _dpr) * _dpr, closeTo(39, 1e-9));
      expect(androidTextSize(12, _dpr) * _dpr, closeTo(32, 1e-9));
      expect(androidTextSize(15, 3), closeTo(15, 1e-12));
    });

    test('scales the sp with the system font size before rounding', () {
      const scaler = TextScaler.linear(1.3);
      // 12 sp × 1.3 = 15.6 sp = 40.95 px → 41 px; top floor(-43.30) = -44, bottom ceil(11.11) = 12.
      expect(
        androidTextSize(12, _dpr, textScaler: scaler) * _dpr,
        closeTo(41, 1e-9),
      );
      expect(
        androidTextViewLineHeight(12, _dpr, textScaler: scaler) * _dpr,
        closeTo(56, 1e-9),
      );
      expect(
        androidTextViewBaseline(12, _dpr, textScaler: scaler) * _dpr,
        closeTo(44, 1e-9),
      );
    });
  });

  group('androidTextViewLinePitch', () {
    // Roboto's hhea ascender 1900 and descender -500 per 2048, each rounded as SkScalarRoundToInt rounds.
    test('15 sp is 36 + 10 = 46 px and 12 sp is 30 + 8 = 38 px at 2.625', () {
      // 39 px: ascent -36.18 → -36, descent 9.52 → 10. 32 px: ascent -29.69 → -30, descent 7.81 → 8.
      expect(androidTextViewLinePitch(15, _dpr) * _dpr, closeTo(46, 1e-9));
      expect(androidTextViewLinePitch(12, _dpr) * _dpr, closeTo(38, 1e-9));
    });

    test('scales the sp with the system font size before rounding', () {
      // 12 sp × 1.3 = 41 px: ascent -38.04 → -38, descent 10.01 → 10.
      expect(
        androidTextViewLinePitch(
              12,
              _dpr,
              textScaler: const TextScaler.linear(1.3),
            ) *
            _dpr,
        closeTo(48, 1e-9),
      );
    });

    test('rounds an ascent of exactly half a px up, as floor(x + 0.5) does', () {
      // At 1 px per dp, 256 sp is 256 px: ascent -237.5 → -237 and descent 62.5 → 63, where Dart's round() would
      // take the ascent to -238.
      expect(androidTextViewLinePitch(256, 1), closeTo(300, 1e-9));
    });
  });

  group('androidTextViewHeight', () {
    test('is the line box plus one pitch for each line after the first', () {
      expect(
        androidTextViewHeight(15, _dpr, lines: 1),
        androidTextViewLineHeight(15, _dpr),
      );
      expect(
        androidTextViewHeight(15, _dpr, lines: 2) * _dpr,
        closeTo(53 + 46, 1e-9),
      );
      expect(
        androidTextViewHeight(12, _dpr, lines: 3) * _dpr,
        closeTo(43 + 2 * 38, 1e-9),
      );
    });
  });

  group('androidTextViewWidth', () {
    test('rounds the text width up to a whole px, as TextView.onMeasure '
        'does', () {
      // 24.1 dp = 63.2625 px → 64 px; 24.4 dp = 64.05 px → 65 px.
      expect(androidTextViewWidth(24.1, _dpr) * _dpr, closeTo(64, 1e-9));
      expect(androidTextViewWidth(24.4, _dpr) * _dpr, closeTo(65, 1e-9));
      expect(androidTextViewWidth(0, _dpr), 0);
    });

    test('keeps a whole px through the 32-bit float of the logical width', () {
      // 64 px / 2.625 as a 32-bit float is 24.380952835083008, 64.0000012 px.
      expect(androidTextViewWidth(64 / _dpr, _dpr) * _dpr, closeTo(64, 1e-9));
      expect(
        androidTextViewWidth(24.380952835083008, _dpr) * _dpr,
        closeTo(64, 1e-9),
      );
    });
  });

  group('AndroidTextView', () {
    Future<void> pumpLine(
      WidgetTester tester, {
      TextScaler? scaler,
      String text = 'Revenue',
      TextStyle style = const TextStyle(fontWeight: FontWeight.bold),
      double? width,
    }) async {
      tester.view.devicePixelRatio = _dpr;
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(textScaler: scaler ?? TextScaler.noScaling),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: AndroidTextView(text, sp: 15, style: style),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('occupies the TextView line box with the text on its '
        'baseline', (tester) async {
      await pumpLine(tester);
      final box = tester.renderObject<RenderBox>(find.byType(AndroidTextView));

      expect(box.size.height * _dpr, closeTo(53, 1e-9));
      expect(
        baselineIn(tester, find.byType(AndroidTextView)) * _dpr,
        closeTo(42, 1e-9),
      );
      final text = tester.widget<Text>(find.text('Revenue'));
      expect(text.style!.fontSize! * _dpr, closeTo(39, 1e-9));
      expect(text.style!.fontWeight, FontWeight.bold);
      // The size is scaled once, before the rounding, so the Text does not scale it again.
      expect(text.textScaler, TextScaler.noScaling);
    });

    testWidgets('follows the system font size', (tester) async {
      await pumpLine(tester, scaler: const TextScaler.linear(2));
      final box = tester.renderObject<RenderBox>(find.byType(AndroidTextView));

      // 30 sp = 78.75 px → 79 px; top floor(-83.43) = -84, bottom ceil(21.41) = 22.
      expect(box.size.height * _dpr, closeTo(106, 1e-9));
      expect(
        baselineIn(tester, find.byType(AndroidTextView)) * _dpr,
        closeTo(84, 1e-9),
      );
      final text = tester.widget<Text>(find.text('Revenue'));
      expect(text.style!.fontSize! * _dpr, closeTo(79, 1e-9));
    });

    testWidgets('is as wide as its text rounded up to a whole px, with the '
        'text at its left', (tester) async {
      // The test font draws every glyph one em wide, here 39 px; the letter spacing (0.3 dp = 0.7875 px per glyph)
      // makes the line 7 × 39.7875 = 278.5125 px wide.
      await pumpLine(tester, style: const TextStyle(letterSpacing: 0.3));
      final box = tester.getRect(find.byType(AndroidTextView));
      final text = tester.getRect(find.byType(RichText));

      expect(text.width * _dpr, closeTo(278.5125, 1e-3));
      expect(box.width * _dpr, closeTo(279, 1e-9));
      expect(text.left, box.left);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a text exactly as wide as the space it has', (
      tester,
    ) async {
      // 'Revenue' is 7 × 39 = 273 px.
      await pumpLine(tester, width: 273 / _dpr);

      final box = tester.getSize(find.byType(AndroidTextView));
      expect(box.width * _dpr, closeTo(273, 1e-9));
      // Still one line.
      expect(box.height * _dpr, closeTo(53, 1e-9));
      expect(tester.takeException(), isNull);
    });

    testWidgets('wraps a text wider than its space onto a second line, in '
        "a box as tall as Android's", (tester) async {
      // 'Revenue Revenue' is 15 × 39 = 585 px; in 400 px it breaks after the space.
      await pumpLine(tester, text: 'Revenue Revenue', width: 400 / _dpr);
      final box = tester.getSize(find.byType(AndroidTextView));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      final lineTops = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 15),
          )
          .map((line) => line.top)
          .toSet()
          .toList();

      // 53 px for the first line and one 46 px pitch for the second; the wrapped text is as wide as the parent.
      expect(box.height * _dpr, closeTo(99, 1e-9));
      expect(box.width * _dpr, closeTo(400, 1e-9));
      expect(
        baselineIn(tester, find.byType(AndroidTextView)) * _dpr,
        closeTo(42, 1e-9),
      );
      // Flutter rounds a paragraph's line height to a whole logical px, so the second line sits 46 px rounded to a
      // whole logical px below the first: 18 logical px, 47.25 px.
      expect(lineTops, hasLength(2));
      expect(
        (lineTops[1] - lineTops[0]) * _dpr,
        closeTo((46 / _dpr).roundToDouble() * _dpr, 1e-3),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
