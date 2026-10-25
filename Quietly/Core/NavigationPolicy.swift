import Foundation

enum NavigationDecision: Equatable {
    case allow, external, deny
    case blocked(String)
}

enum NavigationPolicy {
    static func isInstagram(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else { return false }
        return ["instagram.com", "www.instagram.com"].contains(url.host?.lowercased() ?? "")
    }

    static func decision(for url: URL, settings: FocusSettings, singlePost: InstagramPost? = nil) -> NavigationDecision {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return .deny }
        guard isInstagram(url) else { return singlePost == nil ? .external : .blocked("One post at a time") }
        if let singlePost {
            return InstagramPost(url: url) == singlePost ? .allow : .blocked("One post at a time")
        }
        let component = url.path.split(separator: "/").first.map(String.init)?.lowercased() ?? ""
        let parts = url.path.split(separator: "/").map(String.init)
        let profileReel = parts.count >= 2 && parts[1] == "reel"
        if settings.blockReels && (["reel", "reels"].contains(component) || profileReel) {
            return .blocked("Reels are paused")
        }
        if settings.blockExplore && component == "explore" {
            return .blocked("Explore is paused")
        }
        return .allow
    }

    static func isFriendContext(_ url: URL, settings: FocusSettings) -> Bool {
        guard isInstagram(url) else { return false }
        if url.path.hasPrefix("/direct/") || url.path.hasPrefix("/stories/") { return true }
        if settings.feedMode == .following && isFollowingFeed(url) { return true }
        return FriendAccount.username(on: url).map { settings.validated.friendUsernames.contains($0) } ?? false
    }

    static func isFollowingFeed(_ url: URL) -> Bool {
        isInstagram(url) && (url.path.isEmpty || url.path == "/") &&
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .first(where: { $0.name == "variant" })?.value == "following"
    }

    // These contexts come exclusively from our isolated script after examining
    // profile controls. Require the reported username to match the current route.
    static func allowsObservedProfile(_ url: URL, context: String?, username: String?, settings: FocusSettings) -> Bool {
        guard let profile = FriendAccount.username(on: url), profile == username else { return false }
        return context == "own-profile" || (context == "followed-profile" && settings.feedMode == .following)
    }
}
