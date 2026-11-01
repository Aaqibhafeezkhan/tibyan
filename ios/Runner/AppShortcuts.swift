// Siri, Spotlight and the Shortcuts app (iOS 16+): «open my daily wird»,
// «continue reading» and «open surah …» in Arabic and English (the phrases
// are in {ar,en}.lproj/AppShortcuts.strings). Each shortcut hands an
// existing `tibyan://` link to the app through `app.tibyan/shortcuts`
// (lib/core/platform/app_shortcuts.dart), so it is routed exactly as a
// widget tap or a verse link. The surah names come from the app's own
// content data, handed over at launch; nothing here names a surah itself.

import AppIntents
import Flutter
import UIKit

/// `app.tibyan/shortcuts`: links of shortcuts run, and the surah names.
final class ShortcutsChannel {
  private static var channel: FlutterMethodChannel?
  private static var ready = false
  private static var pending: String?
  static let surahsKey = "shortcuts.surahs"

  static func attach(_ messenger: FlutterBinaryMessenger) {
    let c = FlutterMethodChannel(name: "app.tibyan/shortcuts", binaryMessenger: messenger)
    c.setMethodCallHandler { call, result in
      switch call.method {
      case "ready":
        // The shortcut that launched the app, if one did.
        ready = true
        result(pending)
        pending = nil
      case "setSurahs":
        let list = (call.arguments as? [[String: Any]]) ?? []
        UserDefaults.standard.set(list, forKey: surahsKey)
        if #available(iOS 16.0, *) {
          TibyanShortcuts.updateAppShortcutParameters()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    channel = c
  }

  /// Opens [link] in the app now, or once it is ready.
  static func open(_ link: String) {
    if ready, let c = channel {
      c.invokeMethod("open", arguments: link)
    } else {
      pending = link
    }
  }
}

@available(iOS 16.0, *)
struct SurahEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Surah"
  static var defaultQuery = SurahQuery()

  let id: Int
  let nameAr: String
  let nameEn: String

  var name: String {
    (Locale.preferredLanguages.first ?? "ar").hasPrefix("ar") ? nameAr : nameEn
  }

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)")
  }

  /// The names the app handed over (its content data), in order.
  static var all: [SurahEntity] {
    let list = UserDefaults.standard.array(forKey: ShortcutsChannel.surahsKey) as? [[String: Any]]
    return (list ?? []).compactMap { d in
      guard let n = d["n"] as? Int, let ar = d["ar"] as? String, let en = d["en"] as? String
      else { return nil }
      return SurahEntity(id: n, nameAr: ar, nameEn: en)
    }
  }
}

@available(iOS 16.0, *)
struct SurahQuery: EntityStringQuery {
  func entities(for identifiers: [Int]) async throws -> [SurahEntity] {
    SurahEntity.all.filter { identifiers.contains($0.id) }
  }

  func suggestedEntities() async throws -> [SurahEntity] { SurahEntity.all }

  func entities(matching string: String) async throws -> [SurahEntity] {
    let fold: (String) -> String = {
      $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        .replacingOccurrences(of: "-", with: " ")
    }
    let q = fold(string.trimmingCharacters(in: .whitespaces))
    if let n = Int(q) { return SurahEntity.all.filter { $0.id == n } }
    return SurahEntity.all.filter { fold($0.nameAr).contains(q) || fold($0.nameEn).contains(q) }
  }
}

@available(iOS 16.0, *)
struct OpenDailyWirdIntent: AppIntent {
  static var title: LocalizedStringResource = "Open my daily wird"
  static var description = IntentDescription("Opens today's portion of your khatma.")
  static var openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    ShortcutsChannel.open("tibyan://reader")
    return .result()
  }
}

@available(iOS 16.0, *)
struct ContinueReadingIntent: AppIntent {
  static var title: LocalizedStringResource = "Continue reading"
  static var description = IntentDescription("Opens the mushaf where you stopped.")
  static var openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    ShortcutsChannel.open("tibyan://action/continue")
    return .result()
  }
}

@available(iOS 16.0, *)
struct OpenSurahIntent: AppIntent {
  static var title: LocalizedStringResource = "Open a surah"
  static var description = IntentDescription("Opens a surah in the mushaf.")
  static var openAppWhenRun = true

  @Parameter(title: "Surah")
  var surah: SurahEntity

  @MainActor
  func perform() async throws -> some IntentResult {
    ShortcutsChannel.open("tibyan://verse?s=\(surah.id)&a=1")
    return .result()
  }
}

@available(iOS 16.0, *)
struct TibyanShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: OpenDailyWirdIntent(),
      phrases: [
        "Open my daily wird in \(.applicationName)",
        "\(.applicationName) daily wird",
      ]
    )
    AppShortcut(
      intent: ContinueReadingIntent(),
      phrases: [
        "Continue reading in \(.applicationName)",
        "\(.applicationName) continue reading",
      ]
    )
    AppShortcut(
      intent: OpenSurahIntent(),
      phrases: [
        "Open \(\.$surah) in \(.applicationName)",
        "Open surah \(\.$surah) in \(.applicationName)",
      ]
    )
  }
}
