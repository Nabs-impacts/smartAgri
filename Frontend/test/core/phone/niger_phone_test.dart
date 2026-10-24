import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/phone/niger_phone.dart';

void main() {
  group('normalize', () {
    test('accepts eight digits', () {
      expect(NigerPhone.normalize('90203040'), '+22790203040');
    });

    test('ignores spaces, dots and dashes', () {
      expect(NigerPhone.normalize('90 20.30-40'), '+22790203040');
      expect(NigerPhone.normalize(' 90.20 30-40 '), '+22790203040');
    });

    test('accepts the three country prefixes', () {
      expect(NigerPhone.normalize('22790203040'), '+22790203040');
      expect(NigerPhone.normalize('+22790203040'), '+22790203040');
      expect(NigerPhone.normalize('0022790203040'), '+22790203040');
      expect(NigerPhone.normalize('+227 90 20 30 40'), '+22790203040');
    });

    test('rejects invalid values', () {
      expect(NigerPhone.normalize(''), isNull);
      expect(NigerPhone.normalize('9020304'), isNull);
      expect(NigerPhone.normalize('902030400'), isNull);
      expect(NigerPhone.normalize('2279020304'), isNull);
      expect(NigerPhone.normalize('+22890203040'), isNull);
      expect(NigerPhone.normalize('90 20 30 4a'), isNull);
      expect(NigerPhone.normalize('(90) 20 30 40'), isNull);
    });
  });

  test('isValid mirrors normalize', () {
    expect(NigerPhone.isValid('90 20 30 40'), isTrue);
    expect(NigerPhone.isValid('1234'), isFalse);
  });

  test('format groups the local number by two', () {
    expect(NigerPhone.format('90203040'), '90 20 30 40');
    expect(NigerPhone.format('+22790203040'), '90 20 30 40');
    expect(NigerPhone.format('invalide'), 'invalide');
  });

  group('NigerPhoneInputFormatter', () {
    const NigerPhoneInputFormatter formatter = NigerPhoneInputFormatter();

    TextEditingValue apply(String text) {
      return formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: text),
      );
    }

    test('keeps digits only', () {
      expect(apply('90a20b30c40').text, '90 20 30 40');
    });

    test('groups digits by two while typing', () {
      expect(apply('9').text, '9');
      expect(apply('90').text, '90');
      expect(apply('902').text, '90 2');
      expect(apply('9020').text, '90 20');
    });

    test('limits the input to eight digits', () {
      expect(apply('9020304099').text, '90 20 30 40');
      expect(apply('9020304099').selection.baseOffset, 11);
    });
  });
}
