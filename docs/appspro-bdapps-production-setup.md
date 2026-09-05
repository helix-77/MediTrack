# AppsPro + BDApps production setup

This guide sets up the secure cancellation path used by MediTrack. Complete the
steps in order; do not put an AppsPro `sk_` key in Flutter, `.env`, source code,
logs, or screenshots.

## 1. Rotate the exposed AppsPro secret

1. Sign in to the AppsPro developer dashboard and open the MediTrack app.
2. Regenerate the secret key because the old key was logged by the Android app.
3. Save the new key only in a password manager until Step 4. Do not add it to
   the Flutter `.env` file.
4. Do not revoke the old key until the Cloud Functions deployment in Step 5 has
   succeeded, unless AppsPro’s rotation screen revokes it automatically.

## 2. Configure BDApps to send events to AppsPro

In the BDApps developer portal for the same `applicationId`, set these exact
URLs. They are AppsPro endpoints; MediTrack never calls them directly.

| BDApps portal field | Value |
| --- | --- |
| SMS MO URL | `https://api.appspro.dev/bdapps/sms` |
| USSD MO URL | `https://api.appspro.dev/bdapps/ussd` |
| Notify URL | `https://api.appspro.dev/bdapps/notify` |
| Report URL | `https://api.appspro.dev/bdapps/report` |

Add `217.15.160.79` to the portal’s source-IP allowlist. Save and publish the
portal configuration. A subscription or cancellation cannot be reflected by
AppsPro until BDApps can deliver its Notify callback.

## 3. Prepare Firebase Functions locally

1. Install Node.js 22 LTS and the Firebase CLI.
2. Authenticate and select the project:

   ```bash
   firebase login
   firebase use meditrack-app-2026
   ```

3. Install the checked-in function dependencies:

   ```bash
   cd functions
   npm install
   cd ..
   ```

4. Store the rotated AppsPro secret in Cloud Secret Manager. Paste it only when
   prompted:

   ```bash
   firebase functions:secrets:set APPSPRO_SECRET_KEY
   ```

5. Deploy the proxy and webhook:

   ```bash
   firebase deploy --only functions:appsProProxy,functions:appsProWebhook
   ```

Cloud Functions and Secret Manager require the Firebase project to be on the
Blaze plan. The deploy command prints the `appsProProxy` URL. The committed
configuration uses `asia-south1`; if you deliberately change the region, use
the URL printed by the deploy instead.

## 4. Configure MediTrack’s non-secret environment

Copy `.env.example` to `.env` if needed. Set only the function URL and
AppsPro’s publishable key:

```dotenv
APPSPRO_PROXY_URL=https://asia-south1-meditrack-app-2026.cloudfunctions.net/appsProProxy
APPSPRO_PUBLISHABLE_KEY=pk_your_publishable_key
```

Delete `APPS_PRO_SECRET_KEY` and `Base_URI` from `.env`. Rebuild the Android
app after changing `.env`.

## 5. Configure AppsPro’s outbound webhook

In the AppsPro dashboard, configure the webhook URL below and enable at least
`subscriber.created`, `subscriber.cancelled`, and `subscriber.reactivated`:

```text
https://asia-south1-meditrack-app-2026.cloudfunctions.net/appsProWebhook
```

AppsPro signs each delivery using the same secret saved in Step 3. The function
verifies the HMAC before it writes any Firestore profile. Copy the exact
deployed URL if Firebase prints a different one.

## 6. Verify end to end before release

1. On a Robi/Airtel test SIM, subscribe using the app and complete the OTP.
2. Confirm AppsPro’s dashboard shows the subscriber as `REGISTERED`.
3. Use the app’s cancel button. It must show success only after AppsPro returns
   `S1000` or `UNREGISTERED`.
4. Confirm the AppsPro dashboard and BDApps portal show the subscriber as
   unregistered, then verify Firestore has
   `subscriptionStatus: "UNREGISTERED"` for that user’s profile.
5. Test the ambiguous `E1951` case. The app must keep Premium active unless a
   live AppsPro status check says `UNREGISTERED`; it must never offer an
   in-app-only sync action.
6. In the AppsPro dashboard, send a signed test `subscriber.cancelled` webhook
   and confirm the matching profile updates.
7. Check logs with `firebase functions:log --only appsProProxy,appsProWebhook`.
   No Authorization header, AppsPro secret, OTP, or full phone number should
   appear.

## Troubleshooting

- **`E1951`** means BDApps did not confirm direct unregistration. It can mean
  an invalid carrier address or an already-unregistered user. The proxy performs
  a live status check; only an explicit `UNREGISTERED` result changes access.
- **401 from `appsProProxy`** means the user is signed out or Firebase ID token
  verification failed. Sign in again; do not weaken Firestore rules.
- **No webhook arrives** means the AppsPro dashboard webhook URL/event list or
  BDApps portal Notify URL/IP allowlist is incomplete.
- **Function deployment fails** because billing is disabled: enable Blaze for
  the Firebase project, then run the same deploy command again.

Sources: [AppsPro documentation](https://appspro.dev/docs) and the project’s
`.agents/AppsPro_API_for_ai_agents.md` reference.
