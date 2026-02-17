import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _selectedIndex = 0;
  final Set<int> _driverAtPickupOrderIds = {};
  Set<int> _previousAssignedOrderIds = {};

  @override
  void initState() {
    super.initState();
    Provider.of<OrderProvider>(context, listen: false).startPolling();
  }

  @override
  void dispose() {
    Provider.of<OrderProvider>(context, listen: false).stopPolling();
    super.dispose();
  }

  void _openMap(String from, String to) async {
    // Кодируем адреса для URL
    final encodedFrom = Uri.encodeComponent(from);
    final encodedTo = Uri.encodeComponent(to);
    
    // Пробуем сначала открыть мобильное приложение 2ГИС через deep link
    final mobileUrl = Uri.parse('dgis://2gis.ru/route/$encodedFrom/$encodedTo');
    
    // Если мобильное приложение не установлено, используем веб-версию
    final webUrl = Uri.parse(
      'https://2gis.ru/routeSearch/rsType/car/from/$encodedFrom/to/$encodedTo',
    );
    
    // Пробуем открыть мобильное приложение
    if (await canLaunchUrl(mobileUrl)) {
      try {
        await launchUrl(mobileUrl, mode: LaunchMode.externalApplication);
        return;
      } catch (_) {
        // Если не получилось, пробуем веб-версию
      }
    }
    
    // Открываем веб-версию 2ГИС
    if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  /// Маршрут от текущего местоположения до точки назначения (2ГИС использует GPS)
  void _openMapFromCurrentLocation(String to) async {
    final encodedTo = Uri.encodeComponent(to);
    final mobileUrl = Uri.parse(
      'dgis://2gis.ru/routeSearch/rsType/car/to/$encodedTo',
    );
    final webUrl = Uri.parse(
      'https://2gis.ru/routeSearch/rsType/car/to/$encodedTo',
    );
    if (await canLaunchUrl(mobileUrl)) {
      try {
        await launchUrl(mobileUrl, mode: LaunchMode.externalApplication);
        return;
      } catch (_) {}
    }
    if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _launchCall(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.noPhoneToCall),
            backgroundColor: AppTheme.statusBusy,
          ),
        );
      }
      return;
    }
    final tel = digits.length == 10 ? '7$digits' : digits;
    final uri = Uri.parse('tel:$tel');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.noPhoneToCall),
          backgroundColor: AppTheme.statusBusy,
        ),
      );
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.changePassword),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.oldPassword,
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? l10n.requiredField : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.newPassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.requiredField;
                  if (v.length < 6) return l10n.minPasswordLength;
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ApiService().changePassword(oldCtrl.text, newCtrl.text);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.passwordChanged),
                      backgroundColor: AppTheme.statusFree,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$e'),
                      backgroundColor: AppTheme.statusBusy,
                    ),
                  );
                }
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final currentOrder = orderProvider.currentOrder;
    final queue = orderProvider.queuedOrders;

    // Уведомление водителю при назначении заказа (когда занят)
    final currentAssignedIds = queue.map((o) => o['id'] as int).toSet();
    if (auth.user?['driver_status'] == 'busy' &&
        currentAssignedIds.isNotEmpty &&
        currentAssignedIds.difference(_previousAssignedOrderIds).isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _previousAssignedOrderIds = currentAssignedIds;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.notifications_active, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.orderAssignedNotification)),
              ],
            ),
            content: Text(
              '${l10n.from}: ${queue.first['from_address']}\n${l10n.to}: ${queue.first['to_address']}',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedIndex = 1);
                },
                child: Text(l10n.accept),
              ),
            ],
          ),
        );
      });
    } else if (currentAssignedIds.isNotEmpty) {
      _previousAssignedOrderIds = currentAssignedIds;
    } else {
      _previousAssignedOrderIds = {};
    }

    final pages = [
      _HomeTab(
        auth: auth,
        orderProvider: orderProvider,
        currentOrder: currentOrder,
        queue: queue,
        openMap: _openMap,
        openMapFromCurrent: _openMapFromCurrentLocation,
        launchCall: _launchCall,
        driverAtPickupOrderIds: _driverAtPickupOrderIds,
        onAtLocation: (orderId) =>
            setState(() => _driverAtPickupOrderIds.add(orderId)),
      ),
      _QueueTab(queue: queue, orderProvider: orderProvider),
      _ProfileTab(
        auth: auth,
        onChangePassword: () => _showChangePasswordDialog(context),
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.driver}: ${auth.user?['name'] ?? '...'}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 2),
            _StatusBadge(status: auth.user?['driver_status'] ?? 'offline'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: Text(
                (auth.user?['name'] ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textSecondary,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: l10n.home,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.queue_outlined),
              activeIcon: const Icon(Icons.queue),
              label: l10n.queue,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: l10n.profile,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    String text;
    switch (status) {
      case 'free':
        color = AppTheme.statusFree;
        text = l10n.free;
        break;
      case 'busy':
        color = AppTheme.statusBusy;
        text = l10n.busy;
        break;
      default:
        color = AppTheme.statusOffline;
        text = l10n.offline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final AuthProvider auth;
  final OrderProvider orderProvider;
  final dynamic currentOrder;
  final List<dynamic> queue;
  final void Function(String, String) openMap;
  final void Function(String) openMapFromCurrent;
  final void Function(String) launchCall;
  final Set<int> driverAtPickupOrderIds;
  final void Function(int) onAtLocation;

  const _HomeTab({
    required this.auth,
    required this.orderProvider,
    required this.currentOrder,
    required this.queue,
    required this.openMap,
    required this.openMapFromCurrent,
    required this.launchCall,
    required this.driverAtPickupOrderIds,
    required this.onAtLocation,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    AppTheme.background,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.status,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            auth.user?['driver_status'] == 'offline'
                                ? l10n.offline
                                : l10n.free,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 1.1,
                      child: Switch(
                        value: auth.user?['driver_status'] != 'offline',
                        activeColor: AppTheme.statusFree,
                        activeTrackColor: AppTheme.statusFree.withOpacity(0.5),
                        inactiveThumbColor: AppTheme.statusOffline,
                        inactiveTrackColor: AppTheme.statusOffline.withOpacity(0.3),
                        onChanged: (val) async {
                          final newStatus = val ? 'free' : 'offline';
                          try {
                            await orderProvider.updateDriverStatus(newStatus);
                            await auth.setDriverStatus(newStatus);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$e'),
                                  backgroundColor: AppTheme.statusBusy,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (currentOrder != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.currentOrder,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primary.withOpacity(0.05),
                      AppTheme.primaryLight.withOpacity(0.02),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Адрес отправления
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.statusFree.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: AppTheme.statusFree,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.from,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    currentOrder['from_address'],
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Линия между адресами
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            const SizedBox(width: 19),
                            Container(
                              width: 2,
                              height: 20,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppTheme.primary.withOpacity(0.3),
                                    AppTheme.primary.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Адрес назначения
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.statusBusy.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.flag,
                                color: AppTheme.statusBusy,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.to,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    currentOrder['to_address'],
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if ((currentOrder['comment'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.accent.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.note_outlined,
                                color: AppTheme.accent,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.comment,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      currentOrder['comment'],
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Кнопка "Открыть в 2ГИС" — маршрут: местоположение→А (до "На месте"), А→Б (после)
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final fromAddr = currentOrder['from_address'];
                            final toAddr = currentOrder['to_address'];
                            final status = currentOrder['status'];
                            final orderId = currentOrder['id'] as int;
                            final isAtPickup = driverAtPickupOrderIds.contains(orderId);
                            if (status == 'accepted' && !isAtPickup) {
                              openMapFromCurrent(fromAddr);
                            } else {
                              openMap(fromAddr, toAddr);
                            }
                          },
                          icon: const Icon(Icons.map, size: 20),
                          label: Text(
                            l10n.openIn2GIS,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      // Кнопка "Позвонить" — клиент/пассажир
                      if ((currentOrder['client_phone'] ?? currentOrder['from_phone'] ?? currentOrder['phone'] ?? '').toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => launchCall(
                            (currentOrder['client_phone'] ?? currentOrder['from_phone'] ?? currentOrder['phone'] ?? '').toString(),
                          ),
                          icon: const Icon(Icons.phone, size: 20),
                          label: Text(l10n.call),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                      // Кнопка "На месте" — водитель прибыл в точку А
                      if (currentOrder['status'] == 'accepted' &&
                          !driverAtPickupOrderIds.contains(currentOrder['id'] as int)) ...[
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.accent),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => onAtLocation(currentOrder['id'] as int),
                            icon: const Icon(Icons.location_on, size: 20),
                            label: Text(l10n.atLocation),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: AppTheme.textPrimary,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (currentOrder['status'] == 'accepted' ||
                          currentOrder['status'] == 'in_progress') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (currentOrder['status'] == 'accepted')
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.successGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.statusFree.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      try {
                                        await orderProvider.updateOrderStatus(
                                          currentOrder['id'],
                                          'in_progress',
                                        );
                                        await auth.setDriverStatus('busy');
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(content: Text('$e')));
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.play_arrow, size: 20),
                                    label: Text(l10n.startTrip),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (currentOrder['status'] == 'in_progress')
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.statusBusy,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.statusBusy.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      try {
                                        await orderProvider.updateOrderStatus(
                                          currentOrder['id'],
                                          'done',
                                        );
                                        await auth.setDriverStatus('free');
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(content: Text('$e')));
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.check, size: 20),
                                    label: Text(l10n.finishTrip),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noActiveOrder,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QueueTab extends StatelessWidget {
  final List<dynamic> queue;
  final OrderProvider orderProvider;

  const _QueueTab({
    required this.queue,
    required this.orderProvider,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue_music, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              l10n.noOrders,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: queue.length,
      itemBuilder: (ctx, i) {
        final order = queue[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text('${order['from_address']} → ${order['to_address']}'),
            subtitle: Text(order['comment'] ?? ''),
            trailing: SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await orderProvider.updateOrderStatus(
                      order['id'],
                      'accepted',
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                child: Text(l10n.accept),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final AuthProvider auth;
  final VoidCallback onChangePassword;

  const _ProfileTab({
    required this.auth,
    required this.onChangePassword,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = auth.user?['name'] ?? '...';
    final phone = auth.user?['phone'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.2),
                    radius: 48,
                    child: Text(
                      name.isNotEmpty
                          ? name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: Text(l10n.changePassword),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onChangePassword,
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppTheme.statusBusy),
                  title: Text(
                    l10n.logout,
                    style: const TextStyle(
                      color: AppTheme.statusBusy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => auth.logout(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
