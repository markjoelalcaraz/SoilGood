/// Period and metric dropdowns for the Analytics tab (shell content area).
///
/// Rectangular fields (not chips). Period presets + calendar sheets for a
/// specific ISO week or month. Metric includes All sensors overlay.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../data/daily_soil_bucket.dart';
import '../logic/analytics_period.dart';
import '../logic/manila_time.dart';

const _fieldRadius = BorderRadius.all(Radius.circular(8));

/// Two filter fields: date window and which series to chart.
class AnalyticsFilterBar extends StatelessWidget {
  const AnalyticsFilterBar({
    required this.period,
    required this.metric,
    required this.onPeriodChanged,
    required this.onMetricChanged,
    super.key,
  });

  final AnalyticsPeriod period;

  /// Null means All sensors overlay.
  final SoilMetric? metric;
  final ValueChanged<AnalyticsPeriod> onPeriodChanged;
  final ValueChanged<SoilMetric?> onMetricChanged;

  @override
  Widget build(BuildContext context) {
    final periodField = _MenuField(
      label: 'Period',
      value: period.label,
      menuChildren: [
        ...[
          (
            AnalyticsPeriodKind.thisWeek,
            'This week',
            AnalyticsPeriod.thisWeek,
          ),
          (
            AnalyticsPeriodKind.lastWeek,
            'Last week',
            AnalyticsPeriod.lastWeek,
          ),
          (
            AnalyticsPeriodKind.lastTwoWeeks,
            'Last 2 weeks',
            AnalyticsPeriod.lastTwoWeeks,
          ),
          (
            AnalyticsPeriodKind.last30Days,
            'Last 30 days',
            AnalyticsPeriod.last30Days,
          ),
        ].map(
          (item) => MenuItemButton(
            onPressed: () => onPeriodChanged(item.$3()),
            trailingIcon: period.kind == item.$1
                ? const Icon(Icons.check, size: 18, color: AppColors.primary)
                : null,
            child: Text(item.$2),
          ),
        ),
        const Divider(),
        MenuItemButton(
          onPressed: () => _pickWeek(context),
          leadingIcon: const Icon(Icons.calendar_view_week, size: 18),
          child: const Text('Pick a week…'),
        ),
        MenuItemButton(
          onPressed: () => _pickMonth(context),
          leadingIcon: const Icon(Icons.calendar_month, size: 18),
          child: const Text('Pick a month…'),
        ),
      ],
    );

    final metricField = _MenuField(
      label: 'Metric',
      value: metric?.label ?? 'All sensors',
      menuChildren: [
        MenuItemButton(
          onPressed: () => onMetricChanged(null),
          trailingIcon: metric == null
              ? const Icon(Icons.check, size: 18, color: AppColors.primary)
              : null,
          child: const Text('All sensors'),
        ),
        const Divider(),
        ...SoilMetric.values.map(
          (m) => MenuItemButton(
            onPressed: () => onMetricChanged(m),
            trailingIcon: metric == m
                ? const Icon(Icons.check, size: 18, color: AppColors.primary)
                : null,
            child: Text(m.label),
          ),
        ),
      ],
    );

    if (isNarrowPhone(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          periodField,
          const SizedBox(height: 10),
          metricField,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: periodField),
        const SizedBox(width: 10),
        Expanded(child: metricField),
      ],
    );
  }

  Future<void> _pickWeek(BuildContext context) async {
    final picked = await showAnalyticsWeekSheet(context, current: period);
    if (picked != null) onPeriodChanged(picked);
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showAnalyticsMonthSheet(context, current: period);
    if (picked != null) onPeriodChanged(picked);
  }
}

/// Labeled select that opens a Material 3 menu (rounded rectangle, not a pill).
class _MenuField extends StatelessWidget {
  const _MenuField({
    required this.label,
    required this.value,
    required this.menuChildren,
  });

  final String label;
  final String value;
  final List<Widget> menuChildren;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        MenuAnchor(
          style: MenuStyle(
            backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: _fieldRadius,
                side: const BorderSide(color: AppColors.outline),
              ),
            ),
          ),
          builder: (context, controller, _) {
            return Material(
              color: AppColors.surface,
              borderRadius: _fieldRadius,
              child: InkWell(
                borderRadius: _fieldRadius,
                onTap: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: _fieldRadius,
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Icon(
                        Icons.expand_more,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          menuChildren: menuChildren,
        ),
      ],
    );
  }
}

/// Bottom sheet: ISO week picker (tap a day → whole Mon–Sun).
Future<AnalyticsPeriod?> showAnalyticsWeekSheet(
  BuildContext context, {
  required AnalyticsPeriod current,
}) {
  return showModalBottomSheet<AnalyticsPeriod>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _WeekSheet(current: current),
  );
}

/// Bottom sheet: month grid (current month = so far).
Future<AnalyticsPeriod?> showAnalyticsMonthSheet(
  BuildContext context, {
  required AnalyticsPeriod current,
}) {
  return showModalBottomSheet<AnalyticsPeriod>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _MonthSheet(current: current),
  );
}

class _WeekSheet extends StatefulWidget {
  const _WeekSheet({required this.current});

  final AnalyticsPeriod current;

  @override
  State<_WeekSheet> createState() => _WeekSheetState();
}

class _WeekSheetState extends State<_WeekSheet> {
  late DateTime _calMonth;
  late DateTime _draftMonday;

  @override
  void initState() {
    super.initState();
    final seed = widget.current.kind == AnalyticsPeriodKind.customWeek
        ? widget.current.start
        : manilaCalendarDate(DateTime.now());
    _draftMonday = manilaMondayOf(seed);
    _calMonth = DateTime(_draftMonday.year, _draftMonday.month, 1);
  }

  AnalyticsPeriod get _draft => AnalyticsPeriod.customWeek(_draftMonday);

  @override
  Widget build(BuildContext context) {
    final today = manilaCalendarDate(DateTime.now());
    final first = DateTime(_calMonth.year, _calMonth.month, 1);
    final gridStart = manilaMondayOf(first);
    final draft = _draft;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pick a week',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap a day — the whole Monday–Sunday week is selected. Future days are off.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: _fieldRadius,
                ),
                child: Text(
                  formatManilaRange(draft.start, draft.end),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _calMonth = DateTime(_calMonth.year, _calMonth.month - 1);
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_monthName(_calMonth.month)} ${_calMonth.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _calMonth = DateTime(_calMonth.year, _calMonth.month + 1);
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const Row(
              children: [
                _Dow('Mon'),
                _Dow('Tue'),
                _Dow('Wed'),
                _Dow('Thu'),
                _Dow('Fri'),
                _Dow('Sat'),
                _Dow('Sun'),
              ],
            ),
            for (var row = 0; row < 6; row++)
              Row(
                children: List.generate(7, (col) {
                  final day = gridStart.add(Duration(days: row * 7 + col));
                  final out = day.month != _calMonth.month;
                  final future = day.isAfter(today);
                  final inWeek =
                      !day.isBefore(draft.start) && !day.isAfter(draft.end);
                  return Expanded(
                    child: TextButton(
                      onPressed: future
                          ? null
                          : () => setState(() => _draftMonday = manilaMondayOf(day)),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: EdgeInsets.zero,
                        foregroundColor: future
                            ? AppColors.textSecondary
                            : inWeek
                            ? AppColors.primary
                            : out
                            ? AppColors.outline
                            : AppColors.textPrimary,
                        backgroundColor: inWeek
                            ? AppColors.primarySoft
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.horizontal(
                            left: col == 0 || sameManilaDay(day, draft.start)
                                ? const Radius.circular(8)
                                : Radius.zero,
                            right: col == 6 || sameManilaDay(day, draft.end)
                                ? const Radius.circular(8)
                                : Radius.zero,
                          ),
                        ),
                      ),
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: sameManilaDay(day, today) && !inWeek
                              ? TextDecoration.underline
                              : null,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: _sheetBtn(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, draft),
                    style: _sheetBtn(filled: true),
                    child: const Text('Use this week'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthSheet extends StatefulWidget {
  const _MonthSheet({required this.current});

  final AnalyticsPeriod current;

  @override
  State<_MonthSheet> createState() => _MonthSheetState();
}

class _MonthSheetState extends State<_MonthSheet> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    if (widget.current.kind == AnalyticsPeriodKind.customMonth) {
      _year = widget.current.start.year;
      _month = widget.current.start.month;
    } else {
      final today = manilaCalendarDate(DateTime.now());
      _year = today.year;
      _month = today.month;
    }
  }

  AnalyticsPeriod get _draft => AnalyticsPeriod.customMonth(_year, _month);

  @override
  Widget build(BuildContext context) {
    final today = manilaCalendarDate(DateTime.now());
    final draft = _draft;
    final soFar = _year == today.year && _month == today.month;
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pick a month',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'This month is so far (1st through today). Past months are the full month.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: _fieldRadius,
                ),
                child: Text(
                  '${formatManilaRange(draft.start, draft.end)}${soFar ? ' (so far)' : ''}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _year -= 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: _year >= today.year
                      ? null
                      : () => setState(() => _year += 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: List.generate(12, (i) {
                final m = i + 1;
                final future =
                    _year > today.year ||
                    (_year == today.year && m > today.month);
                final selected = m == _month;
                return OutlinedButton(
                  onPressed: future
                      ? null
                      : () => setState(() => _month = m),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: selected
                        ? AppColors.primary
                        : AppColors.surface,
                    foregroundColor: selected
                        ? Colors.white
                        : AppColors.textPrimary,
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.outline,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: _fieldRadius,
                    ),
                  ),
                  child: Text(
                    names[i],
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: _sheetBtn(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, draft),
                    style: _sheetBtn(filled: true),
                    child: const Text('Use this month'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dow extends StatelessWidget {
  const _Dow(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

ButtonStyle _sheetBtn({bool filled = false}) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: _fieldRadius),
    ),
    backgroundColor: filled
        ? const WidgetStatePropertyAll(AppColors.primary)
        : const WidgetStatePropertyAll(AppColors.surface),
    foregroundColor: filled
        ? const WidgetStatePropertyAll(Colors.white)
        : const WidgetStatePropertyAll(AppColors.textPrimary),
  );
}

String _monthName(int month) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return names[month - 1];
}
