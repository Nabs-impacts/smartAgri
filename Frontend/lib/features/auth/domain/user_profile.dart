class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.role,
    this.email,
    this.language,
  });

  final String id;
  final String phone;
  final String fullName;
  final String role;
  final String? email;
  final String? language;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      phone: json['phone'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      email: json['email'] as String?,
      language: json['language'] as String?,
    );
  }
}
