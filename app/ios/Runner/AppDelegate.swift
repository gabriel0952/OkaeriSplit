import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeOCR") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.okaeri.native_ocr",
      binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognizeText",
        let args = call.arguments as? [String: Any],
        let imagePath = args["imagePath"] as? String,
        let image = UIImage(contentsOfFile: imagePath),
        let cgImage = image.cgImage
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments or image path", details: nil))
        return
      }

      DispatchQueue.global(qos: .userInitiated).async {
        let request = VNRecognizeTextRequest { req, error in
          if let error = error {
            result(FlutterError(code: "OCR_ERROR", message: error.localizedDescription, details: nil))
            return
          }
          let observations = (req.results as? [VNRecognizedTextObservation] ?? [])
            .sorted { $0.boundingBox.midY > $1.boundingBox.midY }

          // Adaptive threshold: 55% of the median observation height.
          // This keeps same-line fragments together while separating adjacent lines,
          // regardless of font size or receipt orientation.
          let heights = observations.map { $0.boundingBox.height }.sorted()
          let medianHeight: CGFloat = heights.isEmpty ? 0.02
              : heights[heights.count / 2]
          let yThreshold = medianHeight * 0.55

          var rows: [[VNRecognizedTextObservation]] = []
          for obs in observations {
            if let lastRow = rows.last,
               let lastObs = lastRow.last,
               abs(obs.boundingBox.midY - lastObs.boundingBox.midY) < yThreshold {
              rows[rows.count - 1].append(obs)
            } else {
              rows.append([obs])
            }
          }

          let linePayloads: [[String: Any]] = rows.enumerated().map { rowIndex, row in
            let sortedRow = row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            let wordPayloads: [[String: Any]] = sortedRow.enumerated().compactMap { wordIndex, observation in
              guard let candidate = observation.topCandidates(1).first else { return nil }
              return [
                "text": candidate.string,
                "reading_order": rowIndex * 1000 + wordIndex,
                "bounding_box": [
                  "left": observation.boundingBox.minX,
                  "top": 1 - observation.boundingBox.minY - observation.boundingBox.height,
                  "width": observation.boundingBox.width,
                  "height": observation.boundingBox.height
                ]
              ]
            }

            let text = wordPayloads
              .compactMap { $0["text"] as? String }
              .joined(separator: "  ")
            let minX = sortedRow.map { $0.boundingBox.minX }.min() ?? 0
            let maxX = sortedRow.map { $0.boundingBox.maxX }.max() ?? 0
            let minY = sortedRow.map { $0.boundingBox.minY }.min() ?? 0
            let maxY = sortedRow.map { $0.boundingBox.maxY }.max() ?? 0

            return [
              "text": text,
              "reading_order": rowIndex,
              "bounding_box": [
                "left": minX,
                "top": 1 - maxY,
                "width": maxX - minX,
                "height": maxY - minY
              ],
              "words": wordPayloads
            ]
          }

          var text = linePayloads
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")

          // Re-join numbers split at a thousands comma by Vision:
          // "4  ,455" → "4,455"
          if let regex = try? NSRegularExpression(pattern: #"(\d)\s+,(\d{3})"#) {
            let range = NSRange(text.startIndex..., in: text)
            text = regex.stringByReplacingMatches(
              in: text, range: range, withTemplate: "$1,$2")
          }

          let payload: [String: Any] = [
            "text": text,
            "page_width": cgImage.width,
            "page_height": cgImage.height,
            "blocks": [[
              "text": text,
              "reading_order": 0,
              "bounding_box": [
                "left": 0,
                "top": 0,
                "width": 1,
                "height": 1
              ],
              "lines": linePayloads
            ]]
          ]

          result(payload)
        }
        // Language priority based on caller hint
        let lang = args["language"] as? String ?? "auto"
        switch lang {
        case "chinese":
          request.recognitionLanguages = ["zh-Hant", "zh-Hans", "ja", "en-US"]
        case "english":
          request.recognitionLanguages = ["en-US", "zh-Hant", "zh-Hans", "ja"]
        default: // "auto" or "japanese"
          request.recognitionLanguages = ["ja", "zh-Hant", "zh-Hans", "en-US"]
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
      }
    }
  }
}
