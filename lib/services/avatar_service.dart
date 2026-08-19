import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvatarNotifier extends ChangeNotifier {
  static const String _avatarPrefKey = 'meditrack_user_avatar_path';
  String? _avatarPath;

  String? get avatarPath => _avatarPath;

  File? get avatarFile {
    if (_avatarPath == null) return null;
    final file = File(_avatarPath!);
    return file.existsSync() ? file : null;
  }

  AvatarNotifier() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_avatarPrefKey);
      if (path != null && File(path).existsSync()) {
        _avatarPath = path;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setAvatarPath(String path) async {
    _avatarPath = path;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarPrefKey, path);
    } catch (_) {}
  }

  Future<void> clearAvatar() async {
    _avatarPath = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_avatarPrefKey);
    } catch (_) {}
  }
}
