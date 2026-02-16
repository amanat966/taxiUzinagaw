import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Use local IP for mobile device, localhost for Windows/Web
  static const String baseUrl = 'http://192.168.1.178:8080';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer \$token',
    };
  }

  // Auth
  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('\$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      // Store user info if needed, or just specific fields
      return data;
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<Map<String, dynamic>> register(
    String name,
    String phone,
    String password,
    String role,
  ) async {
    final response = await http.post(
      Uri.parse('\$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'password': password,
        'role': role,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_parseError(response));
    }
  }

  // Drivers
  Future<List<dynamic>> getDrivers() async {
    final response = await http.get(
      Uri.parse('\$baseUrl/api/drivers'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<void> updateDriverStatus(String status) async {
    final response = await http.put(
      Uri.parse('\$baseUrl/api/drivers/status'),
      headers: await _getHeaders(),
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  // Orders
  Future<List<dynamic>> getOrders() async {
    final response = await http.get(
      Uri.parse('\$baseUrl/api/orders'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<void> createOrder(
    String from,
    String to,
    String comment,
    int? driverId,
  ) async {
    final response = await http.post(
      Uri.parse('\$baseUrl/api/orders'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'from_address': from,
        'to_address': to,
        'comment': comment,
        if (driverId != null) 'driver_id': driverId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    final response = await http.put(
      Uri.parse('\$baseUrl/api/orders/\$orderId/status'),
      headers: await _getHeaders(),
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  String _parseError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      return decoded['error'] ?? 'Unknown error';
    } catch (_) {
      return 'Error: \${response.statusCode}';
    }
  }
}
