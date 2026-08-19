import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RoutineSlotType {
  morning,
  noon,
  evening,
  night,
}

class RoutineScheduleNotifier extends ChangeNotifier {
  static const String _keyMorning = 'meditrack_schedule_morning_min';
  static const String _keyNoon = 'meditrack_schedule_noon_min';
  static const String _keyEvening = 'meditrack_schedule_evening_min';
  static const String _keyNight = 'meditrack_schedule_night_min';

  // Default start times in minutes from midnight (00:00)
  // 🌅 Morning: 05:00 AM - 11:29 AM -> Start at 05:00 AM
  // ☀️ Noon:    11:30 AM - 03:59 PM -> Start at 11:30 AM
  // 🌇 Evening: 04:00 PM - 07:59 PM -> Start at 04:00 PM (16:00)
  // 🌙 Night:   08:00 PM - 04:59 AM -> Start at 08:00 PM (20:00)
  static const int defaultMorningMinutes = 5 * 60; // 05:00 AM (300 min)
  static const int defaultNoonMinutes = 11 * 60 + 30; // 11:30 AM (690 min)
  static const int defaultEveningMinutes = 16 * 60; // 04:00 PM (960 min)
  static const int defaultNightMinutes = 20 * 60; // 08:00 PM (1200 min)

  int _morningMinutes = defaultMorningMinutes;
  int _noonMinutes = defaultNoonMinutes;
  int _eveningMinutes = defaultEveningMinutes;
  int _nightMinutes = defaultNightMinutes;

  int get morningMinutes => _morningMinutes;
  int get noonMinutes => _noonMinutes;
  int get eveningMinutes => _eveningMinutes;
  int get nightMinutes => _nightMinutes;

  TimeOfDay get morningStart => TimeOfDay(hour: _morningMinutes ~/ 60, minute: _morningMinutes % 60);
  TimeOfDay get noonStart => TimeOfDay(hour: _noonMinutes ~/ 60, minute: _noonMinutes % 60);
  TimeOfDay get eveningStart => TimeOfDay(hour: _eveningMinutes ~/ 60, minute: _eveningMinutes % 60);
  TimeOfDay get nightStart => TimeOfDay(hour: _nightMinutes ~/ 60, minute: _nightMinutes % 60);

  RoutineScheduleNotifier() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _morningMinutes = prefs.getInt(_keyMorning) ?? defaultMorningMinutes;
      _noonMinutes = prefs.getInt(_keyNoon) ?? defaultNoonMinutes;
      _eveningMinutes = prefs.getInt(_keyEvening) ?? defaultEveningMinutes;
      _nightMinutes = prefs.getInt(_keyNight) ?? defaultNightMinutes;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateSchedule({
    TimeOfDay? morning,
    TimeOfDay? noon,
    TimeOfDay? evening,
    TimeOfDay? night,
  }) async {
    if (morning != null) _morningMinutes = morning.hour * 60 + morning.minute;
    if (noon != null) _noonMinutes = noon.hour * 60 + noon.minute;
    if (evening != null) _eveningMinutes = evening.hour * 60 + evening.minute;
    if (night != null) _nightMinutes = night.hour * 60 + night.minute;

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyMorning, _morningMinutes);
      await prefs.setInt(_keyNoon, _noonMinutes);
      await prefs.setInt(_keyEvening, _eveningMinutes);
      await prefs.setInt(_keyNight, _nightMinutes);
    } catch (_) {}
  }

  Future<void> resetDefaults() async {
    _morningMinutes = defaultMorningMinutes;
    _noonMinutes = defaultNoonMinutes;
    _eveningMinutes = defaultEveningMinutes;
    _nightMinutes = defaultNightMinutes;

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyMorning);
      await prefs.remove(_keyNoon);
      await prefs.remove(_keyEvening);
      await prefs.remove(_keyNight);
    } catch (_) {}
  }

  String formatTimeOfDay(int totalMinutes) {
    final tod = TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
    final hourOfPeriod = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minuteStr = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hourOfPeriod:$minuteStr $period';
  }

  String formatEndTime(int nextMinutes) {
    var endMin = nextMinutes - 1;
    if (endMin < 0) endMin += 24 * 60;
    return formatTimeOfDay(endMin);
  }

  String getMorningRange() {
    return '${formatTimeOfDay(_morningMinutes)} - ${formatEndTime(_noonMinutes)}';
  }

  String getNoonRange() {
    return '${formatTimeOfDay(_noonMinutes)} - ${formatEndTime(_eveningMinutes)}';
  }

  String getEveningRange() {
    return '${formatTimeOfDay(_eveningMinutes)} - ${formatEndTime(_nightMinutes)}';
  }

  String getNightRange() {
    return '${formatTimeOfDay(_nightMinutes)} - ${formatEndTime(_morningMinutes)}';
  }

  RoutineSlotType getSlotForTime(String timeString) {
    final parts = timeString.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final currentMinutes = hour * 60 + minute;

    if (currentMinutes >= _morningMinutes && currentMinutes < _noonMinutes) {
      return RoutineSlotType.morning;
    } else if (currentMinutes >= _noonMinutes && currentMinutes < _eveningMinutes) {
      return RoutineSlotType.noon;
    } else if (currentMinutes >= _eveningMinutes && currentMinutes < _nightMinutes) {
      return RoutineSlotType.evening;
    } else {
      return RoutineSlotType.night;
    }
  }
}
