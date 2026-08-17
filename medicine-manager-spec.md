# MediTrack — Medicine Manager App: Build Spec & AI Prompt Pack

*(Working title "MediTrack" — rename freely, it's a find-and-replace.)*

## 0. How to use this document

This is written so it can be handed to a coding AI one section at a time. Every
architectural decision below is already made — the goal is to leave the implementing AI
with judgment calls only about code-level details, not product or stack decisions.

- Section 2 ("Master Project Context") is kept in sync with the repo's root `AGENTS.md`.
  If you change a stack decision in one, update the other in the same pass — they should
  never drift apart.
- Section 5.2 ends with its own "Execution Strategy" (5.2.8) — a phased, ordered plan
  specific to rebuilding prescription OCR into a production-grade pipeline. Follow it in
  order; steps 1–4 are a strict dependency chain, don't parallelize those.
- Section 6 ("Build Phasing") is the single sequencing reference for the rest of the app.
  Work phase by phase, and update it as features land or slip — it already reflects what
  is actually shipped today, not just what was originally planned.
- Anywhere you see a 🤖 marker, that block is meant to be copy-pasted as-is.

---

## 1. Product Overview

**What it is:** An Android-first medicine management app for personal/family use in
Bangladesh. Core loop: snap a photo of a medicine strip/box or a doctor's prescription →
app extracts the details → app tracks stock, schedules doses, reminds you to take/refill,
and helps you find a cheaper generic or a nearby pharmacy.

**MVP feature set** (build in this order, see Section 6 for phasing):
1. Add medicine by camera + on-device OCR (name, expiry, batch, quantity)
2. Dose scheduling + local reminders (take-now / refill / expiry alerts)
3. Home dashboard (today's doses, upcoming refills, expiring soon)
4. Manual add/edit/delete medicine
5. Scan prescription (photo → structured medicine list via Firebase AI Logic / Gemini)
6. Medicine price & generic-alternative lookup
7. Nearby pharmacy map
8. Settings (Bangla/English toggle, notification prefs, family profiles)

**Explicitly NOT in MVP** (see Section 5.7 for why): drug interaction/contraindication
checking, barcode-to-drug lookup, crowdsourced live pharmacy pricing.

**Beyond the original MVP, already shipped:** an in-app Gemini-powered AI health
assistant, a prescription "digital vault" (image + notes storage), a medicine buy/restock
list, a calendar/routine view of dose history, full auth (anonymous, email/password,
Google Sign-In), and a BD Apps SMS subscription integration. None of this replaces
anything in this spec — see Section 5.8 for what each one is and Section 6 for how it
slots into the phasing.

---

## 2. Master Project Context (🤖 kept in sync with the root `AGENTS.md`)

```
PROJECT: MediTrack — Flutter medicine manager app for Android (Bangladesh market).

STACK (do not substitute without a strong reason — if you think you need to, stop and
flag it instead of silently switching):
- Flutter 3.44 (stable channel), Dart 3.6+, null-safety everywhere.
- State management: `provider` (`ChangeNotifier` + `MultiProvider`). Never use `setState`
  for anything beyond a single dumb widget's local UI flag; anything shared across
  widgets/screens goes through a `ChangeNotifier`/service exposed via `Provider`.
- Backend: **Firebase** for everything except the BD Apps SMS integration (see below):
  - `firebase_auth` — anonymous sign-in as the frictionless default entry point,
    upgradeable to email/password or Google Sign-In from Settings.
  - `cloud_firestore` — the single source of truth for structured data. Firestore's
    built-in offline persistence/cache is what gives the app offline read/write support
    — do not add Drift, Isar, Hive, sqflite, or any other local database "for offline
    support"; that problem is already solved.
  - `firebase_storage` — prescription images and any other user-uploaded files.
  - `firebase_app_check` — required on every Firebase AI Logic call and should guard
    Firestore/Storage writes too; Play Integrity in release, debug provider in debug
    builds (already wired in `main.dart`).
  - Cloud Functions for Firebase (not yet in this repo — add under `functions/` with the
    Firebase CLI when needed) is the ONLY place allowed to hold a third-party secret key
    (e.g. Google Places for Section 5.5). The Flutter client must never embed a raw
    secret key for a paid external API.
- AI / vision (prescription OCR, in-app AI assistant): `firebase_ai` (Firebase AI Logic)
  calling Gemini 2.5 Flash **directly from the Flutter client**, gated by
  `firebase_app_check` + `firebase_auth`. This is Firebase AI Logic's supported
  client-calling pattern — App Check attestation is the abuse control, so this does not
  violate the "no embedded secret key" rule above (there is no secret to embed). See
  Section 5.2 for the full pipeline and the exact prompt/schema contract.
- OCR (printed text — medicine boxes/strips): `google_mlkit_text_recognition`, on-device,
  offline, free. Do not call any cloud OCR/LLM for this step — it's solved on-device.
- Camera/image capture: `image_picker` (camera + gallery). Only add the lower-level
  `camera` package if a fully custom in-app capture UI becomes a real requirement — don't
  add it speculatively.
- Local notifications: `flutter_local_notifications` + `timezone` + `flutter_timezone`
  for scheduling dose/expiry/refill reminders.
- Maps (Phase 3, nearby pharmacy): `google_maps_flutter`, location via `geolocator`.
- HTTP: `dio` — used for the BD Apps SMS/subscription backend (`lib/features/bdapps/`, a
  PHP service under `backend/`) and for any future Cloud Function invoked over plain
  HTTPS instead of an SDK. Never used to call a third-party paid API directly with an
  embedded key.
- Fonts/design: `google_fonts` (Poppins for headings, Inter for body — Section 4).
- Config/secrets: `flutter_dotenv` (`.env`, gitignored) for non-Firebase config only (BD
  Apps base URL, etc.). Firebase project config lives in `firebase_options.dart` /
  `google-services.json` / `GoogleService-Info.plist`, generated via `flutterfire
  configure` — never hand-edited, never duplicated into `.env`.
- Localization: not wired yet (Section 5.6). `easy_localization` is the intended package
  when it lands; keep user-facing strings centralized rather than scattered so that
  migration is a mechanical pass, not a rewrite.

CODING CONVENTIONS:
- snake_case.dart file names, one primary class per file (a small, tightly-related
  private helper class in the same file is fine, e.g. a result class next to its service).
- `flutter analyze` must pass with zero warnings before a task is considered done.
- No business logic in widgets — widgets call into `lib/services/` (Firestore/Storage/
  Auth/AI access) and `lib/logic/` (pure calculation functions, e.g.
  `refill_calculator.dart`) only. If a widget accumulates parsing/calculation code,
  extract it.
- Every Firestore read/write goes through a `*Service` class in `lib/services/`, never
  directly from a widget via `FirebaseFirestore.instance`.
- Firestore documents are scoped per-user under `users/{uid}/...`; every new collection
  must be added to `firestore.rules` with the same `request.auth.uid == userId` scoping
  before it ships — an unscoped collection is a security bug, not a follow-up task.
- Every user-facing string should read naturally in English today and be easy to hoist
  into `.tr()`/ARB lookups later — avoid concatenating sentence fragments a translator
  would need to reorder.
- Currency: Bangladeshi Taka, symbol "৳", always formatted with `intl` NumberFormat,
  never string-concatenated manually.
- Dates stored in Firestore as `Timestamp`; converted to/from `DateTime` at the model
  boundary (`fromSnapshot`/`toMap`), displayed in local format via `intl`.
- Never auto-save an OCR- or AI-extracted field without the user seeing and confirming it
  first (applies to both Section 5.1 box-scan and Section 5.2 prescription OCR).

FOLDER STRUCTURE (current — extend it, don't restructure it without a strong reason):
lib/
  main.dart                    -- Firebase/App Check/dotenv/notifications init, MaterialApp
  config/
    api_config.dart            -- BD Apps base URL etc.
  core/
    network/                   -- dio_client.dart and other cross-cutting network setup
  theme/
    colors.dart                -- AppColors, Section 4
    typography.dart            -- AppTypography, Section 4
    app_theme.dart              -- ThemeData built from the above
  models/                      -- plain Dart classes with toMap()/fromSnapshot() per
                                   Firestore doc shape (Section 3), no business logic
  services/                    -- one class per Firestore/Storage/Auth/AI concern
                                   (MedicineService, PrescriptionService,
                                   NotificationService, GeminiAiService, ...)
  logic/                       -- pure, unit-testable functions only (refill_calculator.dart;
                                   the Section 5.1 OCR heuristics and Section 5.2 validation
                                   rules belong here too)
  screens/                     -- one file per screen; local-only widgets can live in the
                                   same file, promote to a widgets/ subfolder if reused
  features/
    bdapps/                    -- self-contained BD Apps SMS/subscription integration
                                   (its own data/ layer, service, Provider)
  utils/                       -- small stateless helpers (time_formatter.dart, etc.)
firestore.rules                -- security rules, source of truth for who can read what
firebase.json                  -- FlutterFire project wiring (projectId, app IDs)
backend/                       -- PHP endpoints for BD Apps OTP/SMS/subscription webhooks
                                   (not Firebase — a separate legacy/telco integration)

DO NOT:
- Add a second state-management library "just for this one screen" (no Riverpod/Bloc
  alongside Provider).
- Add a second local database ("just to try Drift/Isar/Hive") — Firestore's offline cache
  already covers this.
- Call Google Places, or any paid third-party API that requires a real secret key,
  directly from the Flutter client — proxy it through a Cloud Function for Firebase.
- Auto-save any OCR- or AI-extracted field without the user seeing and confirming it first.
- Build the drug-interaction checker (out of scope, see Section 5.7).
- Widen `firestore.rules` (or `storage.rules`) beyond per-user scoping to "make a bug go
  away" — fix the query instead.
```

---

## 3. Data Model

Cloud Firestore, not a relational schema — model as collections/subcollections scoped
per user. Field names below match the actual Dart model classes (camelCase); Firestore
stores dates as `Timestamp` and everything else maps directly (`String`, `int`, `double`,
`bool`, `List`, `Map`). Entries marked **(planned)** don't exist in the codebase yet —
they're additions this spec calls for (Section 5.2's execution strategy, Section 5.4's
lookup table, Phase 2's family profiles).

```
users/{uid}                                  -- profile doc
  displayName            String
  email                  String
  bloodGroup             String?
  allergies              String?
  doctorName             String?
  doctorPhone            String?
  emergencyContactName   String?
  emergencyContactPhone  String?
  enableDoseReminders    bool (default true)
  enableExpiryAlerts     bool (default true)
  enableLowStockAlerts   bool (default true)
  bdMobile               String?   -- BD Apps SMS subscriber id, ^01[3-9][0-9]{8}$

users/{uid}/medicines/{medicineId}
  name                 String
  genericName          String?
  dosageForm           String?    -- tablet | syrup | injection | drops | inhaler | other
  strength             String?    -- e.g. "500 mg"
  quantityCurrent      int (default 0)
  quantityTotal        int (default 0)     -- pack size, for % remaining
  expiryDate           Timestamp?
  batchNumber          String?
  manufacturer         String?
  imageUrl             String?              -- Firebase Storage download URL
  lowStockThreshold    int (default 5)
  schedule             Map                  -- embedded, see below
  createdAt            Timestamp
  updatedAt            Timestamp

  `schedule` map (embedded 1:1 today — promote to a `schedules` subcollection only if/when
  a medicine needs more than one concurrent schedule, e.g. "3x on weekdays, 1x on
  weekends" as two independent series):
    doseAmount           int (default 1)
    timesPerDay          int
    doseTimes            List<String>       -- ["08:00", "20:00"]
    daysOfWeek           List<int>          -- [1..7], all days default
    startDate            Timestamp
    endDate              Timestamp?         -- null = ongoing/chronic
    active               bool (default true)

users/{uid}/doseLogs/{logId}
  medicineId           String
  medicineName         String   -- denormalized so history/notifications don't need a join
  scheduledAt          Timestamp
  status               String   -- pending | taken | skipped | missed
  respondedAt          Timestamp?

users/{uid}/prescriptions/{prescriptionId}
  title                String
  doctorName           String?
  date                 Timestamp
  imageUrl             String?              -- Firebase Storage download URL, private
  extractedText        String               -- raw ML Kit / Gemini text, for debugging & search
  notes                String?
  status               String (planned)     -- draft | reviewed, Section 5.2
  createdAt            Timestamp

users/{uid}/prescriptions/{prescriptionId}/items/{itemId}   -- (planned, Section 5.2)
  extractedName            String
  extractedStrength        String?
  extractedForm            String?
  extractedFrequencyPerDay int?
  extractedDurationDays    int?
  extractedInstructions    String?
  confidence               String   -- high | medium | low
  confirmed                bool (default false)
  medicineId               String?  -- filled in once the user confirms/creates the medicine

users/{uid}/buyList/{itemId}
  medicineId           String?
  name                 String
  quantityToBuy        int (default 1)
  estimatedPrice       double?
  isPurchased          bool (default false)
  notes                String?
  createdAt            Timestamp

users/{uid}/familyMembers/{memberId}         -- (planned, Phase 2, Section 5.6)
  displayName          String   -- e.g. "Amma", "Nadia" — no relationship label required

medicineReference/{id}                       -- (planned, Section 5.4) top-level, NOT
                                                 per-user; shared seed/reference data.
                                                 Client gets read-only access via
                                                 firestore.rules; writes only from an
                                                 authenticated seed script/Cloud Function.
  brandName            String
  genericName          String
  manufacturer         String?
  dosageForm           String?
  strength             String?
  unitPriceBdt         double?
  source               String   -- e.g. "medex_seed_2026"
  lastUpdated          Timestamp
```

---

## 4. Design System

Reference: the attached pastel task-manager screenshots (blush pink + sage green +
cream, rounded cards, soft illustrations, bold rounded headings). Port that palette
directly rather than inventing a new one — a health app benefits from that same
calm/approachable feel rather than clinical white-and-blue. This is already implemented
exactly as below in `lib/theme/`.

```dart
// theme/colors.dart
class AppColors {
  static const Color primaryGreen      = Color(0xFF47594E); // deep sage — nav bar, primary buttons, icons
  static const Color primaryGreenLight = Color(0xFF6B7F6F);
  static const Color accentPink        = Color(0xFFF4B8B0); // CTA highlights, active tab, badges
  static const Color accentPinkLight   = Color(0xFFFBE0DC); // section backgrounds, chip fills
  static const Color background        = Color(0xFFFBF6F1); // app scaffold background (warm cream)
  static const Color surface           = Color(0xFFFFFFFF); // cards
  static const Color textPrimary       = Color(0xFF2B2B2B);
  static const Color textSecondary     = Color(0xFF8C8C8C);
  static const Color divider           = Color(0xFFF0E6DF);
  static const Color success           = Color(0xFF5B8C5A); // "taken" state
  static const Color warning           = Color(0xFFE0A458); // "refill soon" / low-confidence OCR
  static const Color danger            = Color(0xFFD96C6C); // "expired" / "missed dose"
}
```

```dart
// theme/typography.dart — via google_fonts
class AppTypography {
  static TextStyle headingLarge  = GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle headingMedium = GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle headingSmall  = GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle bodyLarge     = GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static TextStyle bodyMedium    = GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static TextStyle bodySmall     = GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static TextStyle buttonText    = GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white);
}
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

Screen list (sequencing lives in Section 6 now; see Section 5.8 for screens already
shipped beyond this original list — Welcome/Login/Signup, AI Assistant, Buy List,
Prescription Vault, Calendar & Routine, Profile Settings):
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
Flow: FAB → bottom sheet → "Scan Box" (or the camera icon on the manual Add/Edit form) →
`image_picker` opens the camera → capture → run `google_mlkit_text_recognition` on the
image → pass the raw recognized text into a pure parsing function → pre-fill the form →
user reviews → save.

Parsing heuristics (currently implemented inline inside
`screens/add_edit_medicine_screen.dart` — extract them into `lib/logic/ocr_parser.dart`
as pure, unit-testable functions the next time that screen is touched; logic embedded in
a `State` class can't be unit-tested):
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

**Why this is hard, stated plainly:** prescriptions are often handwritten, frequently mix
Bangla and English, and a misread dosage or frequency is a genuine safety issue, not a
cosmetic bug. That combination rules out a purely on-device solution and demands more
rigor than "send image to an LLM, show the text."

**Current status:** there is a working prototype today — `PrescriptionOcrService` runs
on-device ML Kit text recognition and flags lines containing keywords like "mg"/"tab"/
dose-pattern digits as "detected medicines" (a plain string list, no structured fields,
no confidence, no persistence of line items), and separately, `AIPrescriptionService` /
`GeminiAiService` can send a photo to Gemini 2.5 Flash and get back free-text analysis
in the general AI-assistant chat. Neither path produces the structured, reviewable,
confidence-scored extraction this feature needs, and they aren't wired together. The
rest of this section is the target architecture, and 5.2.8 is the concrete plan to get
there — treat it as the current top priority (Section 6).

#### 5.2.1 Design goals (non-negotiable)
- Never let a model output become a saved dosage without a human looking at it —
  confirmation is mandatory, not a UX nicety (this is already a standing rule in
  Section 2's DO NOT list).
- Fail loudly and cheaply, not silently and expensively — a bad photo should be caught
  before an AI call, not after.
- Every extraction attempt is auditable: which prompt/schema version, which model, what
  confidence, what the user changed after reviewing.
- Cost and latency are user-visible (a spinner, a wait, a call that counts against
  quota) — validate everything client-side that can be validated client-side first.
- Prescriptions are health data (PHI). They get the strictest handling Firebase offers by
  default: private Storage paths, rules scoped per `uid`, no cross-user reads, nothing
  raw going into analytics or crash logs.

#### 5.2.2 Pipeline architecture
1. **Capture & assembly** — `image_picker` camera/gallery, multi-page supported (a list
   of files assembled client-side before upload). Compress each page client-side
   (target ≤ 1600px longest edge, JPEG quality ~85) before it touches the network — keeps
   the Gemini inline-data payload small and Storage cheap.
2. **Client-side pre-flight quality gate** — before spending an AI call: warn on pages
   that are too dark, too small, or look blurry (a cheap luminance/resolution check is
   enough for v1; a proper blur estimator is a nice-to-have, not a blocker). Surface this
   as "this looks unclear, retake?" with an explicit "use anyway" override — never a hard
   block, since a low-quality photo may still be the best one available.
3. **Structured extraction call** — Firebase AI Logic (`firebase_ai`), Gemini 2.5 Flash,
   called with the exact contract in 5.2.3, using the SDK's structured-output support
   (`GenerationConfig` with a JSON response schema) so the JSON shape is enforced at the
   API level rather than relying on prompt-following alone. Verify the exact `Schema`
   builder API against the `firebase_ai` version pinned in `pubspec.yaml` before wiring
   this up — the JSON shape below is the contract, not a claim about exact Dart syntax.
   Gated by `firebase_app_check` + `firebase_auth`, per Section 2.
4. **Response validation** — layered on top of the model's own `confidence` field,
   re-validate client-side before ever showing the review screen: reject items with an
   empty `name`, flag `frequency_per_day` outside 1–6 or `duration_days` outside 1–180 as
   suspicious (don't silently discard — surface them, lower their confidence), and treat
   any JSON parse failure or schema mismatch as an explicit "extraction failed" state,
   never a crash.
5. **Durable persistence before review** — write the `prescriptions/{id}` doc
   (`status: "draft"`) and one `items/{itemId}` doc per extracted line (Section 3)
   immediately after a successful call, so a crash or navigating away doesn't lose the
   extraction and force a re-scan (a re-scan is another paid API call).
6. **Human review & confirm screen** — per-item card: every extracted field, editable; a
   confidence badge using Section 4's success/warning/danger colors for high/medium/low;
   a persistent one-line disclaimer ("extraction can be wrong; verify against the
   physical prescription"); and a bulk "Add all confirmed to My Medicines" action that
   only touches explicitly-confirmed items — default the confirm checkbox ON for
   high-confidence items and OFF for medium/low (still visible and editable, never
   silently skipped).
7. **Confirmation → write-through** — confirmed items become `medicines` (+ a default
   `schedule` the user can immediately adjust) docs, linked back via `medicineId` on the
   `items` doc; `prescriptions/{id}.status` flips to `"reviewed"`.

#### 5.2.3 Exact contract for the Gemini call
🤖 System prompt:
```
You are a medical prescription OCR assistant. You will receive one or more images of a
doctor's prescription, which may be handwritten and may mix Bangla and English. Extract
only what is visibly present on the page — never infer or guess a medicine name, dosage,
or duration that is not legible. If a field is not clearly readable, output null for it
rather than guessing.

Return ONLY valid JSON, no prose, no markdown code fences, matching exactly this schema:
{
  "schema_version": 1,
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
Use `schema_version` for forward-compatible migrations — bump it whenever the shape
changes, and branch client-side parsing on it rather than assuming the latest shape.
Client-side rule: any line item with `confidence: "low"` or `"medium"` is visually
flagged on the review screen so the user scrutinizes it before confirming — never
auto-confirm low-confidence items. Always show the disclaimer from 5.2.2 step 6.

#### 5.2.4 Error handling taxonomy
| Failure | Detection | User-facing behavior |
|---|---|---|
| Image unreadable / not a prescription | model returns `{"error": "unreadable"}` | Toast + retake prompt, no draft written |
| Network/timeout | SDK exception | Retry button, then fall back to "save the photo only, extract later" |
| Malformed JSON despite schema | parse failure | One silent retry with a stricter reminder appended to the prompt; if that also fails, fall back to on-device ML Kit raw text + manual entry |
| Quota/rate limit (App Check / Gemini) | SDK error code | Friendly "AI extraction is busy, try again shortly" + keep the photo saved as a plain prescription-vault entry so the user isn't blocked |
| Low confidence across all items | client-side check | Still show the review screen, but with a banner: "This scan wasn't very clear — please double check every field" |

#### 5.2.5 Observability & quality tracking
Log (never with PHI content): call latency, success/failure/error-type counts, the
confidence distribution per extraction, and the "edit rate" (did the user change a field
the model filled in). A simple aggregated diagnostics doc or Firebase Analytics custom
events with all prescription content stripped out is enough — this is how you'd actually
know the feature works, not just that it shipped.

#### 5.2.6 Security & privacy
Prescription images live at `users/{uid}/prescriptions/{prescriptionId}/{page}.jpg` in
Firebase Storage. **`storage.rules` does not exist in this repo today** — this repo has
`firestore.rules` but no Storage rules file, and `firebase.json` doesn't reference one
either, so uploads are currently running on whatever the project's default Storage access
is. This is a real gap, not a hypothetical one, since prescription images are already
being uploaded. Treat adding `storage.rules` (scoped the same way as `firestore.rules`:
`request.auth.uid == uid`) as a blocking prerequisite — see Step 0 in 5.2.8. Never
generate a public/shareable download URL for a prescription image.

#### 5.2.7 Testing strategy
A small fixed set of representative prescription photos (clear handwriting, messy
handwriting, Bangla+English mix, blurry, and a non-prescription control image) checked
into `test/fixtures/` — synthetic/sample prescriptions only, never real patient data —
used as a manual/semi-automated regression pass whenever the prompt or schema changes.
Unit-test the client-side validation/clamping logic from 5.2.4 as pure functions (no
network involved, no mocking needed).

#### 5.2.8 Execution Strategy
Ordered, each step independently buildable and reviewable. Steps 1–4 are a strict
dependency chain — don't parallelize those; steps 6–8 can trail behind once 1–5 are
stable.

0. **Security prerequisite.** Add `storage.rules` scoping `users/{uid}/**` to the owner
   (mirroring `firestore.rules`), reference it from `firebase.json`, deploy with
   `firebase deploy --only storage`. Do this before anything else in this list — the gap
   already exists in production today.
1. **Extraction contract.** Define the JSON schema as a `Schema` object plus the system
   prompt as a versioned constant (`schemaVersion`), and wire
   `GenerationConfig(responseMimeType: 'application/json', responseSchema: ...)` into a
   new `PrescriptionExtractionService`. This service is specific to the structured
   extraction flow — it doesn't replace `GeminiAiService` (Section 5.8), which stays as
   the general-purpose chat assistant.
2. **Client-side validation.** Pure functions in `lib/logic/prescription_validator.dart`
   implementing the clamping/rejection rules from 5.2.4. Write these against the fixtures
   from 5.2.7 first — the schema from Step 1 already defines the shape, so tests can be
   written before the service that produces the data.
3. **Pre-flight quality gate.** Image compression + the darkness/size heuristics from
   5.2.2 step 2, surfaced as a non-blocking warning before upload.
4. **Data layer.** Add the `items` subcollection (Section 3) to `PrescriptionService`;
   write the draft prescription + items immediately after a successful extraction call,
   before navigating to the review screen.
5. **Review/confirm UI.** Rebuild `ScanPrescriptionScreen`'s post-scan section into the
   per-item, confidence-badged review cards from 5.2.2 step 6, replacing today's flat
   "detected medicines" chip list. Wire the bulk-confirm action to
   `MedicineService.saveMedicine` per confirmed item.
6. **Error handling & retries.** Implement the full taxonomy from 5.2.4, including the
   "save photo only, extract later" fallback path.
7. **Observability.** Add the lightweight diagnostics logging from 5.2.5.
8. **Regression pass.** Run the fixture set from 5.2.7 end-to-end, tune the prompt/schema
   against real failures, bump `schema_version` if the shape changes as a result.

### 5.3 Refill / Dose Reminder Logic
Pure functions already implemented in `lib/logic/refill_calculator.dart`
(`RefillCalculator`), unit-tested, no UI/Firestore dependency:

```
dailyDoseUnits(schedule) = schedule.doseAmount * schedule.timesPerDay
daysRemaining(quantityCurrent, schedule) = floor(quantityCurrent / dailyDoseUnits(schedule))

isRefillDue = daysRemaining <= refillAlertDaysBefore   // default 3, user-configurable 1-14 (not yet exposed in Settings — Section 5.6)
isLowStock  = quantityCurrent <= lowStockThreshold     // default 5
isExpiringSoon = (expiryDate - today).days <= expiryAlertDaysBefore  // default 30, range 7-90 (not yet exposed in Settings)
```

Notification scheduling, already implemented in
`lib/services/notification_service.dart` (`NotificationService`) via
`flutter_local_notifications` + `timezone`:
- On medicine/schedule save, cancel and reschedule that medicine's notifications: one
  repeating local notification per entry in `schedule.doseTimes`, an expiry-warning
  notification fired once at (expiryDate − 30 days), and a refill notification shown
  immediately when `isRefillDue` is true at save time.
- "Mark as Taken" (from the home screen card): `MedicineService.updateDoseStatus` inserts
  a `doseLogs` doc with status `taken` and atomically decrements `quantityCurrent` by
  `doseAmount` via `FieldValue.increment`.
- "Skip": inserts a `doseLogs` doc with status `skipped`, does not decrement quantity.
- "Missed" detection (MVP approach — simplest thing that works, revisit only if it proves
  unreliable in practice): `MedicineService.checkAndMarkMissedDoses()` runs on app open,
  scans for `doseLogs` docs with status `pending` and `scheduledAt` more than 2 hours in
  the past, marks them `missed`. Do not build a background-only solution
  (WorkManager-style periodic reconciliation) until this simpler approach proves
  insufficient — it adds real complexity for a marginal reliability gain at this stage.
- Snooze presets and configurable refill/expiry thresholds are Section 5.6 (Settings)
  work, not yet built — the values above are currently hardcoded defaults.

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
- Seed the top-level `medicineReference` Firestore collection (Section 3) from that
  existing dataset via a one-time authenticated seed script (Firebase Admin SDK,
  Node.js or Python — run once, not part of the app), `source: "medex_seed_2026"`,
  `lastUpdated` set at import time.
- `firestore.rules` should give the client read-only access to `medicineReference` and
  deny client writes entirely; only the seed script (using admin credentials, which
  bypass rules) or a future Cloud Function may write to it.
- Search screen: user types a brand or generic name → results show brand, manufacturer,
  strength, unit price (৳) → below that, "Other brands with the same generic" sorted
  ascending by price, so the user can spot a cheaper equivalent.
- Prices are reference/last-known values, not live — show `lastUpdated` on every result
  so the user knows how stale it is; do not imply real-time accuracy.
- True cross-pharmacy live comparison is a Phase 3+ idea (would need crowdsourced shelf
  prices from users, with moderation) — flagged, not built now.

#### 5.4.1 Execution Strategy
Ordered steps to take this from "planned" to shipped:
1. **Source the dataset.** Default to the static Kaggle "All Medicine Data of Bangladesh"
   snapshot (~25k rows) rather than running `bd-medicine-scraper` yourself for v1 — it
   sidesteps the medex.com.bd terms-of-service/robots.txt question entirely (Section 7
   still flags that check as required before anyone automates scraping in production).
2. **Normalize and seed.** Write a one-off Node.js or Python script (Firebase Admin SDK,
   run locally — not part of the app or CI) that maps the raw dataset into the
   `medicineReference` shape from Section 3, setting `source: "medex_seed_2026"` and
   `lastUpdated` at import time.
3. **Lock down access in the same change.** Add a `firestore.rules` entry giving
   authenticated clients read-only access to `medicineReference` and denying all client
   writes (the seed script's admin credentials bypass rules, so this doesn't block it).
4. **Build the search screen.** Firestore has no full-text search — a pragmatic v1 is a
   prefix-range query (`>=`/`<`) against a lowercased `searchName` field populated at
   seed time, not a substring search. Revisit a dedicated search service (Algolia,
   Typesense) only if that proves too limited in practice, not up front.
5. **Surface staleness honestly.** Show `lastUpdated` and the "reference price, not live"
   disclaimer from this section on every result, per the existing rule above.
6. **Keep refreshes manual for now.** Re-run the seed script by hand when a newer dataset
   snapshot is worth importing; don't build a scheduled pipeline until there's a concrete
   reason to (Section 7 has the open question if that changes).

### 5.5 Nearby Pharmacy
- Client calls a Cloud Function for Firebase (e.g. `nearbyPharmacies`, Node.js/TypeScript
  via `firebase-functions` + `firebase-admin`) with the device's lat/lng (from
  `geolocator`) → the function proxies Google Places API (Nearby Search, New) with
  `type=pharmacy`, keeping the Google API key server-side → returns name, address,
  distance, rating, open-now status. Call it via `dio` or `cloud_functions`
  (`FirebaseFunctions.instance.httpsCallable(...)`) — prefer `cloud_functions` since it
  already carries Firebase Auth context automatically.
- `google_maps_flutter` renders markers + user location; toggle to a plain list view
  sorted by distance.
- Google Places coverage can thin out outside Dhaka/major cities — if a search returns
  under ~3 results, that's worth surfacing to the user honestly ("few results found near
  you") rather than silently showing an empty map.

### 5.6 Settings / Family Profiles (Phase 2)
- Language toggle (English/Bangla) via `easy_localization` — this is why Section 2
  requires every string to be centralized/translation-ready from day one.
- Notification threshold sliders (refill days, expiry days, snooze presets) — the
  toggles for dose/expiry/low-stock alerts already exist on `users/{uid}` (Section 3);
  add the numeric thresholds either as more fields on that same profile doc (if they
  should sync across the user's devices) or `shared_preferences` (if purely local is
  acceptable) — prefer the profile doc, it's already the pattern in use.
- Family members: the lightweight `users/{uid}/familyMembers` subcollection from Section
  3 (display name only, no relationship label required) that medicines can optionally be
  tagged with, so one account can track a parent's and a child's medicines separately on
  the same home dashboard (filter chips).

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

### 5.8 Already shipped beyond the original MVP scope
These exist in the codebase today, aren't described elsewhere in this spec, and should
be kept working while the rest of this document's plan is executed:
- **Auth flows** (`welcome_screen.dart`, `login_screen.dart`, `signup_screen.dart`,
  `auth_service.dart`) — anonymous, email/password, and Google Sign-In, gating entry via
  `MainNavigationShell` vs. `WelcomeScreen` in `main.dart`'s `authStateChanges()` stream.
  This is broader than the original "stay local until opt-in" idea — see Section 7 for
  the open question about whether that's the intended product direction.
- **AI Assistant** (`ai_assistant_screen.dart`, `gemini_ai_service.dart`) — a
  general-purpose Gemini chat that can also parse structured `ADD_MEDICINE` /
  `ADD_BUY_ITEM` actions out of free-text replies. This is a different, complementary
  feature from Section 5.2's structured prescription pipeline — both stay.
- **Buy List** (`buy_list_screen.dart`, `buy_list_service.dart`, `buy_list_item.dart`) —
  a restock list, optionally linked to an existing `medicineId`.
- **Prescription Vault** (`prescription_vault_screen.dart`, `prescription_service.dart`)
  — the storage/browsing half of prescriptions (upload a photo, keep notes). Section 5.2
  is the OCR/extraction half that turns a vault entry into structured, actionable data.
- **Calendar & Routine** (`calendar_routine_screen.dart`) — a calendar view over
  `doseLogs`, an early version of the "dose-adherence history/calendar view" originally
  scoped for Phase 3 (Section 6).
- **BD Apps SMS integration** (`lib/features/bdapps/`, `backend/*.php`) — a Bangladeshi
  telco SMS subscription/OTP integration. Intentionally NOT part of the Firebase stack;
  treat it as a separate bounded context and don't try to fold it into
  Firestore/Cloud Functions.

### 5.9 Manual Add Medicine — Voice Input & AI-Assisted Entry

**Goal:** make `AddEditMedicineScreen` faster to fill by hand, using two mechanisms that
complement Section 5.1's camera OCR rather than replacing it: spoken dictation into
individual fields, and a "describe it, I'll fill the form" AI shortcut built on the
Gemini structured-action support that already exists (Section 5.8's AI Assistant).

**Voice dictation:**
- Use `speech_to_text` (wraps the OS/Google on-device speech engine) — no new cloud
  dependency, consistent with Section 2's on-device-first stance for anything that has an
  on-device option.
- Add a reusable mic-button affordance next to the name/strength/instructions-style text
  fields rather than one bespoke implementation per field.
- Handle microphone-permission denial gracefully: fall back to normal typing, never block
  the form or crash.
- Bangla dictation quality depends entirely on the device's installed OS speech-recognition
  language pack, which MediTrack doesn't control — confirm in Section 7 whether English-only
  dictation is acceptable for v1 or whether Bangla support is a launch requirement.

**AI-assisted fill:**
- Add a "Describe with AI" entry point on the manual-entry screen accepting typed or
  dictated free text (e.g. "Napa 500mg, one tablet twice a day for a week"), sends it
  through Gemini, and reuses the *existing* `ADD_MEDICINE` JSON action contract and parser
  in `GeminiAiService` (Section 5.8) rather than inventing a second schema.
- Apply results the same non-destructive way as `_applyOcrResult` (Section 5.1): only
  fill fields that are currently empty, never overwrite what the user already typed, and
  never call `saveMedicine` directly — the user still reviews and taps Save.
- Validate the parsed JSON (missing name, non-positive stock, etc.) with the same rules
  Section 5.11 defines for chat actions — share one validator, don't fork it.

**Execution steps:**
1. Add the `speech_to_text` dependency and a small reusable voice-input widget/controller.
2. Wire microphone permission requests with a graceful typing fallback.
3. Add the "Describe with AI" text/voice entry point to `AddEditMedicineScreen`, calling a
   thin wrapper around the existing `GeminiAiService` action-parsing logic.
4. Add the shared action validator from Section 5.11 and apply it here too.
5. Unit-test the JSON-action-to-form-field mapping as a pure function.
6. Manual QA on a real Android device — microphone permission flows are unreliable on
   emulators.

### 5.10 BD Apps Subscription & Paywall Strategy

The BD Apps subscription rail connects carrier billing (Robi / Airtel) to premium feature entitlements.
MediTrack operates a hybrid model: core tracking is free forever, while external API cost centers
are gated behind an active ৳2.78/day (+VAT+SD+SC) micro-subscription.

**Implemented Gatekeeping (Option A - Active):**
- **Free Tier (Free forever, offline-first):**
  - Medicine management, pill schedule tracking, local notifications.
  - On-device box/strip OCR (ML Kit text recognition).
  - Digital Prescription Vault (photo storage & retrieval).
  - Low-stock Buy List.
- **Premium Tier (৳2.78/day via Robi 018 / Airtel 016 carrier billing):**
  1. **Prescription AI OCR:** Multi-page structured Gemini 2.5 Flash dosage extraction.
  2. **AI Health Assistant:** Multimodal Gemini conversation & prescription analysis.
  3. **Medicine Price & Generic Lookup:** Bangladesh reference database search & cheap alternatives.
  4. **Nearby Pharmacies:** Live GPS & Google Places locator with call / directions shortcuts.

**Architecture & Implementation:**
- `EntitlementGuard` & `EntitlementService`: Check cached entitlement state (`subscriptionStatus` on `users/{uid}/profile/main`), enforce a 5-minute cache freshness window, query BD Apps carrier servers on stale/foreground resume, and guard against non-registered accounts.
- `SubscriptionOfferScreen`: Commercial subscription UI showing carrier badges, clear pricing disclosure, legal consent checkboxes, terms / privacy dialogs, auto-renewal rules, and polling activation state machine.
- `backend/subscribe.php`: Server-side endpoint executing direct carrier billing subscription requests.
- Gated entry points: `AiAssistantScreen`, `ScanPrescriptionScreen`, `MedicineSearchScreen`, and `NearbyPharmaciesScreen` invoke `requirePremium()` before executing billable operations.
- SMS reminder channels (paid SMS generation/delivery) remain planned future work.

### 5.11 AI Assistant Roadmap

**Current state:** three Gemini entry points exist with overlapping, not-fully-settled
responsibilities — `GeminiAiService` (general chat + `ADD_MEDICINE`/`ADD_BUY_ITEM`
structured actions, Section 5.8), `AIPrescriptionService` (a free-text prescription/label
analyzer used by the AI Assistant screen), and Section 5.2's planned
`PrescriptionExtractionService` (structured, schema-enforced prescription extraction).
There is currently no usage limiting, no shared action-JSON validation, and no persistent
in-UI safety disclaimer beyond whatever text the model happens to include in a reply.

**Roadmap:**
- **Settle ownership once Section 5.2 ships:** `PrescriptionExtractionService` owns
  structured prescription-photo-to-JSON extraction; `GeminiAiService` owns free-form chat
  and quick structured actions. Retire or fold `AIPrescriptionService` into one of those
  two once 5.2 lands — it currently has no clear reason to exist alongside both.
- **Cost control:** tie chat/image messages into Section 5.10's entitlement gate, and add
  a soft per-day message cap even for entitled users (tracked on `users/{uid}` or a small
  `aiUsage` subcollection, reset daily/monthly) so a runaway client bug or loop can't burn
  through the Firebase AI Logic quota unbounded.
- **Safety:** add a persistent disclaimer banner on the chat screen itself ("not a
  substitute for professional medical advice") rather than relying on the model to
  include it in every reply, which isn't guaranteed.
- **Harden structured actions:** validate `ADD_MEDICINE`/`ADD_BUY_ITEM` JSON before ever
  offering it to the user (missing name, non-positive stock/quantity, etc.) using the same
  shared validator introduced for Section 5.9, instead of trusting the model's JSON
  verbatim. The existing "user must confirm before it's saved" behavior stays as-is.
- **Observability:** log call latency and success/failure counts without message content,
  mirroring Section 5.2.5's approach, so quality regressions are visible.

**Execution steps:**
1. Add `lib/logic/ai_action_validator.dart`, shared by chat actions now and prescription
   items later where the rules overlap (e.g. positive integer quantities).
2. Add the Section 5.10 entitlement check at the point a chat message/image is sent.
3. Add the persistent chat-screen disclaimer banner.
4. Implement the free-tier soft message cap once Section 7 sets the actual numbers.
5. After Section 5.2 ships, revisit whether `AIPrescriptionService` should be deleted.

### 5.12 Authentication Hardening — Retiring Silent Anonymous Sign-In

Email/password and Google sign-in already exist (`AuthService`, `LoginScreen`,
`SignUpScreen`, Section 5.8) — the actual problem is that **five services silently create
an anonymous account whenever no user is signed in**, regardless of how the user reached
that screen: `MedicineService`, `PrescriptionService`, `UserProfileService`,
`BuyListService`, and `GeminiAiService` each independently call `signInAnonymously()` as
a fallback inside their own `_ensureAuthenticated()`-style helper. `WelcomeScreen`'s
explicit "Continue as Guest" button calling the same method is fine and intentional; the
services doing it invisibly, on top of that, is the "invisible anonymous auth" this item
is about.

**Design:**
- Remove the silent fallback from all five services. Each should surface a typed
  "not authenticated" result/error instead of calling `signInAnonymously()` itself.
- Screens that call these services catch that error and route to `WelcomeScreen` (or show
  a "please sign in" prompt) rather than silently proceeding on a freshly-minted throwaway
  account the user never chose.
- Keep "Continue as Guest" as an explicit, user-chosen option on `WelcomeScreen` — removing
  guest access entirely adds signup friction before a user has seen any value; Section 7
  records the final call on whether to keep it.
- Add an upgrade path: an anonymous user should be able to link an email/password or
  Google credential to their existing anonymous `uid` (`currentUser.linkWithCredential`)
  so guest data survives becoming a "real" account — this also matters for Section 5.10,
  since a durable identity is what a paid subscription attaches to.
- Add a visible "Guest Mode" notice (Profile Settings is a natural place) warning that
  data is tied to this device/install and won't survive a reinstall unless the user
  creates a real account — anonymous Firebase users have no recovery path today.

**Execution steps:**
1. Audit and remove every `signInAnonymously()` fallback in `MedicineService`,
   `PrescriptionService`, `UserProfileService`, `BuyListService`, and `GeminiAiService`.
2. Update each call site to handle the resulting "not authenticated" state by routing to
   `WelcomeScreen`/`LoginScreen`.
3. Add `AuthService.linkAnonymousWithEmail` / `linkAnonymousWithGoogle`, surfaced from
   Profile Settings only when the current user is anonymous.
4. Add the Guest Mode data-loss notice.
5. Re-verify `firestore.rules`/`storage.rules` still scope correctly regardless of account
   type (expected to already be correct, since rules key off `request.auth.uid`, not
   whether the account is anonymous — confirm, don't assume).

### 5.13 Notification Reliability Audit

This is a verification/hardening pass on the already-implemented Section 5.3 system, not
a rebuild. Checklist:
- **Exact-alarm fallback:** `NotificationService` already requests
  `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` and falls back to `inexactAllowWhileIdle` on
  failure — verify that fallback actually fires correctly on a device where the
  permission is denied, not just that the code path exists.
- **OEM battery-optimization killing the app:** a very common real-world failure on
  Xiaomi/Oppo/Vivo/Samsung builds common in Bangladesh, where reminders silently stop
  firing regardless of correct scheduling code. Add a one-time "disable battery
  optimization for MediTrack" explainer during onboarding or in Settings.
- **Notification channels are effectively frozen once shipped:** Android doesn't let an
  app change an existing channel's importance/sound after creation — changing behavior
  requires a new channel ID, orphaning the old one on users' devices. Treat
  `dose_reminders` / `expiry_alerts` / `refill_alerts` as final; don't edit their settings
  in place later.
- **Refill notifications go stale between edits:** today a refill notification is only
  (re)computed when the medicine is saved/edited (Section 5.3) — verify whether
  `MedicineService.updateDoseStatus`'s "taken" path (which decrements `quantityCurrent`)
  also re-triggers the refill check. If not, a medicine can cross the refill threshold
  purely through normal "Mark as Taken" use without ever notifying the user.
- **Timezone changes while backgrounded:** `flutter_timezone` reads the device zone once
  at `NotificationService.init()`; a mid-trip timezone change won't reschedule already-set
  notifications until the next explicit reschedule. Minor for a Bangladesh-only app (no
  DST), but worth a documented, accepted limitation rather than a silent gap.
- **Missed-dose detection depends on reopening the app** (Section 5.3's stated approach)
  — audit in practice whether this produces acceptable adherence data, or whether it's
  frequently stale because users go days without opening the app.
- **Notification tap does nothing useful today:** `onDidReceiveNotificationResponse` is a
  no-op placeholder — tapping a dose/refill/expiry notification just opens the app to its
  default screen instead of deep-linking to the relevant medicine or offering a quick
  "Mark as Taken" action.

**Execution steps:**
1. Run a manual device-matrix test (at minimum one OEM known for aggressive battery
   management) covering all three notification types across app-killed, backgrounded, and
   foregrounded states.
2. Wire the "taken" path in `MedicineService.updateDoseStatus` to re-run the refill check
   and fire/reschedule a refill notification if the medicine just crossed the threshold.
3. Implement `onDidReceiveNotificationResponse` to deep-link into the relevant medicine's
   detail screen, and add a "Mark as Taken" notification action button for dose reminders.
4. Add the battery-optimization guidance prompt.
5. Document the channel-ID-is-frozen rule here and in `AGENTS.md` so it isn't
   accidentally violated later.

### 5.14 UI/UX Improvement Pass

"UI improvement" is inherently a look-and-decide task, not something to fully pre-specify
in text — this section defines the audit checklist and quality bar; the actual visual
decisions belong in a short, focused pass per screen (a good candidate for the
brainstorming workflow's visual-companion mode) rather than being locked in here.

**Audit checklist:**
- **Design-token drift:** check every screen in Section 4's screen list / Section 5.8's
  shipped list against Section 4's spacing scale, radius scale, shadow style, and color
  usage — screens built incrementally over time commonly drift from the tokens they
  started from.
- **Empty states:** Section 4 requires illustrated empty states, never bare "No data"
  text — audit whether Buy List, Prescription Vault, Calendar & Routine, and the AI
  Assistant's empty chat state actually meet that bar today.
- **Accessibility basics:** verify Android system font-scaling doesn't break layouts,
  verify tap targets meet the 48dp minimum, and verify `textSecondary`-on-`background`/
  `surface` contrast meets WCAG AA — none of this has been explicitly checked yet.
- **Loading/error state consistency:** the app currently mixes ad-hoc
  `CircularProgressIndicator` sizes/placements per screen rather than one shared pattern.
  Extract a shared `AppLoadingIndicator`/`AppErrorState` widget so this is fixed once, not
  per screen.

---

## 6. Build Phasing

**Phase 1 (MVP) — mostly shipped:** auth/entry (welcome screen + anonymous/email/Google
sign-in), home dashboard, manual add/edit/delete medicine, Section 5.1 camera OCR,
Section 5.3 reminder engine. Remaining Phase 1 housekeeping: Section 5.13's notification
audit (verifying the shipped reminder engine actually behaves correctly in the field) and
Section 5.12's auth hardening (removing the silent anonymous-sign-in fallback) — both are
fixes to already-shipped Phase 1 work, not new features, and should land before more
features are stacked on top of them.

**Phase 2 — in progress / current priorities, roughly in this order:**
1. Section 5.2 prescription OCR — a working prototype exists today but not yet the
   structured, reviewable, confidence-scored pipeline this spec targets; 5.2.8's
   Execution Strategy is the concrete plan.
2. Section 5.12 auth hardening — do this before Section 5.10's paywall work, since a
   subscription needs a durable, intentionally-created identity to attach to.
3. Section 5.10 BD Apps subscription/paywall wiring — connect the already-built billing
   rail to an actual entitlement, once Section 7 confirms the gated feature list.
4. Section 5.11 AI Assistant roadmap — consolidate the AI surfaces and add cost/safety
   controls, informed by Section 5.10's entitlement gate.
5. Section 5.9 manual-entry voice input + AI-assisted fill.
6. Section 5.4 price/generic lookup (5.4.1's Execution Strategy).
7. Section 5.6 (localization, family profiles, configurable thresholds) — not started.

**Phase 3:** Section 5.5 (nearby pharmacy — needs a live Google API budget + a Cloud
Function proxy), PDF export of medicine list for doctor visits, dark mode, Section 5.14's
UI/UX improvement pass. The dose-adherence calendar view originally scoped here already
has a first version shipped (Section 5.8's Calendar & Routine screen) — treat remaining
work here as polish, not a from-scratch build.

**Shipped ahead of the original plan (fold into whichever phase touches them next):** AI
health assistant chat, prescription digital vault, medicine buy/restock list, BD Apps SMS
subscription integration — see Section 5.8. These aren't replacing MVP scope, just
already-delivered extras; keep them working while executing the rest of this phasing.

**Not scheduled:** Section 5.7 items.

---

## 7. Things only you can decide/provide before an AI can actually build this

- Final app name (working title "MediTrack" used throughout this doc, and already the
  live Firebase project name, `meditrack-app-2026`).
- Confirm the Gemini Developer API / Firebase AI Logic backend is actually enabled for
  `meditrack-app-2026` (`npx firebase-tools init ailogic` — `flutterfire configure` alone
  does **not** enable it and will surface as `PERMISSION_DENIED` if skipped), and line up
  a Google Cloud project + API key for Places once Section 5.5 is scheduled.
- `storage.rules` does not exist in this repo yet (Section 5.2.6) — someone needs to
  decide/confirm the Storage bucket's current default access and get rules deployed
  before Section 5.2's execution strategy proceeds past Step 0, since prescription
  images are already being uploaded there today.
- The app currently gates entry behind a Welcome/Login screen with an anonymous option,
  rather than the originally-proposed "fully anonymous/local until opt-in" flow —
  confirm that's the intended product decision (a reasonable one, given cross-device sync
  and the AI assistant both wanting a stable `uid` from day one) rather than accidental
  scope creep. Section 5.12 answers the narrower follow-up (remove the *silent* anonymous
  fallback in services) but still needs your call on whether "Continue as Guest" stays as
  an explicit option at all.
- Where the seed medicine-price dataset (Section 5.4) actually gets hosted — a top-level
  `medicineReference` Firestore collection populated by a one-time authenticated seed
  script is the recommended default; a bundled in-app CSV is the cheaper fallback if
  nobody wants to run/maintain that script.
- **Paywall scope (Section 5.10):** which features actually get gated behind the BD Apps
  subscription. Option A there (gate only the calls that cost money — prescription OCR,
  AI assistant, price lookup, nearby pharmacy) is the recommendation, but the final list,
  the price point (configured in the BD Apps dashboard, not app code), any free trial
  length, and whether a usage-metered free tier (Option B) is wanted instead of a hard
  gate are all product calls, not technical ones.
- **Voice input language scope (Section 5.9):** whether English-only dictation is
  acceptable for v1, or whether Bangla speech-recognition support (dependent on the
  device's OS language pack, outside MediTrack's control) is a launch requirement.
- **AI usage caps (Section 5.11):** the actual free/paid message-per-day numbers for the
  soft usage cap — a placeholder "N" isn't a real limit until someone picks N.
- **Guest mode retention (Section 5.12):** confirm "Continue as Guest" should remain on
  `WelcomeScreen` as an explicit, user-chosen option once the silent fallback is removed
  from services, rather than requiring a real account from first launch.
