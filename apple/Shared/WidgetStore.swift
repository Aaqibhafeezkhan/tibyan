// What the widgets share with the app: the App Group's defaults, where the
// app writes the khatma's days (home_widget on iOS, the app's own channel on
// macOS) and where a widget button that must not open the app queues its
// action for the app to apply the next time it runs.

import Foundation
import SwiftUI

enum WidgetStore {
  /// The App Group of the app and its extensions. Read from the bundle's
  /// Info.plist (`AppGroupId`), so macOS's team-prefixed group is not
  /// written into the source.
  static var groupId: String {
    (Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String)
      ?? "group.app.tibyan.tibyan"
  }

  static var defaults: UserDefaults? { UserDefaults(suiteName: groupId) }

  /// `yyyy-MM-dd`, the day keys the app writes (`portion_2026-10-04`).
  static func dayKey(_ date: Date) -> String {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
  }

  /// Must match `pendingKey` in home_widget_sync.dart.
  static let pendingKey = "pending_actions"

  static func queue(_ action: String) {
    guard let d = defaults else { return }
    let now = d.string(forKey: pendingKey) ?? ""
    d.set(now.isEmpty ? action : now + "," + action, forKey: pendingKey)
  }

  /// The app's language as the app last wrote it (`lang`), else the
  /// device's: the widgets speak the app's language, not the system's.
  static var isArabic: Bool {
    let lang = defaults?.string(forKey: "lang") ?? Locale.preferredLanguages.first ?? "ar"
    return lang.hasPrefix("ar")
  }

  /// Arabic reads right to left whatever the device's language is.
  static var direction: LayoutDirection { isArabic ? .rightToLeft : .leftToRight }

  /// The widgets' few words, in the device's language.
  static func text(_ ar: String, _ en: String) -> String { isArabic ? ar : en }
}
