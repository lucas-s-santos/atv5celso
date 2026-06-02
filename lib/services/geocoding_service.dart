import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const _searchUrl = 'https://nominatim.openstreetmap.org/search';
  static const _headers = {
    'User-Agent': 'atv5-entregas-flutter/1.0',
    'Accept-Language': 'pt-BR,pt',
  };

  Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(
        queryParameters: {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'format': 'json',
          'addressdetails': '1',
        },
      );
      final response =
          await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final road   = addr['road'] ?? addr['pedestrian'] ?? addr['path'] ?? '';
          final number = addr['house_number'] ?? '';
          final city   = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? '';
          final state  = addr['state'] ?? '';
          final parts  = [
            if ((road as String).isNotEmpty) road + ((number as String).isNotEmpty ? ', $number' : ''),
            if ((city as String).isNotEmpty) city,
            if ((state as String).isNotEmpty) state,
          ];
          if (parts.isNotEmpty) return parts.join(' — ');
        }
        return data['display_name'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<({double latitude, double longitude})?> geocode(String address) async {
    try {
      final uri = Uri.parse(_searchUrl).replace(queryParameters: {
        'q': address,
        'format': 'json',
        'limit': '1',
        'addressdetails': '0',
      });
      final response =
          await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (data.isNotEmpty) {
          return (
            latitude: double.parse(data[0]['lat'] as String),
            longitude: double.parse(data[0]['lon'] as String),
          );
        }
      }
    } catch (_) {}
    return null;
  }
}
