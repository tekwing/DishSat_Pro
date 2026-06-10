import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart'; // ADDED HIVE IMPORT

// Make sure this path points to your model file!
import 'models/satellite_model.dart';

import 'app/app.dart';

/// Global camera list
List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Hive Database
  await Hive.initFlutter();

  // 2. Register the generated adapters
  Hive.registerAdapter(TransponderAdapter());
  Hive.registerAdapter(SatelliteAdapter());

  // 3. Open the specific storage box (table) for custom satellites
  await Hive.openBox<Satellite>('custom_satellites');

  await Hive.openBox('app_settings');

  // 4. Initialize Hardware Cameras
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error fetching hardware cameras: $e');
  }

  // 5. Boot the App
  runApp(const ProviderScope(child: DishAlignerApp()));
}
