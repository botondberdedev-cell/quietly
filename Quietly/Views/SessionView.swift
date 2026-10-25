import SwiftUI
import SafariServices
import Combine

struct SessionView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var messageAlerts: MessageAlerts
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var browser: InstagramBrowser
    @State private var now = Date()
    @State private var externalPage: ExternalPage?
    let session: FocusSession
    let settings: FocusSettings
    let isSettingsPresented: Bool
    let onSettings: () -> Void
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(session: FocusSession, settings: FocusSettings, messageAlertsEnabled: Bool, isSettingsPresented: Bool, onSettings: @escaping () -> Void) {
        self.session = session
        self.settings = settings
        self.isSettingsPresented = isSettingsPresented
        self.onSettings = onSettings
        _browser = StateObject(wrappedValue: InstagramBrowser(settings: settings, deadline: session.endsAt,
                                                             messageAlertsEnabled: messageAlertsEnabled))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if !dynamicTypeSize.isAccessibilitySize { Text("Quietly").font(.headline) }
                Spacer()
                Label(timeRemaining, systemImage: "hourglass")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.secondaryText)
                    .accessibilityLabel("\(session.remaining(at: now)) seconds remaining")
                Button(action: onSettings) {
                    Label("Settings", systemImage: "slider.horizontal.3")
                        .labelStyle(.iconOnly).frame(width: 44, height: 44).contentShape(Rectangle())
                }
                    .accessibilityIdentifier("settings.open")
                Button(action: finish) {
                    Label("End visit", systemImage: "xmark")
                        .labelStyle(.iconOnly).frame(width: 44, height: 44).contentShape(Rectangle())
                }
                    .accessibilityIdentifier("session.end")
            }.buttonStyle(.plain).padding(.horizontal).padding(.vertical, 4)
            if browser.inlinePostIsActive && !session.hasEnded(at: now) {
                HStack {
                    Text("One shared Reel").font(.subheadline)
                    Spacer()
                    Button("Close Reel") { browser.closeInlinePost() }
                        .frame(minHeight: 44).contentShape(Rectangle())
                        .accessibilityIdentifier("post.inline.close")
                }.padding(.horizontal).padding(.vertical, 8)
            }
            ZStack {
                InstagramWebView(browser: browser, isInteractive: !session.hasEnded(at: now)
                                 && browser.boundary == nil && browser.failure == nil
                                 && !isSettingsPresented && externalPage == nil && browser.selectedPost == nil)
                if session.hasEnded(at: now) {
                    boundaryView(title: "A good place\nto stop.", detail: "Your visit is complete. The rest of your day is waiting.", isEnd: true)
                } else if let reason = browser.boundary {
                    boundaryView(title: reason, detail: "You made room for something else. Your messages are still here.", isEnd: false)
                } else if let failure = browser.failure {
                    VStack(spacing: 20) {
                        Image(systemName: "wifi.exclamationmark").font(.largeTitle)
                        Text(failure).multilineTextAlignment(.center)
                        Button("Try again") { browser.retry() }.buttonStyle(.borderedProminent)
                        Button("End visit") { finish() }
                    }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.paper)
                } else if browser.isLoading {
                    VStack { ProgressView().padding(12).background(.regularMaterial, in: Capsule()); Spacer() }
                        .padding(.top, 10).allowsHitTesting(false)
                }
            }
            if !session.hasEnded(at: now) {
                HStack {
                    Button("Back", systemImage: "chevron.left") { browser.webView.goBack() }
                        .disabled(!browser.canGoBack)
                    Spacer()
                    Button("Messages", systemImage: "bubble.left.and.bubble.right") { browser.navigate(.messages) }
                        .accessibilityIdentifier("tab.messages")
                        .accessibilityValue(browser.inboxUnreadCount.map { "\($0) unread" } ?? "")
                    Spacer()
                    Button("Home", systemImage: "house") { browser.navigate(.home) }
                        .accessibilityIdentifier("tab.home")
                    if !settings.friendUsernames.isEmpty {
                        Spacer()
                        Menu("Friends", systemImage: "person.2") {
                            ForEach(settings.friendUsernames, id: \.self) { name in
                                Button("@\(name)") { browser.navigateToFriend(name) }
                            }
                        }
                    }
                }.labelStyle(.iconOnly).font(.title3).padding()
            }
        }
        .background(Palette.paper)
        .onAppear {
            messageAlerts.resetObservation()
            now = Date()
            browser.setSceneActive(scenePhase == .active)
            browser.setExternalPagePresented(isSettingsPresented || externalPage != nil)
            if session.hasEnded(at: now) { browser.stop() }
            else if messageAlerts.openInboxRequested {
                browser.start(.messages)
                messageAlerts.openInboxRequested = false
            } else { browser.start(session.destination, profileUsername: session.profileUsername) }
        }
        .onReceive(browser.$inboxUnreadCount) { count in
            Task { await messageAlerts.observe(count, active: scenePhase == .active && !session.hasEnded()
                                               && browser.failure == nil) }
        }
        .onChange(of: messageAlerts.openInboxRequested) { _, requested in
            if requested {
                if !session.hasEnded() { browser.navigate(.messages) }
                messageAlerts.openInboxRequested = false
            }
        }
        .onReceive(timer) { tick in
            now = tick
            if session.hasEnded(at: tick) {
                messageAlerts.resetObservation()
                browser.stop()
                externalPage = nil
                browser.externalURL = nil
                browser.selectedPost = nil
            }
        }
        .onChange(of: scenePhase) { _, phase in
            messageAlerts.resetObservation()
            now = Date()
            browser.setSceneActive(phase == .active)
            if session.hasEnded(at: now) { browser.stop(); externalPage = nil }
        }
        .onChange(of: externalPage != nil || isSettingsPresented) { _, presented in browser.setExternalPagePresented(presented) }
        .onDisappear { browser.stop(); messageAlerts.resetObservation() }
        .confirmationDialog("Open outside Quietly’s filters?", isPresented: Binding(
            get: { browser.externalURL != nil },
            set: { if !$0 { browser.externalURL = nil } }
        ), titleVisibility: .visible) {
            if let url = browser.externalURL {
                Button("Open \(url.host ?? "link")") {
                    externalPage = ExternalPage(url: url)
                    browser.externalURL = nil
                }
            }
            Button("Cancel", role: .cancel) { browser.externalURL = nil }
        } message: {
            Text("This link opens in a Safari view. Quietly’s content filters don’t apply there.")
        }
        .sheet(item: $externalPage) { SafariPage(url: $0.url) }
        .sheet(item: $browser.selectedPost) { post in
            SinglePostView(post: post, settings: settings, deadline: session.endsAt)
        }
    }

    private var timeRemaining: String {
        let seconds = session.remaining(at: now)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func finish() { browser.stop(); store.finish() }

    private func boundaryView(title: String, detail: String, isEnd: Bool) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                QuietMark().padding(.top, 32)
                Text(title).font(.system(size: 36, design: .serif)).multilineTextAlignment(.center)
                Text(detail).foregroundStyle(Palette.secondaryText).multilineTextAlignment(.center)
                PrimaryButton(title: "Back to my day", icon: "checkmark") { finish() }
                if !isEnd { Button("Return to messages") { browser.navigate(.messages) } }
            }.padding(28).frame(maxWidth: 500).frame(maxWidth: .infinity)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.paper)
    }
}

private struct ExternalPage: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SafariPage: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
