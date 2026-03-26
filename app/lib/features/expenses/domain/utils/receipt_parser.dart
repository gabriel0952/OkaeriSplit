import 'dart:convert';

import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';

/// Parses the JSON string returned by the Gemma3n LLM into a [ScanResultEntity].
///
/// Designed to be defensive against common LLM output quirks:
/// - Markdown code fences (```json ... ```)
/// - Stray text before/after the JSON object
/// - Numbers returned as strings
/// - Missing or null fields
abstract final class LlmReceiptParser {
  static ScanResultEntity parse(String llmResponse) {
    final cleaned = _stripCodeFences(llmResponse.trim());

    // Find the JSON object boundaries
    final jsonStart = cleaned.indexOf('{');
    final jsonEnd = cleaned.lastIndexOf('}');
    if (jsonStart == -1 || jsonEnd == -1 || jsonEnd <= jsonStart) {
      return ScanResultEntity(items: const [], total: 0, rawText: llmResponse);
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(cleaned.substring(jsonStart, jsonEnd + 1))
          as Map<String, dynamic>;
    } on FormatException {
      return ScanResultEntity(items: const [], total: 0, rawText: llmResponse);
    }

    final rawItems = (data['items'] as List<dynamic>?) ?? [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(_parseItem)
        .where((item) => item.name.isNotEmpty)
        .toList();

    final total = _toDouble(data['total']) ??
        items.fold<double>(0.0, (sum, item) => sum + item.amount);

    return ScanResultEntity(
      items: items,
      total: total,
      rawText: llmResponse,
    );
  }

  static ScanResultItemEntity _parseItem(Map<String, dynamic> map) {
    final name = (map['name'] as String?) ?? '';
    final amount = _toDouble(map['amount']) ?? 0.0;
    final quantity = (map['quantity'] as num?)?.toInt() ?? 1;
    final unitPrice = quantity > 1 ? amount / quantity : null;
    return ScanResultItemEntity(
      name: name,
      amount: amount,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String _stripCodeFences(String text) {
    return text
        .replaceFirst(RegExp(r'^```(?:json)?\s*\n?'), '')
        .replaceFirst(RegExp(r'\n?```\s*$'), '');
  }
}
