import AVFoundation
import Flutter
import MediaPlayer
import Photos
import UIKit
import UserNotifications

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
/// No lock-screen counting on iOS.
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
    case "setLockScreen":
      result(nil)
    case "takePending":
      result(0)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func click() {
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
      guard call.method == "openAppSettings",
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
