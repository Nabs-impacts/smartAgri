enum ConsentType {
  terms('terms'),
  privacy('privacy'),
  dataSharingGov('data_sharing_gov'),
  research('research');

  const ConsentType(this.apiValue);

  final String apiValue;
}

class ConsentChoice {
  const ConsentChoice({required this.type, required this.accepted});

  final ConsentType type;
  final bool accepted;
}
