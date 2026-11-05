// What the widgets share with the app: the App Group's defaults, where the
// app writes the khatma's days (home_widget on iOS, the app's own channel on
// macOS) and where a widget button that must not open the app queues its
// action for the app to apply the next time it runs.

import AppIntents
import CoreText
import Foundation
import ImageIO
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

// MARK: - The app's interface look («شكل الواجهة»)
//
// The app draws each widget's frame as a picture in the App Group
// (lib/features/home_widgets/widget_art.dart) with a spec of slots beside
// it (`wl_<face>_<shape>_<style>_<mode>`): where the day's text goes, in
// which face, size and colour. The widget lays the day's text over the
// picture, so the day rolls over without the app. Without a picture (the
// app not opened since the update) a widget keeps its plain look.


enum LookStyleChoice: String, AppEnum {
  case app, handasi, layli, makhtuta

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Look"
  static var caseDisplayRepresentations: [LookStyleChoice: DisplayRepresentation] = [
    .app: DisplayRepresentation(title: "كما في التطبيق / As in the app"),
    .handasi: DisplayRepresentation(title: "هندسي / Geometric"),
    .layli: DisplayRepresentation(title: "ليلي ذهبي / Golden night"),
    .makhtuta: DisplayRepresentation(title: "مخطوطة / Manuscript"),
  ]
}

enum LookModeChoice: String, AppEnum {
  case app, light, night

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Mode"
  static var caseDisplayRepresentations: [LookModeChoice: DisplayRepresentation] = [
    .app: DisplayRepresentation(title: "كما في التطبيق / As in the app"),
    .light: DisplayRepresentation(title: "فاتح / Light"),
    .night: DisplayRepresentation(title: "ليلي / Night"),
  ]
}

/// A widget's look and mode, chosen in «تعديل الأداة» (Edit Widget).
struct WidgetLookIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "شكل الودجة / Widget look"

  @Parameter(title: "الشكل / Look", default: .app)
  var style: LookStyleChoice

  @Parameter(title: "الوضع / Mode", default: .app)
  var mode: LookModeChoice

  init() {}

  /// `layli_night`: the look to show, the app's where «كما في التطبيق».
  var variant: String {
    let app = (WidgetStore.defaults?.string(forKey: "wl_app") ?? "handasi_light")
      .split(separator: "_").map(String.init)
    let s = style == .app ? app[0] : style.rawValue
    let m = mode == .app ? (app.count > 1 ? app[1] : "light") : mode.rawValue
    return "\(s)_\(m)"
  }
}

enum LookShape: String {
  case small, medium
}

struct LookSlot {
  let id: String
  let rect: CGRect  // in shares of the picture
  let quran: Bool
  let size: CGFloat, min: CGFloat
  let weight: Int
  let color: Color
  let track: Color?
  let center: Bool
  let lines: Int
}

struct LookSpec {
  let image: CGImage
  let rtl: Bool
  let slots: [LookSlot]
  let taps: [String: CGRect]

  /// The picture for [face] in [variant]; else the same style's light or
  /// night; nil when the app has drawn none.
  static func load(face: String, shape: LookShape, variant: String) -> LookSpec? {
    let style = variant.split(separator: "_").first.map(String.init) ?? "handasi"
    let night = variant.hasSuffix("night") || variant.hasSuffix("black")
    for v in [variant, "\(style)_\(night ? "night" : "light")", "handasi_light"] {
      let key = "wl_\(face)_\(shape.rawValue)_\(v)"
      guard let raw = WidgetStore.defaults?.string(forKey: key),
        let json = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
        let file = json["file"] as? String,
        let url = WidgetStore.file(file),
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
      else { continue }
      let slots = (json["slots"] as? [[String: Any]] ?? []).map { s in
        LookSlot(
          id: s["id"] as? String ?? "",
          rect: CGRect(
            x: s["x"] as? Double ?? 0, y: s["y"] as? Double ?? 0,
            width: s["w"] as? Double ?? 0, height: s["h"] as? Double ?? 0),
          quran: (s["font"] as? String) == "quran",
          size: CGFloat(s["size"] as? Double ?? 0.07),
          min: CGFloat(s["min"] as? Double ?? 0.04),
          weight: s["weight"] as? Int ?? 400,
          color: Color(hex: s["color"] as? String),
          track: (s["track"] as? String).map { Color(hex: $0) },
          center: (s["align"] as? String) == "center",
          lines: s["lines"] as? Int ?? 1)
      }
      var taps: [String: CGRect] = [:]
      for (k, v) in json["taps"] as? [String: [Double]] ?? [:] where v.count == 4 {
        taps[k] = CGRect(x: v[0], y: v[1], width: v[2], height: v[3])
      }
      return LookSpec(image: image, rtl: json["rtl"] as? Bool ?? true, slots: slots, taps: taps)
    }
    return nil
  }
}

extension WidgetStore {
  /// A file the app wrote to the App Group (`home_widget/<name>`).
  static func file(_ name: String) -> URL? {
    guard
      let url = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: groupId)?
        .appendingPathComponent("home_widget/\(name)"),
      FileManager.default.fileExists(atPath: url.path)
    else { return nil }
    return url
  }

  private static var fontNames: [String: String] = [:]

  /// The PostScript name of the font the app copied as [key]
  /// (`wl_font_ui`: Changa, `wl_font_quran`: the mushaf's face),
  /// registered for this process on first use.
  static func font(_ key: String) -> String? {
    if let name = fontNames[key] { return name }
    guard let url = file("\(key).ttf"),
      let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL)
        as? [CTFontDescriptor],
      let first = descriptors.first,
      let name = CTFontDescriptorCopyAttribute(first, kCTFontNameAttribute) as? String
    else { return nil }
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    fontNames[key] = name
    return name
  }
}

extension Color {
  /// `#AARRGGBB`, as the app writes colours.
  init(hex: String?) {
    let v = UInt64((hex ?? "").dropFirst(), radix: 16) ?? 0xFFFF_FFFF
    self.init(
      .sRGB,
      red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
      blue: Double(v & 0xFF) / 255, opacity: Double((v >> 24) & 0xFF) / 255)
  }
}

/// A tap target over a part of the picture.
enum LookTap {
  case link(URL)
  case intent(any AppIntent)
}

/// The picture with the day's [texts] laid into its slots (`bar`: the
/// progress, 0 … 1, as text) and [taps] over its buttons.
struct LookCanvas: View {
  let spec: LookSpec
  let texts: [String: String]
  var taps: [String: LookTap] = [:]

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width, h = geo.size.height
      ZStack(alignment: .topLeading) {
        ForEach(Array(spec.slots.enumerated()), id: \.offset) { _, s in
          if let t = texts[s.id], !t.isEmpty {
            slot(s, t, w: w, h: h)
          }
        }
        ForEach(Array(taps.keys.sorted()), id: \.self) { k in
          if let r = spec.taps[k], let tap = taps[k] {
            target(tap)
              .frame(width: r.width * w, height: r.height * h)
              .position(x: (r.midX) * w, y: (r.midY) * h)
          }
        }
      }
      // The spec's places are left to right as drawn.
      .environment(\.layoutDirection, .leftToRight)
    }
  }

  @ViewBuilder private func target(_ tap: LookTap) -> some View {
    let area = Color.clear.contentShape(Rectangle())
    switch tap {
    case .link(let url): Link(destination: url) { area }
    case .intent(let intent): Button(intent: intent) { area }.buttonStyle(.plain)
    }
  }

  @ViewBuilder private func slot(_ s: LookSlot, _ t: String, w: CGFloat, h: CGFloat) -> some View {
    let frame = CGRect(
      x: s.rect.minX * w, y: s.rect.minY * h, width: s.rect.width * w, height: s.rect.height * h)
    if s.id == "bar" {
      let v = CGFloat(Double(t) ?? 0).clamped
      ZStack(alignment: spec.rtl ? .trailing : .leading) {
        Capsule().fill(s.track ?? .clear)
        Capsule().fill(s.color).frame(width: frame.width * v)
      }
      .frame(width: frame.width, height: frame.height)
      .position(x: frame.midX, y: frame.midY)
    } else {
      let size = s.size * h
      let name = WidgetStore.font(s.quran ? "wl_font_quran" : "wl_font_ui")
      Text(t)
        .font(name.map { Font.custom($0, fixedSize: size) } ?? .system(size: size))
        .fontWeight(s.weight >= 700 ? .bold : s.weight >= 600 ? .semibold : .regular)
        .foregroundColor(s.color)
        .multilineTextAlignment(s.center ? .center : .leading)
        .lineLimit(s.lines)
        .minimumScaleFactor(max(0.3, s.min / max(s.size, 0.001)))
        .environment(\.layoutDirection, spec.rtl ? .rightToLeft : .leftToRight)
        .frame(
          width: frame.width, height: frame.height,
          alignment: s.center ? .center : (spec.rtl ? .trailing : .leading))
        .position(x: frame.midX, y: frame.midY)
    }
  }
}

extension CGFloat {
  fileprivate var clamped: CGFloat { Swift.min(1, Swift.max(0, self)) }
}

/// The picture as the widget's ground, filling it.
struct LookGround: View {
  let spec: LookSpec
  var body: some View {
    Image(decorative: spec.image, scale: 1).resizable()
  }
}
