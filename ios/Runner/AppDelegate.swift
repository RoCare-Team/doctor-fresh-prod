import CoreLocation
import Flutter
import SafariServices
import UIKit
import UniformTypeIdentifiers
import UserNotifications

/// The native side of lib/core/native.dart, written with UIKit alone (no
/// plugin packages):
///
///   openUrl  { url }          → Safari, the dialer (tel:), Mail, WhatsApp
///   share    { text }         → the share sheet
///   openFile { path, mime }   → a PDF in the system preview
///   pickFile                  → the document picker; the file is copied to tmp
///   location                  → asks for location permission, then { lat, lon }
///                               or { error: denied | off | unavailable }
///   openInApp { url }         → a secure in-app sheet (payment); answers on close
///   requestNotifications      → asks to show notifications
///   schedule { id, at, title, body, route } / cancel { id }
///                             → local reminders (purifier service, filter change)
///   takeLaunchRoute           → the screen a tapped reminder asked for, once
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let native = DFNative()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = native
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DFNative") {
      native.attach(messenger: registrar.messenger())
    }
  }
}

final class DFNative: NSObject, UIDocumentPickerDelegate, UIDocumentInteractionControllerDelegate, CLLocationManagerDelegate,
  SFSafariViewControllerDelegate, UNUserNotificationCenterDelegate {
  private var channel: FlutterMethodChannel?
  private var pendingSheet: FlutterResult?
  private var launchRoute: String?
  private let locator = CLLocationManager()
  private var pendingLocation: FlutterResult?
  private var pendingPick: FlutterResult?
  private var preview: UIDocumentInteractionController?

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "in.doctorfresh.app/native", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "openUrl": self.openUrl(args["url"] as? String ?? "", result)
      case "share": self.share(args["text"] as? String ?? "", result)
      case "openFile": self.openFile(args["path"] as? String ?? "", result)
      case "pickFile": self.pickFile(result)
      case "location": self.location(result)
      case "openInApp": self.openInApp(args["url"] as? String ?? "", result)
      case "requestNotifications": self.requestNotifications(result)
      case "schedule": self.schedule(args, result)
      case "cancel":
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["df-\(args["id"] as? Int ?? 0)"])
        result(nil)
      case "takeLaunchRoute":
        result(self.launchRoute ?? "")
        self.launchRoute = nil
      default: result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  /// The view controller on top, to present sheets from.
  private func topController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  private func openUrl(_ value: String, _ result: @escaping FlutterResult) {
    guard let url = URL(string: value) else { return result(false) }
    UIApplication.shared.open(url, options: [:]) { ok in result(ok) }
  }

  private func share(_ text: String, _ result: @escaping FlutterResult) {
    guard let top = topController() else { return result(false) }
    let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
    sheet.popoverPresentationController?.sourceView = top.view
    top.present(sheet, animated: true)
    result(true)
  }

  private func openFile(_ path: String, _ result: @escaping FlutterResult) {
    guard FileManager.default.fileExists(atPath: path) else { return result(false) }
    let controller = UIDocumentInteractionController(url: URL(fileURLWithPath: path))
    controller.delegate = self
    preview = controller
    result(controller.presentPreview(animated: true))
  }

  func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
    return topController() ?? UIViewController()
  }

  private func pickFile(_ result: @escaping FlutterResult) {
    guard let top = topController() else { return result(nil) }
    pendingPick = result
    let types: [UTType] = [.pdf, .jpeg, .png, .image, UTType("com.microsoft.word.doc") ?? .data, UTType("org.openxmlformats.wordprocessingml.document") ?? .data]
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
    picker.delegate = self
    top.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingPick else { return }
    pendingPick = nil
    guard let url = urls.first else { return result(nil) }
    let dest = FileManager.default.temporaryDirectory.appendingPathComponent("pick_\(Int(Date().timeIntervalSince1970))_\(url.lastPathComponent)")
    do {
      try? FileManager.default.removeItem(at: dest)
      try FileManager.default.copyItem(at: url, to: dest)
      let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
      result(["path": dest.path, "name": url.lastPathComponent, "mime": mime])
    } catch {
      result(nil)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingPick?(nil)
    pendingPick = nil
  }

  // MARK: in-app sheet

  private func openInApp(_ value: String, _ result: @escaping FlutterResult) {
    guard let url = URL(string: value), url.scheme == "https", let top = topController() else { return result(false) }
    pendingSheet?(true)
    pendingSheet = result
    let sheet = SFSafariViewController(url: url)
    sheet.delegate = self
    sheet.dismissButtonStyle = .close
    sheet.preferredControlTintColor = UIColor(red: 0, green: 0.584, blue: 0.863, alpha: 1)
    top.present(sheet, animated: true)
  }

  func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
    pendingSheet?(true)
    pendingSheet = nil
  }

  // MARK: reminders

  private func requestNotifications(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
      DispatchQueue.main.async { result(granted) }
    }
  }

  private func schedule(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard let id = args["id"] as? Int, let at = (args["at"] as? NSNumber)?.doubleValue else { return result(false) }
    let content = UNMutableNotificationContent()
    content.title = args["title"] as? String ?? "Doctor Fresh"
    content.body = args["body"] as? String ?? ""
    content.sound = .default
    content.userInfo = ["route": args["route"] as? String ?? ""]
    let seconds = max(at / 1000 - Date().timeIntervalSince1970, 5)
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
    let request = UNNotificationRequest(identifier: "df-\(id)", content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request) { error in
      DispatchQueue.main.async { result(error == nil) }
    }
  }

  /// A reminder that arrives while the app is open still shows as a banner.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound, .list])
  }

  /// Tapped: the app opens the screen the reminder is about.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let route = response.notification.request.content.userInfo["route"] as? String ?? ""
    if !route.isEmpty {
      if let channel = channel {
        channel.invokeMethod("openRoute", arguments: route)
      } else {
        launchRoute = route
      }
    }
    completionHandler()
  }

  // MARK: location

  private func location(_ result: @escaping FlutterResult) {
    if pendingLocation != nil { return result(["error": "busy"]) }
    guard CLLocationManager.locationServicesEnabled() else { return result(["error": "off"]) }
    pendingLocation = result
    locator.delegate = self
    locator.desiredAccuracy = kCLLocationAccuracyHundredMeters
    switch locator.authorizationStatus {
    case .notDetermined: locator.requestWhenInUseAuthorization()
    case .denied, .restricted: finishLocation(["error": "denied"])
    default: locator.requestLocation()
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard pendingLocation != nil else { return }
    switch manager.authorizationStatus {
    case .notDetermined: break
    case .denied, .restricted: finishLocation(["error": "denied"])
    default: manager.requestLocation()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let spot = locations.last else { return }
    finishLocation(["lat": spot.coordinate.latitude, "lon": spot.coordinate.longitude])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    finishLocation(["error": "unavailable"])
  }

  private func finishLocation(_ value: [String: Any]) {
    pendingLocation?(value)
    pendingLocation = nil
  }
}
