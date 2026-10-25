import Foundation

struct FocusSession: Codable, Equatable, Identifiable {
    let id: UUID
    let startedAt: Date
    let endsAt: Date
    let destination: InstagramDestination
    let profileUsername: String?

    init(minutes: Int, destination: InstagramDestination, now: Date = Date(), profileUsername: String? = nil) {
        id = UUID()
        startedAt = now
        endsAt = now.addingTimeInterval(TimeInterval(min(30, max(1, minutes)) * 60))
        self.destination = destination
        self.profileUsername = profileUsername.flatMap(FriendAccount.normalize)
    }

    func remaining(at now: Date) -> Int {
        max(0, Int(ceil(endsAt.timeIntervalSince(now))))
    }

    func hasEnded(at now: Date = Date()) -> Bool { now >= endsAt }
}

extension InstagramDestination: Codable {}
