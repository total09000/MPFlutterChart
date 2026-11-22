// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for DefaultFillFormatter, the fromFunction
// wrappers or Utils.defaultValueFormatter. Checks them against the Kotlin source.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/formatter/default_fill_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/default_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/i_fill_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/i_value_formatter.dart';
import 'package:mp_flutter_chart/src/interfaces/dataprovider/line_data_provider.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

/// A LineDataProvider with only the members DefaultFillFormatter reads.
class _Provider implements LineDataProvider {
  _Provider(this.lineData, {required this.yChartMin, required this.yChartMax});

  @override
  final LineData? lineData;

  @override
  final double yChartMin;

  @override
  final double yChartMax;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LineDataSet _set(List<double> ys) => LineDataSet([
  for (var i = 0; i < ys.length; i++) Entry(x: i.toDouble(), y: ys[i]),
], '');

void main() {
  test(
    'DefaultFillFormatter fills to zero, the axis minimum or the axis maximum',
    () {
      const formatter = DefaultFillFormatter();

      final crossing = _set([-1, 2]);
      expect(
        formatter.getFillLinePosition(
          crossing,
          _Provider(LineData([crossing]), yChartMin: -5, yChartMax: 5),
        ),
        0,
      );

      final positive = _set([1, 2]);
      expect(
        formatter.getFillLinePosition(
          positive,
          _Provider(LineData([positive]), yChartMin: 0.5, yChartMax: 3),
        ),
        0.5,
      );

      final negative = _set([-1, -2]);
      expect(
        formatter.getFillLinePosition(
          negative,
          _Provider(LineData([negative]), yChartMin: -3, yChartMax: -0.5),
        ),
        -0.5,
      );

      // A positive set in data that also has negative values fills to zero.
      expect(
        formatter.getFillLinePosition(
          positive,
          _Provider(
            LineData([positive, negative]),
            yChartMin: -3,
            yChartMax: 3,
          ),
        ),
        0,
      );

      expect(
        formatter.getFillLinePosition(
          positive,
          _Provider(null, yChartMin: 1, yChartMax: 2),
        ),
        0,
      );
    },
  );

  test('fromFunction wraps a lambda', () {
    final fill = IFillFormatter.fromFunction((dataSet, dataProvider) => 42);
    expect(
      fill.getFillLinePosition(
        _set([1]),
        _Provider(null, yChartMin: 0, yChartMax: 0),
      ),
      42,
    );

    final value = IValueFormatter.fromFunction(
      (value, entry, dataSetIndex, viewPortHandler) => '<$value>',
    );
    final e = Entry(x: 0, y: 0);
    expect(value.getFormattedValue(1.5, e, 0, ViewPortHandler()), '<1.5>');
    // The stacked default ignores the stack index.
    expect(
      value.getStackedFormattedValue(2.5, 3, e, 0, ViewPortHandler()),
      '<2.5>',
    );
  });

  test(
    'Utils.defaultValueFormatter has one decimal and data sets fall back to it',
    () {
      final formatter = Utils.defaultValueFormatter as DefaultValueFormatter;
      expect(formatter.decimalDigits, 1);
      expect(
        formatter.getFormattedValue(
          1234.56,
          Entry(x: 0, y: 0),
          0,
          ViewPortHandler(),
        ),
        '1,234.6',
      );

      final set = _set([1]);
      expect(set.needsFormatter, isTrue);
      expect(set.valueFormatter, same(Utils.defaultValueFormatter));
      final custom = DefaultValueFormatter(0);
      set.valueFormatter = custom;
      expect(set.needsFormatter, isFalse);
      expect(set.valueFormatter, same(custom));
    },
  );

  test('decimalPattern caps the digits at 45', () {
    expect(decimalPattern(0), '');
    expect(decimalPattern(-3), '');
    expect(decimalPattern(2), '.00');
    expect(decimalPattern(1000), '.${'0' * 45}');
    expect(
      DefaultValueFormatter(
        1000,
      ).getFormattedValue(0.5, Entry(x: 0, y: 0), 0, ViewPortHandler()),
      '0.5${'0' * 44}',
    );
  });
}
