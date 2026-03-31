import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/features/expenses/data/datasources/receipt_scan_datasource.dart';
import 'package:app/features/expenses/domain/entities/gemini_scan_extras_entity.dart';
import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

enum GeminiScanErrorCode {
  notAuthenticated,
  missingKey,
  invalidKey,
  quotaExceeded,
  timeout,
  payloadTooLarge,
  rateLimited,
  schemaInvalid,
  upstreamFailure,
}

class GeminiScanException implements Exception {
  const GeminiScanException(this.code, this.message);

  final GeminiScanErrorCode code;
  final String message;

  @override
  String toString() => message;
}

class GeminiReceiptScanDatasource {
  GeminiReceiptScanDatasource(this._client);

  static const _functionName = 'scan_receipt_gemini';
  static const _maxPayloadBytes = 5 * 1024 * 1024;

  /// Gemini token tiles are 768×768 px each. Constraining the longest side to
  /// 1024 px keeps usage to ~2 tiles (~516 tokens) which is sufficient for
  /// receipt text while minimising TPM consumption on free-tier keys.
  static const _maxLongEdge = 1024;

  final SupabaseClient _client;

  Future<ScanResultEntity> scanReceipt(
    File imageFile, {
    required String apiKey,
    OcrLanguage language = OcrLanguage.auto,
  }) async {
    final bytes = await imageFile.readAsBytes();

    // Compress first so that even large raw photos (common phone captures
    // can exceed 5 MB) are resized down before the size guard is applied.
    final compressedBytes = await _compressImage(bytes);

    if (compressedBytes.length > _maxPayloadBytes) {
      throw const GeminiScanException(
        GeminiScanErrorCode.payloadTooLarge,
        '圖片大小超過 Gemini 掃描上限，請重新選擇較小的圖片',
      );
    }

    final response = await _client.functions
        .invoke(
          _functionName,
          body: {
            'api_key': apiKey,
            'image_base64': base64Encode(compressedBytes),
            'mime_type': 'image/jpeg',
            'language_hint': language.name,
          },
        )
        .timeout(const Duration(seconds: 45));

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const GeminiScanException(
        GeminiScanErrorCode.schemaInvalid,
        'Gemini 掃描回傳格式不正確',
      );
    }

    final success = data['success'] == true;
    if (!success) {
      throw GeminiScanException(
        _parseErrorCode(data['error_code'] as String?),
        data['error'] as String? ?? 'Gemini 掃描失敗',
      );
    }

    final resultJson = data['result'];
    if (resultJson is! Map<String, dynamic>) {
      throw const GeminiScanException(
        GeminiScanErrorCode.schemaInvalid,
        'Gemini 掃描結果缺少必要欄位',
      );
    }

    final itemsJson = resultJson['items'];
    if (itemsJson is! List) {
      throw const GeminiScanException(
        GeminiScanErrorCode.schemaInvalid,
        'Gemini 掃描結果缺少品項資料',
      );
    }

    final items = itemsJson.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const GeminiScanException(
          GeminiScanErrorCode.schemaInvalid,
          'Gemini 掃描品項格式不正確',
        );
      }

      final name = (item['name'] as String?)?.trim() ?? '';
      final amount = item['amount'];
      if (name.isEmpty || amount is! num) {
        throw const GeminiScanException(
          GeminiScanErrorCode.schemaInvalid,
          'Gemini 掃描品項缺少必要欄位',
        );
      }

      return ScanResultItemEntity(
        name: name,
        amount: amount.toDouble(),
        quantity: (item['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (item['unit_price'] as num?)?.toDouble(),
        itemTaxAmount: (item['item_tax_amount'] as num?)?.toDouble(),
      );
    }).toList();

    final totalValue = resultJson['total'];
    if (totalValue is! num) {
      throw const GeminiScanException(
        GeminiScanErrorCode.schemaInvalid,
        'Gemini 掃描結果缺少總金額',
      );
    }

    return ScanResultEntity(
      items: items,
      total: totalValue.toDouble(),
      rawText: (resultJson['raw_text'] as String?) ?? '',
      lowConfidence: resultJson['low_confidence'] as bool? ?? false,
      geminiExtras: _parseExtras(resultJson),
    );
  }

  GeminiScanExtras _parseExtras(Map<String, dynamic> result) {
    final dateStr = result['date'] as String?;
    DateTime? date;
    if (dateStr != null) {
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {
        date = null;
      }
    }

    final taxTypeStr = result['tax_type'] as String?;
    final taxType = switch (taxTypeStr) {
      'included' => GeminiTaxType.included,
      'excluded' => GeminiTaxType.excluded,
      'exempt' => GeminiTaxType.exempt,
      _ => null,
    };

    final categoryStr = result['suggested_category'] as String?;
    final suggestedCategory = switch (categoryStr) {
      '餐飲' => GeminiSuggestedCategory.dining,
      '交通' => GeminiSuggestedCategory.transport,
      '購物' => GeminiSuggestedCategory.shopping,
      '住宿' => GeminiSuggestedCategory.accommodation,
      '娛樂' => GeminiSuggestedCategory.entertainment,
      '醫藥' => GeminiSuggestedCategory.medical,
      '其他' => GeminiSuggestedCategory.other,
      _ => null,
    };

    final merchant = result['merchant'] as String?;
    final currency = result['currency'] as String?;
    final taxAmountRaw = result['tax_amount'];

    return GeminiScanExtras(
      merchant: (merchant?.isNotEmpty ?? false) ? merchant : null,
      date: date,
      currency: (currency?.isNotEmpty ?? false) ? currency : null,
      taxAmount: taxAmountRaw is num ? taxAmountRaw.toDouble() : null,
      taxType: taxType,
      suggestedCategory: suggestedCategory,
    );
  }

  GeminiScanErrorCode _parseErrorCode(String? code) {
    return switch (code) {
      'not_authenticated' => GeminiScanErrorCode.notAuthenticated,
      'missing_key' => GeminiScanErrorCode.missingKey,
      'invalid_key' => GeminiScanErrorCode.invalidKey,
      'quota_exceeded' => GeminiScanErrorCode.quotaExceeded,
      'timeout' => GeminiScanErrorCode.timeout,
      'payload_too_large' => GeminiScanErrorCode.payloadTooLarge,
      'rate_limited' => GeminiScanErrorCode.rateLimited,
      'schema_invalid' => GeminiScanErrorCode.schemaInvalid,
      _ => GeminiScanErrorCode.upstreamFailure,
    };
  }

  /// Resizes image so the longest side is at most [_maxLongEdge] and
  /// re-encodes as JPEG. This keeps Gemini tile count low (fewer tokens)
  /// which reduces the chance of hitting free-tier TPM rate limits.
  Future<List<int>> _compressImage(List<int> bytes) async {
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) return bytes;

    final w = decoded.width;
    final h = decoded.height;
    final maxEdge = w > h ? w : h;

    final resized = maxEdge > _maxLongEdge
        ? img.copyResize(
            decoded,
            width: w > h ? _maxLongEdge : null,
            height: h >= w ? _maxLongEdge : null,
            interpolation: img.Interpolation.linear,
          )
        : decoded;

    return img.encodeJpg(resized, quality: 85);
  }
}
