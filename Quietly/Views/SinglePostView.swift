import SwiftUI
import Combine

struct SinglePostView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var browser: InstagramBrowser
    let deadline: Date
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(post: InstagramPost, settings: FocusSettings, deadline: Date) {
        self.deadline = deadline
        _browser = StateObject(wrappedValue: InstagramBrowser(settings: settings, deadline: deadline, singlePost: post))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                InstagramWebView(browser: browser, isInteractive: browser.postState == "ready" && browser.boundary == nil && browser.failure == nil)
                if browser.postState != "ready" || browser.boundary != nil || browser.failure != nil {
                    VStack(spacing: 20) {
                        if browser.postState == "loading" && browser.failure == nil && browser.boundary == nil {
                            ProgressView("Opening this post…")
                        } else {
                            Image(systemName: "photo.on.rectangle").font(.largeTitle)
                            Text("This post isn’t available here yet.").font(.headline)
                            Text("It may be private, removed, or using a layout Quietly can’t isolate. Sign in from Messages first if needed.")
                                .foregroundStyle(Palette.secondaryText).multilineTextAlignment(.center)
                            Button("Try again") { browser.retry() }
                        }
                        Button("Return to browsing") { dismiss() }
                    }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.paper)
                }
            }
            .navigationTitle("One post, all yours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                Text("Your visit timer continues. Close to return to your friends.")
                    .font(.footnote).foregroundStyle(Palette.secondaryText).padding().frame(maxWidth: .infinity).background(Palette.paper)
            }
        }
        .onAppear { browser.setSceneActive(scenePhase == .active); browser.start(.messages) }
        .onDisappear { browser.stop() }
        .onReceive(timer) { now in if now >= deadline { browser.stop(); dismiss() } }
        .onChange(of: scenePhase) { _, phase in
            browser.setSceneActive(phase == .active)
            if Date() >= deadline { browser.stop(); dismiss() }
        }
    }
}
