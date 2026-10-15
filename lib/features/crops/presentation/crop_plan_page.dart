/// Cultivation plan body: phases, water week, and care tips.
///
/// Shown under the focused crop on the Farm tab, and on the crop list only
/// when a planting is already active. Not a route by itself.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/ai/saved_assessment.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../home/logic/home_ai_story.dart';
import '../data/irrigation_plan.dart';
import '../data/planting.dart';
import '../logic/crop_timeline.dart';
import 'irrigation_week_plan_card.dart';

/// Cultivation plan + water plan + care tips for the selected crop.
class CropPlanView extends StatelessWidget {
  const CropPlanView({
    required this.planting,
    required this.timeline,
    required this.onChangeCrop,
    this.assessment,
    this.aiError,
    this.aiLoading = false,
    this.actionError,
    this.irrigationPlan,
    this.irrigationError,
    this.markingWater = false,
    this.onMarkWatered,
    super.key,
  });

  final Planting planting;
  final CropTimeline? timeline;
  final VoidCallback onChangeCrop;
  final SavedAssessment? assessment;
  final Object? aiError;
  final bool aiLoading;
  final Object? actionError;
  final IrrigationPlan? irrigationPlan;
  final Object? irrigationError;
  final bool markingWater;
  final VoidCallback? onMarkWatered;

  @override
  Widget build(BuildContext context) {
    final crop = planting.crop;
    final t = timeline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (actionError != null) ...[
          SoftCard(
            color: AppColors.errorContainer,
            child: Text(
              '$actionError',
              style: const TextStyle(color: Color(0xFF690005), height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SoftCard(
          color: AppColors.primary,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusChip(
                label: 'ACTIVE PLAN',
                tone: StatusChipTone.good,
              ),
              const SizedBox(height: 12),
              Text(
                crop.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.literata(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (crop.scientificName != null)
                Text(
                  crop.scientificName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                t == null
                    ? 'Catalog is missing days/phases. Run supabase_crops_home_ai.sql.'
                    : 'Day ${t.dayNumber} of ${t.totalDays} · '
                        '${t.daysLeft} day${t.daysLeft == 1 ? '' : 's'} to harvest · '
                        '${_md(t.harvestDate)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onChangeCrop,
            child: const Text('Change crop'),
          ),
        ),
        const SectionHeader(title: 'Cultivation Phases'),
        const SizedBox(height: 12),
        if (t == null)
          const SoftCard(
            child: Text(
              'Cannot show phases until the crop catalog has days_to_maturity and phases.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          )
        else
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: t.phases.length,
              itemBuilder: (context, i) {
                final phase = t.phases[i];
                return _PhaseCard(
                  title: phase.label,
                  body: '${phase.days} day${phase.days == 1 ? '' : 's'}',
                  done: i < t.currentIndex,
                  current: i == t.currentIndex,
                );
              },
            ),
          ),
        const SizedBox(height: 20),
        if (irrigationPlan != null && irrigationPlan!.slots.isNotEmpty) ...[
          IrrigationWeekPlanCard(
            plan: irrigationPlan!,
            onMarkWatered: onMarkWatered ?? () {},
            marking: markingWater,
            error: irrigationError,
          ),
          const SizedBox(height: 20),
        ] else if (irrigationError != null) ...[
          SoftCard(
            color: AppColors.errorContainer,
            child: Text(
              'Water plan unavailable:\n$irrigationError',
              style: const TextStyle(color: Color(0xFF690005), height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
        ],
        const SectionHeader(title: 'Care insights', icon: Icons.psychology),
        const SizedBox(height: 4),
        Text(
          'Same tips as Home for this farm’s ${crop.name}.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 12),
        if (aiError != null) ...[
          SoftCard(
            color: AppColors.errorContainer,
            child: Text(
              'Care insights unavailable:\n$aiError',
              style: const TextStyle(color: Color(0xFF690005), height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (aiLoading && assessment == null)
          const SoftCard(
            color: AppColors.surfaceMuted,
            child: SizedBox(height: 140),
          )
        else if (assessment != null) ...[
          if (displayHomeOverview(assessment!).isNotEmpty) ...[
            SoftCard(
              child: Text(
                displayHomeOverview(assessment!),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          _FarmTipCard(
            slotLabel: 'Condition',
            icon: Icons.grass,
            rec: _recOf(assessment!, 'soil_management'),
          ),
          const SizedBox(height: 10),
          _FarmTipCard(
            slotLabel: 'Water today',
            icon: Icons.water_drop,
            rec: _recOf(assessment!, 'irrigation'),
          ),
          const SizedBox(height: 10),
          _FarmTipCard(
            slotLabel: 'Nutrients',
            icon: Icons.science,
            rec: _recOf(assessment!, 'nutrient'),
          ),
          const SizedBox(height: 10),
          _FarmTipCard(
            slotLabel: 'Crop care',
            icon: Icons.eco_outlined,
            rec: _recOf(assessment!, 'crop_care'),
          ),
        ],
      ],
    );
  }

  /// Prefer the Home slot type on this farm's saved tips.
  static AiRecommendation? _recOf(SavedAssessment a, String type) {
    for (final r in a.recommendations) {
      if (r.type == type) return r;
    }
    if (type == 'irrigation' && a.recommendations.length == 1) {
      return a.recommendations.first;
    }
    return null;
  }

  static String _md(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.title,
    required this.body,
    this.done = false,
    this.current = false,
  });

  final String title;
  final String body;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: current
            ? AppColors.primarySoft.withValues(alpha: 0.45)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: current
              ? AppColors.primary
              : AppColors.outline.withValues(alpha: 0.4),
          width: current ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.circle_outlined,
                color: done || current
                    ? AppColors.primary
                    : AppColors.textSecondary,
                size: 18,
              ),
              const Spacer(),
              if (current)
                const StatusChip(label: 'NOW', tone: StatusChipTone.good),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.literata(
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// One Home tip with the action, title, and the longer note Home hides.
class _FarmTipCard extends StatelessWidget {
  const _FarmTipCard({
    required this.slotLabel,
    required this.icon,
    required this.rec,
  });

  final String slotLabel;
  final IconData icon;
  final AiRecommendation? rec;

  @override
  Widget build(BuildContext context) {
    final action = rec?.recommendedAction.trim() ?? '';
    final title = (rec == null || rec!.title.trim().isEmpty)
        ? 'No tip saved yet'
        : rec!.title;
    final detail = rec?.description.trim() ?? '';

    return SoftCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slotLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (action.isNotEmpty)
                  Text(
                    action,
                    style: GoogleFonts.literata(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      height: 1.3,
                    ),
                  ),
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
