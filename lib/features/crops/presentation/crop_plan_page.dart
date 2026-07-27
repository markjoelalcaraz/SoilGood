/// Crop Plan detail page pushed on top of the shell (slide from right), not a bottom-nav tab.
///
/// Shows a deeper plan for one selected crop. The shell may still exist underneath,
/// but this screen is a full-page route the farmer opens from the Crops tab.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ui_primitives.dart';

/// Crop cultivation plan detail — UI / navigation only.
class CropPlanPage extends StatelessWidget {
  const CropPlanPage({required this.cropName, super.key});

  final String cropName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        title: Text(
          'Crop Plan',
          style: GoogleFonts.literata(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
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
                  cropName,
                  style: GoogleFonts.literata(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Sample cultivation plan • Day 14 of 90',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Cultivation Phases'),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _PhaseCard(
                  title: 'Pre-planting',
                  body: 'Tilling & base nutrients',
                  done: true,
                ),
                _PhaseCard(
                  title: 'Planting',
                  body: 'Current phase — monitor germination',
                  current: true,
                ),
                _PhaseCard(
                  title: 'Growth',
                  body: 'Watch water stress & canopy',
                ),
                _PhaseCard(
                  title: 'Harvest',
                  body: 'Target window later in season',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Smart Tips', icon: Icons.psychology),
          const SizedBox(height: 12),
          SoftCard(
            child: _TipRow(
              icon: Icons.water_drop,
              title: 'Irrigation',
              value: 'Every 3 days',
              note: 'Next: Tomorrow 6:00 AM',
            ),
          ),
          const SizedBox(height: 10),
          SoftCard(
            child: _TipRow(
              icon: Icons.science,
              title: 'Fertilizer',
              value: 'Light nitrogen',
              note: 'After rain for better uptake',
            ),
          ),
          const SizedBox(height: 10),
          SoftCard(
            color: AppColors.secondaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Soil checklist',
                  style: GoogleFonts.literata(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 10),
                const _CheckItem(
                  label: 'Confirm moisture before irrigating',
                  done: true,
                ),
                const _CheckItem(
                  label: 'Watch nitrogen after next rain',
                  done: false,
                ),
                const _CheckItem(
                  label: 'Log fertilizer when applied',
                  done: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
            style: GoogleFonts.literata(
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
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

class _TipRow extends StatelessWidget {
  const _TipRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.note,
  });

  final IconData icon;
  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Row(
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                value,
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Text(
                note,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: done ? AppColors.primary : AppColors.outline,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
