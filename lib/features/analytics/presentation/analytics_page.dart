/// Analytics feature page shown inside the app shell content area (second bottom-nav tab).
///
/// Intended for trends, soil-health style insights, and recommendation cards so
/// the farmer can plan ahead. UI shell is in place; data is still mostly mock
/// until history + weather snapshots are wired.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../shell/app_shell.dart';

/// Analytics UI — trends + recommendations; mock data only.
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SoilGoodTopBar(
        title: 'Analytics',
        leadingIcon: Icons.insights,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Soil Health Trend',
            style: GoogleFonts.literata(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Moisture and pH patterns over the last 30 days (sample data).',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          SoftCard(
            color: AppColors.surface,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Row(
                  children: [
                    _LegendDot(color: AppColors.primary, label: 'Moisture'),
                    SizedBox(width: 16),
                    _LegendDot(color: AppColors.tertiary, label: 'pH'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: CustomPaint(painter: _TrendChartPainter()),
                ),
                const Divider(height: 28),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Day 1',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Day 10',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Day 20',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Day 30',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.55,
                  children: const [
                    _StatMini(
                      label: 'Avg Moisture',
                      value: '68%',
                      note: 'Optimal',
                    ),
                    _StatMini(label: 'Avg pH', value: '6.4', note: 'Stable'),
                    _StatMini(
                      label: 'Soil Temp',
                      value: '22°C',
                      note: 'Good for roots',
                    ),
                    _StatMini(label: 'EC', value: '1.2', note: 'Balanced'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Current Weather'),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: SoftCard(
                  child: _MiniWeather(label: 'Air Temp', value: '28°C'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: SoftCard(
                  child: _MiniWeather(label: 'Condition', value: 'Sunny'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(
                child: SoftCard(
                  child: _MiniWeather(label: 'Humidity', value: '65%'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: SoftCard(
                  child: _MiniWeather(label: 'Rainfall', value: '2.5mm'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'AI Recommendations',
                  style: GoogleFonts.literata(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const StatusChip(label: 'SAMPLE', tone: StatusChipTone.good),
            ],
          ),
          const SizedBox(height: 12),
          const _AdviceBlock(
            icon: Icons.schedule,
            title: 'Irrigation Forecast',
            headline: 'Next watering: Tomorrow 6:00 AM',
            body:
                'Moisture around 68%. Early morning watering helps roots before peak heat.',
          ),
          const SizedBox(height: 12),
          const _AdviceBlock(
            icon: Icons.thunderstorm_outlined,
            title: 'Weather Guidance',
            headline: 'Rain coming — delay fertilizer',
            body:
                'Showers expected mid-week. Wait so nutrients are not washed away.',
            color: AppColors.tertiary,
          ),
          const SizedBox(height: 12),
          const _AdviceBlock(
            icon: Icons.science_outlined,
            title: 'Nutrient Optimization',
            headline: 'Nitrogen slightly low',
            body:
                'A light top-dressing after rain can improve uptake without wasting fertilizer.',
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({
    required this.label,
    required this.value,
    required this.note,
  });
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.literata(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          Text(
            note,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniWeather extends StatelessWidget {
  const _MiniWeather({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.literata(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AdviceBlock extends StatelessWidget {
  const _AdviceBlock({
    required this.icon,
    required this.title,
    required this.headline,
    required this.body,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String headline;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.literata(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Simple dual-line trend chart for mock analytics.
class _TrendChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final moisture = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final ph = Paint()
      ..color = AppColors.tertiary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final mPath = Path()
      ..moveTo(0, size.height * 0.7)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.55,
        size.width * 0.35,
        size.height * 0.8,
        size.width * 0.5,
        size.height * 0.45,
      )
      ..cubicTo(
        size.width * 0.65,
        size.height * 0.25,
        size.width * 0.8,
        size.height * 0.55,
        size.width,
        size.height * 0.4,
      );

    final pPath = Path()
      ..moveTo(0, size.height * 0.45)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.55,
        size.width * 0.4,
        size.height * 0.35,
        size.width * 0.55,
        size.height * 0.5,
      )
      ..cubicTo(
        size.width * 0.7,
        size.height * 0.6,
        size.width * 0.85,
        size.height * 0.4,
        size.width,
        size.height * 0.48,
      );

    canvas.drawPath(mPath, moisture);
    canvas.drawPath(pPath, ph);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
