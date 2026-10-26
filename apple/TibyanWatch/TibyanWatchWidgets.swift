import SwiftUI
import WidgetKit

/// What the complication shows: today's portion of the khatma (the page
/// range, title, and the verse reference it starts at).
struct WirdComplicationEntry: TimelineEntry {
  let date: Date
  let title: String
  let portion: String
  let reference: String
}

struct WirdComplicationProvider: TimelineProvider {
  func placeholder(in context: Context) -> WirdComplicationEntry {
    WirdComplicationEntry(
      date: Date(),
      title: String(localized: "watch.wird.title"),
      portion: "ص ١ - ٤",
      reference: "البقرة: ١"
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (WirdComplicationEntry) -> Void) {
    completion(currentEntry(for: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<WirdComplicationEntry>) -> Void) {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var entries = [currentEntry(for: Date())]
    for i in 1..<14 {
      if let d = calendar.date(byAdding: .day, value: i, to: today) {
        entries.append(currentEntry(for: d))
      }
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }

  private func currentEntry(for date: Date) -> WirdComplicationEntry {
    let saved = UserDefaults(suiteName: "group.app.tibyan.tibyan") ?? UserDefaults.standard
    let dict = saved.dictionary(forKey: "context") as? [String: String] ?? [:]
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    let key = f.string(from: date)
    let portion = dict["portion_\(key)"] ?? dict["idle"] ?? String(localized: "watch.openPhone")
    let title = dict["title"] ?? String(localized: "watch.wird.title")
    let reference = dict["ref_\(key)"] ?? ""
    return WirdComplicationEntry(date: date, title: title, portion: portion, reference: reference)
  }
}

struct WirdComplicationView: View {
  var entry: WirdComplicationEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    switch family {
    case .accessoryInline:
      Text(entry.portion)
    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        VStack(spacing: 1) {
          Image(systemName: "book.fill")
            .font(.system(size: 13))
            .foregroundStyle(Color(red: 0.83, green: 0.70, blue: 0.42))
          Text(entry.portion)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
        }
      }
    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        Text(entry.title)
          .font(.caption.bold())
          .foregroundStyle(Color(red: 0.83, green: 0.70, blue: 0.42))
          .lineLimit(1)
        Text(entry.portion)
          .font(.footnote)
          .lineLimit(1)
        if !entry.reference.isEmpty {
          Text(entry.reference)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    case .accessoryCorner:
      Text(entry.portion)
        .font(.footnote.bold())
        .widgetLabel {
          Text(entry.title)
        }
    default:
      Text(entry.portion)
    }
  }
}

@main
struct TibyanWatchWidgets: WidgetBundle {
  var body: some Widget {
    TibyanWirdComplication()
  }
}

struct TibyanWirdComplication: Widget {
  let kind = "TibyanWirdComplication"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: WirdComplicationProvider()) { entry in
      WirdComplicationView(entry: entry)
    }
    .configurationDisplayName(Text("watch.wird.title"))
    .description(Text("watch.wird.desc"))
    .supportedFamilies([
      .accessoryInline,
      .accessoryCircular,
      .accessoryRectangular,
      .accessoryCorner,
    ])
  }
}
