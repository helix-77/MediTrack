import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/medicine.dart';
import '../logic/refill_calculator.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    // Configure device local timezone
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Could not set local location timezone: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification response/tap if needed
      },
    );

    // Create high-priority Android Notification Channels
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      const AndroidNotificationChannel doseChannel = AndroidNotificationChannel(
        'dose_reminders',
        'Dose Reminders',
        description: 'Notifications for taking scheduled medicine doses',
        importance: Importance.max,
        playSound: true,
      );

      const AndroidNotificationChannel expiryChannel = AndroidNotificationChannel(
        'expiry_alerts',
        'Expiry Alerts',
        description: 'Notifications when medicine is nearing expiration',
        importance: Importance.high,
      );

      const AndroidNotificationChannel refillChannel = AndroidNotificationChannel(
        'refill_alerts',
        'Refill Alerts',
        description: 'Notifications when medicine stock is running low',
        importance: Importance.high,
      );

      await androidImplementation.createNotificationChannel(doseChannel);
      await androidImplementation.createNotificationChannel(expiryChannel);
      await androidImplementation.createNotificationChannel(refillChannel);

      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  Future<void> scheduleMedicineNotifications(Medicine medicine) async {
    await init();

    final baseId = medicine.id.hashCode.abs() % 100000;
    await cancelMedicineNotifications(medicine.id);

    if (!medicine.schedule.active) return;

    // 1. Schedule Dose Reminders
    for (int i = 0; i < medicine.schedule.doseTimes.length; i++) {
      final timeStr = medicine.schedule.doseTimes[i];
      final parts = timeStr.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts[1]) ?? 0;

      final notificationId = baseId + i;
      final time12Hr = _format12Hour(hour, minute);

      await _safeZonedSchedule(
        id: notificationId,
        title: 'Dose Reminder: ${medicine.name}',
        body: 'Time for $time12Hr dose: Take ${medicine.schedule.doseAmount} ${medicine.dosageForm ?? "unit(s)"} (${medicine.strength ?? ""})',
        scheduledDate: _nextInstanceOfTime(hour, minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'dose_reminders',
            'Dose Reminders',
            channelDescription: 'Notifications for taking scheduled doses',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    // 2. Schedule Expiry Warning
    if (medicine.expiryDate != null) {
      final expiryNoticeDate = medicine.expiryDate!.subtract(const Duration(days: 30));
      if (expiryNoticeDate.isAfter(DateTime.now())) {
        final expiryId = baseId + 50;
        final scheduledTz = tz.TZDateTime.from(expiryNoticeDate, tz.local);

        await _safeZonedSchedule(
          id: expiryId,
          title: 'Expiry Alert: ${medicine.name}',
          body: 'Your medicine ${medicine.name} will expire in 30 days.',
          scheduledDate: scheduledTz,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'expiry_alerts',
              'Expiry Alerts',
              channelDescription: 'Notifications when medicine is nearing expiry',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      }
    }

    // 3. Schedule Refill Warning
    if (RefillCalculator.isRefillDue(medicine.quantityCurrent, medicine.schedule)) {
      final refillId = baseId + 80;
      try {
        await _notificationsPlugin.show(
          refillId,
          'Refill Alert: ${medicine.name}',
          'Low stock! You have ${medicine.quantityCurrent} remaining.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'refill_alerts',
              'Refill Alerts',
              channelDescription: 'Notifications when medicine stock is running low',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      } catch (_) {}
    }
  }

  Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (_) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchDateTimeComponents,
        );
      } catch (_) {}
    }
  }

  Future<void> cancelMedicineNotifications(String medicineId) async {
    final baseId = medicineId.hashCode.abs() % 100000;
    for (int i = 0; i < 100; i++) {
      try {
        await _notificationsPlugin.cancel(baseId + i);
      } catch (_) {}
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  String _format12Hour(int hour, int minute) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, hour, minute);
    return DateFormat('h:mm a').format(dt);
  }
}
