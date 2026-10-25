import SwiftUI

@main
struct QuietlyApp: App {
    @StateObject private var store = makeStore()
    @StateObject private var messageAlerts = makeMessageAlerts()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(messageAlerts)
                .tint(Palette.green)
        }
    }

    private static func makeMessageAlerts() -> MessageAlerts {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-quietly-ui-testing"),
           let defaults = UserDefaults(suiteName: "org.quietly.focus.ui-tests.alerts") {
            if ProcessInfo.processInfo.arguments.contains("-quietly-reset") {
                defaults.removePersistentDomain(forName: "org.quietly.focus.ui-tests.alerts")
            }
            return MessageAlerts(defaults: defaults)
        }
        #endif
        return MessageAlerts()
    }

    private static func makeStore() -> AppStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-quietly-ui-testing"),
           let defaults = UserDefaults(suiteName: "org.quietly.focus.ui-tests") {
            if ProcessInfo.processInfo.arguments.contains("-quietly-reset") {
                defaults.removePersistentDomain(forName: "org.quietly.focus.ui-tests")
            }
            return prepare(AppStore(defaults: defaults))
        }
        #endif
        return prepare(AppStore())
    }

    private static func prepare(_ store: AppStore) -> AppStore {
        if store.hasOnboarded && store.session == nil { store.start(.home) }
        return store
    }
}
