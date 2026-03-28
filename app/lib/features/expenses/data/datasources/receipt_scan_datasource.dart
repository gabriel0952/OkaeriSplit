import 'dart:io';

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

      debugPrint(
        '=== OCR OUTPUT (${bestEvaluation.label}) ===\n'
        '${bestEvaluation.text}\n'
        '==================',
      );

      final ruleResult = bestEvaluation.result;
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

  Future<Map<String, String>> _collectOcrCandidates(
    File imageFile, {
    required OcrLanguage language,
  }) async {
    final ocrCandidatesLoader = _ocrCandidatesLoader;
    if (ocrCandidatesLoader != null) {
      return ocrCandidatesLoader(imageFile, language);
    }

    if (Platform.isIOS) {
      return _collectVisionCandidates(imageFile, language: language);
    }
    return _collectMlKitCandidates(imageFile, language: language);
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
    r'合計|小計|帳單|金額|消費税|税込|税額|免税|対象|お預り|お釣|現金|お支払|'
    r'支払|点数|ご請求額|お会計|QUICPay|登録番号|電話|TEL|http|www\.|'
    r'TAX FREE|TOTAL|SUBTOTAL|領収書|レシート|消耗品|商店',
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
    r'合計|小計|原價小計|原价小计|帳單|総計|計[:：$]|實收金額|实收金额|應收金額|应收金额|'
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
    r'桌[A-Za-z0-9一二三四五六七八九十]|服務費|服务费',
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

  double? _parseNum(String raw) {
    final s = _nfkc(raw).replaceAll(RegExp(r'[,，]'), '');
    if (s.length > 1 && s.startsWith('0') && !s.contains('.')) return null;
    final n = double.tryParse(s);
    if (n == null || n <= 0 || n > 99999) return null;
    return n;
  }

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

  Future<Map<String, String>> _collectVisionCandidates(
    File imageFile, {
    required OcrLanguage language,
  }) async {
    final candidates = <String, String>{};
    final languages = language == OcrLanguage.auto
        ? const [OcrLanguage.japanese, OcrLanguage.chinese, OcrLanguage.english]
        : [language];

    for (var pass = 1; pass <= _ocrPassCount; pass++) {
      for (final candidateLanguage in languages) {
        final text = await _recognizeVisionText(
          imageFile,
          language: candidateLanguage,
        );
        if (text.trim().isEmpty) continue;
        candidates['ios:${candidateLanguage.name}:pass$pass'] = text;
      }
    }

    if (candidates.isEmpty) {
      final fallback = await _recognizeVisionText(
        imageFile,
        language: languages.first,
      );
      if (fallback.trim().isNotEmpty) {
        candidates['ios:${languages.first.name}:fallback'] = fallback;
      }
    }

    return candidates;
  }

  Future<String> _recognizeVisionText(
    File imageFile, {
    required OcrLanguage language,
  }) async {
    final text = await _visionChannel.invokeMethod<String>('recognizeText', {
      'imagePath': imageFile.path,
      'language': language.name,
    });
    return text ?? '';
  }

  @visibleForTesting
  ScanResultEntity parseRecognizedText(String ocrText) {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return _parseWithRules(lines).result;
  }

  @visibleForTesting
  String selectBestVisionText(Map<OcrLanguage, String> candidates) {
    final labeled = {
      for (final entry in candidates.entries) entry.key.name: entry.value,
    };
    return _selectBestOcrEvaluation(labeled).text;
  }

  _OcrCandidateEvaluation _selectBestOcrEvaluation(
    Map<String, String> candidates,
  ) {
    final evaluations =
        candidates.entries
            .map((entry) => _evaluateOcrCandidate(entry.key, entry.value))
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

  Future<Map<String, String>> _collectMlKitCandidates(
    File imageFile, {
    required OcrLanguage language,
  }) async {
    final candidates = <String, String>{};
    for (var pass = 1; pass <= _ocrPassCount; pass++) {
      final text = await _extractWithMLKit(imageFile, language: language);
      if (text.trim().isNotEmpty) {
        candidates['android:${language.name}:pass$pass'] = text;
      }
    }
    return candidates;
  }

  Future<String> _extractWithMLKit(
    File imageFile, {
    OcrLanguage language = OcrLanguage.auto,
  }) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizer = TextRecognizer(script: _mlKitScriptFor(language));
    try {
      final recognized = await recognizer.processImage(inputImage);

      final allLines = recognized.blocks.expand((b) => b.lines).toList();
      if (allLines.isEmpty) return recognized.text;

      allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

      const yThreshold = 15.0;
      final rows = <List<dynamic>>[];
      for (final line in allLines) {
        final top = line.boundingBox.top.toDouble();
        if (rows.isEmpty ||
            top - rows.last.last.boundingBox.top.toDouble() > yThreshold) {
          rows.add([line]);
        } else {
          rows.last.add(line);
        }
      }

      return rows
          .map((row) {
            row.sort(
              (a, b) => a.boundingBox.left.compareTo(b.boundingBox.left),
            );
            return row.map((l) => l.text as String).join('  ');
          })
          .join('\n');
    } finally {
      await recognizer.close();
    }
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
