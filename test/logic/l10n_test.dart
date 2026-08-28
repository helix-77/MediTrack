import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/l10n/locale_notifier.dart';

void main() {
  group('Localization Tests', () {
    test('provides English and Bangla translations for key strings', () {
      expect(AppStrings.get('app_title', AppLanguage.english), 'MediTrack');
      expect(AppStrings.get('app_title', AppLanguage.bangla), 'মেডিট্র্যাক');

      expect(AppStrings.get('ongoing_routine', AppLanguage.english), 'Ongoing Routine');
      expect(AppStrings.get('ongoing_routine', AppLanguage.bangla), 'চলমান রুটিন');

      expect(AppStrings.get('take_now', AppLanguage.bangla), 'খেয়েছি');
    });

    test('falls back to key if string is missing', () {
      expect(AppStrings.get('untranslated_key', AppLanguage.english), 'untranslated_key');
      expect(AppStrings.get('untranslated_key', AppLanguage.bangla), 'untranslated_key');
    });

    test('LocaleNotifier switches and reports language', () {
      final notifier = LocaleNotifier();
      expect(notifier.currentLanguage, AppLanguage.english);
      expect(notifier.isBangla, isFalse);

      notifier.setLanguage(AppLanguage.bangla);
      expect(notifier.currentLanguage, AppLanguage.bangla);
      expect(notifier.isBangla, isTrue);
      expect(notifier.tr('app_title'), 'মেডিট্র্যাক');
    });
  });
}
