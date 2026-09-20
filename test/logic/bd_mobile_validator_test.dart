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

    test('validates Robi (018) and Cirkle (016) numbers', () {
      expect(BdMobileValidator.isValidRobiCirkle('01812345678'), isTrue);
      expect(BdMobileValidator.isValidRobiCirkle('01612345678'), isTrue);
      expect(BdMobileValidator.isValidRobiCirkle('+8801812345678'), isTrue);
      expect(BdMobileValidator.isValidRobiCirkle('8801612345678'), isTrue);

      // Other operators should fail Robi/Cirkle check
      expect(BdMobileValidator.isValidRobiCirkle('01712345678'), isFalse); // GP
      expect(
        BdMobileValidator.isValidRobiCirkle('01912345678'),
        isFalse,
      ); // Banglalink
      expect(
        BdMobileValidator.isValidRobiCirkle('01512345678'),
        isFalse,
      ); // Teletalk
      expect(
        BdMobileValidator.isValidRobiCirkle('01312345678'),
        isFalse,
      ); // Skitto
      expect(BdMobileValidator.isValidRobiCirkle('01412345678'), isFalse);
      expect(BdMobileValidator.isValidRobiCirkle('01212345678'), isFalse);
    });

    test('validates operator name', () {
      expect(BdMobileValidator.getOperator('01812345678'), 'Robi');
      expect(BdMobileValidator.getOperator('01612345678'), 'Cirkle');
      expect(BdMobileValidator.getOperator('01712345678'), 'Grameenphone');
      expect(BdMobileValidator.getOperator('01912345678'), 'Banglalink');
      expect(BdMobileValidator.getOperator('01512345678'), 'Teletalk');
      expect(BdMobileValidator.getOperator('invalid'), isNull);
    });

    test('converts normalized numbers to international MSISDN', () {
      expect(BdMobileValidator.toInternational('01812345678'), '8801812345678');
      expect(
        BdMobileValidator.toInternational('+8801612345678'),
        '8801612345678',
      );
      expect(
        BdMobileValidator.toInternational('8801812345678'),
        '8801812345678',
      );
      expect(
        BdMobileValidator.toInternational('018-123 45678'),
        '8801812345678',
      );
      expect(BdMobileValidator.toInternational('12345'), '12345');
    });

    test('masks mobile numbers for privacy', () {
      expect(BdMobileValidator.maskMobile('01812345678'), '018****5678');
      expect(BdMobileValidator.maskMobile('+8801612345678'), '016****5678');
      expect(BdMobileValidator.maskMobile('123'), '123');
    });

    test('returns user-friendly error messages', () {
      expect(BdMobileValidator.validateRobiCirkle(null), isNotNull);
      expect(BdMobileValidator.validateRobiCirkle(''), isNotNull);
      expect(BdMobileValidator.validateRobiCirkle('123'), isNotNull);
      expect(
        BdMobileValidator.validateRobiCirkle('01712345678'),
        contains('Robi (018) and Cirkle (016)'),
      );
      expect(BdMobileValidator.validateRobiCirkle('01812345678'), isNull);
      expect(BdMobileValidator.validateRobiCirkle('01612345678'), isNull);
    });
  });
}
