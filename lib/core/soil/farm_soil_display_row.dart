/// Full-width display-only row for the farm’s texture / series on Crops list mode.
///
/// Not a SoftCard essay and not editable — Profile / onboarding own edits.
/// Shown above the 8-in-1 chips when a label can be built.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'farm_soil_label.dart';
import 'soil_series.dart';
import 'soil_texture.dart';

/// Stretched farm-soil line: icon + `Loam · Bantog` (or texture-only).
class FarmSoilDisplayRow extends StatelessWidget {
  const FarmSoilDisplayRow({
    super.key,
    this.texture,
    this.series,
  });

  final SoilTexture? texture;
  final SoilSeries? series;

  @override
  Widget build(BuildContext context) {
    final label = farmSoilDisplayLabel(texture: texture, series: series);
    if (label == null) return const SizedBox.shrink();

    return Semantics(
      label: 'Farm soil $label',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.landscape, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
