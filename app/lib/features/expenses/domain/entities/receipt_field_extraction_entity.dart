import 'package:app/features/expenses/domain/entities/receipt_confidence_entity.dart';

class ReceiptTextFieldEntity {
  const ReceiptTextFieldEntity({
    required this.value,
    required this.rawText,
    required this.lineOrders,
    required this.confidence,
  });

  final String value;
  final String rawText;
  final List<int> lineOrders;
  final ReceiptConfidenceEntity confidence;
}

class ReceiptAmountFieldEntity {
  const ReceiptAmountFieldEntity({
    required this.value,
    required this.rawText,
    required this.lineOrders,
    required this.confidence,
  });

  final double value;
  final String rawText;
  final List<int> lineOrders;
  final ReceiptConfidenceEntity confidence;
}

class ReceiptExtractedLineItemEntity {
  const ReceiptExtractedLineItemEntity({
    required this.name,
    required this.amount,
    required this.lineOrders,
    required this.confidence,
    this.quantity = 1,
    this.unitPrice,
  });

  final String name;
  final double amount;
  final int quantity;
  final double? unitPrice;
  final List<int> lineOrders;
  final ReceiptConfidenceEntity confidence;
}

class ReceiptFieldExtractionEntity {
  const ReceiptFieldExtractionEntity({
    this.merchant,
    this.subtotal,
    this.tax,
    this.total,
    required this.documentConfidence,
    this.lineItems = const [],
  });

  final ReceiptTextFieldEntity? merchant;
  final ReceiptAmountFieldEntity? subtotal;
  final ReceiptAmountFieldEntity? tax;
  final ReceiptAmountFieldEntity? total;
  final ReceiptConfidenceEntity documentConfidence;
  final List<ReceiptExtractedLineItemEntity> lineItems;
}
