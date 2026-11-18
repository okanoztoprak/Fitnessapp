import ActivityKit
import Foundation
import Observation

/// Rusttimer binnen de app, met een Live Activity op het toegangsscherm en in het Dynamic Island.
@MainActor
@Observable
final class RestTimer {
    private(set) var endDate: Date?
    private(set) var totalSeconds: Int = 0
    private var task: Task<Void, Never>?
    private var workoutName = ""
    @ObservationIgnored private var activity: Activity<RestActivityAttributes>?

    init() {
        // Een timer van een vorige keer (app afgesloten tijdens de rust) hoort niet te blijven hangen.
        Task {
            for leftover in Activity<RestActivityAttributes>.activities {
                await leftover.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    var isRunning: Bool { endDate != nil }

    func remaining(at date: Date = Date()) -> Int {
        guard let endDate else { return 0 }
        return max(0, Int(endDate.timeIntervalSince(date).rounded(.up)))
    }

    func start(seconds: Int, workoutName: String = "") {
        guard seconds > 0 else { return }
        totalSeconds = seconds
        self.workoutName = workoutName
        schedule(until: Date().addingTimeInterval(Double(seconds)))
    }

    func add(seconds: Int) {
        guard let endDate else { return }
        totalSeconds = max(1, totalSeconds + seconds)
        schedule(until: endDate.addingTimeInterval(Double(seconds)))
    }

    func stop() {
        task?.cancel()
        task = nil
        endDate = nil
        endActivity()
    }

    private func schedule(until date: Date) {
        task?.cancel()
        endDate = date
        showActivity(until: date)
        task = Task { [weak self] in
            let wait = date.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            Haptics.success()
            self?.endDate = nil
            self?.endActivity()
        }
    }

    // MARK: Live Activity

    private func showActivity(until date: Date) {
        let content = ActivityContent(state: RestActivityAttributes.ContentState(endDate: date, totalSeconds: totalSeconds),
                                      staleDate: date)
        if let id = activity?.id {
            Task { await Self.activity(id)?.update(content) }
            return
        }
        // De rusttimer op het toegangsscherm hoort bij RIVO Pro.
        guard ProStore.shared.isPro, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        activity = try? Activity.request(attributes: RestActivityAttributes(workoutName: workoutName), content: content)
    }

    private func endActivity() {
        guard let id = activity?.id else { return }
        activity = nil
        Task { await Self.activity(id)?.end(nil, dismissalPolicy: .immediate) }
    }

    /// Opnieuw opzoeken in plaats van doorgeven: `Activity` is niet Sendable.
    private nonisolated static func activity(_ id: String) -> Activity<RestActivityAttributes>? {
        Activity<RestActivityAttributes>.activities.first { $0.id == id }
    }
}
