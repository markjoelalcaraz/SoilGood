/// Data repository for farm alert rows in Supabase `farm_notifications`.
///
/// The engine inserts classified alerts. The pushed inbox page lists them,
/// listens via Realtime, and marks read. RLS keeps each farmer on their own
/// farm rows. Same-day duplicates skip via upsert ignoreDuplicates (no 409).
library;

import '../../../core/supabase/supabase_bootstrap.dart';
import 'farm_notification.dart';

/// Persists and loads classified farm alerts for the signed-in owner.
class NotificationsRepository {
  /// Inserts [draft] or returns null when that type already exists today.
  ///
  /// Uses upsert + ignoreDuplicates so a same-day alert is a 2xx skip, not a
  /// 409 unique-violation that Chrome logs as an error.
  Future<FarmNotification?> insertIfNew(NotificationDraft draft) async {
    final row = await supabase
        .from('farm_notifications')
        .upsert(
          draft.toInsertJson(),
          onConflict: 'farm_id,dedupe_key',
          ignoreDuplicates: true,
        )
        .select()
        .maybeSingle();
    if (row == null) return null;
    return FarmNotification.fromJson(Map<String, dynamic>.from(row));
  }

  /// Inserts each draft; skips same-day duplicates; keeps insert order.
  Future<List<FarmNotification>> insertNewDrafts(
    List<NotificationDraft> drafts,
  ) async {
    final inserted = <FarmNotification>[];
    for (final draft in drafts) {
      final row = await insertIfNew(draft);
      if (row != null) inserted.add(row);
    }
    return inserted;
  }

  /// Newest alerts for the farmer's farms (inbox first paint / pull).
  Future<List<FarmNotification>> fetchRecent({int limit = 60}) async {
    final farmIds = await _ownedFarmIds();
    if (farmIds.isEmpty) return [];

    final rows = await supabase
        .from('farm_notifications')
        .select()
        .inFilter('farm_id', farmIds)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((e) => FarmNotification.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Live inbox updates via Supabase Realtime on `farm_notifications`.
  Stream<List<FarmNotification>> watchRecent({int limit = 60}) async* {
    final farmIds = await _ownedFarmIds();
    if (farmIds.isEmpty) {
      yield [];
      return;
    }

    yield* supabase
        .from('farm_notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) {
          final owned = rows.where((r) => farmIds.contains(r['farm_id']));
          return owned
              .take(limit)
              .map(
                (r) => FarmNotification.fromJson(Map<String, dynamic>.from(r)),
              )
              .toList();
        });
  }

  /// Sets [read_at] on one row. Inbox uses this after optimistic UI.
  Future<void> markRead(String id) async {
    await supabase
        .from('farm_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// Marks every unread row in [ids] as read in one update.
  Future<void> markAllRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await supabase
        .from('farm_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('id', ids);
  }

  /// Marks unread rows whose [type] is in [types] (tab visit / auto-ack).
  Future<void> markTypesRead(Iterable<FarmNotificationType> types) async {
    final names = types.map((t) => t.wireName).toList();
    if (names.isEmpty) return;
    final farmIds = await _ownedFarmIds();
    if (farmIds.isEmpty) return;

    await supabase
        .from('farm_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('farm_id', farmIds)
        .inFilter('type', names)
        .isFilter('read_at', null);
  }

  Future<List<String>> _ownedFarmIds() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];

    final farms = await supabase.from('farms').select('id').eq('owner_id', uid);
    return (farms as List).map((e) => e['id'] as String).toList();
  }
}
