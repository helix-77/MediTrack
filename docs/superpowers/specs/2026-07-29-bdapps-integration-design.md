# BDApps Integration Architecture & Feature Design

**Date:** 2026-07-29  
**Status:** Approved  

## 1. Overview
MediTrack requires a clean, robust, and production-ready BDApps integration (Robi/Airtel Telco Subscription & OTP service) built using the 100% working backend architecture from `Updated_bdapps_backend (1)`.

## 2. Architecture & Components

```
+------------------------------------+
|   MediTrack Flutter Application    |
|   (bdapps_subscription_screen.dart)|
+-----------------+------------------+
                  |
                  | Form UrlEncoded POST
                  v
+------------------------------------+
|  PHP Proxy Backend (cPanel Server) |
|  - config.php                      |
|  - send_otp.php                    |
|  - verify_otp.php                  |
|  - check_subscription.php          |
|  - unsubscribe.php                 |
+-----------------+------------------+
                  |
                  | JSON POST (applicationId + password)
                  v
+------------------------------------+
|    BDApps Telecom TAP Platform     |
|   (https://developer.bdapps.com)   |
+------------------------------------+
```

### A. Backend Layer (`backend/`)
* **`config.php`**: Defines `BDAPPS_APP_ID` (`APP_139363`) and `BDAPPS_APP_PASSWORD` (`y0e74fafba35bd80a3e484ca07ab43715`) with `getenv()` override.
* **`send_otp.php`**: Validates 11-digit mobile (`01[3-9]...`), formats `tel:8801...`, requests OTP from `https://developer.bdapps.com/subscription/otp/request`. Returns `{ success, referenceNo, statusCode, statusDetail }`.
* **`verify_otp.php`**: Verifies `referenceNo` and `Otp` via `https://developer.bdapps.com/subscription/otp/verify`. Returns `{ statusCode, statusDetail, subscriptionStatus, subscriberId }`.
* **`check_subscription.php`**: Queries subscription status from `https://developer.bdapps.com/subscription/getStatus`. Returns `{ subscriptionStatus, isSubscribed, statusCode, statusDetail }`.
* **`unsubscribe.php`**: Triggers unsubscription via `https://developer.bdapps.com/subscription/send` (`action: "0"`). Returns `{ success, subscriptionStatus, statusCode }`.
* **`sms.php`**, **`ussd.php`**, **`subscription_listener.php`**: Webhook listeners.

### B. Flutter Service Layer (`lib/services/bdapps_service.dart`)
* Sends `application/x-www-form-urlencoded` requests to the PHP proxy.
* Formats raw phone numbers into standard local 11-digit numbers (`01XXXXXXXXX`).
* Parses responses cleanly into strong Dart models (`BdAppsOtpResponse`, `BdAppsOtpVerifyResponse`, `BdAppsSubscriptionStatusResponse`).

### C. UI & Presentation (`lib/screens/bdapps_subscription_screen.dart`)
* Interactive Subscription Management Screen:
  * **Phone Input**: Enter Bangladesh mobile number (`018...`).
  * **OTP Request & Verification**: Trigger OTP sent to phone and verify 6-digit pin.
  * **Status Card**: Live card showing subscription status (`REGISTERED` / `UNREGISTERED`).
  * **Unsubscribe**: Unsubscribe user directly with status updates.

## 3. Error Handling
* Catches non-200 HTTP responses gracefully.
* Surface human-readable error messages for BDApps error codes (`E1313`, `E1303`, etc.).

## 4. Verification Plan
* `flutter analyze`: Ensure 0 errors / warnings.
* `flutter test test/services/bdapps_service_test.dart`: All unit tests pass.
