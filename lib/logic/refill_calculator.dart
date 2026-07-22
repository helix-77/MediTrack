import '../models/medicine_schedule.dart';

class RefillCalculator {
  static int dailyDoseUnits(MedicineSchedule schedule) {
    return schedule.doseAmount * schedule.timesPerDay;
  }

  static int daysRemaining(int quantityCurrent, MedicineSchedule schedule) {
    final daily = dailyDoseUnits(schedule);
    if (daily <= 0) return 0;
    return (quantityCurrent / daily).floor();
  }

  static bool isRefillDue(
    int quantityCurrent,
    MedicineSchedule schedule, {
    int alertDaysBefore = 3,
  }) {
    final remaining = daysRemaining(quantityCurrent, schedule);
    return remaining <= alertDaysBefore;
  }

  static bool isLowStock(int quantityCurrent, int lowStockThreshold) {
    return quantityCurrent <= lowStockThreshold;
  }

  static bool isExpiringSoon(
    DateTime? expiryDate, {
    DateTime? currentDate,
    int alertDaysBefore = 30,
  }) {
    if (expiryDate == null) return false;
    final today = currentDate ?? DateTime.now();
    final difference = expiryDate.difference(today).inDays;
    return difference <= alertDaysBefore;
  }
}
