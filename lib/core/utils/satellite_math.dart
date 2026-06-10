import 'dart:math' as math;
import 'package:geomag/geomag.dart';

class SatelliteMath {
  // Earth and Geostationary Orbit constants
  static const double _earthRadius = 6371.0;
  static const double _satelliteRadius = 42164.0;
  static const double _ratio = _earthRadius / _satelliteRadius; // ~0.1511

  // 1. AZIMUTH (Updated to handle True North vs Magnetic North)
  static double getAzimuth({
    required double userLat,
    required double userLon,
    required double satLon,
    required bool useTrueNorth,
    required double
    magneticDeclination, // In degrees (Positive for East, Negative for West)
  }) {
    double latRad = userLat * math.pi / 180.0;
    double deltaLonRad = (satLon - userLon) * math.pi / 180.0;

    double y = math.sin(deltaLonRad);
    double x = -math.sin(latRad) * math.cos(deltaLonRad);

    double azRad = math.atan2(y, x);
    double azDeg = azRad * 180.0 / math.pi;

    // This is your raw geographic True Azimuth
    double trueAzimuth = (azDeg + 360.0) % 360.0;

    if (useTrueNorth) {
      return trueAzimuth;
    } else {
      // Convert True Azimuth to Magnetic Azimuth for analog compasses
      // (True Heading - Declination = Magnetic Heading)
      return (trueAzimuth - magneticDeclination + 360.0) % 360.0;
    }
  }

  // 2. ELEVATION (Tilt: 0 to 90) - Unchanged
  static double getElevation(double userLat, double userLon, double satLon) {
    double latRad = userLat * math.pi / 180.0;
    double deltaLonRad = (satLon - userLon) * math.pi / 180.0;

    double cosGamma = math.cos(latRad) * math.cos(deltaLonRad);
    double gamma = math.acos(cosGamma);
    double sinGamma = math.sin(gamma);

    if (sinGamma == 0) return 90.0; // Directly overhead

    double elRad = math.atan((cosGamma - _ratio) / sinGamma);
    return elRad * 180.0 / math.pi;
  }

  // 3. LNB SKEW (Rotation: -90 to 90) - Unchanged
  // static double getSkew(double userLat, double userLon, double satLon) {
  //   double latRad = userLat * math.pi / 180.0;
  //   double deltaLonRad = (satLon - userLon) * math.pi / 180.0;

  //   double skewRad = math.atan2(math.sin(deltaLonRad), math.tan(latRad));
  //   return skewRad * 180.0 / math.pi;
  // }

  static double getSkew(double userLat, double userLon, double satLon) {
    double latRad = userLat * math.pi / 180.0;
    double deltaLonRad = (satLon - userLon) * math.pi / 180.0;

    // Standard geostationary LNB skew equation using atan2
    double skewRad = math.atan2(math.sin(deltaLonRad), math.tan(latRad));
    double skewDeg = skewRad * 180.0 / math.pi;

    // Invert the sign to adhere to standard satellite installation conventions:
    // Eastern satellites relative to user longitude require a negative skew.
    return -skewDeg;
  }
}

class MagneticService {
  /// Calculates the exact magnetic declination for any Lat/Lon on Earth
  /// Returns a double representing degrees (Positive = East, Negative = West)
  static double getDeclination(double latitude, double longitude) {
    // 1. Initialize the World Magnetic Model
    final geoMag = GeoMag();

    // 2. Calculate the magnetic field for today's date at the GPS coordinates
    final result = geoMag.calculate(latitude, longitude);

    // 3. Return the declination in degrees
    return result.dec;
  }
}
