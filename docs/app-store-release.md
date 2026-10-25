# App Store release guide

This repository is a prototype. Do not submit it as a finished app until the runtime and service checks below are complete.

## Release requirements

1. Local Xcode setup, simulator execution and an unsigned Release archive have been completed. Build and run on a physical device with your own signing team, then validate a signed distribution archive. See validation.md for current simulator evidence.
2. Test a consenting user's Instagram account: password login, 2FA, challenges, logout, DMs, stories, profiles, deep links, SPA navigation, infinite-feed mutations, session expiry, backgrounding, app termination, slow/offline networks, iPad and large Dynamic Type. Do not put account secrets in this repository.
3. Continue checking current signed-in mobile markup and add sanitized regression fixtures. Following and its Stories row were inspected on an iPhone 17 simulator; the default opens Instagram's Following route directly without synchronizing a separate list. Validate the one-post viewer with public/private Reels, carousels, different languages, comments, recycled video elements and route changes; confirm it cannot reveal the next Reel. Verify ad hiding across languages and document unhandled surfaces such as Story ads. Test uploads before promising them.
4. Choose and check an original final product name and icon. “Quietly” has not been checked for naming or trademark availability. Replace the bundle identifier, choose your Apple Developer team, set release version/build values and remove “Prototype” from the app only once accurate.
5. Confirm that the intended use of Instagram is permitted under its applicable terms. Apple's [guideline 5.2.2](https://developer.apple.com/app-store/review/guidelines/#intellectual-property) requires permission for third-party services and allows Apple to request authorization. SocialLite's availability does not establish permission for this project.
6. Review [guidelines 4.1 and 4.2](https://developer.apple.com/app-store/review/guidelines/#design) for originality and useful functionality beyond a repackaged website. The native features help explain utility; approval remains Apple's decision.
7. The intended MIT source repository is [botondberdedev-cell/quietly](https://github.com/botondberdedev-cell/quietly), linked from Settings. Confirm that the source upload succeeded before advertising it as available. Complete a publisher-owned privacy policy and support page with a real contact method; the project privacy draft is not yet the final App Store policy.
8. Review privacy disclosures for the final binary and embedded third-party web experience. The current privacy manifest declares local `UserDefaults` use with reason `CA92.1`; see [Apple's required-reason documentation](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons). Do not blindly copy another app's privacy label.
9. Complete the App Store age-rating questionnaire based on actual social content and messaging access. Do not copy SocialLite's age rating. Complete export compliance and applicable regional trader information.
10. Capture screenshots from the actual running app, using permitted test content. Supply working review access and clear instructions. Use TestFlight for beta testing before public release.
11. Archive in Xcode, validate the archive, upload to your App Store Connect account, and submit only when the listing accurately describes the tested product.

Apple Developer Program membership normally costs [US$99/year or local equivalent](https://developer.apple.com/help/account/membership/program-enrollment), including organization enrollment. The app itself can remain free. Some eligible organizations can request a fee waiver.

## Publisher enrollment

Apple directs individuals and sole proprietors to [Individual enrollment](https://developer.apple.com/programs/enroll/). This uses the account holder's personal legal name as the App Store seller name. A Romanian PFA is an economic undertaking without separate legal personality under Article 2(i) of [OUG 44/2008](https://legislatie.just.ro/Public/DetaliiDocumentAfis/182763). Applying Apple's criteria, Individual enrollment is the expected route for a PFA; Apple makes the final enrollment determination. The organization-only D-U-N-S requirement does not apply to Individual enrollment.

Nothing in this repository enrolls a company or accepts Apple's agreements. For organization enrollment, Apple requests the legal entity name, D‑U‑N‑S number, authority to bind the organization, a work email on its domain, and a functioning company website. The account holder must complete sign-in, identity verification, agreements and payment directly with Apple. Do not send passwords or payment information to contributors.

After enrollment is approved, configure the signing team and final bundle identifier, create the App Store Connect app record, set its price to Free, complete the privacy/age-rating/review details, upload a signed build and validate it through TestFlight. Public App Store download becomes available only after approval and release; a GitHub repository or simulator build does not provide an App Store download.

An Individual account can distribute internationally. In App Store Connect, select [All Countries or Regions](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store) to request availability across supported App Store storefronts, including future storefronts. Being based in Romania does not limit distribution to Romania. Local legal and regulatory requirements can still restrict availability in particular regions.

## Install on your own iPhone first

This can use Xcode's free Personal Team; Apple currently limits its provisioning profiles to seven days, after which you rebuild/reinstall. Paid membership is needed for TestFlight/App Store distribution. See [Apple's account guide](https://developer.apple.com/help/account/basics/about-your-developer-account).

1. Connect and unlock the physical iPhone, trust the Mac, and enable Settings > Privacy & Security > Developer Mode if prompted. The signed-in preview is a separate simulator; its login is not shared with the phone.
2. Sign into Xcode > Settings > Accounts with your Apple Account. Open `Quietly.xcodeproj`, select Quietly > Signing & Capabilities and choose your Personal Team or paid team. Use a unique bundle identifier if `org.quietly.focus` is unavailable.
3. Select the physical iPhone in Xcode and press Run. Alternatively, `python3 scripts/install_on_iphone.py --list` identifies available physical phones, then `python3 scripts/install_on_iphone.py --device DEVICE_IDENTIFIER --team TEAM_ID --bundle-id YOUR_UNIQUE_BUNDLE_ID` builds, signs, verifies, installs and launches. The helper refuses simulators and requires an explicit target. If macOS asks to let `codesign` access your Apple Development key, approve that Keychain prompt yourself. A successful install can still require first-launch trust: on the iPhone, open Settings > General > VPN & Device Management > Developer App, choose your own Apple Account, and confirm Trust. Reopen Quietly after completing any restart or verification iOS requests. Never share the Mac password or signing private key with contributors.
4. Sign into Instagram yourself on the phone; simulator login cookies are not transferred. In Quietly Settings, enable **Message alerts while open**, allow notifications, then tap **Send test notification**. Check the system banner and sound settings.
5. With Quietly open, have someone send a test DM while you view Home. Verify an unread indicator increase gives one generic alert, tapping it opens Messages, and repeated page loads do not replay old alerts. Do not expect every message in an already-unread conversation to change Instagram's indicator. Verify Stories and DM-shared Reels, upward-swipe blocking and Close Reel on the physical screen.

Quietly only detects unread indicators while its page is running in an active visit. It has no personal-Instagram messaging webhook or push service. iOS can suspend it after backgrounding; a scheduled local test notification is not proof of background DM detection. Keep Instagram's own DM notifications enabled for messages while away. There is no background polling, remote push entitlement or notification relay in this build.

## Suggested reviewer explanation — edit after validation

Quietly is an independent tool for intentional social browsing. After onboarding, it opens Instagram's Following feed in WebKit, preserving access to Stories and the inbox. Native settings control Reels, Explore, sponsored-card hiding and alternative home-feed filters. A native session boundary ends the visit at its persisted deadline. Settings also provide local website-data deletion and an explanation of data handling. The app does not alter the separately installed Instagram app.

There are no purchases, developer-operated backend or Quietly registration. Instagram authentication happens on its own website inside WebKit. Its service remains subject to its own terms and privacy policy. Include the evidence and credentials Apple requests separately in App Store Connect; never commit them to Git.

## Optional Screen Time expansion

Blocking the original Instagram app is a separate feature requiring Family Controls/Managed Settings and potentially shield extensions. Before TestFlight or App Store distribution, request the [Family Controls entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement) for each relevant target. No such capability is currently claimed or included.
