import SwiftUI
import WatchKit

/// Colors of the «ليل هندسي» look (handoff 10).
enum Look {
  static let teal = Color(red: 0x0E / 255.0, green: 0x5F / 255.0, blue: 0x58 / 255.0)
  static let deep = Color(red: 0x06 / 255.0, green: 0x30 / 255.0, blue: 0x2C / 255.0)
  static let night = Color(red: 0x02 / 255.0, green: 0x0C / 255.0, blue: 0x0B / 255.0)
  static let cream = Color(red: 0xF4 / 255.0, green: 0xEC / 255.0, blue: 0xD8 / 255.0)
  static let gold = Color(red: 0xD9 / 255.0, green: 0xB2 / 255.0, blue: 0x66 / 255.0)
  static let track = Color(red: 0xD9 / 255.0, green: 0xB2 / 255.0, blue: 0x66 / 255.0).opacity(0.16)
}

/// Star shape for the Girih pattern.
struct StarShape: Shape {
  let points: Int
  let inner: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let cx = rect.midX
    let cy = rect.midY
    let r = min(rect.width, rect.height) / 2
    let total = points * 2
    for i in 0..<total {
      let radius = (i % 2 == 0) ? r : r * inner
      let a = -Double.pi / 2 + Double(i) * Double.pi / Double(points)
      let pt = CGPoint(x: cx + CGFloat(cos(a)) * radius, y: cy + CGFloat(sin(a)) * radius)
      if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
    }
    path.closeSubpath()
    return path
  }
}

/// Background with radial gradient and the Islamic Girih geometric pattern.
struct WatchNightBackground: View {
  var body: some View {
    ZStack {
      RadialGradient(
        colors: [Look.teal, Look.deep, Look.night],
        center: .top,
        startRadius: 0,
        endRadius: 180
      )
      Canvas { context, size in
        let cell: CGFloat = 80
        var y: CGFloat = 0
        while y < size.height + cell {
          var x: CGFloat = 0
          while x < size.width + cell {
            let r8 = CGRect(x: x - cell * 0.25, y: y - cell * 0.25, width: cell * 0.5, height: cell * 0.5)
            context.stroke(
              StarShape(points: 8, inner: 0.72).path(in: r8),
              with: .color(Look.cream.opacity(0.13)),
              lineWidth: 1
            )
            let r4 = CGRect(x: x + cell * 0.5 - cell * 0.11, y: y + cell * 0.5 - cell * 0.11, width: cell * 0.22, height: cell * 0.22)
            context.stroke(
              StarShape(points: 4, inner: 0.45).path(in: r4),
              with: .color(Look.cream.opacity(0.13)),
              lineWidth: 1
            )
            x += cell
          }
          y += cell
        }
      }
    }
    .ignoresSafeArea()
  }
}

/// Edge progress ring (gold over track).
struct EdgeProgressRing: View {
  var progress: Double

  var body: some View {
    Circle()
      .stroke(Look.track, lineWidth: 5)
      .overlay(
        Circle()
          .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
          .stroke(Look.gold, style: StrokeStyle(lineWidth: 5, lineCap: .round))
          .rotationEffect(.degrees(-90))
      )
      .padding(4)
      .ignoresSafeArea()
  }
}

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
      .background(WatchNightBackground())
    }
  }
}

/// Today's portion: «ورد اليوم» with khatma progress ring.
struct WirdView: View {
  @ObservedObject var store: WatchStore

  var body: some View {
    ZStack {
      EdgeProgressRing(progress: store.progress)

      if !store.hasData {
        emptyView
      } else {
        wirdContentView
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var emptyView: some View {
    VStack(spacing: 8) {
      Image(systemName: "book.fill")
        .font(.system(size: 28))
        .foregroundStyle(Look.gold)
      Text("watch.openPhone")
        .font(.footnote)
        .foregroundStyle(Look.cream)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
    }
  }

  private var wirdContentView: some View {
    let today = store.today
    return VStack(spacing: 4) {
      Text(store.value("title"))
        .font(.caption2.bold())
        .foregroundStyle(Look.gold)
        .lineLimit(1)

      if let today {
        Text(today.portion)
          .font(.system(size: 24, weight: .bold, design: .rounded))
          .foregroundStyle(Look.cream)
          .minimumScaleFactor(0.7)
          .lineLimit(1)

        if !today.reference.isEmpty {
          Text(today.reference)
            .font(.caption2)
            .foregroundStyle(Look.cream.opacity(0.7))
            .lineLimit(1)
        }

        if store.progress > 0 {
          Text(String(format: "%.0f%%", store.progress * 100))
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Look.gold)
            .padding(.top, 2)
        }
      } else {
        Text(store.value("idle"))
          .font(.footnote)
          .foregroundStyle(Look.cream)
          .multilineTextAlignment(.center)
      }

      Image(systemName: "chevron.compact.down")
        .font(.caption2)
        .foregroundStyle(Look.gold.opacity(0.7))
        .padding(.top, 4)
    }
    .padding(.horizontal, 20)
  }
}

/// A misbaha: tap anywhere or rotate the digital crown to count.
struct TasbihView: View {
  @ObservedObject var store: WatchStore
  @State private var crownAccumulator: Double = 0
  @State private var showResetSheet = false

  var ringProgress: Double {
    let target = store.target
    if target > 0 {
      let current = store.session % target
      return current == 0 && store.session > 0 ? 1.0 : Double(current) / Double(target)
    }
    return 0
  }

  var body: some View {
    ZStack {
      EdgeProgressRing(progress: ringProgress)

      VStack(spacing: 2) {
        let dhikr = store.value("tasbih_dhikr")
        Text(dhikr.isEmpty ? String(localized: "watch.tasbih.title") : dhikr)
          .font(.caption)
          .foregroundStyle(Look.gold)
          .lineLimit(1)
          .padding(.horizontal, 22)

        Text(store.session.formatted())
          .font(.system(size: 56, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(Look.cream)
          .minimumScaleFactor(0.5)
          .lineLimit(1)

        if store.target > 0 {
          let rem = store.session % store.target
          Text("\(rem) / \(store.target)")
            .font(.caption2)
            .foregroundStyle(Look.cream.opacity(0.65))
            .monospacedDigit()
        }

        Button("watch.tasbih.reset") {
          showResetSheet = true
        }
        .font(.caption2)
        .buttonStyle(.plain)
        .foregroundStyle(Look.cream.opacity(0.5))
        .padding(.top, 2)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      .onTapGesture {
        store.count()
      }
      .focusable()
      .digitalCrownRotation(
        $crownAccumulator,
        from: -Double.infinity,
        through: Double.infinity,
        by: 1,
        sensitivity: .low,
        isContinuous: true,
        isHapticFeedbackEnabled: false
      )
      .onChange(of: crownAccumulator) { _, newVal in
        store.count()
      }
    }
    .sheet(isPresented: $showResetSheet) {
      VStack(spacing: 12) {
        Text("watch.tasbih.reset")
          .font(.headline)
          .foregroundStyle(Look.cream)
        Button("watch.tasbih.reset") {
          store.resetSession()
          showResetSheet = false
        }
        .buttonStyle(.borderedProminent)
        .tint(Look.gold)
      }
      .padding()
      .background(WatchNightBackground())
    }
    .accessibilityLabel(Text("watch.tasbih.count"))
    .accessibilityValue(Text(store.session.formatted()))
  }
}
