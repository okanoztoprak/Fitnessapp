import Foundation
import Observation

/// Rusttimer binnen de app. De Live Activity volgt in fase 5.
@MainActor
@Observable
final class RestTimer {
    private(set) var endDate: Date?
    private(set) var totalSeconds: Int = 0
    private var task: Task<Void, Never>?

    var isRunning: Bool { endDate != nil }

    func remaining(at date: Date = Date()) -> Int {
        guard let endDate else { return 0 }
        return max(0, Int(endDate.timeIntervalSince(date).rounded(.up)))
    }

    func start(seconds: Int) {
        guard seconds > 0 else { return }
        totalSeconds = seconds
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
    }

    private func schedule(until date: Date) {
        task?.cancel()
        endDate = date
        task = Task { [weak self] in
            let wait = date.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            Haptics.success()
            self?.endDate = nil
        }
    }
}
