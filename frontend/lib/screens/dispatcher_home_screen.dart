import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../providers/locale_provider.dart';

extension _OrderStatusLocalization on AppLocalizations {
  String orderStatus(String status) {
    switch (status) {
      case 'new':
        return statusNew;
      case 'assigned':
        return statusAssigned;
      case 'accepted':
        return statusAccepted;
      case 'in_progress':
        return statusInProgress;
      case 'done':
        return statusDone;
      case 'cancelled':
        return statusCancelled;
      default:
        return status;
    }
  }

  String driverStatus(String status) {
    switch (status) {
      case 'free':
        return free;
      case 'busy':
        return busy;
      default:
        return offline;
    }
  }
}

class DispatcherHomeScreen extends StatefulWidget {
  const DispatcherHomeScreen({super.key});

  @override
  State<DispatcherHomeScreen> createState() => _DispatcherHomeScreenState();
}

class _DispatcherHomeScreenState extends State<DispatcherHomeScreen> {
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

  void _showAddDriverSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    const phoneMask = MaskTextInputFormatter(
      mask: '+7 (###) ###-##-##',
      filter: {'#': RegExp(r'[0-9]')},
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.addDriverFormTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.name,
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? l10n.requiredField : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [phoneMask],
                  decoration: InputDecoration(
                    labelText: l10n.phone,
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.requiredField;
                    final digits = v.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 10) return l10n.requiredField;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    prefixIcon: const Icon(Icons.lock),
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          try {
                            var phone = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                            if (phone.length == 10) phone = '7$phone';
                            await ApiService().createDriver(
                              nameCtrl.text,
                              phone,
                              passwordCtrl.text,
                            );
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              Provider.of<OrderProvider>(context, listen: false)
                                  .startPolling();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.driverCreated),
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDriverProfile(BuildContext context, Map<String, dynamic> driver) {
    final l10n = AppLocalizations.of(context)!;
    final name = driver['name'] ?? '';
    final status = driver['driver_status'] ?? 'offline';
    final statusStr = l10n.driverStatus(status);
    final ordersDone = driver['orders_done'] ?? 0;
    final ordersInProgress = driver['orders_in_progress'] ?? 0;
    final avatarUrl = driver['avatar_url'] as String?;

    Color statusColor;
    switch (status) {
      case 'free':
        statusColor = AppTheme.statusFree;
        break;
      case 'busy':
        statusColor = AppTheme.statusBusy;
        break;
      default:
        statusColor = AppTheme.statusOffline;
    }

    final initials = name.isNotEmpty
        ? name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join()
        : '?';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              radius: 48,
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? NetworkImage(avatarUrl)
                  : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Text(
                      initials.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusStr,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                  label: l10n.ordersCompleted,
                  value: ordersDone.toString(),
                  icon: Icons.check_circle,
                  color: AppTheme.statusFree,
                ),
                _StatChip(
                  label: l10n.ordersInProgress,
                  value: ordersInProgress.toString(),
                  icon: Icons.directions_car,
                  color: AppTheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignDriverDialog(
    BuildContext context,
    dynamic order,
    OrderProvider provider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    int? selectedDriverId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.assignDriverToOrder),
          content: DropdownButtonFormField<int>(
            decoration: InputDecoration(
              labelText: l10n.driver,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: provider.drivers
                .map<DropdownMenuItem<int>>((d) => DropdownMenuItem<int>(
                      value: d['id'],
                      child: Text(
                        '${d['name']} (${l10n.driverStatus(d['driver_status'] ?? 'offline')})',
                      ),
                    ))
                .toList(),
            onChanged: (val) => setState(() => selectedDriverId = val),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: selectedDriverId == null
                  ? null
                  : () async {
                      try {
                        await provider.assignOrderDriver(
                          order['id'],
                          selectedDriverId!,
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.driverAssigned),
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
      ),
    );
  }

  void _showCreateOrderDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    int? selectedDriverId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.createOrder),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fromCtrl,
                decoration: InputDecoration(
                  labelText: l10n.from,
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: toCtrl,
                decoration: InputDecoration(
                  labelText: l10n.to,
                  prefixIcon: const Icon(Icons.flag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentCtrl,
                decoration: InputDecoration(
                  labelText: l10n.comment,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Consumer<OrderProvider>(
                builder: (ctx, provider, _) {
                  return DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: l10n.assignDriver,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Text(l10n.none),
                      ),
                      ...provider.drivers.map((d) {
                        final name = d['name'];
                        final status = d['driver_status'];
                        final l10n = AppLocalizations.of(context)!;
                        return DropdownMenuItem<int>(
                          value: d['id'],
                          child: Text(
                            '$name (${l10n.driverStatus(status ?? 'offline')})',
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) => selectedDriverId = val,
                  );
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
              try {
                await Provider.of<OrderProvider>(context, listen: false)
                    .createOrder(
                  fromCtrl.text,
                  toCtrl.text,
                  commentCtrl.text,
                  selectedDriverId,
                );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.orderCreated),
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
            child: Text(l10n.createOrder),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = Provider.of<AuthProvider>(context);
    final provider = Provider.of<OrderProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(l10n.controlPanel),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.local_taxi, size: 48, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    l10n.appTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Provider.of<LocaleProvider>(context, listen: false)
                          .toggleLanguage();
                    },
                    icon: const Icon(Icons.language, color: Colors.white, size: 20),
                    label: Text(
                      Provider.of<LocaleProvider>(context).currentLanguageName,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: Text(l10n.addDriver),
              onTap: () {
                Navigator.pop(context);
                _showAddDriverSheet(context);
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          provider.stopPolling();
          await Future.delayed(const Duration(milliseconds: 500));
          provider.startPolling();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.drivers,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.drivers.length,
                  itemBuilder: (ctx, i) {
                    final d = provider.drivers[i];
                    return GestureDetector(
                      onTap: () => _showDriverProfile(context, d),
                      child: _DriverCard(
                        name: d['name'] ?? '',
                        phone: d['phone'] ?? '',
                        status: d['driver_status'] ?? 'offline',
                        avatarUrl: d['avatar_url'] as String?,
                        l10n: l10n,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.activeOrders,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (provider.orders.isEmpty)
                _EmptyOrdersCard(message: l10n.noOrders)
              else
                ...provider.orders.map((o) => _OrderCard(
                      from: o['from_address'],
                      to: o['to_address'],
                      status: o['status'],
                      driverName: o['driver']?['name'] ?? l10n.none,
                      driverId: o['driver_id'],
                      order: o,
                      provider: provider,
                      l10n: l10n,
                      onAssignDriver: () =>
                          _showAssignDriverDialog(context, o, provider),
                      onCancel: o['status'] != 'cancelled'
                          ? () async {
                              try {
                                await provider.updateOrderStatus(
                                    o['id'], 'cancelled');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.orderCancelled),
                                      backgroundColor: AppTheme.statusOffline,
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
                            }
                          : null,
                    )),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrderDialog(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: Text(l10n.createOrder),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  final String name;
  final String phone;
  final String status;
  final String? avatarUrl;
  final AppLocalizations l10n;

  const _DriverCard({
    required this.name,
    required this.phone,
    required this.status,
    this.avatarUrl,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (status) {
      case 'free':
        statusColor = AppTheme.statusFree;
        break;
      case 'busy':
        statusColor = AppTheme.statusBusy;
        break;
      default:
        statusColor = AppTheme.statusOffline;
    }

    final initials = name.isNotEmpty
        ? name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join()
        : '?';
    final statusStr = l10n.driverStatus(status);
    final hasPhoto = avatarUrl != null && avatarUrl!.isNotEmpty;

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.2),
                    radius: 20,
                    backgroundImage: hasPhoto ? NetworkImage(avatarUrl!) : null,
                    child: hasPhoto
                        ? null
                        : Text(
                            initials.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondary,
                              fontSize: 16,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                statusStr,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                phone,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String from;
  final String to;
  final String status;
  final String driverName;
  final dynamic driverId;
  final dynamic order;
  final OrderProvider provider;
  final AppLocalizations l10n;
  final VoidCallback? onAssignDriver;
  final VoidCallback? onCancel;

  const _OrderCard({
    required this.from,
    required this.to,
    required this.status,
    required this.driverName,
    this.driverId,
    required this.order,
    required this.provider,
    required this.l10n,
    this.onAssignDriver,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final statusStr = l10n.orderStatus(status);
    final canAssign = driverId == null && status != 'cancelled';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: AppTheme.statusFree, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    from,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Container(
                width: 2,
                height: 20,
                color: AppTheme.primary.withOpacity(0.5),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.flag, color: AppTheme.statusBusy, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    to,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${l10n.driver}: $driverName | ${l10n.status}: $statusStr',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canAssign)
                  Tooltip(
                    message: l10n.assignDriverToOrder,
                    child: IconButton(
                      onPressed: onAssignDriver,
                      icon: const Icon(Icons.person_add, color: AppTheme.primary),
                    ),
                  ),
                if (onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.cancel, color: AppTheme.statusBusy),
                    onPressed: onCancel,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrdersCard extends StatelessWidget {
  final String message;

  const _EmptyOrdersCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
