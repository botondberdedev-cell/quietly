import Foundation

enum FeedMode: String, Codable, CaseIterable, Identifiable {
    case following, hidden, limited
    var id: String { rawValue }
    var title: String {
        switch self {
        case .following: return "People I follow"
        case .hidden: return "Only my saved friends"
        case .limited: return "A small catch-up"
        }
    }
}

struct FocusSettings: Codable, Equatable {
    var blockReels = true
    var blockExplore = true
    var hideAds = true
    var feedMode: FeedMode = .following
    var postLimit = 12
    var sessionMinutes = 5
    var friendUsernames: [String] = []

    init() {}

    enum CodingKeys: String, CodingKey {
        case blockReels, blockExplore, hideAds, feedMode, postLimit, sessionMinutes, friendUsernames
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        blockReels = try values.decodeIfPresent(Bool.self, forKey: .blockReels) ?? true
        blockExplore = try values.decodeIfPresent(Bool.self, forKey: .blockExplore) ?? true
        hideAds = try values.decodeIfPresent(Bool.self, forKey: .hideAds) ?? true
        feedMode = try values.decodeIfPresent(FeedMode.self, forKey: .feedMode) ?? .following
        postLimit = try values.decodeIfPresent(Int.self, forKey: .postLimit) ?? 12
        sessionMinutes = try values.decodeIfPresent(Int.self, forKey: .sessionMinutes) ?? 5
        friendUsernames = try values.decodeIfPresent([String].self, forKey: .friendUsernames) ?? []
    }

    var validated: FocusSettings {
        var copy = self
        copy.postLimit = min(30, max(3, postLimit))
        copy.sessionMinutes = min(30, max(1, sessionMinutes))
        copy.friendUsernames = Array(Set(friendUsernames.compactMap(FriendAccount.normalize))).sorted()
        return copy
    }
}

enum InstagramDestination: String, CaseIterable, Identifiable {
    case messages, home
    var id: String { rawValue }
    var title: String { self == .messages ? "Messages" : "Home & stories" }
    var url: URL {
        URL(string: self == .messages
            ? "https://www.instagram.com/direct/inbox/"
            : "https://www.instagram.com/")!
    }
    func url(settings: FocusSettings) -> URL {
        if self == .home && settings.feedMode == .following {
            return URL(string: "https://www.instagram.com/?variant=following")!
        }
        return url
    }
}
