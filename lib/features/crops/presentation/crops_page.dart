/// Crops feature page shown inside the app shell content area (third bottom-nav tab).
///
/// Lists crop suitability / match cards for the farmer. Tapping a crop opens the
/// Crop Plan page as a pushed route outside this tab content.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/navigation/app_page_routes.dart';
import '../../shell/app_shell.dart';
import 'crop_plan_page.dart';

/// Crops suitability UI — mock matches only; navigation to plan detail.
class CropsPage extends StatelessWidget {
  const CropsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SoilGoodTopBar(title: 'Crops', leadingIcon: Icons.eco),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Crop Matches',
            style: GoogleFonts.literata(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Based on your latest soil snapshot (sample data for UI).',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          SoftCard(
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current soil snapshot',
                  style: GoogleFonts.literata(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(
                      label: 'Moisture 68%',
                      tone: StatusChipTone.good,
                    ),
                    StatusChip(label: 'pH 6.4'),
                    StatusChip(label: 'N low', tone: StatusChipTone.warn),
                    StatusChip(label: 'EC 1.2'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'AI Smart Matches'),
          const SizedBox(height: 12),
          _CropMatchCard(
            name: 'Sweet Corn',
            scientific: 'Zea mays',
            matchPercent: 98,
            reason:
                'pH near 6.4 and steady moisture fit corn well for the next cycle.',
            onViewPlan: () => _openPlan(context, 'Sweet Corn'),
          ),
          const SizedBox(height: 14),
          _CropMatchCard(
            name: 'Soybeans',
            scientific: 'Glycine max',
            matchPercent: 92,
            reason:
                'Good rotation choice when nitrogen is low — soybeans help rebuild soil N.',
            accent: AppColors.tertiary,
            onViewPlan: () => _openPlan(context, 'Soybeans'),
          ),
        ],
      ),
    );
  }

  void _openPlan(BuildContext context, String cropName) {
    Navigator.of(
      context,
    ).push(AppPageRoutes.slideFromRight(CropPlanPage(cropName: cropName)));
  }
}

class _CropMatchCard extends StatelessWidget {
  const _CropMatchCard({
    required this.name,
    required this.scientific,
    required this.matchPercent,
    required this.reason,
    required this.onViewPlan,
    this.accent = AppColors.primary,
  });

  final String name;
  final String scientific;
  final int matchPercent;
  final String reason;
  final VoidCallback onViewPlan;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.surface,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.85),
                  AppColors.primary.withValues(alpha: 0.65),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Icon(
                    Icons.eco,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$matchPercent% Match',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.literata(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        scientific,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SoftCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, color: accent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: onViewPlan,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View Plan',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
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
