import '../../auth/domain/user_profile.dart';

class Quota {
  const Quota({
    required this.metric,
    required this.limit,
    required this.used,
    required this.remaining,
  });

  final String metric;
  final int limit;
  final int used;
  final int remaining;

  bool get isUnlimited => limit < 0;

  factory Quota.fromJson(Map<String, dynamic> json) {
    return Quota(
      metric: json['metric'] as String? ?? '',
      limit: (json['limit'] as num?)?.toInt() ?? -1,
      used: (json['used'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    );
  }
}

class MePlan {
  const MePlan({
    required this.code,
    required this.name,
    required this.audience,
    required this.billingModel,
  });

  final String code;
  final String name;
  final String audience;
  final String billingModel;

  factory MePlan.fromJson(Map<String, dynamic> json) {
    return MePlan(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      audience: json['audience'] as String? ?? '',
      billingModel: json['billing_model'] as String? ?? '',
    );
  }
}

class MeData {
  const MeData({required this.user, required this.quotas, this.plan});

  final UserProfile user;
  final List<Quota> quotas;
  final MePlan? plan;

  factory MeData.fromJson(Map<String, dynamic> json) {
    final Object? user = json['user'];
    final Object? rawQuotas = json['quotas'];
    final Object? rawPlan = json['effective_plan'];
    return MeData(
      user: UserProfile.fromJson(
        user is Map ? Map<String, dynamic>.from(user) : <String, dynamic>{},
      ),
      quotas: rawQuotas is List
          ? rawQuotas
                .whereType<Map>()
                .map(
                  (Map item) => Quota.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : <Quota>[],
      plan: rawPlan is Map
          ? MePlan.fromJson(Map<String, dynamic>.from(rawPlan))
          : null,
    );
  }
}
