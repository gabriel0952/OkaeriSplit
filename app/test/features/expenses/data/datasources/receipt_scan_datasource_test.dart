import 'dart:io';

import 'package:app/features/expenses/data/datasources/receipt_scan_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _badOcr = r'''
0S-6231-7800  淺草新仲見世
領吸需
登錄番号：T4120001130747
26/02/28/土21:57担098219任  No01:7013005585  端7013
：=LTAX FREE］=
＜消耗品>
4511413401972
本体  鞋：388K免税額  ，，380x  ¥2,760  ￥10
4511413404133
本体  ¥358（免税額  ¥28）
¥358
4987365015015
本体  ¥648（免税額  ¥64）
¥648
4987300052730
本体  ¥1,120（免税額  ¥112）
¥1,120
4974234619368
本体  ¥2,380（免税額  ¥238）
¥2.  380
4987306045156
本体  ¥1.276（免税額  ¥127）
小計 本体  ¥8，  ¥.  ，542  276
買上点数
10%刘象本体
10%消費稅
22翠杏体
8%消費祝
0%刘象本体
合  （免税額計  ¥8  •
QUICPay+
¥8.542
8%）印 減税率 象
们- a2税制刻象
29/0130055851
仰利
''';

const _goodOcr = r'''
ダイコクドラッグ  03-6231-7800  浅草新仲見世
領収書
登録番号：T4120001130747
26/02/28/土21:57担098219任  No01:7013005585  端7013
==［TAX FREE］=
＜消耗品＞
8860ニチブルーズ  リーエキス120ツブ
4511413401972
本体  ¥・388 免税額  1380x  ¥2,760  ¥110）
8％ビタミンC60ニチ
4511413404133
本体  ¥358 （免税額  ¥28）
¥358
ウオノメコロリバンソウコウアシュビ12マイ
4987365015015
本体  ¥648（免税額  ¥64）
¥648
★（$）イブタイック
4987300052730
本体  ¥1,120（免税額  ¥112）
サガミオリジナル00110P  ¥1,120
4974234619368
本体  ¥2,380（免税額  ¥238）
¥2，  380
★（$）パブロンゴールド”Aくビリュウ＞44ホウ
4987306045156
本体  ¥1,276（免税額  ¥127）
小計 本体  ¥8，  ¥1.1  ； 542  276
お買上点数
10%対象本体
10%消費税
88消費税
0%対象本体
合  ¥8
（免税額計
QUICPay+
¥8,542
''';

const _completeNamesOcr = r'''
領収書
ビタミンC60ニチ
¥358
サガミオリジナル00110P
¥1,120
合計
¥1,478
''';

const _noisyLongNamesOcr = r'''
領収書
ビタミンC60ニチ123456789XYZ
¥358
サガミ00110PABC999999
¥1,120
合計
¥1,478
''';

const _stablePairingOcr = r'''
領収書
ビタミンC60ニチ
¥358
サガミオリジナル00110P
¥1,120
合計
¥1,478
''';

const _unstableLongPairingOcr = r'''
領収書
ビタミンC60ニチ
358
12345678901234567890
ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890
サガミオリジナル00110P
1120
合計
1478
''';

const _restaurantOrderSlipOcr = r'''
桌B了  113年05月19日17點36分00秒  大人  4小孩  點餐員：客人  單號：1019
二 招牌起司漢堡牛  388%2 776
［標準］
口 明太子漢堡牛  428k 1
標準
口秘汁醬燒攤堡牛  378K  378
【標準］
口 日式炸肉餅  248X 1  248
【起司醬］
口炙燒香菇串  38X 1
口 炙燒雞腿串  SOX
口 炙燒撇瓜  50X1
原價小計：  1，.394
服務費：
實收金額：  2,193
''';

void main() {
  late Directory tempDir;
  late File imageFile;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('receipt-scan-test');
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    final image = img.Image(width: 12, height: 12);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    imageFile = File('${tempDir.path}/receipt-test.jpg');
    await imageFile.writeAsBytes(img.encodeJpg(image));
  });

  group('ReceiptScanDatasource OCR heuristics', () {
    final datasource = ReceiptScanDatasource();

    test('prefers OCR candidate with descriptive item names in auto mode', () {
      final best = datasource.selectBestVisionText({
        OcrLanguage.chinese: _badOcr,
        OcrLanguage.japanese: _goodOcr,
      });

      expect(best, equals(_goodOcr));
    });

    test('marks barcode fallback output as low confidence without 商品N', () {
      final result = datasource.parseRecognizedText(_badOcr);

      expect(result.lowConfidence, isTrue);
      expect(result.items.any((item) => item.name.startsWith('商品 ')), isFalse);
      expect(
        result.items.any(
          (item) => item.name.contains('登録番号') || item.name.contains('登錄番号'),
        ),
        isFalse,
      );
      expect(result.items.any((item) => item.name.startsWith('條碼 ')), isTrue);
    });

    test(
      'prefers candidate with more complete item names over longer noisy names',
      () {
        final best = datasource.selectBestVisionText({
          OcrLanguage.chinese: _noisyLongNamesOcr,
          OcrLanguage.japanese: _completeNamesOcr,
        });

        expect(best, equals(_completeNamesOcr));
      },
    );

    test(
      'prefers candidate with stable name price pairing over longer unstable OCR',
      () {
        final best = datasource.selectBestVisionText({
          OcrLanguage.chinese: _unstableLongPairingOcr,
          OcrLanguage.japanese: _stablePairingOcr,
        });

        expect(best, equals(_stablePairingOcr));
      },
    );

    test('runs OCR candidates for each scan request', () async {
      var ocrCallCount = 0;
      final datasourceWithLoader = ReceiptScanDatasource(
        preprocessImageLoader: (file) async {
          final copied = File(
            '${tempDir.path}/preprocessed-${DateTime.now().microsecondsSinceEpoch}.jpg',
          );
          await copied.writeAsBytes(await file.readAsBytes());
          return copied;
        },
        ocrCandidatesLoader: (_, language) async {
          ocrCallCount++;
          expect(language, OcrLanguage.auto);
          return {'ios:japanese:pass1': _goodOcr};
        },
      );

      final first = await datasourceWithLoader.scanReceipt(imageFile);
      final second = await datasourceWithLoader.scanReceipt(imageFile);

      expect(ocrCallCount, 2);
      expect(second.total, first.total);
      expect(second.lowConfidence, first.lowConfidence);
      expect(
        second.items.map((item) => item.name).toList(),
        first.items.map((item) => item.name).toList(),
      );
    });

    test('parses restaurant order slip items and filters header metadata', () {
      final result = datasource.parseRecognizedText(_restaurantOrderSlipOcr);

      expect(
        result.items.any(
          (item) =>
              item.name.contains('點餐員') ||
              item.name.contains('單號') ||
              item.name.contains('大人'),
        ),
        isFalse,
      );

      final burger = result.items.firstWhere(
        (item) => item.name.contains('招牌起司漢堡牛'),
      );
      expect(burger.amount, 776);
      expect(burger.quantity, 2);
      expect(burger.unitPrice, 388);

      final mentaiko = result.items.firstWhere(
        (item) => item.name.contains('明太子漢堡牛'),
      );
      expect(mentaiko.amount, 428);
      expect(mentaiko.quantity, 1);
      expect(mentaiko.unitPrice, 428);

      final croquette = result.items.firstWhere(
        (item) => item.name.contains('日式炸肉餅'),
      );
      expect(croquette.amount, 248);
      expect(croquette.quantity, 1);

      expect(result.items.any((item) => item.name.contains('炙燒香菇串')), isTrue);
      expect(result.items.any((item) => item.name.contains('炙燒撇瓜')), isTrue);
      expect(result.total, 2193);
    });
  });
}
