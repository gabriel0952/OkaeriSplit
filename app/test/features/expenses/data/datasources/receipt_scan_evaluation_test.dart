import 'dart:io';

import 'package:app/features/expenses/data/datasources/receipt_scan_datasource.dart';
import 'package:app/features/expenses/domain/utils/receipt_scan_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Receipt OCR evaluation pipeline', () {
    final evaluator = ReceiptScanEvaluator();
    final datasource = ReceiptScanDatasource();

    late List<ReceiptOcrEvaluationSample> samples;

    setUpAll(() async {
      final fixtureFile = File(
        'test/fixtures/receipt_ocr_evaluation_samples.json',
      );
      samples = ReceiptOcrEvaluationSample.listFromJson(
        await fixtureFile.readAsString(),
      );
    });

    test('loads the fixed OCR evaluation sample set', () {
      expect(samples, hasLength(5));
      expect(samples.any((sample) => sample.id == 'retail-bad'), isTrue);
      expect(
        samples.any((sample) => sample.id == 'weak-column-retail'),
        isTrue,
      );
      expect(
        samples.any((sample) => sample.id == 'restaurant-order-slip'),
        isTrue,
      );
    });

    test('computes stable baseline metrics for names, amounts, and total', () {
      final report = evaluator.evaluateSamples(
        samples,
        parse: datasource.parseRecognizedText,
      );

      expect(report.sampleCount, 5);
      expect(report.totalHitRate, equals(1.0));
      expect(report.amountHitRate, greaterThanOrEqualTo(0.85));
      expect(report.itemNameHitRate, greaterThanOrEqualTo(0.68));
    });

    test('keeps high-risk samples in the fixed regression set', () {
      final report = evaluator.evaluateSamples(
        samples,
        parse: datasource.parseRecognizedText,
      );

      final badRetail = report.sampleById('retail-bad');
      expect(badRetail.lowConfidence, isTrue);
      expect(badRetail.itemNameHitRate, lessThan(1.0));

      final weakColumn = report.sampleById('weak-column-retail');
      expect(weakColumn.lowConfidence, isFalse);
      expect(weakColumn.itemNameHitRate, equals(1.0));

      final restaurant = report.sampleById('restaurant-order-slip');
      expect(restaurant.totalHit, isTrue);
      expect(restaurant.amountHitRate, greaterThanOrEqualTo(0.75));
    });
  });
}
