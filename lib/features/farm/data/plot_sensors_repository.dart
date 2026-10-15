/// Loads claimed sensors and places a kit on the farm's current crop.
///
/// Profile and the Farm tab call this. Claim still goes through
/// [OnboardingRepository.claimDevice]; this file only lists kits and calls
/// `place_sensor_on_plot`. Not a widget.
library;

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
    await _onboarding.claimDevice(claimCode: claimCode);
    final code = normalizeClaimCode(claimCode);
    if (code == null) {
      throw StateError(kEmptyClaimCodeMessage);
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
    await placeOnPlot(deviceId: id, plantingId: plantingId);
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
    return byDevice;
  }
}
