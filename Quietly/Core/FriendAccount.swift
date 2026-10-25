import Foundation

enum FriendAccount {
    private static let reserved = Set(["accounts", "about", "api", "challenge", "direct", "directory", "explore", "legal", "p", "reel", "reels", "stories", "web", "oauth", "share"])

    static func normalize(_ input: String) -> String? {
        let name = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^@", with: "", options: .regularExpression).lowercased()
        guard name.range(of: "^[a-z0-9_][a-z0-9._]{0,29}$", options: .regularExpression) != nil,
              !name.hasSuffix("."), !name.contains(".."), !reserved.contains(name) else { return nil }
        return name
    }

    static func profileURL(_ username: String) -> URL? {
        guard let name = normalize(username) else { return nil }
        return URL(string: "https://www.instagram.com/\(name)/")
    }

    static func username(on url: URL) -> String? {
        guard NavigationPolicy.isInstagram(url) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count == 1 || (parts.count == 2 && ["reels", "tagged"].contains(parts[1])),
              let name = parts.first else { return nil }
        return normalize(name)
    }
}
