class ScanResultEntity {
  const ScanResultEntity({
    required this.items,
    required this.total,
    this.rawText = '',
  });

  final List<ScanResultItemEntity> items;
  final double total;
  final String rawText;

  ScanResultEntity copyWith({
    List<ScanResultItemEntity>? items,
    double? total,
    String? rawText,
  }) {
    return ScanResultEntity(
      items: items ?? this.items,
      total: total ?? this.total,
      rawText: rawText ?? this.rawText,
    );
  }
}

class ScanResultItemEntity {
  const ScanResultItemEntity({
    required this.name,
    required this.amount,
    this.quantity = 1,
    this.unitPrice,
  });

  final String name;
  final double amount;
  final int quantity;
  final double? unitPrice;

  ScanResultItemEntity copyWith({
    String? name,
    double? amount,
    int? quantity,
    double? unitPrice,
  }) {
    return ScanResultItemEntity(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}
