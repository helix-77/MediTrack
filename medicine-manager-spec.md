# MediTrack — Medicine Manager App: Build Spec & AI Prompt Pack

*(Working title "MediTrack" — rename freely, it's a find-and-replace.)*

## 0. How to use this document

This is written so it can be handed to a **weaker/cheaper coding AI** (e.g. a local
Qwen2.5-Coder-7B running through OpenCode) one section at a time. Every architectural
decision below is already made — the goal is to leave the implementing AI with judgment
calls only about code-level details, not product or stack decisions.

Practical notes for feeding this to OpenCode specifically:
- Section 2 ("Master Project Context") is written to be dropped into your repo's
  `AGENTS.md` — OpenCode reads this automatically as standing context for every task.
- Section 8 ("Task Prompts") is deliberately split into ~13 small, single-responsibility
  prompts instead of one giant one. Small local models drift and hallucinate on big
  multi-file asks; they do much better when given one screen or one module at a time
  with the previous step already merged. Feed them in order, review/compile after each,
  then move to the next.
- Anywhere you see a 🤖 marker, that block is meant to be copy-pasted as-is.

---

## 1. Product Overview

**What it is:** An Android-first medicine management app for personal/family use in
Bangladesh. Core loop: snap a photo of a medicine strip/box or a doctor's prescription →
app extracts the details → app tracks stock, schedules doses, reminds you to take/refill,
and helps you find a cheaper generic or a nearby pharmacy.

**MVP feature set** (build in this order, see Section 7 for phasing):
1. Add medicine by camera + on-device OCR (name, expiry, batch, quantity)
2. Dose scheduling + local reminders (take-now / refill / expiry alerts)
3. Home dashboard (today's doses, upcoming refills, expiring soon)
4. Manual add/edit/delete medicine
5. Scan prescription (photo → structured medicine list via cloud vision LLM)
6. Medicine price & generic-alternative lookup
7. Nearby pharmacy map
8. Settings (Bangla/English toggle, notification prefs, family profiles)

**Explicitly NOT in MVP** (see Section 6.7 for why): drug interaction/contraindication
checking, barcode-to-drug lookup, crowdsourced live pharmacy pricing.

---

## 2. Master Project Context (🤖 paste into `AGENTS.md`)

```
PROJECT: MediTrack — Flutter medicine manager app for Android (Bangladesh market).

STACK (do not substitute without a strong reason — if you think you need to, stop and
flag it instead of silently switching):
- Flutter 3.44 (stable channel), Dart 3.6+, null-safety everywhere
- State management: Riverpod 3.x, WITH code generation (@riverpod annotation).
  Never use setState for anything beyond a single dumb widget's local UI flag.
- Local database: Drift (SQLite) — all persisted structured data (medicines, schedules,
  dose logs, prescriptions, cached reference data) lives here. Drift is the single
  source of truth on-device; the app must work fully offline except for: prescription
  OCR, price lookup refresh, and nearby-pharmacy search.
- Navigation: go_router
- Backend: Supabase (Postgres + Auth + Storage + Edge Functions) via `supabase_flutter`.
  Used for: user auth, cross-device sync of the Drift data (simple last-write-wins push/
  pull, not real-time), storing prescription images, and as a proxy for any external API
  call that needs a secret key (Google Places, the vision LLM). The Flutter client NEVER
  calls a third-party paid API directly with an embedded key — it always goes through a
  Supabase Edge Function.
- OCR (printed text — medicine boxes/strips): `google_mlkit_text_recognition`, on-device,
  offline, free. Do not call any cloud OCR for this step.
- OCR (handwritten prescriptions): NOT on-device. Image goes to Supabase Storage, then a
  Supabase Edge Function calls Gemini 2.5 Flash (vision) with the exact prompt in Section
  6.5. This is the one feature that requires network connectivity.
- Camera/image capture: `camera` + `image_picker` (allow both live capture and gallery pick)
- Barcode (future, not MVP): `mobile_scanner`
- Local notifications: `flutter_local_notifications` + `timezone` package for scheduling
- Maps: `google_maps_flutter`, location via `geolocator`
- HTTP: `dio` (only for calls to our own Supabase Edge Functions; everything else goes
  through the `supabase_flutter` SDK)
- Fonts/design: `google_fonts` package (Poppins for headings, Inter for body — see
  Section 5 for full design tokens)
- Localization: `easy_localization` (English + Bangla), added in Phase 2, but wire the
  scaffolding (no hardcoded user-facing strings) from the start

CODING CONVENTIONS:
- snake_case.dart file names, one primary class per file
- After touching any file with a `@riverpod` or Drift `@DriftDatabase`/table annotation,
  ALWAYS run: `dart run build_runner build --delete-conflicting-outputs` — code will not
  compile until you do. Do this before declaring a task finished.
- Effective Dart style, `flutter analyze` must pass with zero warnings before a task is
  considered done.
- No business logic in widgets — widgets read Riverpod providers and call
  repository/notifier methods only. Put logic in `lib/domain/` or `lib/data/repositories/`.
- Every user-facing string is a `.tr()` lookup key, never a raw literal, even in MVP
  (keeps Phase 2 localization from becoming a rewrite).
- Currency: Bangladeshi Taka, symbol "৳", always formatted with `intl` NumberFormat, never
  string-concatenated manually.
- Dates stored in DB as ISO 8601 UTC; displayed in local format via `intl`.

FOLDER STRUCTURE:
lib/
  app.dart                     -- MaterialApp.router + theme wiring
  router.dart                  -- go_router config
  main.dart
  core/
    theme/                     -- colors.dart, typography.dart, spacing.dart (Section 5)
    constants/
    utils/
  data/
    local/
      database.dart            -- Drift @DriftDatabase
      tables/                  -- one file per table (Section 4)
    remote/
      supabase_client.dart
      edge_functions.dart      -- typed wrappers around each Edge Function call
    repositories/               -- MedicineRepository, ScheduleRepository, etc.
  domain/
    models/                    -- freezed-style plain Dart models (or Drift's generated
                                   row classes directly if no extra logic needed)
    logic/
      refill_calculator.dart   -- pure functions, Section 6.3 formulas, unit-testable
  features/
    onboarding/
    home/
    add_medicine/
      capture/                -- camera + ML Kit flow
      manual_form/
    prescription_scan/
    medicine_detail/
    price_lookup/
    pharmacy_map/
    settings/
    (each feature folder: screen(s), local widgets, its own riverpod providers)
  l10n/                        -- easy_localization json files
supabase/
  functions/
    parse-prescription/        -- calls Gemini 2.5 Flash, Section 6.5 prompt
    nearby-pharmacies/         -- proxies Google Places API
  migrations/                  -- Postgres schema mirroring Drift schema, Section 4

DO NOT:
- Add a second state-management library "just for this one screen"
- Add a second local database ("just to try Isar/Hive")
- Call Google Places or any LLM API directly from the Flutter client with a raw key
- Auto-save any OCR-extracted field without the user seeing and confirming it first
- Build the drug-interaction checker (out of scope, see Section 6.7)
```

---

## 3. Data Model

Drift table definitions (mirror the same shape in Postgres for sync). Types are Drift
column types; adapt directly.

```
Medicines
  id                 TEXT PK (uuid)
  user_id            TEXT (nullable until auth added)
  name               TEXT NOT NULL
  generic_name       TEXT NULL
  dosage_form        TEXT NULL        -- tablet | syrup | injection | drops | inhaler | other
  strength           TEXT NULL        -- e.g. "500 mg"
  quantity_current   INTEGER NOT NULL DEFAULT 0
  quantity_total     INTEGER NOT NULL DEFAULT 0   -- size of the pack, for % remaining
  expiry_date        DATE NULL
  batch_number       TEXT NULL
  manufacturer       TEXT NULL
  image_path         TEXT NULL        -- local file path to the captured photo
  barcode            TEXT NULL        -- reserved, Phase 3
  low_stock_threshold  INTEGER NOT NULL DEFAULT 5
  created_at         DATETIME NOT NULL
  updated_at         DATETIME NOT NULL

Schedules
  id                 TEXT PK
  medicine_id        TEXT FK -> Medicines.id
  dose_amount        INTEGER NOT NULL DEFAULT 1     -- units taken per dose
  times_per_day      INTEGER NOT NULL
  dose_times         TEXT NOT NULL     -- JSON array of "HH:mm" strings
  days_of_week       TEXT NOT NULL     -- JSON array, e.g. [1,2,3,4,5,6,7], all days default
  start_date         DATE NOT NULL
  end_date           DATE NULL         -- null = ongoing/chronic
  active              BOOLEAN NOT NULL DEFAULT TRUE

DoseLog
  id                 TEXT PK
  schedule_id        TEXT FK -> Schedules.id
  scheduled_at       DATETIME NOT NULL
  status             TEXT NOT NULL     -- pending | taken | skipped | missed
  responded_at       DATETIME NULL

Prescriptions
  id                 TEXT PK
  user_id            TEXT NULL
  image_paths        TEXT NOT NULL     -- JSON array, supports multi-page
  doctor_name        TEXT NULL
  patient_name       TEXT NULL
  date_issued        DATE NULL
  raw_llm_response    TEXT NULL         -- store the raw JSON for debugging/re-parsing
  created_at         DATETIME NOT NULL

PrescriptionMedicines            -- join table: one row per extracted line item
  id                 TEXT PK
  prescription_id    TEXT FK -> Prescriptions.id
  medicine_id        TEXT FK -> Medicines.id NULL   -- filled in once user confirms/creates
  extracted_name     TEXT NOT NULL
  extracted_strength TEXT NULL
  extracted_frequency INTEGER NULL
  extracted_duration_days INTEGER NULL
  extracted_instructions TEXT NULL
  confidence         TEXT NOT NULL     -- high | medium | low
  confirmed          BOOLEAN NOT NULL DEFAULT FALSE

MedicineReference                -- seeded/synced lookup table, Section 6.4
  id                 TEXT PK
  brand_name         TEXT NOT NULL
  generic_name       TEXT NOT NULL
  manufacturer       TEXT NULL
  dosage_form        TEXT NULL
  strength           TEXT NULL
  unit_price_bdt     REAL NULL
  source             TEXT NOT NULL     -- e.g. "medex_seed_2026"
  last_updated       DATE NOT NULL

FamilyMembers                     -- Phase 2
  id                 TEXT PK
  display_name       TEXT NOT NULL  -- e.g. "Amma", "Nadia" — no relationship label required
```

---

## 4. Design System

Reference: the attached pastel task-manager screenshots (blush pink + sage green +
cream, rounded cards, soft illustrations, bold rounded headings). Port that palette
directly rather than inventing a new one — a health app benefits from that same
calm/approachable feel rather than clinical white-and-blue.

```dart
// core/theme/colors.dart
const primaryGreen   = Color(0xFF47594E);  // deep sage — nav bar, primary buttons, icons
const primaryGreenLight = Color(0xFF6B7F6F);
const accentPink     = Color(0xFFF4B8B0);  // CTA highlights, active tab, badges
const accentPinkLight = Color(0xFFFBE0DC); // section backgrounds, chip fills
const background     = Color(0xFFFBF6F1);  // app scaffold background (warm cream)
const surface        = Color(0xFFFFFFFF);  // cards
const textPrimary    = Color(0xFF2B2B2B);
const textSecondary  = Color(0xFF8C8C8C);
const divider        = Color(0xFFF0E6DF);
const success        = Color(0xFF5B8C5A);  // "taken" state
const warning         = Color(0xFFE0A458); // "refill soon" / low-confidence OCR
const danger          = Color(0xFFD96C6C); // "expired" / "missed dose"
```

```dart
// core/theme/typography.dart — via google_fonts
headingStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600)   // titles, "Recent Tasks"-style headers
bodyStyle:    GoogleFonts.inter(fontWeight: FontWeight.w400)     // everything else
```

Spacing scale: 4 / 8 / 12 / 16 / 24 / 32 (dp).
Radius scale: cards = 20dp, small chips = 12dp, buttons = pill (999dp) — matches the
rounded-everything look in the reference.
Shadows: soft, low-opacity (`BoxShadow(color: black@6%, blur: 16, offset: (0,6))`), never
hard drop shadows.
Illustrations: use a consistent flat-illustration style (same family as the reference —
think Storyset/unDraw customized to the palette above) for onboarding and empty states
(empty medicine list, empty prescription list, etc.) — empty states should never be a
bare "No data" text.

Screen list (Section 8 builds these in order):
1. Onboarding (3 slides + "Get Started", illustration-led, matches reference style)
2. Home dashboard — "Today's Doses" card list + "Upcoming Refills" + "Expiring Soon" +
   FAB for add-medicine
3. Add Medicine — bottom sheet: Scan Box / Scan Prescription / Manual Entry
4. Camera capture screen (shared by box-scan and prescription-scan, different post-processing)
5. OCR review/edit form (pre-filled, always editable, save button disabled until required
   fields present)
6. Medicine detail screen (edit, delete, dose history, adjust schedule)
7. Prescription review screen (list of extracted line items, each a card with confidence
   badge, edit-in-place, "add all to my medicines" button)
8. Price & Generic Lookup — search bar + results list sorted by price ascending
9. Nearby Pharmacies — map/list toggle
10. Settings — language, notification thresholds, family members, data export

---

## 5. Feature Specs

### 5.1 Add Medicine via Camera OCR
Flow: FAB → bottom sheet → "Scan Box" → camera opens → capture → run
`google_mlkit_text_recognition` on the image → pass raw recognized blocks (with their
bounding-box heights) into a pure parsing function → pre-fill form → user reviews →
save.

Parsing heuristics (implement as pure, unit-testable functions in
`domain/logic/ocr_parser.dart`):
- Expiry date: search recognized lines (case-insensitive) for a token matching
  `exp|expiry|exp date|use before`, then look at that line and the following line for a
  date pattern: `DD/MM/YYYY`, `MM/YYYY`, `MM-YYYY`, `DD-MM-YYYY`. Parse the *first* match.
- Manufacture date: same approach with `mfg|manufactured|mfd`.
- Batch number: same approach with `batch|b\.no|lot`.
- Medicine name candidate: the text block with the largest bounding-box height that is
  not itself a date/batch/keyword line — surface it as the pre-filled "name" field, but
  never treat this as reliable; it is a starting guess only, and the field is always
  editable before save.
- If a heuristic finds nothing, leave that field blank (never fabricate a placeholder
  value).

### 5.2 Prescription OCR
Handwriting recognition is out of reach for on-device OCR, so this step uses a cloud
vision LLM behind a Supabase Edge Function (keeps the API key server-side).

Flow: "Scan Prescription" → camera (supports adding multiple pages) → upload each image
to Supabase Storage bucket `prescriptions/{user_id}/{prescription_id}/{page_n}.jpg`
(private bucket, signed URLs only) → call Edge Function `parse-prescription` with the
storage paths → Edge Function fetches the images, calls Gemini 2.5 Flash with the prompt
below, parses the JSON response → returns it to the client → client renders the review
screen (Section 4, screen 7) → user edits/confirms each line → confirmed items become
rows in `Medicines` + `Schedules`, linked back via `PrescriptionMedicines`.

🤖 Exact system prompt for the Edge Function's LLM call:
```
You are a medical prescription OCR assistant. You will receive one or more images of a
doctor's prescription, which may be handwritten and may mix Bangla and English. Extract
only what is visibly present on the page — never infer or guess a medicine name, dosage,
or duration that is not legible. If a field is not clearly readable, output null for it
rather than guessing.

Return ONLY valid JSON, no prose, no markdown code fences, matching exactly this schema:
{
  "doctor_name": string|null,
  "patient_name": string|null,
  "date": string|null,           // "YYYY-MM-DD" if determinable, else the raw text seen
  "medicines": [
    {
      "name": string,
      "strength": string|null,
      "form": string|null,        // tablet, syrup, injection, etc. if stated
      "frequency_per_day": number|null,
      "duration_days": number|null,
      "instructions": string|null, // e.g. "after meal", free text
      "confidence": "high"|"medium"|"low"
    }
  ]
}
If the image is unreadable or is not a prescription, return {"error": "unreadable"}.
```
Client-side rule: any line item with `confidence: "low"` or `"medium"` is visually
flagged (warning-colored badge) on the review screen so the user scrutinizes it before
confirming — never auto-confirm low-confidence items.

Always show a persistent one-line disclaimer on this screen: extraction can be wrong;
verify against the physical prescription before relying on it.

### 5.3 Refill / Dose Reminder Logic
Pure functions in `domain/logic/refill_calculator.dart`, unit-tested, no UI dependency.

```
daily_dose_units(schedule) = schedule.dose_amount * schedule.times_per_day
days_remaining(medicine, schedule) = floor(medicine.quantity_current / daily_dose_units(schedule))

refill_due = days_remaining <= refill_alert_days_before   // default 3, user-configurable 1-14
low_stock  = medicine.quantity_current <= medicine.low_stock_threshold  // default 5
expiring_soon = (medicine.expiry_date - today).days <= expiry_alert_days_before  // default 30, range 7-90
```

Notification scheduling (via `flutter_local_notifications` + `timezone`):
- On medicine/schedule save, cancel and reschedule that medicine's notifications:
  one repeating local notification per entry in `dose_times`, an expiry-warning
  notification fired once at (expiry_date - expiry_alert_days_before), and a refill
  notification recomputed and rescheduled whenever quantity changes.
- "Mark as Taken" (from notification action button or home screen card): insert a
  `DoseLog` row with status `taken`, decrement `quantity_current` by `dose_amount`,
  recompute refill status.
- "Snooze": reschedule the same notification +15/+30/+60 min (user-configurable presets),
  do not touch quantity or log status yet.
- "Skip": insert `DoseLog` row with status `skipped`, do not decrement quantity.
- "Missed" detection (MVP approach — simplest thing that works, revisit if it's not
  reliable enough): on every app open, scan for `DoseLog` rows with status `pending` and
  `scheduled_at` more than 2 hours in the past, mark them `missed`. Do not attempt a
  background-only solution (WorkManager-based periodic reconciliation) until this
  simpler approach proves insufficient in practice — it adds real complexity for a
  marginal reliability gain at MVP stage.

### 5.4 Price & Generic-Alternative Lookup
Important reframe, stated plainly because it changes what's actually buildable: there is
no live public API in Bangladesh that reports what different *pharmacies* currently
charge for a given medicine — that data simply isn't published anywhere accessible.
What does exist is manufacturer-listed unit prices (MRP) per brand, aggregated by
medex.com.bd, and there's already a public scrape of it (an open-source scraper,
`bd-medicine-scraper` on GitHub, and a matching ~25k-row dataset on Kaggle, "All Medicine
Data of Bangladesh"). Before scraping medex.com.bd yourself in production, check its
current terms of service/robots.txt — treat that as an open task for you to verify, not
something to automate blindly.

So MVP feature = **"Price & Generic Lookup"**, not "pharmacy price comparison":
- Seed `MedicineReference` from that existing dataset (one-time import script,
  `source: "medex_seed_2026"`, `last_updated` set at import time).
- Search screen: user types a brand or generic name → results show brand, manufacturer,
  strength, unit price (৳) → below that, "Other brands with the same generic" sorted
  ascending by price, so the user can spot a cheaper equivalent.
- Prices are reference/last-known values, not live — show `last_updated` on every result
  so the user knows how stale it is; do not imply real-time accuracy.
- True cross-pharmacy live comparison is a Phase 3+ idea (would need crowdsourced shelf
  prices from users, with moderation) — flagged, not built now.

### 5.5 Nearby Pharmacy
- Client calls Supabase Edge Function `nearby-pharmacies` with the device's lat/lng
  (from `geolocator`) → Edge Function proxies Google Places API (Nearby Search, New) with
  `type=pharmacy`, keeping the Google API key server-side → returns name, address,
  distance, rating, open-now status.
- `google_maps_flutter` renders markers + user location; toggle to a plain list view
  sorted by distance.
- Google Places coverage can thin out outside Dhaka/major cities — if a search returns
  under ~3 results, that's worth surfacing to the user honestly ("few results found near
  you") rather than silently showing an empty map.

### 5.6 Settings / Family Profiles (Phase 2)
- Language toggle (English/Bangla) via `easy_localization` — this is why Section 2
  requires every string to be a translation key from day one.
- Notification threshold sliders (refill days, expiry days, snooze presets) —
  read/write to a simple key-value Drift table or `shared_preferences`.
- Family members: a lightweight list (display name only, no relationship label required)
  that medicines can optionally be tagged with, so one account can track a parent's and
  a child's medicines separately on the same home dashboard (filter chips).

### 5.7 Deliberately out of scope for now
- **Drug interaction / contraindication checking.** This would mean the app making a
  medical-safety claim, which needs a properly licensed interaction database and, really,
  clinical review before shipping — a hand-rolled ruleset here is a genuine safety risk,
  not just a nice-to-have gap. Worth revisiting later with that in mind, not as a
  weekend feature.
- **Barcode → drug lookup.** No public barcode database for Bangladeshi pharma exists,
  so this only works if the user's own data is barcode-tagged manually — low value for
  the effort right now.
- **Live crowdsourced pharmacy pricing.** Needs a moderation system before it's trustworthy.

---

## 6. Build Phasing

**Phase 1 (MVP):** Sections 5.1, 5.3, home dashboard, manual add/edit/delete, onboarding.
App is fully usable and offline-capable at the end of this phase.

**Phase 2:** 5.2 (prescription OCR), 5.4 (price/generic lookup), localization,
family profiles.

**Phase 3:** 5.5 (nearby pharmacy — needs a live Google API budget), dose-adherence
history/calendar view, PDF export of medicine list for doctor visits, dark mode.

**Not scheduled:** 5.7 items.

---

## 7. Task Prompts (🤖 feed one at a time, in order, to your coding AI)

Each of these assumes Section 2 is already sitting in `AGENTS.md` as standing context —
don't repeat the stack decisions inside these, just reference them.

1. **Scaffold the project.** `flutter create`, add all packages from Section 2's stack
   list to `pubspec.yaml` at their latest stable versions, set up the folder structure
   exactly as listed, wire up an empty `MaterialApp.router` with `go_router` and a single
   placeholder home route. Confirm `flutter analyze` is clean.
2. **Theme.** Implement `core/theme/colors.dart`, `typography.dart`, `spacing.dart`
   exactly per Section 4. Build a `ThemeData` from them. Add a throwaway screen showing
   every color swatch, both font styles, and a sample button/card so the palette can be
   eyeballed before building real screens.
3. **Drift schema.** Implement every table in Section 3 in `data/local/tables/`, wire up
   `database.dart`, run the code generator, confirm the app builds and a trivial
   insert/query round-trips in a widget test.
4. **Onboarding screens.** Three illustrated slides + "Get Started" CTA, matching the
   reference screenshot's layout and the palette from step 2. Illustrations can be
   placeholder SVGs for now if real art isn't ready.
5. **Home dashboard.** "Today's Doses", "Upcoming Refills", "Expiring Soon" sections
   reading from Riverpod providers backed by the Drift repositories; empty states for
   each section; FAB opening the add-medicine bottom sheet (can be a stub for now).
6. **Manual add/edit medicine form.** Full form for every `Medicines` + `Schedules`
   field from Section 3, with validation, wired to save into Drift.
7. **Camera capture + on-device OCR.** Implement `camera`/`image_picker` capture,
   `google_mlkit_text_recognition` extraction, the parsing heuristics in Section 5.1
   as pure functions with unit tests, then pre-fill the form from step 6.
8. **Reminder engine.** Implement Section 5.3's pure calculator functions (with unit
   tests covering the boundary cases explicitly — exactly at threshold, zero quantity,
   no end date), then wire `flutter_local_notifications` scheduling and the
   taken/snooze/skip actions.
9. **Prescription OCR.** Supabase Edge Function `parse-prescription` using the exact
   prompt in Section 5.2, image upload flow, and the review/confirm screen with
   confidence badges.
10. **Price & generic lookup.** Import script for the seed dataset into
    `MedicineReference`, the search screen from Section 5.4.
11. **Nearby pharmacy map.** Edge Function `nearby-pharmacies`, map + list screen.
12. **Settings + localization.** `easy_localization` wiring, threshold sliders, family
    member list.
13. **Polish pass.** Dark mode, empty-state illustrations everywhere, accessibility
    check (font scaling, contrast), and a final `flutter analyze` + test run.

---

## 8. Things only you can decide/provide before an AI can actually build this

- Final app name (working title "MediTrack" used throughout this doc)
- Supabase project + keys; Google Cloud project with Places API + a Gemini API key
- Whether to gate the app behind login on day one or let it work fully anonymous/local
  until the user opts into cloud sync (recommend the latter — lower friction for MVP)
- Where the seed medicine-price dataset actually gets hosted (bundled in-app CSV vs a
  Supabase table you populate once) — bundled CSV is simpler for MVP, no reason to stand
  up the sync path before Phase 2 needs it
