import HealthKit
import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let goal: Int
    let nextWorkout: String?
    let nextDetail: String?
    let weekStreak: Int

    var progress: Double { goal > 0 ? min(1, Double(steps) / Double(goal)) : 0 }
    var goalReached: Bool { goal > 0 && steps >= goal }

    static let sample = TodayEntry(date: Date(), steps: 6_240, goal: 8_000, nextWorkout: "Full Body A",
                                   nextDetail: String(localized: "1 van 3 trainingen deze week"), weekStreak: 3)
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        let reply = Reply(completion)
        Task { reply.send(await Self.entry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let reply = Reply(completion)
        Task {
            let entry = await Self.entry()
            // Stappen lopen door; elk kwartier opnieuw is wat WidgetKit ruim toestaat.
            reply.send(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
        }
    }

    static func entry(now: Date = Date()) async -> TodayEntry {
        let snapshot = WidgetSnapshot.load()
        var steps = snapshot.stepsToday(now: now)
        // Health direct lezen als dat mag (alleen met ontgrendeld toestel); anders de laatste stand uit de app.
        if let live = await StepReader.today(now: now) { steps = max(steps, live) }
        return TodayEntry(date: now, steps: steps, goal: snapshot.stepGoal, nextWorkout: snapshot.nextWorkout,
                          nextDetail: snapshot.nextDetail, weekStreak: snapshot.weekStreak)
    }
}

/// Geeft de completion-handler veilig door aan een Task.
private struct Reply<T>: @unchecked Sendable {
    let send: (T) -> Void
    init(_ send: @escaping (T) -> Void) { self.send = send }
}

enum StepReader {
    static func today(now: Date) async -> Int? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let start = Calendar.current.startOfDay(for: now)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.stepCount),
                                       predicate: HKQuery.predicateForSamples(withStart: start, end: now)),
            options: .cumulativeSum)
        guard let statistics = try? await descriptor.result(for: HKHealthStore()),
              let sum = statistics.sumQuantity() else { return nil }
        return Int(sum.doubleValue(for: .count()).rounded())
    }
}

// MARK: - Stappen

struct StepsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "steps", provider: TodayProvider()) { entry in
            StepsWidgetView(entry: entry)
        }
        .configurationDisplayName("Stappen")
        .description("Je stappen van vandaag tegenover je doel.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct StepsWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.progress) {
                Image(systemName: "figure.walk")
            } currentValueLabel: {
                Text(compact(entry.steps))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Stappen", systemImage: "figure.walk").font(.caption.weight(.semibold))
                Text("\(entry.steps.formatted()) / \(entry.goal.formatted())")
                    .font(.headline).monospacedDigit()
                Gauge(value: entry.progress) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
            }
            .containerBackground(.clear, for: .widget)
        case .accessoryInline:
            Label("\(entry.steps.formatted()) van \(entry.goal.formatted()) stappen", systemImage: "figure.walk")
                .containerBackground(.clear, for: .widget)
        default:
            VStack(alignment: .leading, spacing: 8) {
                Label("Stappen", systemImage: "figure.walk")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                StepsRing(entry: entry, lineWidth: 9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .foregroundStyle(.white)
            .containerBackground(WidgetTheme.background, for: .widget)
        }
    }

    private func compact(_ steps: Int) -> String {
        steps >= 10_000 ? String(format: "%.0fk", Double(steps) / 1_000)
            : steps >= 1_000 ? String(format: "%.1fk", Double(steps) / 1_000) : "\(steps)"
    }
}

struct StepsRing: View {
    let entry: TodayEntry
    var lineWidth: CGFloat = 10

    var body: some View {
        let color = entry.goalReached ? WidgetTheme.good : WidgetTheme.accent
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(entry.steps, format: .number)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("van \(entry.goal.formatted())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.horizontal, lineWidth + 4)
        }
        .padding(lineWidth / 2)
    }
}

// MARK: - Vandaag

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "today", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Vandaag")
        .description("Stappen, je volgende training en je reeks.")
        .supportedFamilies([.systemMedium])
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry

    var body: some View {
        HStack(spacing: 16) {
            StepsRing(entry: entry, lineWidth: 10)
                .frame(width: 112, height: 112)
            VStack(alignment: .leading, spacing: 6) {
                Text("Volgende training")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(entry.nextWorkout ?? String(localized: "Open POWER UP"))
                    .font(.headline)
                    .lineLimit(2)
                if let detail = entry.nextDetail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Label {
                    Text(entry.weekStreak == 1 ? String(localized: "1 week op rij")
                         : String(localized: "\(entry.weekStreak) weken op rij"))
                } icon: {
                    Image(systemName: "flame.fill").foregroundStyle(WidgetTheme.warn)
                }
                .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .containerBackground(WidgetTheme.background, for: .widget)
    }
}
