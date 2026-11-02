# Quietly privacy policy

Updated November 2, 2026. This policy describes Quietly: Friends & Focus version 0.2.0, published by Botond Berde. For privacy or support requests, contact [botond.berde.dev@gmail.com](mailto:botond.berde.dev@gmail.com).

Quietly is a free, open-source iOS app that displays Instagram's website in Apple's WebKit browser component. It has no Quietly account, developer-operated server, analytics SDK, advertising SDK or in-app purchases.

## On your device

Quietly stores its settings, optional saved usernames, onboarding status, completed visit count and visit deadline locally. Instagram's website stores login sessions, cookies and other website data through WebKit. These are not uploaded to a Quietly backend. Clear Website Data in Settings removes the app's stored website data and signs you out of that web session.

Filters inspect the displayed page's layout and links locally to hide supported distractions and sponsored feed cards. They do not collect passwords, conversation text or a copy of your social graph. Selected post identifiers and filtering status pass internally from the isolated filtering script to native app controls; they are not sent to a project server.

Optional message alerts inspect the visible inbox navigation indicator while Quietly is open. Only the numeric unread count crosses the native bridge; it is held in memory and is not saved to browsing history. The opt-in preference is stored locally. Local notifications contain generic text, without sender names or message previews. iOS controls notification permissions, presentation and retention. Turning alerts off removes Quietly's pending/delivered message and test alerts. This feature does not receive new messages when Quietly is suspended or closed, and there is no push relay or background message polling.

## Instagram and other services

Instagram receives your sign-in, messaging, media and browsing requests and handles them under its own terms and [privacy policy](https://privacycenter.instagram.com/policy/). The website can load resources from Meta and other providers. Quietly's visual ad filtering is not a network tracking blocker and does not make Instagram anonymous or remove its data collection.

External links can open in a Safari view after your choice. Those sites have their own data practices. Quietly currently denies camera and microphone capture; native calls and media uploads are not promised features.

## TestFlight beta testing

Apple operates TestFlight and automatically collects beta usage and crash information, and shares it and any submitted feedback with the developer as described in [TestFlight privacy information](https://www.apple.com/legal/privacy/data/en/test-flight/). The developer uses this information to diagnose defects and improve Quietly, without sharing it with third parties. It is accessed through Apple’s testing tools; this build adds no separate analytics storage. Apple controls retention in TestFlight (its policy describes feedback retention of one year and crash/usage retention until bugs are resolved). Contact the developer for access or deletion requests concerning data made available to the developer. This is separate from the absence of a Quietly analytics SDK. Avoid including private Instagram content in screenshots or feedback.

## Support and public contributions

The source and issue tracker are at [botondberdedev-cell/quietly](https://github.com/botondberdedev-cell/quietly). GitHub handles activity on its own service. Never post credentials, tokens, private links, messages or personal account data in public issues.

If you contact the developer, your email address and the information you choose to include are used to respond to your request. Email is handled by the email provider. Do not send passwords, verification codes or private message content. You can request deletion of support correspondence at the contact address above, subject to any required retention.

You can clear Instagram website data in Quietly Settings, remove saved usernames and reset the completed visit count locally. Deleting Quietly removes its local app data from that installation. These actions do not delete your Instagram account, content held by Meta, or copies retained in device backups. Manage those with the relevant service or device settings.

Quietly is independent of Instagram and Meta. Changes to this policy will be published here with an updated date.
