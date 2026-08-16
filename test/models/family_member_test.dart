import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/models/family_member.dart';
import 'package:meditrack/models/user_profile.dart';

void main() {
  group('FamilyMember Model Tests', () {
    test('serializes and deserializes properly from Map', () {
      final now = DateTime(2026, 8, 15, 12, 0);
      final member = FamilyMember(
        id: 'member-123',
        displayName: 'Amma',
        createdAt: now,
      );

      final map = member.toMap();
      expect(map['displayName'], 'Amma');

      final fromMap = FamilyMember.fromMap(map, id: 'member-123');
      expect(fromMap.id, 'member-123');
      expect(fromMap.displayName, 'Amma');
    });
  });

  group('UserProfile Threshold Tests', () {
    test('initializes default reminder and stock thresholds', () {
      final profile = UserProfile(
        uid: 'user-1',
        displayName: 'Rahim',
        email: 'rahim@example.com',
      );

      expect(profile.refillAlertDaysBefore, 3);
      expect(profile.expiryAlertDaysBefore, 30);
      expect(profile.lowStockThreshold, 5);

      final map = profile.toMap();
      expect(map['refillAlertDaysBefore'], 3);
      expect(map['expiryAlertDaysBefore'], 30);
      expect(map['lowStockThreshold'], 5);
    });

    test('supports customized thresholds', () {
      final profile = UserProfile(
        uid: 'user-1',
        displayName: 'Rahim',
        email: 'rahim@example.com',
        refillAlertDaysBefore: 7,
        expiryAlertDaysBefore: 60,
        lowStockThreshold: 10,
      );

      expect(profile.refillAlertDaysBefore, 7);
      expect(profile.expiryAlertDaysBefore, 60);
      expect(profile.lowStockThreshold, 10);
    });
  });
}
