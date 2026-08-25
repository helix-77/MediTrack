# Agent Handoff: AI Latency Fixes + BD Apps Premium Gating + Pre-Subscription Number Check

This document summarizes two rounds of work performed on the MediTrack Flutter app so other agents can pick up the context without re-reading the whole conversation.

---

## Round 1: AI Response Latency + BD Apps Premium Gating (was missing)

### Problem 1: AI responses were too slow

**Root causes identified:**

1. **Unbounded image uploads** — `AiAssistantScreen._pickImage` called `image_picker` with only `imageQuality: 85` and **no dimension cap**. A modern phone photo (3000–4000px) was being base64-inlined straight to Gemini. This is the single biggest latency driver for image messages.
2. **Model rebuilt on every call** — Both `GeminiAiService` and `PrescriptionExtractionService` constructed a brand-new `FirebaseAI.googleAI()` + `GenerativeModel` on every single message, instead of reusing one.
3. **No output bound** — Neither service set a `GenerationConfig`, so replies had no `maxOutputTokens` cap and could run long.

**Fixes applied:**

- `lib/services/gemini_ai_service.dart`:
  - Added `_cachedModel` field; `_getModel()` now caches the `GenerativeModel` via `_cachedModel ??= _buildModel()`.
  - Added `GenerationConfig(maxOutputTokens: 1024)` for chat replies.
- `lib/services/prescription_extraction_service.dart`:
  - Same caching pattern; added `GenerationConfig(maxOutputTokens: 2048)` for structured extraction.
- `lib/screens/ai_assistant_screen.dart`:
  - `_pickImage` now passes `maxWidth: 1920, maxHeight: 1920, imageQuality: 85` (matches what `ScanPrescriptionScreen` already did correctly).

**Important note about `ThinkingConfig` (NOT applied):**

The biggest remaining latency lever for Flash-tier "thinking" models is disabling the thinking budget via `GenerationConfig(thinkingConfig: ThinkingConfig(thinkingBudget: 0))`. I attempted to add this, but the **pinned `firebase_ai: 2.3.0` does not publicly export `ThinkingConfig`** (verified against the pub-cache source — it's exported starting in `firebase_ai` 3.x). I left a comment in both services pointing at this as the highest-impact next step if replies are still slow. Upgrading a pinned major dependency was outside the scope of this task per `AGENTS.md` ("do not substitute without a strong reason — flag it instead").

**Other latency levers NOT applied (flagged for future work):**

- `generateContentStream` (streaming) is available on the pinned `GenerativeModel` and would let the UI render tokens as they arrive instead of waiting for the full reply. Not wired up — would require a streaming-aware `GeminiAiService.sendMessage` signature and a per-token UI update path in `AiAssistantScreen`. Worth doing if perceived latency is still a complaint after the above fixes.
- The system prompt is long and includes a JSON action-schema example; for plain chat turns that don't need an action, a shorter system prompt would reduce input-token cost. Not changed.

### Problem 2: Premium gating was built but never wired up

**What existed:**

- `lib/services/entitlement_service.dart` — `EntitlementService` with `requirePremium()`, `checkAiQuota()`, `checkPrescriptionQuota()`, `recordAiUsage()`, `recordPrescriptionScanUsage()`, 5-minute cache freshness window, BD Apps carrier re-verification.
- `lib/logic/entitlement_guard.dart` — `EntitlementGuard.evaluate()` enforcing the spec's 4 premium features (aiAssistant, prescriptionOcr, priceLookup, nearbyPharmacy) with a 50/day combined soft cap for subscribed users and a hard block for unsubscribed users.
- `lib/features/bdapps/` — full BD Apps subscription flow (OTP, verify, polling, unsubscribe, SMS).
- `lib/screens/subscription_offer_screen.dart` — the commercial paywall UI.
- `lib/screens/account_upgrade_screen.dart` — anonymous-to-real account upgrade path used by `requirePremium` for guest users.

**What was missing:** `requirePremium()` was **never called from any screen**. `AiAssistantScreen` only displayed a cosmetic "Free Tier: 5 AI requests/day remaining" banner that was factually wrong (the guard actually allows zero free-tier AI requests). `ScanPrescriptionScreen`, `MedicineSearchScreen`, `NearbyPharmaciesScreen` had no gating at all. Any authenticated user — subscribed or not — had unlimited access to all four premium features. This matches the spec's own gap list (`medicine-manager-spec.md` §5.11 execution step 2 was never done).

**Fixes applied (per `medicine-manager-spec.md` §5.10's own architecture):**

- **New `lib/widgets/premium_gate.dart`** — a reusable widget that runs `EntitlementService.requirePremium()` on screen entry, routes anonymous users to `AccountUpgradeScreen`, routes non-subscribed users to `SubscriptionOfferScreen`, and pops back if still not entitled after the flow. Shows a spinner while the async check runs.
- **`lib/screens/ai_assistant_screen.dart`** (persistent tab, can't be popped):
  - `_sendMessage()` now calls `entitlement.requirePremium(context, feature: EntitlementFeature.aiAssistant)` **before** calling Gemini; bails out early if not allowed.
  - Calls `entitlement.recordAiUsage()` (fire-and-forget via `unawaited`) after a successful AI response.
  - Replaced the fake "5 requests/day" banner with an accurate "MediTrack AI is a Premium feature (৳2.00/day)" CTA for free users, plus a live quota readout (`entitlement.checkAiQuota().statusMessage`) for already-subscribed users.
- **`lib/screens/scan_prescription_screen.dart`**: wrapped `build()` in `PremiumGate(feature: EntitlementFeature.prescriptionOcr)`. Calls `recordPrescriptionScanUsage()` after a successful extraction.
- **`lib/screens/medicine_search_screen.dart`**: wrapped `build()` in `PremiumGate(feature: EntitlementFeature.priceLookup)`.
- **`lib/screens/nearby_pharmacies_screen.dart`**: wrapped `build()` in `PremiumGate(feature: EntitlementFeature.nearbyPharmacy)`.

**Known minor trade-off:** `NearbyPharmaciesScreen.initState()` fires its GPS permission request immediately on build, in parallel with `PremiumGate`'s async entitlement check (since `State.initState` runs before the gate's `WidgetsBinding.instance.addPostFrameCallback` resolves). A non-subscribed user may briefly see a location permission prompt before being routed to the paywall. Not a functional gap; cosmetic polish item.

---

## Round 2: Pre-Subscription Number Check on the Subscription Offer Screen

### Problem

When a user opened the subscription offer page and entered their phone number, the app immediately requested an OTP via `send_otp.php` — even if that number was **already an active BD Apps subscriber** (e.g. they subscribed before on a different MediTrack account, or reinstalled the app). This wasted an SMS, made the user wait for a code they didn't need, and then `verify_otp.php` would either fail confusingly or silently no-op.

### Fix

**`lib/features/bdapps/bd_apps_service.dart`:**

- Added a new enum `BdNumberCheckResult { alreadyActive, notRegistered, invalidNumber }`.
- Added `BdAppsService.checkNumberBeforeOtp({required String mobileNumber})`:
  1. Validates the number locally via `BdMobileValidator.validateRobiAirtel` → returns `invalidNumber` with `errorMessage` set if it fails.
  2. Calls `_apiClient.checkSubscription(userMobile: normalized)`.
  3. If `subscriptionStatus == 'REGISTERED'`, applies the registered state to the service (`_bdMobile`, `subscriptionStatus`, `subscriptionState.registered`) and returns `alreadyActive` — **no OTP is sent**.
  4. Otherwise (including `UNREGISTERED`, `UNKNOWN`, or any network/parse error) returns `notRegistered` so the caller proceeds to the normal `sendOtp` flow. A failed status lookup intentionally does **not** block subscribing — `send_otp.php` re-validates regardless and will surface a real error if the number is unreachable.
  5. Toggles `isCheckingSubscription` (existing field) during the call so the UI's `isBusy` already reflects it.

**`lib/screens/subscription_offer_screen.dart`:**

- `_sendOtp` now takes `EntitlementService` and runs `bdService.checkNumberBeforeOtp(mobileNumber: phone)` **before** `sendOtp`:
  - `invalidNumber` → snackbar with the validation message, return.
  - `alreadyActive` → calls `entitlement.refreshEntitlement(forceCarrierCheck: true)` to refresh the cached Firestore/carrier state, shows a success snackbar "✅ This number is already a MediTrack Premium subscriber. Activating your account...", and `Navigator.pop(context, true)` to return to the calling screen as subscribed. No OTP screen is shown.
  - `notRegistered` → falls through to the existing `sendOtp` flow unchanged.
- Replaced the ad-hoc `phone.length < 11` check with `BdMobileValidator.validateRobiAirtel(phone)` (the same validator `BdAppsService.requestSubscription` uses), so validation is consistent across the codebase and gives the correct "Only Robi (018) and Airtel (016) numbers are supported" message.
- Added `bdService.isCheckingSubscription` to the `isBusy` flag so the "Send Activation OTP" button disables and shows its spinner during the pre-check too.
- The "Send Activation OTP" button now passes `entitlement` to `_sendOtp`.

### Files changed in Round 2

- `lib/features/bdapps/bd_apps_service.dart` — new enum + `checkNumberBeforeOtp` method.
- `lib/screens/subscription_offer_screen.dart` — pre-check wiring, validation upgrade, `isBusy` flag update.

---

## All files touched (both rounds)

- `lib/services/gemini_ai_service.dart` — model caching, `GenerationConfig(maxOutputTokens: 1024)`, ThinkingConfig comment.
- `lib/services/prescription_extraction_service.dart` — model caching, `GenerationConfig(maxOutputTokens: 2048)`, ThinkingConfig comment.
- `lib/screens/ai_assistant_screen.dart` — image cap, `requirePremium` gate on send, `recordAiUsage`, accurate free-tier banner + live quota readout, `dart:async` import for `unawaited`.
- `lib/screens/scan_prescription_screen.dart` — `PremiumGate` wrapper, `recordPrescriptionScanUsage`, `dart:async` import.
- `lib/screens/medicine_search_screen.dart` — `PremiumGate` wrapper.
- `lib/screens/nearby_pharmacies_screen.dart` — `PremiumGate` wrapper.
- `lib/widgets/premium_gate.dart` — **new file**, the reusable gate widget.
- `lib/features/bdapps/bd_apps_service.dart` — `BdNumberCheckResult` enum + `checkNumberBeforeOtp`.
- `lib/screens/subscription_offer_screen.dart` — pre-subscription number check, validation upgrade, `isBusy` flag.

## Validation

- `flutter analyze`: 0 errors, 0 warnings. One pre-existing `info`-level lint (`curly_braces_in_flow_control_structures` in `scan_prescription_screen.dart` line ~482) was already there before this work and is unrelated.
- `flutter test`: all 72 tests pass, including `subscription_offer_screen_test.dart` (the existing test still renders the screen and asserts all commercial disclosures/features render).

## Architecture notes for the next agent

- The entitlement system is the **single source of truth** for premium gating. Don't add per-screen ad-hoc checks; route through `EntitlementService.requirePremium()` (for action-level gates like AI send) or wrap the screen in `PremiumGate` (for whole-screen gates). The four gated features per spec §5.10 are exactly: `aiAssistant`, `prescriptionOcr`, `priceLookup`, `nearbyPharmacy`. Don't gate anything else speculatively.
- `EntitlementGuard.evaluate()` allows **zero** free-tier uses of `aiAssistant` and `prescriptionOcr` — only subscribed users get any. The old "5 requests/day" banner in `AiAssistantScreen` was wrong; the new banner reflects this.
- `BdAppsService.isRegistered` / `subscriptionStatus` / `subscriptionState` are the in-memory carrier state. `EntitlementService` is what persists it to Firestore (`users/{uid}/profile/main` → `subscriptionStatus`, `subscriptionVerifiedAt`) and enforces the 5-minute freshness window before re-querying the carrier.
- `BdAppsService.checkNumberBeforeOtp` is the new pre-check entry point. It does **not** replace `sendOtp`/`verifyOtp` — it short-circuits the OTP flow only when the number is already `REGISTERED`. For everything else (including status-lookup failures) it falls through to the normal OTP flow so the user is never blocked by a transient carrier-API hiccup.
- `firebase_ai` is pinned at `2.3.0`. `ThinkingConfig` is **not** exported from this version — upgrading to `firebase_ai` 3.x is a prerequisite for disabling the thinking budget, which is the biggest remaining AI-latency lever. Flag this to the user before upgrading; it's a major-version bump and may have other breaking API changes.
