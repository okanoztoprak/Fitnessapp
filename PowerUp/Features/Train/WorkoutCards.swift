import PowerCore
import SwiftData
import SwiftUI

/// Aanbeveling voor vandaag: wat te doen, waarom, en één tik om het te bekijken.
struct NextWorkoutCard: View {
    let recommendation: Coach.Recommendation
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router

    var body: some View {
        let rest = recommendation.isRest
        let exercises = recommendation.day.map { Coach.exercises(slugs: $0.slugs, in: context) } ?? []
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Tag(text: rest ? String(localized: "Herstel") : String(localized: "Aanbevolen"),
                    color: rest ? Theme.Fill.cool : Theme.accent, filled: true)
                Spacer()
                WeekDots(done: recommendation.advice.sessionsThisWeek, planned: recommendation.plannedPerWeek)
            }
            Text(Coach.headline(recommendation))
                .font(.title.weight(.bold))
            if let plan = recommendation.training.plan, !rest {
                Label(recommendation.training.programID == nil ? String(localized: "Deloadweek")
                      : ProgramCoach.weekLine(plan),
                      systemImage: plan.isDeload ? "moon.fill" : "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(plan.isDeload ? Theme.cool : Theme.accentText)
            }
            Text(Coach.explanation(recommendation))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !rest, !exercises.isEmpty {
                HStack(spacing: 14) {
                    Label("\(exercises.count) oefeningen", systemImage: "list.bullet")
                    Label("± \(Coach.estimatedMinutes(exerciseCount: exercises.count, restSeconds: profile.restSeconds)) min",
                          systemImage: "clock")
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                MuscleTags(muscles: uniqueMuscles(exercises))
            }
            if let day = recommendation.day {
                if rest {
                    Button("Toch trainen: \(day.name)") { open(day) }
                        .buttonStyle(SoftButtonStyle())
                } else {
                    Button { open(day) } label: {
                        Label("Bekijk training", systemImage: "arrow.right")
                            .labelStyle(TrailingIconLabelStyle())
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .card()
    }

    private func open(_ day: TemplateDay) {
        let caption = recommendation.training.plan.map {
            ProgramCoach.weekExplanation($0, goal: recommendation.training.goal ?? .hypertrophy)
        } ?? Coach.explanation(recommendation)
        router.proposal = Coach.proposal(for: day, caption: caption, in: context, training: recommendation.training)
    }

    private func uniqueMuscles(_ exercises: [Exercise]) -> [MuscleGroup] {
        var seen: [MuscleGroup] = []
        for exercise in exercises where !seen.contains(exercise.primaryMuscle) { seen.append(exercise.primaryMuscle) }
        return seen
    }
}

/// Kaart voor een training die nog loopt.
struct ActiveWorkoutCard: View {
    let workout: Workout
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Tag(text: String(localized: "Bezig"), color: Theme.accent, filled: true)
                Spacer()
                Text(workout.startedAt, style: .timer)
                    .font(Theme.number(.title3))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accentText)
            }
            Text(workout.name)
                .font(.title.weight(.bold))
            Text(workout.doneSets.count == 1 ? String(localized: "1 set afgevinkt") : String(localized: "\(workout.doneSets.count) sets afgevinkt"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Ga verder") { router.presentedWorkout = workout }
                .buttonStyle(PrimaryButtonStyle())
        }
        .card()
    }
}

/// Eén stip per geplande training deze week; gevuld is gedaan.
struct WeekDots: View {
    let done: Int
    let planned: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<max(planned, done), id: \.self) { index in
                Capsule()
                    .fill(index < done ? Theme.accentText : Color.primary.opacity(0.15))
                    .frame(width: 16, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) van \(planned) trainingen deze week")
    }
}

struct MuscleTags: View {
    let muscles: [MuscleGroup]

    var body: some View {
        // Labels lopen door op een nieuwe regel in plaats van buiten de kaart te schuiven.
        FlowLayout(spacing: 6) {
            ForEach(muscles, id: \.self) { Tag(text: $0.title) }
        }
    }
}

/// Icoon achter de tekst in plaats van ervoor.
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.title
            configuration.icon
        }
    }
}

/// Voorvertoning van een training: oefeningen met doel, duur en één startknop.
struct WorkoutPreviewSheet: View {
    let proposal: WorkoutProposal
    let profile: UserProfile
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(proposal.title)
                            .font(.largeTitle.weight(.bold))
                        Text(proposal.caption)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 14) {
                            Label("\(proposal.exercises.count) oefeningen", systemImage: "list.bullet")
                            Label("± \(Coach.estimatedMinutes(exerciseCount: proposal.exercises.count, restSeconds: profile.restSeconds)) min",
                                  systemImage: "clock")
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(proposal.exercises.enumerated()), id: \.offset) { index, exercise in
                            HStack(spacing: 14) {
                                Text("\(index + 1)")
                                    .font(Theme.number(.subheadline))
                                    .frame(width: 30, height: 30)
                                    .background(Theme.raised, in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name).font(.body.weight(.semibold))
                                    Text(exercise.primaryMuscle.title)
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                if let target = Coach.target(for: exercise, before: nil, units: profile.units,
                                                             training: proposal.training) {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(target.text)
                                            .font(.footnote.weight(.bold))
                                            .foregroundStyle(Theme.accentText)
                                        Text("Doel").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 12)
                            if index < proposal.exercises.count - 1 { Divider() }
                        }
                    }
                    .card(padding: 16)
                    if proposal.exercises.isEmpty {
                        Text("Geen passende oefeningen gevonden voor je materiaal.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                Button("Start training") { router.start(proposal) }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(proposal.exercises.isEmpty)
                    .padding()
                    .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Sluit") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }
}
