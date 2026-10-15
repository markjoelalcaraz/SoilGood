/// Compact week-strip + Today detail for the Crops irrigation plan.
///
/// Shown inside [CropPlanView] after cultivation phases. Seven equal-width
/// day cells (horizon, not seven waterings) and Mark watered on Today only.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../analytics/logic/manila_time.dart';
import '../data/irrigation_plan.dart';

/// Compact irrigation plan strip + today SoftCard.
class IrrigationWeekPlanCard extends StatelessWidget {
  const IrrigationWeekPlanCard({
    required this.plan,
    required this.onMarkWatered,
    this.marking = false,
    this.error,
    super.key,
  });

  final IrrigationPlan plan;
  final VoidCallback onMarkWatered;
  final bool marking;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final today = manilaCalendarDate(DateTime.now());
    final todaySlot = plan.slotFor(today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'This week’s water plan',
          icon: Icons.calendar_month,
        ),
        const SizedBox(height: 4),
        const Text(
          '7-day outlook · not daily watering · Mark watered today only',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final slot in plan.slots)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DayCell(
                    slot: slot,
                    isToday: sameManilaDay(slot.slotDate, today),
                  ),
                ),
              ),
          ],
        ),
        if (todaySlot != null) ...[
          const SizedBox(height: 10),
          SoftCard(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todaySlot.isLogged
                            ? 'Watered'
                            : todaySlot.guidance,
                        style: GoogleFonts.literata(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        todaySlot.reason,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (todaySlot.isLogged)
                  StatusChip(label: 'Done', tone: StatusChipTone.good)
                else if (todaySlot.action == IrrigationSlotAction.water)
                  FilledButton(
                    onPressed: marking ? null : onMarkWatered,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      marking ? '…' : 'Mark watered',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  StatusChip(
                    label: todaySlot.action == IrrigationSlotAction.noWater
                        ? 'No water'
                        : 'Check',
                    tone: StatusChipTone.neutral,
                  ),
              ],
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 8),
          SoftCard(
            color: AppColors.errorContainer,
            child: Text(
              '$error',
              style: const TextStyle(color: Color(0xFF690005), height: 1.45),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.slot, required this.isToday});

  final IrrigationPlanSlot slot;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final letter = _letter(slot.slotDate.weekday);
    final icon = slot.isLogged
        ? Icons.check
        : switch (slot.action) {
            IrrigationSlotAction.water => Icons.water_drop,
            IrrigationSlotAction.check => Icons.visibility_outlined,
            IrrigationSlotAction.noWater => Icons.water_drop_outlined,
          };

    final bg = slot.isLogged
        ? AppColors.primary.withValues(alpha: 0.08)
        : isToday
            ? AppColors.primarySoft.withValues(alpha: 0.45)
            : AppColors.surface;
    final border = isToday ? AppColors.primary : AppColors.outline.withValues(alpha: 0.4);

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: isToday ? 1.5 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            letter,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isToday || slot.isLogged
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
          Icon(
            icon,
            size: 18,
            color: isToday || slot.isLogged
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  static String _letter(int weekday) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return letters[weekday - 1];
  }
}
