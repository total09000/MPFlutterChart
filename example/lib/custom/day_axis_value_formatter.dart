// Ported from MPChartExample: custom/DayAxisValueFormatter.kt
import 'dart:math' as math;

import 'package:mp_flutter_chart/core.dart';

/// Formats an x value as a day counted from the start of 2016: the month and the year while more than six months are
/// visible, else the day and the month.
class DayAxisValueFormatter implements IAxisValueFormatter {
  DayAxisValueFormatter(this._chart);

  final BarLineChartBase _chart;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  @override
  String getFormattedValue(double value, AxisBase axis) {
    final days = value.toInt();
    final year = _determineYear(days);
    final month = _determineMonth(days);
    final monthName = _months[month % _months.length];
    final yearName = year.toString();

    if (_chart.visibleXRange > 30 * 6) {
      return '$monthName $yearName';
    } else {
      final dayOfMonth = _determineDayOfMonth(days, month + 12 * (year - 2016));
      final appendix = switch (dayOfMonth) {
        1 || 21 || 31 => 'st',
        2 || 22 => 'nd',
        3 || 23 => 'rd',
        _ => 'th',
      };
      return dayOfMonth == 0 ? '' : '$dayOfMonth$appendix $monthName';
    }
  }

  int _getDaysForMonth(int month, int year) {
    if (month == 1) {
      final bool is29Feb;
      if (year < 1582) {
        is29Feb = (year < 1 ? year + 1 : year) % 4 == 0;
      } else if (year > 1582) {
        is29Feb = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
      } else {
        is29Feb = false;
      }
      return is29Feb ? 29 : 28;
    }
    return month == 3 || month == 5 || month == 8 || month == 10 ? 30 : 31;
  }

  int _determineMonth(int dayOfYear) {
    var month = -1;
    var days = 0;
    while (days < dayOfYear) {
      month += 1;
      if (month >= 12) month = 0;
      final year = _determineYear(days);
      days += _getDaysForMonth(month, year);
    }
    return math.max(month, 0);
  }

  int _determineDayOfMonth(int days, int month) {
    var count = 0;
    var daysForMonths = 0;
    while (count < month) {
      final year = _determineYear(daysForMonths);
      daysForMonths += _getDaysForMonth(count % 12, year);
      count++;
    }
    return days - daysForMonths;
  }

  int _determineYear(int days) {
    if (days <= 366) return 2016;
    if (days <= 730) return 2017;
    if (days <= 1094) return 2018;
    if (days <= 1458) return 2019;
    return 2020;
  }
}
