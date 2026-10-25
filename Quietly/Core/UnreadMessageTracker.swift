import Foundation

/// Tracks counts only, never message text or people. A new page/visit starts quietly.
struct UnreadMessageTracker {
    private var previous: Int?
    private var lastAlert: Date?

    mutating func reset() {
        previous = nil
    }

    mutating func observe(_ count: Int?, at now: Date = Date()) -> Bool {
        guard let count, (0...999).contains(count) else {
            reset()
            return false
        }
        defer { previous = count }
        guard let previous, count > previous else { return false }
        // A burst of messages produces at most one sound every 15 seconds.
        guard lastAlert.map({ now.timeIntervalSince($0) >= 15 }) ?? true else { return false }
        lastAlert = now
        return true
    }
}
