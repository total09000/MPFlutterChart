// Ported from MPChartExample: AnimationPlaygroundActivity.kt, with res/layout/activity_animation_playground.xml.
//
// All animations: every animation the library offers, on a line, bar or donut chart in the dark Nightfall style, with
// any easing curve and duration. Tabs pick the chart, chips the easing curve (previewed by an EasingCurveView), a seek
// bar the duration; the buttons run animateX, animateY, animateXY, spin, animateDataChange and animateValue or stop
// them, a chip shows whether the chart animates and a line counts the onEnd calls. The three charts stay in the tree
// and the two that are not chosen are offstage, as the Activity sets them to View.GONE. Kotlin's unseeded
// `Random.nextInt(a, b)` is `random.nextInt(b - a) + a` on the page's seeded generator. The Runnable that polls
// `chart.isAnimating` every 80 ms is a periodic Timer.
//
// The Activity has no options menu, so the page shows no overflow button. Not ported: `saveToGallery` (see
// notimportant/demo_base.dart).
import 'dart:async';

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../design/easing_curve_view.dart';
import '../design/nightfall.dart';
import '../design/nightfall_style.dart';
import '../notimportant/demo_base.dart';

/// AnimationPlaygroundActivity.
class AnimationPlaygroundPage extends StatefulWidget {
  const AnimationPlaygroundPage({super.key});

  @override
  State<AnimationPlaygroundPage> createState() => _AnimationPlaygroundPageState();
}

/// The Activity's `Kind`: the chart a tab shows, with the tab's label and the subtitle above the chart.
enum _Kind {
  line('Line', 'animateX draws it, animateY grows it'),
  bar('Bars', 'tap New data to grow, shrink and move bars'),
  donut('Donut', 'animateX sweeps the slices, Spin turns it');

  const _Kind(this.label, this.subtitle);

  final String label;
  final String subtitle;
}

class _AnimationPlaygroundPageState extends State<AnimationPlaygroundPage> with DemoBase {
  /// `theme`.
  static const NightfallTheme _theme = Nightfall.dark;

  /// `easings`, in the order of the chips.
  static const Map<String, EasingFunction> _easings = {
    'Linear': Easing.Linear,
    'EaseInQuad': Easing.EaseInQuad, 'EaseOutQuad': Easing.EaseOutQuad, 'EaseInOutQuad': Easing.EaseInOutQuad,
    'EaseInCubic': Easing.EaseInCubic, 'EaseOutCubic': Easing.EaseOutCubic, 'EaseInOutCubic': Easing.EaseInOutCubic,
    'EaseInQuart': Easing.EaseInQuart, 'EaseOutQuart': Easing.EaseOutQuart, 'EaseInOutQuart': Easing.EaseInOutQuart,
    'EaseInSine': Easing.EaseInSine, 'EaseOutSine': Easing.EaseOutSine, 'EaseInOutSine': Easing.EaseInOutSine,
    'EaseInExpo': Easing.EaseInExpo, 'EaseOutExpo': Easing.EaseOutExpo, 'EaseInOutExpo': Easing.EaseInOutExpo,
    'EaseInCirc': Easing.EaseInCirc, 'EaseOutCirc': Easing.EaseOutCirc, 'EaseInOutCirc': Easing.EaseInOutCirc,
    'EaseInElastic': Easing.EaseInElastic, 'EaseOutElastic': Easing.EaseOutElastic,
    'EaseInOutElastic': Easing.EaseInOutElastic,
    'EaseInBack': Easing.EaseInBack, 'EaseOutBack': Easing.EaseOutBack, 'EaseInOutBack': Easing.EaseInOutBack,
    'EaseInBounce': Easing.EaseInBounce, 'EaseOutBounce': Easing.EaseOutBounce,
    'EaseInOutBounce': Easing.EaseInOutBounce,
  };

  /// `binding.lineChart`.
  final LineChartView _lineChart = LineChartView();

  /// `binding.barChart`.
  final BarChartView _barChart = BarChartView();

  /// `binding.pieChart`.
  final PieChartView _pieChart = PieChartView();

  _Kind _kind = _Kind.line;
  String _easingName = 'EaseInOutCubic';
  EasingFunction get _easing => _easings[_easingName]!;

  /// `binding.duration.progress`, 0 to 4000.
  int _durationProgress = 1500;
  int _durationMillis = 1500;
  int _ended = 0;
  String _lastEnded = '';

  /// `chart`: the chart of the chosen tab.
  Chart get _chart => switch (_kind) {
    _Kind.line => _lineChart,
    _Kind.bar => _barChart,
    _Kind.donut => _pieChart,
  };

  /// `shownRunning`: what the status chip shows, null before the first poll.
  bool? _shownRunning;

  /// The posted `showStatus` Runnable.
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _setUpCharts();
    _select(_Kind.line);
    // onStart posts showStatus, which runs at once and then every 80 ms until onStop.
    _showStatus();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 80), (_) => _showStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  /// `showStatus.run()`: shows whether the chart animates, redrawing only when that changed.
  void _showStatus() {
    final running = _chart.isAnimating;
    if (running != _shownRunning) {
      if (_shownRunning == null) {
        _shownRunning = running;
      } else {
        setState(() => _shownRunning = running);
      }
    }
  }

  void _setUpCharts() {
    nightfallBase(_lineChart, _theme);
    _lineChart
      ..axisLeft.axisMinimum = 0
      ..axisLeft.axisMaximum = 110
      ..data = _lineData(12);

    nightfallBase(_barChart, _theme);
    _barChart
      ..axisLeft.axisMinimum = 0
      ..axisLeft.axisMaximum = 110
      ..data = _barData(8);

    nightfallDonut(_pieChart, _theme);
    _pieChart
      ..holeRadius = 62
      ..data = _pieData(5);
  }

  /// `select(next)`, without the redraw, which the caller's setState does.
  void _select(_Kind next) {
    _chart.stopAnimations();
    _kind = next;
  }

  /// `selectEasing(name)`, without the redraw.
  void _selectEasing(String name) => _easingName = name;

  /// `ended(name)`: counts an onEnd call. It can run while the charts' widgets are being removed, during the build
  /// phase, where the page must not be rebuilt; the text is then updated after the frame.
  void _onEnded(String name) {
    _ended++;
    _lastEnded = name;
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  /// `showEnded()`.
  String get _endedText => switch (_ended) {
    0 => 'onEnd has not run yet',
    1 => 'onEnd ran once, for $_lastEnded',
    _ => 'onEnd ran $_ended times, last for $_lastEnded',
  };

  /// New data with a different number of entries, so values move, new entries grow in and removed ones go.
  void _animateNewData() {
    switch (_kind) {
      case _Kind.line:
        _lineChart.animateDataChange(
          _lineData(random.nextInt(12) + 6),
          _durationMillis,
          easing: _easing,
          onEnd: () => _onEnded('animateDataChange'),
        );
      case _Kind.bar:
        _barChart.animateDataChange(
          _barData(random.nextInt(8) + 4),
          _durationMillis,
          easing: _easing,
          onEnd: () => _onEnded('animateDataChange'),
        );
      case _Kind.donut:
        _pieChart.animateDataChange(
          _pieData(random.nextInt(3) + 3),
          _durationMillis,
          easing: _easing,
          onEnd: () => _onEnded('animateDataChange'),
        );
    }
  }

  void _animateOneValue() {
    final set = _chart.data?.getDataSetByIndex(0);
    if (set == null) return;
    if (set.entryCount == 0) return;
    final entry = set.getEntryForIndex(random.nextInt(set.entryCount));
    _chart.animateValue(entry, _randomValue(), _durationMillis, easing: _easing, onEnd: () => _onEnded('animateValue'));
  }

  LineData _lineData(int count) {
    final set = LineDataSet([for (var i = 0; i < count; i++) Entry(x: i.toDouble(), y: _randomValue())], 'Values');
    nightfallLine(set, _theme);
    set
      ..isDrawCirclesEnabled = true
      ..circleRadius = 3.5
      ..circleHoleRadius = 1.8
      ..circleColor = Nightfall.accent;
    nightfallFullWidthX(_lineChart, count);
    return LineData([set]);
  }

  BarData _barData(int count) {
    final set = BarDataSet([for (var i = 0; i < count; i++) BarEntry(x: i.toDouble(), y: _randomValue())], 'Values');
    nightfallBars(set);
    nightfallPaddedX(_barChart, count);
    return BarData([set])..barWidth = 0.6;
  }

  PieData _pieData(int count) {
    final set = PieDataSet([for (var i = 0; i < count; i++) PieEntry(_randomValue(), label: 'Part ${i + 1}')], '');
    nightfallSlices(set);
    return PieData(set);
  }

  /// `Random.nextInt(15, 100)`.
  double _randomValue() => (random.nextInt(85) + 15).toDouble();

  /// `card()`.
  static BoxDecoration _card() => BoxDecoration(
    color: _theme.card,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _theme.grid, width: 1),
  );

  /// `rounded(color, radiusDp)`.
  static BoxDecoration _rounded(Color color, double radius) =>
      BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius));

  /// `action(row, label, color, weight, onClick)`: a button of the two action rows, [flex] its weight times 10;
  /// [onClick] null disables it, as `isEnabled = false` does, and [opacity] is the View's alpha.
  Widget _action(String label, Color color, VoidCallback? onClick, {int flex = 10, double opacity = 1}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Opacity(
        opacity: opacity,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClick,
          child: Container(
            decoration: _rounded(Nightfall.withAlpha(color, 38), 14),
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    ),
  );

  Widget _host<C extends Chart<D>, D extends ChartData>(_Kind kind, C chart) =>
      Offstage(offstage: _kind != kind, child: ChartHostWidget<C, D>(chart: chart, data: chart.data));

  Widget _status() {
    final running = _shownRunning ?? false;
    final color = running ? Nightfall.green : _theme.muted;
    return Container(
      decoration: _rounded(Nightfall.withAlpha(color, 36), 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        running ? '●  Running' : '●  Idle',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _tab(_Kind kind) {
    final selected = kind == _kind;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _select(kind)),
        child: Container(
          decoration: selected ? _rounded(Nightfall.accent, 11) : null,
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          child: Text(
            kind.label,
            style: TextStyle(
              color: selected ? _theme.stage : _theme.muted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _easingChip(String name) {
    final selected = name == _easingName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => setState(() => _selectEasing(name)),
        child: Container(
          decoration: _rounded(selected ? Nightfall.withAlpha(Nightfall.accent, 40) : _theme.track, 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            name.startsWith('Ease') ? name.substring(4) : name,
            style: TextStyle(color: selected ? Nightfall.accent : _theme.muted, fontSize: 12),
          ),
        ),
      ),
    );
  }

  static const TextStyle _labelStyle =
      TextStyle(color: Nightfall.muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 11 * 0.08);

  @override
  Widget build(BuildContext context) {
    final spinEnabled = _kind == _Kind.donut;
    return DemoScaffold(
      title: 'All animations',
      body: ColoredBox(
        color: _theme.stage,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: _card(),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Animations',
                                  style: TextStyle(color: _theme.text, fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                Text(_kind.subtitle, style: TextStyle(color: _theme.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                          _status(),
                        ],
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _host<LineChartView, LineData>(_Kind.line, _lineChart),
                              _host<BarChartView, BarData>(_Kind.bar, _barChart),
                              _host<PieChartView, PieData>(_Kind.donut, _pieChart),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(3),
                        decoration: _rounded(_theme.track, 14),
                        child: Row(children: [for (final kind in _Kind.values) _tab(kind)]),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: _card(),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('EASING', style: _labelStyle),
                                Text(
                                  _easingName,
                                  style: TextStyle(color: _theme.text, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 72,
                            height: 44,
                            child: EasingCurveView(
                              easing: _easing,
                              curveColor: Nightfall.accent,
                              guideColor: _theme.grid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(children: [for (final name in _easings.keys) _easingChip(name)]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10, left: 14, right: 14),
                      child: Row(
                        children: [
                          const Text('DURATION', style: _labelStyle),
                          Expanded(
                            child: Slider(
                              value: _durationProgress.toDouble(),
                              max: 4000,
                              activeColor: Nightfall.accent,
                              thumbColor: Nightfall.accent,
                              inactiveColor: _theme.muted,
                              onChanged: (value) {
                                final progress = value.round();
                                if (progress == _durationProgress) return;
                                setState(() {
                                  _durationProgress = progress;
                                  _durationMillis = progress < 100 ? 100 : progress;
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 64,
                            child: Text(
                              '$_durationMillis ms',
                              textAlign: TextAlign.end,
                              style: TextStyle(color: _theme.text, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    _action('Draw X', Nightfall.accent, () {
                      _chart.animateX(_durationMillis, easing: _easing, onEnd: () => _onEnded('animateX'));
                    }),
                    _action('Grow Y', Nightfall.accent, () {
                      _chart.animateY(_durationMillis, easing: _easing, onEnd: () => _onEnded('animateY'));
                    }),
                    _action('Both', Nightfall.accent, () {
                      _chart.animateXY(
                        _durationMillis,
                        _durationMillis,
                        easingX: _easing,
                        onEnd: () => _onEnded('animateXY'),
                      );
                    }),
                    // spinButton.isEnabled = kind == Kind.DONUT; alpha = if (isEnabled) 1f else 0.35f
                    _action(
                      'Spin',
                      Nightfall.violet,
                      spinEnabled
                          ? () => _pieChart.spin(
                              _durationMillis,
                              _pieChart.rotationAngle,
                              _pieChart.rotationAngle + 360,
                              easing: _easing,
                              onEnd: () => _onEnded('spin'),
                            )
                          : null,
                      opacity: spinEnabled ? 1 : 0.35,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    _action('New data', Nightfall.amber, _animateNewData, flex: 13),
                    _action('One value', Nightfall.green, _animateOneValue, flex: 13),
                    _action('Stop', Nightfall.coral, () => _chart.stopAnimations()),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _endedText,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _theme.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
