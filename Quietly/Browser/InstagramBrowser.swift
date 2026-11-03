import SwiftUI
import WebKit
import Combine

@MainActor
final class InstagramBrowser: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var failure: String? { didSet { updateMediaSuspension() } }
    @Published var boundary: String? {
        didSet { updateMediaSuspension() }
    }
    @Published var externalURL: URL?
    @Published var selectedPost: InstagramPost? {
        didSet { updateMediaSuspension() }
    }
    @Published var postState = "loading" { didSet { updateMediaSuspension() } }
    @Published var inlinePostIsActive = false
    @Published private(set) var inboxUnreadCount: Int?
    @Published private(set) var isSigningIn = false
    let webView: WKWebView
    private let settings: FocusSettings
    private let deadline: Date
    private let singlePost: InstagramPost?
    private let filterWorld = WKContentWorld.world(name: "QuietlyFilters")
    private var observations: [NSKeyValueObservation] = []
    private var hasStarted = false
    private var hasStopped = false
    private var resourcesReady = false
    private var sceneIsActive = true
    private var externalPageIsPresented = false
    private var mediaIsSuspended = false
    private var facebookSignInIsActive = false
    private var desktopSignInIsActive = false
    private var automaticSignInAttempts = 0

    var shouldSuspendMedia: Bool {
        !sceneIsActive || externalPageIsPresented || hasStopped || Date() >= deadline
            || boundary != nil || selectedPost != nil || failure != nil
            || (singlePost != nil && postState != "ready")
    }

    func setSceneActive(_ active: Bool) {
        sceneIsActive = active
        updateMediaSuspension()
    }

    func setExternalPagePresented(_ presented: Bool) {
        externalPageIsPresented = presented
        updateMediaSuspension()
    }

    private func updateMediaSuspension() {
        // WebKit requires suspend/resume calls in pairs. Repeated status and
        // lifecycle callbacks must not stack suspensions that one resume cannot clear.
        let suspended = shouldSuspendMedia
        guard suspended != mediaIsSuspended else { return }
        mediaIsSuspended = suspended
        webView.setAllMediaPlaybackSuspended(suspended, completionHandler: nil)
    }

    init(settings: FocusSettings, deadline: Date, singlePost: InstagramPost? = nil, messageAlertsEnabled: Bool = false) {
        self.settings = settings
        self.deadline = deadline
        self.singlePost = singlePost
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        // Instagram starts Story playback when the user opens a Story. Requiring
        // another WebKit gesture can leave that player blank. Hidden content,
        // backgrounding and the native visit deadline still suspend playback.
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        #if DEBUG
        webView.isInspectable = true
        #endif

        guard let scriptURL = Bundle.main.url(forResource: singlePost == nil ? "filters" : "single-post", withExtension: "js"),
              let script = try? String(contentsOf: scriptURL, encoding: .utf8),
              let data = try? JSONEncoder().encode(settings),
              var options = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            failure = "The bundled filters could not load. Please reinstall Quietly."
            return
        }
        options["singlePostID"] = singlePost?.id
        guard let optionData = try? JSONSerialization.data(withJSONObject: options),
              let json = String(data: optionData, encoding: .utf8) else { return }
        let controller = configuration.userContentController
        controller.add(WeakScriptHandler(self), contentWorld: filterWorld, name: "quietly")
        controller.addUserScript(WKUserScript(
            source: "window.__quietlyOptions = \(json);\n" + script,
            injectionTime: .atDocumentStart, forMainFrameOnly: true, in: filterWorld
        ))
        if messageAlertsEnabled && singlePost == nil {
            guard let url = Bundle.main.url(forResource: "message-alerts", withExtension: "js"),
                  let alertsScript = try? String(contentsOf: url, encoding: .utf8) else {
                failure = "Message alerts could not load. Please reinstall Quietly."
                return
            }
            controller.addUserScript(WKUserScript(source: alertsScript, injectionTime: .atDocumentStart,
                                                 forMainFrameOnly: true, in: filterWorld))
        }
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        observations = [
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.isLoading = view.isLoading }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.url, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.checkCurrentRoute(view.url) }
            }
        ]
        resourcesReady = true
        updateMediaSuspension()
    }

    func start(_ destination: InstagramDestination, profileUsername: String? = nil) {
        guard !hasStarted, !hasStopped, Date() < deadline else { return }
        hasStarted = true
        if let singlePost, resourcesReady, Date() < deadline {
            webView.load(URLRequest(url: singlePost.url))
        } else if let profileUsername, settings.friendUsernames.contains(profileUsername) { navigateToFriend(profileUsername) }
        else { navigate(destination) }
    }

    func navigate(_ destination: InstagramDestination) {
        guard singlePost == nil, resourcesReady, !hasStopped, Date() < deadline else { return }
        boundary = nil
        failure = nil
        inlinePostIsActive = false
        webView.load(URLRequest(url: destination.url(settings: settings)))
    }

    func signIn(useDesktopSite: Bool = false) {
        guard singlePost == nil, resourcesReady, !hasStopped, Date() < deadline else { return }
        boundary = nil
        failure = nil
        externalURL = nil
        inlinePostIsActive = false
        facebookSignInIsActive = false
        desktopSignInIsActive = useDesktopSite
        automaticSignInAttempts = 0
        webView.load(URLRequest(url: NavigationPolicy.signInURL))
    }

    func closeInlinePost() {
        guard resourcesReady, !hasStopped, Date() < deadline, inlinePostIsActive,
              let current = webView.url, NavigationPolicy.isInstagram(current),
              current.path.hasPrefix("/direct/") || FriendAccount.username(on: current) != nil else { return }
        inlinePostIsActive = false
        boundary = nil
        var conversation = URLComponents(url: current, resolvingAgainstBaseURL: false)
        conversation?.query = nil
        conversation?.fragment = nil
        if let url = conversation?.url { webView.load(URLRequest(url: url)) }
    }

    func navigateToFriend(_ username: String) {
        guard singlePost == nil, settings.friendUsernames.contains(username),
              let url = FriendAccount.profileURL(username), resourcesReady, !hasStopped, Date() < deadline else { return }
        boundary = nil
        failure = nil
        webView.load(URLRequest(url: url))
    }

    func retry() {
        guard resourcesReady, !hasStopped, Date() < deadline else { return }
        failure = nil
        boundary = nil
        if let singlePost {
            postState = "loading"
            webView.load(URLRequest(url: singlePost.url))
        } else if webView.url == nil { navigate(.messages) } else { webView.reload() }
    }

    func stop() {
        guard !hasStopped else { return }
        hasStopped = true
        inboxUnreadCount = nil
        webView.stopLoading()
        webView.evaluateJavaScript("window.__quietlyStopMessageAlerts?.()", in: nil, in: filterWorld, completionHandler: nil)
        webView.evaluateJavaScript("window.__quietlyPause?.()", in: nil, in: filterWorld, completionHandler: nil)
        updateMediaSuspension()
    }

    private func checkCurrentRoute(_ url: URL?) {
        isSigningIn = url.map { NavigationPolicy.isInstagramSignIn($0) || NavigationPolicy.isFacebookSignIn($0) } ?? false
        guard let url, NavigationPolicy.isInstagram(url) else { return }
        facebookSignInIsActive = false
        if !url.path.hasPrefix("/direct/") && FriendAccount.username(on: url) == nil { inlinePostIsActive = false }
        switch NavigationPolicy.decision(for: url, settings: settings, singlePost: singlePost) {
        case .blocked(let message): boundary = message
        case .allow: boundary = nil
        default: break
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        let authenticationPage = action.request.url.map {
            NavigationPolicy.isInstagramSignIn($0) || NavigationPolicy.isFacebookSignIn($0)
                || (NavigationPolicy.isInstagram($0) && $0.path.hasPrefix("/challenge/"))
        } ?? false
        // Public WebKit “Request Desktop Website” mode is scoped to login.
        // Instagram's feed, Stories and messages keep their mobile layout.
        preferences.preferredContentMode = desktopSignInIsActive && authenticationPage ? .desktop : .mobile
        self.webView(webView, decidePolicyFor: action) { decisionHandler($0, preferences) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard !hasStopped, Date() < deadline, let url = action.request.url else {
            decisionHandler(.cancel)
            return
        }
        // Subframes stay in WebKit, cannot invoke arbitrary app schemes.
        if let frame = action.targetFrame, !frame.isMainFrame {
            decisionHandler(url.scheme == "https" || url.absoluteString == "about:blank" ? .allow : .cancel)
            return
        }
        if singlePost == nil, NavigationPolicy.allowsFacebookSignIn(url, from: webView.url,
                                                                   continuing: facebookSignInIsActive) {
            facebookSignInIsActive = true
            if action.navigationType == .linkActivated || action.targetFrame == nil {
                decisionHandler(.cancel)
                webView.load(action.request)
            } else { decisionHandler(.allow) }
            return
        }
        // Instagram's mobile interstitial can offer an instagram:// app button.
        // During sign-in, take the user to the web form instead of a dead tap.
        if singlePost == nil, url.scheme?.lowercased() == "instagram", isSigningIn {
            decisionHandler(.cancel)
            signIn()
            return
        }
        if singlePost == nil, action.navigationType == .linkActivated,
           let source = webView.url, NavigationPolicy.isFriendContext(source, settings: settings),
           let post = InstagramPost(url: url) {
            selectedPost = post
            decisionHandler(.cancel)
            return
        }
        switch NavigationPolicy.decision(for: url, settings: settings, singlePost: singlePost) {
        case .allow:
            // Reissue tapped links as in-web-view requests so WebKit does not
            // hand Universal Links to the installed Instagram app. Form posts
            // and redirects continue normally; no private WebKit API is used.
            if action.navigationType == .linkActivated || action.targetFrame == nil {
                decisionHandler(.cancel)
                webView.load(action.request)
            } else { decisionHandler(.allow) }
        case .blocked(let message):
            boundary = message
            decisionHandler(.cancel)
        case .external:
            externalURL = url
            decisionHandler(.cancel)
        case .deny:
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard !hasStopped, Date() < deadline, let url = action.request.url else { return nil }
        if singlePost == nil, NavigationPolicy.allowsFacebookSignIn(url, from: webView.url,
                                                                   continuing: facebookSignInIsActive) {
            facebookSignInIsActive = true
            webView.load(action.request)
            return nil
        }
        if singlePost == nil, let source = webView.url, NavigationPolicy.isFriendContext(source, settings: settings),
           let post = InstagramPost(url: url) {
            selectedPost = post
            return nil
        }
        switch NavigationPolicy.decision(for: url, settings: settings, singlePost: singlePost) {
        case .allow: webView.load(action.request)
        case .external: externalURL = url
        case .blocked(let message): boundary = message
        case .deny: break
        }
        return nil
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        // Camera/microphone capture and calls are not supported in this prototype.
        // Deny explicitly rather than invoking an undeclared system permission.
        decisionHandler(.deny)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handle(error)
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        inboxUnreadCount = nil
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handle(error)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        failure = "Instagram’s page closed unexpectedly. You can reload it."
    }
    private func handle(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled, !hasStopped else { return }
        failure = "Instagram couldn’t load. Check your connection, then try again."
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !hasStopped, Date() < deadline, message.frameInfo.isMainFrame,
              let origin = message.frameInfo.request.url, NavigationPolicy.isInstagram(origin),
              let body = message.body as? [String: String] else { return }
        if singlePost != nil {
            if body["type"] == "postState", let state = body["state"], ["ready", "loading", "unavailable"].contains(state) {
                postState = state
            }
            return
        }
        if body["type"] == "signInRequired", let current = webView.url,
           NavigationPolicy.isInstagram(current), ["/", "/accounts/login"].contains(current.path),
           origin.path == current.path, automaticSignInAttempts < 2 {
            automaticSignInAttempts += 1
            webView.evaluateJavaScript("window.__quietlyOpenWebSignIn?.()", in: nil, in: filterWorld, completionHandler: nil)
            return
        }
        if body["type"] == "inboxCount" {
            if let value = body["count"], let count = Int(value), (0...999).contains(count), String(count) == value {
                inboxUnreadCount = count
            } else { inboxUnreadCount = nil }
            return
        }
        if body["type"] == "inlinePost", let current = webView.url {
            let permitted = NavigationPolicy.isFriendContext(current, settings: settings)
                || NavigationPolicy.allowsObservedProfile(current, context: body["context"], username: body["friend"], settings: settings)
            if body["state"] == "closed" { inlinePostIsActive = false }
            else if permitted { inlinePostIsActive = body["state"] == "ready" }
            return
        }
        if body["type"] == "openPost", let id = body["id"], let post = InstagramPost(id: id),
           let currentURL = webView.url, NavigationPolicy.isInstagram(currentURL) {
            let fromProfileOrDM = NavigationPolicy.isFriendContext(currentURL, settings: settings)
            let fromFriendArticle = currentURL.path == "/" && body["context"] == "feed"
                && settings.friendUsernames.contains(body["friend"] ?? "")
            let fromObservedProfile = NavigationPolicy.allowsObservedProfile(currentURL, context: body["context"], username: body["friend"], settings: settings)
            if fromProfileOrDM || fromFriendArticle || fromObservedProfile {
                selectedPost = post
                if body["inline"] == "true" || body["context"] == "dm-viewer" {
                    // In-page viewers have no separate navigation entry. Reload
                    // the source under the sheet so Close returns to the grid/inbox.
                    var conversation = URLComponents(url: currentURL, resolvingAgainstBaseURL: false)
                    conversation?.query = nil
                    conversation?.fragment = nil
                    if let url = conversation?.url { webView.load(URLRequest(url: url)) }
                }
            }
            return
        }
        guard ["route", "blockedLink"].contains(body["type"] ?? "") else { return }
        let reason = body["reason"] ?? ""
        if ["Reels are paused", "Explore is paused", "One shared post at a time"].contains(reason) { boundary = reason }
        else if body["type"] == "route" && reason.isEmpty { boundary = nil }
    }
}

// The content controller retains handlers; a weak adapter avoids retaining the web view forever.
@MainActor
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: InstagramBrowser?
    init(_ target: InstagramBrowser) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

struct InstagramWebView: UIViewRepresentable {
    let browser: InstagramBrowser
    var isInteractive = true
    func makeUIView(context: Context) -> WKWebView {
        configure(browser.webView)
        return browser.webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) { configure(uiView) }
    private func configure(_ view: WKWebView) {
        // Apply these to WebKit itself so an overlay's SwiftUI controls stay reachable.
        view.isUserInteractionEnabled = isInteractive
        view.accessibilityElementsHidden = !isInteractive
    }
    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) {
        uiView.stopLoading()
        // The browser owns balanced suspension; a disappearing view only pauses.
        uiView.pauseAllMediaPlayback(completionHandler: nil)
    }
}
