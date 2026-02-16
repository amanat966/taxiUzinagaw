import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider with ChangeNotifier {
  Locale _locale = const Locale('ru');
  static const String _key = 'app_locale';

  Locale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
    notifyListeners();
  }

  void toggleLanguage() {
    if (_locale.languageCode == 'ru') {
      setLocale(const Locale('kk'));
    } else if (_locale.languageCode == 'kk') {
      setLocale(const Locale('en'));
    } else {
      setLocale(const Locale('ru'));
    }
  }

  String get currentLanguageName {
    switch (_locale.languageCode) {
      case 'kk':
        return 'Қаз';
      case 'en':
        return 'EN';
      default:
        return 'RU';
    }
  }
}
