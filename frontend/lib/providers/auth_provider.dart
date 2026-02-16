import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  AuthStatus _status = AuthStatus.unknown;
  Map<String, dynamic>? _user;

  AuthStatus get status => _status;
  Map<String, dynamic>? get user => _user;

  bool get isDispatcher => _user != null && _user!['role'] == 'dispatcher';
  bool get isDriver => _user != null && _user!['role'] == 'driver';

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userStr = prefs.getString('user');

    if (token != null && userStr != null) {
      _user = jsonDecode(userStr);
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> login(String phone, String password) async {
    try {
      final data = await _apiService.login(phone, password);
      _user = data['user'];
      _status = AuthStatus.authenticated;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(_user));

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> register(
    String name,
    String phone,
    String password,
    String role,
  ) async {
    try {
      await _apiService.register(name, phone, password, role);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> setDriverStatus(String status) async {
    if (_user != null) {
      _user!['driver_status'] = status;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(_user));
    }
  }
}
