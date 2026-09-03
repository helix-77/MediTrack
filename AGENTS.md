# AGENTS.md — MediTrack

Standing context for any coding agent working in this repo. Keep this file and
`docs/medicine-manager-spec.md` (Section 2 especially) in sync — if you change a
stack decision in one, update the other in the same pass.

## Project

MediTrack — a Flutter medicine manager app for Android (Bangladesh market). The
source of truth for what to build next and how:

- [`docs/medicine-manager-spec.md`](docs/medicine-manager-spec.md) — full product
  spec, data model, feature specs, and build phasing (Section 6 = phasing,
  Section 5 = feature specs). Read it before doing any non-trivial feature work.
- [`docs/project-completion-roadmap.md`](docs/project-completion-roadmap.md) —
  dependency-ordered milestone plan with exit criteria and the list of tasks that
  require human action (credentials, accounts, product decisions).
- [`docs/task.md`](docs/task.md) — the short working list of done/pending items.

## Stack (do not substitute without a strong reason — flag it instead of silently switching)

- Flutter 3.44+ (stable), Dart 3.12+ (pubspec constraint `^3.12.2`),
  null-safety everywhere.
- State management: `provider` (`ChangeNotifier` + `MultiProvider`). Never reach for
  `setState` beyond a single dumb widget's local UI flag. No second state-management
  library "just for this one screen."
- Backend: **Firebase**, not a custom server, with **AppsPro.dev** (`api.appspro.dev/api/v1`)
  for the BD Apps SMS & carrier billing integration:
  - `firebase_auth` (anonymous + email/password + Google Sign-In)
  - `cloud_firestore` — the single source of truth for app data. Its offline
    persistence already provides offline support; do not add Drift/Isar/Hive or
    any other local database for app data. The one sanctioned exception is
    `sqflite` for the bundled read-only Bangladesh medicine catalog
    (`assets/data/medicine_catalog.db`) — do not extend it to user data.
  - `firebase_storage` — prescription images and other user uploads.
  - `firebase_app_check` — required on every Firebase AI Logic call.
  - Cloud Functions for Firebase (add under `functions/` when needed) — the only place
    allowed to hold a third-party secret key (e.g. Google Places). No `functions/`
    directory exists yet.
  - Monetization: the AppsPro / BD Apps carrier-billing subscription is
    implemented — `EntitlementService` + `EntitlementGuard` (freemium lifetime
    trial: 1 prescription scan, 3 AI messages, 3 price lookups for free users;
    premium ৳2.99/day via Robi/Airtel), `SubscriptionOfferScreen`, and the
    `lib/features/bdapps/` REST clients (spec Section 5.10).
- AI / vision: Hybrid setup:
  - **Prescription OCR** (`PrescriptionExtractionService`): Firebase AI Logic (`firebase_ai` calling `gemini-3.6-flash`).
  - **In-App AI Assistant** (`OpenRouterAiService`): `openrouter` (OpenRouter API SDK) calling the `openrouter/free` router model directly from the Flutter client with `OPENROUTER_API_KEY` configured in `.env`. Assistant calls go through `OpenRouterSanitizingHttpClient` (`lib/core/network/`), which strips invalid JSON fields before they reach the API. Image-attached messages use the verified vision-capable fallback list in `ApiConfig.openRouterVisionModels` — keep it at 3 entries or fewer; OpenRouter rejects longer fallback arrays.
  - `GeminiAiService` also exists for legacy Gemini chat/structured-action paths — check which service a feature actually uses before changing AI behavior.
- On-device OCR (medicine boxes/strips): `google_mlkit_text_recognition`. Never call a
  cloud OCR/LLM for this step.
- Camera/image capture: `image_picker`. Only add `camera` if a fully custom capture UI
  becomes a real requirement.
- Voice input (shipped): `speech_to_text` for on-device dictation into form
  fields — see `lib/utils/voice_input_helper.dart`. No cloud speech API —
  consistent with the on-device-first stance above.
- Local notifications: `flutter_local_notifications` + `timezone` + `flutter_timezone`.
  Android notification channel IDs (`dose_reminders`, `expiry_alerts`,
  `refill_alerts`) are effectively frozen once shipped — changing a channel's
  behavior requires a new channel ID, never in-place edits.
- Maps/pharmacy (nearby pharmacy screen): `geolocator` for device location +
  `url_launcher` deep links into Google Maps search. No `google_maps_flutter`,
  no Google Places API, no Cloud Function proxy today — don't add any of those
  without a flagged decision (they imply a paid API budget and Blaze plan).
- HTTP: `dio` — for AppsPro.dev REST API calls and any future Cloud Function called over
  plain HTTPS. Never used to call a paid third-party API directly with an embedded key.
- Fonts: `google_fonts` (Poppins headings, Inter body).
- Config/secrets: `flutter_dotenv` (`.env`, gitignored but bundled as a Flutter
  asset) for non-Firebase config only — variable names live in
  `lib/config/api_config.dart` and `.env.example`. Firebase config lives in
  `firebase_options.dart` / `google-services.json`, generated by
  `flutterfire configure` — never hand-edited or duplicated into `.env`.
- Localization (shipped): a custom, dependency-free system in `lib/l10n/` —
  `AppStrings` maps string keys to English/Bangla values, `LocaleNotifier`
  switches at runtime. Put every new user-facing string in `AppStrings` (both
  languages); do not add `easy_localization` or any second i18n library without
  a flagged decision.

## Coding conventions

- snake_case.dart file names, one primary class per file.
- `flutter analyze` must pass with zero warnings before a task is considered done.
- No business logic in widgets. Widgets call into `lib/services/` (Firestore/Storage/
  Auth/AI access) and `lib/logic/` (pure, unit-testable functions) only.
- Every Firestore read/write goes through a `*Service` class in `lib/services/`, never
  directly from a widget.
- Firestore data is scoped per-user under `users/{uid}/...`. Every new collection must be
  added to `firestore.rules` with `request.auth.uid == userId` scoping before it ships —
  this is a security requirement, not a follow-up task. The same applies to
  `storage.rules` for anything in Firebase Storage (both files exist at the repo
  root and are wired into `firebase.json`).
- Currency: Bangladeshi Taka, symbol "৳", formatted with `intl` NumberFormat — never
  string-concatenated manually.
- Dates: stored in Firestore as `Timestamp`, converted to/from `DateTime` at the model
  boundary (`fromSnapshot`/`toMap`), displayed via `intl`.
- Never auto-save an OCR- or AI-extracted field without the user seeing and confirming it
  first.
- Never call `FirebaseAuth.instance.signInAnonymously()` as a silent fallback inside a
  service (e.g. "if no user, sign in anonymously"). Only an explicit, user-visible action
  (the Welcome screen's "Continue as Guest") may create an anonymous account — see
  spec Section 5.12. A service with no authenticated user should
  surface a typed "not authenticated" result, not paper over it.

## Folder structure

```
lib/
  main.dart          -- Firebase/App Check/dotenv/notifications init, providers, MaterialApp
  config/            -- api_config.dart (AI model names, AppsPro base URL, env access)
  core/network/      -- dio_client.dart, openrouter_sanitizing_client.dart
  theme/             -- colors.dart, typography.dart, app_theme.dart
  l10n/              -- app_strings.dart (English/Bangla), locale_notifier.dart
  models/            -- plain Dart classes, toMap()/fromSnapshot() per Firestore doc
  services/          -- one class per Firestore/Storage/Auth/AI concern
  logic/             -- pure, unit-testable functions only (refill_calculator.dart,
                        prescription_validator.dart, entitlement_guard.dart, ...)
  screens/           -- one file per screen
  widgets/           -- shared widgets
  features/bdapps/   -- self-contained AppsPro carrier-billing integration
                        (service, offer config, data/ REST clients and models)
  utils/             -- small stateless helpers (voice_input_helper.dart, ...)
test/                -- mirrors lib/: core/, logic/, services/, screens/, models/, ...
firestore.rules      -- per-user Firestore scoping + read-only medicineReference
storage.rules        -- per-user Storage scoping
firebase.json        -- FlutterFire project wiring (references both rules files)
assets/data/         -- bundled SQLite Bangladesh medicine catalog
docs/                -- product spec, completion roadmap, task list, Firebase guide
```

## Do not

- Add a second state-management library or a second local database "just to try it"
  (sqflite is reserved for the bundled medicine catalog only).
- Call Google Places, or any paid API requiring a real secret key, directly from the
  Flutter client — proxy through a Cloud Function for Firebase.
- Auto-save any OCR- or AI-extracted field without user confirmation.
- Build a drug-interaction/contraindication checker (explicitly out of scope — see
  spec Section 5.7).
- Widen `firestore.rules`/`storage.rules` beyond per-user scoping to make a bug go away.
- Add a silent `signInAnonymously()` fallback to any service — see spec Section 5.12.
- Add a new premium gate or change the free-tier trial allowances (1 OCR scan /
  3 AI messages / 3 price lookups in `lib/logic/entitlement_guard.dart`) without
  updating spec Section 5.10 and `EntitlementService` in the same change.
- Edit an existing Android notification channel's settings in place — ship a new
  channel ID instead (channels are frozen once a build reaches devices).

## Workflow

- Run `flutter analyze` (0 errors, 0 warnings) and `flutter test` before declaring
  any task done.
- Run `git add` and `git commit` after completing any significant task or fixing a bug,
  with a clear, descriptive commit message summarizing the work. Commit only the files
  your change touched — never sweep in unrelated dirty files.
- When adding a Firestore collection, update `firestore.rules` in the same change, not a
  follow-up.
- For sequencing multi-step work, follow `docs/project-completion-roadmap.md`; keep
  `docs/task.md` checked off as items land.
