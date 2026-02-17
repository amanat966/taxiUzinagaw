// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/locale_provider.dart';
import 'package:frontend/providers/order_provider.dart';
import 'package:frontend/screens/login_screen.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('App starts and shows LoginScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => OrderProvider()),
        ],
        child: const TaxiFleetApp(),
      ),
    );

    // Verify that the LoginScreen is shown.
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
