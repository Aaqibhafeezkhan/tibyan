import AVFoundation
import Flutter
import MediaPlayer
import Photos
import UIKit
import UserNotifications
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Pack-download notifications (background_downloader).
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    BackupExclusion.apply()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // «Save to Photos» for shared verse pictures, on whichever engine runs.
    PhotoSaverChannel.attach(engineBridge.applicationRegistrar.messenger())
    // The tasmee's «open device settings» when the microphone is off.
    AppSettingsChannel.attach(engineBridge.applicationRegistrar.messenger())
    // «المسبحة»: the bead's click and counting with the volume buttons.
    TasbihChannel.attach(engineBridge.applicationRegistrar.messenger())
    // «المزامنة» through the reader's iCloud.
    ICloudSyncChannel.attach(engineBridge.applicationRegistrar.messenger())
    // «الساعة»: today's portion and the dhikr to the Apple Watch app.
    WatchChannel.attach(engineBridge.applicationRegistrar.messenger())
    // CarPlay may have started the app first: the phone's view controller
    // then adopted the launch engine CarPlay set up (CarPlaySceneDelegate
    // .swift), whose plugins and car channel are already registered.
    if engineBridge.pluginRegistry.hasPlugin(CarPlayBridge.pluginKey) { return }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    CarPlayBridge.shared.attach(engineBridge.applicationRegistrar.messenger())
  }
}

/// «المسبحة»'s channel (`app.tibyan/tasbih`): the bundled click, and the
/// volume buttons counting while the misbaha asks. iOS tells an app of a
/// volume press only through the output volume changing, so the volume is
/// set back each time through a hidden system volume view (which also keeps
/// the volume HUD away), and kept off both ends so a press always moves it.
final class TasbihChannel: NSObject {
  private static var shared: TasbihChannel?
  private let channel: FlutterMethodChannel
  private var players: [AVAudioPlayer] = []
  private var next = 0
  private var observing = false
  private var resetting = false
  private var level: Float = 0.5
  private lazy var volumeView: MPVolumeView = {
    let v = MPVolumeView(frame: CGRect(x: -100, y: -100, width: 10, height: 10))
    v.alpha = 0.01
    v.isUserInteractionEnabled = false
    return v
  }()

  static func attach(_ messenger: FlutterBinaryMessenger) {
    let c = FlutterMethodChannel(name: "app.tibyan/tasbih", binaryMessenger: messenger)
    let me = TasbihChannel(channel: c)
    c.setMethodCallHandler { call, result in me.handle(call, result) }
    shared = me
  }

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  private func handle(_ call: FlutterMethodCall, _ result: FlutterResult) {
    switch call.method {
    case "click":
      click()
      result(nil)
    case "setVolumeKeys":
      setVolumeKeys((call.arguments as? Bool) ?? false)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func click() {
    do {
      if players.isEmpty {
        let key = FlutterDartProject.lookupKey(forAsset: "assets/tasbih/click.wav")
        guard let path = Bundle.main.path(forResource: key, ofType: nil) else { return }
        let url = URL(fileURLWithPath: path)
        players = (0..<3).compactMap { _ in try? AVAudioPlayer(contentsOf: url) }
        players.forEach { $0.prepareToPlay() }
      }
      guard !players.isEmpty else { return }
      let p = players[next % players.count]
      next += 1
      p.currentTime = 0
      p.play()
    } catch {}
  }

  private var slider: UISlider? {
    volumeView.subviews.compactMap { $0 as? UISlider }.first
  }

  private func setVolume(_ v: Float) {
    resetting = true
    slider?.value = v
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.resetting = false }
  }

  private func setVolumeKeys(_ on: Bool) {
    let session = AVAudioSession.sharedInstance()
    if on && !observing {
      try? session.setActive(true)
      let window = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.windows.first { $0.isKeyWindow } }.first
      window?.addSubview(volumeView)
      level = min(max(session.outputVolume, 0.1), 0.9)
      if level != session.outputVolume { setVolume(level) }
      session.addObserver(self, forKeyPath: "outputVolume", options: [.new], context: nil)
      observing = true
    } else if !on && observing {
      session.removeObserver(self, forKeyPath: "outputVolume")
      volumeView.removeFromSuperview()
      observing = false
    }
  }

  override func observeValue(
    forKeyPath keyPath: String?, of object: Any?,
    change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?
  ) {
    guard keyPath == "outputVolume", !resetting else { return }
    DispatchQueue.main.async {
      self.channel.invokeMethod("volumeKey", arguments: nil)
      self.setVolume(self.level)
    }
  }
}

/// Opens this app's page in the Settings app (the tasmee asks for the
/// microphone there once it was refused).
enum AppSettingsChannel {
  private static var channel: FlutterMethodChannel?

  static func attach(_ messenger: FlutterBinaryMessenger) {
    let c = FlutterMethodChannel(name: "app.tibyan/settings", binaryMessenger: messenger)
    c.setMethodCallHandler { call, result in
      // iOS has no public link to its Accessibility page: both open the
      // app's own page in Settings.
      guard call.method == "openAppSettings" || call.method == "openAccessibilitySettings",
        let url = URL(string: UIApplication.openSettingsURLString)
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      UIApplication.shared.open(url) { ok in result(ok) }
    }
    channel = c
  }
}

/// Saves PNG files to the Photos library («Save to Photos» of the shared
/// verse pictures), in a «Tibyan» album when the reader allows full
/// access (NSPhotoLibraryUsageDescription); with add-only access
/// (NSPhotoLibraryAddUsageDescription) they go to the library itself.
enum PhotoSaverChannel {
  private static var channel: FlutterMethodChannel?
  private static let album = "Tibyan"

  static func attach(_ messenger: FlutterBinaryMessenger) {
    let c = FlutterMethodChannel(name: "app.tibyan/photos", binaryMessenger: messenger)
    c.setMethodCallHandler { call, result in
      guard call.method == "saveImages",
        let args = call.arguments as? [String: Any],
        let paths = args["paths"] as? [String]
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      save(paths, result)
    }
    channel = c
  }

  private static func save(_ paths: [String], _ result: @escaping FlutterResult) {
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
      if status == .authorized {
        saveInAlbum(paths, result)
        return
      }
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        guard status == .authorized || status == .limited else {
          DispatchQueue.main.async { result(false) }
          return
        }
        PHPhotoLibrary.shared().performChanges({
          for path in paths {
            PHAssetCreationRequest.forAsset().addResource(
              with: .photo, fileURL: URL(fileURLWithPath: path), options: nil)
          }
        }) { ok, _ in
          DispatchQueue.main.async { result(ok) }
        }
      }
    }
  }

  /// The pictures, added to the «Tibyan» album (made the first time).
  private static func saveInAlbum(_ paths: [String], _ result: @escaping FlutterResult) {
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "title = %@", album)
    let existing = PHAssetCollection.fetchAssetCollections(
      with: .album, subtype: .any, options: options
    ).firstObject
    PHPhotoLibrary.shared().performChanges({
      let albumRequest =
        existing.flatMap { PHAssetCollectionChangeRequest(for: $0) }
        ?? PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: album)
      var added: [PHObjectPlaceholder] = []
      for path in paths {
        let request = PHAssetCreationRequest.forAsset()
        request.addResource(with: .photo, fileURL: URL(fileURLWithPath: path), options: nil)
        if let placeholder = request.placeholderForCreatedAsset { added.append(placeholder) }
      }
      albumRequest.addAssets(added as NSArray)
    }) { ok, _ in
      DispatchQueue.main.async { result(ok) }
    }
  }
}

/// Keeps what the app can download or copy again out of the device's
/// backups (iCloud / Finder on iOS, Time Machine on macOS): the content.db
/// copy, the mushaf packs, the audio, the timing updates and the tasmee
/// models all live under Application Support (path_provider's
/// getApplicationSupportDirectory). Excluding the folder excludes all it
/// will hold. The reader's own data stays backed up: user.sqlite is in
/// Documents, the settings in UserDefaults.
enum BackupExclusion {
  static func apply() {
    let fm = FileManager.default
    guard var url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else { return }
    try? fm.createDirectory(at: url, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? url.setResourceValues(values)
  }
}

/// «المزامنة» on Apple devices (`app.tibyan/icloud`, lib/core/sync/cloud/
/// icloud_store.dart): each device's sync file in the `Sync` folder of the
/// app's iCloud container, which the reader does not see in iCloud Drive.
/// A build without the iCloud capability has no container and says
/// `notInBuild`. Files not yet downloaded are asked for and read at a
/// later sync. Work runs off the main thread.
enum ICloudSyncChannel {
  static let containerId = "iCloud.app.tibyan.tibyan"
  private static let queue = DispatchQueue(label: "app.tibyan.icloud", qos: .utility)
  private static var channel: FlutterMethodChannel?

  static func attach(_ messenger: FlutterBinaryMessenger) {
    let c = FlutterMethodChannel(name: "app.tibyan/icloud", binaryMessenger: messenger)
    c.setMethodCallHandler { call, result in
      queue.async {
        let reply: Any?
        do {
          reply = try handle(call)
        } catch {
          reply = FlutterError(code: "icloud", message: error.localizedDescription, details: nil)
        }
        DispatchQueue.main.async { result(reply) }
      }
    }
    channel = c
  }

  private static func folder() -> URL? {
    guard FileManager.default.ubiquityIdentityToken != nil,
      let root = FileManager.default.url(forUbiquityContainerIdentifier: containerId)
    else { return nil }
    let dir = root.appendingPathComponent("Sync", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  private static func handle(_ call: FlutterMethodCall) throws -> Any? {
    switch call.method {
    case "status":
      if FileManager.default.ubiquityIdentityToken == nil { return "noAccount" }
      return folder() == nil ? "notInBuild" : "available"
    case "readAll":
      guard let dir = folder() else { throw SyncError.unavailable }
      var out: [String: String] = [:]
      let items = try FileManager.default.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey])
      for url in items {
        let name = url.lastPathComponent
        if name.hasPrefix("."), name.hasSuffix(".icloud") {
          // Not downloaded yet: asked for now, read at a later sync.
          let real = String(name.dropFirst().dropLast(".icloud".count))
          try? FileManager.default.startDownloadingUbiquitousItem(
            at: dir.appendingPathComponent(real))
          continue
        }
        guard name.hasPrefix("tibyan-sync-"), name.hasSuffix(".json") else { continue }
        let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
          .ubiquitousItemDownloadingStatus
        if status != nil, status != .current {
          try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
        if let text = coordinatedRead(url) { out[name] = text }
      }
      return out
    case "write":
      guard let dir = folder() else { throw SyncError.unavailable }
      guard let args = call.arguments as? [String: Any],
        let name = args["name"] as? String, let content = args["content"] as? String,
        name.hasPrefix("tibyan-sync-"), !name.contains("/")
      else { throw SyncError.badArguments }
      let url = dir.appendingPathComponent(name)
      var coordError: NSError?
      var writeError: Error?
      NSFileCoordinator(filePresenter: nil).coordinate(
        writingItemAt: url, options: .forReplacing, error: &coordError
      ) { target in
        do { try Data(content.utf8).write(to: target, options: .atomic) } catch {
          writeError = error
        }
      }
      if let e = coordError ?? writeError { throw e }
      return nil
    case "deleteAll":
      guard let dir = folder() else { throw SyncError.unavailable }
      let items = try FileManager.default.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: nil)
      for url in items {
        var coordError: NSError?
        var removeError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(
          writingItemAt: url, options: .forDeleting, error: &coordError
        ) { target in
          do { try FileManager.default.removeItem(at: target) } catch { removeError = error }
        }
        if let e = coordError ?? removeError { throw e }
      }
      return nil
    default:
      return FlutterMethodNotImplemented
    }
  }

  private static func coordinatedRead(_ url: URL) -> String? {
    var text: String?
    var coordError: NSError?
    NSFileCoordinator(filePresenter: nil).coordinate(
      readingItemAt: url, options: [], error: &coordError
    ) { target in
      text = try? String(contentsOf: target, encoding: .utf8)
    }
    return text
  }

  enum SyncError: LocalizedError {
    case unavailable, badArguments
    var errorDescription: String? {
      switch self {
      case .unavailable: return "iCloud is not available"
      case .badArguments: return "bad arguments"
      }
    }
  }
}

/// «الساعة» (`app.tibyan/watch`): what the Apple Watch app shows (today's
/// portion from the khatma widget keys, the current dhikr) goes to it as the
/// WatchConnectivity application context; counts made on the watch come back
/// as user info (queued, delivered even if the app was closed) and join the
/// misbaha's pending counts, like the home screen widget's (docs/WATCH.md).
final class WatchChannel: NSObject, WCSessionDelegate {
  private static var shared: WatchChannel?
  private static let group = "group.app.tibyan.tibyan"
  private static let pendingKey = "tasbih_pending"
  private let tasbih: FlutterMethodChannel
  /// Kept across launches so a dhikr update never drops the portion.
  private var context =
    UserDefaults.standard.dictionary(forKey: "watch_context") as? [String: String] ?? [:]

  static func attach(_ messenger: FlutterBinaryMessenger) {
    let me = WatchChannel(
      tasbih: FlutterMethodChannel(name: "app.tibyan/tasbih", binaryMessenger: messenger))
    shared = me
    FlutterMethodChannel(name: "app.tibyan/watch", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "push", let entries = call.arguments as? [String: String] else {
          result(FlutterMethodNotImplemented)
          return
        }
        me.push(entries)
        result(nil)
      }
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = me
    WCSession.default.activate()
  }

  private init(tasbih: FlutterMethodChannel) {
    self.tasbih = tasbih
  }

  private func push(_ entries: [String: String]) {
    // A new set of days replaces the old ones; the tap links stay on the phone.
    if entries["days"] != nil {
      context = context.filter { k, _ in
        !k.hasPrefix("portion_") && !k.hasPrefix("ref_")
      }
    }
    for (k, v) in entries where !k.hasPrefix("uri_") { context[k] = v }
    UserDefaults.standard.set(context, forKey: "watch_context")
    send()
  }

  private func send() {
    guard WCSession.isSupported() else { return }
    let s = WCSession.default
    guard s.activationState == .activated, s.isPaired, s.isWatchAppInstalled else { return }
    try? s.updateApplicationContext(context)
  }

  func session(
    _ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
    error: Error?
  ) {
    if state == .activated { DispatchQueue.main.async { self.send() } }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    // The reader switched watches: talk to the new one.
    session.activate()
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    guard let n = userInfo["tasbih_add"] as? Int, n > 0 else { return }
    DispatchQueue.main.async {
      let d = UserDefaults(suiteName: WatchChannel.group)
      d?.set((d?.integer(forKey: WatchChannel.pendingKey) ?? 0) + n, forKey: WatchChannel.pendingKey)
      self.tasbih.invokeMethod("pendingAdded", arguments: nil)
    }
  }
}
