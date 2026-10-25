# Contributing

Quietly is an experimental, MIT-licensed iOS app. Contributions are welcome. The app and original assets are free to use, modify and redistribute under LICENSE. Instagram remains a separate proprietary service; this license does not grant rights to its content or branding.

## Development

Follow the build instructions in README.md. Run `swift test`, `pnpm test` and `pnpm test:webkit` for changes to navigation or filters. Run `python3 scripts/test_ios.py` for changes to native behavior or bundled scripts. Use a dedicated QA simulator: UI tests delete website data there.

Keep filtering in an isolated WebKit content world. Do not collect passwords, cookies, message contents, account histories or the account's social graph. No analytics or developer-operated service is needed to run the app.

## Reporting a compatibility problem

Describe the action, expected behavior, actual behavior, app version, iOS version and Instagram language. For a shared Reel, say whether it opened inside Instagram or in the native “One post, all yours” screen. Remove names, messages and account identifiers from screenshots before posting them publicly. Never include credentials, cookies, access tokens or private media links.

For a fix, add a synthetic regression fixture that reproduces the layout or navigation behavior without copying real account content. Confirm that Stories, messaging and selected-post playback still work. Record live checks separately from automated fixture tests; passing a fixture is not proof that every Instagram layout works.

Do not describe experimental features as guaranteed blocking, and do not promise App Store approval. See docs/validation.md for the current release gaps.
