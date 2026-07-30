# MediTrack - BD Apps Backend

PHP endpoints that proxy between the Flutter app and the BD Apps platform
(developer.bdapps.com). They are designed to be deployed on
`https://www.bdappsdigitalapps.com/NADB26067/` (or any path that serves PHP).

## Files

| File | Purpose |
|------|---------|
| `config.php` | Shared `APP_ID` / `APP_PASSWORD` constants. **Rotate before production.** |
| `send_otp.php` | Triggers an OTP for first-time subscription (`POST user_mobile`). |
| `verify_otp.php` | Confirms the OTP and finalises the subscription (`POST Otp, referenceNo`). |
| `check_subscription.php` | Returns the current subscription status for a subscriber. |
| `unsubscribe.php` | Sends an unsubscribe request (`POST user_mobile`). |
| `subscription_listener.php` | Server-pushed lifecycle callback (configure this URL in the BD Apps dashboard). |
| `sms.php` | MO/MT SMS gateway hook (configurable in the dashboard). |
| `ussd.php` | USSD session entry point (configurable in the dashboard). |

## Deploying

1. Upload the contents of this folder to `https://www.bdappsdigitalapps.com/NADB26067/`
   (or any reachable PHP host).
2. In the BD Apps dashboard, point:
   - **Subscription notification URL** → `https://www.bdappsdigitalapps.com/NADB26067/subscription_listener.php`
   - **SMS URL** → `https://www.bdappsdigitalapps.com/NADB26067/sms.php`
   - **USSD URL** → `https://www.bdappsdigitalapps.com/NADB26067/ussd.php`
3. Update the Flutter client `api_config.dart`'s `bdappsBaseUrl` to point at
   the deployed host. The default points at the path above.

## Wire format

All endpoints speak `application/x-www-form-urlencoded` (PHP's `$_POST`) so
the Flutter client uses Dio's `Options(contentType: Headers.formUrlEncodedContentType)`.
