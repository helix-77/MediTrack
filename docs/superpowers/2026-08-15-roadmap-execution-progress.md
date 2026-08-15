# MediTrack Roadmap Execution Progress

**Date:** 2026-08-15
**Approved design:** [`docs/superpowers/specs/2026-08-15-meditrack-completion-design.md`](superpowers/specs/2026-08-15-meditrack-completion-design.md)
**Current batch:** Batch 0, Security and Identity Baseline
**Status:** Implementation in progress; not yet committed

## User-approved decisions

- Execute locally actionable roadmap work on top of the existing MVP.
- Preserve the existing MVP architecture and visual language.
- Use dependency-ordered implementation batches.
- Require email/password or Google authentication for new users.
- Existing anonymous users must link credentials to their current Firebase UID before accessing the app.
- Premium preview: 3 AI Assistant messages and 1 prescription extraction per day for non-premium users.
- Premium users receive a soft cap of 50 combined AI Assistant and prescription extraction calls per day.
- Premium features: prescription OCR, AI Assistant, and medicine price lookup.
- Core tracking, reminders, vault, box OCR, buy list, and previously created premium data remain available without an active entitlement. Previously created premium data is read-only when entitlement is inactive.
- English-only voice input for v1.
- No free trial.
- UI work must apply `ui-ux-pro-max` accessibility and interaction guidance without replacing the current sage/pink palette or Poppins/Inter typography.

## Completed design work

- Added the approved implementation design:
  [`docs/superpowers/specs/2026-08-15-meditrack-completion-design.md`](superpowers/specs/2026-08-15-meditrack-completion-design.md)
- The design was self-reviewed for placeholders, contradictions, quota ambiguity, and anonymous-user migration behavior.
- Design commit: `7c01bce docs: plan roadmap completion`

## Batch 0 implementation so far

### Authentication and routing

- Added [`lib/logic/auth_guard.dart`](../lib/logic/auth_guard.dart):
  - `UnauthenticatedException`
  - `AnonymousAccountException`
  - `requireAuthenticatedUser`
  - deterministic `AuthRoute` decisions
- Updated [`lib/services/auth_service.dart`](../lib/services/auth_service.dart):
  - removed the public anonymous sign-in flow
  - added `linkAnonymousWithEmail`
  - added `linkAnonymousWithGoogle`
  - linking uses `currentUser.linkWithCredential`, preserving the existing UID/data
  - maps credential conflicts and network failures to actionable messages
  - supports constructor injection for Firebase Auth and Google Sign-In dependencies
- Added [`lib/screens/account_upgrade_screen.dart`](../lib/screens/account_upgrade_screen.dart):
  - mandatory, non-dismissible upgrade flow for legacy anonymous users
  - email/password and Google credential linking
  - retry/error feedback
  - no bypass to the normal app
- Updated [`lib/main.dart`](../lib/main.dart):
  - routes signed-out users to `WelcomeScreen`
  - routes anonymous users to `AccountUpgradeScreen`
  - routes registered users to `MainNavigationShell`
  - provides `AuthService` through the existing `MultiProvider`
- Updated [`lib/screens/welcome_screen.dart`](../lib/screens/welcome_screen.dart):
  - removed guest loading state, handler, and button
  - keeps existing sign-up and login entry points
- Updated Home/Profile screens to remove normal-app guest assumptions and use the service auth state where possible.

### Service authentication boundaries

Removed silent anonymous-account creation from:

- `MedicineService`
- `PrescriptionService`
- `UserProfileService`
- `BuyListService`
- `GeminiAiService`

Writes and AI calls now require a registered authenticated user through the shared guard. Existing streams still wait for auth state and return empty data before a user is present; this remains a follow-up consideration for making stream errors typed without breaking current consumers.

### Firebase security

- Added owner-only [`storage.rules`](../storage.rules).
- Wired Storage rules into [`firebase.json`](../firebase.json).
- Storage access is limited to authenticated users whose UID matches `users/{uid}/...`.

### Backend secret handling

- Removed the BD Apps password literal from tracked [`backend/config.php`](../backend/config.php).
- Backend config now loads `BDAPPS_APP_ID` and `BDAPPS_APP_PASSWORD` from deployment environment variables and fails closed when absent.
- Updated [`backend/README.md`](../backend/README.md) with environment-variable deployment instructions and credential-rotation warning.
- Updated [`docs/firebase_setup_guide.md`](firebase_setup_guide.md) to document email/password and Google auth, owner-only Firestore/Storage rules, and legacy anonymous migration.
- The exposed credential must still be rotated by the owner in the BD Apps dashboard; local code cannot perform that external action.

## Tests added

- [`test/logic/auth_guard_test.dart`](../test/logic/auth_guard_test.dart)
  - signed-out route
  - legacy anonymous upgrade route
  - registered-user app route
  - typed auth-error messages
- [`test/screens/welcome_screen_test.dart`](../test/screens/welcome_screen_test.dart)
  - verifies account entry controls exist
  - verifies `Continue as Guest` is absent

## Verification results

- Focused tests passed:
  `flutter test test/logic/auth_guard_test.dart test/screens/welcome_screen_test.dart`
  - Result: `00:03 +5: All tests passed!`
- `git diff --check` passed.
- PHP syntax verification was attempted but could not run because `php` is not installed in the environment.
- `flutter analyze` reports no issues.
- `flutter test` passes: `00:04 +22: All tests passed!`
- `git diff --check` passed.
- PHP syntax verification was attempted but could not run because `php` is not installed in the environment.
- Static scans found no `signInAnonymously`, guest-entry text, or exposed BD Apps password literal in the current tree.

## Batch 0 checkpoint

Batch 0 was verified and committed as `379014d fix: secure authentication and storage boundaries`.

## Batch 1 implementation and verification

Batch 1 is implemented and ready to commit after verification.

Completed locally:

- Added deterministic notification and dose-event identity in `lib/logic/notification_identity.dart`.
- `MedicineService.saveMedicine` now returns the persisted medicine with its Firestore document ID, so new medicines do not schedule using an empty ID.
- Dose status updates use a deterministic event ID when the UI has no log ID, read the existing status, and decrement stock only when transitioning into `taken`.
- Marking a dose taken reloads the persisted medicine and reschedules notifications, re-evaluating refill state.
- Deleting a medicine cancels its notification set.
- Notification IDs are derived from medicine ID, notification kind, and dose slot instead of Dart `hashCode`.
- Notification scheduling accepts the persisted user profile toggles for dose, expiry, and low-stock alerts.
- Profile reminder-toggle changes reschedule the user's medicines.
- Missed-dose reconciliation runs when the authenticated navigation shell opens.
- Notification payloads identify `dose`, `expiry`, or `refill` and route through the app navigator to the medicine detail screen.
- Added `test/logic/notification_identity_test.dart`.

Verification:

- `flutter analyze`: no issues found.
- `flutter test`: `00:04 +25: All tests passed!`
- `git diff --check`: passed.

Known external verification still required:

- Android/iOS notification permission behavior.
- Exact/inexact alarm behavior on real devices.
- Background, killed-app, OEM battery-management, and notification-tap behavior.
- Deploying Firebase Storage rules and checking current bucket defaults.

## Remaining roadmap batches

1. Batch 2: structured prescription OCR production pipeline.
2. Batch 3: medicine reference normalization, seed tooling, rules, and search.
3. Batch 4: BD Apps entitlement, preview quotas, AI validation, safety, and usage caps.
4. Batch 5: English voice, AI-assisted entry, settings thresholds, localization, and family profiles.
5. Batch 6: nearby pharmacy contract/client, PDF export, and dark mode.
6. Batch 7: UI quality audit, accessibility/widget/integration tests, release checklist, and final verification.

External deployment, credential rotation, Firebase/Google/BD Apps dashboard work, billing, translation review, production signing, store submission, and physical-device notification testing remain explicit handoffs and must not be represented as locally verified.
