import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

String _formatMoneyKzt(dynamic v) {
  final n = (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
  final fmt = NumberFormat.decimalPattern();
  final value = (n % 1 == 0) ? fmt.format(n.toInt()) : NumberFormat('#,##0.##').format(n);
  return value;
}

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _selectedIndex = 0;
  final Set<int> _shownAssignedOrderIds = {};

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
    final safeFrom = from.trim();
    final safeTo = to.trim();
    if (safeTo.isEmpty) return;

    // 2GIS deeplink: if "from" is omitted, 2GIS uses current device location.
    // We use routeSearch format (works better than /route for our needs).
    final encodedFrom = Uri.encodeComponent(safeFrom);
    final encodedTo = Uri.encodeComponent(safeTo);

    final Uri mobileUrl = safeFrom.isEmpty
        ? Uri.parse('dgis://2gis.ru/routeSearch/rsType/car/to/$encodedTo')
        : Uri.parse('dgis://2gis.ru/routeSearch/rsType/car/from/$encodedFrom/to/$encodedTo');

    final Uri webUrl = safeFrom.isEmpty
        ? Uri.parse('https://2gis.ru/routeSearch/rsType/car/to/$encodedTo')
        : Uri.parse('https://2gis.ru/routeSearch/rsType/car/from/$encodedFrom/to/$encodedTo');

    try {
      await launchUrl(mobileUrl, mode: LaunchMode.externalApplication);
      return;
    } catch (_) {
      // fallback to web
    }

    try {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      // no-op
    }
  }

  Future<void> _callClient(String phone) async {
    final raw = phone.trim();
    if (raw.isEmpty) return;

    // Normalize phone for KZ/RU style inputs:
    // - 8XXXXXXXXXX -> 7XXXXXXXXXX
    // - XXXXXXXXXX  -> 7XXXXXXXXXX
    // - 7XXXXXXXXXX -> 7XXXXXXXXXX
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    if (digits.length == 11 && digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    } else if (digits.length == 10) {
      digits = '7$digits';
    }

    final telUri = Uri(scheme: 'tel', path: '+$digits');
    try {
      await launchUrl(telUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(telUri, mode: LaunchMode.platformDefault);
      } catch (_) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.callClient}: +$digits'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
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

  void _maybeShowAssignedOrderDialog(
    BuildContext context,
    AppLocalizations l10n,
    dynamic assignedOrder,
  ) {
    if (assignedOrder == null) return;
    final id = _normalizeOrderId(assignedOrder['id']);
    if (id == null || _shownAssignedOrderIds.contains(id)) return;
    _shownAssignedOrderIds.add(id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.assignedOrder),
          content: Text(
            '${assignedOrder['from_address'] ?? ''} → ${assignedOrder['to_address'] ?? ''}',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.accept),
            ),
          ],
        ),
      );
    });
  }

  int? _normalizeOrderId(dynamic orderId) {
    if (orderId == null) return null;
    if (orderId is int) return orderId;
    if (orderId is num) return orderId.toInt();
    return int.tryParse(orderId.toString());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final currentOrder = orderProvider.currentOrder;
    final assignedOrder = orderProvider.assignedOrderWhileBusy;
    final isBusy = (auth.user?['driver_status'] ?? '') == 'busy';
    if (isBusy && assignedOrder != null) {
      _maybeShowAssignedOrderDialog(context, l10n, assignedOrder);
    }

    final pages = [
      _HomeTab(
        auth: auth,
        orderProvider: orderProvider,
        currentOrder: currentOrder,
        openMap: _openMap,
        callClient: _callClient,
      ),
      _HistoryTab(orderProvider: orderProvider),
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
              icon: const Icon(Icons.history_outlined),
              activeIcon: const Icon(Icons.history),
              label: l10n.history,
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
  final void Function(String, String) openMap;
  final Future<void> Function(String) callClient;

  const _HomeTab({
    required this.auth,
    required this.orderProvider,
    required this.currentOrder,
    required this.openMap,
    required this.callClient,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DriverStatusSection(
              auth: auth,
              orderProvider: orderProvider,
            ),
            const SizedBox(height: 24),
            if (currentOrder != null)
              ...[
                TripCard(order: currentOrder),
                const SizedBox(height: 24),
                PriceSection(price: currentOrder['price']),
                const SizedBox(height: 24),
                ActionButtons(
                  status: (currentOrder['status'] ?? '').toString(),
                  phone: (currentOrder['client_phone'] ?? '').toString(),
                  onPrimaryPressed: () async {
                    try {
                      if (currentOrder['status'] == 'accepted') {
                        // If driver starts trip, assume pickup is reached.
                        orderProvider.markArrivedAtPickup(currentOrder['id'], arrived: true);
                        await orderProvider.updateOrderStatus(
                          currentOrder['id'],
                          'in_progress',
                        );
                        await auth.setDriverStatus('busy');
                      } else if (currentOrder['status'] == 'in_progress') {
                        await orderProvider.updateOrderStatus(
                          currentOrder['id'],
                          'done',
                        );
                        await auth.setDriverStatus('free');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                  showArrivedButton: (currentOrder['status'] == 'accepted') &&
                      !orderProvider.isArrivedAtPickup(currentOrder['id']),
                  onArrivedPressed: () =>
                      orderProvider.markArrivedAtPickup(currentOrder['id'], arrived: true),
                  onCallPressed: (currentOrder['client_phone'] ?? '')
                          .toString()
                          .isNotEmpty
                      ? () => callClient(
                            (currentOrder['client_phone'] ?? '').toString(),
                          )
                      : null,
                  onOpenMapPressed: () {
                    final from = (currentOrder['from_address'] ?? '').toString();
                    final to = (currentOrder['to_address'] ?? '').toString();
                    final status = (currentOrder['status'] ?? '').toString();
                    final arrived = orderProvider.isArrivedAtPickup(currentOrder['id']);
                    final effectiveArrived = arrived || status == 'in_progress';

                    // Before "На месте": current location -> A (pickup)
                    // After "На месте": A -> B
                    if (!effectiveArrived) {
                      openMap('', from);
                    } else {
                      openMap(from, to);
                    }
                  },
                ),
              ]
            else
              ..._NewOrdersSection.build(context, orderProvider, openMap),
          ],
        ),
      ),
    );
  }
}

/// Статус водителя (карточка вверху экрана)
class DriverStatusSection extends StatelessWidget {
  final AuthProvider auth;
  final OrderProvider orderProvider;

  const DriverStatusSection({
    super.key,
    required this.auth,
    required this.orderProvider,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      auth.user?['driver_status'] == 'offline'
                          ? l10n.offline
                          : l10n.free,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
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
    );
  }
}

/// Карточка маршрута и данных клиента
class TripCard extends StatelessWidget {
  final dynamic order;

  const TripCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final phone = (order['client_phone'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n.currentOrder,
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _AddressRow(
                  iconBackgroundColor: AppTheme.statusFree.withOpacity(0.15),
                  iconColor: AppTheme.statusFree,
                  icon: Icons.radio_button_checked,
                  label: l10n.from,
                  address: (order['from_address'] ?? '').toString(),
                ),
                const SizedBox(height: 20),
                _AddressRow(
                  iconBackgroundColor: AppTheme.statusBusy.withOpacity(0.15),
                  iconColor: AppTheme.statusBusy,
                  icon: Icons.flag,
                  label: l10n.to,
                  address: (order['to_address'] ?? '').toString(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (order['client_name'] ?? '').toString(),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (phone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                phone,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if ((order['comment'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.comment,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (order['comment'] ?? '').toString(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddressRow extends StatelessWidget {
  final Color iconBackgroundColor;
  final Color iconColor;
  final IconData icon;
  final String label;
  final String address;

  const _AddressRow({
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.icon,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: iconBackgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Блок с ценой
class PriceSection extends StatelessWidget {
  final dynamic price;

  const PriceSection({super.key, required this.price});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n.price,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatMoneyKzt(price)} ${l10n.currencyKzt}',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.statusFree,
          ),
        ),
      ],
    );
  }
}

/// Кнопки действий под заказом
class ActionButtons extends StatelessWidget {
  final String status;
  final String phone;
  final VoidCallback onPrimaryPressed;
  final VoidCallback? onArrivedPressed;
  final bool showArrivedButton;
  final VoidCallback? onCallPressed;
  final VoidCallback onOpenMapPressed;

  const ActionButtons({
    super.key,
    required this.status,
    required this.phone,
    required this.onPrimaryPressed,
    required this.onArrivedPressed,
    required this.showArrivedButton,
    required this.onCallPressed,
    required this.onOpenMapPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final bool canCall = phone.isNotEmpty && onCallPressed != null;
    final bool isAccepted = status == 'accepted';
    final bool isInProgress = status == 'in_progress';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showArrivedButton) ...[
          OutlinedButton.icon(
            onPressed: onArrivedPressed,
            icon: const Icon(Icons.place_outlined, size: 20),
            label: Text(l10n.arrived),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPrimaryPressed,
            icon: Icon(
              isAccepted ? Icons.play_arrow : Icons.check,
              size: 22,
            ),
            label: Text(
              isAccepted ? l10n.startTrip : l10n.finishTrip,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isInProgress ? Colors.red : null,
              foregroundColor: isInProgress ? Colors.white : null,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (canCall) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCallPressed,
                  icon: const Icon(Icons.phone_in_talk, size: 18),
                  label: Text(
                    l10n.callClient,
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOpenMapPressed,
                icon: Image.asset(
                  'assets/images/2gis.png',
                  width: 18,
                  height: 18,
                ),
                label: Text(
                  l10n.openIn2GIS,
                  style: const TextStyle(fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Секция со списком новых заказов (оставлена как вспомогательный helper)
class _NewOrdersSection {
  static List<Widget> build(
    BuildContext context,
    OrderProvider orderProvider,
    void Function(String, String) openMap,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final newOrders = orderProvider.orders
        .where((o) => o['status'] == 'new' || o['status'] == 'assigned')
        .toList();

    if (newOrders.isEmpty) {
      return [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.newOrders,
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
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noNewOrders,
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
      ];
    }

    return [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.newOrders,
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
      Column(
        children: newOrders
            .map(
              (o) => _NewOrderCard(
                order: o,
                l10n: l10n,
                onOpenMap: () => openMap(
                  o['from_address'],
                  o['to_address'],
                ),
                onAccept: () async {
                  try {
                    await orderProvider.updateOrderStatus(
                      o['id'],
                      'accepted',
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  }
                },
              ),
            )
            .toList(),
      ),
    ];
  }
}

class _HistoryTab extends StatefulWidget {
  final OrderProvider orderProvider;

  const _HistoryTab({required this.orderProvider});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  int _days = 7;
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getOrderHistory();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          );
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.noCompletedTrips,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }

        final now = DateTime.now();
        final endDay = DateTime(now.year, now.month, now.day);
        final startDay = endDay.subtract(Duration(days: _days - 1));

        final sums = <DateTime, double>{};
        for (var i = 0; i < _days; i++) {
          final d = startDay.add(Duration(days: i));
          sums[DateTime(d.year, d.month, d.day)] = 0.0;
        }

        for (final o in orders) {
          final price = (o['price'] as num?)?.toDouble() ?? 0.0;
          final dateStr = (o['updated_at'] ?? o['created_at'])?.toString();
          if (dateStr == null || dateStr.isEmpty) continue;
          DateTime dt;
          try {
            dt = DateTime.parse(dateStr).toLocal();
          } catch (_) {
            continue;
          }
          final day = DateTime(dt.year, dt.month, dt.day);
          if (day.isBefore(startDay) || day.isAfter(endDay)) continue;
          sums[day] = (sums[day] ?? 0.0) + price;
        }

        final daysList = sums.keys.toList()..sort();
        final values = daysList.map((d) => sums[d] ?? 0.0).toList();
        final maxY = values.isEmpty ? 0.0 : (values.reduce((a, b) => a > b ? a : b));

        // Ширина чарта должна быть конечной, иначе на Web получим
        // "BoxConstraints forces an infinite width".
        final barsCount = daysList.length;
        final barWidth = _days == 7 ? 20.0 : 10.0;
        final spacing = _days == 7 ? 16.0 : 10.0;
        final minWidth = 260.0;
        final chartWidth = barsCount <= 0
            ? minWidth
            : (barsCount * (barWidth + spacing)).clamp(minWidth, 600.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.earnings,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  ToggleButtons(
                    isSelected: [_days == 7, _days == 30],
                    onPressed: (idx) {
                      setState(() => _days = idx == 0 ? 7 : 30);
                    },
                    borderRadius: BorderRadius.circular(12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(l10n.last7Days),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(l10n.last30Days),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth,
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceBetween,
                          maxY: maxY <= 0 ? 1 : maxY * 1.2,
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= daysList.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final d = daysList[idx];
                                  final label = DateFormat(_days == 7 ? 'E' : 'd').format(d);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: List.generate(daysList.length, (i) {
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: values[i],
                                  color: AppTheme.primary,
                                  width: _days == 7 ? 20 : 10,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.completedTrips,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...orders.map((o) {
                final from = (o['from_address'] ?? '').toString();
                final to = (o['to_address'] ?? '').toString();
                final price = (o['price'] as num?)?.toDouble() ?? 0.0;
                final dateStr = (o['updated_at'] ?? o['created_at'])?.toString() ?? '';
                DateTime? dt;
                try {
                  dt = DateTime.parse(dateStr).toLocal();
                } catch (_) {}

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    title: Text(
                      '$from → $to',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: dt == null
                        ? null
                        : Text(
                            DateFormat('dd.MM.yyyy HH:mm').format(dt),
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                    trailing: Text(
                      '${_formatMoneyKzt(price)} ${l10n.currencyKzt}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _NewOrderCard extends StatelessWidget {
  final dynamic order;
  final AppLocalizations l10n;
  final VoidCallback onOpenMap;
  final VoidCallback onAccept;

  const _NewOrderCard({
    required this.order,
    required this.l10n,
    required this.onOpenMap,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final from = (order['from_address'] ?? '').toString();
    final to = (order['to_address'] ?? '').toString();
    final price = order['price'] ?? 0;
    final clientName = (order['client_name'] ?? '').toString();
    final clientPhone = (order['client_phone'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.18),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$from → $to',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_formatMoneyKzt(price)} ${l10n.currencyKzt}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
              if (clientName.isNotEmpty || clientPhone.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [clientName, clientPhone]
                            .where((s) => s.isNotEmpty)
                            .join(' • '),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: onOpenMap,
                  icon: Image.asset(
                    'assets/images/2gis.png',
                    width: 18,
                    height: 18,
                  ),
                  label: Text(l10n.openIn2GIS),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: onAccept,
                  child: Text(l10n.accept),
                ),
              ),
            ],
          ),
        ),
      ),
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
    final name = (auth.user?['name'] ?? '...').toString();
    final rawPhone = (auth.user?['phone'] ?? '').toString();
    final avatarUrl = (auth.user?['avatar_url'] as String?) ?? '';
    final resolvedAvatarUrl = avatarUrl.isEmpty
        ? null
        : (avatarUrl.startsWith('http') ? avatarUrl : '${ApiService.baseUrl}$avatarUrl');

    String formatKzPhone(String input) {
      final d = input.replaceAll(RegExp(r'\D'), '');
      if (d.isEmpty) return '';
      final ten = d.length == 11 && d.startsWith('7') ? d.substring(1) : d;
      if (ten.length != 10) return input;
      return '+7 (${ten.substring(0, 3)}) ${ten.substring(3, 6)}-${ten.substring(6, 8)}-${ten.substring(8, 10)}';
    }

    final phone = formatKzPhone(rawPhone);

    void openEditProfile() {
      final nameCtrl = TextEditingController(text: name == '...' ? '' : name);
      final phoneCtrl = TextEditingController(text: phone);
      final phoneMask = MaskTextInputFormatter(
        mask: '+7 (###) ###-##-##',
        filter: {'#': RegExp(r'[0-9]')},
      );
      final formKey = GlobalKey<FormState>();
      XFile? picked;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: StatefulBuilder(
              builder: (ctx, setState) => Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.profile,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.primary.withOpacity(0.12),
                          backgroundImage: picked != null
                              ? null
                              : (resolvedAvatarUrl != null ? NetworkImage(resolvedAvatarUrl) : null),
                          child: picked != null
                              ? const Icon(Icons.image, color: AppTheme.primary)
                              : (resolvedAvatarUrl == null
                                  ? Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    )
                                  : null),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final img = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 85,
                              );
                              if (img == null) return;
                              setState(() => picked = img);
                            },
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: Text(l10n.changePhoto),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.name,
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.requiredField : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [phoneMask],
                      decoration: InputDecoration(
                        labelText: l10n.phone,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return l10n.requiredField;
                        final digits = v.replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 11) return l10n.requiredField;
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        var digits = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                        if (digits.length == 10) digits = '7$digits';

                        String? avatarBase64;
                        if (picked != null) {
                          final bytes = await picked!.readAsBytes();
                          avatarBase64 = base64Encode(bytes);
                        }

                        try {
                          final updated = await ApiService().updateProfile(
                            name: nameCtrl.text.trim(),
                            phone: digits,
                            avatarBase64: avatarBase64,
                          );
                          await auth.setUser(updated);
                          if (context.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: Text(l10n.save),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppTheme.primary.withOpacity(0.12),
                    backgroundImage:
                        resolvedAvatarUrl != null ? NetworkImage(resolvedAvatarUrl) : null,
                    child: resolvedAvatarUrl == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: openEditProfile,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: l10n.editProfile,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.settings,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Consumer<LocaleProvider>(
                    builder: (context, localeProvider, _) {
                      final code = localeProvider.locale.languageCode;
                      final isSelected = [
                        code == 'ru',
                        code == 'kk',
                        code == 'en',
                      ];
                      return ToggleButtons(
                        isSelected: isSelected,
                        onPressed: (idx) {
                          if (idx == 0) localeProvider.setLocale(const Locale('ru'));
                          if (idx == 1) localeProvider.setLocale(const Locale('kk'));
                          if (idx == 2) localeProvider.setLocale(const Locale('en'));
                        },
                        borderRadius: BorderRadius.circular(14),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Text('Рус'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Text('Қаз'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Text('Eng'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline),
                    title: Text(l10n.changePassword),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onChangePassword,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => auth.logout(),
              icon: const Icon(Icons.logout),
              label: Text(l10n.logout),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.statusBusy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
