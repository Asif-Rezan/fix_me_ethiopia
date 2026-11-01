# FIX ME ETHIOPIA

One Flutter Android/iOS app for customers and technicians. Riverpod manages state using feature-based MVVM with domain interfaces, Firebase data adapters and presentation view models.

## Free Firebase services only

This app uses **Firebase Spark**: Firebase Authentication (Google and email/password), Cloud Firestore, Firebase Realtime Database, Google Analytics, Crashlytics and Firebase Cloud Messaging. **No Cloud Functions, Cloud Storage, Blaze upgrade, paid map API or payment processor is used.** Spark quotas are hard limits; requests show errors when unavailable rather than switching to billable services.

Online payment gateway UI is explicitly a **demo**. It never transfers funds or marks a live booking paid. Cash after service is real: the customer reports cash paid and the assigned technician confirms receipt before a booking completes. Cash goes directly to the technician; the app does not invent a platform-held payout balance.

## Run

```sh
flutter pub get
flutter run
flutter build apk --debug
```

Normal builds use live Firebase automatically. The public Firebase client configuration is checked in; it contains app identifiers and client API keys, **not administrative credentials**. No special Dart defines are required. Native Google Sign-In uses the official Google SDK, not a simulated login. Android debug SHA-1/SHA-256 and iOS callback/client IDs are configured for `et.fixme.app`. Add your release signing certificate in Firebase before distributing signed release builds. Google and email/password providers are enabled; phone/SMS/OTP authentication is removed.

The sign-in screen includes **Explore as customer** and **Explore as technician**. These open an isolated, interactive demo session with six professionals, six service bookings, twelve categories, addresses, favorites, messages, quotations, reviews and earnings. Use the account menu to switch demo roles and try both sides of the same booking. Demo changes live for the current app session and do not write fake users, credentials or transactions to production Firebase. There is no sample-data banner above the app.

Development-only reference previews can be selected with `--dart-define=USE_MOCKS=true`. Production startup never silently falls back to mock data. Empty catalogs, accounts, requests, chats and earnings reflect actual Firestore data.

## Architecture

- `features/auth`: account/role/approval domain, Firebase identity adapter, AuthViewModel and native email/Google view. User profile listeners switch correctly on logout/account changes.
- `features/catalog`: live service catalog, search, and category selection.
- `features/booking`: immutable status/price/verification models, rule-validated Firestore transaction adapter, read models, booking draft views and live booking views.
- `features/technician`: identity/application, availability, compressed media adapter and view models.
- `features/messaging`: Realtime Database conversations, participant-restricted messages, timestamps, read receipts, typing and online presence, conversation search and unread counts. Chat uses a dedicated layout with a pinned composer and scrolling message history.
- `features/support`: searchable help articles, support request submission and ticket status.
- `features/screens/app_tab_shell.dart`: independent, persistent navigators for bottom tabs; switching tabs preserves screen state, scroll position and branch history.
- `features/notifications`: private Realtime Database feeds, unread badges, mark-one/all-read, notification-tap routing, FCM device registration and a trusted HTTP v1 push sender. Never put a server credential in the app.
- `core/telemetry`: Analytics screen/action events, sanitized nonfatal diagnostics and uncaught Flutter/platform errors. No email, address, chat or identity-document payload is included in telemetry.
- `features/screens`: shared native reference layout widgets. PNGs are never embedded as screens.

## Security and free-tier backend

Firestore transactions are enforced on the Firebase server by `firestore.rules`. Roles are selected once at account creation; only customers begin approved. A technician cannot approve themselves, become admin, issue credentials, skip verification, forge prices, edit another account or settle a customer's payment unilaterally. Every status transition writes an immutable event atomically. Quote totals are checked against the service catalog and itemized amounts. Static badge credentials are checked against active assignment and approved technician status in rules. A QR match identifies a credential; customers must compare the displayed photo with the person at the door.

To avoid a billable Storage bucket, photos are resized/compressed to at most 290 KB and saved in access-controlled Firestore documents. KYC is owner/admin only. This is intended for a modest Spark MVP within Firestore storage/operation quotas, not unlimited media hosting.

See [contract](docs/contracts/README.md) for the current schema and administration workflow. This free-tier architecture supersedes the original callable-functions requirement. There is no deployable Cloud Functions backend in this repository.

## Trusted administration

The existing Firebase CLI project-owner login is used locally; no service account is embedded in Flutter.

```sh
npx firebase-tools login
node tools/admin.cjs seed-catalog
# Review the applicant's identity documents before approving them:
node tools/admin.cjs approve TECHNICIAN_UID
node tools/admin.cjs assign BOOKING_ID TECHNICIAN_UID
node tools/admin.cjs revoke CREDENTIAL_HASH
npx firebase-tools deploy --only firestore --project fixme-ethiopia
```

The seeded service catalog has 12 categories and 5 Addis Ababa areas, with an initial visit fee of ETB 300. Change catalog fees as the project owner to match actual business pricing. No fake approved professionals are created. Customer-selected approved technicians receive assigned bookings directly; unassigned service requests await trusted assignment.

## Realtime chat and notifications

The live Realtime Database instance is `https://fixme-ethiopia-default-rtdb.firebaseio.com`. The Flutter adapter explicitly selects this URL; optional builds can override `FIREBASE_DATABASE_URL`. Security rules are in `database.rules.json` and deny access by default. Only the two assigned booking participants can read a room or create messages. Messages are immutable, sender identity and length are validated, and read receipts, typing and presence can only be written for the signed-in user. Notifications are private to their recipient. A client can create a chat notification only for a message it actually saved in that recipient's booking.

Firestore remains authoritative for booking assignment and status. Realtime Database rules cannot read Firestore, so a **trusted sync worker must keep running** to provision room membership and publish booking alerts. It uses the existing Firebase CLI project-owner session, polls every 15 seconds and needs no Cloud Functions, service-account file or billing upgrade:

```sh
node tools/realtime-admin.cjs deploy-rules
node tools/realtime-admin.cjs sync
node tools/realtime-admin.cjs watch
```

Run `watch` on a trusted host while testing or operating live bookings. New assignments get chat access after the next synchronization. Reassignment removes the old technician's access. The worker also reconciles missed chat alerts and uses FCM HTTP v1 to send recent, unread alerts to registered devices, recording successful sends per device. Device notifications require user permission and a valid token; iOS still needs APNs configuration. Push delivery on a physical device has not been verified as part of this change. The in-app notification feed updates directly from Realtime Database.

For local development, `USE_EMULATORS=true` connects Auth (9099), Firestore (8080) and Realtime Database (9000). Set `EMULATOR_HOST` for the target device. The demo accounts work without the sync worker.

[Realtime Database Flutter documentation](https://firebase.google.com/docs/database/flutter/read-and-write) · [FCM HTTP v1 documentation](https://firebase.google.com/docs/cloud-messaging/send/v1-api)

## Analytics and Crashlytics

Analytics is linked to property `561392200` in Default Account for Firebase. The app logs screen views, login/sign-up method, booking creation, badge-check outcome, and sanitized operational failures. Android applies Google Services and Crashlytics Gradle plugins; iOS bundles GoogleService-Info.plist and has a release symbol upload phase. Crashlytics supports native targets, not web. A real device run/test crash and console receipt are required before claiming delivery verification. No deliberate crash runs in normal builds.

For Analytics DebugView on Android:

```sh
adb shell setprop debug.firebase.analytics.app et.fixme.app
# Disable after testing:
adb shell setprop debug.firebase.analytics.app .none.
```

## Tests

```sh
flutter analyze
flutter test --concurrency=1 --dart-define=USE_MOCKS=true
npm --prefix backend_tests ci
npx firebase-tools emulators:exec --only firestore,database --project demo-fixme-ethiopia 'cd backend_tests && npm test'
```

If port 8080 is occupied, run the Firestore emulator on another port and set FIRESTORE_EMULATOR_HOST for the tests. Security tests include account ownership, role/approval spoofing, full assigned-booking → verified-work → approved-quote → cash-settlement flow, forged price rejection and KYC privacy. UI tests cover Google dispatch, email validation, canceled authentication, role routes and mobile reference layouts. Golden images are implementation regression snapshots, not proof of pixel identity to the supplied designs.

## Platforms and build notes

Camera/photo permissions are declared for issue images and QR scanning. APNs credentials are still required for iOS push delivery. Android release signing uses a local ignored `android/key.properties`; it never uses the debug key for release signing. iOS distribution needs your Apple signing team.

Gradle uses a 2 GB heap, two workers and in-process Kotlin compilation to bound resource use. Keep several GB free for native builds. The KGP message from current FlutterFire plugins is a compatibility warning, not a reason to enable paid Firebase services.

Maps open an external navigation app when configured with a real service address; no paid live tracking API is provisioned. Online payment processing intentionally remains a demo for later implementation. A separate admin website and store publication are not part of this mobile repository.


## Latest verification

- Flutter analyzer: no issues. All 95 app/widget tests passed, covering existing flows, populated customer and technician sections, and persistent bottom-tab navigation.
- Bottom-tab regression verifies the same home state and scroll position survive tab changes without adding back-stack entries.
- Firestore and Realtime Database emulators: 18 security/workflow tests passed, including participant privacy, message spoofing/edit rejection and notification ownership.
- Android ARM64 debug build and emulator checks cover startup, populated customer navigation, chat and notifications. iOS native distribution and physical-device push delivery remain unverified.

All UI failures pass through a safe message mapper. SDK messages, internal paths, raw exceptions and credential hashes are not displayed to customers or technicians. Quota or connection failures show a retry/support message. For an Android build use `flutter build apk --debug --target-platform android-arm64`.
