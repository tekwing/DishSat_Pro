import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/satellite_registry.dart';
import '../../models/satellite_model.dart';

// ==========================================
// GLOBAL STATE: ACTIVE SATELLITE
// ==========================================
// This provider holds the currently selected target satellite globally.
// Any screen can watch this, and when it updates, all screens update automatically.

final activeSatelliteProvider = StateProvider<Satellite>((ref) {
  if (SatelliteRepository.satellites.isEmpty) {
    throw Exception("No satellites found in registry");
  }

  // Default to the first satellite in your registry on app startup
  return SatelliteRepository.satellites.first;
});
