import 'package:geolocator/geolocator.dart';

/// Service to handle offline navigation math (Distance & Bearing)
/// Because Google Maps tiles won't load offline.
class OfflineNavService {
  /// Calculates distance in kilometers between two GPS coordinates.
  /// Returns a formatted string like '2.5 km'
  static String getDistanceString(
      double startLat, double startLng, double endLat, double endLng) {
    double distanceInMeters =
        Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      double distanceInKm = distanceInMeters / 1000;
      return '${distanceInKm.toStringAsFixed(1)} km';
    }
  }

  /// Calculates the cardinal direction (N, NE, E, SE, etc.) from start to end point.
  static String getDirectionString(
      double startLat, double startLng, double endLat, double endLng) {
    // bearingBetween returns the initial bearing in degrees (0 to 360)
    // 0 = North, 90 = East, 180 = South, 270 = West
    double bearing =
        Geolocator.bearingBetween(startLat, startLng, endLat, endLng);

    // Normalize bearing to 0-360 just in case
    bearing = (bearing + 360) % 360;

    if (bearing >= 337.5 || bearing < 22.5) {
      return 'North';
    } else if (bearing >= 22.5 && bearing < 67.5) {
      return 'North-East';
    } else if (bearing >= 67.5 && bearing < 112.5) {
      return 'East';
    } else if (bearing >= 112.5 && bearing < 157.5) {
      return 'South-East';
    } else if (bearing >= 157.5 && bearing < 202.5) {
      return 'South';
    } else if (bearing >= 202.5 && bearing < 247.5) {
      return 'South-West';
    } else if (bearing >= 247.5 && bearing < 292.5) {
      return 'West';
    } else if (bearing >= 292.5 && bearing < 337.5) {
      return 'North-West';
    } else {
      return 'Unknown';
    }
  }

  /// Returns a combined routing string: '2.5 km North-East'
  static String getRoutingString(
      double startLat, double startLng, double endLat, double endLng) {
    String distance = getDistanceString(startLat, startLng, endLat, endLng);
    String direction = getDirectionString(startLat, startLng, endLat, endLng);
    return '$distance $direction';
  }
}
