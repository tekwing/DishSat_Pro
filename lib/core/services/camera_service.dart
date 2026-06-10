import 'package:camera/camera.dart';
import '../../main.dart';

class CameraService {
  Future<CameraController> initialize() async {
    if (cameras.isEmpty) {
      throw Exception('No cameras available');
    }

    final controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller.initialize();

    return controller;
  }
}
