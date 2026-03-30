import 'dart:convert';

import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';

class ReceiptOcrExpectedLineItem {
  const ReceiptOcrExpectedLineItem({required this.name, required this.amount});

  factory ReceiptOcrExpectedLineItem.fromJson(Map<String, dynamic> json) {
    return ReceiptOcrExpectedLineItem(
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  final String name;
  final double amount;
}

class ReceiptOcrEvaluationSample {
  const ReceiptOcrEvaluationSample({
    required this.id,
    required this.ocrText,
    required this.expectedTotal,
    required this.expectedItems,
    this.tags = const [],
  });

  factory ReceiptOcrEvaluationSample.fromJson(Map<String, dynamic> json) {
    return ReceiptOcrEvaluationSample(
      id: json['id'] as String? ?? '',
      ocrText: json['ocrText'] as String? ?? '',
      expectedTotal: (json['expectedTotal'] as num?)?.toDouble() ?? 0,
      expectedItems: ((json['expectedItems'] as List?) ?? const [])
          .map(
            (item) => ReceiptOcrExpectedLineItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      tags: ((json['tags'] as List?) ?? const [])
          .map((tag) => tag.toString())
          .toList(),
    );
  }

  static List<ReceiptOcrEvaluationSample> listFromJson(String source) {
    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .map(
          (item) => ReceiptOcrEvaluationSample.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  final String id;
  final String ocrText;
  final double expectedTotal;
  final List<ReceiptOcrExpectedLineItem> expectedItems;
  final List<String> tags;
}

class ReceiptOcrSampleEvaluation {
  const ReceiptOcrSampleEvaluation({
    required this.sampleId,
    required this.expectedItemCount,
    required this.itemNameHits,
    required this.amountHits,
    required this.totalHit,
    required this.lowConfidence,
  });

  final String sampleId;
  final int expectedItemCount;
  final int itemNameHits;
  final int amountHits;
  final bool totalHit;
  final bool lowConfidence;

  double get itemNameHitRate =>
      expectedItemCount == 0 ? 1 : itemNameHits / expectedItemCount;

  double get amountHitRate =>
      expectedItemCount == 0 ? 1 : amountHits / expectedItemCount;
}

class ReceiptOcrEvaluationReport {
  const ReceiptOcrEvaluationReport({required this.samples});

  final List<ReceiptOcrSampleEvaluation> samples;

  int get sampleCount => samples.length;

  double get itemNameHitRate {
    final expected = samples.fold<int>(
      0,
      (sum, sample) => sum + sample.expectedItemCount,
    );
    if (expected == 0) return 1;
    final hits = samples.fold<int>(
      0,
      (sum, sample) => sum + sample.itemNameHits,
    );
    return hits / expected;
  }

  double get amountHitRate {
    final expected = samples.fold<int>(
      0,
      (sum, sample) => sum + sample.expectedItemCount,
    );
    if (expected == 0) return 1;
    final hits = samples.fold<int>(0, (sum, sample) => sum + sample.amountHits);
    return hits / expected;
  }

  double get totalHitRate {
    if (samples.isEmpty) return 1;
    final hits = samples.where((sample) => sample.totalHit).length;
    return hits / samples.length;
  }

  ReceiptOcrSampleEvaluation sampleById(String id) =>
      samples.firstWhere((sample) => sample.sampleId == id);
}

class ReceiptScanEvaluator {
  const ReceiptScanEvaluator();

  ReceiptOcrEvaluationReport evaluateSamples(
    List<ReceiptOcrEvaluationSample> samples, {
    required ScanResultEntity Function(String ocrText) parse,
  }) {
    return ReceiptOcrEvaluationReport(
      samples: [
        for (final sample in samples) _evaluateSample(sample, parse: parse),
      ],
    );
  }

  ReceiptOcrSampleEvaluation _evaluateSample(
    ReceiptOcrEvaluationSample sample, {
    required ScanResultEntity Function(String ocrText) parse,
  }) {
    final parsed = parse(sample.ocrText);
    final predictedNames = parsed.items
        .map((item) => _normalizeName(item.name))
        .toList();
    final expectedNames = sample.expectedItems
        .map((item) => _normalizeName(item.name))
        .toList();
    final itemNameHits = _countListHits(expectedNames, predictedNames);
    final amountHits = _countAmountHits(
      sample.expectedItems.map((item) => item.amount).toList(),
      parsed.items.map((item) => item.amount).toList(),
    );
    final totalHit = (parsed.total - sample.expectedTotal).abs() < 0.01;

    return ReceiptOcrSampleEvaluation(
      sampleId: sample.id,
      expectedItemCount: sample.expectedItems.length,
      itemNameHits: itemNameHits,
      amountHits: amountHits,
      totalHit: totalHit,
      lowConfidence: parsed.lowConfidence,
    );
  }

  int _countListHits(List<String> expected, List<String> predicted) {
    final remaining = [...predicted];
    var hits = 0;
    for (final item in expected) {
      final index = remaining.indexOf(item);
      if (index == -1) continue;
      hits++;
      remaining.removeAt(index);
    }
    return hits;
  }

  int _countAmountHits(List<double> expected, List<double> predicted) {
    final remaining = [...predicted];
    var hits = 0;
    for (final item in expected) {
      final index = remaining.indexWhere(
        (value) => (value - item).abs() < 0.01,
      );
      if (index == -1) continue;
      hits++;
      remaining.removeAt(index);
    }
    return hits;
  }

  String _normalizeName(String value) => value
      .replaceAll(RegExp(r'[^A-Za-z0-9\u4e00-\u9fff\u3040-\u30ff]+'), '')
      .toLowerCase();
}
