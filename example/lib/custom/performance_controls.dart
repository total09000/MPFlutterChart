// What MPChartExample's LinePerformanceActivity.kt and BarPerformanceActivity.kt have in common, which Kotlin writes
// out in both: the count formatting, the generator behind their data, and the controls of
// res/layout/activity_line_performance.xml and res/layout/activity_bar_performance.xml.
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Easing;

/// `String.format(Locale.US, "%,d", value)`.
String grouped(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

final Float32List _float = Float32List(1);

/// [value] rounded to a Kotlin `Float`.
double kotlinFloat(double value) {
  _float[0] = value;
  return _float[0];
}

/// `java.util.Random(seed)`: the 48-bit linear congruential generator of the JDK, so the data equals Android's.
class JavaRandom {
  JavaRandom(int seed) : _seed = (seed ^ _multiplier) & _mask;

  static const int _multiplier = 0x5DEECE66D;
  static const int _mask = (1 << 48) - 1;

  int _seed;

  /// `next(bits)`. The product wraps at 64 bits, which keeps its low 48 bits exact.
  int _next(int bits) {
    _seed = (_seed * _multiplier + 0xB) & _mask;
    return (_seed >> (48 - bits)).toSigned(32);
  }

  /// `nextFloat()`: 24 random bits as a value from 0 inclusive to 1 exclusive.
  double nextFloat() => _next(24) / (1 << 24);
}

/// `binding.readout`: monospace 13sp on #EEEEEE with 8dp padding.
class PerformanceReadout extends StatelessWidget {
  const PerformanceReadout(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFFEEEEEE),
    padding: const EdgeInsets.all(8),
    child: Text(text, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
  );
}

/// `binding.entryCount`, a horizontal RadioGroup in a HorizontalScrollView.
class EntryCountGroup extends StatelessWidget {
  const EntryCountGroup({super.key, required this.count, required this.onChanged});

  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: RadioGroup<int>(
      groupValue: count,
      onChanged: (value) {
        if (value != null && value != count) onChanged(value);
      },
      child: const Row(
        children: [
          PerformanceRadioButton(1000, '1k'),
          PerformanceRadioButton(10000, '10k'),
          PerformanceRadioButton(50000, '50k'),
          PerformanceRadioButton(100000, '100k'),
          PerformanceRadioButton(500000, '500k'),
        ],
      ),
    ),
  );
}

/// A RadioButton with its text, in the [RadioGroup] above it.
class PerformanceRadioButton<T> extends StatelessWidget {
  const PerformanceRadioButton(this.value, this.label, {super.key});

  final T value;
  final String label;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => RadioGroup.maybeOf<T>(context)?.onChanged(value),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Radio<T>(value: value), Text(label), const SizedBox(width: 8)],
    ),
  );
}

/// A SwitchCompat: its text, then the switch at the end of the row.
class PerformanceSwitch extends StatelessWidget {
  const PerformanceSwitch(this.text, this.value, this.onChanged, {super.key});

  final String text;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    title: Text(text),
    value: value,
    onChanged: onChanged,
    dense: true,
    contentPadding: EdgeInsets.zero,
  );
}

/// The label limit row: its text, `binding.labelLimit` (max 5000) and `binding.labelLimitValue`, 56dp wide.
class LabelLimit extends StatelessWidget {
  const LabelLimit({super.key, required this.progress, required this.onProgressChanged});

  final int progress;
  final ValueChanged<int> onProgressChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text('Labels up to', style: TextStyle(fontSize: 13)),
      Expanded(
        child: Slider(
          value: progress.clamp(0, 5000).toDouble(),
          max: 5000,
          onChanged: (value) {
            final next = value.round();
            if (next != progress) onProgressChanged(next);
          },
        ),
      ),
      SizedBox(
        width: 56,
        child: Text(grouped(progress), textAlign: TextAlign.end, style: const TextStyle(fontSize: 13)),
      ),
    ],
  );
}
