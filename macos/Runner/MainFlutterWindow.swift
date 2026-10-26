import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    // «المزامنة» through the reader's iCloud.
    ICloudSyncChannel.attach(flutterViewController.engine.binaryMessenger)
    VideoEncoderChannel.attach(flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  // Hidden until Dart has restored the last size and place
  // (lib/core/ui/desktop_window.dart), so the window does not jump.
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
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
