import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_service.dart';

class PushService {
  PushService._();

  static final PushService instance = PushService._();

  bool _initialized = false;
  StreamSubscription<String>? _tokenSub;

  bool get _isSupportedPlatform {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (!_isSupportedPlatform) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // iOS requires explicit permission; Android 13+ may prompt as well.
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Auto-register refreshed tokens.
      _tokenSub = messaging.onTokenRefresh.listen((token) async {
        try {
          await ApiService().updateFcmToken(token);
        } catch (e) {
          debugPrint('FCM token refresh update failed: $e');
        }
      });
    } catch (e) {
      debugPrint('PushService init failed: $e');
    }
  }

  Future<void> registerCurrentToken() async {
    await init();
    if (!_isSupportedPlatform) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await ApiService().updateFcmToken(token);
    } catch (e) {
      debugPrint('FCM token update failed: $e');
    }
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
  }
}

