// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/BarEntry.kt
import '../highlight/range.dart';
import 'entry.dart';

/// Entry for a bar chart. A bar is either a single value in [y] or a stack of values in [stackValues].
///
/// [D] is the type of the payload stored in [data]. Kotlin's positional constructors and its payload-less
/// `BarEntry(x, y, icon)` / `BarEntry(x, stackValues, icon)` factories are the named constructors [BarEntry.new] and
/// [BarEntry.stacked], with `data` optional.
class BarEntry<D> extends Entry<D> {
  /// Creates a single, unstacked bar at [x] (position on the x axis in value space) with height [y], an optional
  /// [icon] drawn at the entry when icons are enabled and an optional [data] payload.
  BarEntry({required super.x, required super.y, super.icon, super.data});

  /// Creates a stacked bar at [x] whose [y] is the sum of [stackValues], the stack values bottom to top, with an
  /// optional [icon] drawn at the entry when icons are enabled and an optional [data] payload for the whole stack.
  BarEntry.stacked({
    required super.x,
    required List<double> stackValues,
    super.icon,
    super.data,
  }) : super(y: _calcSum(stackValues)) {
    this.stackValues = stackValues;
  }

  List<double>? _stackValues;

  /// Values of a stacked bar, drawn bottom to top in list order, or null for a single bar.
  /// Assigning them sets [y] to their sum and recomputes [positiveSum], [negativeSum] and [ranges].
  List<double>? get stackValues => _stackValues;

  set stackValues(List<double>? value) {
    _stackValues = value;
    y = _calcSum(value);
    _calcPosNegSum();
    _calcRanges();
  }

  List<Range>? _ranges;

  /// Start and end on the y axis of each stack value, in the order of [stackValues]. Positive values stack
  /// upwards from zero, negative values downwards. Null until stack values have been set.
  List<Range>? get ranges => _ranges;

  double _negativeSum = 0;

  /// Sum of the absolute values of all negative stack values, so a positive number. 0 for a single bar.
  double get negativeSum => _negativeSum;

  double _positiveSum = 0;

  /// Sum of all positive stack values. 0 for a single bar.
  double get positiveSum => _positiveSum;

  /// Returns a new entry with the same values. The stack list, icon and payload are shared, not copied.
  ///
  /// As in Kotlin, the stack is assigned to the copy even when it is null, and assigning a null stack sets [y] to
  /// the sum of no values: the copy of a single, unstacked bar has a [y] of 0.
  @override
  BarEntry<D> copy() {
    final copied = BarEntry<D>(x: x, y: y, icon: icon, data: data);
    copied.stackValues = stackValues;
    return copied;
  }

  /// True when this entry holds stack values, even if the stack has only one value.
  bool get isStacked => stackValues != null;

  /// Sums the stack values that come after [stackIndex] in [stackValues].
  ///
  /// Returns the sum, or 0 for an unstacked entry.
  double getSumBelow(int stackIndex) {
    final vals = stackValues;
    if (vals == null) return 0;
    var remainder = 0.0;
    var index = vals.length - 1;
    while (index > stackIndex && index >= 0) {
      remainder += vals[index];
      index--;
    }
    return remainder;
  }

  void _calcPosNegSum() {
    final vals = stackValues;
    if (vals == null) {
      _negativeSum = 0;
      _positiveSum = 0;
      return;
    }
    var sumNeg = 0.0;
    var sumPos = 0.0;
    for (final f in vals) {
      if (f <= 0) {
        sumNeg += f.abs();
      } else {
        sumPos += f;
      }
    }
    _negativeSum = sumNeg;
    _positiveSum = sumPos;
  }

  void _calcRanges() {
    final values = stackValues;
    if (values == null || values.isEmpty) {
      _ranges = null;
      return;
    }
    var negRemain = -negativeSum;
    var posRemain = 0.0;
    final ranges = <Range>[];
    for (final value in values) {
      if (value < 0) {
        ranges.add(Range(negRemain, negRemain - value));
        negRemain -= value;
      } else {
        ranges.add(Range(posRemain, posRemain + value));
        posRemain += value;
      }
    }
    _ranges = ranges;
  }
}

double _calcSum(List<double>? vals) {
  if (vals == null) return 0;
  var sum = 0.0;
  for (final f in vals) {
    sum += f;
  }
  return sum;
}
