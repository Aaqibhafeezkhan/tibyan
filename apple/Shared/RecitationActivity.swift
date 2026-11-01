// The recitation's Live Activity (iOS 16.2+): what the lock screen and the
// Dynamic Island show while a recitation plays. Compiled into the app and
// the actions widget extension, which draws it (RecitationLiveActivity
// .swift). Names and numbers only: the reciter, the surah, the verse
// number; never the Quran's text.

#if os(iOS)
import ActivityKit
import AppIntents
import Foundation

@available(iOS 16.1, *)
struct RecitationAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// The reciter's name, as the app shows it.
    var reciter: String
    /// «سورة الكهف» / "Surah Al-Kahf".
    var surah: String
    /// «الآية ١٠» / "Verse 10"; empty when the recitation has no timing.
    var verse: String
    var playing: Bool
    /// Accessibility labels of the play/pause button.
    var playLabel: String
    var pauseLabel: String
    var rtl: Bool
  }
}

extension Notification.Name {
  /// The Live Activity's play/pause button (handled by the app's channel).
  static let tibyanToggleRecitation = Notification.Name("app.tibyan.toggleRecitation")
}

/// Play/pause from the lock screen or the Dynamic Island (iOS 17+). A Live
/// Activity intent runs in the app's process, which is running anyway while
/// the recitation plays.
@available(iOS 17.0, *)
struct ToggleRecitationIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Play or pause"
  static var isDiscoverable = false

  func perform() async throws -> some IntentResult {
    await MainActor.run {
      NotificationCenter.default.post(name: .tibyanToggleRecitation, object: nil)
    }
    return .result()
  }
}
#endif
