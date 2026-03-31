import 'package:app/features/expenses/domain/entities/gemini_scan_extras_entity.dart';
import 'package:app/features/expenses/domain/entities/receipt_document_entity.dart';
import 'package:app/features/expenses/domain/entities/receipt_field_extraction_entity.dart';

class ScanResultEntity {
  const ScanResultEntity({
    required this.items,
    required this.total,
    this.rawText = '',
    this.lowConfidence = false,
    this.document,
    this.extraction,
    this.geminiExtras,
  });

  final List<ScanResultItemEntity> items;
  final double total;
  final String rawText;
  final bool lowConfidence;
  final ReceiptDocumentEntity? document;
  final ReceiptFieldExtractionEntity? extraction;
  final GeminiScanExtras? geminiExtras;

  ScanResultEntity copyWith({
    List<ScanResultItemEntity>? items,
    double? total,
    String? rawText,
    bool? lowConfidence,
    ReceiptDocumentEntity? document,
    ReceiptFieldExtractionEntity? extraction,
    GeminiScanExtras? geminiExtras,
  }) {
    return ScanResultEntity(
      items: items ?? this.items,
      total: total ?? this.total,
      rawText: rawText ?? this.rawText,
      lowConfidence: lowConfidence ?? this.lowConfidence,
      document: document ?? this.document,
      extraction: extraction ?? this.extraction,
      geminiExtras: geminiExtras ?? this.geminiExtras,
    );
  }
}

class ScanResultItemEntity {
  const ScanResultItemEntity({
    required this.name,
    required this.amount,
    this.quantity = 1,
    this.unitPrice,
    this.itemTaxAmount,
  });

  final String name;
  final double amount;
  final int quantity;
  final double? unitPrice;

  /// Tax portion embedded in [amount] for 内税 (included) receipts.
  /// Null for 外税, 免税, or when Gemini could not determine per-item tax.
  final double? itemTaxAmount;

  ScanResultItemEntity copyWith({
    String? name,
    double? amount,
    int? quantity,
    double? unitPrice,
    double? itemTaxAmount,
  }) {
    return ScanResultItemEntity(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      itemTaxAmount: itemTaxAmount ?? this.itemTaxAmount,
    );
  }
}
