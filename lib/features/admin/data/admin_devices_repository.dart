/// Data layer for the admin web console: list/provision/get devices via RPCs.
///
/// Calls security-definer admin_* functions (is_admin checked in Postgres).
/// No service_role in the client. UI lives under features/admin/presentation.
library;

import '../../../core/supabase/supabase_bootstrap.dart';
import 'admin_device.dart';

/// Admin device inventory + provision against Supabase RPCs.
class AdminDevicesRepository {
  /// All kits (newest first).
  Future<List<AdminDeviceSummary>> listDevices() async {
    final raw = await supabase.rpc('admin_list_devices');
    final rows = (raw as List).cast<dynamic>();
    return rows
        .map((e) => AdminDeviceSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Creates an unclaimed kit; returns secrets for flashing.
  Future<AdminDeviceDetail> provisionDevice({String? name}) async {
    final trimmed = name?.trim();
    final label =
        (trimmed == null || trimmed.isEmpty) ? 'SoilGood Sensor' : trimmed;
    final raw = await supabase.rpc(
      'admin_provision_device',
      params: {'p_name': label},
    );
    final rows = (raw as List).cast<dynamic>();
    if (rows.isEmpty) {
      throw StateError('Provision returned no device.');
    }
    return AdminDeviceDetail.fromJson(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  /// Detail including ingest_token for flash / secrets.h fallback.
  Future<AdminDeviceDetail> getDevice(String id) async {
    final raw = await supabase.rpc('admin_get_device', params: {'p_id': id});
    final rows = (raw as List).cast<dynamic>();
    if (rows.isEmpty) {
      throw StateError('Device not found.');
    }
    return AdminDeviceDetail.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  /// Marks kit flashed after successful SGCFG (Admin Web or Lab Flasher).
  Future<void> markFlashed(String deviceId) async {
    final raw = await supabase.rpc(
      'admin_mark_device_flashed',
      params: {'p_id': deviceId},
    );
    final rows = (raw as List).cast<dynamic>();
    if (rows.isEmpty) {
      throw StateError('Mark flashed returned no row.');
    }
  }
}
