import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_ai/flutter_local_ai.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ReceiptScanDatasource {
  static const _maxImageDimension = 1280;
  static const _inferenceTimeout = Duration(seconds: 90);

  static const _instructions =
      'You are a receipt parser. Extract purchase information and output only valid JSON.';

  Future<ScanResultEntity> scanReceipt(File imageFile) async {
    File? tempFile;
    try {
      tempFile = await _preprocessImageToFile(imageFile);
      final ocrText = await _extractTextFromImage(tempFile);

      debugPrint('=== OCR OUTPUT ===\n$ocrText\n==================');

      final lines = ocrText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      // Parse each line into (name, numbers) — send only numbers to LLM
      final lineData = lines.map(_parseLineData).toList();

      final ai = FlutterLocalAi();
      await ai.initialize(instructions: _instructions);

      final response = await ai
          .generateTextSimple(
              prompt: _buildNumericPrompt(lineData), maxTokens: 1024)
          .timeout(_inferenceTimeout);

      debugPrint('=== LLM RESPONSE ===\n$response\n====================');

      return _parseNumericResponse(response, lineData);
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  // ─── Line data extraction ──────────────────────────────────────────────────

  /// Holds the name portion and all numbers found on a receipt line.
  ({String name, List<double> amounts}) _parseLineData(String line) {
    // Extract all numbers (including decimals)
    final numberPattern = RegExp(r'\d+(?:\.\d+)?');
    final amounts = numberPattern
        .allMatches(line)
        .map((m) => double.parse(m.group(0)!))
        .where((n) => n > 0)
        .toList();

    // Remove currency symbols, quantity markers, and numbers to get the name
    final name = line
        .replaceAll(RegExp(r'NT\$|JPY|¥|\$'), '')
        .replaceAll(RegExp(r'[x×]\s*\d+', caseSensitive: false), '')
        .replaceAll(numberPattern, '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    return (name: name, amounts: amounts);
  }

  // ─── Prompt ───────────────────────────────────────────────────────────────

  String _buildNumericPrompt(
      List<({String name, List<double> amounts})> lineData) {
    // Build numbered list with only the numeric content — no CJK characters
    final numbered = lineData.asMap().entries.map((e) {
      final nums = e.value.amounts;
      if (nums.isEmpty) return '[${e.key}] (no numbers)';
      return '[${e.key}] ${nums.join(', ')}';
    }).join('\n');

    return '''Parse this receipt and return ONLY valid JSON, no markdown, no explanation.

Output format:
{"total": <number>, "items": [{"line_index": <integer>, "amount": <number>, "quantity": <integer>}]}

Rules:
- total: the grand total (largest single number, or explicit total row)
- items: individual product lines only; exclude tax rows, subtotal rows, and the grand total row
- line_index: 0-based index from the list below
- amount: the line total for that item
- quantity: units purchased; default 1 if not shown
- If a line has multiple numbers, the larger one is usually the line total

Receipt lines (index: numbers only):
$numbered
''';
  }

  // ─── Response parsing ──────────────────────────────────────────────────────

  ScanResultEntity _parseNumericResponse(
      String response,
      List<({String name, List<double> amounts})> lineData) {
    try {
      var json = response.trim();
      json = json.replaceAll(RegExp(r'```[a-z]*\n?', caseSensitive: false), '');
      final start = json.indexOf('{');
      final end = json.lastIndexOf('}');
      if (start == -1 || end == -1) {
        return const ScanResultEntity(items: [], total: 0);
      }

      final map =
          jsonDecode(json.substring(start, end + 1)) as Map<String, dynamic>;

      final total = _toDouble(map['total']);
      final rawItems = (map['items'] as List?) ?? [];

      final items = rawItems.map((item) {
        final lineIndex = (item['line_index'] as num?)?.toInt() ?? -1;
        final amount = _toDouble(item['amount']);
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;

        // Map line index back to the original OCR text for the name
        final name = (lineIndex >= 0 && lineIndex < lineData.length)
            ? lineData[lineIndex].name
            : '';

        return ScanResultItemEntity(name: name, amount: amount, quantity: quantity);
      }).where((item) => item.amount > 0).toList();

      return ScanResultEntity(items: items, total: total);
    } catch (_) {
      return const ScanResultEntity(items: [], total: 0);
    }
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toDouble();
    return double.tryParse(
            val.toString().replaceAll(RegExp(r'[^\d.]'), '')) ??
        0;
  }

  // ─── OCR ──────────────────────────────────────────────────────────────────

  /// iOS: Apple Vision framework via method channel with explicit language list.
  /// Android: ML Kit dual-script (Chinese + Latin).
  Future<String> _extractTextFromImage(File imageFile) async {
    if (Platform.isIOS) {
      return _extractWithVision(imageFile);
    }
    return _extractWithMLKit(imageFile);
  }

  static const _visionChannel = MethodChannel('com.okaeri.native_ocr');

  Future<String> _extractWithVision(File imageFile) async {
    final text = await _visionChannel.invokeMethod<String>(
      'recognizeText',
      {'imagePath': imageFile.path},
    );
    return text ?? '';
  }

  Future<String> _extractWithMLKit(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final chineseRecognizer =
        TextRecognizer(script: TextRecognitionScript.chinese);
    final latinRecognizer =
        TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final results = await Future.wait([
        chineseRecognizer.processImage(inputImage),
        latinRecognizer.processImage(inputImage),
      ]);
      final chineseText = results[0].text.trim();
      final latinText = results[1].text.trim();
      if (latinText.isNotEmpty && latinText != chineseText) {
        return '$chineseText\n\n[Additional pass]\n$latinText';
      }
      return chineseText;
    } finally {
      await chineseRecognizer.close();
      await latinRecognizer.close();
    }
  }

  // ─── Image preprocessing ──────────────────────────────────────────────────

  Future<File> _preprocessImageToFile(File imageFile) async {
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

    final jpegBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 92));

    final tmpDir = await getTemporaryDirectory();
    final tmpFile = File(
      '${tmpDir.path}/receipt_scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await tmpFile.writeAsBytes(jpegBytes);
    return tmpFile;
  }
}
