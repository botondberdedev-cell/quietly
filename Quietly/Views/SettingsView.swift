import SwiftUI
import WebKit

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var messageAlerts: MessageAlerts
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false
    @State private var isClearing = false
    @State private var cleared = false
    @State private var friendInput = ""
    @State private var friendError: String?
    @FocusState private var friendInputIsFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Block the Reels feed", isOn: $store.settings.blockReels)
                    Toggle("Hide Explore", isOn: $store.settings.blockExplore)
                    Toggle("Hide sponsored posts", isOn: $store.settings.hideAds)
                    Picker("Home feed", selection: $store.settings.feedMode) {
                        ForEach(FeedMode.allCases) { Text($0.title).tag($0) }
                    }
                    if store.settings.feedMode == .limited {
                        Stepper("Up to \(store.settings.postLimit) posts", value: $store.settings.postLimit, in: 3...30, step: 3)
                    }
                } header: { Text("Make room") } footer: {
                    Text("People I follow opens Instagram’s Following feed, including Stories. Shared posts and Reels open individually. Sponsored cards are hidden when their ad label is recognized; filters may need updates when Instagram changes.")
                }

                Section {
                    HStack {
                        TextField("Instagram username", text: $friendInput)
                            .focused($friendInputIsFocused)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .submitLabel(.done).onSubmit(addFriend)
                            .accessibilityLabel("Friend’s Instagram username")
                        Button("Add", action: addFriend).disabled(friendInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if let friendError { Text(friendError).foregroundStyle(.red).font(.footnote) }
                    ForEach(store.settings.friendUsernames, id: \.self) { name in Text("@\(name)") }
                        .onDelete { offsets in store.settings.friendUsernames.remove(atOffsets: offsets) }
                } header: { Text("Saved friends · optional") } footer: {
                    Text("Profile shortcuts and the optional saved-friends filter. Your Following feed works without this list. Swipe a name to remove it. All posts and Reels shared in DMs are allowed, regardless of who created them.")
                }

                Section {
                    Picker("Visit length", selection: $store.settings.sessionMinutes) {
                        ForEach([1, 3, 5, 10, 15, 20, 30], id: \.self) { minutes in
                            Text(minutes == 1 ? "1 minute" : "\(minutes) minutes").tag(minutes)
                        }
                    }
                } header: { Text("A time to finish") } footer: {
                    Text("The visit ends at its scheduled time, including time spent away from the app. You can always choose to start another visit.")
                }

                Section {
                    Toggle("Message alerts while open", isOn: Binding(
                        get: { messageAlerts.enabled },
                        set: { value in Task { await messageAlerts.setEnabled(value) } }
                    ))
                    .disabled(messageAlerts.isRequestingPermission)
                    .accessibilityIdentifier("notifications.enabled")
                    if messageAlerts.enabled {
                        Button("Send test notification") { Task { await messageAlerts.sendTest() } }
                            .accessibilityIdentifier("notifications.test")
                    }
                    if messageAlerts.status == .denied {
                        Button("Open iPhone notification settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                    }
                    if let feedback = messageAlerts.feedback {
                        Text(feedback).font(.footnote).foregroundStyle(Palette.secondaryText)
                    }
                } header: { Text("Messages") } footer: {
                    Text("Alerts when Instagram’s unread-message indicator increases while Quietly is open. No sender names or message previews are included. Detection depends on Instagram’s layout and stops when Quietly is closed or backgrounded. For messages while away, keep Instagram’s own message notifications enabled.")
                }

                Section("Your data") {
                    NavigationLink("Privacy & how it works") { privacy }
                    Button(isClearing ? "Clearing…" : "Clear Instagram login & website data", role: .destructive) {
                        confirmClear = true
                    }.disabled(isClearing)
                    Button("Reset completed visit count", role: .destructive) { store.resetLocalHistory() }
                    if cleared { Text("Website data cleared on this device.").font(.footnote).foregroundStyle(Palette.secondaryText) }
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0 · Prototype")
                    LabeledContent("License", value: "MIT · Open source")
                    Link("Source code on GitHub", destination: URL(string: "https://github.com/botondberdedev-cell/quietly")!)
                    Text("Quietly is an independent project, not affiliated with Instagram, Meta or SocialLite. Quietly is a working name.")
                        .font(.footnote).foregroundStyle(Palette.secondaryText)
                    NavigationLink("Open-source license") {
                        ScrollView {
                            Text(license).font(.footnote).textSelection(.enabled).padding()
                        }.navigationTitle("MIT License")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Your boundaries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.accessibilityIdentifier("settings.done")
            } }
            .confirmationDialog("Clear Instagram’s saved login?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear website data", role: .destructive) {
                    isClearing = true
                    messageAlerts.resetObservation()
                    WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {
                        isClearing = false
                        cleared = true
                    }
                }
            } message: {
                Text("This signs you out in Quietly and removes its saved website data. Your Instagram account stays intact.")
            }
            .task { await messageAlerts.refreshAuthorization() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await messageAlerts.refreshAuthorization() } }
            }
        }
    }

    private var privacy: some View {
        List {
            Section("How browsing works") {
                Text("Quietly loads instagram.com in Apple’s embedded WebKit browser. You sign in on Instagram’s page. The app applies bundled filters to page elements and navigation; it does not modify the installed Instagram app.")
                Text("Messages, stories, profiles, posting and authentication depend on what Instagram supports on its mobile website. Optional message alerts detect increases in its unread indicator only while Quietly is open. Background message delivery and native calls are not provided. Facebook login may need a separate browser and is not validated in this prototype.")
            }
            Section("Stored on your device") {
                Text("Your filter preferences, Friends list, current visit deadline and completed visit count are saved locally. WebKit stores Instagram cookies and website data to keep you signed in. You can clear them in Settings.")
            }
            Section("No Quietly servers") {
                Text("This build has no developer-operated server, analytics, ads, purchases or third-party SDKs. Filters inspect link destinations and author links, without extracting passwords or message text. The native bridge receives filter status, the identifier of a post you choose to open and, when alerts are enabled, the unread-message count. Post identifiers and unread counts are not saved to browsing history or sent to a Quietly server. Local notifications use generic text without sender names or message previews.")
            }
            Section("Instagram is a separate service") {
                Text("Instagram still receives your login, messages and browsing requests and handles them under its own terms and privacy policy. Quietly cannot remove Instagram’s own data collection. Website resources may contact Meta and other providers.")
                Link("Instagram’s privacy policy", destination: URL(string: "https://privacycenter.instagram.com/policy/")!)
            }
            Section("Prototype limitations") {
                Text("Filters depend on Instagram’s page structure and may break when it changes. Ad hiding covers recognized sponsored feed cards; Story ads and unfamiliar layouts may still appear. This is a voluntary focus tool, not a parental lock. It has not yet been validated on a physical iPhone.")
            }
        }.navigationTitle("Privacy & details")
    }

    private var license: String {
        guard let url = Bundle.main.url(forResource: "LICENSE", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "MIT License — see the project’s LICENSE file." }
        return text
    }

    private func addFriend() {
        guard let name = FriendAccount.normalize(friendInput) else {
            friendError = "Enter a username, such as @alex, without a website address."
            return
        }
        if !store.settings.friendUsernames.contains(name) {
            store.settings.friendUsernames.append(name)
            store.settings.friendUsernames.sort()
        }
        friendInput = ""
        friendError = nil
        friendInputIsFocused = false
    }
}
