import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/features/auth/domain/auth_purpose.dart';
import 'package:smartagri/features/auth/domain/auth_session.dart';
import 'package:smartagri/features/auth/domain/consent_choice.dart';
import 'package:smartagri/features/auth/domain/user_profile.dart';

void main() {
  test('parses a user profile', () {
    final UserProfile user = UserProfile.fromJson(<String, dynamic>{
      'id': '7f0a6a2e-0000-0000-0000-000000000001',
      'phone': '+22790203040',
      'full_name': 'Amina Diallo',
      'email': 'amina@example.com',
      'language': 'fr',
      'role': 'farmer',
    });

    expect(user.id, '7f0a6a2e-0000-0000-0000-000000000001');
    expect(user.phone, '+22790203040');
    expect(user.fullName, 'Amina Diallo');
    expect(user.email, 'amina@example.com');
    expect(user.language, 'fr');
    expect(user.role, 'farmer');
  });

  test('parses a user profile without optional fields', () {
    final UserProfile user = UserProfile.fromJson(<String, dynamic>{
      'id': 'id',
      'phone': '+22790203040',
      'full_name': 'Amina Diallo',
      'role': 'farmer',
      'email': null,
      'language': null,
    });

    expect(user.email, isNull);
    expect(user.language, isNull);
  });

  test('parses an auth session', () {
    final AuthSession session = AuthSession.fromJson(<String, dynamic>{
      'access_token': 'access',
      'refresh_token': 'refresh',
      'token_type': 'bearer',
      'expires_in': 1800,
      'user': <String, dynamic>{
        'id': 'id',
        'phone': '+22790203040',
        'full_name': 'Amina Diallo',
        'email': null,
        'language': 'ha',
        'role': 'farmer',
      },
    });

    expect(session.tokens.accessToken, 'access');
    expect(session.tokens.refreshToken, 'refresh');
    expect(session.tokenType, 'bearer');
    expect(session.user.fullName, 'Amina Diallo');
    expect(session.user.language, 'ha');
    expect(session.tokens.expiresAt.isAfter(DateTime.now()), isTrue);
  });

  test('exposes the api values of auth purposes', () {
    expect(AuthPurpose.login.apiValue, 'login');
    expect(AuthPurpose.verifyPhone.apiValue, 'verify_phone');
    expect(AuthPurpose.resetPassword.apiValue, 'reset_password');
  });

  test('exposes the api values of consent types', () {
    expect(ConsentType.terms.apiValue, 'terms');
    expect(ConsentType.privacy.apiValue, 'privacy');
    expect(ConsentType.dataSharingGov.apiValue, 'data_sharing_gov');
    expect(ConsentType.research.apiValue, 'research');
  });
}
