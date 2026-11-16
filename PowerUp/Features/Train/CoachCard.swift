import PowerCore
import SwiftUI

/// Aanbeveling voor vandaag: wat te doen en waarom.
struct CoachCard: View {
    let recommendation: Coach.Recommendation
    let onStart: (TemplateDay) -> Void

    var body: some View {
        let rest = recommendation.isRest
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Aanbevolen voor vandaag")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                WeekDots(done: recommendation.advice.sessionsThisWeek, planned: recommendation.plannedPerWeek)
            }
            Label {
                Text(Coach.headline(recommendation))
            } icon: {
                Image(systemName: rest ? "moon.zzz.fill" : "bolt.fill")
                    .foregroundStyle(rest ? Color.indigo : Theme.accent)
            }
            .font(Theme.display(.title2))
            Text(Coach.explanation(recommendation))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let day = recommendation.day {
                if rest {
                    Button("Toch trainen: \(day.name)") { onStart(day) }
                        .font(.subheadline.weight(.semibold))
                } else {
                    Button {
                        onStart(day)
                    } label: {
                        Text("Start training · \(day.slugs.count) oefeningen")
                    }
                    .buttonStyle(ComicButtonStyle())
                }
            }
        }
        .comicCard(tint: rest ? .indigo : Theme.accent)
    }
}

/// Eén stip per geplande training deze week; gevuld is gedaan.
struct WeekDots: View {
    let done: Int
    let planned: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(planned, done), id: \.self) { index in
                Circle()
                    .fill(index < done ? Theme.accent : Color.primary.opacity(0.15))
                    .overlay { Circle().strokeBorder(Color.primary, lineWidth: 1.5) }
                    .frame(width: 12, height: 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) van \(planned) trainingen deze week")
    }
}

/// Herstelstatus van één spiergroep; tik om een focus-training te starten.
struct MuscleChip: View {
    let status: Coach.MuscleStatus

    private var color: Color {
        switch status.status {
        case .untrained: .gray
        case .recovering: .orange
        case .ready: .green
        case .overdue: .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 9, height: 9).accessibilityHidden(true)
                Text(status.muscle.title).font(.subheadline.weight(.bold))
            }
            Text(Coach.statusText(status))
                .font(.caption2)
                .foregroundStyle(.secondary)
            if status.lastTrained != nil {
                Text(Coach.relativeDay(status.lastTrained))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 62, alignment: .topLeading)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
    }
}
