import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/order_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dispatcher_home_screen.dart';
import 'screens/driver_home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
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
    return Consumer2<LocaleProvider, AuthProvider>(
      builder: (context, localeProvider, auth, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Taxi Fleet',
          theme: AppTheme.lightTheme,
          locale: localeProvider.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ru'),
            Locale('kk'),
            Locale('en'),
          ],
          home: const AuthWrapper(),
        );
      },
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

    return const LoginScreen();
  }
}
