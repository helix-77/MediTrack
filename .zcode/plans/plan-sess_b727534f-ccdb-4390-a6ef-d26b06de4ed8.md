# Documentation Refresh: README.md, AGENTS.md (/init), .env.example

## Ground truth established during exploration

The repo has drifted from its docs. The rewrite will be grounded in what actually exists today (verified against `pubspec.yaml`, `lib/`, `ApiConfig`, `EntitlementGuard`, rules files, and git):

- Dart SDK is `^3.12.2` (docs say 3.6+ — stale), Flutter 3.44, Android-only, version 1.0.0+1
- `storage.rules` **exists** and is wired into `firebase.json` (both AGENTS.md and the spec still claim it's missing)
- Localization is a **custom enum-based `AppStrings` system** in `lib/l10n/` (English + Bangla) — `easy_localization` is not used
- Freemium entitlements are **implemented**: lifetime trial of 1 prescription OCR scan, 3 AI messages, 3 price lookups for free users; premium is ৳2.99/day via AppsPro carrier billing (Robi/Airtel) — `EntitlementService` + `EntitlementGuard` + `SubscriptionOfferScreen`
- Nearby pharmacies uses `geolocator` + `url_launcher` deep links into Google Maps — **no** `google_maps_flutter`, no Places API, no `functions/` directory
- Voice input is wired (`speech_to_text` via `lib/utils/voice_input_helper.dart`)
- `.env` variables actually read by `ApiConfig`: `OPENROUTER_API_KEY`, `Base_URI`, `APPS_PRO_SECRET_KEY`, `Publishable_Key`, `App_ID`, `Share_URL` — the README currently documents wrong names
- AI: OCR = `firebase_ai` calling `gemini-3.6-flash` (`PrescriptionExtractionService`); assistant = `openrouter` package calling `openrouter/free` with a ≤3-entry vision-model fallback list, routed through a custom `OpenRouterSanitizingHttpClient`
- 33 test files across `test/{core,features,logic,models,screens,services}`; no CI; no `backend/` directory (the spec's PHP references are gone)
- Repo: `github.com/helix-77/MediTrack`; LICENSE = PolyForm Noncommercial 1.0.0, © 2026 Md. Atik Mouhtasim
- No screenshots exist (`docs/screenshots/` is empty) — README will not fabricate a proof/screenshots section

## 1. Rewrite `README.md` (beautify-github-readme skill, README mode, full polish)

Follow the skill's reading order (value → mechanism → first use → detail), zero emoji headings, no unverifiable claims ("120 tests pass", "25,000+ medicines" get dropped), tables only for enumerable facts, plain professional prose. Sections:

1. **Title + tagline + badges** — one-line value proposition ("Medication tracking, prescription scanning, and an AI health assistant, built for Bangladesh"), 5 accurate shields (Flutter 3.44, Dart 3.12, Firebase, Android, PolyForm License)
2. **Overview** — 2–3 sentences: who it's for (BD patients/caregivers), the core loop (scan → track → remind → refill → cheaper generic), bilingual EN/বাংলা
3. **Features** — grouped table: Medication Management / AI & OCR / Bangladesh-Specific / Accounts & Subscription. Concrete and verifiable per row
4. **Architecture** — ONE simplified Mermaid `graph TD` (~13 nodes max, short quoted labels, no `\n` literals, no inline styling so GitHub dark mode renders cleanly): UI screens → services → {Firebase, OpenRouter, AppsPro} + on-device engines {ML Kit, SQLite catalog, local notifications, Firestore offline cache}
5. **Prescription scanning pipeline** — ONE simplified `flowchart TD` (~8 nodes): capture → preflight → on-device ML Kit pre-scan → Gemini structured extraction → client validation → mandatory human review screen → save. Plus 3 bullets on why hybrid (offline pre-scan, OCR text as context enrichment, never auto-save). The assistant sequence diagram is **cut** per your choice; AI assistant becomes prose + bullets (context-aware answers, conversational add/update/delete with explicit confirmation card, trial limits)
6. **Tech stack** — table with accurate versions from pubspec
7. **Getting started** — prerequisites (Flutter 3.44+, Android API 24+, JDK 17), clone from `helix-77/MediTrack`, `flutter pub get`, correct `.env` variables (matches `ApiConfig`), Firebase setup pointing to `docs/firebase_setup_guide.md`, run
8. **Testing & code quality** — `flutter analyze` / `flutter test` commands and test areas, no pass-count claims
9. **Project structure** — trimmed `lib/` tree incl. `widgets/`, `l10n/`, `features/bdapps/`
10. **Security & privacy** — per-user `users/{uid}` scoping in both `firestore.rules` and `storage.rules`, read-only `medicineReference`, App Check, confirmation-before-save rule, medical disclaimer
11. **Project status** (brief, per your choice) — Implemented vs In progress/planned two-column list, linking `docs/project-completion-roadmap.md` for detail
12. **Documentation** — links to the three docs files + firebase setup guide
13. **License** — PolyForm Noncommercial 1.0.0 summary with copyright retained

## 2. Refresh `AGENTS.md` (/init — same structure, corrected facts)

- Fix spec references to `docs/medicine-manager-spec.md`; add pointers to `docs/project-completion-roadmap.md` (sequencing) and `docs/task.md` (working list)
- Dart `3.6+` → `3.12+`
- `storage.rules` bullet: exists, deployed via `firebase.json` — remove the stale open-item caveat
- Localization: reflect the live `lib/l10n/` `AppStrings` (EN/BN) system; keep strings centralized there; don't add a second i18n library without flagging
- Monetization: gated-feature list is confirmed and implemented — update the bullet and rewrite the "don't gate speculatively" Do-not into "don't add new gates or change trial allowances (1 OCR / 3 AI messages / 3 lookups in `EntitlementGuard`) without updating spec Section 5.10 in the same change"
- Maps: geolocator + url_launcher Google Maps deep links (no `google_maps_flutter`/Places/Cloud Function yet)
- `sqflite`: permitted **only** for the bundled BD medicine catalog (`assets/data/medicine_catalog.db`); app data remains Firestore-only
- Voice input: `speech_to_text` wired via `lib/utils/voice_input_helper.dart`
- Folder structure: add `widgets/`, `l10n/`, `docs/`, test layout; drop the nonexistent `backend/` entry (AppsPro is direct REST via `lib/features/bdapps/`)
- Add conventions: assistant HTTP calls go through `OpenRouterSanitizingHttpClient`; keep the OpenRouter vision fallback list ≤ 3 models
- Workflow: `flutter test` alongside `flutter analyze`; commit guidance unchanged

## 3. Fix `.env.example`

Document the real variables with placeholder values and brief comments: `OPENROUTER_API_KEY`, `Base_URI`, `APPS_PRO_SECRET_KEY`, `Publishable_Key`, `App_ID`, `Share_URL`.

## Validation & delivery

1. Run the skill's audit: `python3 .agents/skills/beautify-github-readme/scripts/audit_readme.py README.md`; fix anything it flags
2. Sanity-check both Mermaid blocks (balanced quotes/brackets, GitHub-safe syntax, readable at mobile width)
3. Verify every badge/link target and every documented env var against the code
4. Commit **only** `README.md`, `AGENTS.md`, `.env.example` with a `docs:` message — leaving the unrelated dirty files (`scan_prescription_screen.dart`, deleted `prescriptions/`) untouched
