import XCTest
import WebKit
import AVFoundation
@testable import Quietly

/// These run inside the actual iOS app host with its bundled scripts and WKContentWorld.
/// HTML is synthetic and uses loadHTMLString; no Instagram account or messages are used.
@MainActor
final class WebKitIntegrationTests: XCTestCase {
    private let world = WKContentWorld.world(name: "QuietlyFilters")
    private var fixtureWindow: UIWindow?

    override func tearDownWithError() throws {
        fixtureWindow?.isHidden = true
        fixtureWindow = nil
    }

    private func browser(post: InstagramPost? = nil, feedMode: FeedMode = .hidden) -> InstagramBrowser {
        var settings = FocusSettings()
        settings.feedMode = feedMode
        settings.friendUsernames = ["alex"]
        return InstagramBrowser(settings: settings, deadline: Date().addingTimeInterval(120), singlePost: post)
    }

    private func load(_ html: String, path: String, into browser: InstagramBrowser) async throws {
        if fixtureWindow == nil {
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
            let window = UIWindow(windowScene: scene)
            window.frame = scene.coordinateSpace.bounds
            window.rootViewController = UIViewController()
            fixtureWindow = window
        }
        fixtureWindow?.rootViewController?.view = browser.webView
        fixtureWindow?.makeKeyAndVisible()
        browser.webView.loadHTMLString("<!doctype html><meta name='viewport' content='width=device-width'><body>\(html)</body>", baseURL: URL(string: "https://www.instagram.com\(path)"))
        try await eventually {
            (try? await browser.webView.evaluateJavaScript("document.readyState === 'complete' && location.pathname + location.search === '\(path)'")) as? Bool == true
        }
        XCTAssertNil(browser.failure)
    }

    private func eventually(timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line, _ check: () async throws -> Bool) async throws {
        let until = Date().addingTimeInterval(timeout)
        while Date() < until {
            if try await check() { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("WebKit condition did not become true within \(timeout) seconds", file: file, line: line)
    }

    func testUnreadIndicatorUsesTheIsolatedBridgeAndStopsWithTheVisit() async throws {
        let browser = InstagramBrowser(settings: FocusSettings(), deadline: Date().addingTimeInterval(120), messageAlertsEnabled: true)
        defer { browser.stop() }
        try await load("<nav><a href='/direct/inbox/' aria-label='Messages'><span id='unread'>2</span></a></nav>", path: "/direct/inbox/", into: browser)
        try await eventually { browser.inboxUnreadCount == 2 }
        let exposed = try await browser.webView.evaluateJavaScript("Boolean(window.webkit?.messageHandlers?.quietly)") as? Bool
        XCTAssertEqual(exposed, false)
        _ = try await browser.webView.evaluateJavaScript("document.querySelector('#unread').textContent = '3'")
        try await eventually { browser.inboxUnreadCount == 3 }
        browser.stop()
        _ = try await browser.webView.evaluateJavaScript("document.querySelector('#unread').textContent = '4'")
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertNil(browser.inboxUnreadCount)
    }

    func testUnreadObserverIsAbsentUnlessOptedIn() async throws {
        let browser = browser()
        defer { browser.stop() }
        try await load("<nav><a href='/direct/inbox/' aria-label='Messages'>9</a></nav>", path: "/direct/inbox/", into: browser)
        let exists: String? = try await withCheckedThrowingContinuation { continuation in
            browser.webView.evaluateJavaScript("typeof window.__quietlyStopMessageAlerts", in: nil, in: world) { result in
                continuation.resume(with: result.map { $0 as? String })
            }
        }
        XCTAssertEqual(exists, "undefined")
        XCTAssertNil(browser.inboxUnreadCount)
    }

    func testBundledFilterRunsInIsolatedWorldAndPreservesFriendAuthor() async throws {
        let browser = browser()
        defer { browser.stop() }
        try await load("""
        <main><article id="friend"><header><a href="/alex/">Alex</a></header><a href="/p/Friend1/">Friend post</a></article>
        <article id="stranger"><header><a href="/stranger/">Stranger</a></header><a href="/p/Other1/">Suggested post</a></article></main>
        """, path: "/", into: browser)
        try await eventually {
            (try? await browser.webView.evaluateJavaScript("getComputedStyle(document.querySelector('#stranger')).display === 'none'")) as? Bool == true
        }
        let friend = try await browser.webView.evaluateJavaScript("getComputedStyle(document.querySelector('#friend')).display") as? String
        XCTAssertNotEqual(friend, "none")
        let pageCanAccessBridge = try await browser.webView.evaluateJavaScript("Boolean(window.webkit?.messageHandlers?.quietly)") as? Bool
        XCTAssertEqual(pageCanAccessBridge, false)
        let scriptInstalled = try await browser.webView.evaluateJavaScript("Boolean(window.__quietlyOptions)", in: nil, contentWorld: world) as? Bool
        XCTAssertEqual(scriptInstalled, true)
    }

    func testIsolatedBridgeOpensDMShareAndRejectsUnapprovedContext() async throws {
        let browser = browser()
        defer { browser.stop() }
        try await load("<main>Messages fixture</main>", path: "/direct/inbox/", into: browser)
        _ = try await browser.webView.evaluateJavaScript("window.webkit.messageHandlers.quietly.postMessage({type:'openPost', id:'Shared1', context:'dm'}); true", in: nil, contentWorld: world)
        try await eventually { browser.selectedPost?.id == "Shared1" }
        browser.selectedPost = nil
        try await load("<main>Unknown profile</main>", path: "/stranger/", into: browser)
        _ = try await browser.webView.evaluateJavaScript("window.webkit.messageHandlers.quietly.postMessage({type:'openPost', id:'Other1', context:'profile', friend:'stranger'}); true", in: nil, contentWorld: world)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNil(browser.selectedPost)
    }

    func testFollowingAllowsPostsAndFiltersSponsoredCardsInRealWebKit() async throws {
        let browser = browser(feedMode: .following)
        defer { browser.stop() }
        try await load("""
        <main><article id="friend"><header><a href="/friend/">Friend</a></header><a href="/reel/Friend1/">Reel</a></article>
        <article id="ad"><header><a href="/advertiser/">Advertiser</a><span>Publicidad</span></header><video></video></article></main>
        """, path: "/?variant=following", into: browser)
        try await eventually {
            (try? await browser.webView.evaluateJavaScript("getComputedStyle(document.querySelector('#ad')).display === 'none' && getComputedStyle(document.querySelector('#friend')).display !== 'none'")) as? Bool == true
        }
        _ = try await browser.webView.evaluateJavaScript("window.webkit.messageHandlers.quietly.postMessage({type:'openPost',id:'Friend1',context:'following'});true", in: nil, contentWorld: world)
        try await eventually { browser.selectedPost?.id == "Friend1" }
    }

    func testSinglePostReportsReadyAndHidesRecommendationsThenFailsClosed() async throws {
        let browser = browser(post: try XCTUnwrap(InstagramPost(id: "Shared1")))
        defer { browser.stop() }
        try await load("""
        <main><article id="chosen"><a href="/p/Shared1/">Selected Reel</a></article>
        <article id="next"><a href="/p/Other1/">Next Reel</a></article></main>
        """, path: "/p/Shared1/", into: browser)
        try await eventually { browser.postState == "ready" }
        let hidden = try await browser.webView.evaluateJavaScript("getComputedStyle(document.querySelector('#next')).display === 'none'") as? Bool
        XCTAssertEqual(hidden, true)
        _ = try await browser.webView.evaluateJavaScript("document.querySelector('#chosen a').href='/p/Recycled1/'")
        try await eventually { browser.postState != "ready" }
        let recycledVisible = try await browser.webView.evaluateJavaScript("getComputedStyle(document.querySelector('#chosen')).visibility") as? String
        XCTAssertEqual(recycledVisible, "hidden")
    }

    func testDMInPageReelListHandsOffWithoutAURLChange() async throws {
        let browser = browser()
        defer { browser.stop() }
        try await load("<main id='fixture'>Conversation fixture</main>", path: "/direct/t/123/", into: browser)
        _ = try await browser.webView.evaluateJavaScript("""
        document.querySelector('#fixture').innerHTML = `<div style="height:400px;overflow-y:scroll;scroll-snap-type:y mandatory">
        <div style="height:400px"><video width="320" height="350"></video><a href="/author/reel/Shared1/">Shared</a></div>
        <div style="height:400px"><video width="320" height="350"></video><a href="/reel/Next1/">Next</a></div></div>`;
        true
        """)
        try await eventually { browser.selectedPost?.id == "Shared1" }
        XCTAssertTrue(browser.shouldSuspendMedia)
        XCTAssertEqual(browser.webView.url?.path.split(separator: "/").map(String.init), ["direct", "t", "123"])
    }

    func testInlineDMVideoWithoutPermalinkIsIsolatedAndRecyclingSuspendsPlayback() async throws {
        let browser = browser()
        defer { browser.stop() }
        try await load("""
        <div style="height:400px;overflow-y:scroll;scroll-snap-type:y mandatory"><div>
        <section id="current" style="height:400px"><video id="media" width="320" height="350" src="/fixture-a.mp4"></video><a href="/creator/reels/">Creator</a><a href="/reels/audio/123/">Audio</a></section>
        <section id="next" style="height:400px"><video width="320" height="350"></video><a href="/other/reels/">Other</a><a href="/reels/audio/456/">Audio</a></section>
        </div></div>
        """, path: "/direct/t/123/", into: browser)
        try await eventually { browser.inlinePostIsActive }
        let hidden = try await browser.webView.evaluateJavaScript("getComputedStyle(document.querySelector('#next')).display === 'none'") as? Bool
        XCTAssertEqual(hidden, true)
        XCTAssertFalse(browser.shouldSuspendMedia)
        _ = try await browser.webView.evaluateJavaScript("document.querySelector('#media').src = '/fixture-b.mp4'")
        try await eventually { browser.boundary == "One shared post at a time" }
        XCTAssertTrue(browser.shouldSuspendMedia)
    }

    func testBackgroundAndModalSuspensionSurviveRouteUpdates() throws {
        let browser = browser()
        defer { browser.stop() }
        browser.setSceneActive(false)
        browser.boundary = "Reels are paused"
        browser.boundary = nil
        browser.selectedPost = InstagramPost(id: "Shared1")
        browser.selectedPost = nil
        XCTAssertTrue(browser.shouldSuspendMedia, "A page callback must not resume background audio")
        browser.setSceneActive(true)
        XCTAssertFalse(browser.shouldSuspendMedia)
        browser.setExternalPagePresented(true)
        browser.boundary = nil
        XCTAssertTrue(browser.shouldSuspendMedia)
        browser.setExternalPagePresented(false)
        XCTAssertFalse(browser.shouldSuspendMedia)
        browser.stop()
        browser.setSceneActive(true)
        XCTAssertTrue(browser.shouldSuspendMedia)
    }

    func testUnknownSinglePostNeverBecomesInteractive() async throws {
        let browser = browser(post: try XCTUnwrap(InstagramPost(id: "Shared1")))
        defer { browser.stop() }
        try await load("<main><video></video><p id='unknown'>Unrecognized layout</p></main>", path: "/p/Shared1/", into: browser)
        try await eventually { browser.postState == "unavailable" }
        XCTAssertTrue(browser.shouldSuspendMedia)
        let visibility = try await browser.webView.evaluateJavaScript("getComputedStyle(document.querySelector('#unknown')).visibility") as? String
        XCTAssertEqual(visibility, "hidden")
    }

    func testOwnAndFollowedProfileReelsReachTheNativeSinglePostViewer() async throws {
        for (name, control, context) in [
            ("myself", "<a href='/accounts/edit/'>Edit profile</a>", "own-profile"),
            ("followed", "<button>Following</button>", "followed-profile")
        ] {
            let browser = browser(feedMode: .following)
            defer { browser.stop() }
            try await load("<main><header>\(control)</header><a id='upload' href='/reel/Video1/'>Video</a><a id='endless' href='/reels/'>Reels</a></main>", path: "/\(name)/reels/", into: browser)
            try await eventually {
                (try? await browser.webView.evaluateJavaScript("getComputedStyle(document.querySelector('#upload')).display !== 'none' && getComputedStyle(document.querySelector('#endless')).display === 'none'")) as? Bool == true
            }
            _ = try await browser.webView.evaluateJavaScript("window.webkit.messageHandlers.quietly.postMessage({type:'openPost',id:'Video1',context:'\(context)',friend:'\(name)'});true", in: nil, contentWorld: world)
            try await eventually { browser.selectedPost?.id == "Video1" }
            XCTAssertTrue(browser.shouldSuspendMedia)
        }
    }

    func testSelectedVideoActuallyPlaysWhileRecommendationsStayPaused() async throws {
        // Generate a small H.264 fixture: checks actual decoding and playback,
        // rather than replacing HTMLMediaElement.pause with a test stub.
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: file) }
        let writer = try AVAssetWriter(outputURL: file, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 64
        ])
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32ARGB, nil, &buffer), kCVReturnSuccess)
        let pixel = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(pixel, [])
        memset(CVPixelBufferGetBaseAddress(pixel), 120, CVPixelBufferGetDataSize(pixel))
        CVPixelBufferUnlockBaseAddress(pixel, [])
        for frame in 0..<90 {
            try await eventually { input.isReadyForMoreMediaData }
            XCTAssertTrue(adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
        let video = try Data(contentsOf: file).base64EncodedString()
        let browser = browser(post: try XCTUnwrap(InstagramPost(id: "OwnVideo")))
        defer { browser.stop() }
        try await load("""
        <main><article><a href='/p/OwnVideo/'>Selected</a><video id='selected' muted playsinline loop src='data:video/mp4;base64,\(video)'></video></article>
        <article id='recommended'><a href='/reel/Other/'>Next</a><video id='other' muted playsinline src='data:video/mp4;base64,\(video)'></video></article></main>
        """, path: "/p/OwnVideo/", into: browser)
        try await eventually { browser.postState == "ready" }
        try await eventually { await browser.webView.requestMediaPlaybackState() != .suspended }
        _ = try await browser.webView.callAsyncJavaScript("await document.querySelector('#selected').play(); document.querySelector('#other').play().catch(() => {}); return true;", arguments: [:], in: nil, contentWorld: .page)
        try await eventually {
            (try? await browser.webView.evaluateJavaScript("document.querySelector('#selected').currentTime > 0.25 && !document.querySelector('#selected').paused && document.querySelector('#other').paused && getComputedStyle(document.querySelector('#recommended')).display === 'none'")) as? Bool == true
        }
        browser.setSceneActive(false)
        browser.setSceneActive(false)
        browser.boundary = "Reels are paused"
        browser.boundary = nil
        try await eventually { await browser.webView.requestMediaPlaybackState() == .suspended }
        browser.setSceneActive(true)
        browser.postState = "ready"
        browser.postState = "ready"
        try await eventually { await browser.webView.requestMediaPlaybackState() != .suspended }
        _ = try await browser.webView.callAsyncJavaScript("const video = document.querySelector('#selected'); video.currentTime = 0; await video.play(); return true;", arguments: [:], in: nil, contentWorld: .page)
        // Check the selected element's clock: the page also contains a paused,
        // hidden recommendation, so a page-wide state is not a playback proof.
        try await eventually {
            (try? await browser.webView.evaluateJavaScript("document.querySelector('#selected').currentTime > 0.25 && !document.querySelector('#selected').paused && document.querySelector('#other').paused")) as? Bool == true
        }
        _ = try await browser.webView.evaluateJavaScript("history.pushState({}, '', '/reel/Other/'); true")
        try await eventually { browser.postState != "ready" && browser.shouldSuspendMedia }
    }
}
