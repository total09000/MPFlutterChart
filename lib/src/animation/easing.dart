// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/animation/Easing.kt
import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curve;

/// An easing curve: maps progress 0..1 to a value that is 0 at 0 and 1 at 1.
///
/// Kotlin's `Easing.EasingFunction` (a `fun interface` extending `TimeInterpolator`) is this top-level function type:
/// any `double Function(double)` closure is an easing, and [Easing.fromCurve] adapts a Flutter [Curve].
typedef EasingFunction = double Function(double input);

/// Easing curves for `ChartAnimator`. Each maps animation progress 0..1 to an eased value that is 0 at 0 and 1 at 1;
/// the elastic, back and bounce curves overshoot in between. EaseIn starts slow, EaseOut ends slow, EaseInOut does
/// both.
abstract final class Easing {
  static const double _DOUBLE_PI = 2 * math.pi;

  /// Adapts a Flutter [Curve] to an [EasingFunction] (no Kotlin counterpart), for example
  /// `Easing.fromCurve(Curves.fastOutSlowIn)`.
  static EasingFunction fromCurve(Curve c) => c.transform;

  /// Constant speed.
  static const EasingFunction Linear = _linear;

  /// Quadratic, starts slow.
  static const EasingFunction EaseInQuad = _easeInQuad;

  /// Quadratic, ends slow.
  static const EasingFunction EaseOutQuad = _easeOutQuad;

  /// Quadratic, starts and ends slow.
  static const EasingFunction EaseInOutQuad = _easeInOutQuad;

  /// Cubic, starts slow.
  static const EasingFunction EaseInCubic = _easeInCubic;

  /// Cubic, ends slow.
  static const EasingFunction EaseOutCubic = _easeOutCubic;

  /// Cubic, starts and ends slow.
  static const EasingFunction EaseInOutCubic = _easeInOutCubic;

  /// Quartic, starts slow.
  static const EasingFunction EaseInQuart = _easeInQuart;

  /// Quartic, ends slow.
  static const EasingFunction EaseOutQuart = _easeOutQuart;

  /// Quartic, starts and ends slow.
  static const EasingFunction EaseInOutQuart = _easeInOutQuart;

  /// Sine wave, gently starts slow.
  static const EasingFunction EaseInSine = _easeInSine;

  /// Sine wave, gently ends slow.
  static const EasingFunction EaseOutSine = _easeOutSine;

  /// Sine wave, gently starts and ends slow.
  static const EasingFunction EaseInOutSine = _easeInOutSine;

  /// Exponential, starts very slow.
  static const EasingFunction EaseInExpo = _easeInExpo;

  /// Exponential, ends very slow.
  static const EasingFunction EaseOutExpo = _easeOutExpo;

  /// Exponential, starts and ends very slow.
  static const EasingFunction EaseInOutExpo = _easeInOutExpo;

  /// Circular, starts slow.
  static const EasingFunction EaseInCirc = _easeInCirc;

  /// Circular, ends slow.
  static const EasingFunction EaseOutCirc = _easeOutCirc;

  /// Circular, starts and ends slow.
  static const EasingFunction EaseInOutCirc = _easeInOutCirc;

  /// Winds back below 0 like a spring before moving to 1.
  static const EasingFunction EaseInElastic = _easeInElastic;

  /// Springs past 1 and settles back.
  static const EasingFunction EaseOutElastic = _easeOutElastic;

  /// Winds back at the start and springs past 1 at the end.
  static const EasingFunction EaseInOutElastic = _easeInOutElastic;

  /// Pulls back below 0 slightly before moving to 1.
  static const EasingFunction EaseInBack = _easeInBack;

  /// Overshoots 1 slightly and settles back.
  static const EasingFunction EaseOutBack = _easeOutBack;

  /// Pulls back at the start and overshoots at the end.
  static const EasingFunction EaseInOutBack = _easeInOutBack;

  /// Bounces to a stop at 1 like a dropped ball.
  static const EasingFunction EaseOutBounce = _easeOutBounce;

  /// Bounces at the start, the mirror of [EaseOutBounce].
  static const EasingFunction EaseInBounce = _easeInBounce;

  /// Bounces at the start and at the end.
  static const EasingFunction EaseInOutBounce = _easeInOutBounce;

  // The curves are static functions, not closures, so that the constants above (and default arguments such as
  // `easing = Easing.Linear`) are compile-time constants.

  static double _linear(double input) => input;

  static double _easeInQuad(double input) => input * input;

  static double _easeOutQuad(double input) => -input * (input - 2);

  static double _easeInOutQuad(double value) {
    var input = value * 2;
    if (input < 1) {
      return 0.5 * input * input;
    } else {
      input -= 1;
      return -0.5 * (input * (input - 2) - 1);
    }
  }

  static double _easeInCubic(double input) => _pow(input, 3);

  static double _easeOutCubic(double value) {
    final input = value - 1;
    return _pow(input, 3) + 1;
  }

  static double _easeInOutCubic(double value) {
    var input = value * 2;
    if (input < 1) {
      return 0.5 * _pow(input, 3);
    } else {
      input -= 2;
      return 0.5 * (_pow(input, 3) + 2);
    }
  }

  static double _easeInQuart(double input) => _pow(input, 4);

  static double _easeOutQuart(double value) {
    final input = value - 1;
    return -(_pow(input, 4) - 1);
  }

  static double _easeInOutQuart(double value) {
    var input = value * 2;
    if (input < 1) {
      return 0.5 * _pow(input, 4);
    } else {
      input -= 2;
      return -0.5 * (_pow(input, 4) - 2);
    }
  }

  static double _easeInSine(double input) =>
      -math.cos(input * (math.pi / 2)) + 1;

  static double _easeOutSine(double input) => math.sin(input * (math.pi / 2));

  static double _easeInOutSine(double input) =>
      -0.5 * (math.cos(math.pi * input) - 1);

  static double _easeInExpo(double input) =>
      input == 0 ? 0 : _pow(2, 10 * (input - 1));

  static double _easeOutExpo(double input) =>
      input == 1 ? 1 : 1 - _pow(2, -10 * input);

  static double _easeInOutExpo(double value) {
    if (value == 0) return 0;
    if (value == 1) return 1;
    var input = value * 2;
    if (input < 1) {
      return 0.5 * _pow(2, 10 * (input - 1));
    } else {
      input -= 1;
      return 0.5 * (-(_pow(2, -10 * input)) + 2);
    }
  }

  static double _easeInCirc(double input) =>
      -(math.sqrt(1 - input * input) - 1);

  static double _easeOutCirc(double value) {
    final input = value - 1;
    return math.sqrt(1 - input * input);
  }

  static double _easeInOutCirc(double value) {
    var input = value * 2;
    if (input < 1) {
      return -0.5 * (math.sqrt(1 - input * input) - 1);
    } else {
      input -= 2;
      return 0.5 * (math.sqrt(1 - input * input) + 1);
    }
  }

  static double _easeInElastic(double value) {
    if (value == 0) return 0;
    if (value == 1) return 1;
    const p = 0.3;
    final s = p / _DOUBLE_PI * math.asin(1);
    final input = value - 1;
    return -(_pow(2, 10 * input) * math.sin((input - s) * _DOUBLE_PI / p));
  }

  static double _easeOutElastic(double input) {
    if (input == 0) return 0;
    if (input == 1) return 1;
    const p = 0.3;
    final s = p / _DOUBLE_PI * math.asin(1);
    return 1 + _pow(2, -10 * input) * math.sin((input - s) * _DOUBLE_PI / p);
  }

  static double _easeInOutElastic(double value) {
    if (value == 0) {
      return 0;
    } else {
      var input = value * 2;
      if (input == 2) {
        return 1;
      } else {
        const p = 1 / 0.45;
        final s = 0.45 / _DOUBLE_PI * math.asin(1);
        if (input < 1) {
          input -= 1;
          return -0.5 *
              (_pow(2, 10 * input) *
                  math.sin((input * 1 - s) * _DOUBLE_PI * p));
        } else {
          input -= 1;
          return 1 +
              0.5 *
                  (_pow(2, -10 * input) *
                      math.sin((input * 1 - s) * _DOUBLE_PI * p));
        }
      }
    }
  }

  static double _easeInBack(double input) {
    const s = 1.70158;
    return input * input * ((s + 1) * input - s);
  }

  static double _easeOutBack(double value) {
    const s = 1.70158;
    final input = value - 1;
    return input * input * ((s + 1) * input + s) + 1;
  }

  static double _easeInOutBack(double value) {
    var s = 1.70158;
    var input = value * 2;
    if (input < 1) {
      s *= 1.525;
      return 0.5 * (input * input * ((s + 1) * input - s));
    } else {
      input -= 2;
      s *= 1.525;
      return 0.5 * (input * input * ((s + 1) * input + s) + 2);
    }
  }

  static double _easeOutBounce(double value) {
    const s = 7.5625;
    var input = value;
    if (input < 1 / 2.75) {
      return s * input * input;
    } else if (input < 2 / 2.75) {
      input -= 1.5 / 2.75;
      return s * input * input + 0.75;
    } else if (input < 2.5 / 2.75) {
      input -= 2.25 / 2.75;
      return s * input * input + 0.9375;
    } else {
      input -= 2.625 / 2.75;
      return s * input * input + 0.984375;
    }
  }

  static double _easeInBounce(double input) => 1 - EaseOutBounce(1 - input);

  static double _easeInOutBounce(double input) {
    if (input < 0.5) {
      return EaseInBounce(input * 2) * 0.5;
    } else {
      return EaseOutBounce(input * 2 - 1) * 0.5 + 0.5;
    }
  }

  /// Kotlin `Float.pow`, `Math.pow` on doubles.
  static double _pow(double x, double exponent) =>
      math.pow(x, exponent).toDouble();
}
