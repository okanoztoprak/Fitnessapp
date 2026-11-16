import Charts
import PowerCore
import SwiftData
import SwiftUI

struct ProgressTabView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyWeightEntry.date) private var weights: [BodyWeightEntry]
    @Query(sort: \Workout.startedAt) private var workouts: [Workout]
    @Query(sort: \PersonalRecord.date, order: .reverse) private var records: [PersonalRecord]
    @State private var showWeightSheet = false

    private struct WeekVolume: Identifiable {
        let week: Date
        let kg: Double
        var id: Date { week }
    }

    private var weeklyVolume: [WeekVolume] {
        let calendar = Calendar.current
        var totals: [Date: Double] = [:]
        for workout in workouts where workout.endedAt != nil {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: workout.startedAt)?.start else { continue }
            totals[week, default: 0] += workout.volumeKg
        }
        return Array(totals.map { WeekVolume(week: $0.key, kg: $0.value) }.sorted { $0.week < $1.week }.suffix(12))
    }

    var body: some View {
        NavigationStack {
            List {
                weightSection
                Section("Volume per week") {
                    if weeklyVolume.isEmpty {
                        Text("Nog geen afgeronde trainingen.").foregroundStyle(.secondary)
                    } else {
                        Chart(weeklyVolume) { item in
                            BarMark(x: .value("Week", item.week, unit: .weekOfYear),
                                    y: .value("Volume", profile.units.displayWeight(item.kg)))
                                .foregroundStyle(Theme.accent)
                        }
                        .frame(height: 160)
                    }
                }
                Section("Recente records") {
                    if records.isEmpty {
                        Text("Je records verschijnen hier zodra je een eerdere prestatie verbetert.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(records.prefix(15)) { record in
                        LabeledContent {
                            Text(record.date, format: .dateTime.day().month())
                        } label: {
                            VStack(alignment: .leading) {
                                Text(record.exerciseName)
                                Text("\(record.kind.title): \(profile.units.weightText(record.weightKg, digits: 2)) × \(record.reps)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Voortgang")
            .toolbar {
                Button("Weeg in", systemImage: "scalemass.fill") { showWeightSheet = true }
            }
            .sheet(isPresented: $showWeightSheet) { LogWeightSheet(profile: profile) }
        }
    }

    @ViewBuilder
    private var weightSection: some View {
        let points = weights.map { WeightPoint(date: $0.date, kg: $0.kg) }
        let trend = WeightTrend.ema(points)
        Section {
            if profile.hideWeight {
                Text("Gewicht is verborgen. Je kunt dit aanpassen in de instellingen.")
                    .foregroundStyle(.secondary)
            } else if points.isEmpty {
                Text("Nog geen wegingen.").foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(points, id: \.date) { point in
                        PointMark(x: .value("Datum", point.date),
                                  y: .value("Gewicht", profile.units.displayWeight(point.kg)))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .symbolSize(20)
                    }
                    ForEach(trend, id: \.date) { point in
                        LineMark(x: .value("Datum", point.date),
                                 y: .value("Gewicht", profile.units.displayWeight(point.kg)))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 200)
                .accessibilityLabel("Grafiek van wegingen en trendlijn")
                if let last = trend.last {
                    LabeledContent("Trend", value: profile.units.weightText(last.kg))
                }
                if let rate = WeightTrend.weeklyRate(trend: trend) {
                    LabeledContent("Per week",
                                   value: "\(rate >= 0 ? "+" : "")\(UnitFormatter.number(profile.units.displayWeight(rate), digits: 2)) \(profile.units.weightUnit)")
                }
            }
        } header: {
            Text("Gewicht")
        } footer: {
            Text("De lijn is een voortschrijdend gemiddelde. Dagelijkse schommelingen door vocht en eten zeggen weinig; de trend wel.")
        }
        if !profile.hideWeight, !weights.isEmpty {
            Section("Wegingen") {
                ForEach(weights.reversed().prefix(30)) { entry in
                    LabeledContent {
                        Text(profile.units.weightText(entry.kg))
                    } label: {
                        Text(entry.date, format: .dateTime.weekday().day().month())
                    }
                    .swipeActions {
                        Button("Verwijder", systemImage: "trash", role: .destructive) {
                            context.delete(entry)
                        }
                    }
                }
            }
        }
    }
}
