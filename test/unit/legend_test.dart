// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/LegendTest.kt
//
// Kotlin's Int colors 0xFF0000 and 0 have alpha 0; they are ported as the Colors with the same ARGB value.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/components/legend.dart';
import 'package:mp_flutter_chart/src/components/legend_entry.dart';

void main() {
  test('assigningEntriesMakesTheLegendCustomUntilReset', () {
    final legend = Legend();
    expect(legend.isLegendCustom, isFalse);

    legend.entries = [LegendEntry('Custom')];
    expect(legend.isLegendCustom, isTrue);
    expect(legend.entries[0].label, 'Custom');

    legend.resetCustom();
    expect(legend.isLegendCustom, isFalse);

    legend.setExtra(
      [const Color(0x00FF0000), const Color(0x00000000)],
      ['red', 'hidden'],
    );
    expect(legend.extraEntries.length, 2);
    expect(legend.extraEntries[1].form, LegendForm.NONE);
  });
}
