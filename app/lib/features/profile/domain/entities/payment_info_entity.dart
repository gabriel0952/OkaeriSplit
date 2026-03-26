class PaymentInfoEntity {
  const PaymentInfoEntity({
    required this.bankName,
    required this.bankCode,
    required this.accountNumber,
  });

  final String bankName;
  final String bankCode;
  final String accountNumber;
}
