# MediTrack — Project Completion Roadmap

A dependency-ordered master plan for finishing MediTrack, synthesizing
`medicine-manager-spec.md` Sections 5–7 into one sequence. Each milestone lists its
spec references, exit criteria, and — called out explicitly — every point where a human
(not a coding agent) has to act: dashboards, accounts, credentials, files, money, or a
judgment call.

> Convention used throughout: a blockquote starting with **🧑 Human action needed** is
> something no agent can complete — it requires an account you own, a credential only you
> can issue, a payment method, a physical device, or a decision only you can make.

Ordering logic: fix shipped-but-fragile foundations first (M0), then build the
highest-priority unfinished feature (M1), then everything that depends on a stable
identity/billing layer (M3 before M4), then lower-priority/Phase-3 items, then release
readiness last.

---

## M0 — Security & Stability Baseline
*Spec: 5.2.6, 5.12, 5.13. Blocking — do this before new feature work.*

1. Add `storage.rules` scoping `users/{uid}/**` to the owner, reference it in
   `firebase.json`, deploy.
2. Remove the silent `signInAnonymously()` fallback from `MedicineService`,
   `PrescriptionService`, `UserProfileService`, `BuyListService`, `GeminiAiService`
   (5.12 steps 1–2).
3. Run the Section 5.13 notification audit and fix the concrete gap found (refill check
   not re-triggered by "Mark as Taken"); implement notification-tap deep linking.

**Exit criteria:** `storage.rules` deployed and verified with the Firebase emulator or
console; no service creates an anonymous account without explicit user action; dose/
refill/expiry notifications verified on a real device across app-killed/backgrounded/
foreground states.

> 🧑 **Human action needed:**
> - Firebase Console access (Storage → Rules) to confirm current default bucket access
>   before the new rules go live, and to approve the deploy.
> - Confirm the Section 7 decision: keep "Continue as Guest" as an explicit option, or
>   require a real account from first launch.
> - At least one physical Android device for the notification audit — ideally including
>   one Xiaomi/Oppo/Vivo/Samsung device, since aggressive OEM battery management is the
>   most common real-world cause of "reminders stopped working" and can't be verified in
>   an emulator or CI.

---

## M1 — Prescription OCR Production Pipeline
*Spec: 5.2.8 (already the most detailed section — this milestone just executes it).*
*Current top priority per Section 6.*

Execute Steps 0–8 exactly as written in 5.2.8: security prerequisite (covered by M0),
extraction contract with a JSON response schema, client-side validation, pre-flight
quality gate, data layer (`items` subcollection), the confidence-badged review UI,
error-handling taxonomy, observability, and a fixture-based regression pass.

**Exit criteria:** a real prescription photo produces structured, confidence-scored line
items the user reviews and confirms before anything is saved; the error taxonomy in
5.2.4 is exercised end-to-end (try an unreadable image, airplane mode, etc.).

> 🧑 **Human action needed:**
> - Confirm the Gemini Developer API / Firebase AI Logic backend is actually enabled for
>   `meditrack-app-2026` by running `npx firebase-tools init ailogic` — this is an
>   interactive CLI login against your Firebase account; an agent cannot complete Google's
>   OAuth device-login flow on your behalf.
> - Provide 4–6 sample prescription photos for the Section 5.2.7 test fixture set —
>   **synthetic/mock prescriptions only, never a real patient's**. If you don't have any,
>   say so and we'll generate synthetic mock ones instead of leaving this untested.
> - For production-grade App Check (Play Integrity, not the debug provider): the app
>   needs to exist in Google Play Console with its release signing certificate's SHA-256
>   registered — this requires your Play Console account (see M10).

---

## M2 — Medicine Price & Generic Lookup
*Spec: 5.4, 5.4.1.*

1. Source and normalize the medicine-price dataset into the `medicineReference` shape.
2. Add the `firestore.rules` entry for read-only client access.
3. Build the search screen (prefix-range query on a `searchName` field).
4. Surface `lastUpdated` + the "reference price, not live" disclaimer.

**Exit criteria:** searching a brand or generic name returns priced results with a
visible last-updated date; `medicineReference` is confirmed read-only from the client.

> 🧑 **Human action needed:**
> - **Provide the dataset file.** The recommended source is the Kaggle "All Medicine
>   Data of Bangladesh" CSV (~25k rows). Kaggle requires an authenticated account/API
>   token to download, and an agent's sandboxed environment can't do that without you
>   granting network access and credentials — the simplest path is: you download it once
>   and hand me the CSV file directly.
> - **Provide a Firebase Admin SDK service account key** (JSON) so the one-off seed
>   script can write to Firestore with admin credentials. Generate this from Firebase
>   Console → Project Settings → Service Accounts → "Generate new private key." Treat
>   this file as a secret — never commit it to git; share it only long enough to run the
>   import, then revoke/rotate it if it was shared insecurely.
> - **Legal/ToS judgment call:** if you ever want to scrape medex.com.bd yourself instead
>   of using the static Kaggle snapshot, someone needs to actually read medex.com.bd's
>   current terms of service/robots.txt and decide it's acceptable — this is a human
>   judgment call the spec deliberately doesn't make for you.

---

## M3 — Authentication Hardening Completion
*Spec: 5.12 steps 3–5 (steps 1–2 done in M0).*

1. Add `AuthService.linkAnonymousWithEmail` / `linkAnonymousWithGoogle`.
2. Add the "Guest Mode — data may not survive a reinstall" notice in Profile Settings.
3. Re-verify `firestore.rules`/`storage.rules` behave identically for anonymous vs. real
   accounts.

**Exit criteria:** a guest user can upgrade to a real account without losing data; the
guest-mode data-loss risk is visibly disclosed.

> 🧑 **Human action needed:**
> - Google Sign-In in a **release** build needs your release keystore's SHA-1/SHA-256
>   fingerprint registered in the Firebase Console (Project Settings → Your apps →
>   Android app). If you haven't finalized/uploaded a release keystore yet, this blocks
>   final verification of Google Sign-In in release mode (see M10 for keystore setup).

---

## M4 — BD Apps Subscription → Paywall/Entitlement Wiring
*Spec: 5.10. Sequenced after M3 because a subscription needs a durable identity to
attach to.*

1. Decide the gated feature list, price point, and any free trial (Section 7) —
   **recommended default: gate prescription OCR, AI Assistant, price lookup, and nearby
   pharmacy; keep manual tracking, reminders, box OCR, buy list, and vault free.**
2. Add `EntitlementService` (cached/refreshed `subscriptionStatus` on `users/{uid}`).
3. Add the reusable `requirePremium()` gate and wire it at the decided call sites.
4. Add "Manage Subscription" to Profile Settings, reusing the existing OTP flow.

**Exit criteria:** an unsubscribed user is prompted to subscribe via BD Apps at each
gated feature's entry point; a subscribed user passes through; a lapsed subscription
degrades to read-only access, never data loss.

> 🧑 **Human action needed:**
> - **This is fundamentally a pricing/product decision, not a technical one** — confirm
>   the gated feature list and the actual price (configured in the BD Apps dashboard, not
>   app code), and whether there's a free trial or usage-metered free tier instead of a
>   hard gate.
> - **Rotate `APP_ID`/`APP_PASSWORD`** in `backend/config.php` before any of this goes
>   live for real users — the backend README already flags these as placeholder/dev
>   credentials. New production credentials come from the BD Apps developer dashboard
>   (developer.bdapps.com), which only your registered developer account can access.
> - **Confirm the production hosting** for `backend/*.php` (currently pointed at
>   `bdappsdigitalapps.com/NADB26067/`) — if that's not your final host, you'll need to
>   provide new hosting credentials and update `ApiConfig.bdappsBaseUrl`.
> - **BD Apps dashboard configuration**: register the deployed SMS/USSD callback URLs in
>   the BD Apps developer dashboard — this is a manual dashboard step only the account
>   owner can do.
> - BD Apps (and the underlying telco) typically require their own review/approval
>   before a subscription product goes live for real billing — budget time for that
>   external approval, it isn't something we control.

---

## M5 — AI Assistant Roadmap Hardening
*Spec: 5.11.*

1. Consolidate AI service ownership (retire/fold `AIPrescriptionService` once M1 ships).
2. Add the shared `lib/logic/ai_action_validator.dart`.
3. Wire the M4 entitlement gate onto chat/image messages.
4. Add the persistent in-chat safety disclaimer.
5. Implement the soft per-day usage cap.

**Exit criteria:** one clearly-owned service per AI concern; structured actions are
validated before being offered to the user; usage is capped and logged (without message
content) for quality tracking.

> 🧑 **Human action needed:**
> - Provide the actual free/paid message-per-day numbers for the usage cap — pick a
>   number, or approve the recommendation once we propose one based on expected Gemini
>   cost per call.

---

## M6 — Manual Add Medicine: Voice + AI-Assisted Entry
*Spec: 5.9.*

1. Add `speech_to_text`, a reusable mic-input widget, and permission handling.
2. Add the "Describe with AI" entry point reusing the existing `ADD_MEDICINE` action
   parser and the M5 validator.

**Exit criteria:** a user can dictate or type a free-text description and have the form
pre-filled (never auto-saved); denying microphone permission degrades to normal typing
without crashing.

> 🧑 **Human action needed:**
> - Confirm whether English-only dictation is acceptable for v1, or whether Bangla
>   speech recognition is a launch requirement — Bangla quality depends entirely on the
>   device's installed OS language pack, which we don't control, so this is worth
>   deciding (and testing on a real Bangla-configured device) before promising it.
> - Adding the microphone permission changes what the Play Store's **Data Safety** form
>   must disclose — a small but real task for whoever manages the Play Console listing
>   (see M10) when this ships.

---

## M7 — Settings, Localization, Family Profiles
*Spec: 5.6.*

1. Wire `easy_localization`, extract strings, add the language toggle.
2. Add numeric notification thresholds to the `users/{uid}` profile doc.
3. Add the `familyMembers` subcollection + filter chips on the dashboard.

**Exit criteria:** the app is fully usable in both English and Bangla; refill/expiry
thresholds and snooze presets are user-configurable; medicines can be tagged to a family
member and filtered.

> 🧑 **Human action needed:**
> - **Bangla translation review.** An agent can produce a first-pass machine translation
>   of every extracted string, but for a health app, mistranslated dosage/instruction
>   text is a real safety risk — a native Bangla speaker should review the translations
>   before release, not just the agent's draft.

---

## M8 — Nearby Pharmacy
*Spec: 5.5. Explicitly Phase 3 — needs a live Google API budget.*

1. Write the `nearbyPharmacies` Cloud Function proxying Google Places (Nearby Search).
2. Build the map/list toggle UI with `google_maps_flutter` + `geolocator`.

**Exit criteria:** searching near the device's location returns real pharmacy results
with the "few results found" honesty fallback outside major cities.

> 🧑 **Human action needed:**
> - **Create/confirm a Google Cloud project, enable the Places API (New), attach a
>   billing account (a credit card on file), and generate an API key restricted to that
>   Cloud Function** — none of this is possible without your Google Cloud Console access.
> - **Upgrade the Firebase project to the Blaze (pay-as-you-go) plan.** Cloud Functions
>   for Firebase (2nd gen) require Blaze even for light usage — this is separate from
>   Firebase AI Logic, which already works on the free Spark plan via the Gemini
>   Developer API backend.
> - Set a budget alert in Google Cloud Console so an unexpected traffic spike doesn't
>   produce a surprise bill — worth doing at the same time as enabling billing.

---

## M9 — UI/UX Improvement Pass
*Spec: 5.14.*

Run the audit checklist (design-token drift, empty states, accessibility, loading/error
consistency), then do a focused visual pass per screen — a good candidate for the
brainstorming workflow's visual-companion mode rather than pre-deciding pixels in text.

**Exit criteria:** every shipped screen matches Section 4's design tokens; every empty
state is illustrated, not bare text; tap targets and contrast pass a basic accessibility
check.

> 🧑 **Human action needed:**
> - Provide (or approve generating placeholder) illustration assets for empty states —
>   if you want a specific licensed illustration pack (Storyset, unDraw, etc.), you'll
>   need to pick/purchase it; licensing terms (attribution requirements) are a judgment
>   call only you can make for a commercial app.
> - A quick visual sign-off per screen once mockups/comparisons are presented.

---

## M10 — Release Readiness
*Cuts across everything above — do this in parallel with the later milestones, not only
at the very end, since some of it (keystore, Play Console account) has lead time.*

1. Confirm/finalize app name, package id, and app icon.
2. Prepare a Privacy Policy covering health data, camera/microphone, location, and SMS
   subscription billing.
3. Complete the Play Store "Data Safety" declaration accurately as features ship.
4. Prepare store listing assets (screenshots, feature graphic, description).
5. Final `flutter analyze` + full test pass + a release build smoke test.

> 🧑 **Human action needed — this milestone is almost entirely human tasks:**
> - **A Google Play Console developer account** (one-time registration fee, ~$25 USD),
>   owned and paid for by you.
> - **A release signing keystore.** Either generate one yourself and keep it safe, or opt
>   into Google Play App Signing — either way this is a credential-management decision
>   only the account owner should make (losing it can permanently block future updates).
> - **A hosted Privacy Policy URL.** For a health-data app already handling prescriptions,
>   AI chat, location, and carrier billing, this should be reviewed by a lawyer or at
>   minimum a careful human read-through before publishing — not just AI-drafted text.
> - **Upgrade Firebase to Blaze** if not already done for M8 — required before Cloud
>   Functions can be deployed at all, regardless of expected usage volume.
> - **Bangladesh-specific compliance check**: if there are local regulations around
>   storing health/medical data or SMS-based billing consent, that's a legal
>   due-diligence item for you (and ideally counsel), not something an agent can certify.
> - Final go/no-go approval to publish.

---

## Consolidated "things only you can provide" checklist

A flat list of every credential, account, file, or decision referenced above, for quick
reference when starting a session:

- [ ] Firebase Console access (already have this — used for `init ailogic`, service
      account keys, Blaze upgrade, Storage rules review)
- [ ] Firebase Admin SDK service account key (for the M2 seed script — handle as a secret)
- [ ] Kaggle medicine-price dataset file (or explicit approval to source it differently)
- [ ] Decision: keep vs. remove "Continue as Guest" (M0/M3)
- [ ] Decision: paywall gated-feature list + price + trial length (M4)
- [ ] BD Apps production `APP_ID`/`APP_PASSWORD` + dashboard callback URL registration (M4)
- [ ] Production hosting confirmation for `backend/*.php` (M4)
- [ ] Decision: AI usage cap numbers (M5)
- [ ] Decision: voice-input language scope, English-only vs. Bangla (M6)
- [ ] Native Bangla speaker for translation review (M7)
- [ ] Google Cloud project + billing + Places API key (M8)
- [ ] Firebase Blaze plan upgrade (M8, M10)
- [ ] Illustration/empty-state asset decision or approval to generate placeholders (M9)
- [ ] Google Play Console developer account (M10)
- [ ] Release signing keystore decision (M10)
- [ ] Hosted, human-reviewed Privacy Policy (M10)
- [ ] Bangladesh health-data/SMS-billing compliance check (M10)
- [ ] At least one physical Android device, ideally a battery-aggressive OEM
      (Xiaomi/Oppo/Vivo/Samsung), for notification testing (M0)
- [ ] 4–6 synthetic/mock prescription photos for OCR test fixtures (M1)
