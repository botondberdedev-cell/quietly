# SocialLite implementation research

Checked October 17, 2026. These are public-source findings, not a binary analysis or a review of private source code.

| Finding | Confidence / source |
| --- | --- |
| The product offers an in-app browsing experience for social platforms. | Explicit in its [App Store description](https://apps.apple.com/se/app/sociallite-block-reels-shorts/id6757661674?l=en-GB). |
| Social-platform cookies remain on-device to retain login sessions. | Explicit in its [privacy policy](https://sociallite.app/privacy/), updated June 6, 2026. |
| It has a separate Screen Time/app shielding feature. | Listed in App Store version notes. This blocks access to whole native apps; it does not edit their UI. |
| It filters page elements and routes using scripts/CSS in an embedded web view. | Strong architectural inference from the described behavior. Exact framework, selectors and implementation are unverified. |
| Shared videos can be viewed without entering a continuous video feed. | Advertised in its App Store description. Not independently tested. Quietly now has an independently implemented one-post viewer for DM shares and selected friends. |

Its website privacy policy lists account and usage information. Do not repeat the App Store's “Data Not Collected” label as a verified description of the current product without reconciling that difference.

## Implementation available to us

Apple's [WKWebView](https://developer.apple.com/documentation/webkit/wkwebview/) embeds websites; [WKUserScript](https://developer.apple.com/documentation/webkit/wkuserscript) injects bundled filtering logic. Quietly uses these public APIs, native navigation checks and an isolated content world. Filters inspect structural selectors and link URLs, with no credential extraction, private Instagram APIs, scraping service or server proxy.

The native shell supplies settings, a bounded session with a persisted deadline, explicit end states, navigation controls, privacy information and local data deletion. This provides useful functionality around web browsing, though it does not guarantee approval under Apple's rules.

Apps cannot alter the UI of other installed apps because of [iOS sandboxing](https://support.apple.com/guide/security/sec15bfe098e/web). Optional future shielding would use Screen Time frameworks and requires Apple's [Family Controls distribution entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement). It is separate from the filtering implemented here.

## Product distinction

An original, account-free, open-source product with intentional visits, transparent filter limits and no monetization is the direction for Quietly. MIT covers this repository, not Instagram's service or third-party intellectual property. A different name alone does not resolve Apple's copycat concerns; validate the final design and actual utility against the [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
