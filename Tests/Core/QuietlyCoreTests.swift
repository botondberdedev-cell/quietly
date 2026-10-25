import XCTest
@testable import QuietlyCore

final class QuietlyCoreTests: XCTestCase {
    private var settings = FocusSettings()

    func testMessagesStoriesProfilesAndLoginRemainAvailable() {
        for path in ["/direct/inbox/", "/stories/friend/123/", "/friend/", "/accounts/login/", "/challenge/", "/p/abc/"] {
            XCTAssertEqual(decision("https://www.instagram.com" + path), .allow)
        }
    }

    func testReelRoutesAndExploreAreBlocked() {
        for path in ["/reel/abc/", "/reels", "/reels/abc/?source=dm", "/%72eels/"] {
            XCTAssertEqual(decision("https://www.instagram.com" + path), .blocked("Reels are paused"))
        }
        XCTAssertEqual(decision("https://instagram.com/explore/tags/travel"), .blocked("Explore is paused"))
        XCTAssertEqual(decision("https://www.instagram.com/reelsfan/"), .allow)
    }

    func testSettingsCanPermitReelsAndExplore() {
        settings.blockReels = false
        settings.blockExplore = false
        XCTAssertEqual(decision("https://www.instagram.com/reel/abc"), .allow)
        XCTAssertEqual(decision("https://www.instagram.com/explore/"), .allow)
    }

    func testUntrustedOriginsDoNotOpenInsideApp() {
        for url in ["https://instagram.com.evil.example/reels/", "https://evilinstagram.com/", "https://www.instagram.com@evil.example/", "http://www.instagram.com/", "https://www.instagram.com:444/", "https://user@www.instagram.com/"] {
            XCTAssertEqual(decision(url), .external)
            XCTAssertFalse(NavigationPolicy.isInstagram(URL(string: url)!))
        }
    }

    func testAppAndExecutableSchemesAreDenied() {
        for url in ["instagram://reels", "javascript:alert(1)", "file:///etc/passwd", "data:text/html,hello", "tel:123"] {
            XCTAssertEqual(decision(url), .deny)
        }
    }

    func testBudgetHasExactBoundaryAndSurvivesCoding() throws {
        let start = Date(timeIntervalSince1970: 1000)
        let session = FocusSession(minutes: 5, destination: .messages, now: start)
        XCTAssertEqual(session.remaining(at: start), 300)
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(299.1)), 1)
        XCTAssertFalse(session.hasEnded(at: start.addingTimeInterval(299)))
        XCTAssertTrue(session.hasEnded(at: start.addingTimeInterval(300)))
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(10000)), 0)
        let restored = try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(restored, session)
        XCTAssertTrue(restored.hasEnded(at: start.addingTimeInterval(600)))
    }

    func testCorruptSettingsCannotProduceUnboundedSession() {
        var s = FocusSettings()
        s.postLimit = -2
        s.sessionMinutes = 999
        XCTAssertEqual(s.validated.postLimit, 3)
        XCTAssertEqual(s.validated.sessionMinutes, 30)
        let start = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(FocusSession(minutes: -1, destination: .home, now: start).remaining(at: start), 60)
    }

    func testFriendsNormalizeWithoutAllowingRoutesOrHostInjection() {
        XCTAssertEqual(FriendAccount.normalize(" @Alice.Name "), "alice.name")
        for name in ["reels", "direct", "../alice", "alice/", "https://instagram.com/alice", "alice@evil.com", "alice?x=1", ""] {
            XCTAssertNil(FriendAccount.normalize(name), name)
        }
        settings.friendUsernames = ["@Alice", "ALICE", "bob", "../evil"]
        XCTAssertEqual(settings.validated.friendUsernames, ["alice", "bob"])
        XCTAssertTrue(NavigationPolicy.isFriendContext(URL(string: "https://www.instagram.com/alice/reels/")!, settings: settings))
        XCTAssertFalse(NavigationPolicy.isFriendContext(URL(string: "https://www.instagram.com/other/")!, settings: settings))
        XCTAssertFalse(NavigationPolicy.isFriendContext(URL(string: "https://evil.example/direct/t/123/")!, settings: settings))
    }

    func testOldSettingsAndSessionsMigrateWithoutLosingPreferences() throws {
        let json = #"{"blockReels":false,"blockExplore":true,"feedMode":"limited","postLimit":6,"sessionMinutes":10}"#
        let restored = try JSONDecoder().decode(FocusSettings.self, from: Data(json.utf8))
        XCTAssertEqual(restored.friendUsernames, [])
        XCTAssertFalse(restored.blockReels)
        XCTAssertEqual(restored.postLimit, 6)
        XCTAssertTrue(restored.hideAds)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(FocusSession(minutes: 5, destination: .home))) as? [String: Any])
        object.removeValue(forKey: "profileUsername")
        let session = try JSONDecoder().decode(FocusSession.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(session.profileUsername)
    }

    func testFollowingIsDefaultAndOnlyTrustedFollowingRoutesGrantPostContext() {
        XCTAssertEqual(settings.feedMode, .following)
        XCTAssertTrue(settings.hideAds)
        let following = InstagramDestination.home.url(settings: settings)
        XCTAssertEqual(following.absoluteString, "https://www.instagram.com/?variant=following")
        XCTAssertTrue(NavigationPolicy.isFriendContext(following, settings: settings))
        for value in ["https://evil.example/?variant=following", "https://www.instagram.com/?variant=other", "https://www.instagram.com/reels/?variant=following"] {
            XCTAssertFalse(NavigationPolicy.isFollowingFeed(URL(string: value)!))
        }
        XCTAssertTrue(NavigationPolicy.isFriendContext(URL(string: "https://www.instagram.com/stories/friend/1/")!, settings: settings))
        settings.feedMode = .hidden
        XCTAssertEqual(InstagramDestination.home.url(settings: settings), InstagramDestination.home.url)
        XCTAssertFalse(NavigationPolicy.isFriendContext(following, settings: settings))
    }

    func testSinglePostAllowsOnlyTheSelectedIDAcrossCanonicalRedirects() throws {
        let post = try XCTUnwrap(InstagramPost(id: "AbC_123"))
        for path in ["/p/AbC_123/", "/reel/AbC_123/", "/reels/AbC_123/?source=dm", "/alice/reel/AbC_123/"] {
            XCTAssertEqual(NavigationPolicy.decision(for: URL(string: "https://www.instagram.com" + path)!, settings: settings, singlePost: post), .allow)
        }
        for url in ["https://www.instagram.com/reels/", "https://www.instagram.com/reel/next/", "https://www.instagram.com/p/next/", "https://www.instagram.com/", "https://evil.example/p/AbC_123/"] {
            XCTAssertEqual(NavigationPolicy.decision(for: URL(string: url)!, settings: settings, singlePost: post), .blocked("One post at a time"))
        }
        XCTAssertEqual(decision("https://www.instagram.com/alice/reel/AbC_123/"), .blocked("Reels are paused"))
    }

    func testPostIDsCannotInjectURLsAndDoNotTreatFeedRoutesAsPosts() {
        for id in ["../next", "abc/def", "abc?next=x", "abc#next", "", String(repeating: "a", count: 65)] {
            XCTAssertNil(InstagramPost(id: id))
        }
        for url in ["https://www.instagram.com/reels/", "https://www.instagram.com/reel/id/embed/", "https://evil.example/p/123/", "http://www.instagram.com/p/123/"] {
            XCTAssertNil(InstagramPost(url: URL(string: url)!))
        }
    }

    func testObservedOwnAndFollowedProfilesAreBoundToTheCurrentUsername() {
        for path in ["/myself/", "/myself/reels/", "/myself/tagged/"] {
            let url = URL(string: "https://www.instagram.com" + path)!
            XCTAssertTrue(NavigationPolicy.allowsObservedProfile(url, context: "own-profile", username: "myself", settings: settings))
            XCTAssertTrue(NavigationPolicy.allowsObservedProfile(url, context: "followed-profile", username: "myself", settings: settings))
            XCTAssertFalse(NavigationPolicy.allowsObservedProfile(url, context: "own-profile", username: "another", settings: settings))
        }
        for path in ["/reels/", "/explore/", "/p/abc/", "/direct/inbox/"] {
            XCTAssertFalse(NavigationPolicy.allowsObservedProfile(URL(string: "https://www.instagram.com" + path)!, context: "own-profile", username: "reels", settings: settings))
        }
        settings.feedMode = .hidden
        let profile = URL(string: "https://www.instagram.com/myself/")!
        XCTAssertFalse(NavigationPolicy.allowsObservedProfile(profile, context: "followed-profile", username: "myself", settings: settings))
        XCTAssertTrue(NavigationPolicy.allowsObservedProfile(profile, context: "own-profile", username: "myself", settings: settings))
        XCTAssertFalse(NavigationPolicy.allowsObservedProfile(URL(string: "https://evil.example/myself/")!, context: "own-profile", username: "myself", settings: settings))
    }

    private func decision(_ value: String) -> NavigationDecision {
        NavigationPolicy.decision(for: URL(string: value)!, settings: settings)
    }
}
