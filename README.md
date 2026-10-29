# FIX ME ETHIOPIA

One Flutter Android/iOS app for customers and technicians. Riverpod manages state using feature-based MVVM with domain interfaces, Firebase data adapters and presentation view models.

## Free Firebase services only

This app uses **Firebase Spark**: Firebase Authentication (Google and email/password), Cloud Firestore, Google Analytics, Crashlytics and FCM device registration. **No Cloud Functions, Cloud Storage, Blaze upgrade, paid map API or payment processor is used.** Spark quotas are hard limits; requests show errors when unavailable rather than switching to billable services.

Online payment gateway UI is explicitly a **demo**. It never transfers funds or marks a live booking paid. Cash after service is real: the customer reports cash paid and the assigned technician confirms receipt before a booking completes. Cash goes directly to the technician; the app does not invent a platform-held payout balance.

## Run

```sh
flutter pub get
flutter run
flutter build apk --debug
```

Normal builds use live Firebase automatically. The public Firebase client configuration is checked in; it contains app identifiers and client API keys, **not administrative credentials**. No special Dart defines are required. Native Google Sign-In uses the official Google SDK, not a simulated login. Android debug SHA-1/SHA-256 and iOS callback/client IDs are configured for `et.fixme.app`. Add your release signing certificate in Firebase before distributing signed release builds. Google and email/password providers are enabled; phone/SMS/OTP authentication is removed.

Development-only reference previews can be selected with `--dart-define=USE_MOCKS=true`. Production startup never silently falls back to mock data. Empty catalogs, accounts, requests, chats and earnings reflect actual Firestore data.

## Architecture

- `features/auth`: account/role/approval domain, Firebase identity adapter, AuthViewModel and native email/Google view. User profile listeners switch correctly on logout/account changes.
- `features/catalog`: live service catalog, search, and category selection.
- `features/booking`: immutable status/price/verification models, rule-validated Firestore transaction adapter, read models, booking draft views and live booking views.
- `features/technician`: identity/application, availability, compressed media adapter and view models.
- `features/messaging`: persistent chat and support commands.
- `features/notifications`: FCM device registration. Automatic remote push delivery needs a trusted sender; use Firebase Console campaigns or your own trusted sender, never put a server credential in the app.
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
npx firebase-tools emulators:exec --only firestore --project demo-fixme-ethiopia 'cd backend_tests && npm test'
```

If port 8080 is occupied, run the Firestore emulator on another port and set FIRESTORE_EMULATOR_HOST for the tests. Security tests include account ownership, role/approval spoofing, full assigned-booking → verified-work → approved-quote → cash-settlement flow, forged price rejection and KYC privacy. UI tests cover Google dispatch, email validation, canceled authentication, role routes and mobile reference layouts. Golden images are implementation regression snapshots, not proof of pixel identity to the supplied designs.

## Platforms and build notes

Camera/photo permissions are declared for issue images and QR scanning. APNs credentials are still required for iOS push delivery. Android release signing uses a local ignored `android/key.properties`; it never uses the debug key for release signing. iOS distribution needs your Apple signing team.

Gradle uses a 2 GB heap, two workers and in-process Kotlin compilation to bound resource use. Keep several GB free for native builds. The KGP message from current FlutterFire plugins is a compatibility warning, not a reason to enable paid Firebase services.

Maps open an external navigation app when configured with a real service address; no paid live tracking API is provisioned. Online payment processing intentionally remains a demo for later implementation. A separate admin website and store publication are not part of this mobile repository.
