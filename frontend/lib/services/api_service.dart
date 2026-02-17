import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // localhost для Web на том же ПК, 192.168.x.x для телефона в локальной сети
  static const String baseUrl = 'http://127.0.0.1:8080';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Auth
  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
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
      Uri.parse('$baseUrl/auth/register'),
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
      Uri.parse('$baseUrl/api/drivers'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<void> createDriver(String name, String phone, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/drivers'),
      headers: await _getHeaders(),
      body: jsonEncode({'name': name, 'phone': phone, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/auth/change-password'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  Future<void> updateDriverStatus(String status) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/drivers/status'),
      headers: await _getHeaders(),
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  // Notifications
  Future<void> updateFcmToken(String token) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/users/fcm-token'),
      headers: await _getHeaders(),
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  // Profile
  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/profile'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
    String? avatarBase64,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (avatarBase64 != null) 'avatar_base64': avatarBase64,
    };

    final response = await http.put(
      Uri.parse('$baseUrl/api/profile'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(_parseError(response));
    }
  }

  // Orders
  Future<List<dynamic>> getOrders() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/orders'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<List<dynamic>> getOrderHistory() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/orders/history'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<Map<String, dynamic>> createOrder(
    String from,
    String to,
    String comment,
    double price,
    String clientName,
    String clientPhone,
    int? driverId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/orders'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'from_address': from,
        'to_address': to,
        'comment': comment,
        'price': price,
        'client_name': clientName,
        'client_phone': clientPhone,
        if (driverId != null) 'driver_id': driverId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
    
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> assignOrderDriver(dynamic orderId, int driverId) async {
    // Handle different types of orderId
    int id;
    if (orderId is int) {
      id = orderId;
    } else if (orderId is num) {
      id = orderId.toInt();
    } else if (orderId is String) {
      id = int.parse(orderId);
    } else {
      throw Exception('Invalid order ID type: ${orderId.runtimeType}');
    }
    
    final response = await http.put(
      Uri.parse('$baseUrl/api/orders/$id/assign'),
      headers: await _getHeaders(),
      body: jsonEncode({'driver_id': driverId}),
    );

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/orders/$orderId/status'),
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
      final errorMsg = decoded['error'] ?? 'Unknown error';
      return 'Error ${response.statusCode}: $errorMsg';
    } catch (_) {
      return 'Error ${response.statusCode}: ${response.body}';
    }
  }
}
