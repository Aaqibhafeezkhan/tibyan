import Foundation
import WatchConnectivity
import WatchKit
import WidgetKit

/// The phone's data on the watch (the WatchConnectivity application
/// context, kept for when the phone is away) and the counts to send back.
@MainActor
final class WatchStore: NSObject, ObservableObject {
  @Published private(set) var entries: [String: String]
  /// Counts made in this sitting, shown on the misbaha.
  @Published private(set) var session = 0

  private let saved = UserDefaults(suiteName: "group.app.tibyan.tibyan") ?? UserDefaults.standard
  private var unsent = 0
  private var flush: Task<Void, Never>?

  override init() {
    entries = saved.dictionary(forKey: "context") as? [String: String] ?? [:]
    session = saved.integer(forKey: "session")
    super.init()
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
    }
  }

  var hasData: Bool { !entries.isEmpty }

  func value(_ key: String) -> String { entries[key] ?? "" }

  /// Today's entry of the portions the phone wrote ahead, if there is one.
  var today: (portion: String, reference: String)? {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    let key = f.string(from: Date())
    guard let portion = entries["portion_\(key)"], !portion.isEmpty else { return nil }
    return (portion, entries["ref_\(key)"] ?? "")
  }

  func count() {
    session += 1
    unsent += 1
    saved.set(session, forKey: "session")
    WKInterfaceDevice.current().play(.click)
    // Taps in a row go to the phone together.
    flush?.cancel()
    flush = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1.5))
      guard !Task.isCancelled else { return }
      self?.send()
    }
  }

  func resetSession() {
    send()
    session = 0
    saved.set(0, forKey: "session")
  }

  private func send() {
    guard unsent > 0, WCSession.isSupported(),
      WCSession.default.activationState == .activated
    else { return }
    // Queued by the system and delivered even when the phone is away now.
    WCSession.default.transferUserInfo(["tasbih_add": unsent])
    unsent = 0
  }

  fileprivate func apply(_ context: [String: Any]) {
    let strings = context.compactMapValues { $0 as? String }
    guard !strings.isEmpty else { return }
    entries = strings
    saved.set(strings, forKey: "context")
    UserDefaults.standard.set(strings, forKey: "context")
    WidgetCenter.shared.reloadAllTimelines()
  }
}

extension WatchStore: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
    error: Error?
  ) {
    let context = session.receivedApplicationContext
    Task { @MainActor in
      self.apply(context)
      self.send()
    }
  }

  nonisolated func session(
    _ session: WCSession, didReceiveApplicationContext context: [String: Any]
  ) {
    Task { @MainActor in self.apply(context) }
  }
}
