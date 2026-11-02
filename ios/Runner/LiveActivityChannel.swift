// `app.tibyan/live_activity`: the recitation's Live Activity, started,
// updated and ended by the app's audio (lib/features/audio/live_activity
// .dart). iOS 16.2+ only; on older systems, or with Live Activities turned
// off, every call does nothing. It never touches the audio session: the
// recitation plays exactly as without it.

import ActivityKit
import Flutter
import Foundation

final class LiveActivityChannel {
  private static var channel: FlutterMethodChannel?
  private static var observer: NSObjectProtocol?

  static func attach(_ messenger: FlutterBinaryMessenger) {
    let c = FlutterMethodChannel(name: "app.tibyan/live_activity", binaryMessenger: messenger)
    c.setMethodCallHandler { call, result in
      guard #available(iOS 16.2, *) else { return result(false) }
      switch call.method {
      case "update":
        guard let map = call.arguments as? [String: Any] else { return result(false) }
        RecitationActivities.show(state(map))
        result(true)
      case "end":
        RecitationActivities.end()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    channel = c
    if observer == nil {
      // The Live Activity's buttons (RecitationActivity.swift's intents).
      observer = NotificationCenter.default.addObserver(
        forName: .tibyanRecitationCommand, object: nil, queue: .main
      ) { note in
        guard let command = note.object as? String,
          ["toggle", "previous", "next"].contains(command)
        else { return }
        channel?.invokeMethod(command, arguments: nil)
      }
    }
  }

  @available(iOS 16.1, *)
  private static func state(_ m: [String: Any]) -> RecitationAttributes.ContentState {
    RecitationAttributes.ContentState(
      reciter: m["reciter"] as? String ?? "",
      surah: m["surah"] as? String ?? "",
      verse: m["verse"] as? String ?? "",
      playing: m["playing"] as? Bool ?? false,
      playLabel: m["playLabel"] as? String ?? "",
      pauseLabel: m["pauseLabel"] as? String ?? "",
      rtl: m["rtl"] as? Bool ?? true,
      ayah: m["ayah"] as? Int ?? 0,
      ayahCount: m["ayahCount"] as? Int ?? 0,
      previousLabel: m["previousLabel"] as? String ?? "",
      nextLabel: m["nextLabel"] as? String ?? ""
    )
  }
}

@available(iOS 16.2, *)
enum RecitationActivities {
  /// Starts the activity, or updates the one running.
  static func show(_ state: RecitationAttributes.ContentState) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let content = ActivityContent(state: state, staleDate: nil)
    let running = Activity<RecitationAttributes>.activities
    if let current = running.first {
      // One at a time: any other left from an earlier run goes.
      for extra in running.dropFirst() {
        Task { await extra.end(nil, dismissalPolicy: .immediate) }
      }
      Task { await current.update(content) }
      return
    }
    do {
      _ = try Activity.request(attributes: RecitationAttributes(), content: content, pushType: nil)
    } catch {
      // Not allowed now (e.g. requested from the background): the next
      // update tries again.
    }
  }

  static func end() {
    for a in Activity<RecitationAttributes>.activities {
      Task { await a.end(nil, dismissalPolicy: .immediate) }
    }
  }
}
