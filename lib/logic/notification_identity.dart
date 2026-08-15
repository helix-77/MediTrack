import 'dart:convert';

int notificationIdFor(String medicineId, String kind, [int slot = 0]) {
  final bytes = utf8.encode('$medicineId:$kind:$slot');
  var hash = 2166136261;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 16777619) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

String doseEventIdFor({
  required String medicineId,
  required DateTime scheduledAt,
}) {
  final normalized = DateTime(
    scheduledAt.year,
    scheduledAt.month,
    scheduledAt.day,
    scheduledAt.hour,
    scheduledAt.minute,
  );
  final stamp = normalized.toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
  return '$medicineId-$stamp';
}
