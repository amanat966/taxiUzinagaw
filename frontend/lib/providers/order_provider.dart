import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';

class OrderProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _drivers = [];
  List<dynamic> _orders = [];
  Timer? _pollingTimer;

  List<dynamic> get drivers => _drivers;
  List<dynamic> get orders => _orders;

  // Active order for driver
  dynamic get currentOrder {
    try {
      return _orders.firstWhere(
        (o) => o['status'] == 'in_progress' || o['status'] == 'accepted',
      );
    } catch (_) {
      return null;
    }
  }

  List<dynamic> get queuedOrders {
    return _orders.where((o) => o['status'] == 'assigned').toList();
  }

  void startPolling() {
    _fetchData();
    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _fetchData();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> _fetchData() async {
    try {
      // Depending on role, we might only need one of these
      // But for simplicity, let's try both safe calls or check role
      // Ideally pass role to this provider or check from AuthProvider
      // For MVP, we'll just try to fetch orders. Drivers might fail fetching drivers list.

      _orders = await _apiService.getOrders();
      notifyListeners();

      // Try fetching drivers (only works for dispatcher)
      try {
        _drivers = await _apiService.getDrivers();
        notifyListeners();
      } catch (_) {
        // Ignore if not dispatcher
      }
    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }

  Future<Map<String, dynamic>> createOrder(
    String from,
    String to,
    String comment,
    int? driverId,
  ) async {
    final order = await _apiService.createOrder(from, to, comment, driverId);
    await _fetchData();
    return order;
  }

  Future<void> updateDriverStatus(String status) async {
    await _apiService.updateDriverStatus(status);
    // Refresh might be needed?
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    await _apiService.updateOrderStatus(orderId, status);
    await _fetchData();
  }

  Future<void> assignOrderDriver(dynamic orderId, int driverId) async {
    await _apiService.assignOrderDriver(orderId, driverId);
    await _fetchData();
  }
}
