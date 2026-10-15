/// Derives ops summary metrics from admin device inventory (client-side).
///
/// No soil readings — kit pipeline counts only. Used by Admin Analytics page.
library;

import '../data/admin_device.dart';

/// Snapshot of kit pipeline health for the Admin Analytics tab.
class AdminOpsSummary {
  const AdminOpsSummary({
    required this.total,
    required this.unclaimed,
    required this.active,
    required this.offline,
    required this.error,
    required this.flashed,
    required this.notFlashed,
    required this.recentClaims,
    required this.attention,
  });

  final int total;
  final int unclaimed;
  final int active;
  final int offline;
  final int error;
  final int flashed;
  final int notFlashed;
  final List<AdminDeviceSummary> recentClaims;
  final List<AdminAttentionItem> attention;

  /// Builds summary from `admin_list_devices` rows.
  factory AdminOpsSummary.fromDevices(List<AdminDeviceSummary> devices) {
    var unclaimed = 0;
    var active = 0;
    var offline = 0;
    var error = 0;
    var flashed = 0;
    for (final d in devices) {
      switch (d.status) {
        case 'unclaimed':
          unclaimed++;
        case 'active':
          active++;
        case 'offline':
          offline++;
        case 'error':
          error++;
      }
      if (d.isFlashed) flashed++;
    }

    final claimed = devices.where((d) => d.claimedAt != null).toList()
      ..sort((a, b) => b.claimedAt!.compareTo(a.claimedAt!));

    final attention = <AdminAttentionItem>[];
    for (final d in devices) {
      if (!d.isFlashed) {
        attention.add(
          AdminAttentionItem(
            device: d,
            reason: 'Not flashed',
          ),
        );
      } else if (d.status == 'offline') {
        attention.add(
          AdminAttentionItem(
            device: d,
            reason: 'Offline',
          ),
        );
      } else if (d.status == 'unclaimed' && d.isFlashed) {
        attention.add(
          AdminAttentionItem(
            device: d,
            reason: 'Flashed, waiting farmer claim',
          ),
        );
      } else if (d.status == 'active' && d.lastSeenAt == null) {
        attention.add(
          AdminAttentionItem(
            device: d,
            reason: 'Active but never seen',
          ),
        );
      }
    }

    return AdminOpsSummary(
      total: devices.length,
      unclaimed: unclaimed,
      active: active,
      offline: offline,
      error: error,
      flashed: flashed,
      notFlashed: devices.length - flashed,
      recentClaims: claimed.take(8).toList(),
      attention: attention.take(12).toList(),
    );
  }
}

/// One row in the Analytics “attention” list.
class AdminAttentionItem {
  const AdminAttentionItem({
    required this.device,
    required this.reason,
  });

  final AdminDeviceSummary device;
  final String reason;
}
