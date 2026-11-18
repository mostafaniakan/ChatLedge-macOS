import Foundation

struct ChatPanelIdle {
    static let interval: TimeInterval = 30 * 60

    private var deadline: Date?

    mutating func recordInteraction(at now: Date = .now) {
        deadline = now.addingTimeInterval(Self.interval)
    }

    mutating func stop() {
        deadline = nil
    }

    func remaining(at now: Date = .now) -> TimeInterval? {
        deadline?.timeIntervalSince(now)
    }
}
