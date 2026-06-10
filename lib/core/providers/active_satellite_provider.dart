import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/satellite_registry.dart';
import '../../models/satellite_model.dart';

// ==========================================
// GLOBAL STATE: ACTIVE SATELLITE (HIVE PERSISTENCE)
// ==========================================
// This provider holds the currently selected target satellite globally.
// It instantly loads from Hive on boot and saves continuously.

class ActiveSatelliteNotifier extends Notifier<Satellite> {
  // Use a dedicated box for app settings/preferences
  static const String _boxName = 'settingsBox';
  static const String _storageKey = 'ACTIVE_SATELLITE_NAME';

  @override
  Satellite build() {
    if (SatelliteRepository.satellites.isEmpty) {
      throw Exception("No satellites found in registry");
    }

    final defaultSat = SatelliteRepository.satellites.first;

    // Because Hive is fast and synchronous, we can return the saved
    // satellite instantly without flashing the default one first!
    if (Hive.isBoxOpen(_boxName)) {
      final box = Hive.box(_boxName);
      final savedName = box.get(_storageKey);

      if (savedName != null) {
        return SatelliteRepository.satellites.firstWhere(
          (sat) => sat.name == savedName,
          orElse: () => defaultSat, // Fallback if the saved one was deleted
        );
      }
    }

    return defaultSat;
  }

  void setActiveSatellite(Satellite newSat) {
    // 1. Update the UI immediately
    state = newSat;

    // 2. Save to Hive synchronously
    if (Hive.isBoxOpen(_boxName)) {
      Hive.box(_boxName).put(_storageKey, newSat.name);
    } else {
      // Safety net just in case the box closed unexpectedly
      Hive.openBox(_boxName).then((box) => box.put(_storageKey, newSat.name));
    }
  }
}

final activeSatelliteProvider =
    NotifierProvider<ActiveSatelliteNotifier, Satellite>(() {
      return ActiveSatelliteNotifier();
    });
