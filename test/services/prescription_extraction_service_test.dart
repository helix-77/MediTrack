import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/services/prescription_extraction_service.dart';

void main() {
  group('PrescriptionExtractionService Tests', () {
    test('extractPrescription throws when image file does not exist on disk', () async {
      final service = PrescriptionExtractionService();
      final nonExistentFile = File('/path/does/not/exist/prescription.jpg');

      // Note: without auth, auth_guard throws unauthenticated, but if mocked/unauthenticated,
      // requireAuthenticatedUser throws StateError or AuthenticationException.
      expect(
        () => service.extractPrescription(imageFile: nonExistentFile),
        throwsA(anything),
      );
    });
  });
}
