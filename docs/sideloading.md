# Install Quietly with SideStore or AltStore Classic

Quietly is free and MIT-licensed. These are early testing builds for iPhone and
iPad running iOS/iPadOS 17 or later. They are not an App Store or AltStore PAL release.

## Install

1. Set up [SideStore](https://docs.sidestore.io/docs/installation/prerequisites)
   or [AltStore Classic](https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos)
   using its official instructions. Initial setup needs a computer, your own Apple
   Account and Developer Mode on the phone. Do not share your Apple password with
   Quietly's developer or a friend.
2. Add this source URL in the installer's Sources screen:

   `https://raw.githubusercontent.com/botondberdedev-cell/quietly/main/altstore-source.json`

3. Choose Quietly and install. Alternatively, download the IPA from
   [GitHub Releases](https://github.com/botondberdedev-cell/quietly/releases)
   and import it using the installer's **My Apps → +** control.
4. Open Quietly and sign in directly to Instagram in its web view. Login sessions
   from Safari, Instagram or another person's installation are not included.
5. Keep **People I follow**, **Block Reels** and **Block Explore** enabled. Your
   own profile and recognized followed profiles can open individual videos. Add a
   username to Quietly's saved Friends list if Instagram's language/layout is not
   recognized. That also provides a profile shortcut.

With a free Apple Account, apps expire after seven days unless refreshed. Keep
the installer's refresh setup working. Apple normally permits three active apps
per device, including the installer. SideStore can refresh on-device after setup;
AltStore Classic normally needs its AltServer computer available. See the
[SideStore FAQ](https://docs.sidestore.io/docs/faq) and
[AltStore refresh guide](https://faq.altstore.io/altstore-classic/altserver).

## What to check on your account

- Your profile's Posts and Reels grids: open one of your own uploads.
- A followed friend's profile: open a photo, video and Reel. Try the saved Friends
  shortcut if the relationship control is not recognized.
- A Story and a Reel shared in a DM: both should play.
- Swipe up repeatedly in a selected Reel: a second Reel must not become visible
  or audible. Close should return to the original profile or conversation.

The infinite Reels feed and Explore stay blocked. Videos still depend on Instagram
granting your account access. Unrecognized players remain hidden instead of
exposing recommendations. Message alerts work only while Quietly is open; this
build has no background Instagram DM push service.

## Updates and support

Refresh and update using the same Apple Account and installer. Do not delete an
existing installation if you want to keep its settings and login. Moving from an
Xcode installation to another signing account can create a separate installation.

Report reproducible problems in [GitHub Issues](https://github.com/botondberdedev-cell/quietly/issues).
Include the Quietly version, iOS version, Instagram language and the type of page.
Do not post private messages, cookies, passwords, tokens or account recovery codes.

The IPA contains the app only. Each installer signs it with the recipient's own
account; it does not contain the publisher's provisioning profile or certificates.
Checksums are provided with each release. To build it yourself on a Mac:

```sh
python3 scripts/package_sideload.py
```
