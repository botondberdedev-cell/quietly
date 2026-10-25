import Foundation

struct InstagramPost: Equatable, Identifiable {
    let id: String

    init?(id: String) {
        guard id.range(of: "^[A-Za-z0-9_-]{1,64}$", options: .regularExpression) != nil else { return nil }
        self.id = id
    }

    init?(url: URL) {
        guard NavigationPolicy.isInstagram(url) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        if parts.count == 2 && ["p", "reel", "reels"].contains(parts[0]) {
            self.init(id: parts[1])
        } else if parts.count == 3 && ["p", "reel"].contains(parts[1]) && FriendAccount.normalize(parts[0]) != nil {
            self.init(id: parts[2])
        } else { return nil }
    }

    // Authenticated post page: public embeds cannot cover private friends' posts.
    var url: URL { URL(string: "https://www.instagram.com/p/\(id)/")! }
}
