// Android shim: java.text.DecimalFormat for MPAndroidChart v4.0.1 port
import 'dart:typed_data';

/// A minimal `java.text.DecimalFormat` for the number patterns MPAndroidChart uses, such as `###,###,###,##0.0`,
/// `###,###,###,##0`, `###,###,##0.#` and `#.##`.
///
/// Supported pattern characters: `#` (optional digit), `0` (required digit), `,` (grouping separator; the group size
/// is the number of digits after the last `,` of the integer part) and one `.` (decimal separator). The fraction part
/// is zero or more `0` followed by zero or more `#`. Prefixes, suffixes, percent, exponents and quotes are not
/// supported and throw an [ArgumentError].
///
/// A double is rounded with `RoundingMode.HALF_EVEN` applied to its exact binary value, to the maximum number of
/// fraction digits (so `#.##` formats 1.005 as `1`, since 1.005 is stored slightly below the tie, and 0.125 as `0.12`);
/// the digits are its shortest round-trip decimal digits. The JDK and Android's ICU `DecimalFormat` each differ from
/// this, and from each other, on rare inputs next to a decimal tie (see MIGRATION.md). An `int` is formatted exactly, like Java's `format(long)`. A negative value keeps its minus sign even when
/// it rounds to zero (`#.#` formats -0.01 as `-0`), and -0.0 prints `-0`. NaN prints `NaN` and the infinities `∞` and
/// `-∞`.
///
/// Unlike Java, the symbols are fixed (`.` decimal separator, `,` grouping separator, `-` minus sign) and never follow
/// the locale.
class DecimalFormat {
  late final int _minimumIntegerDigits;
  late final int _minimumFractionDigits;
  late final int _maximumFractionDigits;

  /// The group size, or 0 when the pattern has no grouping separator.
  late final int _groupingSize;

  /// The minimum number of fraction digits shown (`DecimalFormat.getMinimumFractionDigits`): the `0`s after `.`.
  int get minimumFractionDigits => _minimumFractionDigits;

  /// The maximum number of fraction digits shown (`DecimalFormat.getMaximumFractionDigits`): all digits after `.`.
  int get maximumFractionDigits => _maximumFractionDigits;

  /// Creates a format for [pattern]; throws an [ArgumentError] for a pattern outside the supported family.
  DecimalFormat(String pattern) {
    _applyPattern(pattern);
  }

  /// Parses [pattern] the way `java.text.DecimalFormat.applyPattern` does for the supported characters.
  void _applyPattern(String pattern) {
    var digitLeftCount = 0; // '#' before the first '0'
    var zeroDigitCount = 0;
    var digitRightCount = 0; // '#' after a '0'
    var decimalPos = -1;
    var groupingCount = -1;

    for (var i = 0; i < pattern.length; i++) {
      final ch = pattern[i];
      switch (ch) {
        case '#':
          if (zeroDigitCount == 0) {
            digitLeftCount++;
          } else {
            digitRightCount++;
          }
          if (groupingCount >= 0 && decimalPos < 0) groupingCount++;
        case '0':
          if (digitRightCount > 0) throw ArgumentError.value(pattern, 'pattern', "Unexpected '0'");
          zeroDigitCount++;
          if (groupingCount >= 0 && decimalPos < 0) groupingCount++;
        case ',':
          if (decimalPos >= 0) throw ArgumentError.value(pattern, 'pattern', "Grouping separator after '.'");
          groupingCount = 0;
        case '.':
          if (decimalPos >= 0) throw ArgumentError.value(pattern, 'pattern', 'Multiple decimal separators');
          decimalPos = digitLeftCount + zeroDigitCount + digitRightCount;
        default:
          throw ArgumentError.value(pattern, 'pattern', "Unsupported pattern character '$ch'");
      }
    }
    if (digitLeftCount + zeroDigitCount + digitRightCount == 0) {
      throw ArgumentError.value(pattern, 'pattern', 'Pattern has no digits');
    }

    // Java: patterns with no '0' are interpreted, "##.###" -> "#0.###" and ".###" -> ".0##".
    if (zeroDigitCount == 0 && digitLeftCount > 0 && decimalPos >= 0) {
      var n = decimalPos;
      if (n == 0) n++;
      digitRightCount = digitLeftCount - n;
      digitLeftCount = n - 1;
      zeroDigitCount = 1;
    }

    // Java's syntax check: '#' after '0' only in the fraction, '0' only next to the decimal point, no empty group.
    if ((decimalPos < 0 && digitRightCount > 0) ||
        (decimalPos >= 0 && (decimalPos < digitLeftCount || decimalPos > digitLeftCount + zeroDigitCount)) ||
        groupingCount == 0) {
      throw ArgumentError.value(pattern, 'pattern', 'Malformed pattern');
    }

    final digitTotalCount = digitLeftCount + zeroDigitCount + digitRightCount;
    final effectiveDecimalPos = decimalPos >= 0 ? decimalPos : digitTotalCount;
    _minimumIntegerDigits = effectiveDecimalPos - digitLeftCount;
    _maximumFractionDigits = decimalPos >= 0 ? digitTotalCount - decimalPos : 0;
    _minimumFractionDigits = decimalPos >= 0 ? digitLeftCount + zeroDigitCount - decimalPos : 0;
    _groupingSize = groupingCount > 0 ? groupingCount : 0;
  }

  /// Formats [value] with this pattern.
  String format(num value) {
    if (value is double) {
      if (value.isNaN) return 'NaN';
      final isNegative = value.isNegative; // true for -0.0, like Java
      if (value.isInfinite) return isNegative ? '-∞' : '∞';
      final digits = _DigitList.ofDouble(value.abs(), _maximumFractionDigits);
      return _subformat(isNegative, digits);
    }
    final digits = _DigitList.ofInt(value as int);
    return _subformat(value < 0, digits);
  }

  /// Writes the sign, the grouped integer digits and the fraction digits, as Java's `DecimalFormat.subformat`.
  String _subformat(bool isNegative, _DigitList digitList) {
    final result = StringBuffer();
    if (isNegative) result.write('-');
    final digits = digitList.digits;
    final decimalAt = digitList.decimalAt;

    var count = _minimumIntegerDigits;
    if (decimalAt > 0 && count < decimalAt) count = decimalAt;
    var digitIndex = 0;
    final sizeBeforeIntegerPart = result.length;
    for (var i = count - 1; i >= 0; --i) {
      if (i < decimalAt && digitIndex < digits.length) {
        result.write(digits[digitIndex++]);
      } else {
        result.write('0');
      }
      if (_groupingSize != 0 && i > 0 && i % _groupingSize == 0) result.write(',');
    }

    final fractionPresent = _minimumFractionDigits > 0 || digitIndex < digits.length;
    // With no fraction and no integer digit printed, print a zero.
    if (!fractionPresent && result.length == sizeBeforeIntegerPart) result.write('0');
    if (fractionPresent) result.write('.');

    for (var i = 0; i < _maximumFractionDigits; ++i) {
      if (i >= _minimumFractionDigits && digitIndex >= digits.length) break;
      // Zeros between the decimal point and the first digit.
      if (-1 - i > decimalAt - 1) {
        result.write('0');
        continue;
      }
      result.write(digitIndex < digits.length ? digits[digitIndex++] : '0');
    }
    return result.toString();
  }
}

/// The decimal digits of a non-negative number as `0.digits × 10^decimalAt`, like Java's `java.text.DigitList`.
///
/// [digits] has no leading or trailing zeros; zero is the empty string with [decimalAt] 0.
class _DigitList {
  final String digits;
  final int decimalAt;

  const _DigitList(this.digits, this.decimalAt);

  static const _DigitList zero = _DigitList('', 0);

  /// The exact digits of [value].
  factory _DigitList.ofInt(int value) {
    final s = BigInt.from(value).abs().toString();
    return _DigitList._normalized(s, s.length);
  }

  /// The shortest round-trip digits of the finite, non-negative [value], rounded HALF_EVEN to
  /// [maximumFractionDigits] fraction digits.
  factory _DigitList.ofDouble(double value, int maximumFractionDigits) {
    final shortest = _parseShortest(value);
    final digits = shortest.digits;
    final decimalAt = shortest.decimalAt;
    final keep = decimalAt + maximumFractionDigits;
    if (digits.length <= keep) return shortest;
    if (keep < 0) return zero;

    var kept = digits.substring(0, keep);
    var newDecimalAt = decimalAt;
    if (_shouldRoundUp(value, digits, decimalAt, keep)) {
      final buf = kept.codeUnits.toList();
      var i = buf.length - 1;
      while (i >= 0 && buf[i] == 0x39) {
        buf[i] = 0x30;
        i--;
      }
      if (i < 0) {
        // All nines (or nothing kept): the value becomes 10^decimalAt.
        kept = '1';
        newDecimalAt++;
      } else {
        buf[i]++;
        kept = String.fromCharCodes(buf);
      }
    }
    return _DigitList._normalized(kept, newDecimalAt);
  }

  /// Strips leading and trailing zeros from [digits] (whose decimal point is at [decimalAt]).
  factory _DigitList._normalized(String digits, int decimalAt) {
    var start = 0;
    while (start < digits.length && digits.codeUnitAt(start) == 0x30) {
      start++;
    }
    var end = digits.length;
    while (end > start && digits.codeUnitAt(end - 1) == 0x30) {
      end--;
    }
    if (start == end) return zero;
    return _DigitList(digits.substring(start, end), decimalAt - start);
  }

  /// Parses `double.toString` (shortest round-trip digits), e.g. `1234.56`, `1e-7`, `1.2345678901234568e+29`.
  static _DigitList _parseShortest(double value) {
    final s = value.toString();
    final e = s.indexOf('e');
    final mantissa = e < 0 ? s : s.substring(0, e);
    final exponent = e < 0 ? 0 : int.parse(s.substring(e + 1));
    final dot = mantissa.indexOf('.');
    final intPart = dot < 0 ? mantissa : mantissa.substring(0, dot);
    final fracPart = dot < 0 ? '' : mantissa.substring(dot + 1);
    return _DigitList._normalized(intPart + fracPart, intPart.length + exponent);
  }

  /// HALF_EVEN rounding of [digits] at index [keep], as Java's `DigitList.shouldRoundUp`: a lone `5` at [keep] is a
  /// tie of the decimal digits, resolved by the exact binary [value].
  static bool _shouldRoundUp(double value, String digits, int decimalAt, int keep) {
    final d = digits.codeUnitAt(keep);
    if (d > 0x35) return true;
    if (d < 0x35) return false;
    // digits has no trailing zeros, so any digit after the 5 makes it more than half.
    if (keep < digits.length - 1) return true;
    final cmp = _compareExact(value, digits, decimalAt);
    if (cmp != 0) return cmp > 0;
    // Exact tie: round to the even neighbour.
    return keep > 0 && (digits.codeUnitAt(keep - 1) - 0x30).isOdd;
  }

  /// Compares the exact binary value of the finite, positive [value] with `0.digits × 10^decimalAt`.
  static int _compareExact(double value, String digits, int decimalAt) {
    final bytes = ByteData(8)..setFloat64(0, value);
    final hi = bytes.getUint32(0);
    final lo = bytes.getUint32(4);
    final biasedExponent = (hi >> 20) & 0x7FF;
    var mantissa = (BigInt.from(hi & 0xFFFFF) << 32) | BigInt.from(lo);
    int binaryExponent;
    if (biasedExponent == 0) {
      binaryExponent = -1074;
    } else {
      mantissa |= BigInt.one << 52;
      binaryExponent = biasedExponent - 1075;
    }
    // value = mantissa × 2^binaryExponent, decimal = n × 10^decimalExponent.
    var left = mantissa;
    var right = BigInt.parse(digits);
    final decimalExponent = decimalAt - digits.length;
    if (binaryExponent >= 0) {
      left <<= binaryExponent;
    } else {
      right <<= -binaryExponent;
    }
    if (decimalExponent >= 0) {
      right *= BigInt.from(10).pow(decimalExponent);
    } else {
      left *= BigInt.from(10).pow(-decimalExponent);
    }
    return left.compareTo(right);
  }
}
