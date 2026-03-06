import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Obtener posición actual con máxima precisión
  static Future<Position?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        return position;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Obtener URL de Google Maps con ubicación actual
  static Future<String?> getLocationMapUrl() async {
    try {
      final position = await getCurrentLocation();
      if (position != null) {
        return 'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Obtener ubicación como texto (latitud, longitud)
  static Future<String?> getLocationAsText() async {
    try {
      final position = await getCurrentLocation();
      if (position != null) {
        return '${position.latitude}, ${position.longitude}';
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}
