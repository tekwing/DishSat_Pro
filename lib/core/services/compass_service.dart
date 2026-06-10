import 'package:flutter_compass/flutter_compass.dart';

class CompassService {
  Stream<double?> getHeadingStream() {
    return FlutterCompass.events?.map((event) => event.heading) ??
        const Stream.empty();
  }
}
