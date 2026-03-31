import 'package:app/features/expenses/domain/entities/receipt_scan_method.dart';

class GeminiScanSettingsEntity {
  const GeminiScanSettingsEntity({
    required this.hasApiKey,
    required this.preferredMethod,
    required this.hasAcknowledgedUsageNotice,
    this.maskedApiKey,
  });

  final bool hasApiKey;
  final String? maskedApiKey;
  final ReceiptScanMethod preferredMethod;
  final bool hasAcknowledgedUsageNotice;

  GeminiScanSettingsEntity copyWith({
    bool? hasApiKey,
    String? maskedApiKey,
    ReceiptScanMethod? preferredMethod,
    bool? hasAcknowledgedUsageNotice,
  }) {
    return GeminiScanSettingsEntity(
      hasApiKey: hasApiKey ?? this.hasApiKey,
      maskedApiKey: maskedApiKey ?? this.maskedApiKey,
      preferredMethod: preferredMethod ?? this.preferredMethod,
      hasAcknowledgedUsageNotice:
          hasAcknowledgedUsageNotice ?? this.hasAcknowledgedUsageNotice,
    );
  }
}
