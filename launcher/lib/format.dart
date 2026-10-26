/// Date and time strings as the designs show them.
abstract final class HaloFormat {
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String two(int n) => n.toString().padLeft(2, '0');

  /// `09` and `41`, 24-hour.
  static String hours(DateTime t) => two(t.hour);
  static String minutes(DateTime t) => two(t.minute);

  /// `10:00`
  static String clock(DateTime t) => '${hours(t)}:${minutes(t)}';

  static const _weekdayShort = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  /// `FRI 23.10` (the status row date).
  static String statusDate(DateTime t) =>
      '${_weekdayShort[t.weekday - 1]} ${two(t.day)}.${two(t.month)}';

  /// Time label in the Stream: `9:39` today, `YEST` yesterday, else `21.10`.
  static String streamTime(DateTime t, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '${t.hour}:${minutes(t)}';
    if (diff == 1) return 'YEST';
    return '${two(t.day)}.${two(t.month)}';
  }

  /// `FRIDAY — 23 OCTOBER` (the Lock date line).
  static String lockDate(DateTime t) =>
      '${_weekdays[t.weekday - 1]} — ${t.day} ${_months[t.month - 1]}'
          .toUpperCase();
}
