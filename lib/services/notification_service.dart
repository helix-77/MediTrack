import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../logic/notification_identity.dart';
import '../logic/refill_calculator.dart';
import '../models/medicine.dart';
import '../models/user_profile.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  void Function(NotificationResponse response)? onNotificationTap;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (error) {
      debugPrint('Could not set local location timezone: $error');
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
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
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response);
      },
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'dose_reminders',
          'Dose Reminders',
          description: 'Notifications for taking scheduled medicine doses',
          importance: Importance.max,
          playSound: true,
        ),
      );
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'expiry_alerts',
          'Expiry Alerts',
          description: 'Notifications when medicine is nearing expiration',
          importance: Importance.high,
        ),
      );
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'refill_alerts',
          'Refill Alerts',
          description: 'Notifications when medicine stock is running low',
          importance: Importance.high,
        ),
      );
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  Future<void> scheduleMedicineNotifications(
    Medicine medicine, {
    UserProfile? profile,
  }) async {
    await init();
    await cancelMedicineNotifications(medicine.id);
    if (medicine.id.isEmpty || !medicine.schedule.active) return;

    final doseEnabled = profile?.enableDoseReminders ?? true;
    final expiryEnabled = profile?.enableExpiryAlerts ?? true;
    final refillEnabled = profile?.enableLowStockAlerts ?? true;

    if (doseEnabled) {
      for (var i = 0; i < medicine.schedule.doseTimes.length; i++) {
        final parts = medicine.schedule.doseTimes[i].split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null || hour > 23 || minute > 59) {
          continue;
        }

        await _safeZonedSchedule(
          id: notificationIdFor(medicine.id, 'dose', i),
          title: 'Dose Reminder: ${medicine.name}',
          body:
              'Time for ${_format12Hour(hour, minute)} dose: Take ${medicine.schedule.doseAmount} ${medicine.dosageForm ?? "unit(s)"} (${medicine.strength ?? ""})',
          payload: 'dose:${medicine.id}',
          scheduledDate: _nextInstanceOfTime(hour, minute),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'dose_reminders',
              'Dose Reminders',
              channelDescription:
                  'Notifications for taking scheduled medicine doses',
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
    }

    if (expiryEnabled && medicine.expiryDate != null) {
      final expiryNoticeDate = medicine.expiryDate!.subtract(
        const Duration(days: 30),
      );
      if (expiryNoticeDate.isAfter(DateTime.now())) {
        await _safeZonedSchedule(
          id: notificationIdFor(medicine.id, 'expiry'),
          title: 'Expiry Alert: ${medicine.name}',
          body: 'Your medicine ${medicine.name} will expire in 30 days.',
          payload: 'expiry:${medicine.id}',
          scheduledDate: tz.TZDateTime.from(expiryNoticeDate, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'expiry_alerts',
              'Expiry Alerts',
              channelDescription:
                  'Notifications when medicine is nearing expiry',
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

    if (refillEnabled &&
        (RefillCalculator.isLowStock(
              medicine.quantityCurrent,
              medicine.lowStockThreshold,
            ) ||
            RefillCalculator.isRefillDue(
              medicine.quantityCurrent,
              medicine.schedule,
            ))) {
      await _showRefillNotification(medicine);
    }
  }

  Future<void> _showRefillNotification(Medicine medicine) async {
    try {
      await _notificationsPlugin.show(
        id: notificationIdFor(medicine.id, 'refill'),
        title: 'Refill Alert: ${medicine.name}',
        body: 'Low stock! You have ${medicine.quantityCurrent} remaining.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'refill_alerts',
            'Refill Alerts',
            channelDescription:
                'Notifications when medicine stock is running low',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'refill:${medicine.id}',
      );
    } catch (_) {}
  }

  Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required String payload,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
    } catch (_) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: matchDateTimeComponents,
          payload: payload,
        );
      } catch (_) {}
    }
  }

  Future<void> cancelMedicineNotifications(String medicineId) async {
    if (medicineId.isEmpty) return;
    await init();
    for (final kind in ['dose', 'expiry', 'refill']) {
      for (var slot = 0; slot < 100; slot++) {
        try {
          await _notificationsPlugin.cancel(
            id: notificationIdFor(medicineId, kind, slot),
          );
        } catch (_) {}
      }
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
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
