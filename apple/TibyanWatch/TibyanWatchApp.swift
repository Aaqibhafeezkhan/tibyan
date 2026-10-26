import SwiftUI

/// «تبيان» on the Apple Watch: today's portion of the khatma and a
/// misbaha whose counts join the phone's current dhikr. Everything shown
/// comes from the phone (docs/WATCH.md); the watch adds no text of its own
/// beyond its labels.
@main
struct TibyanWatchApp: App {
  @StateObject private var store = WatchStore()

  var body: some Scene {
    WindowGroup {
      TabView {
        WirdView(store: store)
        TasbihView(store: store)
      }
      .tabViewStyle(.verticalPage)
    }
  }
}

/// Today's portion: the khatma title, the pages and where they start.
struct WirdView: View {
  @ObservedObject var store: WatchStore

  var body: some View {
    let today = store.today
    ScrollView {
      VStack(alignment: .leading, spacing: 6) {
        Text("watch.wird.title")
          .font(.footnote)
          .foregroundStyle(.secondary)
        if !store.hasData {
          Text("watch.openPhone")
            .font(.body)
        } else {
          Text(store.value("title"))
            .font(.headline)
          if let today {
            Text(today.portion)
              .font(.title3)
            if !today.reference.isEmpty {
              Text(today.reference)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          } else {
            Text(store.value("idle"))
              .font(.body)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
  }
}

/// A misbaha: tap to count. The counts go to the phone, which adds them to
/// its current dhikr the next time the misbaha opens there.
struct TasbihView: View {
  @ObservedObject var store: WatchStore

  var body: some View {
    VStack(spacing: 4) {
      Text(store.value("tasbih_dhikr").isEmpty
           ? String(localized: "watch.tasbih.title") : store.value("tasbih_dhikr"))
        .font(.footnote)
        .lineLimit(2)
        .multilineTextAlignment(.center)
      Button {
        store.count()
      } label: {
        Text(store.session.formatted())
          .font(.system(size: 44, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(Color(red: 0.72, green: 0.58, blue: 0.29))
      .accessibilityLabel(Text("watch.tasbih.count"))
      .accessibilityValue(Text(store.session.formatted()))
      Button("watch.tasbih.reset") { store.resetSession() }
        .font(.footnote)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 4)
  }
}
