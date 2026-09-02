import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';

export 'app_strings.dart';

class LocaleNotifier extends ChangeNotifier {
  static const String _prefKey = 'app_language';
  AppLanguage _currentLanguage = AppLanguage.english;

  AppLanguage get currentLanguage => _currentLanguage;
  bool get isBangla => _currentLanguage == AppLanguage.bangla;
  Locale get locale => _currentLanguage == AppLanguage.bangla
      ? const Locale('bn', 'BD')
      : const Locale('en', 'US');

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
    if (_currentLanguage == language) return;
    _currentLanguage = language;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language == AppLanguage.bangla ? 'bangla' : 'english');
    } catch (_) {}
  }

  String tr(String key, [Map<String, String>? params]) {
    return AppStrings.get(key, _currentLanguage, params);
  }
}

extension LocalizationExtension on BuildContext {
  LocaleNotifier get localeNotifier {
    try {
      return watch<LocaleNotifier>();
    } catch (_) {
      return read<LocaleNotifier>();
    }
  }

  bool get isBangla {
    try {
      return watch<LocaleNotifier>().isBangla;
    } catch (_) {
      return read<LocaleNotifier>().isBangla;
    }
  }

  String tr(String key, [Map<String, String>? params]) {
    try {
      return watch<LocaleNotifier>().tr(key, params);
    } catch (_) {
      return read<LocaleNotifier>().tr(key, params);
    }
  }
}

extension StringLocalizationExtension on String {
  String tr(BuildContext context, [Map<String, String>? params]) =>
      context.tr(this, params);
}

