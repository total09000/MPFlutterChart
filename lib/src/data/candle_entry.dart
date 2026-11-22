// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/CandleEntry.kt
import 'entry.dart';

/// Entry for a candle stick chart with the high, low, open and close values of one candle.
/// The inherited [y] is set once at construction to the middle between [high] and [low] and does not follow
/// later changes to those properties.
///
/// [D] is the type of the payload stored in [data]. Kotlin's positional constructor and its payload-less
/// `CandleEntry(x, high, low, open, close, icon)` factory are this constructor with named arguments, `data` optional.
class CandleEntry<D> extends Entry<D> {
  /// Creates a candle at [x] (position on the x axis in value space) with its [high], [low], [open] and [close]
  /// values, an optional [icon] drawn at the entry when icons are enabled and an optional [data] payload.
  CandleEntry({
    required super.x,
    required this.high,
    required this.low,
    required this.open,
    required this.close,
    super.icon,
    super.data,
  }) : super(y: (high + low) / 2);

  /// Highest value, the top of the upper shadow.
  double high;

  /// Lowest value, the bottom of the lower shadow.
  double low;

  /// Value at the start of the period, one end of the body.
  double open;

  /// Value at the end of the period, the other end of the body.
  double close;

  /// Distance between [high] and [low], the full height of the candle including shadows.
  double get shadowRange => (high - low).abs();

  /// Distance between [open] and [close], the height of the candle body.
  double get bodyRange => (open - close).abs();

  @override
  CandleEntry<D> copy() => CandleEntry<D>(
    x: x,
    high: high,
    low: low,
    open: open,
    close: close,
    icon: icon,
    data: data,
  );
}
