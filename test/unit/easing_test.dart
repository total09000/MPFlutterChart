// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/EasingTest.kt
//
// The Kotlin test checks the end points of every curve (within 0.01) and one mid value; the extra tests check a mid
// value of every curve against the Kotlin formula worked out by hand, and the Curve adapter.
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/animation/easing.dart';

void main() {
  test('everyEasingStartsAtZeroAndEndsAtOne', () {
    final easings = <String, EasingFunction>{
      'Linear': Easing.Linear,
      'EaseInQuad': Easing.EaseInQuad,
      'EaseOutQuad': Easing.EaseOutQuad,
      'EaseInOutQuad': Easing.EaseInOutQuad,
      'EaseInCubic': Easing.EaseInCubic,
      'EaseOutCubic': Easing.EaseOutCubic,
      'EaseInOutCubic': Easing.EaseInOutCubic,
      'EaseInQuart': Easing.EaseInQuart,
      'EaseOutQuart': Easing.EaseOutQuart,
      'EaseInOutQuart': Easing.EaseInOutQuart,
      'EaseInSine': Easing.EaseInSine,
      'EaseOutSine': Easing.EaseOutSine,
      'EaseInOutSine': Easing.EaseInOutSine,
      'EaseInExpo': Easing.EaseInExpo,
      'EaseOutExpo': Easing.EaseOutExpo,
      'EaseInOutExpo': Easing.EaseInOutExpo,
      'EaseInCirc': Easing.EaseInCirc,
      'EaseOutCirc': Easing.EaseOutCirc,
      'EaseInOutCirc': Easing.EaseInOutCirc,
      'EaseInElastic': Easing.EaseInElastic,
      'EaseOutElastic': Easing.EaseOutElastic,
      'EaseInOutElastic': Easing.EaseInOutElastic,
      'EaseInBack': Easing.EaseInBack,
      'EaseOutBack': Easing.EaseOutBack,
      'EaseInOutBack': Easing.EaseInOutBack,
      'EaseInBounce': Easing.EaseInBounce,
      'EaseOutBounce': Easing.EaseOutBounce,
      'EaseInOutBounce': Easing.EaseInOutBounce,
    };
    for (final MapEntry(key: name, value: easing) in easings.entries) {
      expect(easing(0), closeTo(0, 0.01), reason: name);
      expect(easing(1), closeTo(1, 0.01), reason: name);
    }
    expect(Easing.EaseInQuad(0.5), closeTo(0.25, 0.001));
  });

  test('every easing follows its Kotlin formula between the end points', () {
    // Values worked out by hand from Easing.kt (s = p / 2π · asin(1) is 0.075 for p = 0.3 and 0.1125 for 0.45).
    final expected = <String, (EasingFunction, double, double)>{
      'Linear': (Easing.Linear, 0.3, 0.3),
      'EaseInQuad': (Easing.EaseInQuad, 0.5, 0.25),
      'EaseOutQuad': (Easing.EaseOutQuad, 0.5, 0.75),
      'EaseInOutQuad low': (Easing.EaseInOutQuad, 0.25, 0.125),
      'EaseInOutQuad high': (Easing.EaseInOutQuad, 0.75, 0.875),
      'EaseInCubic': (Easing.EaseInCubic, 0.5, 0.125),
      'EaseOutCubic': (Easing.EaseOutCubic, 0.5, 0.875),
      'EaseInOutCubic low': (Easing.EaseInOutCubic, 0.25, 0.0625),
      'EaseInOutCubic high': (Easing.EaseInOutCubic, 0.75, 0.9375),
      'EaseInQuart': (Easing.EaseInQuart, 0.5, 0.0625),
      'EaseOutQuart': (Easing.EaseOutQuart, 0.5, 0.9375),
      'EaseInOutQuart low': (Easing.EaseInOutQuart, 0.25, 0.03125),
      'EaseInOutQuart high': (Easing.EaseInOutQuart, 0.75, 0.96875),
      'EaseInSine': (Easing.EaseInSine, 0.5, 0.2928932),
      'EaseOutSine': (Easing.EaseOutSine, 0.5, 0.7071068),
      'EaseInOutSine': (Easing.EaseInOutSine, 0.25, 0.1464466),
      'EaseInExpo': (Easing.EaseInExpo, 0.5, 0.03125),
      'EaseOutExpo': (Easing.EaseOutExpo, 0.5, 0.96875),
      'EaseInOutExpo low': (Easing.EaseInOutExpo, 0.25, 0.015625),
      'EaseInOutExpo high': (Easing.EaseInOutExpo, 0.75, 0.984375),
      'EaseInCirc': (Easing.EaseInCirc, 0.5, 0.1339746),
      'EaseOutCirc': (Easing.EaseOutCirc, 0.5, 0.8660254),
      'EaseInOutCirc low': (Easing.EaseInOutCirc, 0.25, 0.0669873),
      'EaseInOutCirc high': (Easing.EaseInOutCirc, 0.75, 0.9330127),
      'EaseInElastic': (Easing.EaseInElastic, 0.5, -0.015625),
      'EaseOutElastic': (Easing.EaseOutElastic, 0.5, 1.015625),
      'EaseInOutElastic low': (Easing.EaseInOutElastic, 0.25, 0.0119694),
      'EaseInOutElastic high': (Easing.EaseInOutElastic, 0.75, 0.9880306),
      'EaseInBack': (Easing.EaseInBack, 0.5, -0.0876975),
      'EaseOutBack': (Easing.EaseOutBack, 0.5, 1.0876975),
      'EaseInOutBack low': (Easing.EaseInOutBack, 0.25, -0.0996818),
      'EaseInOutBack high': (Easing.EaseInOutBack, 0.75, 1.0996818),
      'EaseOutBounce': (Easing.EaseOutBounce, 0.5, 0.765625),
      'EaseInBounce': (Easing.EaseInBounce, 0.5, 0.234375),
      'EaseInOutBounce low': (Easing.EaseInOutBounce, 0.25, 0.1171875),
      'EaseInOutBounce high': (Easing.EaseInOutBounce, 0.75, 0.8828125),
    };
    for (final MapEntry(key: name, value: (easing, input, output))
        in expected.entries) {
      expect(easing(input), closeTo(output, 1e-4), reason: name);
    }
  });

  test(
    'the exact end points are special-cased where the formula would miss them',
    () {
      expect(Easing.EaseInExpo(0), 0);
      expect(Easing.EaseOutExpo(1), 1);
      expect(Easing.EaseInOutExpo(0), 0);
      expect(Easing.EaseInOutExpo(1), 1);
      expect(Easing.EaseInElastic(0), 0);
      expect(Easing.EaseInElastic(1), 1);
      expect(Easing.EaseOutElastic(0), 0);
      expect(Easing.EaseOutElastic(1), 1);
      expect(Easing.EaseInOutElastic(0), 0);
      expect(Easing.EaseInOutElastic(1), 1);
    },
  );

  test('fromCurve adapts a Flutter Curve', () {
    final easing = Easing.fromCurve(Curves.easeIn);
    expect(easing(0), 0);
    expect(easing(0.5), Curves.easeIn.transform(0.5));
    expect(easing(1), 1);
  });
}
