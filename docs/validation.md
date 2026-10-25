# Validation — October 25, 2026

## 0.2.0 sideloading beta

- 16 Swift core tests passed.
- 35 offline browser tests passed in Chromium and 35 in WebKit. New cases cover own and followed profiles, localized Following controls, profile navigation, false-positive controls, saved-only mode and inline profile video isolation.
- All 18 native app-host tests passed on the dedicated iPhone 17 / iOS 27.0 QA simulator (`test-results/profile-videos-native-paired.xcresult`). The new H.264 fixture verifies actual selected-video playback, hidden/paused recommendations, repeated background and modal callbacks, playback after resuming, and blocking a route change to another Reel. A regression in repeated native media-suspension calls was fixed. The final test checks the selected video's advancing playback clock rather than assuming a page-wide media status describes that element.
- In the separate signed-in preview, the user confirmed: **own uploads and a followed friend's Reel both play, and swiping stays on the selected Reel**. This does not establish compatibility with every account or Instagram layout.
- The final unsigned iPhone archive and `Quietly-0.2.0.ipa` built successfully with Swift warnings treated as errors. Packaging verifies the bundled scripts, version, privacy manifest and license and rejects embedded signing profiles or keys.
- The eight native UI tests below are prior baseline results; they were not rerun for 0.2.0. A complete recipient installation through SideStore/AltStore and physical-device playback still require testing. The package is an early beta, not an App Store distribution archive.

## Previous baseline — October 18, 2026

## Passed locally

- **Swift package:** 15 tests for trusted origins, disallowed schemes, Reels/Explore routes, Following destinations, persisted deadlines, settings migration, saved-friend validation, exact-post navigation and unread-count baselines/deduplication/throttling.
- **Chromium and WebKit:** 30 offline tests in each engine, using pinned Playwright 1.58.2. Includes automatic Following routing, query-only SPA changes, sponsored-card labels and mutations, caption/username false positives, root-URL login preservation, DM/Story shares, author detection, single-post isolation, carousel links, media guards and username-prefixed permalinks. Notification fixtures check English/Spanish unread badges, duplicate/hidden indicators, unknown states, unrelated page counts, minimal bridge data and observer shutdown.
- **Native iOS tests:** 16 app-host tests on an iPhone 17 simulator running iOS 27.0. They load the actual bundled scripts into real WKWebView instances and check isolated-world bridge delivery, Following/ad behavior, friend filtering, one-post isolation, unavailable layouts, playback suspension and persisted state. Notification tests cover opt-in, permission denial/revocation, generic notification requests, deduplication, background cancellation, delivery errors, cleanup and real WebKit observer isolation.
- **Native UI tests:** 8 passed across the full suite and a targeted rerun on the same regular iPhone model. Covers direct Instagram launch, restoring a visit, friend validation/add/remove/persistence, large Dynamic Type, landscape, accessibility contrast/hit regions/descriptions/text clipping, immediate exit, a real one-minute deadline across backgrounding/relaunch, confirmed website-data deletion, and notification opt-in with an actual iOS test banner.
- **Release archive:** unsigned device archive succeeded with Swift warnings treated as errors. Rebuilt with message alerts. Bundled filters, notification script, privacy manifest and license verified; Debug UI-test launch switches are absent from the Release executable.
- **Metadata:** Xcode project, Info.plist and privacy manifest passed plutil validation. Project generation is deterministic.
- **Physical installation and launch:** a development build was signed with the publisher's Personal Team, passed strict code-signature verification and installed on an iPhone 16 running iOS 27.0.1. Device inventory confirmed Quietly 0.1.0 (1). After the user trusted their developer profile, the device launch command succeeded and the running Quietly process was verified. This establishes installation and launch; signed-in Instagram features and notifications still need physical-device testing. Signing assets, device identifiers and account details remain local.

The baseline full native result bundle is `test-results/following-iphone17-complete.xcresult`. The final permalink-normalization change was additionally checked in both browser engines and all 8 app-host tests (`test-results/final-bundled-webkit.xcresult`). The final DM regression result bundle is `test-results/dm-regression-native-final.xcresult`. Test outputs/build products are ignored by Git. Automated fixture/UI suites use a dedicated QA simulator. The separate, temporary live test used the signed-in preview only with user authorization.

The notification build's full run is `test-results/message-alerts-native-2.xcresult`: all 16 app-host tests and the 7 existing UI tests passed. The new UI test initially missed the SwiftUI switch's trailing tap target; after correcting the test, notification opt-in and the actual system banner passed in `test-results/message-alerts-ui-final.xcresult`. No product change was required for that rerun. Real incoming messages on a physical phone remain untested.

## Live observations

A user signed into Instagram themselves in a separate **iPhone 17** preview. The signed-in home layout, Following selector and Stories row were inspected. Selecting the website's Following menu navigated to `/?variant=following`; Stories remained available. The updated app opened that route and displayed followed-account posts without a manually populated friends list. Login persistence across installing new Debug builds was observed.

The ordinary home feed's Spanish sponsored label and its card structure were inspected. The implementation now detects labels in the author area, before media; it does not classify an entire caption containing an advertising word as an ad. Following displayed no sponsored cards during the observed sample. This sample alone does not establish universal ad removal.

The user confirmed that Stories and DM-shared Reels play normally with real taps. They then reported an in-page DM Reel list that bypassed the native one-post viewer. This was reproduced on the signed-in preview: Instagram mounted a vertical list without changing the conversation URL, without article/dialog containers, and without a post permalink.

The updated filter isolates the selected media card in that layout, hides surrounding cards, prevents vertical paging, pauses other video elements and fails closed on selected-media replacement. A native Close Reel button reloads the original conversation. A real simulator UI test opened the user-authorized shared Reel, swiped upward and returned to the conversation successfully (`test-results/live-reel-controls.xcresult`). Screenshots before and after the swipe showed the same Reel continuing playback. The website's player still has a narrow/cropped layout in this simulator; this needs further device/layout work before release.

Temporary account-specific UI checks and layout diagnostics were removed from product/test source after validation. Private test screenshots and result bundles remain local in ignored directories. Public regression fixtures are synthetic; no credentials, private conversation content or account identifiers are published.

## Still required before a stable/App Store release

- Validate real incoming DMs on a physical phone: opt-in permission, banner/sound, tapping an alert to open the inbox, repeated messages in already-unread conversations, permission changes and foreground/background transitions. Automated notification fixtures and a test banner do not prove live Instagram delivery. This build observes the website's unread indicator during an active visit only; it has no background DM push service and cannot promise an alert for every message.
- Broaden in-page DM Reel checks beyond the one observed layout/account: long playback, repeated swipes, rotation, source changes, other languages, private posts and carousels. Improve the cropped player layout. Fixture tests and one successful live flow do not establish universal compatibility.
- Test 2FA/challenges, logout, slow/offline networks, uploads, different languages, VoiceOver traversal, iPad and a physical iPhone. The automatic accessibility audit covers native pause-screen controls, not the full Instagram website.
- Validate sponsored-card hiding across live layouts and languages. Story ads and unfamiliar advertising surfaces are not guaranteed to be removed.
- Upgrade from Personal Team development signing to paid-program distribution, validate a signed distribution archive, distribute through TestFlight, and complete App Store review requirements, final naming, service authorization, public source/support/privacy URLs and listing disclosures.

The latest local archive is `build/Quietly-notifications.xcarchive`; it is unsigned and is not an App Store upload. The simulator build is `build/DerivedData/Build/Products/Debug-iphonesimulator/Quietly.app`. See [the installation guide](app-store-release.md#install-on-your-own-iphone-first) for the prepared physical-device steps.
