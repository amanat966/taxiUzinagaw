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
    final url = Uri.parse(
      'https://2gis.ru/routeSearch/rsType/car/from/$from/to/$to',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
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

    final pages = [
      _HomeTab(
        auth: auth,
        orderProvider: orderProvider,
        currentOrder: currentOrder,
        queue: queue,
        openMap: _openMap,
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
        title: Text('${l10n.driver}: ${auth.user?['name'] ?? '...'}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Center(
              child: _StatusBadge(status: auth.user?['driver_status'] ?? 'offline'),
            ),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: AppTheme.primary,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: l10n.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.queue),
            label: l10n.queue,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: l10n.profile,
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
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

  const _HomeTab({
    required this.auth,
    required this.orderProvider,
    required this.currentOrder,
    required this.queue,
    required this.openMap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: Text(l10n.status),
              subtitle: Text(
                auth.user?['driver_status'] == 'offline'
                    ? l10n.offline
                    : l10n.free,
              ),
              value: auth.user?['driver_status'] != 'offline',
              activeColor: AppTheme.statusFree,
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
                      ),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 24),

          if (currentOrder != null) ...[
            Text(
              l10n.currentOrder,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 4,
              color: AppTheme.statusFree.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: AppTheme.statusFree, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            currentOrder['from_address'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Column(
                        children: List.generate(
                          3,
                          (_) => Container(
                            width: 2,
                            height: 12,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: AppTheme.primary.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.flag,
                            color: AppTheme.statusBusy, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            currentOrder['to_address'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((currentOrder['comment'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${l10n.comment}: ${currentOrder['comment']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (currentOrder['status'] == 'accepted')
                          Expanded(
                            child: SizedBox(
                              height: 52,
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
                                icon: const Icon(Icons.play_arrow),
                                label: Text(l10n.startTrip),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.statusFree,
                                ),
                              ),
                            ),
                          ),
                        if (currentOrder['status'] == 'in_progress')
                          Expanded(
                            child: SizedBox(
                              height: 52,
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
                                icon: const Icon(Icons.check),
                                label: Text(l10n.finishTrip),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 52,
                          child: IconButton.filled(
                            onPressed: () => openMap(
                              currentOrder['from_address'],
                              currentOrder['to_address'],
                            ),
                            icon: const Icon(Icons.map),
                          ),
                        ),
                      ],
                    ),
                  ],
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
