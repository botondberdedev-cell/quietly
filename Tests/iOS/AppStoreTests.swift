import XCTest
@testable import Quietly

@MainActor
final class AppStoreTests: XCTestCase {
    func testSettingsAndVisitSurviveRelaunchWithoutExtendingDeadline() throws {
        let suite = "QuietlyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(defaults: defaults)
        store.hasOnboarded = true
        store.settings.sessionMinutes = 1
        store.settings.friendUsernames = ["@Alex", "alex", "invalid/path"]
        store.start(.home, friend: "alex")
        let original = try XCTUnwrap(store.session)
        let reopened = AppStore(defaults: defaults)
        XCTAssertTrue(reopened.hasOnboarded)
        XCTAssertEqual(reopened.settings.friendUsernames, ["alex"])
        XCTAssertEqual(reopened.session, original)
        XCTAssertEqual(reopened.session?.remaining(at: original.startedAt.addingTimeInterval(61)), 0)
        reopened.finish()
        reopened.finish()
        let finished = AppStore(defaults: defaults)
        XCTAssertNil(finished.session)
        XCTAssertEqual(finished.completedSessions, 1)
        finished.resetLocalHistory()
        XCTAssertEqual(AppStore(defaults: defaults).completedSessions, 0)
    }

    func testCorruptSettingsRecoverAndExpiredVisitRemainsEnded() throws {
        let suite = "QuietlyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("bad json".utf8), forKey: "settings")
        let expired = FocusSession(minutes: 1, destination: .messages, now: Date().addingTimeInterval(-120))
        defaults.set(try JSONEncoder().encode(expired), forKey: "session")
        let store = AppStore(defaults: defaults)
        XCTAssertEqual(store.settings, FocusSettings())
        XCTAssertTrue(try XCTUnwrap(store.session).hasEnded(at: Date()))
    }
}
