# MediTrack Completion Implementation Design

## Status

Approved design for completing the locally actionable items in `project-completion-roadmap.md` on top of the existing MVP. The current MVP architecture and design language remain the source of implementation conventions.

## Goal

Finish the roadmap's local product work through dependency-ordered, independently testable batches. The result must preserve the existing `provider` state management, Firestore service boundaries, pure Dart logic, navigation structure, sage/pink visual language, Poppins/Inter typography, and current screen composition.

This plan claims local code completeness only. Firebase, Google Cloud, BD Apps, Play Console, production signing, billing, translation review, release deployment, and physical-device verification remain explicit external handoffs.

## Product decisions

- The app requires email/password or Google authentication at first launch. The explicit guest entry is removed.
- Premium preview policy: non-premium users receive 3 AI Assistant messages and 1 prescription extraction per day. After the preview quota, a subscription is required.
- Premium users receive a soft cap of 50 combined AI Assistant and prescription extraction calls per day.
- Prescription OCR, AI Assistant, and medicine price lookup are premium features. Core medicine tracking, reminders, vault access, box OCR, buy list, and previously created premium data remain available without an active entitlement. Previously created premium data is read-only when the entitlement is inactive.
- Voice input is English-only for v1. Bangla UI localization is separate from speech recognition.
- No free trial is implemented.

## Constraints and existing architecture

- Continue using `provider` with `ChangeNotifier` and `MultiProvider`.
- All Firestore and Storage access goes through service classes. Widgets do not call Firebase directly.
- Pure, deterministic validation, parsing, calculations, gates, and mapping belong in `lib/logic/` and must be unit-testable without platform channels.
- User data remains scoped to `users/{uid}/...`; every new collection or subcollection gets owner-scoped security rules in the same change.
- Dates cross the model boundary as Firestore `Timestamp` values and are displayed with `intl`.
- OCR and AI values remain drafts until the user reviews and confirms them.
- Do not introduce a local database, second state-management package, or custom server for Firebase-backed concerns.
- Treat the tracked BD Apps credential as exposed. It must be removed from tracked source and replaced by an untracked/deployment secret mechanism; credential rotation is an external handoff.

## Batch sequence

### Batch 0: Security and identity baseline

Add owner-only `storage.rules` and wire it in `firebase.json`. Add rule tests or emulator-test fixtures where the existing environment supports them. Remove silent anonymous authentication fallbacks from all services and replace them with a typed unauthenticated result or error. Remove guest entry from the welcome flow and make authenticated email/password and Google paths explicit. Existing anonymous users must see a mandatory account-upgrade flow that links email or Google credentials to their current Firebase UID before normal app access resumes, preserving their existing data.

Remove the tracked BD Apps password from `backend/config.php` and document the required deployment variable/configuration without committing a replacement secret. Do not rotate or deploy external credentials from local code.

Exit criteria: no service can create an anonymous user implicitly; unauthenticated service calls fail predictably; Storage and Firestore rules are owner-scoped; new users must authenticate; existing anonymous users can retain their UID and data only by linking an account; no secret remains in tracked source.

### Batch 1: Reminder correctness

Fix notification identifiers to use the persisted medicine document ID. Make scheduling honor profile reminder settings and threshold values. Persist dose events needed for missed-dose reconciliation, run missed-dose checks at the defined lifecycle points, and re-evaluate refill alerts after marking a dose taken. Route notification payloads to the relevant medicine, dose, expiry, or refill screen through the existing navigation structure. Preserve the current notification channels and exact/inexact scheduling fallback.

Exit criteria: identifiers are stable and collision-free for newly created medicines; settings affect scheduling; taken and missed doses update the appropriate state; notification taps have a deterministic route; pure refill and schedule decisions have unit coverage.

### Batch 2: Structured prescription OCR

Create app-owned prescription extraction models, a versioned response contract, JSON validation, and a typed error taxonomy. Add image quality checks and bounded image preparation before Firebase AI Logic. Persist a prescription draft and item documents through services, with Storage paths that remain owner-scoped and durable. Support multi-image capture where the existing capture flow permits it. Build a review screen using existing cards, inputs, chips, buttons, and typography; show confidence and validation state beside each item; require explicit confirmation before saving medicines or prescription items.

Add fixture-based tests for valid, incomplete, malformed, low-quality, offline, permission, and model-failure cases. Do not log prescription text or images in diagnostics. Reuse the existing AI/App Check service configuration and consolidate the unused prescription AI service once the structured service is active.

Exit criteria: a synthetic prescription fixture can produce a validated draft, the user can edit/reject each item, no unconfirmed extraction is persisted as a medicine, and each defined failure category has a recoverable UI state.

### Batch 3: Medicine reference lookup

Normalize the committed Bangladesh medicine dataset into the `medicineReference` shape, including a normalized `searchName`, generic/brand fields, price, unit, source, and `lastUpdated`. Add a repeatable local seed/import tool with validation output and no committed Admin SDK credential. Add read-only Firestore rules and a service that performs bounded prefix queries. Add a search screen or route using the current MVP app bar, search field, cards, spacing, and typography. Display the reference date and the disclaimer that prices are not live.

Exit criteria: normalized data passes import validation; client writes are denied; prefix search returns stable results; the UI exposes source date and reference-price limitations.

### Batch 4: Entitlement and AI safety

Add an `EntitlementService` and provider state that reads verified subscription status, caches the last verified state and timestamp, refreshes on foreground and relevant entry points, and fails closed for premium actions while preserving read-only access to existing data. Reuse the current BD Apps profile/OTP lifecycle instead of adding a second subscription UI. Add a shared premium gate that implements the 3-message/1-extraction daily preview and the 50 combined paid-user soft cap.

Add pure AI action validation for allowed action types and required fields. Ensure invalid model output is rejected rather than defaulted into a saveable action. Add a persistent safety disclaimer, non-content usage counters, and recoverable limit/error states. Keep all AI calls behind Auth and App Check.

Exit criteria: premium entry points have consistent preview/paywall/limit behavior; entitlement refresh is testable; invalid actions never become saveable defaults; usage accounting does not store message content.

### Batch 5: Manual entry, settings, localization, and family profiles

Add English speech-to-text input with permission-denied fallback to typing. Add typed AI-assisted manual entry by reusing the validated action contract; never auto-save. Add configurable refill and expiry thresholds to the canonical user profile location and feed them into notification scheduling. Add localization using the project-approved package/configuration, centralize user-facing strings, and provide English and first-pass Bangla resources. Add family member models/services, owner-scoped rules, medicine tagging, and dashboard filter chips.

Exit criteria: manual entry works without microphone permission; threshold changes affect future scheduling; all user-facing strings are centralized; English and Bangla paths render without layout breakage; family filters affect dashboard results.

### Batch 6: Nearby pharmacy and remaining roadmap features

Add a Cloud Function contract and local tests for the nearby pharmacy proxy without embedding a Places key in Flutter. Add location permission handling and a map/list screen using the existing navigation and design tokens. Implement honest empty and limited-result states. Add roadmap-specified PDF medicine-list export and dark mode only through shared theme tokens, keeping existing light-mode visuals unchanged.

External Places API enablement, billing, Blaze plan, restricted key, and deployment remain handoffs.

### Batch 7: UI quality and release readiness

Audit every touched and existing shipped screen for design-token drift, loading/error/empty-state consistency, semantic labels, minimum 48dp touch targets, dynamic text scaling, safe-area spacing, contrast, and predictable back/deep-link behavior. Use existing colors and typography; do not substitute the generated UI-UX palette or fonts. Add shared loading/error/empty widgets only where repetition is real. Keep motion restrained to meaningful 150–300ms transitions and respect reduced-motion behavior where supported.

Add focused widget and integration coverage for account entry, reminder actions, prescription review, premium gating, search, and settings. Run `flutter analyze`, unit tests, widget tests, and available integration/emulator tests. Prepare a release checklist covering signing, privacy/Data Safety, App Check, Firebase rules deployment, BD Apps configuration, store assets, and physical-device notification checks.

## UI/UX quality contract

The UI-UX Pro Max guidance is applied as constraints, not as a visual redesign:

- Preserve `AppColors`, `AppTypography`, existing card radius/elevation, app bars, bottom navigation, and button treatments unless a defect requires a token-level correction.
- Use semantic theme tokens instead of raw per-screen colors.
- Keep primary actions singular and visually clear. Use familiar Material icons with labels/tooltips for unfamiliar icon-only actions; do not use emoji as structural icons.
- Maintain 48dp minimum touch targets, visible pressed/disabled states, readable labels, inline field errors, retry paths, cancel/back escape routes, and no gesture-only critical actions.
- Keep content within safe areas and preserve scroll insets around fixed navigation or CTA areas.
- Support system font scaling without clipping or overlap; test small phone, large phone, tablet, and landscape layouts where relevant.
- Use consistent loading, error, empty, success, and offline feedback. Color must not be the sole indicator of status.
- Keep animations purposeful and short; do not add decorative motion or layout-shifting effects.
- Add dark-mode tokens as a paired theme and verify contrast independently when that feature is implemented.

## Testing and verification

Every batch must include tests proportional to its risk:

- Pure logic: `package:test` unit tests for parsing, validation, quotas, thresholds, gates, schedule decisions, and mapping.
- Services: mocked or emulator-backed tests for auth boundaries, Firestore ownership, Storage paths, entitlement refresh, and notification persistence where feasible.
- UI: widget tests for state rendering and critical interactions; integration tests for account entry, reminder action, OCR review, premium gate, and search flows.
- Standards: run `flutter analyze` with zero warnings and the repository's complete Flutter test command before declaring a batch complete.
- External checks: record Firebase Console, BD Apps dashboard, Google Cloud, Play Console, translation review, and physical-device checks as uncompleted handoffs when unavailable locally.

## Traceability and commits

Maintain a roadmap traceability table in the implementation plan, mapping each M0–M10 item to a batch, files, tests, and external handoffs. Commit each completed batch with a focused message matching repository style. Never stage unrelated user changes. Do not push to a remote repository.

## Non-goals

Do not build a drug-interaction checker, add a local database, widen Firebase rules to bypass failures, add silent anonymous sign-in, embed third-party API keys, or claim deployed/release-ready status without external verification.
