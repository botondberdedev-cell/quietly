# Quietly: Friends & Focus — TestFlight 0.2.0 (4)

Uploaded successfully to App Store Connect on November 3, 2026. Xcode confirmed that the uploaded package is processing. Assignment to the external testing group and any required beta review remain pending; build 4 is not yet confirmed available to friends. The existing [friends' invitation](https://testflight.apple.com/join/a2EyuZq8) remains the same and continues to offer the earlier beta.

## Changes

- Clearer **Continue in Quietly** entry button and an **Account** menu for returning to Instagram's web sign-in form.
- Recognized mobile app-promotion screens follow their existing web-login control, with bounded retries. Tapped Instagram links are kept in the embedded browser.
- **More login options (desktop page)** requests Instagram's desktop authentication layout while keeping the normal feed, Stories and messages in the mobile layout.
- Supported Facebook authentication pages can remain in the same browser session. Facebook sign-in is experimental: its button appeared in the QA iPhone test, but it may still be missing in other phone/account layouts. Complete authentication and return to Instagram are not verified. Instagram username/password sign-in remains the fallback.

## What to test

Check that sign-in stays in Quietly instead of opening the installed Instagram app. Try the Account menu if Instagram shows an app-promotion screen. If Facebook is offered, check sign-in, verification and the return to Instagram. Please describe errors without sharing passwords or codes.

Retest Stories, your own and followed friends' profile videos, DM-shared Reels, and repeated vertical swipes staying on the selected Reel. Check the visit timer and returning to Messages or Home.

Recognized sponsored-card hiding does not remove every ad. Message alerts still work only during active visits; background DM notifications and native calls are not provided.

## Validation and distribution

113 checks passed: 17 Swift core, 37 Chromium, 37 WebKit, 19 native app-host and 3 focused native UI tests. The Release build and archive succeeded with Swift warnings treated as errors. The App Store export passed strict signature verification for `com.botondberde.quietly`, version `0.2.0`, build `4`, with a distribution profile and the required bundled scripts/privacy manifest/license.

This build uses distribution overrides, as described in [build 3's signing notes](testflight-0.2.0-3.md#build-and-signing). The older unsigned sideload artifact is unchanged. See [validation](../validation.md), [privacy](../privacy.md) and [support](../support.md).
