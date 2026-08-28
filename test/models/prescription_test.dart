import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/models/prescription.dart';

void main() {
  group('Prescription Model Tests', () {
    test('serializes and deserializes properly with familyMemberId', () {
      final date = DateTime(2026, 8, 20);
      final createdAt = DateTime(2026, 8, 20, 10, 30);

      final prescription = Prescription(
        id: 'rx-123',
        title: 'Cardiology Visit',
        doctorName: 'Dr. Rafiq',
        date: date,
        imageUrl: 'https://example.com/rx.jpg',
        extractedText: 'Napa Extra 500mg',
        notes: 'Take after meal',
        status: 'reviewed',
        familyMemberId: 'member-mother-01',
        createdAt: createdAt,
      );

      final map = prescription.toMap();
      expect(map['title'], 'Cardiology Visit');
      expect(map['doctorName'], 'Dr. Rafiq');
      expect(map['familyMemberId'], 'member-mother-01');
      expect(map['status'], 'reviewed');
      expect((map['date'] as Timestamp).toDate(), date);

      final fromMap = Prescription.fromMap(map, id: 'rx-123');
      expect(fromMap.id, 'rx-123');
      expect(fromMap.title, 'Cardiology Visit');
      expect(fromMap.doctorName, 'Dr. Rafiq');
      expect(fromMap.familyMemberId, 'member-mother-01');
      expect(fromMap.status, 'reviewed');
    });

    test('supports null familyMemberId for primary user (myself)', () {
      final now = DateTime.now();
      final prescription = Prescription(
        id: 'rx-456',
        title: 'Routine Checkup',
        date: now,
        extractedText: 'Vitamin D',
        createdAt: now,
      );

      final map = prescription.toMap();
      expect(map['familyMemberId'], isNull);

      final fromMap = Prescription.fromMap(map, id: 'rx-456');
      expect(fromMap.familyMemberId, isNull);
    });

    test('copyWith updates fields correctly', () {
      final now = DateTime.now();
      final rx = Prescription(
        id: 'rx-1',
        title: 'Original Title',
        date: now,
        extractedText: 'Ace 500mg',
        createdAt: now,
      );

      final updated = rx.copyWith(
        title: 'Updated Title',
        familyMemberId: 'member-father-02',
        status: 'reviewed',
      );

      expect(updated.id, 'rx-1');
      expect(updated.title, 'Updated Title');
      expect(updated.familyMemberId, 'member-father-02');
      expect(updated.status, 'reviewed');
    });
  });
}
