import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';
  static const Duration _timeout = Duration(seconds: 10);

  static Future<Map<String, dynamic>> getFrostCheck({
    double lat = 19.0414,
    double lon = -98.2063,
  }) async {
    final uri = Uri.parse('$baseUrl/analysis/frost-check');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'lat': lat, 'lon': lon}),
    ).timeout(_timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('frost-check error ${response.statusCode}');
  }
}