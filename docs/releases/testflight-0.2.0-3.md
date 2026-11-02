# Quietly: Friends & Focus — TestFlight 0.2.0 (3)

Uploaded and processed November 2, 2026. The owner-only internal testing invitation is active. External beta review awaits review-account access; there is no friends/public invitation link yet. This build is an early beta, not a public App Store release.

## What to test

- Open Stories, your own profile videos, recognized followed-profile videos and DM-shared Reels.
- Check that the chosen video plays and repeated vertical swipes do not open the next Reel. Use Close Reel to return.
- Check Following, saved friends, visit deadlines and website-data deletion.
- Optional message alerts only detect supported unread-count increases while Quietly is open. They do not provide background DM notifications. Do not include private messages or account details in feedback.

Filters depend on Instagram's website and can break when it changes. Sponsored-card hiding does not cover every ad, including Story ads. Uploads, native calls and all account/language layouts are not promised.

## Build and signing

- Bundle ID: `com.botondberde.quietly`
- Version/build: `0.2.0` / `3`
- Xcode 27.2, iOS 17 minimum, iPhone and iPad target families.
- The existing unsigned sideload release remains 0.2.0 build 2. This upload uses build-setting overrides rather than replacing its published artifact.
- Archive with `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`, then export with the App Store Connect method, automatic distribution signing and your paid team. Do not copy signing keys or provisioning profiles into source control.
- Use `manageAppVersionAndBuildNumber=false` and `testFlightInternalTestingOnly=false` for export. Verify the signed export before upload.

All 112 automated checks passed; see [validation](../validation.md) for evidence and remaining manual checks. See [privacy](../privacy.md) and [support](../support.md).
