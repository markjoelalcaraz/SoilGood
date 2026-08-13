/// Active (or ended) planting row joined with its catalog crop.
///
/// Crops tab uses this to decide list vs plan. `planted_at` drives the local
/// phase timeline. Not a UI file.
library;

import 'crop_catalog.dart';

/// One farm planting of a catalog crop.
class Planting {
  const Planting({
    required this.id,
    required this.farmId,
    required this.cropId,
    required this.status,
    required this.crop,
    this.plantedAt,
    this.expectedHarvestAt,
  });

  final String id;
  final String farmId;
  final String cropId;
  final String status;
  final CropCatalogEntry crop;
  final DateTime? plantedAt;
  final DateTime? expectedHarvestAt;

  factory Planting.fromJson(Map<String, dynamic> json) {
    final cropRaw = json['crops'];
    if (cropRaw is! Map) {
      throw StateError('Planting row missing joined crops data.');
    }
    return Planting(
      id: json['id'] as String,
      farmId: json['farm_id'] as String,
      cropId: json['crop_id'] as String,
      status: json['status'] as String? ?? 'active',
      plantedAt: _dateOnly(json['planted_at']),
      expectedHarvestAt: _dateOnly(json['expected_harvest_at']),
      crop: CropCatalogEntry.fromJson(Map<String, dynamic>.from(cropRaw)),
    );
  }

  static DateTime? _dateOnly(Object? value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
