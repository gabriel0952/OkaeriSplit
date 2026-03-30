import 'dart:io';

import 'package:app/features/expenses/domain/entities/receipt_confidence_entity.dart';
import 'package:app/features/expenses/domain/entities/receipt_document_entity.dart';
import 'package:app/features/expenses/domain/entities/receipt_field_extraction_entity.dart';
import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

enum OcrLanguage { auto, chinese, japanese, english }

// ─── Token types (file-private) ──────────────────────────────────────────────

/// Price classification tier, ordered by reliability.
enum _PriceType { p3, p2, p2b, p1, p0, base }

class _NameToken {
  const _NameToken(
    this.text,
    this.lineIndex, {
    this.quantity = 1,
    this.unitPrice,
  });
  final String text;
  final int lineIndex;
  final int quantity;
  final double? unitPrice;
}

class _PriceToken {
  const _PriceToken(
    this.value,
    this.type,
    this.lineIndex, {
    this.isDiscount = false,
  });
  final double value;
  final _PriceType type;
  final int lineIndex;

  /// Whether the line immediately before this price was a discount/deduction.
  final bool isDiscount;

  /// Base confidence by price type.
  double get baseConf => switch (type) {
    _PriceType.p3 => 0.9,
    _PriceType.p2 => 0.7,
    _PriceType.p2b => 0.4,
    _PriceType.p1 => 0.5,
    _PriceType.p0 => 0.3,
    _PriceType.base => 0.5,
  };

  /// Score relative to a name at [nameLineIndex].
  /// Confidence decreases slightly the further the price is from the name.
  double scoreFor(int nameLineIndex) {
    final dist = lineIndex - nameLineIndex;
    final penalty = dist <= 0
        ? 0.0
        : dist <= 2
        ? 0.05
        : dist <= 4
        ? 0.1
        : 0.2;
    return baseConf - penalty;
  }
}

class _OcrCandidatePayload {
  const _OcrCandidatePayload({required this.text, required this.document});

  final String text;
  final ReceiptDocumentEntity document;
}

class _ReceiptLayoutRow {
  const _ReceiptLayoutRow({
    required this.text,
    required this.normalizedText,
    required this.lineOrders,
    required this.top,
    required this.left,
    required this.height,
  });

  final String text;
  final String normalizedText;
  final List<int> lineOrders;
  final double top;
  final double left;
  final double height;

  int get readingOrder => lineOrders.isEmpty ? 0 : lineOrders.first;
}

// ─── Datasource ──────────────────────────────────────────────────────────────

class ReceiptScanDatasource {
  ReceiptScanDatasource({
    Future<Map<String, String>> Function(File imageFile, OcrLanguage language)?
    ocrCandidatesLoader,
    Future<File> Function(File imageFile)? preprocessImageLoader,
  }) : _ocrCandidatesLoader = ocrCandidatesLoader,
       _preprocessImageLoader = preprocessImageLoader;

  static const _maxImageDimension = 1280;
  static const _ocrPassCount = 2;

  final Future<Map<String, String>> Function(
    File imageFile,
    OcrLanguage language,
  )?
  _ocrCandidatesLoader;
  final Future<File> Function(File imageFile)? _preprocessImageLoader;

  Future<ScanResultEntity> scanReceipt(
    File imageFile, {
    OcrLanguage language = OcrLanguage.auto,
  }) async {
    File? tempFile;
    try {
      final preprocessImageLoader = _preprocessImageLoader;
      tempFile = preprocessImageLoader != null
          ? await preprocessImageLoader(imageFile)
          : await _preprocessImageToFile(imageFile);

      final candidates = await _collectOcrCandidates(
        tempFile,
        language: language,
      );
      if (candidates.isEmpty) {
        final emptyResult = const ScanResultEntity(
          items: [],
          total: 0,
          lowConfidence: true,
        );
        _logScanResult(emptyResult);
        return emptyResult;
      }
      final bestEvaluation = _selectBestOcrEvaluation(candidates);
      final bestDocument =
          candidates[bestEvaluation.label]?.document ??
          _buildDocumentModelFromText(bestEvaluation.text);
      final extraction = _extractFields(bestDocument);

      debugPrint(
        '=== OCR OUTPUT (${bestEvaluation.label}) ===\n'
        '${bestEvaluation.text}\n'
        '==================',
      );

      final ruleResult = _mapExtractionToScanResult(
        extraction,
        fallbackResult: bestEvaluation.result,
        rawText: bestEvaluation.text,
        document: bestDocument,
      );
      _logScanResult(ruleResult);
      return ruleResult;
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<Map<String, _OcrCandidatePayload>> _collectOcrCandidates(
    File imageFile, {
    required OcrLanguage language,
  }) async {
    final ocrCandidatesLoader = _ocrCandidatesLoader;
    if (ocrCandidatesLoader != null) {
      final loaded = await ocrCandidatesLoader(imageFile, language);
      return {
        for (final entry in loaded.entries)
          entry.key: _OcrCandidatePayload(
            text: entry.value,
            document: _buildDocumentModelFromText(entry.value),
          ),
      };
    }

    if (Platform.isIOS) {
      return _collectVisionCandidates(imageFile, language: language);
    }
    if (Platform.isAndroid) {
      return _collectMlKitCandidates(imageFile, language: language);
    }
    throw UnsupportedError('目前僅支援 iOS 與 Android 裝置進行收據掃描');
  }

  void _logScanResult(ScanResultEntity result) {
    if (result.items.isEmpty) {
      debugPrint(
        '[ReceiptScan] rule-based found 0 items, returning lowConfidence',
      );
      return;
    }

    debugPrint(
      '[ReceiptScan] rule-based OK: ${result.items.length} items, '
      'total=${result.total}, lowConf=${result.lowConfidence}',
    );
    for (final item in result.items) {
      debugPrint(
        '[ReceiptScan]   "${item.name}" × ${item.quantity} = ${item.amount}',
      );
    }
  }

  // ─── Static patterns ─────────────────────────────────────────────────────

  static final _numPat = RegExp(
    r'\d{1,3}(?:[,，]\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?',
  );

  static final _cjkPat = RegExp(
    r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff\uff00-\uffef]',
  );

  static final _labelPat = RegExp(
    r'合計|總計|总计|小計|帳單|金額|消費税|税込|税額|免税|対象|お預り|お釣|現金|お支払|'
    r'支払|点数|ご請求額|お会計|QUICPay|登録番号|電話|TEL|http|www\.|'
    r'TAX FREE|TOTAL|SUBTOTAL|領収書|レシート|消耗品|商店|發[票篻]|发票|證明聯|证明联|'
    r'隨機碼|随机码',
    caseSensitive: false,
  );

  // ─── Two-phase parser ─────────────────────────────────────────────────────

  _ReceiptParseAnalysis _parseWithRules(List<String> lines) {
    final normalized = lines.map(_normalizeLine).toList();

    // Phase 1 — tokenize: classify every line as name / price / noise
    final (:names, :prices, :grandTotal) = _tokenize(normalized);

    // Phase 2 — match: assign the best-scoring price to each name
    final (:items, :usedAnyP0, :matches) = _matchTokens(names, prices);

    // Infer total if none was found in the footer
    final total = (grandTotal ?? 0) > 0
        ? grandTotal!
        : _inferTotal(normalized, items);

    // Validation / confidence
    final itemSum = items.fold(0.0, (s, i) => s + i.amount);
    final fallbackNameCount = items
        .where((item) => _isFallbackItemName(item.name))
        .length;
    final lowConf =
        items.isEmpty ||
        fallbackNameCount > 0 ||
        usedAnyP0 ||
        (total > 0 && (itemSum - total).abs() > total * 0.05);

    final result = ScanResultEntity(
      items: items,
      total: total,
      rawText: lines.join('\n'),
      lowConfidence: lowConf,
    );
    return _ReceiptParseAnalysis(result: result, matches: matches);
  }

  ReceiptFieldExtractionEntity _extractFields(ReceiptDocumentEntity document) {
    final rows = _buildLayoutRows(document);
    final extractedMerchant = _extractMerchant(rows);
    final extractedSubtotal = _extractSubtotal(rows);
    final extractedTax = _extractTax(rows);
    final extractedTotal = _extractTotal(rows);
    final footerStart = [
      if (extractedSubtotal != null && extractedSubtotal.lineOrders.isNotEmpty)
        extractedSubtotal.lineOrders.first,
      if (extractedTax != null && extractedTax.lineOrders.isNotEmpty)
        extractedTax.lineOrders.first,
      if (extractedTotal != null && extractedTotal.lineOrders.isNotEmpty)
        extractedTotal.lineOrders.first,
    ];
    final lineItems = _extractLineItems(
      rows,
      footerStart: footerStart.isEmpty
          ? null
          : footerStart.reduce((a, b) => a < b ? a : b),
    );
    final refined = _applyHeuristicReinforcements(
      rows,
      merchant: extractedMerchant,
      subtotal: extractedSubtotal,
      tax: extractedTax,
      total: extractedTotal,
      lineItems: lineItems,
    );
    return ReceiptFieldExtractionEntity(
      merchant: refined.merchant,
      subtotal: refined.subtotal,
      tax: refined.tax,
      total: refined.total,
      documentConfidence: _buildDocumentConfidence(
        merchant: refined.merchant,
        subtotal: refined.subtotal,
        tax: refined.tax,
        total: refined.total,
        lineItems: refined.lineItems,
      ),
      lineItems: refined.lineItems,
    );
  }

  ScanResultEntity _mapExtractionToScanResult(
    ReceiptFieldExtractionEntity extraction, {
    required ScanResultEntity fallbackResult,
    required String rawText,
    required ReceiptDocumentEntity document,
  }) {
    final extractedItems = extraction.lineItems
        .map(
          (item) => ScanResultItemEntity(
            name: item.name,
            amount: item.amount,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
          ),
        )
        .toList();
    final shouldUseInvoiceSummaryFallback =
        extractedItems.isEmpty &&
        extraction.total != null &&
        _looksLikeTaiwanInvoiceSummary(rawText);
    final resolvedItems = extractedItems.isNotEmpty
        ? extractedItems
        : shouldUseInvoiceSummaryFallback
        ? [
            ScanResultItemEntity(
              name: '發票總計',
              amount: extraction.total!.value,
              quantity: 1,
            ),
          ]
        : fallbackResult.items;
    final hasCriticalLowConfidence =
        extraction.merchant == null ||
        extraction.total == null ||
        extraction.lineItems.any(
          (item) => item.confidence.level == ReceiptConfidenceLevel.low,
        );

    return ScanResultEntity(
      items: resolvedItems,
      total: extraction.total?.value ?? fallbackResult.total,
      rawText: rawText,
      lowConfidence:
          shouldUseInvoiceSummaryFallback ||
          extraction.documentConfidence.level == ReceiptConfidenceLevel.low ||
          hasCriticalLowConfidence,
      document: document,
      extraction: extraction,
    );
  }

  List<_ReceiptLayoutRow> _buildLayoutRows(ReceiptDocumentEntity document) {
    final lines = [...document.lines]
      ..sort((a, b) {
        final topDiff = a.boundingBox.top.compareTo(b.boundingBox.top);
        if (topDiff != 0) return topDiff;
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      });

    return lines
        .map(
          (line) => _ReceiptLayoutRow(
            text: line.text.trim(),
            normalizedText: _normalizeLine(line.text),
            lineOrders: [line.readingOrder],
            top: line.boundingBox.top,
            left: line.boundingBox.left,
            height: line.boundingBox.height,
          ),
        )
        .toList();
  }

  ReceiptTextFieldEntity? _extractMerchant(List<_ReceiptLayoutRow> rows) {
    final candidates = <({ReceiptTextFieldEntity field, int score})>[];
    for (var i = 0; i < rows.length && i < 6; i++) {
      final row = rows[i];
      final cleaned = _cleanMerchantText(row.text);
      if (cleaned.isEmpty) continue;
      if (_looksLikeReceiptMetadata(cleaned) || _isAddressLine(cleaned)) {
        continue;
      }
      if (_isTotalLine(cleaned)) continue;
      if (RegExp(r'^\d+$').hasMatch(cleaned)) continue;
      final cjkCount = _cjkPat.allMatches(cleaned).length;
      final latinCount = RegExp(r'[A-Za-z]').allMatches(cleaned).length;
      final digitCount = RegExp(r'\d').allMatches(cleaned).length;
      final score =
          cjkCount * 10 + latinCount * 3 - digitCount * 2 + (60 - i * 8);
      if (score <= 0) continue;
      candidates.add((
        field: ReceiptTextFieldEntity(
          value: cleaned,
          rawText: row.text,
          lineOrders: row.lineOrders,
          confidence: _buildMerchantConfidence(cleaned, row, rowIndex: i),
        ),
        score: score,
      ));
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first.field;
  }

  ReceiptAmountFieldEntity? _extractTotal(List<_ReceiptLayoutRow> rows) =>
      _extractAmountField(
        rows,
        labelPattern: RegExp(
          r'合計|總計|总计|総計|^合(?:\s|$)|實收金額|实收金额|應收金額|应收金额|お支払|ご請求額|お会計|TOTAL',
          caseSensitive: false,
        ),
        preferNearbyLargest: true,
      );

  ReceiptAmountFieldEntity? _extractSubtotal(List<_ReceiptLayoutRow> rows) =>
      _extractAmountField(
        rows,
        labelPattern: RegExp(
          r'小計|原價小計|原价小计|SUBTOTAL|SUB TOTAL',
          caseSensitive: false,
        ),
      );

  ReceiptAmountFieldEntity? _extractTax(List<_ReceiptLayoutRow> rows) =>
      _extractAmountField(
        rows,
        labelPattern: RegExp(r'消費税|消費稅|税額|TAX', caseSensitive: false),
      );

  ReceiptAmountFieldEntity? _extractAmountField(
    List<_ReceiptLayoutRow> rows, {
    required RegExp labelPattern,
    bool preferNearbyLargest = false,
  }) {
    for (var i = rows.length - 1; i >= 0; i--) {
      final row = rows[i];
      if (!labelPattern.hasMatch(row.normalizedText)) continue;
      final labelMatch = labelPattern.firstMatch(row.normalizedText);
      final labelText = labelMatch?.group(0)?.trim() ?? '';
      final labeledAmount = _extractAmountAdjacentToLabel(
        row.normalizedText,
        labelPattern,
      );
      final rowAmounts = _collectValidAmounts(row.normalizedText);
      final trustInlineAmount =
          labeledAmount != null &&
          (!preferNearbyLargest || rowAmounts.length > 1 || labelText != '合');
      if (trustInlineAmount) {
        return ReceiptAmountFieldEntity(
          value: labeledAmount,
          rawText: row.text,
          lineOrders: row.lineOrders,
          confidence: _buildAmountFieldConfidence(
            labelRow: row,
            valueRow: row,
            amount: labeledAmount,
          ),
        );
      }
      final directAmount = _largestValidAmount(row.normalizedText);
      if (directAmount != null && !preferNearbyLargest) {
        return ReceiptAmountFieldEntity(
          value: directAmount,
          rawText: row.text,
          lineOrders: row.lineOrders,
          confidence: _buildAmountFieldConfidence(
            labelRow: row,
            valueRow: row,
            amount: directAmount,
          ),
        );
      }
      final nearbyRows = rows.skip(i).take(4).toList();
      final nearbyCandidates = nearbyRows
          .map((candidateRow) {
            final amount = _largestValidAmount(candidateRow.normalizedText);
            if (amount == null) return null;
            return (amount: amount, row: candidateRow);
          })
          .whereType<({double amount, _ReceiptLayoutRow row})>()
          .toList();
      if (nearbyCandidates.isNotEmpty) {
        nearbyCandidates.sort((a, b) => b.amount.compareTo(a.amount));
        final best = nearbyCandidates.first;
        return ReceiptAmountFieldEntity(
          value: best.amount,
          rawText: best.row == row ? row.text : '${row.text}\n${best.row.text}',
          lineOrders: [...row.lineOrders, ...best.row.lineOrders],
          confidence: _buildAmountFieldConfidence(
            labelRow: row,
            valueRow: best.row,
            amount: best.amount,
          ),
        );
      }
    }
    return null;
  }

  List<ReceiptExtractedLineItemEntity> _extractLineItems(
    List<_ReceiptLayoutRow> rows, {
    int? footerStart,
  }) {
    final scopedRows = rows
        .where((row) => footerStart == null || row.readingOrder < footerStart)
        .where((row) => !_looksLikeReceiptMetadata(row.normalizedText))
        .where((row) => !_isAddressLine(row.normalizedText))
        .toList();
    if (scopedRows.isEmpty) return const [];
    if (_looksLikeTaiwanInvoiceSummary(
          rows.map((row) => row.text).join('\n'),
        ) &&
        !_hasStructuredItemEvidence(scopedRows)) {
      return const [];
    }

    final startIndex = scopedRows.indexWhere(
      (row) =>
          _isItemName(row.normalizedText) ||
          _trySameLine(row.normalizedText) != null ||
          RegExp(r'^\d{8,}$').hasMatch(row.normalizedText.trim()),
    );
    final itemRows = startIndex >= 0
        ? scopedRows.skip(startIndex).toList()
        : scopedRows;
    if (itemRows.isEmpty) return const [];

    final parserLines = itemRows.map((row) => row.text).toList();
    final parsed = _parseWithRules(parserLines).result.items;
    if (parsed.isNotEmpty) {
      return parsed.map((item) {
        return ReceiptExtractedLineItemEntity(
          name: item.name,
          amount: item.amount,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          lineOrders: _matchItemLineOrders(item, itemRows),
          confidence: _buildItemConfidence(
            item,
            _matchItemLineOrders(item, itemRows),
          ),
        );
      }).toList();
    }

    final fallbackItems = <ReceiptExtractedLineItemEntity>[];
    for (final row in itemRows) {
      final pair = _trySameLine(row.normalizedText);
      if (pair == null) continue;
      fallbackItems.add(
        ReceiptExtractedLineItemEntity(
          name: pair.name,
          amount: pair.amount,
          quantity: pair.quantity,
          unitPrice: pair.unitPrice,
          lineOrders: row.lineOrders,
          confidence: _buildItemConfidence(
            ScanResultItemEntity(
              name: pair.name,
              amount: pair.amount,
              quantity: pair.quantity,
              unitPrice: pair.unitPrice,
            ),
            row.lineOrders,
          ),
        ),
      );
    }
    return fallbackItems;
  }

  bool _hasStructuredItemEvidence(List<_ReceiptLayoutRow> rows) => rows.any(
    (row) =>
        RegExp(r'[¥$]\s*\d').hasMatch(row.normalizedText) ||
        RegExp(r'\d{2,5}\s*[xX×]\s*\d').hasMatch(row.normalizedText) ||
        RegExp(r'^\d{8,}$').hasMatch(row.normalizedText.trim()),
  );

  List<int> _matchItemLineOrders(
    ScanResultItemEntity item,
    List<_ReceiptLayoutRow> rows,
  ) {
    final compactName = _compactForMatch(item.name);
    for (final row in rows) {
      final rowCompact = _compactForMatch(_cleanName(row.normalizedText));
      if (compactName.isNotEmpty && rowCompact.contains(compactName)) {
        return row.lineOrders;
      }
    }

    final amountText = item.amount.toStringAsFixed(
      item.amount % 1 == 0 ? 0 : 2,
    );
    for (final row in rows) {
      if (row.normalizedText.contains(amountText)) {
        return row.lineOrders;
      }
    }
    return const [];
  }

  String _cleanMerchantText(String raw) {
    var text = _nfkc(raw);
    text = text.replaceAll(RegExp(r'\d{2,4}[-−]\d{3,4}[-−]\d{4}'), ' ');
    text = text.replaceAll(RegExp(r'T\d{6,}'), ' ');
    text = text.replaceAll(RegExp(r'^\s*0S[-−]\d{4}[-−]\d{4}\s*'), ' ');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
    text = text.replaceAll(
      RegExp(r'^[^A-Za-z0-9\u4e00-\u9fff\u3040-\u30ff]+'),
      '',
    );
    text = text.replaceAll(
      RegExp(r'[^A-Za-z0-9\u4e00-\u9fff\u3040-\u30ff]+$'),
      '',
    );
    return text.trim();
  }

  String _compactForMatch(String text) => text
      .replaceAll(RegExp(r'[^A-Za-z0-9\u4e00-\u9fff\u3040-\u30ff]+'), '')
      .toLowerCase();

  ({
    ReceiptTextFieldEntity? merchant,
    ReceiptAmountFieldEntity? subtotal,
    ReceiptAmountFieldEntity? tax,
    ReceiptAmountFieldEntity? total,
    List<ReceiptExtractedLineItemEntity> lineItems,
  })
  _applyHeuristicReinforcements(
    List<_ReceiptLayoutRow> rows, {
    required ReceiptTextFieldEntity? merchant,
    required ReceiptAmountFieldEntity? subtotal,
    required ReceiptAmountFieldEntity? tax,
    required ReceiptAmountFieldEntity? total,
    required List<ReceiptExtractedLineItemEntity> lineItems,
  }) {
    final refinedItems = _applyPairingHeuristics(rows, lineItems);
    final inferredSubtotal = subtotal ?? _inferSubtotalFromItems(refinedItems);

    return (
      merchant: merchant,
      subtotal: inferredSubtotal,
      tax: tax,
      total: total,
      lineItems: refinedItems,
    );
  }

  List<ReceiptExtractedLineItemEntity> _applyPairingHeuristics(
    List<_ReceiptLayoutRow> rows,
    List<ReceiptExtractedLineItemEntity> items,
  ) {
    final claimedOrders = items.expand((item) => item.lineOrders).toSet();

    return items.map((item) {
      final shouldRefine =
          item.confidence.level == ReceiptConfidenceLevel.low ||
          _isFallbackItemName(item.name);
      if (!shouldRefine) return item;

      final anchorOrder = item.lineOrders.isEmpty ? null : item.lineOrders.last;
      if (anchorOrder == null) return item;

      final candidateRows =
          rows.where((row) {
            final distance = (row.readingOrder - anchorOrder).abs();
            if (distance == 0 || distance > 2) return false;
            if (claimedOrders.contains(row.readingOrder)) return false;
            if (!_isItemName(row.normalizedText)) return false;
            if (_looksLikeReceiptMetadata(row.normalizedText)) return false;
            return _scoreItemNameQuality(_cleanName(row.text)) >
                _scoreItemNameQuality(item.name);
          }).toList()..sort((a, b) {
            final qualityDiff = _scoreItemNameQuality(
              _cleanName(b.text),
            ).compareTo(_scoreItemNameQuality(_cleanName(a.text)));
            if (qualityDiff != 0) return qualityDiff;
            return (a.readingOrder - anchorOrder).abs().compareTo(
              (b.readingOrder - anchorOrder).abs(),
            );
          });

      if (candidateRows.isEmpty) return item;

      final bestRow = candidateRows.first;
      final refinedName = _cleanName(bestRow.text);
      return ReceiptExtractedLineItemEntity(
        name: refinedName,
        amount: item.amount,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        lineOrders: [...bestRow.lineOrders, ...item.lineOrders],
        confidence: _confidenceFromScore(
          (item.confidence.score + 0.2).clamp(0.0, 1.0).toDouble(),
          reasons: [...item.confidence.reasons, 'heuristic-pairing-reinforced'],
        ),
      );
    }).toList();
  }

  ReceiptAmountFieldEntity? _inferSubtotalFromItems(
    List<ReceiptExtractedLineItemEntity> items,
  ) {
    if (items.isEmpty) return null;
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.amount);
    return ReceiptAmountFieldEntity(
      value: subtotal,
      rawText: 'inferred-from-line-items',
      lineOrders: items.expand((item) => item.lineOrders).toList(),
      confidence: _confidenceFromScore(
        0.45,
        reasons: const ['heuristic-field-inferred-subtotal'],
      ),
    );
  }

  ReceiptConfidenceEntity _buildMerchantConfidence(
    String cleaned,
    _ReceiptLayoutRow row, {
    required int rowIndex,
  }) {
    var score = 0.45;
    final reasons = <String>[];
    final cjkCount = _cjkPat.allMatches(cleaned).length;
    final digitCount = RegExp(r'\d').allMatches(cleaned).length;

    if (cjkCount >= 4) {
      score += 0.2;
    } else {
      reasons.add('merchant-name-short');
    }
    if (digitCount <= 4) {
      score += 0.1;
    } else {
      score -= 0.1;
      reasons.add('merchant-name-digit-heavy');
    }
    if (rowIndex <= 1 || row.top <= 0.12) {
      score += 0.15;
    } else {
      reasons.add('merchant-not-in-header');
    }

    return _confidenceFromScore(score, reasons: reasons);
  }

  ReceiptConfidenceEntity _buildAmountFieldConfidence({
    required _ReceiptLayoutRow labelRow,
    required _ReceiptLayoutRow valueRow,
    required double amount,
  }) {
    var score = 0.55;
    final reasons = <String>[];
    if (labelRow.readingOrder == valueRow.readingOrder) {
      score += 0.25;
    } else {
      score += 0.1;
      reasons.add('value-found-nearby');
    }
    if (amount >= 100) {
      score += 0.1;
    } else {
      reasons.add('small-amount-fragment');
    }
    if ((valueRow.readingOrder - labelRow.readingOrder).abs() > 1) {
      score -= 0.1;
      reasons.add('label-value-gap');
    }
    return _confidenceFromScore(score, reasons: reasons);
  }

  ReceiptConfidenceEntity _buildItemConfidence(
    ScanResultItemEntity item,
    List<int> lineOrders,
  ) {
    var score = 0.4;
    final reasons = <String>[];
    final nameQuality = _scoreItemNameQuality(item.name);
    score += (((nameQuality + 40) / 140).clamp(0.0, 0.35) as num).toDouble();
    if (lineOrders.isNotEmpty) {
      score += 0.15;
    } else {
      reasons.add('item-source-line-missing');
    }
    if (item.unitPrice != null) {
      score += 0.1;
    }
    if (item.quantity > 1) {
      score += 0.05;
    }
    if (_isFallbackItemName(item.name)) {
      score -= 0.25;
      reasons.add('fallback-item-name');
    }
    return _confidenceFromScore(score, reasons: reasons);
  }

  ReceiptConfidenceEntity _buildDocumentConfidence({
    required ReceiptTextFieldEntity? merchant,
    required ReceiptAmountFieldEntity? subtotal,
    required ReceiptAmountFieldEntity? tax,
    required ReceiptAmountFieldEntity? total,
    required List<ReceiptExtractedLineItemEntity> lineItems,
  }) {
    final reasons = <String>[];
    final scores = <double>[
      if (merchant != null) merchant.confidence.score,
      if (subtotal != null) subtotal.confidence.score,
      if (tax != null) tax.confidence.score,
      if (total != null) total.confidence.score,
      ...lineItems.map((item) => item.confidence.score),
    ];

    var score = scores.isEmpty
        ? 0.2
        : scores.reduce((a, b) => a + b) / scores.length;

    if (merchant == null) {
      score -= 0.2;
      reasons.add('merchant-missing');
    }
    if (total == null) {
      score -= 0.25;
      reasons.add('total-missing');
    }
    if (lineItems.isEmpty) {
      score -= 0.3;
      reasons.add('line-items-missing');
    } else if (total != null) {
      final itemSum = lineItems.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );
      if ((itemSum - total.value).abs() > total.value * 0.05) {
        score -= 0.2;
        reasons.add('total-item-mismatch');
      }
    }
    final lowItemCount = lineItems
        .where((item) => item.confidence.level == ReceiptConfidenceLevel.low)
        .length;
    if (lowItemCount > 0 && lineItems.isNotEmpty) {
      score -= 0.15 + (lowItemCount / lineItems.length) * 0.25;
      reasons.add('low-confidence-line-items');
    }

    return _confidenceFromScore(score, reasons: reasons);
  }

  ReceiptConfidenceEntity _confidenceFromScore(
    double score, {
    List<String> reasons = const [],
  }) {
    final normalized = (score.clamp(0.0, 1.0) as num).toDouble();
    final level = normalized >= 0.75
        ? ReceiptConfidenceLevel.high
        : normalized >= 0.45
        ? ReceiptConfidenceLevel.medium
        : ReceiptConfidenceLevel.low;
    return ReceiptConfidenceEntity(
      score: normalized,
      level: level,
      reasons: reasons,
    );
  }

  // ── Phase 1: Tokenize ────────────────────────────────────────────────────

  ({List<_NameToken> names, List<_PriceToken> prices, double? grandTotal})
  _tokenize(List<String> normalized) {
    final names = <_NameToken>[];
    final prices = <_PriceToken>[];
    double? grandTotal;

    bool inTotalSection = false;
    bool needTotalNextLine = false;
    bool pendingCurrency = false;

    for (int i = 0; i < normalized.length; i++) {
      final line = normalized[i];

      // ── Grab total from line AFTER bare keyword ("合計\n¥4,455") ─────────
      if (needTotalNextLine) {
        needTotalNextLine = false;
        final amt = _largestValidAmount(line);
        if (amt != null && amt > 0) grandTotal = amt;
      }

      // ── Footer: only track grand total ───────────────────────────────────
      if (inTotalSection) {
        final amt = _largestValidAmount(line);
        if (amt != null && amt > (grandTotal ?? 0)) grandTotal = amt;
        continue;
      }

      // ── Grand total / end-of-items detection ─────────────────────────────
      if (_isTotalLine(line)) {
        final amt = _largestValidAmount(line);
        if (amt != null && amt > 0) {
          grandTotal = amt;
        } else {
          needTotalNextLine = true;
        }
        inTotalSection = true;
        continue;
      }

      // ── Standalone ¥/$ line ──────────────────────────────────────────────
      if (line.trim() == '¥' || line.trim() == r'$') {
        pendingCurrency = true;
        continue;
      }
      if (pendingCurrency) {
        pendingCurrency = false;
        final amt = _parseNum(line.replaceAll(RegExp(r'[,，]'), ''));
        if (amt != null && amt >= 10) {
          prices.add(_PriceToken(amt, _PriceType.p3, i));
        }
        continue;
      }

      // ── Discount context ─────────────────────────────────────────────────
      final isDiscount = i > 0 && _isDiscountLine(normalized[i - 1]);

      // ── Item name ────────────────────────────────────────────────────────
      if (_isItemName(line)) {
        final pair = _trySameLine(line);
        if (pair != null) {
          // Same-line name+price: emit both tokens.
          // Price stored as P2 — a P3 line appearing after it can still win.
          names.add(
            _NameToken(
              pair.name,
              i,
              quantity: pair.quantity,
              unitPrice: pair.unitPrice,
            ),
          );
          prices.add(
            _PriceToken(pair.amount, _PriceType.p2, i, isDiscount: isDiscount),
          );
        } else {
          names.add(_NameToken(_cleanName(line), i));
        }
        continue;
      }

      // ── Price classification ─────────────────────────────────────────────

      // Barcode lines (8+ pure digits):
      // • If the immediately preceding line was already added as a name token,
      //   the barcode is just a separator — skip it (product name handles the item).
      // • Otherwise (no product name before the barcode, poor-quality OCR),
      //   create a barcode fallback name so the following price lines are matched.
      if (RegExp(r'^\d{8,}$').hasMatch(line.trim())) {
        final hasNearbyName = names.isNotEmpty && names.last.lineIndex >= i - 1;
        if (!hasNearbyName) {
          names.add(_NameToken(_barcodeFallbackName(line.trim()), i));
        }
        continue;
      }

      // P3a — TX price: $65TX
      if (RegExp(r'[¥$][\d,，]+\s*T[xX]').hasMatch(line)) {
        final amt = _firstValidAmount(line);
        if (amt != null && amt >= 10) {
          prices.add(
            _PriceToken(amt, _PriceType.p3, i, isDiscount: isDiscount),
          );
        }
        continue;
      }

      // P3b — standalone final price: ¥648
      if (_isFinalPrice(line)) {
        final amt = _firstValidAmount(line);
        if (amt != null && amt >= 10) {
          prices.add(
            _PriceToken(amt, _PriceType.p3, i, isDiscount: isDiscount),
          );
        }
        continue;
      }

      // Base price fallback — ¥1,380（免税額...
      if (RegExp(r'[¥$]').hasMatch(line) && line.contains('(')) {
        final amt = _firstValidAmount(line);
        if (amt != null && amt >= 10) {
          prices.add(
            _PriceToken(amt, _PriceType.base, i, isDiscount: isDiscount),
          );
        }
        continue;
      }

      // Tax-fragment — bare ¥110) with no other content
      if (RegExp(r'^[¥$][\d,，]+\)$').hasMatch(line.trim())) continue;

      // P2 — unit × qty: $65 x 1
      if (RegExp(r'[¥$][\d,，]+\s*[xX×]').hasMatch(line)) {
        final amt = _firstValidAmount(line);
        if (amt != null && amt >= 10) {
          prices.add(
            _PriceToken(amt, _PriceType.p2, i, isDiscount: isDiscount),
          );
        }
        continue;
      }

      final cjkCount = _cjkPat.allMatches(line).length;

      // P1 — short CJK context price: 外 4,050
      if (cjkCount > 0 && cjkCount <= 3) {
        final amt = _largestValidAmount(line);
        if (amt != null && amt >= 10) {
          prices.add(
            _PriceToken(amt, _PriceType.p1, i, isDiscount: isDiscount),
          );
        }
        continue;
      }

      // P2b — multi-CJK description line with embedded ¥: 本体 ¥2,760 ¥110)
      if (cjkCount > 3 && RegExp(r'[¥$]\d').hasMatch(line)) {
        double? biggest;
        for (final m in RegExp(r'[¥$]([\d,，]+)').allMatches(line)) {
          final n = _parseNum(m.group(1)!);
          if (n != null && (biggest == null || n > biggest)) biggest = n;
        }
        if (biggest != null && biggest >= 10) {
          prices.add(
            _PriceToken(biggest, _PriceType.p2b, i, isDiscount: isDiscount),
          );
        }
        continue;
      }

      // P0 — plain number: last resort
      if (cjkCount == 0 && !RegExp(r'[¥$@]').hasMatch(line)) {
        final amt = _largestValidAmount(line);
        if (amt != null && amt >= 100) {
          prices.add(
            _PriceToken(amt, _PriceType.p0, i, isDiscount: isDiscount),
          );
        }
      }
    }

    return (names: names, prices: prices, grandTotal: grandTotal);
  }

  // ── Phase 2: Match ───────────────────────────────────────────────────────

  ({
    List<ScanResultItemEntity> items,
    bool usedAnyP0,
    List<_MatchedItemCandidate> matches,
  })
  _matchTokens(List<_NameToken> names, List<_PriceToken> prices) {
    final items = <ScanResultItemEntity>[];
    final matches = <_MatchedItemCandidate>[];
    final usedPriceIdxs = <int>{};
    bool usedAnyP0 = false;

    for (int ni = 0; ni < names.length; ni++) {
      final name = names[ni];
      // Window: [name.lineIndex, next name's lineIndex)
      final windowEnd = ni + 1 < names.length
          ? names[ni + 1].lineIndex
          : 0x7fffffff;

      // Collect candidate price tokens within this name's window
      final candidates = <({int priceIdx, _PriceToken token, double score})>[];

      for (int pi = 0; pi < prices.length; pi++) {
        if (usedPriceIdxs.contains(pi)) continue;
        final p = prices[pi];
        if (p.lineIndex < name.lineIndex) continue; // price before name
        if (p.lineIndex >= windowEnd) continue; // belongs to next name
        candidates.add((
          priceIdx: pi,
          token: p,
          score: p.scoreFor(name.lineIndex),
        ));
      }

      if (candidates.isEmpty) continue;

      // P0 anomaly check — remove outliers > median × 10
      final knownPrices = items.map((e) => e.amount).toList()..sort();
      final median = knownPrices.length >= 3
          ? knownPrices[knownPrices.length ~/ 2]
          : null;

      final valid = candidates.where((c) {
        if (c.token.type == _PriceType.p0 && median != null) {
          return c.token.value <= median * 10;
        }
        return true;
      }).toList();

      if (valid.isEmpty) continue;

      // Check if any candidate carries a discount context
      final hasDiscount = valid.any((c) => c.token.isDiscount);

      // Sort: highest score first.
      // Equal scores: prefer larger value normally; prefer smaller under discount.
      valid.sort((a, b) {
        final diff = b.score - a.score;
        if (diff.abs() > 0.01) return diff > 0 ? 1 : -1;
        return hasDiscount
            ? a.token.value.compareTo(b.token.value) // smaller = discounted
            : b.token.value.compareTo(a.token.value); // larger = safer
      });

      final best = valid.first;
      usedPriceIdxs.add(best.priceIdx);
      if (best.token.type == _PriceType.p0) usedAnyP0 = true;

      final runnerUp = valid.length > 1 ? valid[1] : null;
      final scoreMargin = runnerUp == null ? 1.0 : best.score - runnerUp.score;
      final item = ScanResultItemEntity(
        name: name.text,
        amount: best.token.value,
        quantity: name.quantity,
        unitPrice: name.unitPrice,
      );

      items.add(item);
      matches.add(
        _MatchedItemCandidate(
          item: item,
          priceType: best.token.type,
          lineDistance: best.token.lineIndex - name.lineIndex,
          candidateCount: valid.length,
          scoreMargin: scoreMargin,
          priceScore: best.score,
        ),
      );
    }

    return (items: items, usedAnyP0: usedAnyP0, matches: matches);
  }

  // ─── Line classifiers ────────────────────────────────────────────────────

  bool _isItemName(String line) {
    if (_cjkPat.allMatches(line).length < 3) return false;
    if (_labelPat.hasMatch(line)) return false;
    if (_looksLikeReceiptMetadata(line)) return false;
    if (_isAddressLine(line)) return false;
    if (RegExp(r'^[¥$]').hasMatch(line.trimLeft())) return false;
    if (RegExp(r'^\d{6}').hasMatch(line.trim())) return false;
    if (RegExp(r'\d{2}[/\-]\d{2}[/\-]\d{2}').hasMatch(line)) return false;
    if (RegExp(r'\d{2,4}[-−]\d{3,4}[-−]\d{4}').hasMatch(line)) return false;
    return true;
  }

  bool _isFinalPrice(String line) {
    if (!RegExp(r'^[¥$]').hasMatch(line.trimLeft())) return false;
    if (line.contains('(')) return false;
    if (line.trimRight().endsWith(')')) return false;
    if (RegExp(r'[xX×]').hasMatch(line)) return false;
    return true;
  }

  bool _isTotalLine(String line) => RegExp(
    r'合計|總計|总计|小計|原價小計|原价小计|帳單|総計|計[:：$]|實收金額|实收金额|應收金額|应收金额|'
    r'お支払|お買上|税込合計|ご請求額|お会計|TOTAL|SUBTOTAL|SUB TOTAL',
    caseSensitive: false,
  ).hasMatch(line);

  bool _isAddressLine(String line) {
    if (RegExp(r'〒\d{3}-?\d{4}').hasMatch(line)) return true;
    if (RegExp(r'(東京都|北海道|.{2,3}[府県]).{1,4}[市区町村郡]').hasMatch(line)) {
      return true;
    }
    if (RegExp(r'\d{1,3}丁目|\d+-\d+').hasMatch(line) &&
        RegExp(r'[市区町村]').hasMatch(line)) {
      return true;
    }
    return false;
  }

  bool _isDiscountLine(String line) =>
      RegExp(r'割引|値引|OFF|ｵﾌ|割引き|クーポン|▲', caseSensitive: false).hasMatch(line) ||
      RegExp(r'^[-−]').hasMatch(line.trimLeft());

  bool _looksLikeReceiptMetadata(String line) => RegExp(
    r'登録番号|登錄番号|領収書|領吸需|TAX\s*FREE|消耗品|免税額計|買上点数|お買上点数|'
    r'QUICPay|端\d+|No\d+|電話|TEL|仰利|點餐員|点餐員|單號|单号|大人|小孩|'
    r'桌[A-Za-z0-9一二三四五六七八九十]|服務費|服务费|電子?發[票篻]|电子?发票|'
    r'證明聯|证明联|隨機碼|随机码|賣方|卖方|買方|买方|'
    r'[A-Z]{2}[-−]\d{8}|\d{2,3}年\d{2}[-−]\d{2}月',
    caseSensitive: false,
  ).hasMatch(line);

  // ─── Name / amount helpers ───────────────────────────────────────────────

  String _normalizeLine(String line) {
    var s = _nfkc(line);
    s = s.replaceAllMapped(
      RegExp(r'(\d{1,3})[,，]\.(\d{3})\b'),
      (m) => '${m.group(1)},${m.group(2)}',
    );
    // ¥1・380 → ¥1,380  (middle-dot misread)
    s = s.replaceAllMapped(
      RegExp(r'([¥$])(\d{1,3})[・･](\d{3})\b'),
      (m) => '${m.group(1)}${m.group(2)},${m.group(3)}',
    );
    // ¥8:543 → ¥8,543  (colon misread)
    s = s.replaceAllMapped(
      RegExp(r'([¥$])(\d{1,3})[：:](\d{3})\b'),
      (m) => '${m.group(1)}${m.group(2)},${m.group(3)}',
    );
    // ¥1.380 / ¥2.  380 → ¥1,380  (period misread of thousands comma, optional spaces)
    s = s.replaceAllMapped(
      RegExp(r'([¥$])(\d{1,3})[.]\s*(\d{3})\b'),
      (m) => '${m.group(1)}${m.group(2)},${m.group(3)}',
    );
    // ¥l,380 / ¥I,380 → ¥1,380  (lowercase-L or uppercase-I misread as 1)
    s = s.replaceAllMapped(
      RegExp(r'([¥$])[lI](\d)'),
      (m) => '${m.group(1)}1${m.group(2)}',
    );
    // ¥2,  380 → ¥2,380  (OCR inserts space after thousands comma)
    s = s.replaceAllMapped(
      RegExp(r'([¥$]\d{1,3}),\s+(\d{3}\b)'),
      (m) => '${m.group(1)},${m.group(2)}',
    );
    s = s.replaceAllMapped(
      RegExp(r'(\d{2,5})\s*[%xX×kK]\s*([0-9SOso]{0,3})(?=\D|$)'),
      (m) => '${m.group(1)} X ${_normalizeOcrDigits(m.group(2) ?? '')}',
    );
    s = s.replaceAllMapped(
      RegExp(r'\b([S5])([O0])X(?=\D|$)'),
      (m) => '${m.group(1) == 'S' ? '5' : m.group(1)}0 X 1',
    );
    return s;
  }

  /// Lightweight NFKC: full-width digits/letters → ASCII, common symbols.
  String _nfkc(String s) {
    final buf = StringBuffer();
    for (final rune in s.runes) {
      if (rune >= 0xFF10 && rune <= 0xFF19) {
        buf.writeCharCode(rune - 0xFF10 + 0x30); // ０-９ → 0-9
      } else if (rune >= 0xFF21 && rune <= 0xFF3A) {
        buf.writeCharCode(rune - 0xFF21 + 0x41); // Ａ-Ｚ → A-Z
      } else if (rune >= 0xFF41 && rune <= 0xFF5A) {
        buf.writeCharCode(rune - 0xFF41 + 0x61); // ａ-ｚ → a-z
      } else if (rune == 0xFF08) {
        buf.write('(');
      } else if (rune == 0xFF09) {
        buf.write(')');
      } else if (rune == 0xFF0C) {
        buf.write(',');
      } else if (rune == 0xFF0E) {
        buf.write('.');
      } else if (rune == 0xFFE5) {
        buf.write('¥'); // ￥ → ¥
      } else if (rune == 0xFF04) {
        buf.write(r'$'); // ＄ → $
      } else if (rune == 0xFF05) {
        buf.write('%'); // ％ → %
      } else {
        buf.writeCharCode(rune);
      }
    }
    return buf.toString();
  }

  String _cleanName(String line) {
    var s = _nfkc(line);
    // Leading product codes — with or without space before CJK
    s = s.replaceAll(
      RegExp(r'^\d{4,}(?:\s+|(?=[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]))'),
      '',
    );
    s = s.replaceAll(RegExp(r'^[0-9]+[軽%]\s*'), ''); // tax prefix (8軽, 8%)
    s = s.replaceAll(RegExp(r'\([0-9]+%\)'), ''); // (8%) (10%) marks
    s = s.replaceAll(RegExp(r'\(\$\)'), ''); // ($) TAX FREE marker
    s = s.replaceAll(RegExp(r'\s+[外内]\s+'), ' '); // standalone 外/内 (middle)
    s = s.replaceAll(RegExp(r'\s+[外内]\s*$'), ''); // standalone 外/内 (trailing)
    s = s.replaceAll(RegExp(r'^\s*[外内]\s+'), ''); // standalone 外/内 (leading)
    s = s.replaceAll(RegExp(r'[★☆◆◇●○▲△■□※]'), ''); // decorative markers
    s = s.replaceAll(RegExp(r'^\s*[口ロ◯○●◎•・▪■□◆◇△▲※二]\s*'), '');
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ');
    return s.trim();
  }

  String _normalizeOcrDigits(String raw) => raw
      .replaceAll('S', '5')
      .replaceAll('s', '5')
      .replaceAll('O', '0')
      .replaceAll('o', '0');

  String _barcodeFallbackName(String barcode) => '條碼 $barcode';

  bool _isFallbackItemName(String name) =>
      name.startsWith('條碼 ') || name.startsWith('商品 ');

  /// Returns name / amount metadata if the line contains both item text and price.
  ({String name, double amount, int quantity, double? unitPrice})? _trySameLine(
    String line,
  ) {
    final norm = _normalizeLine(line);
    final orderStyle = _tryOrderStyleSameLine(norm);
    if (orderStyle != null) return orderStyle;

    final matches = _numPat.allMatches(norm).toList();
    if (matches.isEmpty) return null;

    for (int i = matches.length - 1; i >= 0; i--) {
      final m = matches[i];
      final s = m.group(0)!.replaceAll(RegExp(r'[,，]'), '');
      if (s.length > 1 && s.startsWith('0')) continue;
      final price = double.tryParse(s);
      if (price == null || price < 100 || price > 99999) continue;

      // Skip measurement/quantity suffixes: 3.8寸, 100ml, 120ツブ etc.
      final after = norm.substring(m.end);
      if (RegExp(r'^[寸㎝㎜gGmlMLkgKGL]').hasMatch(after)) continue;
      if (RegExp(r'^[\u3040-\u30ff]').hasMatch(after)) continue; // kana unit

      final namePart = line.substring(0, m.start).trim();
      if (_cjkPat.allMatches(namePart).isEmpty) continue;

      // Strip trailing ¥/$ that got included in namePart
      final cleaned = _cleanName(
        namePart.replaceAll(RegExp(r'\s*[¥$]\s*$'), ''),
      );
      if (cleaned.isEmpty) continue;

      return (name: cleaned, amount: price, quantity: 1, unitPrice: null);
    }
    return null;
  }

  ({String name, double amount, int quantity, double? unitPrice})?
  _tryOrderStyleSameLine(String normalizedLine) {
    final match = RegExp(
      r'^(.*?[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff].*?)\s+(\d{2,5})\s*X\s*([0-9]{0,3})?(?:\s+(\d{2,5}))?\s*$',
    ).firstMatch(normalizedLine);
    if (match == null) return null;

    final cleanedName = _cleanName(match.group(1) ?? '');
    if (cleanedName.isEmpty || _looksLikeReceiptMetadata(cleanedName)) {
      return null;
    }

    final unitPrice = _parseNum(match.group(2) ?? '');
    if (unitPrice == null || unitPrice < 10) return null;

    final rawQty = match.group(3);
    final rawTrailingTotal = match.group(4);
    final qtyCandidate = rawQty == null || rawQty.isEmpty
        ? null
        : int.tryParse(rawQty);
    final trailingTotal = rawTrailingTotal == null
        ? null
        : _parseNum(rawTrailingTotal);

    var quantity = qtyCandidate ?? 1;
    double amount;

    if (trailingTotal != null) {
      amount = trailingTotal;
      if (qtyCandidate == null || qtyCandidate <= 0) {
        quantity = trailingTotal >= unitPrice && trailingTotal % unitPrice == 0
            ? (trailingTotal / unitPrice).round()
            : 1;
      }
    } else if (qtyCandidate != null && qtyCandidate > 20) {
      amount = qtyCandidate.toDouble();
      quantity = 1;
    } else {
      amount = unitPrice * quantity;
    }

    if (quantity <= 0) quantity = 1;
    return (
      name: cleanedName,
      amount: amount,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }

  double? _firstValidAmount(String line) {
    final s = _normalizeLine(line);
    for (final m in _numPat.allMatches(s)) {
      final n = _parseNum(m.group(0)!);
      if (n != null) return n;
    }
    return null;
  }

  double? _largestValidAmount(String line) {
    final s = _normalizeLine(line);
    double? best;
    for (final m in _numPat.allMatches(s)) {
      final n = _parseNum(m.group(0)!);
      if (n != null && (best == null || n > best)) best = n;
    }
    return best;
  }

  double? _extractAmountAdjacentToLabel(String line, RegExp labelPattern) {
    final match = labelPattern.firstMatch(line);
    if (match == null) return null;

    final trailing = line
        .substring(match.end)
        .replaceFirst(RegExp(r'^[\s:：$¥]+'), '');
    final trailingAmount = _firstValidAmount(trailing);
    if (trailingAmount != null) return trailingAmount;

    final leading = line.substring(0, match.start).trim();
    if (leading.isEmpty) return null;

    double? best;
    for (final amountMatch in _numPat.allMatches(leading)) {
      final parsed = _parseNum(amountMatch.group(0)!);
      if (parsed != null) best = parsed;
    }
    return best;
  }

  List<double> _collectValidAmounts(String line) {
    final amounts = <double>[];
    for (final amountMatch in _numPat.allMatches(_normalizeLine(line))) {
      final parsed = _parseNum(amountMatch.group(0)!);
      if (parsed != null) {
        amounts.add(parsed);
      }
    }
    return amounts;
  }

  double? _parseNum(String raw) {
    final s = _nfkc(raw).replaceAll(RegExp(r'[,，]'), '');
    if (s.length > 1 && s.startsWith('0') && !s.contains('.')) return null;
    final n = double.tryParse(s);
    if (n == null || n <= 0 || n > 99999) return null;
    return n;
  }

  bool _looksLikeTaiwanInvoiceSummary(String text) => RegExp(
    r'電子?發[票篻]|电子?发票|證明聯|证明联|隨機碼|随机码|[A-Z]{2}[-−]\d{8}',
    caseSensitive: false,
  ).hasMatch(text);

  double _inferTotal(
    List<String> normalized,
    List<ScanResultItemEntity> items,
  ) {
    final sum = items.fold<double>(0, (s, i) => s + i.amount);
    for (final line in normalized.reversed) {
      if (_isItemName(line)) continue;
      final amt = _largestValidAmount(line);
      if (amt != null && amt >= sum * 0.95 && amt <= sum * 1.2) return amt;
    }
    return sum;
  }

  // ─── OCR ─────────────────────────────────────────────────────────────────

  static const _visionChannel = MethodChannel('com.okaeri.native_ocr');

  Future<Map<String, _OcrCandidatePayload>> _collectVisionCandidates(
    File imageFile, {
    required OcrLanguage language,
  }) async {
    final candidates = <String, _OcrCandidatePayload>{};
    final languages = language == OcrLanguage.auto
        ? const [OcrLanguage.japanese, OcrLanguage.chinese, OcrLanguage.english]
        : [language];

    for (var pass = 1; pass <= _ocrPassCount; pass++) {
      for (final candidateLanguage in languages) {
        final document = await _recognizeVisionDocument(
          imageFile,
          language: candidateLanguage,
        );
        if (document.text.trim().isEmpty) continue;
        candidates['ios:${candidateLanguage.name}:pass$pass'] =
            _OcrCandidatePayload(text: document.text, document: document);
      }
    }

    if (candidates.isEmpty) {
      final fallbackDocument = await _recognizeVisionDocument(
        imageFile,
        language: languages.first,
      );
      if (fallbackDocument.text.trim().isNotEmpty) {
        candidates['ios:${languages.first.name}:fallback'] =
            _OcrCandidatePayload(
              text: fallbackDocument.text,
              document: fallbackDocument,
            );
      }
    }

    return candidates;
  }

  Future<ReceiptDocumentEntity> _recognizeVisionDocument(
    File imageFile, {
    required OcrLanguage language,
  }) async {
    final payload = await _visionChannel.invokeMethod<Object?>(
      'recognizeText',
      {'imagePath': imageFile.path, 'language': language.name},
    );
    if (payload is String) {
      return _buildDocumentModelFromText(payload);
    }
    if (payload is Map) {
      return _buildVisionDocumentModel(Map<String, dynamic>.from(payload));
    }
    return _buildDocumentModelFromText('');
  }

  @visibleForTesting
  ScanResultEntity parseRecognizedText(String ocrText) {
    final document = _buildDocumentModelFromText(ocrText);
    final lines = document.lines.map((line) => line.text).toList();
    final extraction = _extractFields(document);
    return _mapExtractionToScanResult(
      extraction,
      fallbackResult: _parseWithRules(lines).result,
      rawText: ocrText,
      document: document,
    );
  }

  @visibleForTesting
  ReceiptFieldExtractionEntity extractFieldsFromText(String ocrText) {
    final document = _buildDocumentModelFromText(ocrText);
    return _extractFields(document);
  }

  @visibleForTesting
  ReceiptFieldExtractionEntity extractFieldsFromDocument(
    ReceiptDocumentEntity document,
  ) {
    return _extractFields(document);
  }

  @visibleForTesting
  String selectBestVisionText(Map<OcrLanguage, String> candidates) {
    final labeled = {
      for (final entry in candidates.entries)
        entry.key.name: _OcrCandidatePayload(
          text: entry.value,
          document: _buildDocumentModelFromText(entry.value),
        ),
    };
    return _selectBestOcrEvaluation(labeled).text;
  }

  _OcrCandidateEvaluation _selectBestOcrEvaluation(
    Map<String, _OcrCandidatePayload> candidates,
  ) {
    final evaluations =
        candidates.entries
            .map((entry) => _evaluateOcrCandidate(entry.key, entry.value.text))
            .toList()
          ..sort((a, b) {
            final scoreDiff = b.score.compareTo(a.score);
            if (scoreDiff != 0) return scoreDiff;
            return b.text.length.compareTo(a.text.length);
          });

    for (final evaluation in evaluations) {
      debugPrint(
        '[ReceiptScan] OCR candidate ${evaluation.label}: '
        'score=${evaluation.score}, '
        'descriptive=${evaluation.descriptiveItemCount}, '
        'fallback=${evaluation.fallbackItemCount}, '
        'items=${evaluation.result.items.length}, '
        'lowConf=${evaluation.result.lowConfidence}',
      );
    }

    return evaluations.first;
  }

  _OcrCandidateEvaluation _evaluateOcrCandidate(String label, String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final analysis = _parseWithRules(lines);
    final result = analysis.result;
    final fallbackItemCount = result.items
        .where((item) => _isFallbackItemName(item.name))
        .length;
    final metadataItemCount = result.items
        .where((item) => _looksLikeReceiptMetadata(item.name))
        .length;
    final descriptiveItemCount =
        result.items.length - fallbackItemCount - metadataItemCount;
    final nameQualityScore = analysis.matches.fold<int>(
      0,
      (sum, match) => sum + _scoreItemNameQuality(match.item.name),
    );
    final stablePairingScore = analysis.matches.fold<int>(
      0,
      (sum, match) => sum + _scorePairingStability(match),
    );
    final strongNameCount = analysis.matches
        .where((match) => _scoreItemNameQuality(match.item.name) >= 45)
        .length;
    final stablePairCount = analysis.matches
        .where((match) => _scorePairingStability(match) >= 55)
        .length;
    final weakPairCount = analysis.matches.length - stablePairCount;
    final score =
        descriptiveItemCount * 180 +
        strongNameCount * 80 +
        stablePairCount * 90 +
        nameQualityScore * 3 +
        stablePairingScore * 4 +
        result.items.length * 20 +
        (result.total > 0 ? 20 : 0) +
        (result.lowConfidence ? -80 : 60) -
        fallbackItemCount * 180 -
        metadataItemCount * 220 -
        weakPairCount * 45 +
        (text.length ~/ 8);

    return _OcrCandidateEvaluation(
      label: label,
      text: text,
      result: result,
      descriptiveItemCount: descriptiveItemCount,
      fallbackItemCount: fallbackItemCount,
      nameQualityScore: nameQualityScore,
      stablePairCount: stablePairCount,
      score: score,
    );
  }

  int _scoreItemNameQuality(String name) {
    if (_isFallbackItemName(name) || _looksLikeReceiptMetadata(name)) {
      return -40;
    }

    final compact = name.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return -40;

    final cjkCount = _cjkPat.allMatches(compact).length;
    final latinCount = RegExp(r'[A-Za-z]').allMatches(compact).length;
    final digitCount = RegExp(r'\d').allMatches(compact).length;
    final readableCount = cjkCount + latinCount + digitCount;
    final noiseCount = compact.length - readableCount;
    final readableRatio = compact.isEmpty
        ? 0.0
        : readableCount / compact.length;
    final digitRatio = readableCount == 0 ? 0.0 : digitCount / readableCount;

    var score = cjkCount * 8 + latinCount * 2 + digitCount;
    if (compact.length >= 6 && compact.length <= 24) {
      score += 24;
    } else if (compact.length >= 4 && compact.length <= 32) {
      score += 12;
    } else if (compact.length < 4) {
      score -= 12;
    } else {
      score -= 6;
    }

    if (readableRatio >= 0.9) {
      score += 18;
    } else if (readableRatio >= 0.75) {
      score += 10;
    } else if (readableRatio < 0.6) {
      score -= 16;
    }

    if (digitRatio > 0.45) score -= 14;
    if (noiseCount >= 4) score -= noiseCount * 4;

    return score;
  }

  int _scorePairingStability(_MatchedItemCandidate match) {
    var score = switch (match.priceType) {
      _PriceType.p3 => 42,
      _PriceType.p2 => 34,
      _PriceType.p2b => 26,
      _PriceType.p1 => 18,
      _PriceType.base => 8,
      _PriceType.p0 => -16,
    };

    if (match.lineDistance == 0) {
      score += 18;
    } else if (match.lineDistance == 1) {
      score += 14;
    } else if (match.lineDistance == 2) {
      score += 8;
    } else if (match.lineDistance <= 4) {
      score += 2;
    } else {
      score -= 10;
    }

    if (match.candidateCount == 1) {
      score += 12;
    } else if (match.candidateCount >= 4) {
      score -= 8;
    }

    if (match.scoreMargin >= 0.25) {
      score += 14;
    } else if (match.scoreMargin >= 0.08) {
      score += 6;
    } else {
      score -= 10;
    }

    score += (match.priceScore * 10).round();

    return score;
  }

  Future<Map<String, _OcrCandidatePayload>> _collectMlKitCandidates(
    File imageFile, {
    required OcrLanguage language,
  }) async {
    final candidates = <String, _OcrCandidatePayload>{};
    for (var pass = 1; pass <= _ocrPassCount; pass++) {
      final document = await _extractWithMLKitDocument(
        imageFile,
        language: language,
      );
      if (document.text.trim().isNotEmpty) {
        candidates['android:${language.name}:pass$pass'] = _OcrCandidatePayload(
          text: document.text,
          document: document,
        );
      }
    }
    return candidates;
  }

  Future<ReceiptDocumentEntity> _extractWithMLKitDocument(
    File imageFile, {
    OcrLanguage language = OcrLanguage.auto,
  }) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizer = TextRecognizer(script: _mlKitScriptFor(language));
    try {
      final recognized = await recognizer.processImage(inputImage);
      return _buildMlKitDocumentModel(recognized, imageFile);
    } finally {
      await recognizer.close();
    }
  }

  ReceiptDocumentEntity _buildMlKitDocumentModel(
    RecognizedText recognized,
    File imageFile,
  ) {
    final decoded = img.decodeImage(imageFile.readAsBytesSync());
    final pageWidth = decoded?.width.toDouble() ?? 1.0;
    final pageHeight = decoded?.height.toDouble() ?? 1.0;
    final blocks = <ReceiptBlockEntity>[];
    var lineOrder = 0;
    var wordOrder = 0;

    for (
      var blockIndex = 0;
      blockIndex < recognized.blocks.length;
      blockIndex++
    ) {
      final block = recognized.blocks[blockIndex];
      final lines = block.lines.map((line) {
        final words = line.elements.map((element) {
          final box = element.boundingBox;
          return ReceiptWordEntity(
            text: element.text,
            normalizedText: element.text.trim(),
            boundingBox: _normalizeBox(
              left: box.left.toDouble(),
              top: box.top.toDouble(),
              width: box.width.toDouble(),
              height: box.height.toDouble(),
              pageWidth: pageWidth,
              pageHeight: pageHeight,
            ),
            readingOrder: wordOrder++,
          );
        }).toList();

        final box = line.boundingBox;
        return ReceiptLineEntity(
          text: line.text,
          normalizedText: line.text.trim(),
          boundingBox: _normalizeBox(
            left: box.left.toDouble(),
            top: box.top.toDouble(),
            width: box.width.toDouble(),
            height: box.height.toDouble(),
            pageWidth: pageWidth,
            pageHeight: pageHeight,
          ),
          readingOrder: lineOrder++,
          words: words,
        );
      }).toList();

      final box = block.boundingBox;
      blocks.add(
        ReceiptBlockEntity(
          text: lines.map((line) => line.text).join('\n'),
          normalizedText: lines.map((line) => line.normalizedText).join('\n'),
          boundingBox: _normalizeBox(
            left: box.left.toDouble(),
            top: box.top.toDouble(),
            width: box.width.toDouble(),
            height: box.height.toDouble(),
            pageWidth: pageWidth,
            pageHeight: pageHeight,
          ),
          readingOrder: blockIndex,
          lines: lines,
        ),
      );
    }

    final text = _documentText(blocks);
    return ReceiptDocumentEntity(
      blocks: blocks,
      text: text,
      normalizedText: text.trim(),
      pageWidth: pageWidth,
      pageHeight: pageHeight,
    );
  }

  ReceiptDocumentEntity _buildVisionDocumentModel(
    Map<String, dynamic> payload,
  ) {
    final pageWidth = (payload['page_width'] as num?)?.toDouble() ?? 1.0;
    final pageHeight = (payload['page_height'] as num?)?.toDouble() ?? 1.0;
    final rawBlocks = (payload['blocks'] as List?) ?? const [];
    final blocks = <ReceiptBlockEntity>[];

    for (var blockIndex = 0; blockIndex < rawBlocks.length; blockIndex++) {
      final blockJson = Map<String, dynamic>.from(rawBlocks[blockIndex] as Map);
      final rawLines = (blockJson['lines'] as List?) ?? const [];
      final lines = <ReceiptLineEntity>[];

      for (var lineIndex = 0; lineIndex < rawLines.length; lineIndex++) {
        final lineJson = Map<String, dynamic>.from(rawLines[lineIndex] as Map);
        final rawWords = (lineJson['words'] as List?) ?? const [];
        final words = <ReceiptWordEntity>[];

        for (var wordIndex = 0; wordIndex < rawWords.length; wordIndex++) {
          final wordJson = Map<String, dynamic>.from(
            rawWords[wordIndex] as Map,
          );
          words.add(
            ReceiptWordEntity(
              text: wordJson['text'] as String? ?? '',
              normalizedText: (wordJson['text'] as String? ?? '').trim(),
              boundingBox: _boxFromJson(
                Map<String, dynamic>.from(wordJson['bounding_box'] as Map),
              ),
              readingOrder:
                  (wordJson['reading_order'] as num?)?.toInt() ??
                  (lineIndex * 1000 + wordIndex),
            ),
          );
        }

        lines.add(
          ReceiptLineEntity(
            text: lineJson['text'] as String? ?? '',
            normalizedText: (lineJson['text'] as String? ?? '').trim(),
            boundingBox: _boxFromJson(
              Map<String, dynamic>.from(lineJson['bounding_box'] as Map),
            ),
            readingOrder:
                (lineJson['reading_order'] as num?)?.toInt() ?? lineIndex,
            words: words,
          ),
        );
      }

      blocks.add(
        ReceiptBlockEntity(
          text:
              blockJson['text'] as String? ??
              lines.map((line) => line.text).join('\n'),
          normalizedText:
              (blockJson['text'] as String? ??
                      lines.map((line) => line.text).join('\n'))
                  .trim(),
          boundingBox: _boxFromJson(
            Map<String, dynamic>.from(blockJson['bounding_box'] as Map),
          ),
          readingOrder:
              (blockJson['reading_order'] as num?)?.toInt() ?? blockIndex,
          lines: lines,
        ),
      );
    }

    final text = (payload['text'] as String?) ?? _documentText(blocks);
    return ReceiptDocumentEntity(
      blocks: blocks,
      text: text,
      normalizedText: text.trim(),
      pageWidth: pageWidth,
      pageHeight: pageHeight,
    );
  }

  ReceiptDocumentEntity _buildDocumentModelFromText(String text) {
    final rawLines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (rawLines.isEmpty) {
      return const ReceiptDocumentEntity(
        blocks: [],
        text: '',
        normalizedText: '',
        pageWidth: 1,
        pageHeight: 1,
      );
    }

    final lines = <ReceiptLineEntity>[];
    for (var i = 0; i < rawLines.length; i++) {
      final lineText = rawLines[i];
      final lineTop = i / rawLines.length;
      final rawWords = lineText
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();
      final wordWidth = rawWords.isEmpty ? 1.0 : 1 / rawWords.length;
      final words = <ReceiptWordEntity>[];
      for (var j = 0; j < rawWords.length; j++) {
        words.add(
          ReceiptWordEntity(
            text: rawWords[j],
            normalizedText: rawWords[j].trim(),
            boundingBox: ReceiptBoundingBoxEntity(
              left: j * wordWidth,
              top: lineTop,
              width: wordWidth,
              height: 1 / rawLines.length,
            ),
            readingOrder: i * 1000 + j,
          ),
        );
      }

      lines.add(
        ReceiptLineEntity(
          text: lineText,
          normalizedText: lineText.trim(),
          boundingBox: ReceiptBoundingBoxEntity(
            left: 0,
            top: lineTop,
            width: 1,
            height: 1 / rawLines.length,
          ),
          readingOrder: i,
          words: words,
        ),
      );
    }

    final block = ReceiptBlockEntity(
      text: rawLines.join('\n'),
      normalizedText: rawLines.join('\n'),
      boundingBox: const ReceiptBoundingBoxEntity(
        left: 0,
        top: 0,
        width: 1,
        height: 1,
      ),
      readingOrder: 0,
      lines: lines,
    );

    return ReceiptDocumentEntity(
      blocks: [block],
      text: rawLines.join('\n'),
      normalizedText: rawLines.join('\n'),
      pageWidth: 1,
      pageHeight: 1,
    );
  }

  ReceiptBoundingBoxEntity _boxFromJson(Map<String, dynamic> json) {
    return ReceiptBoundingBoxEntity(
      left: (json['left'] as num?)?.toDouble() ?? 0,
      top: (json['top'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
    );
  }

  ReceiptBoundingBoxEntity _normalizeBox({
    required double left,
    required double top,
    required double width,
    required double height,
    required double pageWidth,
    required double pageHeight,
  }) {
    return ReceiptBoundingBoxEntity(
      left: pageWidth <= 0 ? 0 : left / pageWidth,
      top: pageHeight <= 0 ? 0 : top / pageHeight,
      width: pageWidth <= 0 ? 0 : width / pageWidth,
      height: pageHeight <= 0 ? 0 : height / pageHeight,
    );
  }

  String _documentText(List<ReceiptBlockEntity> blocks) {
    final lines = <ReceiptLineEntity>[
      for (final block in blocks) ...block.lines,
    ]..sort((a, b) => a.readingOrder.compareTo(b.readingOrder));
    return lines.map((line) => line.text).join('\n');
  }

  TextRecognitionScript _mlKitScriptFor(OcrLanguage language) {
    switch (language) {
      case OcrLanguage.japanese:
        return TextRecognitionScript.japanese;
      case OcrLanguage.chinese:
      case OcrLanguage.auto:
        return TextRecognitionScript.chinese;
      case OcrLanguage.english:
        return TextRecognitionScript.latin;
    }
  }

  // ─── Image preprocessing ─────────────────────────────────────────────────

  Future<File> _preprocessImageToFile(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('無法解碼圖片');

    final oriented = img.bakeOrientation(decoded);
    final resized =
        (oriented.width > _maxImageDimension ||
            oriented.height > _maxImageDimension)
        ? img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? _maxImageDimension : 0,
            height: oriented.height > oriented.width ? _maxImageDimension : 0,
          )
        : oriented;

    final enhanced = img.adjustColor(img.grayscale(resized), contrast: 1.4);

    final jpegBytes = Uint8List.fromList(img.encodeJpg(enhanced, quality: 92));
    final tmpDir = await getTemporaryDirectory();
    final tmpFile = File(
      '${tmpDir.path}/receipt_scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await tmpFile.writeAsBytes(jpegBytes);
    return tmpFile;
  }
}

class _OcrCandidateEvaluation {
  const _OcrCandidateEvaluation({
    required this.label,
    required this.text,
    required this.result,
    required this.descriptiveItemCount,
    required this.fallbackItemCount,
    required this.nameQualityScore,
    required this.stablePairCount,
    required this.score,
  });

  final String label;
  final String text;
  final ScanResultEntity result;
  final int descriptiveItemCount;
  final int fallbackItemCount;
  final int nameQualityScore;
  final int stablePairCount;
  final int score;
}

class _ReceiptParseAnalysis {
  const _ReceiptParseAnalysis({required this.result, required this.matches});

  final ScanResultEntity result;
  final List<_MatchedItemCandidate> matches;
}

class _MatchedItemCandidate {
  const _MatchedItemCandidate({
    required this.item,
    required this.priceType,
    required this.lineDistance,
    required this.candidateCount,
    required this.scoreMargin,
    required this.priceScore,
  });

  final ScanResultItemEntity item;
  final _PriceType priceType;
  final int lineDistance;
  final int candidateCount;
  final double scoreMargin;
  final double priceScore;
}
