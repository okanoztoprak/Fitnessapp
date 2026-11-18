import ActivityKit
import SwiftUI
import WidgetKit

/// Rusttimer op het toegangsscherm en in het Dynamic Island, zodat je je telefoon kunt wegleggen.
struct RestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            RestLockScreenView(context: context)
                .activityBackgroundTint(WidgetTheme.background)
                .activitySystemActionForegroundColor(WidgetTheme.accent)
        } dynamicIsland: { context in
            let range = Self.range(context.state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rust", systemImage: "timer")
                        .font(.headline)
                        .foregroundStyle(WidgetTheme.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: range, countsDown: true)
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(timerInterval: range, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                            .tint(WidgetTheme.accent)
                        Text(context.attributes.workoutName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(WidgetTheme.accent)
            } compactTrailing: {
                Text(timerInterval: range, countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
                    .foregroundStyle(WidgetTheme.accent)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(WidgetTheme.accent)
            }
        }
    }

    static func range(_ state: RestActivityAttributes.ContentState) -> ClosedRange<Date> {
        let start = state.endDate.addingTimeInterval(-Double(max(state.totalSeconds, 1)))
        return start...max(start, state.endDate)
    }
}

private struct RestLockScreenView: View {
    let context: ActivityViewContext<RestActivityAttributes>

    var body: some View {
        let range = RestLiveActivity.range(context.state)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(context.isStale ? String(localized: "Rust voorbij") : String(localized: "Rust"),
                      systemImage: context.isStale ? "checkmark.circle.fill" : "timer")
                    .font(.headline)
                    .foregroundStyle(WidgetTheme.accent)
                Spacer()
                if !context.isStale {
                    Text(timerInterval: range, countsDown: true)
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                        .foregroundStyle(.white)
                }
            }
            if !context.isStale {
                ProgressView(timerInterval: range, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(WidgetTheme.accent)
            }
            Text(context.attributes.workoutName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
