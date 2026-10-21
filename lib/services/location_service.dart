import 'package:geolocator/geolocator.dart';

/// Ported from expo-location usage in settings.tsx / qibla.tsx.
class LocationService {
  /// Requests foreground permission if needed and returns the current
  /// position, or throws with a readable state.
  static Future<Position> getCurrentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('denied');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('deniedForever');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }
}
