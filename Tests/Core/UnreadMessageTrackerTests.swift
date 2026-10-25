import XCTest
@testable import QuietlyCore

final class UnreadMessageTrackerTests: XCTestCase {
    func testInitialUnreadMessagesAndDuplicateCountsStayQuiet() {
        var tracker = UnreadMessageTracker()
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertFalse(tracker.observe(3, at: now))
        XCTAssertFalse(tracker.observe(3, at: now))
        XCTAssertTrue(tracker.observe(4, at: now))
        XCTAssertFalse(tracker.observe(4, at: now.addingTimeInterval(20)))
        XCTAssertFalse(tracker.observe(0, at: now.addingTimeInterval(20)))
        XCTAssertTrue(tracker.observe(1, at: now.addingTimeInterval(20)))
    }

    func testUnknownLayoutAndNewPagesRequireANewBaseline() {
        var tracker = UnreadMessageTracker()
        XCTAssertFalse(tracker.observe(0))
        XCTAssertFalse(tracker.observe(nil))
        XCTAssertFalse(tracker.observe(8))
        tracker.reset()
        XCTAssertFalse(tracker.observe(9))
        XCTAssertFalse(tracker.observe(-1))
        XCTAssertFalse(tracker.observe(1000))
        XCTAssertFalse(tracker.observe(10))
        XCTAssertTrue(tracker.observe(11))
    }

    func testBurstsAreThrottledWithoutReplayingOldMessages() {
        var tracker = UnreadMessageTracker()
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertFalse(tracker.observe(0, at: now))
        XCTAssertTrue(tracker.observe(1, at: now))
        XCTAssertFalse(tracker.observe(2, at: now.addingTimeInterval(1)))
        XCTAssertFalse(tracker.observe(2, at: now.addingTimeInterval(20)))
        XCTAssertTrue(tracker.observe(3, at: now.addingTimeInterval(20)))
        tracker.reset()
        XCTAssertFalse(tracker.observe(0, at: now.addingTimeInterval(21)))
        XCTAssertFalse(tracker.observe(1, at: now.addingTimeInterval(22)))
    }
}
