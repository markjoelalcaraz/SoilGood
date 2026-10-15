/// Shared UI building blocks reused across shell tabs and feature pages.
///
/// SoftCard, section headers, phone breakpoints, and two-up layout live here
/// so Home, Analytics, Crops, and Profile stay consistent on small phones.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// True when two-up cards would squeeze on a small phone (~320–360px).
bool isNarrowPhone(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 360;

/// Lays out [first] and [second] side-by-side, or stacked on a narrow phone.
class ResponsiveTwoUp extends StatelessWidget {
  const ResponsiveTwoUp({
    required this.first,
    required this.second,
    this.gap = 10,
    super.key,
  });

  final Widget first;
  final Widget second;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (isNarrowPhone(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          SizedBox(height: gap),
          second,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: first),
        SizedBox(width: gap),
        Expanded(child: second),
      ],
    );
  }
}

/// Soft metric / insight card used across dashboard screens.
class SoftCard extends StatelessWidget {
  const SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surfaceLow,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.35)),
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}

/// Section title with optional leading icon.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.icon,
    this.trailing,
    super.key,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.literata(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Small status chip for metric cards.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    this.tone = StatusChipTone.neutral,
    super.key,
  });

  final String label;
  final StatusChipTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      StatusChipTone.good => (
        AppColors.primary.withValues(alpha: 0.12),
        AppColors.primary,
      ),
      StatusChipTone.warn => (AppColors.errorContainer, AppColors.error),
      StatusChipTone.neutral => (
        AppColors.surfaceHigh,
        AppColors.textSecondary,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.$2,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

enum StatusChipTone { good, warn, neutral }
