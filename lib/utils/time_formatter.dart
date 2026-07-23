import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeFormatter {
  /// Converts a 24-hour time string ("15:55", "08:00", "20:00") to a 12-hour formatted string ("3:55 PM", "8:00 AM", "8:00 PM").
  static String format24To12Hour(String time24) {
    if (time24.isEmpty) return time24;
    final parts = time24.split(':');
    if (parts.length != 2) return time24;

    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, hour, minute);
    return DateFormat('h:mm a').format(dt);
  }

  /// Formats a DateTime object into 12-hour format (e.g. "Thu, Jul 23 • 3:55 PM").
  static String formatDateTime12Hour(DateTime dateTime) {
    return DateFormat('EEE, MMM d • h:mm a').format(dateTime);
  }

  /// Converts TimeOfDay to 24-hour string format for backend storage ("15:55").
  static String timeOfDayTo24Hour(TimeOfDay time) {
    final hourStr = time.hour.toString().padLeft(2, '0');
    final minuteStr = time.minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr';
  }
}
