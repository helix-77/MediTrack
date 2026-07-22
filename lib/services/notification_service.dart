import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/medicine.dart';
import '../logic/refill_calculator.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

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
        // Handle notification tap if needed
      },
    );
  }

  Future<void> scheduleMedicineNotifications(Medicine medicine) async {
    // Cancel existing notifications for this medicine using deterministic IDs based on medicine hash
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

      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'Dose Reminder: ${medicine.name}',
        'Time to take ${medicine.schedule.doseAmount} ${medicine.dosageForm ?? "unit(s)"} (${medicine.strength ?? ""})',
        _nextInstanceOfTime(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'dose_reminders',
            'Dose Reminders',
            channelDescription: 'Notifications for taking scheduled doses',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    // 2. Schedule Expiry Warning
    if (medicine.expiryDate != null) {
      final expiryNoticeDate = medicine.expiryDate!.subtract(const Duration(days: 30));
      if (expiryNoticeDate.isAfter(DateTime.now())) {
        final expiryId = baseId + 50;
        final scheduledTz = tz.TZDateTime.from(expiryNoticeDate, tz.local);

        await _notificationsPlugin.zonedSchedule(
          expiryId,
          'Expiry Alert: ${medicine.name}',
          'Your medicine ${medicine.name} will expire in 30 days.',
          scheduledTz,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'expiry_alerts',
              'Expiry Alerts',
              channelDescription: 'Notifications when medicine is nearing expiry',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }

    // 3. Schedule Refill Warning
    if (RefillCalculator.isRefillDue(medicine.quantityCurrent, medicine.schedule)) {
      final refillId = baseId + 80;
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
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  Future<void> cancelMedicineNotifications(String medicineId) async {
    final baseId = medicineId.hashCode.abs() % 100000;
    for (int i = 0; i < 100; i++) {
      await _notificationsPlugin.cancel(baseId + i);
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
}
