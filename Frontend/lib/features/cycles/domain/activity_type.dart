enum ActivityType {
  sowing('sowing'),
  fertilizing('fertilizing'),
  irrigation('irrigation'),
  weeding('weeding'),
  pesticide('pesticide'),
  harvest('harvest'),
  other('other');

  const ActivityType(this.code);

  final String code;

  static ActivityType fromCode(Object? value) {
    for (final ActivityType type in ActivityType.values) {
      if (type.code == value) {
        return type;
      }
    }
    return ActivityType.other;
  }
}
