/// Mixin for a data page that should refetch when [FarmLiveHub] fires.
///
/// Hidden shell tabs wait (IndexedStack turns tickers off) and catch up when
/// the farmer comes back, so Groq is not billed for a tab that is not showing.
/// Pull-to-refresh stays. This does not replace the first load.
library;

import 'package:flutter/material.dart';

import 'farm_live_hub.dart';
import 'farm_live_scope.dart';

/// Refetches [liveSources] when those tables change.
mixin LivePage<T extends StatefulWidget> on State<T> {
  /// Tables this page shows. A change outside this set is ignored.
  Set<LiveSource> get liveSources;

  /// Reload the rows this page is showing. Keep the last screen up.
  Future<void> onLive(Set<LiveSource> changed);

  FarmLiveHub? _hub;
  bool _visible = true;
  bool _dirtyWhileHidden = false;
  bool _busy = false;
  bool _queued = false;
  final Set<LiveSource> _batch = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    final hub = FarmLiveScope.maybeOf(context) ?? FarmLiveHub.active;
    if (!identical(hub, _hub)) {
      _hub?.removeListener(_onHub);
      _hub = hub;
      _hub?.addListener(_onHub);
    }
    if (_visible && _dirtyWhileHidden) {
      _dirtyWhileHidden = false;
      _flush();
    }
  }

  @override
  void dispose() {
    if (_hub != null && !_hub!.closed) {
      _hub!.removeListener(_onHub);
    }
    super.dispose();
  }

  void _onHub() {
    final hub = _hub;
    if (hub == null || !mounted) return;
    final hit = hub.changed.intersection(liveSources);
    if (hit.isEmpty) return;
    _batch.addAll(hit);
    if (!_visible) {
      _dirtyWhileHidden = true;
      return;
    }
    _flush();
  }

  /// One refresh at a time. A change during the fetch runs once more after.
  void _flush() {
    if (_busy) {
      _queued = true;
      return;
    }
    _busy = true;
    () async {
      try {
        do {
          _queued = false;
          final batch = Set<LiveSource>.of(_batch);
          _batch.clear();
          if (batch.isEmpty || !mounted) return;
          await onLive(batch);
        } while (_queued && mounted);
      } finally {
        _busy = false;
      }
    }();
  }
}
