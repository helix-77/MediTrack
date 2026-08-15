import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/logic/notification_identity.dart';

void main() {
  test('notification IDs are stable for the same medicine slot', () {
    final first = notificationIdFor('medicine-123', 'dose', 0);
    final second = notificationIdFor('medicine-123', 'dose', 0);

    expect(first, second);
    expect(first, isNonZero);
  });

  test('notification IDs differ by kind and dose slot', () {
    expect(
      notificationIdFor('medicine-123', 'dose', 0),
      isNot(notificationIdFor('medicine-123', 'dose', 1)),
    );
    expect(
      notificationIdFor('medicine-123', 'dose'),
      isNot(notificationIdFor('medicine-123', 'refill')),
    );
  });

  test('dose event IDs normalize seconds for one scheduled slot', () {
    final first = doseEventIdFor(
      medicineId: 'medicine-123',
      scheduledAt: DateTime(2026, 8, 15, 8, 30, 1),
    );
    final second = doseEventIdFor(
      medicineId: 'medicine-123',
      scheduledAt: DateTime(2026, 8, 15, 8, 30, 59),
    );

    expect(first, second);
  });
}
