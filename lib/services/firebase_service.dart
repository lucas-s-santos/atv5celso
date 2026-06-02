import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/delivery.dart';

class FirebaseService {
  static const _dbUrl = 'https://atv5-entrega-default-rtdb.firebaseio.com';

  Future<List<Delivery>> fetchAll() async {
    final response = await http
        .get(Uri.parse('$_dbUrl/deliveries.json'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body == null) return [];
    if (body is! Map) throw Exception('Resposta inesperada: ${body.runtimeType}');

    final result = <Delivery>[];
    for (final entry in body.entries) {
      if (entry.value == null || entry.value is! Map) continue;
      try {
        final map = Map<String, dynamic>.from(entry.value as Map);
        map['id'] = int.tryParse(entry.key.toString());
        result.add(Delivery.fromMap(map));
      } catch (e) {
        debugPrint('[Firebase] parse entry ${entry.key}: $e');
      }
    }
    result.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    return result;
  }

  Future<void> upsert(Delivery d) async {
    final map = Map<String, dynamic>.from(d.toMap())..remove('id');
    final response = await http
        .put(
          Uri.parse('$_dbUrl/deliveries/${d.id}.json'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(map),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  Future<void> delete(int id) async {
    await http
        .delete(Uri.parse('$_dbUrl/deliveries/$id.json'))
        .timeout(const Duration(seconds: 10));
  }
}
