# Quietly

A free, MIT-licensed iPhone and iPad app for intentional Instagram visits. No subscription, app account, analytics SDK, or backend. **Quietly is a working name; this is a prototype, not a release-ready App Store build.**

**Install the early beta:** [SideStore / AltStore Classic instructions](docs/sideloading.md).
The installer signs the app with your own Apple Account. Free accounts need a
refresh within seven days. See [release notes](docs/releases/0.2.0.md) and
[GitHub Releases](https://github.com/botondberdedev-cell/quietly/releases).

## What it does

- Opens Instagram's mobile website inside a native SwiftUI app using `WKWebView`.
- Goes straight to Instagram's **Following** feed, including Stories, after onboarding and on later launches. This uses Instagram's own followed-account feed without importing a separate friends list.
- Hides recognized sponsored feed cards by default. The rule checks advertising labels in the card's author area, rather than captions or comments. Settings can turn it off.
- Blocks the endless Reels and Explore feeds, including in-page navigation.
- Opens posts and Reels shared in DMs in a separate one-post viewer, preserving the conversation underneath.
- Keeps an optional local saved-friends list with profile shortcuts. It is also used by the optional saved-friends-only feed filter.
- Preserves individual videos on your own profile and recognized followed profiles. Own profiles use the visible Edit profile control; followed profiles use supported Following controls in People I follow mode. Saved friends provide a fallback for other layouts/languages.
- Offers a finite catch-up of 3–30 other recognized posts per page visit as an alternative to Following.
- Ends each visit after 1–30 minutes. The deadline persists through app restarts and includes time spent away.
- Keeps preferences and visit counts locally. Lets you clear WebKit cookies and site data.
- Offers optional **message alerts while open** when a recognized unread inbox indicator increases. Notifications contain no sender names or message previews. Settings includes permission handling and a test notification.
- Includes an original icon, onboarding, accessibility labels, privacy explanation, MIT license and privacy manifest.
- DM attachment buttons that open an in-page Reel list are also filtered. Recognized lists keep only the selected Reel, block vertical paging and offer a native Close Reel button. Replacing its media closes access rather than unlocking the next Reel.

These filters apply **inside Quietly only**. They cannot remove features inside the installed Instagram app. Messages and stories depend on Instagram's mobile website. No Instagram account is created or operated by this project.

## How SocialLite appears to work

SocialLite's [App Store listing](https://apps.apple.com/se/app/sociallite-block-reels-shorts/id6757661674?l=en-GB) describes focused browsing and separate Screen Time integration. Its [privacy policy](https://sociallite.app/privacy/) says it stores social-platform session cookies locally. This supports the embedded-browser approach. JavaScript/CSS filtering inside that browser is an **inference**, not a verified account of SocialLite's private source. See [the research notes](docs/research.md).

Quietly is an independent implementation with its own design and code. It does not use SocialLite's source, icons, screenshots or branding, and is not affiliated with SocialLite, Instagram or Meta.

## Run on an iPhone

1. Install Xcode with its iOS platform and first-launch components.
2. Open `Quietly.xcodeproj`, select the **Quietly** scheme, then a simulator or your connected iPhone.
3. For a physical device, choose your developer team in Signing & Capabilities and set your own bundle identifier. The checked-in `org.quietly.focus` identifier is a development placeholder, not a registered identifier.
4. Build and run. Complete onboarding to open Instagram's Following/Stories view. Sign in only on Instagram's website in the web view. The native messages button opens the inbox. Existing prototype installations retain their previous feed setting; choose **People I follow** in Settings.

Requires iOS/iPadOS 17+. There are no third-party production dependencies. The checked-in project does not require XcodeGen or CocoaPods. Regenerate the project after adding/removing Swift or bundled resource files:

```sh
python3 scripts/generate_project.py
```

The generator also copies the root MIT license into the app bundle. The editable icon source is `scripts/icon.svg`; its 1024px PNG is checked in.

## Checks

```sh
swift test
pnpm install --frozen-lockfile
pnpm exec playwright install chromium webkit
pnpm test
pnpm test:webkit
xcodebuild -project Quietly.xcodeproj -scheme Quietly \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
python3 scripts/test_ios.py
```

Browser tests intercept every request and use synthetic fixtures; they never contact Instagram or use an account. They cover dynamic posts, recycled DOM nodes, SPA routes, settings, inbox preservation and hostile lookalike domains. Swift package tests cover navigation policy and persisted session deadlines.

The simulator runner uses an installed iOS runtime and creates a dedicated `Quietly QA iPhone` if needed. Native app-host tests load synthetic HTML into the real `WKWebView`, checking bundled-script injection, isolated-world bridge delivery, friend filtering, one-post isolation and playback suspension. UI tests exercise direct Instagram launch, onboarding, friend validation/persistence/removal, data deletion, large text, landscape, accessibility contrast/tap targets, immediate exit and a real 60-second visit across backgrounding and relaunch. They may load Instagram's public login page but do not sign in or send messages. UI tests use separate preferences in Debug; those launch switches are excluded from Release. Website-data deletion tests clear the app's WebKit data on the selected test simulator, so use a separate simulator for signed-in manual testing. Debug builds expose their web views to Safari's Web Inspector for local compatibility work; Release builds do not enable inspection.

Results and screenshots are saved in `test-results/*.xcresult`. Open the bundle in Xcode, or export its screenshots with `xcrun xcresulttool export attachments --path <bundle> --output-path <folder>`. To target an existing simulator, pass `--device <UDID>`. GitHub Actions runs the browser, core and native simulator checks and retains the native result bundle.

See [validation status](docs/validation.md) for checks actually executed and environment limitations. Passing fixture tests does **not** demonstrate compatibility with Instagram's current signed-in pages.

## Current limits

- **Live compatibility is only partially verified.** Signed-in Following and its Stories row were inspected on an iPhone 17 simulator. The default uses the website's `/?variant=following` route, verified through its visible Following menu. Instagram can change this route, its feed behavior, or its markup.
- Home-feed filtering recognizes `main article` / `[role=main] article` containers. Saved-friend exceptions use a direct `header` or the observed mobile author/avatar section before the media. Mentions in captions/comments do not qualify. The optional saved-friends list stays local and is not a copy of the account's Following list.
- Sponsored-card detection currently recognizes English, Spanish, German, French, Italian, Portuguese and Hungarian labels in supported author sections. Spanish markup was inspected live; the other languages have not been validated live. Offline fixtures cover English and Spanish labels. This is visual filtering, not a network-level tracking blocker. Story ads, unfamiliar languages and changed layouts are not guaranteed to be removed.
- The one-post viewer uses the authenticated mobile website, not public-only embeds. It shows only an identifiable article with the selected post's exact permalink, hides surrounding content, pauses other videos and blocks navigation to other posts. Same-post carousel links remain allowed. Unrecognized layouts stay hidden with a return/retry option. The user confirmed playback and blocked swiping for own/followed profile videos in the signed-in preview; broader public/private-account testing remains necessary.
- The finite post budget survives in-page navigation and DOM recycling, but a full page reload or a new page visit resets it. It is a voluntary boundary, not a tamper-proof restriction.
- **No background DM alerts:** unread detection runs only while Quietly is open in an active visit. It recognizes supported English/Spanish inbox navigation badges, not every message event; Instagram can change the layout. Initial unread messages establish a silent baseline, and bursts are throttled. Local alerts are not a remote push service. Keep Instagram's own DM notifications enabled for messages while away.
- No system-wide app shielding, Screen Time entitlement, remote push notifications, native calls, media downloads, or other social platforms are implemented.
- Instagram's web login, 2FA, challenges, uploads, accessibility and non-English layouts require device testing. Facebook cross-site login is not validated; a Safari login does not automatically share cookies with the embedded browser.
- Following relies on Instagram to provide followed-account content. The app redirects ordinary home timelines to Following in that mode; it does not retrieve the account's social graph through private APIs. No claim is made to remove every possible suggested or sponsored surface.
- Public source: [botondberdedev-cell/quietly](https://github.com/botondberdedev-cell/quietly). There is no App Store listing yet. The public code is an experimental prototype, not a signed distribution build.

## Publishing

Use [the sideloading guide](docs/sideloading.md) for the free-account installation route, or [the App Store release guide](docs/app-store-release.md) for conventional distribution. App Store distribution requires Apple's developer membership, normally [US$99/year or local currency](https://developer.apple.com/help/account/membership/program-enrollment). Approval is not guaranteed. Apple reviews originality, useful native functionality and permission to use third-party services.

For a personal installation before TestFlight, follow **Install on your own iPhone first** in that guide. `python3 scripts/install_on_iphone.py --list` checks for physical iPhones; the helper can build, sign and install once you provide the device and Apple signing team. A free Personal Team can be used with Apple's seven-day provisioning limit.

## Contributing

Keep browsing filters in `Quietly/Resources/filters.js`, isolated post-view filters in `Quietly/Resources/single-post.js`, and optional unread-indicator observation in `Quietly/Resources/message-alerts.js`. Add a sanitized fixture for each regression and run both browser engines. Never commit cookies, passwords, real messages or account identifiers. Native bridge messages are limited to filter status, explicitly selected post identifiers/context and an opt-in unread count; they are not logged or transmitted to a project backend. All product code and original assets are under the [MIT license](LICENSE).
