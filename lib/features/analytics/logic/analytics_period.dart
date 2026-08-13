/// Analytics history window (preset or calendar pick) in Asia/Manila dates.
///
/// Used by the Analytics tab filters, daily RPC fetch, and period-AI cache
/// key (`period_start` + `period_end`). Not a live Home reading window.
library;

import 'manila_time.dart';

/// How the farmer picked the Analytics date range.
enum AnalyticsPeriodKind {
  thisWeek,
  lastWeek,
  lastTwoWeeks,
  last30Days,
  customWeek,
  customMonth,
}

/// Inclusive Manila calendar range plus a farmer-facing label.
class AnalyticsPeriod {
  const AnalyticsPeriod({
    required this.kind,
    required this.start,
    required this.end,
  });

  final AnalyticsPeriodKind kind;

  /// Inclusive Manila calendar start (time unused).
  final DateTime start;

  /// Inclusive Manila calendar end (time unused).
  final DateTime end;

  /// This ISO week (Monday through today).
  factory AnalyticsPeriod.thisWeek() {
    final today = manilaCalendarDate(DateTime.now());
    return AnalyticsPeriod(
      kind: AnalyticsPeriodKind.thisWeek,
      start: manilaMondayOf(today),
      end: today,
    );
  }

  factory AnalyticsPeriod.lastWeek() {
    final today = manilaCalendarDate(DateTime.now());
    final thisMon = manilaMondayOf(today);
    return AnalyticsPeriod(
      kind: AnalyticsPeriodKind.lastWeek,
      start: thisMon.subtract(const Duration(days: 7)),
      end: thisMon.subtract(const Duration(days: 1)),
    );
  }

  /// Monday two weeks before this Monday, through today.
  factory AnalyticsPeriod.lastTwoWeeks() {
    final today = manilaCalendarDate(DateTime.now());
    final thisMon = manilaMondayOf(today);
    return AnalyticsPeriod(
      kind: AnalyticsPeriodKind.lastTwoWeeks,
      start: thisMon.subtract(const Duration(days: 14)),
      end: today,
    );
  }

  factory AnalyticsPeriod.last30Days() {
    final today = manilaCalendarDate(DateTime.now());
    return AnalyticsPeriod(
      kind: AnalyticsPeriodKind.last30Days,
      start: today.subtract(const Duration(days: 29)),
      end: today,
    );
  }

  /// ISO week containing [anyDay]; end clamped to today.
  factory AnalyticsPeriod.customWeek(DateTime anyDay) {
    final today = manilaCalendarDate(DateTime.now());
    final mon = manilaMondayOf(anyDay);
    final sun = mon.add(const Duration(days: 6));
    final end = sun.isAfter(today) ? today : sun;
    return AnalyticsPeriod(
      kind: AnalyticsPeriodKind.customWeek,
      start: mon,
      end: end,
    );
  }

  /// Calendar month; current month is 1st through today.
  factory AnalyticsPeriod.customMonth(int year, int month) {
    final today = manilaCalendarDate(DateTime.now());
    final start = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final end = last.isAfter(today) ? today : last;
    return AnalyticsPeriod(
      kind: AnalyticsPeriodKind.customMonth,
      start: start,
      end: end,
    );
  }

  int get dayCount => end.difference(start).inDays + 1;

  String get label => switch (kind) {
    AnalyticsPeriodKind.thisWeek => 'This week',
    AnalyticsPeriodKind.lastWeek => 'Last week',
    AnalyticsPeriodKind.lastTwoWeeks => 'Last 2 weeks',
    AnalyticsPeriodKind.last30Days => 'Last 30 days',
    AnalyticsPeriodKind.customWeek => formatManilaRange(start, end),
    AnalyticsPeriodKind.customMonth => _monthLabel(),
  };

  String _monthLabel() {
    final today = manilaCalendarDate(DateTime.now());
    final name = '${_monthShort[start.month - 1]} ${start.year}';
    final soFar = start.year == today.year && start.month == today.month;
    return soFar ? '$name (so far)' : name;
  }

  /// Every Manila calendar day in the window (chart x-axis).
  List<DateTime> get days {
    return List<DateTime>.generate(
      dayCount,
      (i) => DateTime(start.year, start.month, start.day).add(Duration(days: i)),
    );
  }
}

const _monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Short range for custom-week dropdown labels (e.g. `11–17 Aug`).
String formatManilaRange(DateTime start, DateTime end) {
  if (start.month == end.month && start.year == end.year) {
    return '${start.day}–${end.day} ${_monthShort[end.month - 1]}';
  }
  return '${start.day} ${_monthShort[start.month - 1]} – '
      '${end.day} ${_monthShort[end.month - 1]}';
}
