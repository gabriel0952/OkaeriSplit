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
          let text = (req.results as? [VNRecognizedTextObservation] ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
          result(text)
        }
        // ja first so kana is prioritised; zh-Hant covers Traditional Chinese
        request.recognitionLanguages = ["ja", "zh-Hant", "zh-Hans", "en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
      }
    }
  }
}
