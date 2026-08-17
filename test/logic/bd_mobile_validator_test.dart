import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/logic/bd_mobile_validator.dart';

void main() {
  group('BdMobileValidator Tests', () {
    test('normalizes various mobile number formats', () {
      expect(BdMobileValidator.normalize('01812345678'), '01812345678');
      expect(BdMobileValidator.normalize('+8801812345678'), '01812345678');
      expect(BdMobileValidator.normalize('8801812345678'), '01812345678');
      expect(BdMobileValidator.normalize(' 018-1234 5678 '), '01812345678');
      expect(BdMobileValidator.normalize(''), '');
      expect(BdMobileValidator.normalize('12345'), '12345');
    });

    test('validates Robi (018) and Airtel (016) numbers', () {
      expect(BdMobileValidator.isValidRobiAirtel('01812345678'), isTrue);
      expect(BdMobileValidator.isValidRobiAirtel('01612345678'), isTrue);
      expect(BdMobileValidator.isValidRobiAirtel('+8801812345678'), isTrue);
      expect(BdMobileValidator.isValidRobiAirtel('8801612345678'), isTrue);

      // Other operators should fail Robi/Airtel check
      expect(BdMobileValidator.isValidRobiAirtel('01712345678'), isFalse); // GP
      expect(BdMobileValidator.isValidRobiAirtel('01912345678'), isFalse); // Banglalink
      expect(BdMobileValidator.isValidRobiAirtel('01512345678'), isFalse); // Teletalk
      expect(BdMobileValidator.isValidRobiAirtel('01312345678'), isFalse); // Skitto
      expect(BdMobileValidator.isValidRobiAirtel('01412345678'), isFalse);
      expect(BdMobileValidator.isValidRobiAirtel('01212345678'), isFalse);
    });

    test('validates operator name', () {
      expect(BdMobileValidator.getOperator('01812345678'), 'Robi');
      expect(BdMobileValidator.getOperator('01612345678'), 'Airtel');
      expect(BdMobileValidator.getOperator('01712345678'), 'Grameenphone');
      expect(BdMobileValidator.getOperator('01912345678'), 'Banglalink');
      expect(BdMobileValidator.getOperator('01512345678'), 'Teletalk');
      expect(BdMobileValidator.getOperator('invalid'), isNull);
    });

    test('masks mobile numbers for privacy', () {
      expect(BdMobileValidator.maskMobile('01812345678'), '018****5678');
      expect(BdMobileValidator.maskMobile('+8801612345678'), '016****5678');
      expect(BdMobileValidator.maskMobile('123'), '123');
    });

    test('returns user-friendly error messages', () {
      expect(BdMobileValidator.validateRobiAirtel(null), isNotNull);
      expect(BdMobileValidator.validateRobiAirtel(''), isNotNull);
      expect(BdMobileValidator.validateRobiAirtel('123'), isNotNull);
      expect(
        BdMobileValidator.validateRobiAirtel('01712345678'),
        contains('Robi (018) and Airtel (016)'),
      );
      expect(BdMobileValidator.validateRobiAirtel('01812345678'), isNull);
      expect(BdMobileValidator.validateRobiAirtel('01612345678'), isNull);
    });
  });
}
