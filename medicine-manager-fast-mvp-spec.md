# MediTrack — Fast-Ship MVP Spec (Firebase edition)

This supersedes the earlier full spec for right now. Everything cut here isn't gone —
it's your v2 backlog, still documented in `medicine-manager-spec.md`. This version
optimizes for one thing: **shipping to the Play Store on a tight deadline** with a
genuinely useful app, not a maximal one.

## 0. Two tiers — build Tier 1 first, stop and ship if you must

**Tier 1 — the whole app, if nothing else gets built:**
- Add/edit/delete a medicine (name, strength, quantity, expiry, dose schedule) — manual entry
- Home screen: today's doses (tap to mark taken), low-stock list, expiring-soon list
- Local notifications: dose reminders, refill alert, expiry alert
- Firebase (invisible anonymous auth + Firestore as the only data store)

This alone is a complete, shippable, genuinely useful medicine reminder app.

**Tier 2 — add only if Tier 1 is done with time to spare (each is independent, skip any):**
- Camera + on-device OCR to prefill the add-medicine form from a box/strip photo
- Attach a photo to a medicine record (Firebase Storage)
- Settings screen: reminder time offsets, dark mode

**Cut entirely for this pass** (real time/complexity sinks, not worth it on a tight
deadline — see the full spec for how to build them properly later):
- Prescription OCR — needs a cloud vision LLM + a backend function
- Price / generic-alternative lookup — needs a seeded reference dataset you don't have yet
- Nearby pharmacy — needs Google Maps SDK + Places API billing setup
- Multi-user/family profiles, Bangla localization

---

## 1. Stack (deliberately minimal — 🤖 paste into `AGENTS.md`)

```
PROJECT: MediTrack — lean Flutter medicine reminder app for Android. Tight deadline —
ship Tier 1 completely before touching anything in Tier 2. Do not add any library not
listed below without a very good reason.

STACK:
- Flutter 3.44 stable, Dart 3.6+, null safety
- State management: NONE. No Provider/Riverpod/Bloc — one more dependency and one more
  way to get stuck is not worth it for ~4 screens. Use StreamBuilder directly on
  Firestore streams inside each screen, plus a single plain class
  `services/medicine_service.dart` with the CRUD + query methods every screen calls.
- Backend: Firebase only.
  - firebase_auth — anonymous sign-in, called once on app start, no login screen, no UI.
  - cloud_firestore — the only data store. Its offline cache is on by default in the
    Flutter SDK, so the app keeps working without a connection with zero extra code.
    Do not add a local SQL database on top of this.
  - firebase_storage — medicine photos only (Tier 2).
- Navigation: MaterialApp named routes + Navigator.pushNamed/pop. No router package.
- OCR (Tier 2): google_mlkit_text_recognition — on-device, offline, no backend call.
- Notifications: flutter_local_notifications + timezone.
- Image capture: image_picker (covers both camera and gallery — skip the separate
  `camera` package, it isn't needed here).
- Fonts: google_fonts (Poppins for headings, Inter for body).

CODING CONVENTIONS:
- snake_case.dart filenames.
- flutter analyze clean before calling a task done.
- Every Firestore read goes through `medicine_service.dart`, never inline in a widget —
  keeps it easy to change later without hunting through every screen.
- Currency ৳, dates via `intl` — same as before, small thing but avoid manual string
  formatting bugs.

DO NOT (for this pass):
- Add a state management package
- Add a local database
- Build a login/signup screen
- Build prescription OCR, price lookup, or nearby pharmacy
```

---

## 2. Data model (Firestore — much simpler than a relational schema)

```
/users/{uid}/medicines/{medicineId}
  name: string
  genericName: string?
  dosageForm: string?          // tablet | syrup | injection | drops | other
  strength: string?             // "500 mg"
  quantityCurrent: number
  quantityTotal: number
  expiryDate: Timestamp?
  batchNumber: string?
  manufacturer: string?
  imageUrl: string?             // Tier 2, Firebase Storage download URL
  lowStockThreshold: number     // default 5
  schedule: {
    doseAmount: number
    timesPerDay: number
    doseTimes: [string]         // ["08:00","20:00"]
    daysOfWeek: [number]        // [1..7], default all
    startDate: Timestamp
    endDate: Timestamp?         // null = ongoing
    active: boolean
  }
  createdAt: Timestamp
  updatedAt: Timestamp

/users/{uid}/doseLogs/{logId}
  medicineId: string
  medicineName: string          // denormalized so the home screen needs one query, not a join
  scheduledAt: Timestamp
  status: string                 // "pending" | "taken" | "skipped" | "missed"
  respondedAt: Timestamp?
```

The schedule is embedded directly in the medicine document (not a separate collection) —
it's always a 1:1 relationship here, so a join buys you nothing and just costs an extra
query.

Security rules:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

---

## 3. Design (unchanged from before, still cheap to reuse)

```dart
const primaryGreen  = Color(0xFF47594E);
const accentPink    = Color(0xFFF4B8B0);
const accentPinkLight = Color(0xFFFBE0DC);
const background    = Color(0xFFFBF6F1);
const surface       = Color(0xFFFFFFFF);
const textPrimary   = Color(0xFF2B2B2B);
const textSecondary = Color(0xFF8C8C8C);
const success       = Color(0xFF5B8C5A);
const warning       = Color(0xFFE0A458);
const danger        = Color(0xFFD96C6C);

headings: GoogleFonts.poppins(fontWeight: FontWeight.w600)
body:     GoogleFonts.inter()
radius: cards 20dp, buttons pill-shaped
```

Skip onboarding slides for v1 — go straight to the home screen on first launch (an empty
state with a friendly illustration and an "Add your first medicine" prompt does the same
job with zero extra screens to build).

## 4. Screens (Tier 1 = 3 screens total)

1. **Home** — StreamBuilder on `medicines` + today's `doseLogs`. Three sections:
   Today's Doses (tap a card to mark taken → writes a `doseLogs` entry + decrements
   `quantityCurrent`), Low Stock, Expiring Soon. FAB → Add Medicine. Empty state if no
   medicines yet.
2. **Add/Edit Medicine** — one form for every field in Section 2's `medicines` doc,
   plus the embedded schedule fields (dose times as a simple time-picker list,
   days-of-week as a row of toggle chips). Tier 2: a camera icon that runs OCR and
   prefills name/expiry/batch before the user reviews and saves — same as the full spec's
   heuristics (look for "EXP"/"MFG"/"Batch" keywords near a date pattern), still always
   editable, never auto-saved.
3. **Medicine Detail** — view/edit/delete, and a simple list of the last 7 `doseLogs`
   entries (skip a full calendar view — a plain list is enough for v1).

(Tier 2 adds a 4th screen: **Settings** — reminder offset sliders, dark mode toggle.)

## 5. Reminder logic (same formulas as before, still just a few lines)

```
dailyDoseUnits = schedule.doseAmount * schedule.timesPerDay
daysRemaining  = floor(quantityCurrent / dailyDoseUnits)

refillDue     = daysRemaining <= 3          // hardcode 3 for v1, make it a Settings slider in Tier 2
lowStock      = quantityCurrent <= lowStockThreshold   // default 5
expiringSoon  = (expiryDate - today).days <= 30        // hardcode 30 for v1
```

- On save, (re)schedule one repeating `flutter_local_notifications` entry per
  `doseTimes` value, one expiry notification, one refill notification (recomputed
  whenever `quantityCurrent` changes).
- "Mark taken": write a `doseLogs` row with status `taken`, decrement `quantityCurrent`.
- "Missed" detection: on app open, mark any `pending` doseLog more than 2 hours past its
  `scheduledAt` as `missed`. Don't build a background-service version of this for v1 —
  checking on open is enough and meaningfully less to get wrong.

## 6. Build order (7 tasks — feed one at a time)

1. Firebase project: enable Anonymous Auth, Firestore, Storage; add the security rules
   above; wire `firebase_auth` sign-in-anonymously call at app start (before anything
   else renders).
2. Theme + empty-state home screen shell.
3. Add/Edit Medicine form → Firestore CRUD via `medicine_service.dart`.
4. Home screen StreamBuilder wiring: Today's Doses / Low Stock / Expiring Soon.
5. Notification scheduling + mark-taken/skip actions (Section 5's logic, unit-test the
   pure calculator functions specifically).
6. Medicine Detail screen (view/edit/delete + last-7-days dose list).
7. *(Tier 2 only, do this last)* Camera OCR prefill, then photo upload to Storage,
   then the Settings screen.

## 7. Play Store publishing checklist — budget real time for this, it's easy to forget

Firebase Auth + Firestore + Storage means the app collects user/device data, so Play
Console will require:
- A **privacy policy URL** (even a one-page static site is fine — this is a hard
  requirement, the app can't be submitted without it)
- A completed **Data Safety form** in Play Console, declaring what's collected
  (account identifiers via anonymous auth, any photos if Tier 2 ships)
- A signed release build (keystore + `flutter build appbundle`)
- App icon + at least 2 screenshots + a content rating questionnaire
- Play Console's minimum/target Android API level requirement changes yearly — check
  the current number on the Play Console publishing page before your release build,
  rather than assuming last year's figure still holds

None of this is complex, but all of it takes calendar time (privacy policy hosting,
Play Console review turnaround) independent of how fast the code gets written — worth
starting in parallel with Task 1, not after Task 7.
