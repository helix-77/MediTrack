import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';

class LocaleNotifier extends ChangeNotifier {
  static const String _prefKey = 'app_language';
  AppLanguage _currentLanguage = AppLanguage.english;

  AppLanguage get currentLanguage => _currentLanguage;
  bool get isBangla => _currentLanguage == AppLanguage.bangla;

  LocaleNotifier() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final langStr = prefs.getString(_prefKey);
      if (langStr == 'bangla') {
        _currentLanguage = AppLanguage.bangla;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language == AppLanguage.bangla ? 'bangla' : 'english');
    } catch (_) {}
  }

  String tr(String key) {
    return AppStrings.get(key, _currentLanguage);
  }
}
