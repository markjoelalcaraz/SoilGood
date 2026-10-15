/// Supabase RPCs for Lab Flasher: provision kit + mark flashed.
///
/// Admin-only security-definer functions. Same anon client as SoilGood —
/// never service_role. UI calls this after a COM port is resolved.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Provisioned kit secrets ready for SGCFG inject + sticker.
class ProvisionedKit {
  const ProvisionedKit({
    required this.id,
    required this.deviceUid,
    required this.ingestToken,
    required this.claimCode,
    required this.name,
  });

  final String id;
  final String deviceUid;
  final String ingestToken;
  final String claimCode;
  final String name;

  factory ProvisionedKit.fromJson(Map<String, dynamic> json) {
    final code = (json['claim_code'] as String?)?.trim() ?? '';
    if (code.isEmpty) {
      throw StateError('Provision returned empty claim_code.');
    }
    final token = (json['ingest_token'] as String?)?.trim() ?? '';
    if (token.length < 8) {
      throw StateError('Provision returned invalid ingest_token.');
    }
    return ProvisionedKit(
      id: json['id'] as String,
      deviceUid: (json['device_uid'] as String?)?.trim() ?? '',
      ingestToken: token,
      claimCode: code,
      name: (json['name'] as String?)?.trim() ?? 'SoilGood Sensor',
    );
  }
}

/// Calls admin_provision_device / admin_mark_device_flashed.
class FlashRepository {
  FlashRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Creates an unclaimed device row; returns flash secrets.
  Future<ProvisionedKit> provision({String? name}) async {
    final trimmed = name?.trim();
    final label =
        (trimmed == null || trimmed.isEmpty) ? 'SoilGood Sensor' : trimmed;
    final raw = await _client.rpc(
      'admin_provision_device',
      params: {'p_name': label},
    );
    final rows = (raw as List).cast<dynamic>();
    if (rows.isEmpty) {
      throw StateError('Provision returned no device.');
    }
    return ProvisionedKit.fromJson(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  /// Marks kit as successfully flashed after SGCFG_OK.
  Future<void> markFlashed(String deviceId) async {
    final raw = await _client.rpc(
      'admin_mark_device_flashed',
      params: {'p_id': deviceId},
    );
    final rows = (raw as List).cast<dynamic>();
    if (rows.isEmpty) {
      throw StateError('Mark flashed returned no row.');
    }
  }

  /// True when profiles.role is admin for the signed-in user.
  Future<bool> isAdmin() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await _client
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    final role = (row?['role'] as String?)?.trim().toLowerCase() ?? '';
    return role == 'admin';
  }
}
