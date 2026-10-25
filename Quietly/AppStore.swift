import SwiftUI
import Combine

@MainActor
final class AppStore: ObservableObject {
    @Published var settings: FocusSettings {
        didSet { save(settings.validated, key: "settings") }
    }
    @Published private(set) var session: FocusSession?
    @Published private(set) var completedSessions: Int
    @Published var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: "onboarded") }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settings = Self.read(FocusSettings.self, key: "settings", from: defaults)?.validated ?? FocusSettings()
        session = Self.read(FocusSession.self, key: "session", from: defaults)
        completedSessions = defaults.integer(forKey: "completedSessions")
        hasOnboarded = defaults.bool(forKey: "onboarded")
    }

    func start(_ destination: InstagramDestination, friend: String? = nil) {
        let newSession = FocusSession(minutes: settings.validated.sessionMinutes, destination: destination, profileUsername: friend)
        save(newSession, key: "session")
        session = newSession
    }

    func finish() {
        guard session != nil else { return }
        session = nil
        defaults.removeObject(forKey: "session")
        completedSessions += 1
        defaults.set(completedSessions, forKey: "completedSessions")
    }

    func resetLocalHistory() {
        completedSessions = 0
        defaults.removeObject(forKey: "completedSessions")
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private static func read<T: Decodable>(_ type: T.Type, key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
