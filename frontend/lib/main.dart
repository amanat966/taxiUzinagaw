import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/order_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dispatcher_home_screen.dart';
import 'screens/driver_home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: const TaxiFleetApp(),
    ),
  );
}

class TaxiFleetApp extends StatelessWidget {
  const TaxiFleetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taxi Fleet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.status == AuthStatus.authenticated) {
      if (auth.isDispatcher) {
        return const DispatcherHomeScreen();
      } else if (auth.isDriver) {
        return const DriverHomeScreen();
      }
    }

    // Default or loading or login
    return const LoginScreen();
  }
}
