# AppsPro API — Customer Reference for AI Agents

AppsPro is a subscription-management platform built on top of Dialog Axiata BDApps.
This document covers the **customer-facing** API surface only — what a developer
integrating their app with AppsPro can call. Internal dashboard endpoints are
not included.

Base URL: https://api.appspro.dev
SDK Base URI (shown in your dashboard): https://api.appspro.dev/api/v1

---

## Credentials (issued per app in the AppsPro dashboard)

- publishable*key — client-side safe (e.g. "pk*..."). Used in WebSDK init
  code (AppsPro('pk\_...')) and as a query param on the
  /sdk/app-info and /embed/subscribe public endpoints.
- secret*key — server secret (e.g. "sk*..."). The Authorization
  Bearer token for /api/v1/sdk/\* calls AND the HMAC-SHA256
  key for verifying outbound webhook signatures. Shown
  once on regenerate.
- url_slug — short 10-char base62 handle (e.g. "Hd3kF9aZ2x"). Used
  in user-facing checkout URLs: appspro.dev/s/<slug>.
  Stable across credential rotations.

You never use an "app_id" path parameter from your side. /sdk/\* endpoints
identify your app via the Bearer key; checkout URLs identify it via the
url_slug; the WebSDK identifies it via the publishable_key.

---

## Auth schemes by route group

- /api/v1/sdk/{verify,subscribers,status,otp/\*,subscribe,unsubscribe}
  → Bearer (Authorization: Bearer sk\_<secret>)
- /api/v1/sdk/app-info, /api/v1/sdk/generate-token
  → no auth (uses publishable_key in body / query)
- /api/v1/discover/\* — no auth (public marketplace)
- /s/{url_slug}/\* — no auth (hosted checkout, called by browser)
- /bdapps/\* — no auth (called by BDApps, not by you — configured in BDApps portal)
- /embed/\* — no auth (token from /sdk/generate-token instead)
- /public/unsubscribe/\* — no auth (end-user UI flow, not for customer code)

---

## BDApps Portal Configuration

In your BDApps developer portal, paste these URLs:

SMS MO URL: https://api.appspro.dev/bdapps/sms
USSD MO URL: https://api.appspro.dev/bdapps/ussd
Notify URL: https://api.appspro.dev/bdapps/notify
Report URL: https://api.appspro.dev/bdapps/report

These URLs are identical for every customer. AppsPro routes each incoming
payload to your app via BDApps' applicationId field.

Whitelist this source IP in the BDApps portal so we can reach you:
217.15.160.79

You can also read these values programmatically:
GET /platform/bdapps-portal-config
Response: { sms_url, ussd_url, notify_url, whitelisted_ips }

---

## SDK (Bearer auth or public)

GET /api/v1/sdk/verify/{subscriber_id} // Bearer
subscriber_id must be the BDApps subscriber ID returned by /sdk/subscribers,
e.g. "tel:8801712345678" — not the internal AppsPro UUID.
Response: { valid: bool, subscriber?: SubscriberResponse, reason?: string }

GET /api/v1/sdk/subscribers?page=&limit=&status=
Response: { subscribers: SubscriberResponse[], total, page, limit }

POST /api/v1/sdk/status // Bearer
Body: { phone } // raw "01XXXXXXXXX"
Response: { subscription_status, status_code, status_detail, raw }
// Queries BDApps live (not local DB) so it's truth even before notify webhook.

POST /api/v1/sdk/otp/request // Bearer Rate limit 10/h/phone/app.
Body: { phone }
Response: { reference_no, status_code, status_detail, raw }
// Sends a real SMS. Pass reference_no back to /sdk/otp/verify.

POST /api/v1/sdk/otp/verify // Bearer
Body: { reference_no, otp }
Response: { subscription_status, subscriber_id, local_subscriber_id, status_code, status_detail, raw }
// On success, registers subscriber locally and fires subscriber.created webhook.

POST /api/v1/sdk/subscribe // Bearer
Body: { phone }
Response: { status_code, status_detail, raw }
// Direct subscribe without OTP. For trusted server-to-server use.

POST /api/v1/sdk/unsubscribe // Bearer
Body: { phone }
Response: { status_code, status_detail, raw }
// Success if statusCode == "S1000" OR raw.subscriptionStatus == "UNREGISTERED".

GET /api/v1/sdk/app-info?publishable_key=... // no auth (legacy ?public_key= alias accepted)
Response: { name, description, category, pricing_model, icon_url, publishable_key }

POST /api/v1/sdk/generate-token // no auth, scoped to Origin
Body: { publishableKey } // accepts legacy publicKey too
Response: { token, expires_in: 300 }

SubscriberResponse:
{ id, bdapps_subscriber_id, phone_masked, status, subscription_type, frequency, subscribed_at, cancelled_at, created_at }

---

## Hosted Checkout (no auth)

User-facing page: https://appspro.dev/s/{url_slug}

GET /s/{url_slug}/info
Response: { name, description, icon_url, pricing_model, category }

POST /s/{url_slug}/otp/request
Body: { phone }
Response: { status_code, status_detail, raw, reference_no }

POST /s/{url_slug}/otp/verify
Body: { reference_no, otp }
Response: { status_code, status_detail, raw, subscription_status, subscriber_id, local_subscriber_id, redirect_url }

Phone formats accepted: 01XXXXXXXXX, 8801XXXXXXXXX, or +8801XXXXXXXXX.

---

## Discover / Marketplace (no auth)

Public catalogue of apps that have been published on AppsPro. Useful if
your app is listed and you want to surface its marketplace metadata, or
if you're building an external directory page.

GET /api/v1/discover/apps?page=&limit=&search=&category=
Response: { apps: DiscoverAppItem[], total, page, limit }
Pagination: page >= 1, limit in [1, 100] (default 20).

GET /api/v1/discover/apps/{url_slug}
Response: DiscoverAppItem
404 if the slug doesn't match a published app.

GET /api/v1/discover/apps/{url_slug}/download
302 redirect to the latest APK URL; also increments downloads_count.
404 if the app isn't an Android app or has no published APK.

DiscoverAppItem:
{
name, description, icon_url, screenshots, category, pricing_model,
url_slug, developer_name, organization, subscriber_count, app_type,
apk_url,
versions: [{ version_name, release_notes, created_at }],
pricing: [{ method_name, display_name, price, billing_period }]
}

---

## Webhooks (your server receives POSTs from AppsPro)

Configure your webhook URL and event list in the AppsPro dashboard.

Headers on every delivery:
X-Event-Type: <event name>
X-Signature: <hex HMAC-SHA256 of canonical JSON, signed with secret_key> // NO "sha256=" prefix
Content-Type: application/json

Canonical body: json.dumps({ "event": <type>, "data": <payload> }, sort_keys=True)
You MUST canonicalise the parsed body with sorted keys before HMAC.
Comparing raw request bytes will not work in most frameworks.

Event types:
subscription lifecycle:
subscriber.created, subscriber.cancelled, subscriber.reactivated,
subscriber.<status>, subscriber.unknown.<status>
inbound messaging (forwarded from BDApps):
sms.received, ussd.received
hosted checkout:
checkout.otp.requested, checkout.otp.verify.failed

Example subscriber.created body:
{
"event": "subscriber.created",
"data": {
"applicationId": "BDAPPS_123",
"frequency": "daily",
"internal_subscriber_id": "550e8400-...",
"status": "REGISTERED",
"subscriberId": "tel:8801712345678",
"timeStamp": "2026-05-11T10:30:00Z"
}
}

---

## Embed (no auth)

GET /embed/subscribe?publishable_key=&token=&theme=&locale=&button_text=&button_color=&compact=&hide_header=
→ HTML page suitable for iframe embedding
token comes from POST /api/v1/sdk/generate-token
(legacy ?public_key= query is still accepted)

---

## WebSDK (browser JS — appspro.js)

Embed a subscription widget directly in your website or mobile WebView.
The widget is injected as plain HTML into your container — no iframe, no
postMessage — so it works reliably in Android/iOS WebViews.

### Install

  <script src="https://appspro.dev/sdk/v1/appspro.js"></script>

// Legacy URL /sdk/v1/texionapps.js is still served as a symlink to
// appspro.js but is deprecated — use the new filename in new pages.

### Init

const sdk = AppsPro(publicKey, { baseUrl });

- publicKey: your publishable*key (e.g. "pk*..."). Safe to ship to the browser.
- baseUrl (required): the API host, "https://api.appspro.dev". The SDK does
  not auto-detect this — the script is served from appspro.dev but the API
  lives on api.appspro.dev, so it must be passed explicitly.

### Create the subscribe element

const el = sdk.elements.create('subscribe', {
buttonText: string, // default: 'Subscribe Now'
buttonColor: string, // default: '#6366f1' (CSS color)
theme: 'dark' | 'light', // default: 'dark'
compact: boolean, // default: false — tighter padding
hideHeader: boolean, // default: false — hide app-name header
borderRadius: string, // default: '12px'
});

NOTE: WebSDK option keys are camelCase (buttonText, hideHeader). The
/embed/subscribe REST surface uses snake_case (button_text, hide_header).
Don't mix them.

### Element API

el.mount(selector); // selector string, e.g. '#subscribe-box'
el.unmount(); // remove from DOM
el.update(opts); // change options on a mounted element
el.on(event, cb); // subscribe to events (see below)

mount() fetches /api/v1/sdk/app-info under the hood to render the header.

### Events

ready → {} — widget has rendered in the DOM
otp-sent → { phone } — OTP SMS was dispatched
success → { subscriberId, localSubscriberId, redirectUrl } — user subscribed
payment-redirect → { url } — forwarded from OTP verify
error → { message } — anything failed in the flow

On 'success', verify server-side before granting paid access:
GET /api/v1/sdk/verify/{subscriberId} // Bearer sk\_...

### Checkout helpers (no widget)

If you don't want to embed the widget, the SDK can hand you a hosted-checkout
URL or open it in a popup.

const url = sdk.createCheckoutUrl({ redirectUrl: 'https://your-site.com/welcome' });
// → "https://appspro.dev/s/<url_slug>?redirect_url=..."

sdk.openCheckout({
redirectUrl: 'https://your-site.com/welcome',
width: 460,
height: 600,
});
// Opens a centered popup window named 'appspro-checkout'.

### Flutter / mobile WebView

The SDK auto-posts every event to a JavaScript channel named "AppsPro":

window.AppsPro.postMessage(JSON.stringify({ type, data }));

In Flutter (webview_flutter), register a channel of that exact name and
parse the JSON to receive ready/otp-sent/success/payment-redirect/error
events. No extra JS wiring is needed inside the WebView.

---

## Inbound BDApps webhooks (no auth, called by BDApps — NOT by you)

POST /bdapps/sms // SMS MO callback
POST /bdapps/ussd // USSD MO callback
POST /bdapps/notify // subscription notify
POST /bdapps/report // SMS delivery report

You configure these URLs in the BDApps portal. Do not call them from your code.

---

## Public cross-app unsubscribe (end-user UI)

For end users who want to opt out across every app on the platform from
a single page, AppsPro hosts a public OTP-gated unsubscribe flow:

https://appspro.dev/unsubscribe

Backend routes (POST /public/unsubscribe/otp/request, /otp/verify, and
/public/unsubscribe) are driven by that UI and are not intended to be
called from customer code. From your own code, use:

POST /api/v1/sdk/unsubscribe // Bearer sk\_...

---

## Notes

- Phone numbers: 01XXXXXXXXX, 8801XXXXXXXXX, or +8801XXXXXXXXX (Robi/Airtel for BDApps).
- /api/v1/sdk/verify accepts the BDApps subscriber_id from /sdk/subscribers (e.g. tel:8801...).
- secret_key is shown only once when regenerating — store it immediately.
- For browser-side subscription UI, prefer the WebSDK (appspro.js) over
  the /embed/subscribe iframe — it works inside Android/iOS WebViews where
  iframes routinely break.
- Sending SMS or charging subscribers from your own backend is not part of the
  public API. Use the AppsPro dashboard for those operations.
