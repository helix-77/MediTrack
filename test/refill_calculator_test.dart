import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/logic/refill_calculator.dart';
import 'package:meditrack/models/medicine_schedule.dart';

void main() {
  group('RefillCalculator Tests', () {
    final schedule = MedicineSchedule(
      doseAmount: 1,
      timesPerDay: 2,
      doseTimes: ['08:00', '20:00'],
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      startDate: DateTime(2026, 1, 1),
    );

    test('calculates dailyDoseUnits correctly', () {
      expect(RefillCalculator.dailyDoseUnits(schedule), equals(2));
    });

    test('calculates daysRemaining correctly', () {
      expect(RefillCalculator.daysRemaining(10, schedule), equals(5));
      expect(RefillCalculator.daysRemaining(1, schedule), equals(0));
      expect(RefillCalculator.daysRemaining(0, schedule), equals(0));
    });

    test('evaluates isRefillDue correctly', () {
      expect(RefillCalculator.isRefillDue(8, schedule, alertDaysBefore: 3), isFalse); // 4 days remaining
      expect(RefillCalculator.isRefillDue(6, schedule, alertDaysBefore: 3), isTrue);  // 3 days remaining <= 3
      expect(RefillCalculator.isRefillDue(0, schedule, alertDaysBefore: 3), isTrue);
    });

    test('evaluates isLowStock correctly', () {
      expect(RefillCalculator.isLowStock(10, 5), isFalse);
      expect(RefillCalculator.isLowStock(5, 5), isTrue);
      expect(RefillCalculator.isLowStock(2, 5), isTrue);
    });

    test('evaluates isExpiringSoon correctly', () {
      final now = DateTime(2026, 7, 23);
      final expiryFar = DateTime(2026, 9, 30);
      final expirySoon = DateTime(2026, 8, 10);
      final expired = DateTime(2026, 7, 20);

      expect(RefillCalculator.isExpiringSoon(expiryFar, currentDate: now, alertDaysBefore: 30), isFalse);
      expect(RefillCalculator.isExpiringSoon(expirySoon, currentDate: now, alertDaysBefore: 30), isTrue);
      expect(RefillCalculator.isExpiringSoon(expired, currentDate: now, alertDaysBefore: 30), isTrue);
      expect(RefillCalculator.isExpiringSoon(null, currentDate: now), isFalse);
    });
  });
}
