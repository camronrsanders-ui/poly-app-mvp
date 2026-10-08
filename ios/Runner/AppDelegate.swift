import Flutter
import UIKit
import CoreLocation
#if canImport(DeclaredAgeRange)
import DeclaredAgeRange
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CLLocationManagerDelegate {
  private let ageAssuranceChannel = "com.polycircle.app/age_assurance"
  private let discoverLocationChannel = "com.polycircle.app/discover_location"
  private var discoverLocationManager: CLLocationManager?
  private var pendingDiscoverLocationResult: FlutterResult?
  private var discoverLocationTimeout: DispatchWorkItem?

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

    let locationChannel = FlutterMethodChannel(
      name: discoverLocationChannel,
      binaryMessenger: registrar.messenger()
    )
    locationChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "requestCurrentLocation":
        self?.requestDiscoverLocation(result: result)
      case "openLocationSettings":
        self?.openDiscoverLocationSettings(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func requestDiscoverLocation(result: @escaping FlutterResult) {
    guard pendingDiscoverLocationResult == nil else {
      result(FlutterError(
        code: "LOCATION_REQUEST_IN_PROGRESS",
        message: "A Discover location request is already active.",
        details: nil
      ))
      return
    }
    guard CLLocationManager.locationServicesEnabled() else {
      result(["status": "services_disabled"])
      return
    }

    let manager = discoverLocationManager ?? CLLocationManager()
    discoverLocationManager = manager
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyKilometer
    pendingDiscoverLocationResult = result

    let timeout = DispatchWorkItem { [weak self] in
      self?.completeDiscoverLocation(["status": "unavailable"])
    }
    discoverLocationTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)

    switch manager.authorizationStatus {
    case .notDetermined:
      manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse, .authorizedAlways:
      manager.requestLocation()
    case .denied:
      completeDiscoverLocation(["status": "denied"])
    case .restricted:
      completeDiscoverLocation(["status": "restricted"])
    @unknown default:
      completeDiscoverLocation(["status": "unavailable"])
    }
  }

  private func openDiscoverLocationSettings(result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }
    UIApplication.shared.open(url, options: [:]) { opened in
      result(opened)
    }
  }

  private func completeDiscoverLocation(_ payload: [String: Any]) {
    guard let result = pendingDiscoverLocationResult else { return }
    pendingDiscoverLocationResult = nil
    discoverLocationTimeout?.cancel()
    discoverLocationTimeout = nil
    discoverLocationManager?.stopUpdatingLocation()
    result(payload)
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard pendingDiscoverLocationResult != nil else { return }
    switch manager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      manager.requestLocation()
    case .denied:
      completeDiscoverLocation(["status": "denied"])
    case .restricted:
      completeDiscoverLocation(["status": "restricted"])
    case .notDetermined:
      break
    @unknown default:
      completeDiscoverLocation(["status": "unavailable"])
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last, location.horizontalAccuracy >= 0 else {
      completeDiscoverLocation(["status": "unavailable"])
      return
    }
    completeDiscoverLocation([
      "status": "ready",
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "accuracyMeters": location.horizontalAccuracy,
      "observedAtMs": Int(location.timestamp.timeIntervalSince1970 * 1000),
    ])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if let locationError = error as? CLError, locationError.code == .denied {
      completeDiscoverLocation(["status": "denied"])
      return
    }
    completeDiscoverLocation(["status": "unavailable"])
  }

  private func requestAdultAgeSignal(result: @escaping FlutterResult) {
#if canImport(DeclaredAgeRange)
    // isEligibleForAgeFeatures is available beginning with iOS 26.2. Keep the
    // entire privacy-preserving age-range path behind that availability check;
    // older OS versions return an explicit unavailable result to Flutter rather
    // than attempting an unsupported API.
    if #available(iOS 26.2, *) {
      Task { @MainActor in
        var regulatedRegion: Bool?
        do {
          regulatedRegion = try await AgeRangeService.shared.isEligibleForAgeFeatures
          guard let presenter = activeViewController() else {
            result([
              "status": "unavailable",
              "platformStatus": "no_presenting_view_controller",
              "regulatedRegion": regulatedRegion ?? true,
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
              "regulatedRegion": regulatedRegion ?? true,
            ]
            if let lower { payload["lowerBound"] = lower }
            if let upper { payload["upperBound"] = upper }
            result(payload)

          case .declinedSharing:
            result([
              "status": "not_shared",
              "platformStatus": "declined_sharing",
              "regulatedRegion": regulatedRegion ?? true,
            ])

          @unknown default:
            result([
              "status": "unavailable",
              "platformStatus": "unknown_response",
              "regulatedRegion": regulatedRegion ?? true,
            ])
          }
        } catch {
          // If eligibility itself failed, we do not know whether age assurance
          // is legally required for this account/region. Treat that uncertainty
          // as regulated so Flutter cannot silently downgrade to self-attested
          // DOB. If eligibility was positively known to be nonregulated before
          // a later request error, preserve false and allow the documented
          // fallback behavior.
          result([
            "status": "unavailable",
            "platformStatus": String(describing: error),
            "regulatedRegion": regulatedRegion ?? true,
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
