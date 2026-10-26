import 'auth_purpose.dart';

class OtpArgs {
  const OtpArgs({required this.phone, required this.purpose});

  final String phone;
  final AuthPurpose purpose;
}
