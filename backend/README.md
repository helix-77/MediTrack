# MediTrack - BD Apps Backend (Legacy / Migrated to AppsPro.dev)

> [!NOTE]
> **Status: Migrated to AppsPro.dev API**
> MediTrack has migrated from this custom PHP backend proxy to [AppsPro.dev](https://api.appspro.dev) (`/api/v1/sdk/*`).
> The Flutter client now communicates directly with AppsPro via Bearer token authentication and JSON REST endpoints.
> These PHP files are retained for reference and legacy fallback.

## Legacy PHP Endpoints

| File | Purpose | AppsPro Equivalent |
|------|---------|--------------------|
| `config.php` | Loaded BDApps credentials | Replaced by `.env` (`APPS_PRO_SECRET_KEY`, `Base_URI`, etc.) |
| `subscribe.php` | Initiated carrier subscription | `POST /api/v1/sdk/subscribe` |
| `send_otp.php` | Requested subscription OTP | `POST /api/v1/sdk/otp/request` |
| `verify_otp.php` | Verified subscriber OTP | `POST /api/v1/sdk/otp/verify` |
| `check_subscription.php` | Queried subscription status | `POST /api/v1/sdk/status` / `GET /api/v1/sdk/verify/{id}` |
| `unsubscribe.php` | Handled subscriber cancellation | `POST /api/v1/sdk/unsubscribe` |
| `send_sms.php` | Client-initiated test SMS | Managed via AppsPro platform |
| `sms.php` | MO/MT SMS gateway hook | Configured via AppsPro BDApps callback URL |
| `ussd.php` | USSD session entry point | Configured via AppsPro BDApps callback URL |

## BDApps Portal Configuration with AppsPro

In the BDApps developer portal, configure the following unified AppsPro URLs:
- **SMS MO URL**: `https://api.appspro.dev/bdapps/sms`
- **USSD MO URL**: `https://api.appspro.dev/bdapps/ussd`
- **Notify URL**: `https://api.appspro.dev/bdapps/notify`
- **Report URL**: `https://api.appspro.dev/bdapps/report`

