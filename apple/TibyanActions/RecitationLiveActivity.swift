// The recitation's Live Activity: lock screen and Dynamic Island (compact,
// minimal, expanded), in the app's teal and gold. Its data comes from the
// app (ios/Runner/LiveActivityChannel.swift); see RecitationActivity.swift.
// Names and numbers only: never the Quran's text.

#if os(iOS)
import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private let teal = Color(red: 0.06, green: 0.40, blue: 0.38)
private let deepTeal = Color(red: 0.07, green: 0.25, blue: 0.19)
private let gold = Color(red: 0.72, green: 0.57, blue: 0.24)
private let paper = Color(red: 0.96, green: 0.93, blue: 0.87)

/// The Tibyan logo (gold) beside the waveform.
private struct Brand: View {
  var height: CGFloat = 22

  var body: some View {
    HStack(spacing: 6) {
      Image("TibyanLogo")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(height: height)
      Image(systemName: "waveform")
        .font(.system(size: height * 0.8, weight: .semibold))
    }
    .foregroundColor(gold)
    .accessibilityHidden(true)
  }
}

private struct RoundButton<I: AppIntent>: View {
  let intent: I
  let symbol: String
  let label: String
  let size: CGFloat
  let filled: Bool

  var body: some View {
    Button(intent: intent) {
      Image(systemName: symbol)
        .font(.system(size: size * 0.42, weight: .bold))
        .foregroundColor(filled ? deepTeal : gold)
        .frame(width: size, height: size)
        .background(Circle().fill(filled ? gold : gold.opacity(0.18)))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

/// Previous verse, play/pause, next verse; the verse buttons only when the
/// verse is known (a timed recitation). In Arabic the row runs right to
/// left: «السابقة» on the right, its arrow pointing right.
private struct Controls: View {
  let state: RecitationAttributes.ContentState
  var size: CGFloat = 36

  var body: some View {
    HStack(spacing: 10) {
      if state.ayah > 0 {
        RoundButton(
          intent: PreviousVerseIntent(), symbol: state.rtl ? "forward.fill" : "backward.fill",
          label: state.previousLabel, size: size * 0.8, filled: false)
      }
      RoundButton(
        intent: ToggleRecitationIntent(), symbol: state.playing ? "pause.fill" : "play.fill",
        label: state.playing ? state.pauseLabel : state.playLabel, size: size, filled: true)
      if state.ayah > 0 {
        RoundButton(
          intent: NextVerseIntent(), symbol: state.rtl ? "backward.fill" : "forward.fill",
          label: state.nextLabel, size: size * 0.8, filled: false)
      }
    }
  }
}

/// A thin gold bar: the verse reached in the surah (filled from the
/// start side, right in Arabic).
private struct Progress: View {
  let state: RecitationAttributes.ContentState

  var body: some View {
    if let p = state.progress {
      GeometryReader { g in
        ZStack(alignment: .leading) {
          Capsule().fill(gold.opacity(0.25))
          Capsule().fill(gold).frame(width: max(3, g.size.width * p))
        }
      }
      .frame(height: 3)
      .accessibilityElement()
      .accessibilityLabel("\(state.verse)")
      .accessibilityValue("\(state.ayah) / \(state.ayahCount)")
    }
  }
}

private struct Detail: View {
  let state: RecitationAttributes.ContentState

  var body: some View {
    Text(state.verse.isEmpty ? state.reciter : "\(state.reciter) · \(state.verse)")
      .font(.subheadline).foregroundColor(paper.opacity(0.8)).lineLimit(1)
  }
}

private struct LockScreenView: View {
  let state: RecitationAttributes.ContentState

  var body: some View {
    VStack(spacing: 10) {
      HStack(spacing: 12) {
        Brand(height: 22)
        VStack(alignment: .leading, spacing: 2) {
          Text(state.surah).font(.headline).foregroundColor(paper).lineLimit(1)
          Detail(state: state)
        }
        .accessibilityElement(children: .combine)
        Spacer(minLength: 0)
        Controls(state: state, size: 38)
      }
      Progress(state: state)
    }
    .padding(16)
    .environment(\.layoutDirection, state.rtl ? .rightToLeft : .leftToRight)
  }
}

struct RecitationLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RecitationAttributes.self) { context in
      LockScreenView(state: context.state)
        .activityBackgroundTint(deepTeal)
        .activitySystemActionForegroundColor(gold)
    } dynamicIsland: { context in
      let s = context.state
      let dir: LayoutDirection = s.rtl ? .rightToLeft : .leftToRight
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Brand(height: 20).environment(\.layoutDirection, dir)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(s.surah).font(.headline).foregroundColor(paper).lineLimit(1)
            .environment(\.layoutDirection, dir)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(spacing: 8) {
            HStack {
              Detail(state: s)
              Spacer(minLength: 8)
              Controls(state: s, size: 34)
            }
            Progress(state: s)
          }
          .environment(\.layoutDirection, dir)
        }
      } compactLeading: {
        // The logo is too wide to sit cleanly beside the camera: the
        // waveform stays here.
        Image(systemName: s.playing ? "waveform" : "pause.fill")
          .foregroundColor(gold)
          .accessibilityLabel(s.surah)
      } compactTrailing: {
        Text(s.verse).font(.caption2).foregroundColor(gold).lineLimit(1)
          .frame(maxWidth: 64)
      } minimal: {
        Image(systemName: "waveform").foregroundColor(gold)
          .accessibilityLabel(s.surah)
      }
      .keylineTint(teal)
    }
  }
}
#endif
