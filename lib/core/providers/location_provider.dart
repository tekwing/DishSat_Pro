import 'dart:async';
import 'package:flutter/material.dart'; // Needed for AppLifecycleState
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';

class LocationState {
  final double? lat;
  final double? lon;
  final double? accuracy;
  final bool isLocked;
  final bool isManualOverride; // Tracks if we are spoofing GPS
  final String? error;

  const LocationState({
    this.lat,
    this.lon,
    this.accuracy,
    required this.isLocked,
    this.isManualOverride = false, // Default to false
    this.error,
  });

  LocationState copyWith({
    double? lat,
    double? lon,
    double? accuracy,
    bool? isLocked,
    bool? isManualOverride,
    String? error,
    bool clearError = false, // Helper to wipe error messages
  }) {
    return LocationState(
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      accuracy: accuracy ?? this.accuracy,
      isLocked: isLocked ?? this.isLocked,
      isManualOverride: isManualOverride ?? this.isManualOverride,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final locationProvider = NotifierProvider<LocationNotifier, LocationState>(
  LocationNotifier.new,
);

// --- ADDED: 'with WidgetsBindingObserver' ---
class LocationNotifier extends Notifier<LocationState>
    with WidgetsBindingObserver {
  StreamSubscription<Position>? _sub;

  @override
  LocationState build() {
    state = const LocationState(isLocked: false);

    // Tell Flutter to start sending background/foreground lifecycle events to this provider
    WidgetsBinding.instance.addObserver(this);

    _init();

    ref.onDispose(() {
      // Clean up the observer when the provider dies to prevent memory leaks
      WidgetsBinding.instance.removeObserver(this);
      _sub?.cancel();
    });

    return state;
  }

  // --- THE LIFECYCLE TRIPWIRE ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // --------------------------------------------------------
      // APP MOVED TO BACKGROUND (Minimized or Screen Locked)
      // --------------------------------------------------------
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Pause the GPS stream to save battery!
        // (Only if we aren't using a manual override)
        if (!this.state.isManualOverride) {
          _sub?.pause();
          debugPrint("App backgrounded: GPS stream paused.");
        }
        break;

      // --------------------------------------------------------
      // APP RETURNED TO FOREGROUND
      // --------------------------------------------------------
      case AppLifecycleState.resumed:
        if (this.state.error != null && !this.state.isManualOverride) {
          // Scenario A: They had an error (like GPS off). Re-run the whole init!
          debugPrint("App resumed! Re-checking hardware GPS...");
          _init(); 
        } else if (!this.state.isManualOverride) {
          // Scenario B: They had a good connection. Just unpause the stream!
          _sub?.resume();
          debugPrint("App resumed: GPS stream resumed.");
        }
        break;

      default:
        break;
    }
  }

  Future<void> _init() async {
    // Prevent double-init if we are already manually overriding
    if (state.isManualOverride) return;

    final service = ref.read(locationServiceProvider);

    final serviceEnabled = await service.isServiceEnabled();

    if (!serviceEnabled) {
      state = state.copyWith(
        isLocked: false,
        error: "PLEASE TURN ON GPS / LOCATION SERVICES",
      );
      return;
    }

    var permission = await service.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await service.requestPermission();

      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          isLocked: false,
          error: "LOCATION PERMISSION DENIED",
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        isLocked: false,
        error: "PERMISSION PERMANENTLY DENIED IN SETTINGS",
      );
      return;
    }

    // Temporarily clear the error so the UI shifts to "Searching..."
    state = state.copyWith(clearError: true);

    // Initial rapid fetch
    try {
      final pos = await service.getInitialLocation();

      // Only apply if manual override hasn't been engaged in the split second this took
      if (!state.isManualOverride) {
        state = state.copyWith(
          lat: pos.latitude,
          lon: pos.longitude,
          accuracy: pos.accuracy,
          isLocked: true,
          clearError: true,
        );
      }
    } catch (_) {
      if (!state.isManualOverride) {
        state = state.copyWith(
          isLocked: false,
          error: "Waiting for GPS signal...",
        );
      }
    }

    // Cancel any existing subscription before creating a new one (prevents duplicate streams)
    await _sub?.cancel();

    // Continuous background stream
    _sub = service.getPositionStream().listen(
      (pos) {
        // Bulletproof check: Ignore hardware updates if override is active
        if (state.isManualOverride) return;

        state = state.copyWith(
          lat: pos.latitude,
          lon: pos.longitude,
          accuracy: pos.accuracy,
          isLocked: true,
          clearError: true,
        );
      },
      onError: (_) {
        if (!state.isManualOverride) {
          state = state.copyWith(isLocked: false, error: "GPS Signal Weak");
        }
      },
    );
  }

  // ==========================================
  // MANUAL OVERRIDE CONTROLS
  // ==========================================

  void setManualLocation(double lat, double lon) {
    // 1. Pause the hardware stream to save battery
    _sub?.pause();

    // 2. Inject the fake coordinates and lock the UI
    state = state.copyWith(
      lat: lat,
      lon: lon,
      accuracy: 1.0, // Perfect accuracy for manual inputs
      isLocked: true,
      isManualOverride: true,
      clearError: true,
    );
  }

  Future<void> clearManualLocation() async {
    // 1. Flip the flag back to live mode AND instantly lock the UI
    state = state.copyWith(
      isManualOverride: false,
      isLocked: false, // <--- THIS INSTANTLY TRIGGERS THE LOCK SCREEN
      error: "Searching for hardware GPS lock...",
    );

    // 2. Resume the hardware stream
    _sub?.resume();

    // 3. Force an immediate hardware ping so the UI doesn't lag
    try {
      final service = ref.read(locationServiceProvider);
      final pos = await service.getInitialLocation();

      // Ensure the user didn't hit override again while this was loading
      if (!state.isManualOverride) {
        state = state.copyWith(
          lat: pos.latitude,
          lon: pos.longitude,
          accuracy: pos.accuracy,
          isLocked: true,
          clearError: true,
        );
      }
    } catch (_) {
      if (!state.isManualOverride) {
        state = state.copyWith(
          isLocked: false,
          error: "Waiting for GPS signal...",
        );
      }
    }
  }
}
