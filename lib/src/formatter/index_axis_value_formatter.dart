// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/formatter/IndexAxisValueFormatter.kt
import '../components/axis_base.dart';
import '../utils/float_math.dart';
import 'i_axis_value_formatter.dart';

/// Shows a fixed label per whole x value, taking the label at index x from [values]. Use it on the x-axis when the
/// x values are indices into a list of names, together with an `AxisBase.granularity` of 1.
class IndexAxisValueFormatter extends IAxisValueFormatter {
  /// The labels, one per whole x value starting at 0.
  List<String> values;

  /// Creates a formatter showing [values]; index 0 is shown at x = 0.
  IndexAxisValueFormatter([this.values = const []]);

  /// Returns the label at the index nearest to [value], or an empty string when that index is outside [values] or
  /// [value] has a fraction of 0.5 or more.
  @override
  String getFormattedValue(double value, AxisBase axis) {
    if (value.isNaN) return '';
    final index = _roundToInt(value);
    if (index != kotlinFloatToInt(value)) return '';
    return index >= 0 && index < values.length ? values[index] : '';
  }
}

/// Kotlin `Float.roundToInt()` for a non-NaN [value]: `Math.round`, which rounds half up towards positive infinity
/// (-0.5 gives 0, unlike Dart's `round()`), saturating at the Int range instead of throwing on the infinities.
int _roundToInt(double value) {
  final floor = value.floorToDouble();
  return kotlinFloatToInt(value - floor >= 0.5 ? floor + 1 : floor);
}
