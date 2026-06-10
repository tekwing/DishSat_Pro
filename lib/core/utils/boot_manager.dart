import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class BootManager {
  /// Runs on Splash Screen to prime the OS permissions.
  /// It DOES NOT block the app or show any custom dialogs.
  static Future<bool> initializeLocation(BuildContext context) async {
    LocationPermission permission = await Geolocator.checkPermission();

    // If permissions haven't been asked yet, trigger the native OS popup
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    // We no longer check if the GPS hardware is actually toggled ON here.
    // We instantly return true so the Splash Screen drops them into the Home Screen.
    // The LocationNotifier will handle all hardware errors natively inside the tools!
    return true;
  }
}
