enum AppLanguage {
  fr('fr', 'FR'),
  ha('ha', 'HA'),
  dje('dje', 'ZA');

  const AppLanguage(this.apiCode, this.label);

  final String apiCode;
  final String label;
}
