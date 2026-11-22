// Tests for the ColorTemplate port (colors as dart:ui Color); no Kotlin counterpart.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/utils/color_template.dart';

void main() {
  test('sentinels keep the Kotlin int values', () {
    expect(ColorTemplate.COLOR_NONE.toARGB32(), 0x00112233);
    expect(ColorTemplate.COLOR_SKIP.toARGB32(), 0x00112234);
  });

  test('rgb parses hex with or without # into an opaque color', () {
    expect(ColorTemplate.rgb('#2ecc71').toARGB32(), 0xFF2ECC71);
    expect(ColorTemplate.rgb('2ecc71').toARGB32(), 0xFF2ECC71);
    // Like Kotlin, only the low 24 bits are used and the alpha is always opaque.
    expect(ColorTemplate.rgb('#80112233').toARGB32(), 0xFF112233);
    expect(() => ColorTemplate.rgb('#zz'), throwsFormatException);
  });

  test('colorWithAlpha replaces the alpha byte', () {
    final c = ColorTemplate.colorWithAlpha(const Color(0xFF112233), 0x40);
    expect(c.toARGB32(), 0x40112233);
    expect(
      ColorTemplate.colorWithAlpha(const Color(0x00112233), 0x1FF).toARGB32(),
      0xFF112233,
    );
  });

  test('templates', () {
    expect(ColorTemplate.LIBERTY_COLORS.first.toARGB32(), 0xFFCFF8F6);
    expect(ColorTemplate.JOYFUL_COLORS.length, 5);
    expect(ColorTemplate.PASTEL_COLORS.length, 5);
    expect(ColorTemplate.COLORFUL_COLORS.length, 5);
    expect(ColorTemplate.VORDIPLOM_COLORS.last.toARGB32(), 0xFFFF8C9D);
    expect(ColorTemplate.MATERIAL_COLORS.map((c) => c.toARGB32()), [
      0xFF2ECC71,
      0xFFF1C40F,
      0xFFE74C3C,
      0xFF3498DB,
    ]);
    expect(ColorTemplate.holoBlue.toARGB32(), 0xFF33B5E5);
    expect(
      () => ColorTemplate.MATERIAL_COLORS.add(const Color(0x00000000)),
      throwsUnsupportedError,
    );
  });
}
