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

          var text = rows.map { row in
            row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
               .compactMap { $0.topCandidates(1).first?.string }
               .joined(separator: "  ")
          }.joined(separator: "\n")

          // Re-join numbers split at a thousands comma by Vision:
          // "4  ,455" → "4,455"
          if let regex = try? NSRegularExpression(pattern: #"(\d)\s+,(\d{3})"#) {
            let range = NSRange(text.startIndex..., in: text)
            text = regex.stringByReplacingMatches(
              in: text, range: range, withTemplate: "$1,$2")
          }

          result(text)
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
