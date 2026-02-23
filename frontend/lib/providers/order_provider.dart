import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';

class OrderProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _drivers = [];
  List<dynamic> _orders = [];
  final Set<int> _arrivedAtPickupOrderIds = {};
  final Set<int> _onTheWayToPickupOrderIds = {};
  Timer? _pollingTimer;

  List<dynamic> get drivers => _drivers;
  List<dynamic> get orders => _orders;

  bool isArrivedAtPickup(dynamic orderId) {
    final id = _normalizeOrderId(orderId);
    if (id == null) return false;
    return _arrivedAtPickupOrderIds.contains(id);
  }

  void markArrivedAtPickup(dynamic orderId, {bool arrived = true}) {
    final id = _normalizeOrderId(orderId);
    if (id == null) return;
    if (arrived) {
      _arrivedAtPickupOrderIds.add(id);
    } else {
      _arrivedAtPickupOrderIds.remove(id);
    }
    notifyListeners();
  }

  bool isOnTheWayToPickup(dynamic orderId) {
    final id = _normalizeOrderId(orderId);
    if (id == null) return false;
    return _onTheWayToPickupOrderIds.contains(id);
  }

  void markOnTheWayToPickup(dynamic orderId, {bool onTheWay = true}) {
    final id = _normalizeOrderId(orderId);
    if (id == null) return;
    if (onTheWay) {
      _onTheWayToPickupOrderIds.add(id);
    } else {
      _onTheWayToPickupOrderIds.remove(id);
    }
    notifyListeners();
  }

  int? _normalizeOrderId(dynamic orderId) {
    if (orderId == null) return null;
    if (orderId is int) return orderId;
    if (orderId is num) return orderId.toInt();
    return int.tryParse(orderId.toString());
  }

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

  /// Заказ со статусом "назначен" (диспетчер назначил водителю, пока водитель может быть занят).
  dynamic get assignedOrderWhileBusy {
    try {
      return _orders.firstWhere((o) => o['status'] == 'assigned');
    } catch (_) {
      return null;
    }
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

      // Очистим локальные флаги для заказов, которых больше нет в списке
      final existingIds = _orders
          .map((o) => _normalizeOrderId(o['id']))
          .whereType<int>()
          .toSet();
      _arrivedAtPickupOrderIds
          .removeWhere((id) => !existingIds.contains(id));
      _onTheWayToPickupOrderIds
          .removeWhere((id) => !existingIds.contains(id));
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
    double price,
    String clientName,
    String clientPhone,
    int? driverId,
  ) async {
    final order = await _apiService.createOrder(
      from,
      to,
      comment,
      price,
      clientName,
      clientPhone,
      driverId,
    );
    await _fetchData();
    return order;
  }

  Future<void> updateDriverStatus(String status) async {
    await _apiService.updateDriverStatus(status);
    // Refresh might be needed?
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    await _apiService.updateOrderStatus(orderId, status);
    if (status == 'done' || status == 'cancelled') {
      _arrivedAtPickupOrderIds.remove(orderId);
      _onTheWayToPickupOrderIds.remove(orderId);
    }
    await _fetchData();
  }

  Future<void> assignOrderDriver(dynamic orderId, int driverId) async {
    await _apiService.assignOrderDriver(orderId, driverId);
    await _fetchData();
  }
}
