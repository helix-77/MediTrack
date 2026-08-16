import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/models/pharmacy.dart';
import 'package:meditrack/services/pdf_export_service.dart';
import 'package:meditrack/models/user_profile.dart';
import 'package:meditrack/models/medicine.dart';
import 'package:meditrack/models/medicine_schedule.dart';

void main() {
  group('Pharmacy Model Tests', () {
    test('serializes and deserializes properly from Map', () {
      final pharmacy = Pharmacy(
        id: 'pharmacy-1',
        name: 'Lazz Pharma (24 Hours)',
        address: 'Kalabagan, Dhaka',
        latitude: 23.750,
        longitude: 90.380,
        distanceMeters: 450,
        isOpen: true,
        rating: 4.8,
        phone: '01711223344',
      );

      final map = pharmacy.toMap();
      expect(map['name'], 'Lazz Pharma (24 Hours)');
      expect(map['distanceMeters'], 450);

      final fromMap = Pharmacy.fromMap(map);
      expect(fromMap.id, 'pharmacy-1');
      expect(fromMap.name, 'Lazz Pharma (24 Hours)');
      expect(fromMap.formattedDistance, '450 m');
    });

    test('formats kilometer distance correctly', () {
      final pharmacy = Pharmacy(
        id: 'pharmacy-2',
        name: 'Square Model Pharmacy',
        address: 'Panthapath, Dhaka',
        latitude: 23.752,
        longitude: 90.385,
        distanceMeters: 1450,
      );

      expect(pharmacy.formattedDistance, '1.5 km');
    });
  });

  group('Doctor Summary Report Tests', () {
    test('generates structured clinical summary with patient and meds', () {
      final profile = UserProfile(
        uid: 'user-1',
        displayName: 'Rahim Khan',
        email: 'rahim@example.com',
        bloodGroup: 'B+',
        allergies: 'Penicillin',
        doctorName: 'Dr. Hasan',
      );

      final med = Medicine(
        id: 'med-1',
        name: 'Napa Extra',
        strength: '500mg',
        dosageForm: 'tablet',
        quantityCurrent: 20,
        quantityTotal: 30,
        schedule: MedicineSchedule(
          doseAmount: 1,
          timesPerDay: 2,
          doseTimes: ['08:00', '20:00'],
          daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
          startDate: DateTime.now(),
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final report = PdfExportService.generateDoctorSummaryReport(
        profile: profile,
        medicines: [med],
        recentLogs: [],
      );

      expect(report, contains('Rahim Khan'));
      expect(report, contains('B+'));
      expect(report, contains('Penicillin'));
      expect(report, contains('Dr. Hasan'));
      expect(report, contains('Napa Extra'));
      expect(report, contains('500mg'));
    });
  });
}
