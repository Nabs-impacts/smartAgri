enum AuthPurpose {
  login('login'),
  verifyPhone('verify_phone'),
  resetPassword('reset_password');

  const AuthPurpose(this.apiValue);

  final String apiValue;
}
