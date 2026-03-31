enum ReceiptScanMethod { local, gemini }

extension ReceiptScanMethodX on ReceiptScanMethod {
  String get label => switch (this) {
    ReceiptScanMethod.local => '本地 OCR',
    ReceiptScanMethod.gemini => 'Gemini',
  };
}
