import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var messageAlerts: MessageAlerts
    @State private var showingSettings = false
    @State private var browserRevision = 0
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 40

    var body: some View {
        ZStack {
            if !store.hasOnboarded {
                onboarding
            } else if let session = store.session {
                SessionView(session: session, settings: store.settings.validated,
                            messageAlertsEnabled: messageAlerts.enabled,
                            isSettingsPresented: showingSettings, onSettings: { showingSettings = true })
                    .id(BrowserIdentity(sessionID: session.id, revision: browserRevision))
            } else {
                paused
            }
        }
        .sheet(isPresented: $showingSettings, onDismiss: { browserRevision += 1 }) { SettingsView() }
        .onChange(of: messageAlerts.enabled) { _, _ in browserRevision += 1 }
        .onChange(of: messageAlerts.openInboxRequested) { _, requested in
            guard requested else { return }
            showingSettings = false
            // Respect the visit budget: tapping an alert never silently starts a new visit.
            if store.session?.hasEnded() != false { messageAlerts.openInboxRequested = false }
        }
    }

    private var onboarding: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("QUIETLY").font(.caption.weight(.bold)).tracking(4)
                QuietMark().frame(maxWidth: .infinity).padding(.vertical, 12)
                Text("Your people.\nA quieter Instagram.")
                    .font(.system(size: titleSize, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Stories, conversations and the posts you came for.")
                    .font(.title3).foregroundStyle(Palette.secondaryText)
                feature("person.2", "Keep your people", "Keep friends’ photos and Reels, plus anything shared in your messages.")
                feature("rectangle.stack", "Keep the familiar experience", "Open Instagram’s own website, with its Stories and inbox. Skip the endless Reels and Explore feeds.")
                feature("lock", "Free and open source", "No Quietly account, subscriptions or analytics. Your settings stay on your device.")
                Text("Your home opens Instagram’s Following feed. No separate friends list needed. Instagram’s own privacy policy applies, and filters work inside Quietly.")
                    .font(.footnote).foregroundStyle(Palette.secondaryText)
                PrimaryButton(title: "Open Instagram") {
                    store.hasOnboarded = true
                    store.start(.home)
                }
                Button("Settings & privacy") { showingSettings = true }
                    .frame(maxWidth: .infinity, minHeight: 44).padding(.bottom, 10)
                    .accessibilityIdentifier("settings.open")
            }.padding(28).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }.background(Palette.paper)
    }

    private var paused: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    QuietMark().frame(maxWidth: .infinity).padding(.vertical, 18)
                    Text("A little room\nfor the rest of your day.")
                        .font(.system(size: titleSize, design: .serif))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Your visit has ended. Your people will still be here when you want to return.")
                        .font(.title3).foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    PrimaryButton(title: "Open Instagram", icon: "house") { store.start(.home) }
                    NavigationLink { FriendsView() } label: {
                        Label("Your people", systemImage: "person.2")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    if store.completedSessions > 0 {
                        Text(store.completedSessions == 1 ? "1 visit brought to a close." : "\(store.completedSessions) visits brought to a close.")
                            .font(.footnote).foregroundStyle(Palette.secondaryText)
                    }
                }.padding(28).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(Palette.paper)
            .navigationTitle("Quietly").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "slider.horizontal.3") { showingSettings = true }
                        .accessibilityIdentifier("settings.open")
                }
            }
        }
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Palette.green)
                .frame(width: 30).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Palette.secondaryText)
            }
        }
    }
}

private struct BrowserIdentity: Hashable {
    let sessionID: UUID
    let revision: Int
}
