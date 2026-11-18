import Charts
import PowerCore
import SwiftData
import SwiftUI

struct ProgressTabView: View {
    let profile: UserProfile
    @Query(sort: \BodyWeightEntry.date) private var weights: [BodyWeightEntry]
    @Query(sort: \Workout.startedAt) private var workouts: [Workout]
    @Query(sort: \PersonalRecord.date, order: .reverse) private var records: [PersonalRecord]
    @State private var showWeightSheet = false

    private var finished: [Workout] { workouts.filter { $0.endedAt != nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    monthSummary
                    MotivationQuery(profile: profile) { data in RecapHistoryCard(data: data) }
                    consistencyCard
                    weightCard
                    volumeCard
                    balanceCard
                    recordsCard
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("Voortgang")
            .toolbar {
                Button("Weeg in", systemImage: "scalemass.fill") { showWeightSheet = true }
            }
            .sheet(isPresented: $showWeightSheet) { LogWeightSheet(profile: profile) }
        }
    }

    // MARK: Deze maand

    private var monthSummary: some View {
        let calendar = Calendar.current
        let month = finished.filter { calendar.isDate($0.startedAt, equalTo: Date(), toGranularity: .month) }
        let monthRecords = records.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
        return VStack(alignment: .leading, spacing: 12) {
            Text(Date(), format: .dateTime.month(.wide).year())
                .font(.subheadline.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            HStack {
                StatTile(value: "\(month.count)", label: String(localized: "Trainingen"), symbol: "figure.strengthtraining.traditional")
                StatTile(value: profile.units.weightText(month.reduce(0) { $0 + $1.volumeKg }, digits: 0),
                         label: String(localized: "Volume"), symbol: "scalemass.fill", tint: Theme.cool)
                StatTile(value: "\(Set(monthRecords.map(\.exerciseSlug)).count)", label: String(localized: "Records"),
                         symbol: "trophy.fill", tint: Theme.warn)
            }
        }
        .card()
    }

    // MARK: Consistentie

    private var consistencyCard: some View {
        let streak = Insights.weekStreak(finished: finished)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Consistentie").font(.headline)
                Spacer()
                Label(Insights.streakText(streak), systemImage: "flame.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(streak > 0 ? Theme.warn : .secondary)
            }
            ConsistencyGrid(setsPerDay: Insights.setsPerDay(finished: finished))
            Text("Elke kolom is een week; hoe voller het vakje, hoe meer sets die dag.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .card()
    }

    // MARK: Gewicht

    @ViewBuilder
    private var weightCard: some View {
        let points = weights.map { WeightPoint(date: $0.date, kg: $0.kg) }
        let trend = WeightTrend.ema(AdaptiveExpenditure.withoutOutliers(points))
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Gewicht").font(.headline)
                Spacer()
                if !weights.isEmpty, !profile.hideWeight {
                    NavigationLink("Alle wegingen") { WeighInListView(profile: profile) }
                        .font(.footnote.weight(.semibold))
                }
            }
            if profile.hideWeight {
                Text("Gewicht is verborgen. Je kunt dit aanpassen in de instellingen.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else if points.isEmpty {
                Text("Nog geen wegingen.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let last = trend.last {
                        Text(profile.units.weightText(last.kg)).font(Theme.number(.title))
                    }
                    if let rate = WeightTrend.weeklyRate(trend: trend) {
                        Text("\(rate >= 0 ? "+" : "")\(UnitFormatter.number(profile.units.displayWeight(rate), digits: 2)) \(profile.units.weightUnit) per week")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if points.count < 2 {
                    Text("Weeg je een paar keer per week; de trend filtert dagelijkse schommelingen eruit.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                Chart {
                    ForEach(points, id: \.date) { point in
                        PointMark(x: .value("Datum", point.date),
                                  y: .value("Gewicht", profile.units.displayWeight(point.kg)))
                            .foregroundStyle(Color.secondary.opacity(0.55))
                            .symbolSize(22)
                    }
                    ForEach(trend, id: \.date) { point in
                        LineMark(x: .value("Datum", point.date),
                                 y: .value("Gewicht", profile.units.displayWeight(point.kg)))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            .foregroundStyle(Theme.accentText)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 180)
                .accessibilityLabel("Grafiek van wegingen en trendlijn")
                }
                Text("De lijn is een voortschrijdend gemiddelde. Dagelijkse schommelingen door vocht en eten zeggen weinig; de trend wel.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    // MARK: Volume

    private var volumeCard: some View {
        let weeks = Insights.weekly(finished: finished)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Volume per week").font(.headline)
            if finished.isEmpty {
                Text("Nog geen afgeronde trainingen.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                Chart(weeks) { item in
                    BarMark(x: .value("Week", item.week, unit: .weekOfYear),
                            y: .value("Volume", profile.units.displayWeight(item.volumeKg)))
                        .cornerRadius(5)
                        .foregroundStyle(item.id == weeks.last?.id ? Theme.accentText : Theme.accentText.opacity(0.45))
                }
                .frame(height: 160)
                .accessibilityLabel("Staafgrafiek van je trainingsvolume per week")
            }
        }
        .card()
    }

    // MARK: Spierbalans

    private var balanceCard: some View {
        let totals = Insights.muscleSets(finished: finished)
        let muscles: [MuscleGroup] = [.chest, .shoulders, .triceps, .quads, .glutes, .calves, .hamstrings, .core, .back, .biceps]
        let top = max(muscles.compactMap { totals[$0] }.max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Spierbalans").font(.headline)
            if totals.isEmpty {
                Text("Train een paar keer om te zien welke spiergroepen je het meest belast.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                RadarChart(axes: muscles.map { RadarChart.Axis(label: $0.title, value: (totals[$0] ?? 0) / top) })
                    .frame(maxWidth: 340)
                    .frame(maxWidth: .infinity)
                Text("Sets per spiergroep in de laatste 4 weken. Een gelijkmatige vorm betekent een gebalanceerd schema.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    // MARK: Records

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recente records").font(.headline)
            if records.isEmpty {
                Text("Je records verschijnen hier zodra je een eerdere prestatie verbetert.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(records.prefix(10)) { record in
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.warn)
                        .frame(width: 32, height: 32)
                        .background(Theme.raised, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.exerciseName).font(.subheadline.weight(.semibold))
                        Text("\(record.kind.title): \(profile.units.weightText(record.weightKg, digits: 2)) × \(record.reps)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(record.date, format: .dateTime.day().month())
                        .font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }
}

/// Raster van de laatste 16 weken: één vakje per dag.
private struct ConsistencyGrid: View {
    let setsPerDay: [Date: Int]
    private let weeks = 16

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let top = Double(max(setsPerDay.values.max() ?? 1, 1))
        HStack(spacing: 4) {
            ForEach(0..<weeks, id: \.self) { column in
                VStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { row in
                        let offset = (column - (weeks - 1)) * 7 + row
                        let date = calendar.date(byAdding: .day, value: offset, to: thisWeek) ?? today
                        let sets = setsPerDay[date] ?? 0
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(sets > 0 ? Theme.accentText.opacity(0.4 + 0.6 * Double(sets) / top) : Theme.raised)
                            .opacity(date > today ? 0.25 : 1)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(setsPerDay.count) trainingsdagen in totaal")
    }
}

/// Spinnenwebgrafiek: elke as is een spiergroep, de afstand tot het midden het aantal sets.
struct RadarChart: View {
    struct Axis: Identifiable {
        let label: String
        /// 0...1
        let value: Double
        var id: String { label }
    }

    let axes: [Axis]

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = min(proxy.size.width, proxy.size.height) / 2 - 38
            ZStack {
                ForEach(1...3, id: \.self) { ring in
                    polygon(center: center, radius: radius, values: axes.map { _ in Double(ring) / 3 })
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }
                Path { path in
                    for index in axes.indices {
                        path.move(to: center)
                        path.addLine(to: point(center: center, radius: radius, index: index))
                    }
                }
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                polygon(center: center, radius: radius, values: axes.map { max($0.value, 0.04) })
                    .fill(Theme.accentText.opacity(0.22))
                polygon(center: center, radius: radius, values: axes.map { max($0.value, 0.04) })
                    .stroke(Theme.accentText, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                ForEach(Array(axes.enumerated()), id: \.element.id) { index, axis in
                    Text(axis.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .position(point(center: center, radius: radius + 22, index: index))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(axes.map { "\($0.label) \(Int(($0.value * 100).rounded()))%" }.joined(separator: ", "))
    }

    private func point(center: CGPoint, radius: CGFloat, index: Int) -> CGPoint {
        let angle = CGFloat(index) / CGFloat(max(axes.count, 1)) * 2 * .pi - .pi / 2
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    private func polygon(center: CGPoint, radius: CGFloat, values: [Double]) -> Path {
        var path = Path()
        for (index, value) in values.enumerated() {
            let target = point(center: center, radius: radius * CGFloat(min(max(value, 0), 1)), index: index)
            if index == 0 { path.move(to: target) } else { path.addLine(to: target) }
        }
        path.closeSubpath()
        return path
    }
}

struct WeighInListView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var weights: [BodyWeightEntry]

    var body: some View {
        List {
            ForEach(weights) { entry in
                LabeledContent {
                    Text(profile.units.weightText(entry.kg))
                } label: {
                    Text(entry.date, format: .dateTime.weekday().day().month().year())
                }
                .listRowBackground(Theme.card)
                .swipeActions {
                    Button("Verwijder", systemImage: "trash", role: .destructive) {
                        context.delete(entry)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Wegingen")
        .navigationBarTitleDisplayMode(.inline)
    }
}
