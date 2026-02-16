import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';

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

  void _showCreateOrderDialog(BuildContext context) {
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    int? selectedDriverId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Order'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fromCtrl,
                decoration: const InputDecoration(labelText: 'From'),
              ),
              TextField(
                controller: toCtrl,
                decoration: const InputDecoration(labelText: 'To'),
              ),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(labelText: 'Comment'),
              ),
              const SizedBox(height: 16),
              Consumer<OrderProvider>(
                builder: (ctx, provider, _) {
                  return DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Assign Driver (Optional)',
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...provider.drivers.map((d) {
                        final name = d['name'];
                        final status = d['driver_status'];
                        return DropdownMenuItem<int>(
                          value: d['id'],
                          child: Text('$name ($status)'),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await Provider.of<OrderProvider>(
                  context,
                  listen: false,
                ).createOrder(
                  fromCtrl.text,
                  toCtrl.text,
                  commentCtrl.text,
                  selectedDriverId,
                );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order created successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create order: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final provider = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatcher Dashboard'),
        actions: [
          IconButton(
            onPressed: () => _showCreateOrderDialog(context),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: [
          // Drivers List
          Expanded(
            flex: 2,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'DRIVERS',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.drivers.length,
                    itemBuilder: (ctx, i) {
                      final d = provider.drivers[i];
                      return ListTile(
                        leading: Icon(
                          Icons.drive_eta,
                          color: _getStatusColor(d['driver_status']),
                        ),
                        title: Text(d['name']),
                        subtitle: Text(d['driver_status']),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(),
          // Orders List
          Expanded(
            flex: 3,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'ACTIVE ORDERS',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.orders.length,
                    itemBuilder: (ctx, i) {
                      final o = provider.orders[i];
                      final from = o['from_address'];
                      final to = o['to_address'];
                      final status = o['status'];
                      final driverName = o['driver']?['name'] ?? 'Unassigned';

                      return Card(
                        margin: const EdgeInsets.all(4),
                        child: ListTile(
                          title: Text('$from -> $to'),
                          subtitle: Text(
                            'Status: $status | Driver: $driverName',
                          ),
                          trailing: o['status'] != 'cancelled'
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    try {
                                      await provider.updateOrderStatus(
                                        o['id'],
                                        'cancelled',
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Order cancelled'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to cancel order: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'free':
        return Colors.green;
      case 'busy':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
