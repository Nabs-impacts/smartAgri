enum HarvestQuality {
  a('A'),
  b('B'),
  c('C');

  const HarvestQuality(this.code);

  final String code;

  static HarvestQuality? fromCode(Object? value) {
    for (final HarvestQuality quality in HarvestQuality.values) {
      if (quality.code == value) {
        return quality;
      }
    }
    return null;
  }
}
