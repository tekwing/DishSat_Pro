import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_compass/flutter_compass.dart';

class CompassState {
  final double azimuth;
  final bool isAvailable;
  final bool needsCalibration;
  final bool
  isLocked; // RESTORED: Prevents UI from updating while tightening bolts

  const CompassState({
    required this.azimuth,
    required this.isAvailable,
    required this.needsCalibration,
    required this.isLocked,
  });

  CompassState copyWith({
    double? azimuth,
    bool? isAvailable,
    bool? needsCalibration,
    bool? isLocked,
  }) {
    return CompassState(
      azimuth: azimuth ?? this.azimuth,
      isAvailable: isAvailable ?? this.isAvailable,
      needsCalibration: needsCalibration ?? this.needsCalibration,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class CompassService {
  /// Returns the raw stream of CompassEvents
  Stream<CompassEvent>? getCompassStream() {
    return FlutterCompass.events;
  }
}

final compassServiceProvider = Provider<CompassService>((ref) {
  return CompassService();
});

final compassProvider = NotifierProvider<CompassNotifier, CompassState>(
  CompassNotifier.new,
);

class CompassNotifier extends Notifier<CompassState> {
  StreamSubscription<CompassEvent>? _subscription;

  bool _first = true;
  static const double _alpha = 0.15; // Low-pass filter smoothing

  @override
  CompassState build() {
    state = const CompassState(
      azimuth: 0,
      isAvailable: false,
      needsCalibration: true, // Default to true until proven otherwise
      isLocked: false,
    );

    _startCompass();

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return state;
  }

  void _startCompass() {
    final service = ref.read(compassServiceProvider);
    final stream = service.getCompassStream();

    if (stream == null) {
      state = state.copyWith(isAvailable: false);
      return;
    }

    _subscription = stream.listen((event) {
      // If the user locked the screen, ignore incoming hardware data
      if (state.isLocked) return;

      final double? rawHeading = event.heading;
      final double? accuracy = event.accuracy;

      if (rawHeading == null) {
        state = state.copyWith(isAvailable: false);
        return;
      }

      // ==========================================
      // HARDWARE CALIBRATION CHECK
      // ==========================================
      // BUGFIX: Default to TRUE. If the OS can't confirm accuracy, assume it's bad.
      bool requiresCalib = true;

      if (accuracy != null) {
        if (Platform.isAndroid) {
          // Android accuracy: 0 (Unreliable), 1 (Low), 2 (Medium), 3 (High)
          requiresCalib = (accuracy <= 1.0);
        } else if (Platform.isIOS) {
          // iOS accuracy: margin of error in degrees. Negative means totally uncalibrated.
          requiresCalib = (accuracy < 0 || accuracy > 25.0);
        }
      }

      // ==========================================
      // LOW-PASS FILTER (Keeps UI Smooth)
      // ==========================================
      if (_first) {
        _first = false;
        state = state.copyWith(
          azimuth: rawHeading,
          isAvailable: true,
          needsCalibration: requiresCalib,
        );
        return;
      }

      double current = state.azimuth;
      double delta = rawHeading - current;

      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;

      current = (current + (_alpha * delta)) % 360;

      if (current < 0) {
        current += 360;
      }

      state = state.copyWith(
        azimuth: current,
        isAvailable: true,
        needsCalibration: requiresCalib,
      );
    });
  }

  /// Toggles the hardware state lock to freeze visual gauges in place
  void toggleLock() {
    state = state.copyWith(isLocked: !state.isLocked);
  }
}
