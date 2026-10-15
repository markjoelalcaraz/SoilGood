/// One Realtime listener for the signed-in farmer's tables.
///
/// Started from the app shell. Pages subscribe with [LivePage] and refetch
/// when a row changes, keeping the last screen on screen. Open-Meteo weather
/// is not a database table, so it refreshes when soil or the farm changes.
/// Not a widget.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../supabase/supabase_bootstrap.dart';

/// Which saved table changed. Several tables can share one source.
enum LiveSource {
  soil,
  plantings,
  devices,
  farms,
  profiles,
  assessments,
  irrigation,
  actions,
  crops,
}

/// Debounced Realtime signals for the farmer shell.
class FarmLiveHub extends ChangeNotifier {
  /// The shell hub, so a page pushed above the shell can still listen.
  static FarmLiveHub? active;

  final List<StreamSubscription<List<Map<String, dynamic>>>> _subs = [];
  Timer? _debounce;

  /// Sources in the latest debounced batch. Empty on an error-only notify.
  Set<LiveSource> changed = {};

  final Set<LiveSource> _pending = {};
  final Map<LiveSource, Object> _errors = {};

  bool _started = false;
  bool closed = false;

  /// Opens one stream per farmer table. Safe to call once from the shell.
  void start() {
    if (_started) return;
    _started = true;
    active = this;
    _listen(LiveSource.soil, 'soil_readings');
    _listen(LiveSource.plantings, 'plantings');
    _listen(LiveSource.devices, 'devices');
    _listen(LiveSource.farms, 'farms');
    _listen(LiveSource.profiles, 'profiles');
    _listen(LiveSource.assessments, 'ai_assessments');
    _listen(LiveSource.assessments, 'ai_recommendations');
    _listen(LiveSource.irrigation, 'irrigation_plans');
    _listen(LiveSource.irrigation, 'irrigation_plan_slots');
    _listen(LiveSource.actions, 'farm_actions');
    _listen(LiveSource.crops, 'crops');
  }

  /// Short note when a table is not in the Realtime publication yet.
  String? messageFor(Set<LiveSource> sources) {
    final names = <String>[];
    for (final source in sources) {
      if (_errors.containsKey(source)) names.add(source.name);
    }
    if (names.isEmpty) return null;
    return 'Realtime is off for ${names.join(', ')}. '
        'Run docs/context/supabase_realtime.sql in the Supabase SQL Editor.';
  }

  void _listen(LiveSource source, String table) {
    var skipSnapshot = true;
    final sub = supabase.from(table).stream(primaryKey: ['id']).listen(
      (rows) {
        if (skipSnapshot) {
          skipSnapshot = false;
          if (_errors.remove(source) != null) {
            changed = {};
            notifyListeners();
          }
          return;
        }
        _errors.remove(source);
        _queue(source);
      },
      onError: (Object error) {
        _errors[source] = error;
        changed = {};
        notifyListeners();
      },
    );
    _subs.add(sub);
  }

  /// Coalesce bursts (a save often writes two tables) into one page refresh.
  void _queue(LiveSource source) {
    _pending.add(source);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      changed = Set<LiveSource>.of(_pending);
      _pending.clear();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    closed = true;
    if (identical(active, this)) active = null;
    _debounce?.cancel();
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }
}
