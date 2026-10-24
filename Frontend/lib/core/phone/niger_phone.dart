import 'dart:math';

import 'package:flutter/services.dart';

abstract final class NigerPhone {
  static final RegExp _localPattern = RegExp(r'^\d{8}$');
  static final RegExp _countryPattern = RegExp(r'^227\d{8}$');
  static final RegExp _plusCountryPattern = RegExp(r'^\+227\d{8}$');
  static final RegExp _doubleZeroPattern = RegExp(r'^00227\d{8}$');
  static final RegExp _ignoredChars = RegExp(r'[\s.\-]');

  static String? normalize(String input) {
    final String cleaned = input.trim().replaceAll(_ignoredChars, '');
    final String? local = _extractLocal(cleaned);
    if (local == null) {
      return null;
    }
    return '+227$local';
  }

  static bool isValid(String input) => normalize(input) != null;

  static String format(String input) {
    final String cleaned = input.trim().replaceAll(_ignoredChars, '');
    final String? local = _extractLocal(cleaned);
    if (local == null) {
      return input;
    }
    final List<String> groups = <String>[];
    for (int index = 0; index < local.length; index += 2) {
      groups.add(local.substring(index, min(index + 2, local.length)));
    }
    return groups.join(' ');
  }

  static String? _extractLocal(String cleaned) {
    if (_localPattern.hasMatch(cleaned)) {
      return cleaned;
    }
    if (_countryPattern.hasMatch(cleaned)) {
      return cleaned.substring(3);
    }
    if (_plusCountryPattern.hasMatch(cleaned)) {
      return cleaned.substring(4);
    }
    if (_doubleZeroPattern.hasMatch(cleaned)) {
      return cleaned.substring(5);
    }
    return null;
  }
}

class NigerPhoneInputFormatter extends TextInputFormatter {
  const NigerPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final String limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final List<String> groups = <String>[];
    for (int index = 0; index < limited.length; index += 2) {
      groups.add(limited.substring(index, min(index + 2, limited.length)));
    }
    final String text = groups.join(' ');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
