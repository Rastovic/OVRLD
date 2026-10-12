/// Weeks start on Monday. All dates here are local calendar dates; times of
/// day are dropped on purpose so a DST change can never move a session to a
/// neighbouring day.
library;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 0 = Monday ... 6 = Sunday.
int weekdayIndex(DateTime d) => d.weekday - 1;

DateTime startOfWeek(DateTime d) {
  final day = dateOnly(d);
  return DateTime(day.year, day.month, day.day - weekdayIndex(day));
}

DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// ISO-8601 week number (weeks start Monday; week 1 holds the first Thursday).
int isoWeek(DateTime d) {
  final day = dateOnly(d);
  final thursday = addDays(day, 3 - weekdayIndex(day));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final week1Monday = addDays(firstThursday, -weekdayIndex(firstThursday));
  return (thursday.difference(week1Monday).inHours / (24 * 7)).round() + 1;
}

/// Whole calendar days from [a] to [b], DST-safe.
int daysBetween(DateTime a, DateTime b) {
  final ua = DateTime.utc(a.year, a.month, a.day);
  final ub = DateTime.utc(b.year, b.month, b.day);
  return ub.difference(ua).inDays;
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const weekdayShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const monthShort = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// "MON 12 OCT".
String shortDate(DateTime d) =>
    '${weekdayShort[weekdayIndex(d)]} ${d.day} ${monthShort[d.month - 1]}';

/// Consecutive weeks, ending with the current or the previous one, in which
/// every planned training day was done. The current week only counts once it
/// is complete or already fully done, so a Monday does not break a streak.
int weekStreak({
  required DateTime today,
  required bool Function(DateTime weekStart) weekComplete,
  int maxWeeks = 520,
}) {
  var week = startOfWeek(today);
  var streak = 0;
  if (weekComplete(week)) streak++;
  for (var i = 0; i < maxWeeks; i++) {
    week = addDays(week, -7);
    if (!weekComplete(week)) break;
    streak++;
  }
  return streak;
}
