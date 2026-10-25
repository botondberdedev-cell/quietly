import XCTest
import UserNotifications
@testable import Quietly

@MainActor
private final class FakeNotificationClient: MessageNotificationClient {
    var status: UNAuthorizationStatus = .authorized
    var requests: [UNNotificationRequest] = []
    var removed = 0
    var shouldFail = false
    var onStatus: (() -> Void)?
    func authorizationStatus() async -> UNAuthorizationStatus { onStatus?(); return status }
    func requestAuthorization() async throws -> Bool { status == .authorized }
    func add(_ request: UNNotificationRequest) async throws {
        if shouldFail { throw NSError(domain: "Fixture", code: 1) }
        requests.append(request)
    }
    func removeAlerts() { removed += 1 }
    func setDelegate(_ delegate: UNUserNotificationCenterDelegate) {}
}

@MainActor
final class MessageAlertsTests: XCTestCase {
    private func setup() throws -> (MessageAlerts, FakeNotificationClient, UserDefaults) {
        let suite = "QuietlyAlertsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let client = FakeNotificationClient()
        return (MessageAlerts(defaults: defaults, client: client), client, defaults)
    }

    func testPermissionOptInAndPrivateDeduplicatedAlert() async throws {
        let (alerts, client, defaults) = try setup()
        XCTAssertFalse(alerts.enabled)
        await alerts.observe(0, active: true)
        await alerts.observe(1, active: true)
        XCTAssertTrue(client.requests.isEmpty)
        await alerts.setEnabled(true)
        XCTAssertTrue(defaults.bool(forKey: MessageAlerts.preferenceKey))
        await alerts.observe(3, active: true)
        await alerts.observe(4, active: true)
        await alerts.observe(4, active: true)
        XCTAssertEqual(client.requests.count, 1)
        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.identifier, MessageAlerts.messageIdentifier)
        XCTAssertEqual(request.content.title, "New messages on Instagram")
        XCTAssertEqual(request.content.userInfo as? [String: String], ["destination": "messages"])
        XCTAssertNil(request.trigger)
        XCTAssertTrue(request.content.attachments.isEmpty)
    }

    func testBackgroundAndRevokedPermissionDoNotDeliver() async throws {
        let (alerts, client, _) = try setup()
        await alerts.setEnabled(true)
        await alerts.observe(0, active: true)
        await alerts.observe(1, active: false)
        await alerts.observe(5, active: true)
        XCTAssertTrue(client.requests.isEmpty)
        client.status = .denied
        await alerts.observe(6, active: true)
        XCTAssertTrue(client.requests.isEmpty)
        await alerts.refreshAuthorization()
        XCTAssertFalse(alerts.enabled)
        XCTAssertEqual(client.removed, 1)
    }

    func testSuspensionDuringPermissionLookupCancelsDelivery() async throws {
        let (alerts, client, _) = try setup()
        await alerts.setEnabled(true)
        await alerts.observe(0, active: true)
        client.onStatus = { alerts.resetObservation() }
        await alerts.observe(1, active: true)
        XCTAssertTrue(client.requests.isEmpty)
    }

    func testDenialTestNotificationAndDisableCleanup() async throws {
        let (alerts, client, _) = try setup()
        client.status = .denied
        await alerts.setEnabled(true)
        XCTAssertFalse(alerts.enabled)
        XCTAssertNotNil(alerts.feedback)
        await alerts.sendTest()
        XCTAssertTrue(client.requests.isEmpty)
        client.status = .authorized
        await alerts.setEnabled(true)
        await alerts.sendTest()
        XCTAssertEqual(client.requests.first?.identifier, MessageAlerts.testIdentifier)
        XCTAssertEqual(client.requests.first?.content.userInfo.count, 0)
        client.shouldFail = true
        await alerts.sendTest()
        XCTAssertTrue(alerts.feedback?.contains("could not") == true)
        await alerts.setEnabled(false)
        XCTAssertFalse(alerts.enabled)
        XCTAssertGreaterThan(client.removed, 0)
    }
}
