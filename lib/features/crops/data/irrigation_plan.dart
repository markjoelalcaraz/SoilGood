/// Models for the Crops rolling irrigation plan (7-day horizon, not 7 waterings).
///
/// Data layer only. Persisted in `irrigation_plans` / `irrigation_plan_slots`.
/// UI lives on the Crops crop-plan body.
library;

/// What the plan suggests for one Manila calendar day.
enum IrrigationSlotAction {
  water,
  check,
  noWater;

  static IrrigationSlotAction parse(String raw) {
    switch (raw) {
      case 'water':
        return IrrigationSlotAction.water;
      case 'check':
        return IrrigationSlotAction.check;
      case 'no_water':
        return IrrigationSlotAction.noWater;
      default:
        return IrrigationSlotAction.check;
    }
  }

  String get dbValue => switch (this) {
        IrrigationSlotAction.water => 'water',
        IrrigationSlotAction.check => 'check',
        IrrigationSlotAction.noWater => 'no_water',
      };
}

/// One day in an [IrrigationPlan].
class IrrigationPlanSlot {
  const IrrigationPlanSlot({
    required this.id,
    required this.planId,
    required this.slotDate,
    required this.action,
    required this.confidence,
    required this.guidance,
    required this.reason,
    this.completedActionId,
  });

  final String id;
  final String planId;
  /// Manila calendar date (date-only).
  final DateTime slotDate;
  final IrrigationSlotAction action;
  final String confidence;
  final String guidance;
  final String reason;
  final String? completedActionId;

  bool get isLogged => completedActionId != null;

  factory IrrigationPlanSlot.fromJson(Map<String, dynamic> json) {
    final dateRaw = json['slot_date'] as String;
    final parts = dateRaw.split('-');
    return IrrigationPlanSlot(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      slotDate: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      action: IrrigationSlotAction.parse(json['action'] as String? ?? 'check'),
      confidence: json['confidence'] as String? ?? 'high',
      guidance: json['guidance'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      completedActionId: json['completed_action_id'] as String?,
    );
  }
}

/// Saved week plan for one planting.
class IrrigationPlan {
  const IrrigationPlan({
    required this.id,
    required this.farmId,
    required this.plantingId,
    required this.horizonStart,
    required this.horizonDays,
    required this.storyFingerprint,
    required this.generatedAt,
    this.overview = '',
    this.modelName,
    this.promptVersion,
    this.validUntil,
    this.slots = const [],
  });

  final String id;
  final String farmId;
  final String plantingId;
  final DateTime horizonStart;
  final int horizonDays;
  final String storyFingerprint;
  final DateTime generatedAt;
  final String overview;
  final String? modelName;
  final String? promptVersion;
  final DateTime? validUntil;
  final List<IrrigationPlanSlot> slots;

  IrrigationPlanSlot? slotFor(DateTime manilaDay) {
    for (final s in slots) {
      if (s.slotDate.year == manilaDay.year &&
          s.slotDate.month == manilaDay.month &&
          s.slotDate.day == manilaDay.day) {
        return s;
      }
    }
    return null;
  }

  factory IrrigationPlan.fromJson(
    Map<String, dynamic> json, {
    List<IrrigationPlanSlot> slots = const [],
  }) {
    final startRaw = json['horizon_start'] as String;
    final parts = startRaw.split('-');
    return IrrigationPlan(
      id: json['id'] as String,
      farmId: json['farm_id'] as String,
      plantingId: json['planting_id'] as String,
      horizonStart: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      horizonDays: json['horizon_days'] as int? ?? 7,
      storyFingerprint: json['story_fingerprint'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      modelName: json['model_name'] as String?,
      promptVersion: json['prompt_version'] as String?,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      validUntil: json['valid_until'] == null
          ? null
          : DateTime.tryParse(json['valid_until'] as String),
      slots: slots,
    );
  }
}
