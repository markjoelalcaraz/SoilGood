/// Analytics feature page in the app shell content area (second bottom-nav tab).
///
/// Farm notebook: selected Manila window, **All sensors** by default (scaled
/// overlay — intra-day when only one day has data, daily Mon–Sun when ≥2),
/// or one metric in real units. Groq period AI keyed to start/end. Not a
/// second Home.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/data/refresh_timeout.dart';
import '../../../shared/navigation/app_page_routes.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../crops/data/irrigation_plan_repository.dart';
import '../../home/data/soil_reading.dart';
import '../../shell/app_shell.dart';
import '../data/daily_soil_bucket.dart';
import '../data/period_ai_repository.dart';
import '../data/period_assessment.dart';
import '../data/period_weather.dart';
import '../data/period_weather_repository.dart';
import '../data/soil_history_repository.dart';
import '../logic/analytics_period.dart';
import '../logic/analytics_stats.dart';
import '../logic/groq_period_ai_client.dart';
import '../logic/manila_time.dart';
import '../logic/period_ai_regen.dart';
import 'analytics_filters.dart';
import 'day_readings_page.dart';
import 'metric_chart_style.dart';

/// Over-time soil history + Groq period recommendations.
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final _historyRepo = SoilHistoryRepository();
  final _weatherRepo = PeriodWeatherRepository();
  final _aiRepo = PeriodAiRepository();
  final _groq = GroqPeriodAiClient();
  final _irrigationRepo = IrrigationPlanRepository();

  AnalyticsPeriod _period = AnalyticsPeriod.thisWeek();

  /// Null = All sensors (scaled overlay / intra-day). Default.
  SoilMetric? _metric;

  List<DailySoilBucket> _buckets = [];
  /// Raw readings for the only day in the window (All-sensors intra-day lines).
  List<SoilReading> _intraDay = [];
  Object? _historyError;
  bool _historyDone = false;

  PeriodWeather? _weather;
  Object? _weatherError;
  bool _weatherDone = false;

  PeriodAssessment? _assessment;
  Object? _aiError;
  bool _aiLoading = false;

  int? _irrigationCount;
  List<Map<String, dynamic>> _irrigationHistory = [];
  Object? _irrigationError;
  bool _irrigationDone = false;

  bool _started = false;

  /// IndexedStack builds this tab offstage with Home. Wait until Analytics
  /// is actually visible so Groq is not called on every app open.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && TickerMode.valuesOf(context).enabled) {
      _started = true;
      _reloadAll();
    }
  }

  /// Refetches soil + period weather + irrigation logs in parallel, then saved AI.
  Future<void> _reloadAll() async {
    final results = await Future.wait([
      _loadHistory(),
      _loadWeather(),
      _loadIrrigationLogs(),
    ]);
    final historyOk = results[0];
    if (!historyOk) return;
    await _loadAi();
  }

  /// Count + recent Mark watered rows for the selected Manila window.
  Future<bool> _loadIrrigationLogs() async {
    try {
      final farmId = await withRefreshTimeout(
        _historyRepo.fetchPrimaryFarmId(),
      );
      if (farmId == null) {
        throw StateError('No farm found. Finish onboarding first.');
      }
      final count = await withRefreshTimeout(
        _irrigationRepo.countIrrigations(
          farmId: farmId,
          start: _period.start,
          end: _period.end,
        ),
      );
      final history = await withRefreshTimeout(
        _irrigationRepo.fetchIrrigationHistory(
          farmId: farmId,
          start: _period.start,
          end: _period.end,
        ),
      );
      if (!mounted) return false;
      setState(() {
        _irrigationCount = count;
        _irrigationHistory = history;
        _irrigationError = null;
        _irrigationDone = true;
      });
      return true;
    } on Object catch (e) {
      if (!mounted) return false;
      setState(() {
        _irrigationError = e;
        _irrigationDone = true;
      });
      return false;
    }
  }

  /// Returns false when the fetch failed so AI does not use a stale window.
  Future<bool> _loadHistory() async {
    try {
      final buckets = await withRefreshTimeout(
        _historyRepo.fetchDaily(start: _period.start, end: _period.end),
      );
      // One calendar day → load raw rows so All sensors can draw intra-day lines.
      var intra = <SoilReading>[];
      if (buckets.length == 1) {
        intra = await withRefreshTimeout(
          _historyRepo.fetchForDay(buckets.first.bucketDate),
        );
      }
      if (!mounted) return false;
      setState(() {
        _buckets = buckets;
        _intraDay = intra;
        _historyError = null;
        _historyDone = true;
      });
      return true;
    } on Object catch (e) {
      if (!mounted) return false;
      setState(() {
        _historyError = e;
        _historyDone = true;
      });
      return false;
    }
  }

  /// Period weather for the selected window. Failure does not block soil.
  Future<bool> _loadWeather() async {
    try {
      final weather = await withRefreshTimeout(
        _weatherRepo.fetchRange(start: _period.start, end: _period.end),
      );
      if (!mounted) return false;
      setState(() {
        _weather = weather;
        _weatherError = null;
        _weatherDone = true;
      });
      return true;
    } on Object catch (e) {
      if (!mounted) return false;
      setState(() {
        _weatherError = e;
        _weatherDone = true;
      });
      return false;
    }
  }

  Future<void> _loadAi() async {
    if (_buckets.isEmpty) {
      if (!mounted) return;
      setState(() {
        _assessment = null;
        _aiError = null;
        _aiLoading = false;
      });
      return;
    }

    setState(() => _aiLoading = true);

    try {
      final farmId = await _historyRepo.fetchPrimaryFarmId();
      if (farmId == null) {
        throw StateError('No farm found. Finish onboarding first.');
      }

      final saved = await withRefreshTimeout(
        _aiRepo.fetchLatest(
          farmId: farmId,
          periodStart: _period.start,
          periodEnd: _period.end,
        ),
      );

      if (!shouldRegenPeriodAi(
        saved: saved,
        period: _period,
        buckets: _buckets,
      )) {
        if (!mounted) return;
        setState(() {
          _assessment = saved;
          _aiError = null;
          _aiLoading = false;
        });
        return;
      }

      final crop = await _historyRepo.fetchActiveCropName();
      final generated = await _groq.generate(
        period: _period,
        buckets: _buckets,
        weather: _weather,
        cropName: crop,
      );
      final validUntil = DateTime.now().add(const Duration(hours: 24));
      final savedNew = await withRefreshTimeout(
        _aiRepo.save(
          farmId: farmId,
          periodStart: _period.start,
          periodEnd: _period.end,
          periodDays: _period.dayCount,
          overview: generated.overview,
          soilHealthScore: generated.soilHealthScore,
          modelName: kGroqModel,
          promptVersion: kPeriodAiPromptVersion,
          validUntil: validUntil,
          recommendations: generated.recommendations,
        ),
      );
      if (!mounted) return;
      setState(() {
        _assessment = savedNew;
        _aiError = null;
        _aiLoading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = e;
        _aiLoading = false;
      });
    }
  }

  Future<void> _onPeriodChanged(AnalyticsPeriod next) async {
    if (sameManilaDay(next.start, _period.start) &&
        sameManilaDay(next.end, _period.end) &&
        next.kind == _period.kind) {
      return;
    }
    setState(() {
      _period = next;
      _assessment = null;
      _aiError = null;
      _weather = null;
      _weatherError = null;
      _weatherDone = false;
    });
    await _reloadAll();
  }

  void _openDay(DateTime manilaDate) {
    final today = manilaCalendarDate(DateTime.now());
    // Week chart may include Tue–Sun with no data yet — ignore future taps.
    if (manilaDate.isAfter(today)) return;
    Navigator.of(context).push(
      AppPageRoutes.slideFromRight(DayReadingsPage(manilaDate: manilaDate)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waitingFirst =
        !_historyDone && _buckets.isEmpty && _historyError == null;
    // 1 calendar day with raw rows → intra-day trend (All sensors or one metric).
    final useAllSensors = _metric == null;
    final useIntraDay = _buckets.length < 2 && _intraDay.isNotEmpty;
    final useDailyOverlay = useAllSensors && _buckets.length >= 2;
    final chartMetric = _metric ?? SoilMetric.moisture;
    final stats = useAllSensors ? null : metricStats(_buckets, chartMetric);
    // Week skeleton is 7 slots; data window may still be Mon→today only.
    final expectedChartDays = _period.usesWeekChartSkeleton
        ? _period.chartDays.length
        : _period.dayCount;
    final shortHistory =
        _historyDone &&
        _buckets.isNotEmpty &&
        _buckets.length < expectedChartDays;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SoilGoodTopBar(
        title: 'Analytics',
        leadingIcon: Icons.insights,
      ),
      body: AppRefreshScroll(
        onRefresh: _reloadAll,
        children: [
          Text(
            'Soil over time',
            style: GoogleFonts.literata(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'History, averages, and what to do next for soil and crops — not today’s live reading.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          AnalyticsFilterBar(
            period: _period,
            metric: _metric,
            onPeriodChanged: _onPeriodChanged,
            onMetricChanged: (m) => setState(() => _metric = m),
          ),
          const SizedBox(height: 16),
          if (_historyError != null) ...[
            _SourceErrorCard(
              message: 'Could not load history:\n$_historyError',
            ),
            const SizedBox(height: 12),
          ],
          if (waitingFirst)
            const _AnalyticsFirstLoadSkeleton()
          else if (_buckets.isEmpty) ...[
            const SoftCard(
              child: Text(
                'No soil history yet.\nLink a device and wait for readings, then pull to refresh.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            ..._weatherSection(),
            const SizedBox(height: 16),
            ..._irrigationSection(),
          ] else ...[
            if (shortHistory) ...[
              SoftCard(
                color: AppColors.tertiarySoft,
                child: Text(
                  _period.usesWeekChartSkeleton
                      ? '${_buckets.length} day${_buckets.length == 1 ? '' : 's'} of data this week — chart shows Mon–Sun; empty days are not yet. Averages use only days with readings.'
                      : '${_buckets.length} day${_buckets.length == 1 ? '' : 's'} of data — not a full ${_period.dayCount} days. Averages use only days with readings.',
                  style: const TextStyle(height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _TrendCard(
              period: _period,
              metric: _metric,
              chartMetric: chartMetric,
              useIntraDay: useIntraDay,
              useDailyOverlay: useDailyOverlay,
              buckets: _buckets,
              intraDay: _intraDay,
              stats: stats,
              onDayTap: _openDay,
              onSelectMetric: (m) => setState(() => _metric = m),
            ),
            const SizedBox(height: 16),
            ..._weatherSection(),
            const SizedBox(height: 16),
            ..._irrigationSection(),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Past period', icon: Icons.auto_awesome),
            const SizedBox(height: 4),
            Text(
              'Kalagayan of ${_period.label.toLowerCase()}, then actions for better soil and crops.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (_aiError != null) ...[
              _SourceErrorCard(message: 'Period AI unavailable:\n$_aiError'),
              const SizedBox(height: 12),
            ],
            if (_aiLoading && _assessment == null)
              const SoftCard(
                color: AppColors.surfaceMuted,
                child: SizedBox(height: 140),
              )
            else if (_assessment != null)
              _PeriodAiBlock(assessment: _assessment!),
          ],
        ],
      ),
    );
  }

  /// Period weather block — independent of soil so a weather error is visible.
  List<Widget> _weatherSection() {
    if (_weatherError != null) {
      return [
        _SourceErrorCard(
          message: 'Could not load period weather:\n$_weatherError',
        ),
      ];
    }
    if (!_weatherDone && _weather == null) {
      return [
        const SoftCard(
          color: AppColors.surfaceMuted,
          child: SizedBox(height: 120),
        ),
      ];
    }
    if (_weather == null) return const [];
    return [
      _PeriodWeatherCard(
        period: _period,
        weather: _weather!,
        onDayTap: _openDay,
      ),
    ];
  }

  /// Mark watered counts from farm_actions for this window.
  List<Widget> _irrigationSection() {
    if (_irrigationError != null) {
      return [
        _SourceErrorCard(
          message: 'Could not load watering logs:\n$_irrigationError',
        ),
      ];
    }
    if (!_irrigationDone && _irrigationCount == null) {
      return [
        const SoftCard(
          color: AppColors.surfaceMuted,
          child: SizedBox(height: 88),
        ),
      ];
    }
    return [
      _IrrigationLogCard(
        period: _period,
        count: _irrigationCount ?? 0,
        history: _irrigationHistory,
      ),
    ];
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.period,
    required this.metric,
    required this.chartMetric,
    required this.useIntraDay,
    required this.useDailyOverlay,
    required this.buckets,
    required this.intraDay,
    required this.stats,
    required this.onDayTap,
    required this.onSelectMetric,
  });

  final AnalyticsPeriod period;

  /// Null = All sensors.
  final SoilMetric? metric;
  final SoilMetric chartMetric;
  final bool useIntraDay;
  final bool useDailyOverlay;
  final List<DailySoilBucket> buckets;
  final List<SoilReading> intraDay;
  final MetricPeriodStats? stats;
  final void Function(DateTime manilaDate) onDayTap;
  final ValueChanged<SoilMetric> onSelectMetric;

  @override
  Widget build(BuildContext context) {
    final allSensors = metric == null;
    final days = period.chartDays;
    final byDate = {
      for (final b in buckets)
        DateTime(b.bucketDate.year, b.bucketDate.month, b.bucketDate.day): b,
    };

    final title = useIntraDay
        ? (allSensors
            ? 'All sensors · today (intra-day)'
            : '${chartMetric.label} · today (intra-day)')
        : allSensors
            ? 'All sensors · ${period.label.toLowerCase()}'
            : '${chartMetric.label} · ${period.label.toLowerCase()}';

    final weekSkeleton = !useIntraDay &&
        period.usesWeekChartSkeleton &&
        days.last.isAfter(period.end);

    final showOverlayChart = useIntraDay || useDailyOverlay;
    final thinIntra = !useIntraDay && buckets.length < 2 && intraDay.isEmpty;

    return SoftCard(
      color: AppColors.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
          if (thinIntra) ...[
            const SizedBox(height: 8),
            const Text(
              'Waiting for more readings today so the chart can draw a trend line.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: showOverlayChart ? 168 : 160,
            width: double.infinity,
            child: useIntraDay
                ? (allSensors
                    ? _TappableChart(
                        days: [
                          for (final r in intraDay)
                            manilaCalendarDate(r.recordedAt),
                        ],
                        onDayTap: onDayTap,
                        overlaySeries: [
                          for (final m in SoilMetric.values)
                            (
                              metricChartColor(m),
                              [
                                for (final r in intraDay)
                                  metricOverlayFromRaw(m, m.valueOfReading(r)),
                              ],
                            ),
                        ],
                      )
                    : _TappableChart(
                        days: [
                          for (final r in intraDay)
                            manilaCalendarDate(r.recordedAt),
                        ],
                        onDayTap: onDayTap,
                        lineColor: metricChartColor(chartMetric),
                        values: [
                          for (final r in intraDay)
                            chartMetric.valueOfReading(r),
                        ],
                      ))
                : useDailyOverlay
                    ? _TappableChart(
                        days: days,
                        onDayTap: onDayTap,
                        overlaySeries: [
                          for (final m in SoilMetric.values)
                            (
                              metricChartColor(m),
                              [
                                for (final d in days)
                                  byDate[d] == null
                                      ? null
                                      : metricOverlayUnit(m, byDate[d]!),
                              ],
                            ),
                        ],
                      )
                    : _TappableChart(
                        days: days,
                        onDayTap: onDayTap,
                        lineColor: metricChartColor(chartMetric),
                        values: [
                          for (final d in days)
                            byDate[d] == null
                                ? null
                                : chartMetric.avgOf(byDate[d]!),
                        ],
                      ),
          ),
          const SizedBox(height: 8),
          if (useIntraDay)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _axisLabel(_intraAxisLabels(intraDay).left),
                _axisLabel(_intraAxisLabels(intraDay).mid),
                _axisLabel(_intraAxisLabels(intraDay).right),
              ],
            )
          else if (days.length <= 7)
            Row(
              children: [
                for (final d in days)
                  Expanded(
                    child: Text(
                      _mdPad(d),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _axisLabel(_mdPad(days.first)),
                _axisLabel(_mdPad(days[days.length ~/ 2])),
                _axisLabel(_mdPad(days.last)),
              ],
            ),
          if (useIntraDay) ...[
            const SizedBox(height: 8),
            Text(
              allSensors
                  ? 'One day in this window — lines are today’s 15-min readings (scaled). Pick a single metric for real units.'
                  : 'One day in this window — line is today’s 15-min ${chartMetric.label} readings.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ] else if (weekSkeleton) ...[
            const SizedBox(height: 8),
            const Text(
              'Mon–Sun week. Today sits on its weekday; empty days are still ahead.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (allSensors) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in SoilMetric.values)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: metricChartColor(m),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          m.label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              useIntraDay
                  ? 'All sensors graph for today. Tap a tile for one metric in real units.'
                  : 'Daily All sensors (scaled). Tap a tile for one metric in real units.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ] else ...[
            const Divider(height: 28),
            if (stats == null)
              const Text(
                'No values for this metric in the window.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ResponsiveTwoUp(
                first: _CaptionStat(
                  label: 'Avg (${stats!.dayCount}d)',
                  value: formatMetric(stats!.average, chartMetric),
                ),
                second: _CaptionStat(
                  label: 'Min / max',
                  value:
                      '${formatMetric(stats!.min, chartMetric)} – ${formatMetric(stats!.max, chartMetric)}',
                ),
              ),
          ],
          const SizedBox(height: 16),
          const Text(
            'SENSORS THIS WINDOW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a tile to chart that metric in real units.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          _SensorAvgGrid(
            buckets: buckets,
            selected: allSensors ? null : chartMetric,
            onSelectMetric: onSelectMetric,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the chart to open that day’s readings.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static String _mdPad(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$m/$day';
  }

  static String _hm(DateTime instant) {
    final m = instant.toUtc().add(kManilaOffset);
    final h = m.hour.toString().padLeft(2, '0');
    final min = m.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  static ({String left, String mid, String right}) _intraAxisLabels(
    List<SoilReading> readings,
  ) {
    if (readings.isEmpty) {
      return (left: '—', mid: '—', right: '—');
    }
    final first = readings.first.recordedAt;
    final mid = readings[readings.length ~/ 2].recordedAt;
    final last = readings.last.recordedAt;
    return (left: _hm(first), mid: _hm(mid), right: _hm(last));
  }

  static Widget _axisLabel(String text) => Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      );
}

class _TappableChart extends StatelessWidget {
  const _TappableChart({
    required this.days,
    required this.onDayTap,
    this.values,
    this.overlaySeries,
    this.lineColor,
  });

  final List<double?>? values;
  final List<(Color color, List<double?> values)>? overlaySeries;
  final Color? lineColor;
  final List<DateTime> days;
  final void Function(DateTime manilaDate) onDayTap;

  void _handle(Offset local, double width) {
    if (days.isEmpty || width <= 0) return;
    final t = (local.dx / width).clamp(0.0, 1.0);
    final i = (t * (days.length - 1)).round().clamp(0, days.length - 1);
    onDayTap(days[i]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final series = overlaySeries;
        return GestureDetector(
          onTapDown: (d) => _handle(d.localPosition, constraints.maxWidth),
          child: CustomPaint(
            painter: series != null
                ? _OverlayChartPainter(series: series)
                : _TrendChartPainter(
                    values: values ?? const [],
                    lineColor: lineColor ?? AppColors.primary,
                  ),
            size: Size(constraints.maxWidth, constraints.maxHeight),
          ),
        );
      },
    );
  }
}

class _SensorAvgGrid extends StatelessWidget {
  const _SensorAvgGrid({
    required this.buckets,
    required this.onSelectMetric,
    this.selected,
  });

  final List<DailySoilBucket> buckets;
  final SoilMetric? selected;
  final ValueChanged<SoilMetric> onSelectMetric;

  @override
  Widget build(BuildContext context) {
    final metrics = SoilMetric.values;
    return Column(
      children: [
        for (var i = 0; i < metrics.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SensorAvgTile(
                  metric: metrics[i],
                  stats: metricStats(buckets, metrics[i]),
                  selected: selected == metrics[i],
                  onTap: () => onSelectMetric(metrics[i]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: i + 1 < metrics.length
                    ? _SensorAvgTile(
                        metric: metrics[i + 1],
                        stats: metricStats(buckets, metrics[i + 1]),
                        selected: selected == metrics[i + 1],
                        onTap: () => onSelectMetric(metrics[i + 1]),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One sensor's avg/min/max for the selected window. Tap charts that metric.
class _SensorAvgTile extends StatelessWidget {
  const _SensorAvgTile({
    required this.metric,
    required this.stats,
    required this.onTap,
    this.selected = false,
  });

  final SoilMetric metric;
  final MetricPeriodStats? stats;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: metricChartColor(metric),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      metric.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                stats == null ? '—' : formatMetric(stats!.average, metric),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Text(
                stats == null
                    ? 'No readings'
                    : 'Min ${formatMetric(stats!.min, metric)} · Max ${formatMetric(stats!.max, metric)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rain + temp for the selected Analytics window — not Home's live forecast.
class _PeriodWeatherCard extends StatelessWidget {
  const _PeriodWeatherCard({
    required this.period,
    required this.weather,
    required this.onDayTap,
  });

  final AnalyticsPeriod period;
  final PeriodWeather weather;
  final void Function(DateTime manilaDate) onDayTap;

  @override
  Widget build(BuildContext context) {
    final avgHigh = weather.avgTempMaxC;
    final avgLow = weather.avgTempMinC;
    final peakRain = weather.days.fold<double>(
      0,
      (m, d) => d.rainfallMm > m ? d.rainfallMm : m,
    );

    return SoftCard(
      color: AppColors.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Weather this window',
            icon: Icons.cloud_outlined,
          ),
          const SizedBox(height: 4),
          Text(
            'Rain and temperature for ${period.label.toLowerCase()} — not today’s forecast.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          ResponsiveTwoUp(
            first: _CaptionStat(
              label: 'Total rain',
              value: '${weather.totalRainMm.toStringAsFixed(1)} mm',
            ),
            second: _CaptionStat(
              label: 'Rainy days',
              value: '${weather.rainyDayCount}',
            ),
          ),
          const SizedBox(height: 10),
          ResponsiveTwoUp(
            first: _CaptionStat(
              label: 'Avg high',
              value: avgHigh == null ? '—' : '${avgHigh.toStringAsFixed(0)}°C',
            ),
            second: _CaptionStat(
              label: 'Avg low',
              value: avgLow == null ? '—' : '${avgLow.toStringAsFixed(0)}°C',
            ),
          ),
          if (weather.days.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in weather.days)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onDayTap(
                          DateTime(day.date.year, day.date.month, day.date.day),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Container(
                            height: peakRain <= 0
                                ? 4
                                : (4 + (day.rainfallMm / peakRain) * 40).clamp(
                                    4,
                                    44,
                                  ),
                            decoration: BoxDecoration(
                              color: day.rainfallMm >= 1
                                  ? AppColors.primary
                                  : AppColors.outline,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bars = rain that day. Tap a bar for that day’s soil readings.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Logged Mark watered actions for the selected Analytics window.
class _IrrigationLogCard extends StatelessWidget {
  const _IrrigationLogCard({
    required this.period,
    required this.count,
    required this.history,
  });

  final AnalyticsPeriod period;
  final int count;
  final List<Map<String, dynamic>> history;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Watering this window',
            icon: Icons.water_drop_outlined,
          ),
          const SizedBox(height: 4),
          Text(
            'Times you marked watered in ${period.label.toLowerCase()} — from Crops plan logs.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: GoogleFonts.literata(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          Text(
            count == 1 ? 'watering logged' : 'waterings logged',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final row in history.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatWhen(row['performed_at'] as String?),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _formatWhen(String? raw) {
    if (raw == null) return 'Unknown time';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m/$d · $h:$min';
  }
}

class _CaptionStat extends StatelessWidget {
  const _CaptionStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: GoogleFonts.literata(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodAiBlock extends StatelessWidget {
  const _PeriodAiBlock({required this.assessment});

  final PeriodAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final score = assessment.soilHealthScore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftCard(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kalagayan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.literata(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (score != null)
                    StatusChip(
                      label: 'Score ${score.round()}',
                      tone: score >= 60
                          ? StatusChipTone.good
                          : StatusChipTone.warn,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                assessment.overview,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...assessment.recommendations.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AdviceCard(rec: r),
          ),
        ),
      ],
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.rec});

  final PeriodRecommendation rec;

  @override
  Widget build(BuildContext context) {
    final icon = switch (rec.type) {
      'irrigation' => Icons.water_drop_outlined,
      'nutrient' => Icons.science_outlined,
      'crop_suitability' => Icons.eco_outlined,
      _ => Icons.grass_outlined,
    };
    final tone = rec.priority == 'high'
        ? StatusChipTone.warn
        : rec.priority == 'low'
        ? StatusChipTone.neutral
        : StatusChipTone.good;

    return SoftCard(
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rec.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.literata(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
              StatusChip(label: rec.priority.toUpperCase(), tone: tone),
            ],
          ),
          if (rec.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              rec.description,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
          if (rec.recommendedAction.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              rec.recommendedAction,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceErrorCard extends StatelessWidget {
  const _SourceErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.errorContainer,
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF690005), height: 1.5),
      ),
    );
  }
}

class _AnalyticsFirstLoadSkeleton extends StatelessWidget {
  const _AnalyticsFirstLoadSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftCard(color: AppColors.surfaceMuted, child: SizedBox(height: 200)),
        SizedBox(height: 16),
        SoftCard(color: AppColors.surfaceMuted, child: SizedBox(height: 120)),
      ],
    );
  }
}

/// Line chart of daily averages; null days are gaps.
///
/// One-day windows (e.g. This week on Monday) draw a single dot — a line
/// needs two points, but today still belongs on the chart.
class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({required this.values, required this.lineColor});

  final List<double?> values;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final numeric = values.whereType<double>().toList();
    if (numeric.isEmpty) {
      final paint = Paint()
        ..color = AppColors.outline
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    var minV = numeric.first;
    var maxV = numeric.first;
    for (final v in numeric) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    if (maxV == minV) {
      minV -= 1;
      maxV += 1;
    }

    final n = values.length;
    double xAt(int i) => n == 1 ? size.width / 2 : size.width * (i / (n - 1));
    double yAt(double v) {
      final y = size.height - ((v - minV) / (maxV - minV)) * size.height;
      return y.clamp(2.0, size.height - 2);
    }

    // Need ≥2 plotted points for a segment; one day still gets a visible dot.
    if (numeric.length >= 2) {
      final path = Path();
      var started = false;
      for (var i = 0; i < n; i++) {
        final v = values[i];
        if (v == null) {
          started = false;
          continue;
        }
        final x = xAt(i);
        final y = yAt(v);
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }

      final line = Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, line);
    }

    final dot = Paint()..color = lineColor;
    final radius = numeric.length == 1 ? 5.0 : 3.5;
    for (var i = 0; i < n; i++) {
      final v = values[i];
      if (v == null) continue;
      canvas.drawCircle(Offset(xAt(i), yAt(v)), radius, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.lineColor != lineColor;
}

/// Several 0–1 series (All sensors). Dots only when a series has a single day.
class _OverlayChartPainter extends CustomPainter {
  _OverlayChartPainter({required this.series});

  final List<(Color color, List<double?> values)> series;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (color, values) in series) {
      _strokeSeries(canvas, size, color, values);
    }
  }

  void _strokeSeries(
    Canvas canvas,
    Size size,
    Color color,
    List<double?> values,
  ) {
    final numeric = values.whereType<double>().toList();
    if (numeric.isEmpty) return;

    final n = values.length;
    double xAt(int i) => n == 1 ? size.width / 2 : size.width * (i / (n - 1));
    double yAt(double v) {
      final y = size.height - (v.clamp(0.0, 1.0) * size.height);
      return y.clamp(2.0, size.height - 2);
    }

    if (numeric.length >= 2) {
      final path = Path();
      var started = false;
      for (var i = 0; i < n; i++) {
        final v = values[i];
        if (v == null) {
          started = false;
          continue;
        }
        final x = xAt(i);
        final y = yAt(v);
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }

      final line = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, line);
      return;
    }

    // One-day window (or one non-null day): show a colored point per series.
    final dot = Paint()..color = color;
    for (var i = 0; i < n; i++) {
      final v = values[i];
      if (v == null) continue;
      canvas.drawCircle(Offset(xAt(i), yAt(v)), 4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayChartPainter oldDelegate) =>
      oldDelegate.series != series;
}
