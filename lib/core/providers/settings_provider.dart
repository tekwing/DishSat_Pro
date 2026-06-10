import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// 1. The State Object
class AppSettings {
  final bool useTrueNorth;
  final bool enableSound;
  final bool preventScreenOff;
  final bool enableVibration;
  final double dishOffsetAngle; // --- NEW VARIABLE ---

  AppSettings({
    this.useTrueNorth = true,
    this.enableSound = true,
    this.preventScreenOff = true,
    this.enableVibration = true,
    this.dishOffsetAngle = 22.0, // Default offset for standard dishes
  });

  AppSettings copyWith({
    bool? useTrueNorth,
    bool? enableSound,
    bool? preventScreenOff,
    bool? enableVibration,
    double? dishOffsetAngle,
  }) {
    return AppSettings(
      useTrueNorth: useTrueNorth ?? this.useTrueNorth,
      enableSound: enableSound ?? this.enableSound,
      preventScreenOff: preventScreenOff ?? this.preventScreenOff,
      enableVibration: enableVibration ?? this.enableVibration,
      dishOffsetAngle: dishOffsetAngle ?? this.dishOffsetAngle,
    );
  }
}

// 2. The Notifier (Controller)
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings()) {
    _loadSettings();
  }

  final _box = Hive.box('app_settings');

  void _loadSettings() {
    state = AppSettings(
      useTrueNorth: _box.get('useTrueNorth', defaultValue: true),
      enableSound: _box.get('enableSound', defaultValue: true),
      preventScreenOff: _box.get('preventScreenOff', defaultValue: true),
      enableVibration: _box.get('enableVibration', defaultValue: true),
      dishOffsetAngle: _box.get('dishOffsetAngle', defaultValue: 22.0),
    );
    _applyWakelock(state.preventScreenOff);
  }

  void toggleTrueNorth(bool value) {
    state = state.copyWith(useTrueNorth: value);
    _box.put('useTrueNorth', value);
  }

  void toggleSound(bool value) {
    state = state.copyWith(enableSound: value);
    _box.put('enableSound', value);
  }

  void toggleVibration(bool value) {
    state = state.copyWith(enableVibration: value);
    _box.put('enableVibration', value);
  }

  void toggleScreenOff(bool value) {
    state = state.copyWith(preventScreenOff: value);
    _box.put('preventScreenOff', value);
    _applyWakelock(value);
  }

  // --- NEW METHOD FOR OFFSET SLIDER ---
  void setDishOffsetAngle(double value) {
    state = state.copyWith(dishOffsetAngle: value);
    _box.put('dishOffsetAngle', value);
  }

  // Hardware execution for screen wake
  void _applyWakelock(bool enable) {
    if (enable) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }
}

// 3. The Global Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier();
});
