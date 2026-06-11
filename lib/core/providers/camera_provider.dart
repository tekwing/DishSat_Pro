import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart'; // ADD THIS

final cameraProvider = FutureProvider.autoDispose<CameraController>((
  ref,
) async {
  // 1. EXPLICIT PERMISSION CHECK
  var status = await Permission.camera.status;

  // If it's denied (first time), ask for it natively
  if (status.isDenied) {
    status = await Permission.camera.request();
  }

  // If they previously clicked "Deny" or "Don't ask again"
  if (status.isPermanentlyDenied) {
    // Throw a specific error code we can catch in the UI
    throw Exception('PERMISSION_PERMANENTLY_DENIED');
  }

  // If it's still not granted for any other reason
  if (!status.isGranted) {
    throw Exception('Camera permission is required for AR.');
  }

  // 2. INITIALIZE CAMERA (Your original code)
  final cameras = await availableCameras();
  if (cameras.isEmpty) {
    throw Exception('No cameras available on this device.');
  }

  final controller = CameraController(
    cameras.first,
    ResolutionPreset.high,
    enableAudio: false,
  );

  await controller.initialize();

  // 3. EXPLICIT CLEANUP
  ref.onDispose(() {
    controller.dispose();
  });

  return controller;
});
