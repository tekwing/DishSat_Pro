import 'package:sensors_plus/sensors_plus.dart';

class AccelerometerService {
  Stream<AccelerometerEvent> getStream() {
    return accelerometerEventStream();
  }
}
