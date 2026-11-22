// Ported from MPChartExample: custom/FrameTimes.kt.
//
// Collects how long the draws of one chart took, for the readouts of the Performance pages. Not ported:
// `System.nanoTime()` is the injectable [FrameTimes.nanoTime], [FrameTimes.systemNanoTime] by default (a monotonic
// clock with microsecond resolution), so a test can fix the time.

/// Collects how long the draws of one chart took. Recorded and read on the thread that draws, so the readout never has
/// to wait for the chart and the chart never has to wait for the readout.
class FrameTimes {
  /// Creates an empty record that reads the time from [nanoTime].
  FrameTimes({this.nanoTime = systemNanoTime});

  /// `System.nanoTime()`: a monotonic time in nanoseconds.
  final int Function() nanoTime;

  static final Stopwatch _clock = Stopwatch()..start();

  /// The default [nanoTime]: the time since the app first asked for it, in nanoseconds, from a [Stopwatch].
  static int systemNanoTime() => _clock.elapsedMicroseconds * 1000;

  static const int _capacity = 256;
  static const int _headlineFrames = 30;
  static const int _oneSecondNanos = 1000000000;
  static const double _nanosPerMilli = 1000000;

  final List<int> _drawnAt = List.filled(_capacity, 0);
  final List<int> _tookNanos = List.filled(_capacity, 0);
  int _recorded = 0;

  /// Records a draw that took [durationNanos] nanoseconds and ended now.
  void record(int durationNanos) {
    final slot = _recorded % _capacity;
    _drawnAt[slot] = nanoTime();
    _tookNanos[slot] = durationNanos;
    _recorded++;
  }

  /// Forgets every recorded draw.
  void clear() {
    _recorded = 0;
  }

  /// Mean draw time in milliseconds over the last 30 frames, 0 before the first frame. As in Kotlin, the sum is
  /// divided by the number of frames in whole nanoseconds before it becomes milliseconds.
  double get recentMillis {
    final frames = _recorded < _headlineFrames ? _recorded : _headlineFrames;
    if (frames == 0) return 0;

    var sum = 0;
    for (var i = 1; i <= frames; i++) {
      sum += _tookNanos[(_recorded - i) % _capacity];
    }
    return (sum ~/ frames) / _nanosPerMilli;
  }

  /// Longest draw in milliseconds within the last second, 0 when nothing was drawn in it.
  double get worstMillisLastSecond {
    final since = nanoTime() - _oneSecondNanos;
    var worst = 0;
    final count = _recorded < _capacity ? _recorded : _capacity;
    for (var i = 1; i <= count; i++) {
      final slot = (_recorded - i) % _capacity;
      if (_drawnAt[slot] < since) break;
      if (_tookNanos[slot] > worst) worst = _tookNanos[slot];
    }
    return worst / _nanosPerMilli;
  }
}
