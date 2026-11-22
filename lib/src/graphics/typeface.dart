// Android shim: android.graphics.Typeface for MPAndroidChart v4.0.1 port
import 'package:flutter/painting.dart';

/// The font of a [ChartPaint]'s text, standing in for `android.graphics.Typeface`.
///
/// A thin wrapper around the font fields of [TextStyle]: a family (null for the platform default), a weight and a
/// style. Android's `Typeface.create("sans-serif-medium", Typeface.NORMAL)` becomes
/// `Typeface(weight: FontWeight.w500)`.
class Typeface {
  /// The font family, or null to keep the family of the style it is applied to (the platform default).
  final String? fontFamily;

  /// The font weight.
  final FontWeight weight;

  /// The font style (upright or italic).
  final FontStyle style;

  /// Creates a typeface; with no arguments it equals [DEFAULT].
  const Typeface({
    this.fontFamily,
    this.weight = FontWeight.normal,
    this.style = FontStyle.normal,
  });

  /// The default typeface, like `Typeface.DEFAULT`.
  static const Typeface DEFAULT = Typeface();

  /// The default typeface in bold, like `Typeface.DEFAULT_BOLD`.
  static const Typeface DEFAULT_BOLD = Typeface(weight: FontWeight.bold);

  /// Returns [base] with the family (when not null), weight and style of this typeface.
  TextStyle apply(TextStyle base) => base.copyWith(
    fontFamily: fontFamily,
    fontWeight: weight,
    fontStyle: style,
  );

  @override
  bool operator ==(Object other) =>
      other is Typeface &&
      other.fontFamily == fontFamily &&
      other.weight == weight &&
      other.style == style;

  @override
  int get hashCode => Object.hash(fontFamily, weight, style);

  @override
  String toString() =>
      'Typeface(fontFamily: $fontFamily, weight: $weight, style: $style)';
}
