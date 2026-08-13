/// Analytics feature page in the app shell content area (second bottom-nav tab).
///
/// Farm notebook: selected Manila window (week / 2 weeks / 30 days / calendar),
/// metric or All-sensors overlay, period avg/min/max, tap-a-day readings, and
/// Groq period AI keyed to that start/end. Not a second Home.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/data/refresh_timeout.dart';
import '../../../shared/navigation/app_page_routes.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
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

  AnalyticsPeriod _period = AnalyticsPeriod.thisWeek();
  SoilMetric? _metric;

  List<DailySoilBucket> _buckets = [];
  Object? _historyError;
  bool _historyDone = false;

  PeriodWeather? _weather;
  Object? _weatherError;
  bool _weatherDone = false;

  PeriodAssessment? _assessment;
  Object? _aiError;
  bool _aiLoading = false;

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

  /// Refetches soil + period weather in parallel, then saved AI.
  Future<void> _reloadAll() async {
    final results = await Future.wait([_loadHistory(), _loadWeather()]);
    final historyOk = results[0];
    if (!historyOk) return;
    await _loadAi();
  }

  /// Returns false when the fetch failed so AI does not use a stale window.
  Future<bool> _loadHistory() async {
    try {
      final buckets = await withRefreshTimeout(
        _historyRepo.fetchDaily(start: _period.start, end: _period.end),
      );
      if (!mounted) return false;
      setState(() {
        _buckets = buckets;
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
    Navigator.of(context).push(
      AppPageRoutes.slideFromRight(DayReadingsPage(manilaDate: manilaDate)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waitingFirst =
        !_historyDone && _buckets.isEmpty && _historyError == null;
    final stats = _metric == null ? null : metricStats(_buckets, _metric!);
    final shortHistory =
        _historyDone &&
        _buckets.isNotEmpty &&
        _buckets.length < _period.dayCount;

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
          ] else ...[
            if (shortHistory) ...[
              SoftCard(
                color: AppColors.tertiarySoft,
                child: Text(
                  '${_buckets.length} day${_buckets.length == 1 ? '' : 's'} of data — not a full ${_period.dayCount} days. Averages use only days with readings.',
                  style: const TextStyle(height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _TrendCard(
              period: _period,
              metric: _metric,
              buckets: _buckets,
              stats: stats,
              onDayTap: _openDay,
              onSelectMetric: (m) => setState(() => _metric = m),
            ),
            const SizedBox(height: 16),
            ..._weatherSection(),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Past period',
              icon: Icons.auto_awesome,
            ),
            const SizedBox(height: 4),
            Text(
              'Kalagayan of ${_period.label.toLowerCase()}, then actions for better soil and crops.',
              style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
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
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.period,
    required this.metric,
    required this.buckets,
    required this.stats,
    required this.onDayTap,
    required this.onSelectMetric,
  });

  final AnalyticsPeriod period;
  final SoilMetric? metric;
  final List<DailySoilBucket> buckets;
  final MetricPeriodStats? stats;
  final void Function(DateTime manilaDate) onDayTap;
  final ValueChanged<SoilMetric> onSelectMetric;

  @override
  Widget build(BuildContext context) {
    final days = period.days;
    final byDate = {
      for (final b in buckets)
        DateTime(b.bucketDate.year, b.bucketDate.month, b.bucketDate.day): b,
    };
    final overlay = metric == null;
    final title = overlay
        ? 'All sensors · ${period.label.toLowerCase()}'
        : '${metric!.label} · ${period.label.toLowerCase()}';

    final first = days.first;
    final mid = days[days.length ~/ 2];
    final last = days.last;

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
          const SizedBox(height: 12),
          SizedBox(
            height: overlay ? 168 : 160,
            width: double.infinity,
            child: overlay
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
                    values: [
                      for (final d in days)
                        byDate[d] == null ? null : metric!.avgOf(byDate[d]!),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _axisLabel(_md(first)),
              _axisLabel(_md(mid)),
              _axisLabel(_md(last)),
            ],
          ),
          if (overlay) ...[
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
            const Text(
              'One chart, all eight. Each line is scaled to its typical range so % and pH can sit together — tap a box for real units.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _SensorAvgGrid(
              buckets: buckets,
              onSelectMetric: onSelectMetric,
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
                  value: formatMetric(stats!.average, metric!),
                ),
                second: _CaptionStat(
                  label: 'Min / max',
                  value:
                      '${formatMetric(stats!.min, metric!)} – ${formatMetric(stats!.max, metric!)}',
                ),
              ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Tap the chart to open that day’s readings.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static String _md(DateTime d) => '${d.month}/${d.day}';

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
  });

  final List<double?>? values;
  final List<(Color color, List<double?> values)>? overlaySeries;
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
                : _TrendChartPainter(values: values ?? const []),
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
  });

  final List<DailySoilBucket> buckets;
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
                  onTap: () => onSelectMetric(metrics[i]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: i + 1 < metrics.length
                    ? _SensorAvgTile(
                        metric: metrics[i + 1],
                        stats: metricStats(buckets, metrics[i + 1]),
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

/// One sensor's avg/min/max for the selected window. Tap opens that metric chart.
class _SensorAvgTile extends StatelessWidget {
  const _SensorAvgTile({
    required this.metric,
    required this.stats,
    required this.onTap,
  });

  final SoilMetric metric;
  final MetricPeriodStats? stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.outline),
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
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
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
          const SectionHeader(title: 'Weather this window', icon: Icons.cloud_outlined),
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
                                : (4 + (day.rainfallMm / peakRain) * 40)
                                    .clamp(4, 44),
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
              style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
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
class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({required this.values});

  final List<double?> values;

  @override
  void paint(Canvas canvas, Size size) {
    final numeric = values.whereType<double>().toList();
    if (numeric.isEmpty || values.length < 2) {
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

    final path = Path();
    var started = false;
    final n = values.length;
    for (var i = 0; i < n; i++) {
      final v = values[i];
      if (v == null) {
        started = false;
        continue;
      }
      final x = n == 1 ? size.width / 2 : size.width * (i / (n - 1));
      final y = size.height - ((v - minV) / (maxV - minV)) * size.height;
      final clampedY = y.clamp(2.0, size.height - 2);
      if (!started) {
        path.moveTo(x, clampedY);
        started = true;
      } else {
        path.lineTo(x, clampedY);
      }
    }

    final line = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);

    final dot = Paint()..color = AppColors.primary;
    for (var i = 0; i < n; i++) {
      final v = values[i];
      if (v == null) continue;
      final x = n == 1 ? size.width / 2 : size.width * (i / (n - 1));
      final y = size.height - ((v - minV) / (maxV - minV)) * size.height;
      canvas.drawCircle(Offset(x, y.clamp(2.0, size.height - 2)), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.values != values;
}

/// Several 0–1 series (All sensors). No dots — eight series would clutter.
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
    if (numeric.isEmpty || values.length < 2) return;

    final path = Path();
    var started = false;
    final n = values.length;
    for (var i = 0; i < n; i++) {
      final v = values[i];
      if (v == null) {
        started = false;
        continue;
      }
      final x = n == 1 ? size.width / 2 : size.width * (i / (n - 1));
      final y = size.height - (v.clamp(0.0, 1.0) * size.height);
      final clampedY = y.clamp(2.0, size.height - 2);
      if (!started) {
        path.moveTo(x, clampedY);
        started = true;
      } else {
        path.lineTo(x, clampedY);
      }
    }

    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _OverlayChartPainter oldDelegate) =>
      oldDelegate.series != series;
}
