import Combine
import Foundation
import UserNotifications

@MainActor
protocol MessageNotificationClient {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removeAlerts()
    func setDelegate(_ delegate: UNUserNotificationCenterDelegate)
}

@MainActor
final class SystemMessageNotificationClient: MessageNotificationClient {
    private let center = UNUserNotificationCenter.current()
    func authorizationStatus() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func requestAuthorization() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound]) }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func setDelegate(_ delegate: UNUserNotificationCenterDelegate) { center.delegate = delegate }
    func removeAlerts() {
        let identifiers = [MessageAlerts.messageIdentifier, MessageAlerts.testIdentifier]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

@MainActor
final class MessageAlerts: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let messageIdentifier = "quietly.unread-messages"
    static let testIdentifier = "quietly.notification-test"
    static let preferenceKey = "messageAlertsEnabled"
    @Published private(set) var enabled: Bool
    @Published private(set) var isRequestingPermission = false
    @Published private(set) var status: UNAuthorizationStatus = .notDetermined
    @Published private(set) var feedback: String?
    @Published var openInboxRequested = false
    private let defaults: UserDefaults
    private let client: MessageNotificationClient
    private var tracker = UnreadMessageTracker()
    private var deliveryGeneration = 0

    init(defaults: UserDefaults = .standard, client: MessageNotificationClient? = nil) {
        self.defaults = defaults
        self.client = client ?? SystemMessageNotificationClient()
        enabled = defaults.bool(forKey: Self.preferenceKey)
        super.init()
        self.client.setDelegate(self)
    }

    func refreshAuthorization() async {
        status = await client.authorizationStatus()
        if status == .denied { disable() }
    }

    func setEnabled(_ value: Bool) async {
        guard !isRequestingPermission else { return }
        feedback = nil
        resetObservation()
        guard value else { disable(); return }
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        do {
            let granted = try await client.requestAuthorization()
            status = await client.authorizationStatus()
            enabled = granted
            defaults.set(granted, forKey: Self.preferenceKey)
            if !granted { feedback = "Notifications are off in iPhone Settings. You can enable them there." }
        } catch {
            disable()
            feedback = "Notification permission could not be requested. Try again."
        }
    }

    private func disable() {
        enabled = false
        defaults.set(false, forKey: Self.preferenceKey)
        resetObservation()
        client.removeAlerts()
    }

    func resetObservation() {
        tracker.reset()
        deliveryGeneration += 1
    }

    func observe(_ count: Int?, active: Bool, now: Date = Date()) async {
        guard enabled, active else { resetObservation(); return }
        guard tracker.observe(count, at: now) else { return }
        let generation = deliveryGeneration
        let authorization = await client.authorizationStatus()
        guard generation == deliveryGeneration, enabled,
              authorization == .authorized || authorization == .provisional || authorization == .ephemeral else { return }
        let content = UNMutableNotificationContent()
        content.title = "New messages on Instagram"
        content.body = "Your unread message count increased. Tap to open your inbox."
        content.sound = .default
        content.userInfo = ["destination": "messages"]
        do {
            try await client.add(UNNotificationRequest(identifier: Self.messageIdentifier, content: content, trigger: nil))
        } catch {
            feedback = "The message alert could not be delivered. Your inbox is still available."
        }
    }

    func sendTest() async {
        feedback = nil
        await refreshAuthorization()
        guard enabled, status == .authorized || status == .provisional || status == .ephemeral else {
            feedback = "Enable message alerts first."
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Quietly notification test"
        content.body = "Notifications work. Message detection runs only while Quietly is open."
        content.sound = .default
        do {
            try await client.add(UNNotificationRequest(identifier: Self.testIdentifier, content: content, trigger: nil))
            feedback = "Test notification sent. iPhone notification settings control its appearance and sound."
        } catch {
            feedback = "The test notification could not be delivered. Try again."
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        let defaultAction = response.actionIdentifier == UNNotificationDefaultActionIdentifier
        Task { @MainActor [weak self] in
            if identifier == Self.messageIdentifier && defaultAction { self?.openInboxRequested = true }
            completionHandler()
        }
    }
}
