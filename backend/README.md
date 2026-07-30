# MediTrack - BD Apps Backend

PHP endpoints that proxy between the Flutter app and the BD Apps platform
(developer.bdapps.com). They are designed to be deployed on
`https://www.bdappsdigitalapps.com/NADB26067/` (or any path that serves PHP).

## Files

| File | Purpose |
|------|---------|
| `config.php` | Shared `APP_ID` / `APP_PASSWORD` constants. **Rotate before production.** |
| `check_subscription.php` | Returns the current subscription status for a subscriber. |
| `unsubscribe.php` | Sends an unsubscribe request (`POST user_mobile`). |
| `send_sms.php` | Client-initiated outbound SMS (`POST user_mobile, message`) — used by the profile tab's "Send test SMS" action. |
| `sms.php` | MO/MT SMS gateway hook (configurable in the dashboard). |
| `ussd.php` | USSD session entry point (configurable in the dashboard). |

## Deploying

1. Upload the contents of this folder to `https://www.bdappsdigitalapps.com/NADB26067/`
   (or any reachable PHP host).
2. In the BD Apps dashboard, point:
   - **SMS URL** → `https://www.bdappsdigitalapps.com/NADB26067/sms.php`
   - **USSD URL** → `https://www.bdappsdigitalapps.com/NADB26067/ussd.php`
3. Update the Flutter client `api_config.dart`'s `bdappsBaseUrl` to point at
   the deployed host. The default points at the path above.

## Wire format

All endpoints speak `application/x-www-form-urlencoded` (PHP's `$_POST`) so
the Flutter client uses Dio's `Options(contentType: Headers.formUrlEncodedContentType)`.
