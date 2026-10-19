/// App-wide memory of which planted crop the farmer is looking at.
///
/// Logic layer only (no widgets). A farm can grow several crops at once; Home,
/// the Farm tab, and Profile → Sensors all read this so they show the same
/// crop. The choice survives app restarts via SharedPreferences.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/planting.dart';

/// Holds the selected planting id and notifies listeners when it changes.
class SelectedCrop {
  SelectedCrop._();

  static final SelectedCrop instance = SelectedCrop._();

  static const _prefsKey = 'selected_planting_id';

  /// Current planting id, or null before the first load / when nothing is planted.
  final ValueNotifier<String?> plantingId = ValueNotifier<String?>(null);

  bool _restored = false;

  /// Reads the saved choice once per app run.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    final prefs = await SharedPreferences.getInstance();
    plantingId.value ??= prefs.getString(_prefsKey);
  }

  /// Farmer picked a crop (Home picker, Farm chip, or just planted one).
  Future<void> select(String id) async {
    plantingId.value = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, id);
  }

  /// Saved crop if it is still active, otherwise the oldest active crop.
  ///
  /// Also fixes the stored id when the saved crop was ended (Change crop).
  Planting? resolve(List<Planting> plantings) {
    if (plantings.isEmpty) return null;
    final id = plantingId.value;
    for (final p in plantings) {
      if (p.id == id) return p;
    }
    final fallback = plantings.first;
    plantingId.value = fallback.id;
    return fallback;
  }
}
