/// Loads claimed sensors and places a kit on the farm's current crop.
///
/// Profile and the Farm tab call this. Claim still goes through
/// [OnboardingRepository.claimDevice]; this file only lists kits and calls
/// `place_sensor_on_plot`. Not a widget.
library;

import '../../../core/soil/device_texture_resolver.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../home/data/soil_reading.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/logic/device_claim_rules.dart';
import 'farm_sensor.dart';

/// Supabase access for sensors on the signed-in farmer's farm.
class PlotSensorsRepository {
  PlotSensorsRepository({OnboardingRepository? onboarding})
    : _onboarding = onboarding ?? OnboardingRepository();

  final OnboardingRepository _onboarding;

  /// Turns probe moisture into wetness for each kit's plot / farm texture.
  final _textures = DeviceTextureResolver();

  /// Every claimed kit on [farmId], oldest claim first, with its latest reading.
  Future<List<FarmSensor>> listForFarm(String farmId) async {
    final rows = await supabase
        .from('devices')
        .select(
          'id, claim_code, planting_id, claimed_at, plantings(status, crops(name))',
        )
        .eq('farm_id', farmId)
        .order('claimed_at', ascending: true);

    final sensors = <FarmSensor>[];
    for (final raw in rows as List) {
      final json = Map<String, dynamic>.from(raw as Map);
      final code = (json['claim_code'] as String?)?.trim();
      if (code == null || code.isEmpty) continue;
      final plot = json['plantings'];
      String? cropName;
      String? plantingStatus;
      if (plot is Map) {
        plantingStatus = plot['status'] as String?;
        final crops = plot['crops'];
        if (crops is Map) cropName = crops['name'] as String?;
      }
      sensors.add(
        FarmSensor(
          id: json['id'] as String,
          claimCode: code,
          plantingId: json['planting_id'] as String?,
          cropName: cropName,
          plantingStatus: plantingStatus,
        ),
      );
    }

    if (sensors.isEmpty) return sensors;
    final latest = await _latestByDevice(sensors.map((s) => s.id).toList());
    return [
      for (final sensor in sensors)
        FarmSensor(
          id: sensor.id,
          claimCode: sensor.claimCode,
          plantingId: sensor.plantingId,
          cropName: sensor.cropName,
          plantingStatus: sensor.plantingStatus,
          latest: latest[sensor.id],
        ),
    ];
  }

  /// Sticker code and crop name for one device, used when an alert is written.
  Future<({String code, String? cropName})?> identityForDevice(
    String deviceId,
  ) async {
    final row = await supabase
        .from('devices')
        .select('claim_code, plantings(crops(name))')
        .eq('id', deviceId)
        .maybeSingle();
    if (row == null) return null;
    final code = (row['claim_code'] as String?)?.trim();
    if (code == null || code.isEmpty) return null;
    final plot = row['plantings'];
    String? cropName;
    if (plot is Map) {
      final crops = plot['crops'];
      if (crops is Map) cropName = crops['name'] as String?;
    }
    return (code: code, cropName: cropName);
  }

  /// Claims a new kit onto the farm, then places it on [plantingId].
  Future<void> claimOnPlot({
    required String claimCode,
    required String plantingId,
  }) async {
    final id = await claimToFarm(claimCode);
    await placeOnPlot(deviceId: id, plantingId: plantingId);
  }

  /// Claims a new kit onto the farm without a plot yet. Returns the device id.
  ///
  /// Add a crop uses this so the kit can start reporting before a crop is chosen.
  Future<String> claimToFarm(String claimCode) async {
    final code = normalizeClaimCode(claimCode);
    if (code == null) {
      throw StateError(kEmptyClaimCodeMessage);
    }
    try {
      await _onboarding.claimDevice(claimCode: code);
    } on Object catch (e) {
      throw StateError(friendlyClaimError(e));
    }
    final row = await supabase
        .from('devices')
        .select('id')
        .eq('claim_code', code)
        .maybeSingle();
    final id = row?['id'] as String?;
    if (id == null) {
      throw StateError('Claim code not found. Check the code on your box');
    }
    return id;
  }

  /// Newest reading from [deviceId] at or after [since], or null.
  Future<SoilReading?> fetchReadingSince({
    required String deviceId,
    required DateTime since,
  }) async {
    final row = await supabase
        .from('soil_readings')
        .select()
        .eq('device_id', deviceId)
        .gte('recorded_at', since.toUtc().toIso8601String())
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return _textures.normalize(
      SoilReading.fromJson(Map<String, dynamic>.from(row)),
    );
  }

  /// Live: emits the newest reading from [deviceId] once it is at/after [since].
  Stream<SoilReading?> watchReadingSince({
    required String deviceId,
    required DateTime since,
  }) {
    return supabase
        .from('soil_readings')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .asyncMap((rows) async {
          if (rows.isEmpty) return null;
          final reading = SoilReading.fromJson(
            Map<String, dynamic>.from(rows.first),
          );
          if (reading.recordedAt.isBefore(since)) return null;
          return _textures.normalize(reading);
        });
  }

  /// Moves an already-claimed kit onto the current crop.
  Future<void> placeOnPlot({
    required String deviceId,
    required String plantingId,
  }) async {
    try {
      await supabase.rpc(
        'place_sensor_on_plot',
        params: {'p_device_id': deviceId, 'p_planting_id': plantingId},
      );
    } on Object catch (e) {
      throw StateError(friendlyClaimError(e));
    }
  }

  /// Newest reading per device. Later rows in the descending list are ignored.
  Future<Map<String, SoilReading>> _latestByDevice(List<String> deviceIds) async {
    final rows = await supabase
        .from('soil_readings')
        .select()
        .inFilter('device_id', deviceIds)
        .order('recorded_at', ascending: false)
        .limit(200);

    final byDevice = <String, SoilReading>{};
    for (final raw in rows as List) {
      final json = Map<String, dynamic>.from(raw as Map);
      final deviceId = json['device_id'] as String?;
      if (deviceId == null || byDevice.containsKey(deviceId)) continue;
      byDevice[deviceId] = SoilReading.fromJson(json);
    }
    // Sensor list is reloaded after placements, so plot textures must be fresh.
    _textures.invalidate();
    final normalized = await _textures.normalizeAll(byDevice.values.toList());
    return {for (final r in normalized) r.deviceId!: r};
  }
}
