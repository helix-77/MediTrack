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

  /// Formats a list of weekday numbers (1 = Mon, 7 = Sun) into readable string ("Everyday", "Weekdays", "Mon, Wed, Fri").
  static String formatDaysOfWeek(List<int> days) {
    if (days.isEmpty) return 'No days selected';
    if (days.length == 7) return 'Everyday';
    if (days.length == 5 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5)) {
      return 'Weekdays (Mon-Fri)';
    }
    if (days.length == 2 && days.contains(6) && days.contains(7)) {
      return 'Weekends (Sat-Sun)';
    }

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = List<int>.from(days)..sort();
    return sorted
        .map((d) => (d >= 1 && d <= 7) ? dayNames[d - 1] : '')
        .where((s) => s.isNotEmpty)
        .join(', ');
  }
}
