/// Supabase access for irrigation plans, slots, and Mark watered logs.
///
/// Data layer for the Crops water plan. Inserts `farm_actions` then links the
/// Today slot. Callers own UI / optimistic updates.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../analytics/logic/manila_time.dart';
import 'irrigation_plan.dart';
import '../logic/irrigation_plan_builder.dart';

/// Loads / saves irrigation plans and irrigation farm_actions.
class IrrigationPlanRepository {
  IrrigationPlanRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Latest plan for this planting (with slots), or null.
  Future<IrrigationPlan?> fetchLatest({
    required String farmId,
    required String plantingId,
  }) async {
    final row = await _client
        .from('irrigation_plans')
        .select()
        .eq('farm_id', farmId)
        .eq('planting_id', plantingId)
        .order('generated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;

    final plan = IrrigationPlan.fromJson(Map<String, dynamic>.from(row as Map));
    final slotRows = await _client
        .from('irrigation_plan_slots')
        .select()
        .eq('plan_id', plan.id)
        .order('slot_date');
    final slots = (slotRows as List)
        .map((e) => IrrigationPlanSlot.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return IrrigationPlan.fromJson(
      Map<String, dynamic>.from(row as Map),
      slots: slots,
    );
  }

  /// Manila calendar day of last irrigation action for this farm/planting.
  Future<DateTime?> fetchLastIrrigationDay({
    required String farmId,
    String? plantingId,
  }) async {
    var q = _client
        .from('farm_actions')
        .select('performed_at')
        .eq('farm_id', farmId)
        .eq('action_type', 'irrigation');
    if (plantingId != null) {
      q = q.eq('planting_id', plantingId);
    }
    final row = await q
        .order('performed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    final at = DateTime.tryParse(row['performed_at'] as String? ?? '');
    if (at == null) return null;
    return manilaCalendarDate(at);
  }

  /// Count irrigation logs in a Manila-inclusive range (for Analytics).
  Future<int> countIrrigations({
    required String farmId,
    required DateTime start,
    required DateTime end,
  }) async {
    final range = manilaRangeUtcForDates(start, end);
    final rows = await _client
        .from('farm_actions')
        .select('id')
        .eq('farm_id', farmId)
        .eq('action_type', 'irrigation')
        .gte('performed_at', range.from.toIso8601String())
        .lt('performed_at', range.to.toIso8601String());
    return (rows as List).length;
  }

  /// Recent irrigation actions for Analytics diary list.
  Future<List<Map<String, dynamic>>> fetchIrrigationHistory({
    required String farmId,
    required DateTime start,
    required DateTime end,
    int limit = 20,
  }) async {
    final range = manilaRangeUtcForDates(start, end);
    final rows = await _client
        .from('farm_actions')
        .select('id, performed_at, notes, plan_slot_id')
        .eq('farm_id', farmId)
        .eq('action_type', 'irrigation')
        .gte('performed_at', range.from.toIso8601String())
        .lt('performed_at', range.to.toIso8601String())
        .order('performed_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Saves a new plan + slots. Optionally keeps Done links from [previous].
  Future<IrrigationPlan> savePlan({
    required String farmId,
    required String plantingId,
    required DateTime horizonStart,
    required String storyFingerprint,
    required List<IrrigationSlotDraft> drafts,
    IrrigationPlan? previous,
    String overview = '',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Not signed in.');
    }

    final completedByDate = <String, String>{};
    if (previous != null) {
      for (final s in previous.slots) {
        final id = s.completedActionId;
        if (id != null) {
          completedByDate[manilaIsoDate(s.slotDate)] = id;
        }
      }
    }

    final validUntil = DateTime.now().toUtc().add(const Duration(hours: 24));
    final inserted = await _client
        .from('irrigation_plans')
        .insert({
          'farm_id': farmId,
          'planting_id': plantingId,
          'horizon_start': manilaIsoDate(horizonStart),
          'horizon_days': drafts.length,
          'story_fingerprint': storyFingerprint,
          'overview': overview,
          'model_name': 'rules_v1',
          'prompt_version': kIrrigationPlanRulesVersion,
          'valid_until': validUntil.toIso8601String(),
        })
        .select()
        .single();

    final planId = inserted['id'] as String;
    final slotPayload = drafts.map((d) {
      final key = manilaIsoDate(d.slotDate);
      final doneId = completedByDate[key];
      return {
        'plan_id': planId,
        'slot_date': key,
        'action': d.action.dbValue,
        'confidence': d.confidence,
        'guidance': doneId != null ? 'Watered' : d.guidance,
        'reason': doneId != null ? 'Logged from plan' : d.reason,
        'completed_action_id': ?doneId,
      };
    }).toList();
    await _client.from('irrigation_plan_slots').insert(slotPayload);

    return (await fetchLatest(farmId: farmId, plantingId: plantingId))!;
  }

  /// True when story, day roll, or expiry means we should rewrite the horizon.
  bool needsRebuild({
    required IrrigationPlan? plan,
    required String fingerprint,
    required DateTime todayManila,
  }) {
    if (plan == null || plan.slots.isEmpty) return true;
    if (plan.storyFingerprint != fingerprint) return true;
    if (!sameManilaDay(plan.horizonStart, todayManila)) return true;
    final until = plan.validUntil;
    if (until != null && DateTime.now().toUtc().isAfter(until.toUtc())) {
      return true;
    }
    return false;
  }

  /// Marks Today watered: inserts farm_action and links slot.
  Future<void> markWatered({
    required String farmId,
    required String plantingId,
    required IrrigationPlanSlot slot,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Not signed in.');
    }
    final today = manilaCalendarDate(DateTime.now());
    if (!sameManilaDay(slot.slotDate, today)) {
      throw StateError('Only today’s water slot can be marked.');
    }
    if (slot.isLogged) return;

    final action = await _client
        .from('farm_actions')
        .insert({
          'farm_id': farmId,
          'created_by': userId,
          'planting_id': plantingId,
          'plan_slot_id': slot.id,
          'action_type': 'irrigation',
          'notes': 'Marked watered from Crops plan',
          'performed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    await _client.from('irrigation_plan_slots').update({
      'completed_action_id': action['id'],
      'guidance': 'Watered',
      'reason': 'Logged from plan',
    }).eq('id', slot.id);
  }
}
