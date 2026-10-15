/// Admin device row models returned by admin_* RPCs (ops console only).
///
/// Used by the Flutter web AdminShell. Farmers never see ingest_token;
/// admin list omits the token until detail/provision.
library;

/// Summary row from `admin_list_devices` (no ingest_token).
class AdminDeviceSummary {
  const AdminDeviceSummary({
    required this.id,
    required this.deviceUid,
    required this.name,
    required this.status,
    this.claimCode,
    this.farmId,
    this.farmName,
    this.ownerEmail,
    this.lastSeenAt,
    this.claimedAt,
    this.createdAt,
    this.flashedAt,
    this.flashStatus,
  });

  final String id;
  final String deviceUid;
  final String? claimCode;
  final String name;
  final String status;
  final String? farmId;
  final String? farmName;
  final String? ownerEmail;
  final DateTime? lastSeenAt;
  final DateTime? claimedAt;
  final DateTime? createdAt;
  final DateTime? flashedAt;
  final String? flashStatus;

  /// True when Lab Flasher (or mark RPC) recorded a successful burn.
  bool get isFlashed => flashedAt != null || flashStatus == 'flashed';

  factory AdminDeviceSummary.fromJson(Map<String, dynamic> json) {
    return AdminDeviceSummary(
      id: json['id'] as String,
      deviceUid: json['device_uid'] as String? ?? '',
      claimCode: json['claim_code'] as String?,
      name: json['name'] as String? ?? 'SoilGood Sensor',
      status: json['status'] as String? ?? 'unclaimed',
      farmId: json['farm_id'] as String?,
      farmName: json['farm_name'] as String?,
      ownerEmail: json['owner_email'] as String?,
      lastSeenAt: _parseDt(json['last_seen_at']),
      claimedAt: _parseDt(json['claimed_at']),
      createdAt: _parseDt(json['created_at']),
      flashedAt: _parseDt(json['flashed_at']),
      flashStatus: json['flash_status'] as String?,
    );
  }
}

/// Full device from provision / `admin_get_device` (includes ingest_token).
class AdminDeviceDetail extends AdminDeviceSummary {
  const AdminDeviceDetail({
    required super.id,
    required super.deviceUid,
    required super.name,
    required super.status,
    required this.ingestToken,
    super.claimCode,
    super.farmId,
    super.farmName,
    super.ownerEmail,
    super.lastSeenAt,
    super.claimedAt,
    super.createdAt,
    super.flashedAt,
    super.flashStatus,
  });

  final String ingestToken;

  factory AdminDeviceDetail.fromJson(Map<String, dynamic> json) {
    return AdminDeviceDetail(
      id: json['id'] as String,
      deviceUid: json['device_uid'] as String? ?? '',
      ingestToken: json['ingest_token'] as String? ?? '',
      claimCode: json['claim_code'] as String?,
      name: json['name'] as String? ?? 'SoilGood Sensor',
      status: json['status'] as String? ?? 'unclaimed',
      farmId: json['farm_id'] as String?,
      farmName: json['farm_name'] as String?,
      ownerEmail: json['owner_email'] as String?,
      lastSeenAt: _parseDt(json['last_seen_at']),
      claimedAt: _parseDt(json['claimed_at']),
      createdAt: _parseDt(json['created_at']),
      flashedAt: _parseDt(json['flashed_at']),
      flashStatus: json['flash_status'] as String?,
    );
  }

  /// Block ready to paste into firmware secrets.h (WiFi still manual / Lab Flasher).
  String secretsHSnippet() {
    return 'const char* DEVICE_UID = "$deviceUid";\n'
        'const char* INGEST_TOKEN = "$ingestToken";';
  }
}

DateTime? _parseDt(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
