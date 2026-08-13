/// Asia/Manila calendar helpers for Analytics history windows.
///
/// The Philippines has no DST. Used by the history repository and day
/// drill-down so chart days match the SQL `timezone('Asia/Manila', …)` buckets.
library;

/// Fixed offset: Manila is UTC+8 year-round.
const Duration kManilaOffset = Duration(hours: 8);

/// Current wall clock in Asia/Manila.
DateTime manilaNow() => DateTime.now().toUtc().add(kManilaOffset);

/// Calendar date (year/month/day) in Manila for [instant] (any timezone).
DateTime manilaCalendarDate(DateTime instant) {
  final manila = instant.toUtc().add(kManilaOffset);
  return DateTime(manila.year, manila.month, manila.day);
}

/// UTC instant for Manila midnight of the given calendar date.
DateTime manilaMidnightUtc(int year, int month, int day) {
  return DateTime.utc(year, month, day).subtract(kManilaOffset);
}

/// Exclusive UTC end of a Manila calendar day.
DateTime manilaDayEndUtc(int year, int month, int day) {
  final next = DateTime(year, month, day).add(const Duration(days: 1));
  return manilaMidnightUtc(next.year, next.month, next.day);
}

/// Inclusive [from] (UTC) and exclusive [to] (UTC) for the last [days] Manila days.
({DateTime from, DateTime to}) manilaRangeUtc(int days) {
  final today = manilaCalendarDate(DateTime.now());
  final start = today.subtract(Duration(days: days - 1));
  return manilaRangeUtcForDates(start, today);
}

/// Inclusive Manila calendar [start]..[end] as UTC `[from, to)`.
({DateTime from, DateTime to}) manilaRangeUtcForDates(
  DateTime start,
  DateTime end,
) {
  final tomorrow = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
  return (
    from: manilaMidnightUtc(start.year, start.month, start.day),
    to: manilaMidnightUtc(tomorrow.year, tomorrow.month, tomorrow.day),
  );
}

/// Monday of the ISO week that contains [calendarDate] (Manila Y/M/D).
DateTime manilaMondayOf(DateTime calendarDate) {
  final day = DateTime(calendarDate.year, calendarDate.month, calendarDate.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// `YYYY-MM-DD` for PostgREST `date` columns.
String manilaIsoDate(DateTime calendarDate) {
  final y = calendarDate.year.toString().padLeft(4, '0');
  final m = calendarDate.month.toString().padLeft(2, '0');
  final d = calendarDate.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// True when two values are the same Manila calendar day.
bool sameManilaDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
