// The recitation's Live Activity: lock screen and Dynamic Island (compact,
// minimal, expanded), in the app's teal and gold. Its data comes from the
// app (ios/Runner/LiveActivityChannel.swift); see RecitationActivity.swift.

#if os(iOS)
import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private let teal = Color(red: 0.06, green: 0.40, blue: 0.38)
private let deepTeal = Color(red: 0.07, green: 0.25, blue: 0.19)
private let gold = Color(red: 0.72, green: 0.57, blue: 0.24)
private let paper = Color(red: 0.96, green: 0.93, blue: 0.87)

private struct PlayPauseButton: View {
  let state: RecitationAttributes.ContentState
  var size: CGFloat = 36

  var body: some View {
    Button(intent: ToggleRecitationIntent()) {
      Image(systemName: state.playing ? "pause.fill" : "play.fill")
        .font(.system(size: size * 0.45, weight: .bold))
        .foregroundColor(deepTeal)
        .frame(width: size, height: size)
        .background(Circle().fill(gold))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(state.playing ? state.pauseLabel : state.playLabel)
  }
}

private struct LockScreenView: View {
  let state: RecitationAttributes.ContentState

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "waveform")
        .font(.title3)
        .foregroundColor(gold)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(state.surah).font(.headline).foregroundColor(paper).lineLimit(1)
        Text(state.verse.isEmpty ? state.reciter : "\(state.reciter) · \(state.verse)")
          .font(.subheadline).foregroundColor(paper.opacity(0.8)).lineLimit(1)
      }
      .accessibilityElement(children: .combine)
      Spacer(minLength: 0)
      PlayPauseButton(state: state, size: 40)
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
          Image(systemName: "waveform").foregroundColor(gold).accessibilityHidden(true)
        }
        DynamicIslandExpandedRegion(.trailing) {
          PlayPauseButton(state: s, size: 34)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(s.surah).font(.headline).foregroundColor(paper).lineLimit(1)
            .environment(\.layoutDirection, dir)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(s.verse.isEmpty ? s.reciter : "\(s.reciter) · \(s.verse)")
            .font(.subheadline).foregroundColor(paper.opacity(0.8)).lineLimit(1)
            .environment(\.layoutDirection, dir)
        }
      } compactLeading: {
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
