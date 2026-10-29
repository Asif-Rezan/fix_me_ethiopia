# Current implementation update

Normal builds now use real Firebase by default. Google and email/password providers are enabled. Native Google Sign-In uses the official SDK; the Android debug SHA-1/SHA-256 and iOS callback configuration are registered. Phone/SMS authentication has been removed. Visual tests opt into `--dart-define=USE_MOCKS=true`.

Per the latest requirement, the backend is being migrated to free Firebase Auth + Firestore Spark, with no Cloud Functions, Cloud Storage or Blaze billing. The online payment gateway alone remains a labeled demo. The older setup sections below are superseded during this migration.

# FIX ME ETHIOPIA

One Flutter application for customer and technician journeys. Native Flutter views cover the 45 supplied references, with the official supplied artwork, Inter font, navy `#092B4D`, orange `#FF6410`, white and pale surfaces. Reference HTML is transformed into semantic content/layout specifications, rendered as reusable Flutter widgets; no HTML webview or screenshot is used as a screen.

## Architecture

Riverpod 3 provides state and dependency injection. Feature folders contain domain models/interfaces, Firebase/mock data adapters, and MVVM presentation view models. Widgets handle rendering, form controllers and navigation; feature view models execute authentication, bookings, verification, messaging, uploads and technician commands. `core` holds cross-feature session state and domain exports. `features/screens` is the shared native layout renderer used by both roles. Live Firestore read models are separate from preview content. `go_router` guards production customer/technician routes using the server user profile and approval status.

- `features/auth`: immutable account/role/approval types, auth contracts, Firebase and demo repositories, AuthViewModel.
- `features/booking`: immutable status/quote/verification models, Firestore read adapter, BookingViewModel, RecordsViewModel, VerificationViewModel, live views.
- `features/technician`: media domain interface, Storage adapter, MediaViewModel, TechnicianViewModel.
- `features/messaging`: MessagingViewModel for chat/support commands.
- `assets/data/screens.json`: reference-derived content and semantic layout only, used for visual development.
- `functions/src`: callable backend and booking/price policy. See [shared contracts](docs/contracts/README.md).

## Run the design/demo flavor

Requires Flutter stable with Dart 3.12+. Tested with Flutter 3.44.7.

```sh
flutter pub get
flutter run
flutter run -d chrome
```

Demo is the default and displays a permanent DEMO label. The profile menu offers all 45 screen previews and an approved technician preview account. Demo does not send SMS, transfer money or prove a technician's identity. Test QR token: `DEMO-FIXME-00002`; any other token demonstrates mismatch. Reference names, reviews, dates, balances and maps are demo data. Sample maps are not live tracking.

## Firebase project and current deployment

Project: `fixme-ethiopia`. Android/iOS bundle identifier: `et.fixme.app`. Android, iOS and web preview apps have been registered using the existing authorized Firebase CLI session. Downloaded mobile SDK configuration and per-platform Dart define files are present locally and ignored by Git. No admin credential is included.

**Deployed:** Cloud Firestore default database, restrictive Firestore rules and query indexes.

**Blocked by project billing:** Cloud Functions deployment returned “project must be on the Blaze plan” when enabling Artifact Registry. Authentication initialization via the Identity Platform management API also returned `BILLING_NOT_ENABLED`; Firebase Auth providers are not confirmed enabled. Storage/App Check/provider provisioning remains to be completed in the Firebase console. No billing upgrade was performed. Production signup, privileged booking transitions and server verification cannot succeed until the callable backend and providers are available.

After enabling the needed services, deploy the backend and rules:

```sh
npx firebase-tools login
npm --prefix functions ci
npm --prefix functions test
npx firebase-tools deploy --only functions,firestore,storage --project fixme-ethiopia
flutter run --dart-define-from-file=config/android.json
flutter run --dart-define-from-file=config/ios.json
flutter run -d chrome --dart-define-from-file=config/web.json
```

Local `config/{android,ios,web}.json` contains PRODUCTION=true plus FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_SENDER_ID and FIREBASE_STORAGE_BUCKET. They contain Firebase client configuration, not service account credentials. Regenerate SDK configurations using Firebase CLI or FlutterFire CLI when needed. For a fresh checkout:

```sh
dart pub global activate flutterfire_cli
flutterfire configure --project=fixme-ethiopia --platforms=android,ios,web --android-package-name=et.fixme.app --ios-bundle-id=et.fixme.app
```

The app currently reads Dart environment options; pass the matching platform values with `--dart-define-from-file`. Enable Email/Password and optionally Google/Phone/Apple in Firebase Auth. Google requires Android signing fingerprints and iOS URL configuration. Apple needs the Apple developer capability/provider credentials. Phone requires SMS region/policy configuration, APNs or platform verification. Register Play Integrity/App Attest providers in App Check before calling enforced endpoints. Web production needs a reCAPTCHA provider configured before use; it is a preview target and not yet enabled for production App Check.

Seed `service_categories` and `service_areas` with genuine catalog data; the initial booking category ID is `refrigerator`. Do not seed fake approved technicians into production. The admin dashboard must follow the shared contract and invoke approval/assignment functions with a trusted admin custom claim.

## Permissions and platform services

Android requests INTERNET/CAMERA; iOS camera/photo library descriptions are in Info.plist. Camera permission is requested by the scanning/photo plugins when used. Add APNs entitlement/key and FCM platform configuration before push delivery. Crashlytics is initialized on native production startup, but release symbol/mapping upload and analytics consent policy still need release setup. Native release signing is not configured. A payment gateway and map/location provider are deliberately not simulated as real services.

## Emulator

```sh
npm --prefix functions ci
npm --prefix functions run build
npx firebase-tools emulators:start --project demo-fixme-ethiopia --only auth,firestore,functions,storage
```

For a Firebase-backed emulator build add `--dart-define=USE_EMULATORS=true`; use `--dart-define=EMULATOR_HOST=10.0.2.2` on an Android emulator (default localhost for iOS simulator/web). Firebase emulator app options can use nonsecret dummy values with a `demo-` project. Set `FIREBASE_PROJECT_ID=demo-fixme-ethiopia`. Backend App Check enforcement is disabled only when FUNCTIONS_EMULATOR is true. Use the Emulator UI to inspect rules and create fixtures; production security remains enforced.

## Verification and builds

```sh
dart format lib test
flutter analyze
flutter test
npm --prefix functions test
flutter build web
flutter build apk --debug
flutter build ios --simulator
flutter build appbundle --release --dart-define-from-file=config/android.json
flutter build ipa --release --dart-define-from-file=config/ios.json
```

Tests cover role homes, booking transition restrictions, prices, mock adapters, QR match/mismatch, every reference screen at 390×844, splash navigation and five visual snapshots. Snapshots are implementation regression baselines, not proof of pixel parity to references. See [design route mapping](docs/design_mapping.md).

## Current limits

The 45 reference routes are available as native visual previews. The UI recreates the reference structure/palette but is **not verified pixel-identical**; illustrative emoji have generally become Material icons, and the supplied official artwork differs from the simplified reference wordmark. Live views intentionally use real loading/empty/error states rather than reference fixture balances or identities.

Live assignment requires an admin. Production backend deployment, provider setup and device validation remain blocked/unverified as described above. Advanced saved addresses/favorites editing, technician availability/service-area editing, real-time map tracking, invoice PDF export, payout provider settlement and push notification delivery are not finished. Digital badge display awaits securely issued credentials; no functional fake QR is shown. Cash receipt is valid only after both customer report and technician confirmation. Online payment adapters, admin dashboard UI and store-ready signing are outside the delivered working preview.

The Android debug build now succeeds after clearing failed project build state and regenerable Gradle caches, and limiting Gradle to a 2 GB heap and two workers. Output: `build/app/outputs/flutter-apk/app-debug.apk`. The iOS build remains unverified after its earlier disk-space failure. Keep several GB free before native builds.


## Latest verification

`flutter analyze`: no issues. `flutter test`: 58 tests passed, including all 45 mobile reference routes and feature view-model/guard checks. `npm --prefix functions test`: TypeScript build and 3 policy tests passed. Web compilation passed. Android debug APK build passed (`flutter build apk --debug`, 52.5 seconds). The iOS package build remains unverified. Golden files under `test/goldens/` are regression baselines generated from the implementation.

Android release builds use `android/key.properties` when provided, never the starter debug signing key. Create your own keystore and define storeFile, storePassword, keyAlias and keyPassword there. iOS distribution requires your Apple signing team.
