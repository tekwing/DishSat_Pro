import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. The .autoDispose modifier is the magic key.
// It tells Riverpod: "When no screens are watching this, destroy it."
final cameraProvider = FutureProvider.autoDispose<CameraController>((
  ref,
) async {
  // Fetch available cameras
  final cameras = await availableCameras();
  if (cameras.isEmpty) {
    throw Exception('No cameras available on this device.');
  }

  // Initialize the back camera
  final controller = CameraController(
    cameras.first,
    ResolutionPreset.high,
    enableAudio: false, // Don't request mic permissions for AR
  );

  await controller.initialize();

  // 2. EXPLICIT CLEANUP
  // When the user pops the AR screen, Riverpod triggers this callback.
  // This physically releases the hardware camera back to the phone OS.
  ref.onDispose(() {
    controller.dispose();
  });

  return controller;
});
