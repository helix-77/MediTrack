import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/models/user_profile.dart';

void main() {
  group('UserProfile Model Tests', () {
    test('serializes and deserializes subscription and consent fields', () {
      final now = DateTime(2026, 8, 17, 12, 0, 0);
      final profile = UserProfile(
        uid: 'user-123',
        displayName: 'Test User',
        email: 'test@example.com',
        bdMobile: '01812345678',
        subscriptionStatus: 'REGISTERED',
        subscriptionVerifiedAt: now,
        subscriptionConsentVersion: '2026-08-v1',
        subscriptionConsentAt: now,
      );

      final map = profile.toMap();
      expect(map['uid'], 'user-123');
      expect(map['bdMobile'], '01812345678');
      expect(map['subscriptionStatus'], 'REGISTERED');
      expect(map['subscriptionVerifiedAt'], isA<Timestamp>());
      expect(map['subscriptionConsentVersion'], '2026-08-v1');
      expect(map['subscriptionConsentAt'], isA<Timestamp>());

      final deserialized = UserProfile.fromMap(map);
      expect(deserialized.uid, 'user-123');
      expect(deserialized.bdMobile, '01812345678');
      expect(deserialized.subscriptionStatus, 'REGISTERED');
      expect(deserialized.subscriptionConsentVersion, '2026-08-v1');
      expect(deserialized.subscriptionVerifiedAt?.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(deserialized.subscriptionConsentAt?.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('handles null subscription fields gracefully', () {
      final map = {
        'uid': 'user-456',
        'displayName': 'Guest User',
        'email': '',
      };

      final profile = UserProfile.fromMap(map);
      expect(profile.uid, 'user-456');
      expect(profile.subscriptionStatus, isNull);
      expect(profile.subscriptionVerifiedAt, isNull);
      expect(profile.subscriptionConsentVersion, isNull);
      expect(profile.subscriptionConsentAt, isNull);
    });
  });
}
