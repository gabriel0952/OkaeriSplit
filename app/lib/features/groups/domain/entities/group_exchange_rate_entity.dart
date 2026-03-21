class GroupExchangeRateEntity {
  const GroupExchangeRateEntity({
    required this.groupId,
    required this.currency,
    required this.rate,
  });

  final String groupId;
  final String currency;
  final double rate;
}
