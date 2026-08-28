import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/services/family_filter_notifier.dart';

void main() {
  group('FamilyFilterNotifier Tests', () {
    test('defaults to myself ("self")', () {
      final notifier = FamilyFilterNotifier();
      expect(notifier.selectedMemberId, 'self');
      expect(notifier.isSelf, isTrue);
      expect(notifier.currentFamilyMemberId, isNull);
    });

    test('selects a specific family member and notifies listeners', () {
      final notifier = FamilyFilterNotifier();
      bool notified = false;
      notifier.addListener(() => notified = true);

      notifier.selectMember('member-123');

      expect(notifier.selectedMemberId, 'member-123');
      expect(notifier.isSelf, isFalse);
      expect(notifier.currentFamilyMemberId, 'member-123');
      expect(notified, isTrue);
    });

    test('switching back to myself sets isSelf to true and currentFamilyMemberId to null', () {
      final notifier = FamilyFilterNotifier();
      notifier.selectMember('member-123');
      expect(notifier.isSelf, isFalse);

      notifier.selectSelf();
      expect(notifier.selectedMemberId, 'self');
      expect(notifier.isSelf, isTrue);
      expect(notifier.currentFamilyMemberId, isNull);
    });

    test('does not notify if selecting the already active member', () {
      final notifier = FamilyFilterNotifier();
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      notifier.selectSelf();
      expect(notifyCount, 0);

      notifier.selectMember('member-123');
      expect(notifyCount, 1);

      notifier.selectMember('member-123');
      expect(notifyCount, 1);
    });
  });
}
