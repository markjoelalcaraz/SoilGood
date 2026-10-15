/// Admin Analytics — ops kit pipeline summary (not farmer soil charts).
///
/// First AdminShell tab. Counts + recent claims + attention list from
/// `admin_list_devices`. No soil readings across farms (privacy).
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/navigation/app_page_routes.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/presentation/widgets/auth_error_banner.dart';
import '../data/admin_device.dart';
import '../data/admin_devices_repository.dart';
import '../logic/admin_datetime.dart';
import '../logic/admin_ops_summary.dart';
import 'admin_device_detail_page.dart';

/// Ops overview content inside AdminShell.
class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  final _repo = AdminDevicesRepository();
  List<AdminDeviceSummary>? _devices;
  String? _error;
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// Refetches inventory; keeps last-known on failure.
  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      final list =
          await _repo.listDevices().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _devices = list;
        _firstLoad = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _firstLoad = false;
      });
    }
  }

  Future<void> _openDevice(AdminDeviceSummary d) async {
    await Navigator.of(context).push(
      AppPageRoutes.slideFromRight(
        AdminDeviceDetailPage(deviceId: d.id),
      ),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_firstLoad && _devices == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final summary = AdminOpsSummary.fromDevices(
      _devices ?? const <AdminDeviceSummary>[],
    );

    return AppRefreshScroll(
      onRefresh: _reload,
      maxWidth: kAdminContentMaxWidth,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'Ops overview',
          style: GoogleFonts.literata(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Kit pipeline health — provision → flash → claim → online. '
          'Not farmer soil charts.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        AuthErrorBanner(message: _error),
        if (_error != null) const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 520;
            final cols = wide ? 3 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: wide ? 1.55 : 1.45,
              children: [
                _StatTile(label: 'Total kits', value: summary.total),
                _StatTile(label: 'Unclaimed', value: summary.unclaimed),
                _StatTile(label: 'Active', value: summary.active),
                _StatTile(
                  label: 'Offline',
                  value: summary.offline,
                  muted: true,
                ),
                _StatTile(label: 'Flashed', value: summary.flashed),
                _StatTile(
                  label: 'Not flashed',
                  value: summary.notFlashed,
                  warn: true,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        SoftCard(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Recent claims',
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (summary.recentClaims.isEmpty)
                const Text(
                  'No claims yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                ...summary.recentClaims.map(
                  (d) => InkWell(
                    onTap: () => _openDevice(d),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.claimCode ?? '—',
                                  style: GoogleFonts.literata(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (d.farmName != null) d.farmName!,
                                    if (d.ownerEmail != null) d.ownerEmail!,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatAdminDateTime(d.claimedAt),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SoftCard(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Never seen / attention',
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (summary.attention.isEmpty)
                const Text(
                  'No kits need attention.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                ...summary.attention.map(
                  (item) => InkWell(
                    onTap: () => _openDevice(item.device),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.device.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  item.device.claimCode ?? '—',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Text(
                              item.reason,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: item.reason.contains('Offline')
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Pull to refresh reloads kit inventory only — no soil tables.',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.warn = false,
    this.muted = false,
  });

  final String label;
  final int value;
  final bool warn;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final bg = warn
        ? AppColors.tertiarySoft
        : muted
            ? AppColors.surfaceMuted
            : AppColors.primarySoft.withValues(alpha: 0.55);
    final valueColor = warn
        ? AppColors.tertiary
        : muted
            ? AppColors.textPrimary
            : AppColors.primary;

    return SoftCard(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: GoogleFonts.literata(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
