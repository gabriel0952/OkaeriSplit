import 'dart:io';
import 'dart:typed_data';

import 'package:app/core/services/gemma_model_manager.dart';
import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';
import 'package:app/features/expenses/domain/utils/receipt_parser.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:image/image.dart' as img;

class ReceiptScanDatasource {
  ReceiptScanDatasource(this._modelManager);

  final GemmaModelManager _modelManager;

  static const _maxImageDimension = 768;
  static const _inferenceTimeout = Duration(seconds: 60);

  static const _prompt = '''
Analyze this receipt image and extract the purchase information.
Return ONLY valid JSON with no explanation or markdown formatting.
Use this exact format:
{
  "total": <number>,
  "items": [
    {"name": "<item name>", "amount": <number>, "quantity": <integer>}
  ]
}

Rules:
- total: the grand total amount paid (number only, no currency symbols)
- items: list of purchased items only; do NOT include tax lines, subtotals, or the grand total as items
- name: the item name exactly as printed; preserve original language (Chinese/Japanese/English)
- amount: the total price for this line item (quantity x unit price)
- quantity: number of units purchased (use 1 if not shown)
- If the grand total is not visible, calculate it by summing the items
- If no items are recognizable, return an empty items array
''';

  Future<ScanResultEntity> scanReceipt(File imageFile) async {
    final model = await _modelManager.getReadyModel();
    try {
      final processedBytes = await _preprocessImage(imageFile);

      final chat = await model.createChat(
        temperature: 0.1,
        topK: 1,
        supportImage: true,
        modelType: ModelType.gemmaIt,
      );

      await chat.addQueryChunk(
        Message.withImage(
          text: _prompt,
          imageBytes: processedBytes,
          isUser: true,
        ),
      );

      final response = await chat
          .generateChatResponse()
          .timeout(_inferenceTimeout);

      final text = response is TextResponse ? response.token : '';
      return LlmReceiptParser.parse(text);
    } finally {
      await model.close();
    }
  }

  /// Resizes image to max [_maxImageDimension] on the longest side,
  /// corrects EXIF rotation, and re-encodes as JPEG.
  Future<Uint8List> _preprocessImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('無法解碼圖片');
    }

    final oriented = img.bakeOrientation(decoded);

    final resized = (oriented.width > _maxImageDimension ||
            oriented.height > _maxImageDimension)
        ? img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? _maxImageDimension : 0,
            height: oriented.height > oriented.width ? _maxImageDimension : 0,
          )
        : oriented;

    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }
}
