import 'package:geolocator/geolocator.dart';

class LocationService {
  static const _mockLat = -23.5505;
  static const _mockLon = -46.6333;

  Future<({double latitude, double longitude, bool isMock})> getCurrentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return (latitude: _mockLat, longitude: _mockLon, isMock: true);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 20), onTimeout: () => throw Exception());
      return (latitude: pos.latitude, longitude: pos.longitude, isMock: false);
    } catch (_) {
      return (latitude: _mockLat, longitude: _mockLon, isMock: true);
    }
  }
}
