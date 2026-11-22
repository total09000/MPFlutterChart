// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/FormatterTest.kt
//
// Task 7 ported the DefaultValueFormatter cases, Task 8 the others; Phase 1 enabled the
// StackedValueFormatter cases, which need `BarEntry`. `Locale.setDefault(Locale.US)` has no counterpart: DecimalFormat
// always uses US symbols (see MIGRATION.md).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/components/x_axis.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/formatter/default_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/i_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/index_axis_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/large_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/percent_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/stacked_value_formatter.dart';
import 'package:mp_flutter_chart/src/graphics/decimal_format.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

class _ExposingFormatter extends DefaultValueFormatter {
  _ExposingFormatter(super.digits);

  DecimalFormat get current => format;
}

void main() {
  test('defaultValueFormatterUsesRequestedDigits', () {
    expect(
      DefaultValueFormatter(
        0,
      ).getFormattedValue(1234.4, Entry(x: 0, y: 0), 0, ViewPortHandler()),
      '1,234',
    );
    expect(
      DefaultValueFormatter(
        2,
      ).getFormattedValue(1234.4, Entry(x: 0, y: 0), 0, ViewPortHandler()),
      '1,234.40',
    );
  });

  test('defaultValueFormatterRebuildsOnlyWhenDigitsChange', () {
    final formatter = _ExposingFormatter(2);
    final built = formatter.current;
    formatter.setup(2);
    expect(formatter.current, same(built));
    formatter.setup(3);
    expect(formatter.current, isNot(same(built)));
    expect(
      formatter.getFormattedValue(1.5, Entry(x: 0, y: 0), 0, ViewPortHandler()),
      '1.500',
    );
  });

  test('percentFormatterAppendsPercentSign', () {
    expect(
      PercentFormatter().getFormattedValue(
        12.34,
        Entry(x: 0, y: 0),
        0,
        ViewPortHandler(),
      ),
      '12.3 %',
    );
    expect(PercentFormatter().getFormattedValue(12.34, XAxis()), '12.3 %');
  });

  test('stackedValueFormatterShowsOnlyTheTopOfAStack', () {
    final stack = BarEntry.stacked(x: 0, stackValues: [1, 2, 3]);
    final topOnly = StackedValueFormatter(false, ' kg', 1);
    expect(topOnly.getFormattedValue(1, stack, 0, ViewPortHandler()), '');
    expect(topOnly.getFormattedValue(3, stack, 0, ViewPortHandler()), '6.0 kg');
    final whole = StackedValueFormatter(true, '', 0);
    expect(whole.getFormattedValue(2, stack, 0, ViewPortHandler()), '2');
  });

  test('stackedValueFormatterTellsRepeatedValuesApartByPosition', () {
    final stack = BarEntry.stacked(x: 0, stackValues: [1, 2, 2]);
    final topOnly = StackedValueFormatter(false, ' kg', 1);
    expect(
      topOnly.getStackedFormattedValue(2, 1, stack, 0, ViewPortHandler()),
      '',
    );
    expect(
      topOnly.getStackedFormattedValue(2, 2, stack, 0, ViewPortHandler()),
      '5.0 kg',
    );
  });

  // Not in FormatterTest.kt: Kotlin compares two Floats; a value read back from a Float buffer (the bar renderers'
  // Float32List) still matches the top of a stack of doubles (A7).
  test('the top of a stack is matched at Float precision', () {
    final stack = BarEntry.stacked(x: 0, stackValues: [0.1, 0.2]);
    final topOnly = StackedValueFormatter(false, '', 2);
    final asFloat = Float32List.fromList([0.2])[0];
    expect(asFloat, isNot(0.2));
    expect(
      topOnly.getFormattedValue(asFloat, stack, 0, ViewPortHandler()),
      '0.30',
    );
    expect(topOnly.getFormattedValue(0.1, stack, 0, ViewPortHandler()), '');
  });

  test('indexAxisValueFormatterMapsWholeIndicesOnly', () {
    final formatter = IndexAxisValueFormatter(['Jan', 'Feb', 'Mar']);
    expect(formatter.getFormattedValue(1, XAxis()), 'Feb');
    expect(formatter.getFormattedValue(1.5, XAxis()), '');
    expect(formatter.getFormattedValue(3, XAxis()), '');
    expect(formatter.getFormattedValue(-1, XAxis()), '');
  });

  test('formattersSurviveEdgeValues', () {
    final labels = ['Jan', 'Feb', 'Mar'];
    final index = IndexAxisValueFormatter(labels);
    labels.removeAt(2);
    expect(index.getFormattedValue(2, XAxis()), '');
    expect(index.getFormattedValue(double.nan, XAxis()), '');

    final emptyStack = BarEntry.stacked(x: 0, stackValues: []);
    expect(
      StackedValueFormatter(
        false,
        '',
        0,
      ).getFormattedValue(1, emptyStack, 0, ViewPortHandler()),
      '',
    );

    final large = LargeValueFormatter();
    large.suffix = [];
    expect(large.getFormattedValue(5, XAxis()), '5');
  });

  // Not in FormatterTest.kt (task brief): locks Dart's `toStringAsFixed`, which rounds the exact binary value, for
  // users porting `String.format("%.2f", value)` formatters (Java prints 1.01 here). See MIGRATION.md.
  test('toStringAsFixed rounds the exact binary value', () {
    final formatter = IValueFormatter.fromFunction(
      (v, _, _, _) => v.toStringAsFixed(2),
    );
    expect(
      formatter.getFormattedValue(
        1.005,
        Entry(x: 0, y: 0),
        0,
        ViewPortHandler(),
      ),
      '1.00',
    );
  });
}
