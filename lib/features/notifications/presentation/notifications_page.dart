/// Pushed inbox page (outside the shell) listing saved farm alerts.
///
/// Opened from the top-bar bell with slide-from-right. Bottom nav is not
/// visible. Farmers scan unread soil/weather alerts, pull to refetch, and tap
/// a card to mark it read. Not a fifth shell tab.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/data/refresh_timeout.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../analytics/logic/manila_time.dart';
import '../data/farm_notification.dart';
import '../data/notifications_repository.dart';

/// Farmer-facing list of `farm_notifications` for the signed-in farm.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _repo = NotificationsRepository();
  StreamSubscription<List<FarmNotification>>? _sub;
  List<FarmNotification> _cached = [];
  final _optimisticReadIds = <String>{};
  Object? _loadError;
  Object? _actionError;
  bool _fetchDone = false;

  @override
  void initState() {
    super.initState();
    _sub = _repo.watchRecent().listen(
      (rows) {
        if (!mounted) return;
        // Empty stream tick must not wipe a successful fetch.
        if (rows.isEmpty && _cached.isNotEmpty) return;
        setState(() {
          _cached = rows;
          _loadError = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _loadError = e);
      },
    );
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Last-known rows with optimistic reads so a tap does not flash back.
  List<FarmNotification> get _visible {
    if (_optimisticReadIds.isEmpty) return _cached;
    return [
      for (final n in _cached)
        if (_optimisticReadIds.contains(n.id) && n.isUnread)
          n.copyWith(readAt: DateTime.now().toUtc())
        else
          n,
    ];
  }

  /// First paint and pull-to-refresh. Keeps last-known rows on pull.
  Future<void> _load() async {
    try {
      final rows = await withRefreshTimeout(_repo.fetchRecent());
      if (!mounted) return;
      setState(() {
        _cached = rows;
        _loadError = null;
        _fetchDone = true;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _fetchDone = true;
      });
    }
  }

  /// Marks one unread alert read immediately; rolls back on failure.
  Future<void> _markRead(FarmNotification item) async {
    if (!item.isUnread) return;
    _optimisticReadIds.add(item.id);
    setState(() => _actionError = null);
    try {
      await _repo.markRead(item.id);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _optimisticReadIds.remove(item.id);
        _actionError = e;
      });
    }
  }

  /// Marks every unread row read; rolls the whole list back on failure.
  Future<void> _markAllRead(List<FarmNotification> unread) async {
    if (unread.isEmpty) return;
    final ids = unread.map((n) => n.id).toList();
    _optimisticReadIds.addAll(ids);
    setState(() => _actionError = null);
    try {
      await _repo.markAllRead(ids);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _optimisticReadIds.removeAll(ids);
        _actionError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        title: Text(
          'Notifications',
          style: GoogleFonts.literata(fontWeight: FontWeight.w700),
        ),
      ),
      body: Builder(
        builder: (context) {
          final rows = _visible;
          final waitingFirst =
              !_fetchDone && rows.isEmpty && _loadError == null;
          final unread = rows.where((n) => n.isUnread).toList();
          final read = rows.where((n) => !n.isUnread).toList();

          return AppRefreshScroll(
            onRefresh: _load,
            children: [
              const Text(
                'Alerts for your field — dry soil, nutrients, sensor, weather. '
                'Tap a card to mark it read.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              if (unread.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _markAllRead(unread),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('Mark all read'),
                  ),
                ),
              ] else
                const SizedBox(height: 16),
              if (_actionError != null) ...[
                SoftCard(
                  color: AppColors.errorContainer,
                  child: Text(
                    'Could not update that alert:\n$_actionError',
                    style: const TextStyle(
                      color: Color(0xFF690005),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_loadError != null) ...[
                SoftCard(
                  color: AppColors.errorContainer,
                  child: Text(
                    'Could not load notifications:\n$_loadError',
                    style: const TextStyle(
                      color: Color(0xFF690005),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (waitingFirst) ...[
                const SoftCard(
                  color: AppColors.surfaceMuted,
                  child: SizedBox(height: 88),
                ),
                const SizedBox(height: 10),
                const SoftCard(
                  color: AppColors.surfaceMuted,
                  child: SizedBox(height: 88),
                ),
                const SizedBox(height: 10),
                const SoftCard(
                  color: AppColors.surfaceMuted,
                  child: SizedBox(height: 88),
                ),
              ] else if (rows.isEmpty)
                const SoftCard(
                  child: Text(
                    'No alerts yet. When soil is dry, nutrients are low, '
                    'or the sensor stops reporting, it will show here.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                )
              else ...[
                if (unread.isNotEmpty) ...[
                  const SectionHeader(title: 'Needs attention'),
                  const SizedBox(height: 10),
                  ...unread.map(
                    (n) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AlertCard(
                        notification: n,
                        onTap: () => _markRead(n),
                      ),
                    ),
                  ),
                ],
                if (read.isNotEmpty) ...[
                  if (unread.isNotEmpty) const SizedBox(height: 8),
                  const SectionHeader(title: 'Earlier'),
                  const SizedBox(height: 10),
                  ...read.map(
                    (n) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AlertCard(notification: n),
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.notification, this.onTap});

  final FarmNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final unread = n.isUnread;
    final tone = switch (n.severity) {
      FarmNotificationSeverity.urgent => StatusChipTone.warn,
      FarmNotificationSeverity.warning => StatusChipTone.warn,
      FarmNotificationSeverity.info => StatusChipTone.neutral,
    };

    return SoftCard(
      onTap: onTap,
      color: unread ? AppColors.surface : AppColors.surfaceLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _iconFor(n.type),
            color: unread ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.literata(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: unread ? 'New' : n.type.farmerLabel,
                      tone: unread ? tone : StatusChipTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  n.body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _when(n.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(FarmNotificationType type) {
    return switch (type) {
      FarmNotificationType.irrigation => Icons.water_drop_outlined,
      FarmNotificationType.nutrientLow => Icons.grass_outlined,
      FarmNotificationType.soilAlert => Icons.science_outlined,
      FarmNotificationType.sensorError => Icons.sensors_off_outlined,
      FarmNotificationType.deviceOffline => Icons.wifi_off,
      FarmNotificationType.phaseChange => Icons.spa_outlined,
    };
  }

  String _when(DateTime createdAt) {
    final manila = createdAt.toUtc().add(kManilaOffset);
    final now = manilaNow();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(manila.year, manila.month, manila.day);
    final hm =
        '${manila.hour.toString().padLeft(2, '0')}:'
        '${manila.minute.toString().padLeft(2, '0')}';
    if (day == today) return 'Today $hm';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday $hm';
    }
    final y = manila.year.toString().padLeft(4, '0');
    final m = manila.month.toString().padLeft(2, '0');
    final d = manila.day.toString().padLeft(2, '0');
    return '$y-$m-$d $hm';
  }
}
