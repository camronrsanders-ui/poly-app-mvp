import Flutter
import UIKit
#if canImport(DeclaredAgeRange)
import DeclaredAgeRange
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let ageAssuranceChannel = "com.polycircle.app/age_assurance"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "PolycircleAgeAssurance"
    ) else {
      return
    }
    let channel = FlutterMethodChannel(
      name: ageAssuranceChannel,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "requestAdultAgeSignal" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.requestAdultAgeSignal(result: result)
    }
  }

  private func requestAdultAgeSignal(result: @escaping FlutterResult) {
#if canImport(DeclaredAgeRange)
    // isEligibleForAgeFeatures is available beginning with iOS 26.2. Keep the
    // entire privacy-preserving age-range path behind that availability check;
    // older OS versions return an explicit unavailable result to Flutter rather
    // than attempting an unsupported API.
    if #available(iOS 26.2, *) {
      Task { @MainActor in
        do {
          let regulatedRegion = try await AgeRangeService.shared.isEligibleForAgeFeatures
          guard let presenter = activeViewController() else {
            result([
              "status": "unavailable",
              "platformStatus": "no_presenting_view_controller",
              "regulatedRegion": regulatedRegion,
            ])
            return
          }

          let response = try await AgeRangeService.shared.requestAgeRange(
            ageGates: 18,
            in: presenter
          )

          switch response {
          case let .sharing(ageRange):
            let lower = ageRange.lowerBound
            let upper = ageRange.upperBound
            let status: String
            if let upper, upper < 18 {
              status = "minor"
            } else if let lower, lower >= 18 {
              status = "adult"
            } else {
              status = "not_shared"
            }

            var payload: [String: Any] = [
              "status": status,
              "platformStatus": "shared",
              "regulatedRegion": regulatedRegion,
            ]
            if let lower { payload["lowerBound"] = lower }
            if let upper { payload["upperBound"] = upper }
            result(payload)

          case .declinedSharing:
            result([
              "status": "not_shared",
              "platformStatus": "declined_sharing",
              "regulatedRegion": regulatedRegion,
            ])

          @unknown default:
            result([
              "status": "unavailable",
              "platformStatus": "unknown_response",
              "regulatedRegion": regulatedRegion,
            ])
          }
        } catch {
          result([
            "status": "unavailable",
            "platformStatus": String(describing: error),
            "regulatedRegion": false,
          ])
        }
      }
      return
    }
#endif

    result([
      "status": "unavailable",
      "platformStatus": "declared_age_range_unavailable",
      "regulatedRegion": false,
    ])
  }

  @MainActor
  private func activeViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }

    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}
