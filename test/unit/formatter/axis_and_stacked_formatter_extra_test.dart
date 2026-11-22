// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for DefaultAxisValueFormatter, the
// IAxisValueFormatter.fromFunction wrapper, StackedValueFormatter on a non-bar entry, or the edge cases
// below. Checks them against the Kotlin source.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/components/axis_base.dart';
import 'package:mp_flutter_chart/src/components/x_axis.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/formatter/default_axis_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/i_axis_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/i_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/index_axis_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/large_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/percent_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/stacked_value_formatter.dart';
import 'package:mp_flutter_chart/src/graphics/decimal_format.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

void main() {
  final axis = XAxis();
  final entry = Entry(x: 0, y: 0);
  final viewPortHandler = ViewPortHandler();

  test('DefaultAxisValueFormatter uses the requested digits', () {
    expect(
      DefaultAxisValueFormatter(2).getFormattedValue(1234.5, axis),
      '1,234.50',
    );
    expect(
      DefaultAxisValueFormatter(0).getFormattedValue(1234.6, axis),
      '1,235',
    );
    expect(
      DefaultAxisValueFormatter(-1).getFormattedValue(1234.6, axis),
      '1,235',
    );
    expect(DefaultAxisValueFormatter(2).decimalDigits, 2);
    expect(DefaultAxisValueFormatter(-1).decimalDigits, -1);
  });

  test('IAxisValueFormatter.fromFunction passes value and axis through', () {
    AxisBase? seen;
    final formatter = IAxisValueFormatter.fromFunction((value, a) {
      seen = a;
      return 'v$value';
    });
    expect(formatter.getFormattedValue(1.5, axis), 'v1.5');
    expect(seen, same(axis));
  });

  test(
    'IndexAxisValueFormatter rounds like Kotlin roundToInt and survives infinities',
    () {
      final formatter = IndexAxisValueFormatter(['Jan', 'Feb']);
      // Math.round rounds half up towards +infinity: -0.5 -> 0, and toInt(-0.5) is 0 too.
      expect(formatter.getFormattedValue(-0.5, axis), 'Jan');
      expect(formatter.getFormattedValue(-0.4, axis), 'Jan');
      expect(formatter.getFormattedValue(0.4, axis), 'Jan');
      expect(formatter.getFormattedValue(0.5, axis), '');
      expect(formatter.getFormattedValue(double.infinity, axis), '');
      expect(formatter.getFormattedValue(double.negativeInfinity, axis), '');

      final empty = IndexAxisValueFormatter();
      expect(empty.values, isEmpty);
      expect(empty.getFormattedValue(0, axis), '');
      empty.values = ['A'];
      expect(empty.getFormattedValue(0, axis), 'A');
    },
  );

  test('LargeValueFormatter appendix, value-formatter path and edges', () {
    final formatter = LargeValueFormatter(' €');
    expect(formatter.appendix, ' €');
    expect(formatter.getFormattedValue(5821, axis), '5.8k €');
    expect(
      formatter.getFormattedValue(5821, entry, 0, viewPortHandler),
      '5.8k €',
    );
    expect(formatter.decimalDigits, 0);
    expect(formatter.getFormattedValue(double.nan, axis), 'NaN €');
    expect(formatter.getFormattedValue(double.infinity, axis), 'Infinity €');
    expect(
      formatter.getFormattedValue(double.negativeInfinity, axis),
      '-Infinity €',
    );

    final plain = LargeValueFormatter();
    expect(plain.suffix, ['', 'k', 'm', 'b', 't']);
    // A value that would print as 1,000 moves on to the next suffix.
    expect(plain.getFormattedValue(999.6, axis), '1k');
    expect(plain.getFormattedValue(-999.6, axis), '-1k');
    expect(plain.getFormattedValue(999.4, axis), '999');
    expect(plain.getFormattedValue(99.96, axis), '100');
    // Beyond the last suffix the number is written out.
    expect(plain.getFormattedValue(1e18, axis), '1,000,000t');
  });

  test('PercentFormatter takes a custom format and reports its digits', () {
    expect(PercentFormatter().decimalDigits, 1);
    final formatter = PercentFormatter(DecimalFormat('#.##'));
    expect(formatter.decimalDigits, 2);
    expect(formatter.getFormattedValue(1.5, axis), '1.5 %');
    expect(
      formatter.getFormattedValue(1.5, entry, 0, viewPortHandler),
      '1.5 %',
    );
    expect(
      formatter.getStackedFormattedValue(1.5, 0, entry, 0, viewPortHandler),
      '1.5 %',
    );
  });

  test('Percent and Large formatters work through both interfaces', () {
    final IValueFormatter value = PercentFormatter();
    final IAxisValueFormatter axisFormatter = PercentFormatter();
    expect(value.getFormattedValue(50, entry, 0, viewPortHandler), '50.0 %');
    expect(axisFormatter.getFormattedValue(50, axis), '50.0 %');

    final IValueFormatter largeValue = LargeValueFormatter();
    final IAxisValueFormatter largeAxis = LargeValueFormatter();
    expect(
      largeValue.getFormattedValue(5821, entry, 0, viewPortHandler),
      '5.8k',
    );
    expect(largeAxis.getFormattedValue(5821, axis), '5.8k');
  });

  test(
    'StackedValueFormatter with drawWholeStack formats every stack value as it is, by position too',
    () {
      final stack = BarEntry.stacked(x: 0, stackValues: [1, 2, 2]);
      final whole = StackedValueFormatter(true, ' kg', 1);
      expect(
        [
          for (var i = 0; i < 3; i++)
            whole.getStackedFormattedValue(
              stack.stackValues![i],
              i,
              stack,
              0,
              viewPortHandler,
            ),
        ],
        ['1.0 kg', '2.0 kg', '2.0 kg'],
      );
      expect(
        whole.getStackedFormattedValue(5, 0, stack, 0, viewPortHandler),
        '5.0 kg',
        reason: 'the value given, not the entry total or the stack value',
      );
      expect(
        whole.getStackedFormattedValue(
          1234.5,
          9,
          BarEntry(x: 0, y: 3),
          0,
          viewPortHandler,
        ),
        '1,234.5 kg',
      );
    },
  );

  test('StackedValueFormatter formats a non-bar entry as it is', () {
    final topOnly = StackedValueFormatter(false, ' kg', 1);
    expect(topOnly.getFormattedValue(2, entry, 0, viewPortHandler), '2.0 kg');
    expect(
      topOnly.getStackedFormattedValue(2, 1, entry, 0, viewPortHandler),
      '2.0 kg',
    );
    final whole = StackedValueFormatter(true, '', 0);
    expect(whole.getFormattedValue(1234.6, entry, 0, viewPortHandler), '1,235');
  });
}
