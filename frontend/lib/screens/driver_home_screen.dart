import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
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
    // 2GIS Deep Link
    // dgis://2gis.ru/routeSearch/rsType/car/from/.../to/...
    // Fallback to web
    // For MVP, simple web search or generic map intent
    // dgis:// routes are complex to construct without coords.
    // Using web url for simplicity: https://2gis.ru/routeSearch/rsType/car/from/{from}/to/{to}

    final url = Uri.parse(
      'https://2gis.ru/routeSearch/rsType/car/from/\$from/to/\$to',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      print('Could not launch \$url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final currentOrder = orderProvider.currentOrder;
    final queue = orderProvider.queuedOrders;

    return Scaffold(
      appBar: AppBar(
        title: Text('Driver: ${auth.user?['name'] ?? 'Unknown'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Toggle
          SwitchListTile(
            title: Text('Status: ${auth.user?['driver_status'] ?? 'unknown'}'),
            value: auth.user?['driver_status'] != 'offline',
            onChanged: (val) async {
              final newStatus = val ? 'free' : 'offline';
              try {
                await orderProvider.updateDriverStatus(newStatus);
                await auth.setDriverStatus(newStatus);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update status: $e')),
                  );
                }
              }
            },
          ),
          const Divider(),

          // Current Order
          if (currentOrder != null)
            Card(
              color: Colors.green[100],
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT ORDER',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('From: ${currentOrder['from_address']}'),
                    Text('To: ${currentOrder['to_address']}'),
                    Text('Comment: ${currentOrder['comment']}'),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (currentOrder['status'] == 'accepted')
                          ElevatedButton(
                            onPressed: () async {
                              try {
                                await orderProvider.updateOrderStatus(
                                  currentOrder['id'],
                                  'in_progress',
                                );
                                await auth.setDriverStatus('busy');
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                            child: const Text('Start Trip'),
                          ),
                        if (currentOrder['status'] == 'in_progress')
                          ElevatedButton(
                            onPressed: () async {
                              try {
                                await orderProvider.updateOrderStatus(
                                  currentOrder['id'],
                                  'done',
                                );
                                await auth.setDriverStatus('free');
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Finish'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.map),
                          onPressed: () => _openMap(
                            currentOrder['from_address'],
                            currentOrder['to_address'],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No active order. Waiting for assignments...'),
            ),

          const Divider(),

          // Queue
          Expanded(
            child: ListView.builder(
              itemCount: queue.length,
              itemBuilder: (ctx, i) {
                final order = queue[i];
                final from = order['from_address'];
                final to = order['to_address'];
                return ListTile(
                  title: Text('Queue: $from -> $to'),
                  subtitle: Text(order['comment'] ?? ''),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      try {
                        await orderProvider.updateOrderStatus(
                          order['id'],
                          'accepted',
                        );
                        // No driver status change needed immediately, or maybe 'busy' if we want to block them?
                        // Usually 'accepted' means they are on the way. Let's keep them as free/busy based on logic.
                        // For now, adhering to 'Start Trip' -> busy.
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: \$e')));
                        }
                      }
                    },
                    child: const Text('Accept'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
