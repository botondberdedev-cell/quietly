# Quietly privacy information — draft

Updated October 18, 2026. This describes the current public prototype. Company contact details and the final distribution disclosures must be completed before an App Store submission.

Quietly is a free, open-source iOS app that displays Instagram's website in Apple's WebKit browser component. It has no Quietly account, developer-operated server, analytics SDK, advertising SDK or in-app purchases.

## On your device

Quietly stores its settings, optional saved usernames, onboarding status and visit deadline locally. Instagram's website stores login sessions, cookies and other website data through WebKit. These are not uploaded to a Quietly backend. Clear Website Data in Settings removes the app's stored website data and signs you out of that web session.

Filters inspect the displayed page's layout and links locally to hide supported distractions and sponsored feed cards. They do not collect passwords, conversation text or a copy of your social graph. Selected post identifiers and filtering status pass internally from the isolated filtering script to native app controls; they are not sent to a project server.

Optional message alerts inspect the visible inbox navigation indicator while Quietly is open. Only the numeric unread count crosses the native bridge; it is held in memory and is not saved to browsing history. The opt-in preference is stored locally. Local notifications contain generic text, without sender names or message previews. iOS controls notification permissions, presentation and retention. Turning alerts off removes Quietly's pending/delivered message and test alerts. This feature does not receive new messages when Quietly is suspended or closed, and there is no push relay or background message polling.

## Instagram and other services

Instagram receives your sign-in, messaging, media and browsing requests and handles them under its own terms and privacy policy. The website can load resources from Meta and other providers. Quietly's visual ad filtering is not a network tracking blocker and does not make Instagram anonymous or remove its data collection.

External links can open in a Safari view after your choice. Those sites have their own data practices. Quietly currently denies camera and microphone capture; native calls and media uploads are not promised features.

## Support and public contributions

The source and issue tracker are at [botondberdedev-cell/quietly](https://github.com/botondberdedev-cell/quietly). GitHub handles activity on its own service. Never post credentials, tokens, private links, messages or personal account data in public issues.

Before distribution, the publisher must add its legal identity and a private support/privacy contact, confirm the final binary's data behavior, and complete Apple's privacy disclosures for the embedded service. This draft must not be used to claim that Instagram collects no data.
