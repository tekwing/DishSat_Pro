import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/accelerometer_service.dart';

class AccelerometerState {
  final double elevation;
  final double roll;

  const AccelerometerState({required this.elevation, required this.roll});

  AccelerometerState copyWith({double? elevation, double? roll}) {
    return AccelerometerState(
      elevation: elevation ?? this.elevation,
      roll: roll ?? this.roll,
    );
  }
}

final accelerometerServiceProvider = Provider<AccelerometerService>((ref) {
  return AccelerometerService();
});

final accelerometerProvider =
    NotifierProvider<AccelerometerNotifier, AccelerometerState>(
      AccelerometerNotifier.new,
    );

class AccelerometerNotifier extends Notifier<AccelerometerState> {
  StreamSubscription<AccelerometerEvent>? _sub;

  double? _x;
  double? _y;
  double? _z;

  static const double _alpha = 0.15;

  @override
  AccelerometerState build() {
    state = const AccelerometerState(elevation: 0, roll: 0);

    _start();

    ref.onDispose(() {
      _sub?.cancel();
    });

    return state;
  }

  void _start() {
    final service = ref.read(accelerometerServiceProvider);

    _sub = service.getStream().listen((event) {
      // 1. Smooth the raw sensor data
      _x = _x == null ? event.x : (_alpha * event.x) + ((1 - _alpha) * _x!);
      _y = _y == null ? event.y : (_alpha * event.y) + ((1 - _alpha) * _y!);
      _z = _z == null ? event.z : (_alpha * event.z) + ((1 - _alpha) * _z!);

      // =========================================================
      // 2. THE FIX: AR CAMERA ELEVATION (PITCH)
      // Calculates angle from Horizon (0°) to Sky Zenith (90°)
      // We use math.sqrt on X and Y so that if the user tilts the phone
      // slightly sideways (roll), the elevation reading remains perfectly stable.
      // =========================================================
      final pitchRadians = math.atan2(
        -_z!,
        math.sqrt((_x! * _x!) + (_y! * _y!)),
      );

      double elevationDegrees = pitchRadians * (180 / math.pi);

      // 3. ROLL (For the LNB Skew Tool)
      final rollRadians = math.atan2(_x!, math.sqrt((_y! * _y!) + (_z! * _z!)));

      state = state.copyWith(
        elevation: elevationDegrees,
        roll: rollRadians * (180 / math.pi),
      );
    });
  }
}
