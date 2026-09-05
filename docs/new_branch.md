# MediTrack AppsPro/BDApps cancellation work

## User-reported problem

The app called AppsPro's unsubscribe endpoint and received HTTP 200 with this
carrier result:

- status code: E1951
- detail: the carrier address format was invalid or the user was already
  unregistered

The app then removed the in-app entitlement even though the carrier had not
confirmed cancellation. A separate Firestore write was rejected because the
running client attempted to write under users/main/..., while the security
rules only allow a signed-in user to write under their own Firebase UID.

## Documentation reviewed

- AppsPro documentation: https://appspro.dev/docs
- Local AppsPro reference: .agents/AppsPro_API_for_ai_agents.md

The documented unsubscribe success contract is S1000 or an explicit raw
carrier UNREGISTERED state. AppsPro's BDApps callback URLs must be configured
in the BDApps portal, and AppsPro bearer secrets must not be shipped in a
Flutter client.

## Changes made

- Added docs/appspro-bdapps-production-setup.md, a step-by-step production
  setup and verification guide.
- Added Firebase Functions 2nd-gen appsProProxy and appsProWebhook.
- Moved AppsPro bearer calls behind the authenticated Firebase proxy.
- Bound the AppsPro secret through Cloud Secret Manager.
- Made unsubscribe read the linked phone from the authenticated user's profile.
- Added a live status check before and after unsubscribe.
- Persisted UNREGISTERED only after AppsPro/carrier confirmation.
- Added HMAC validation for AppsPro webhook deliveries.
- Removed the in-app-only entitlement sync action and the undocumented hard-coded
  SMS cancellation instruction.
- Added safe AppsPro public unsubscribe fallback link.
- Disabled request/response bodies in debug logging so tokens, OTPs, and phone
  numbers are not written to logcat.
- Updated the project specification, task list, Firebase configuration, client
  tests, and unsubscribe response parsing.

## Deployment constraint

Firebase Functions and Secret Manager require the Firebase project to use the
Blaze plan. The Spark plan cannot deploy this secure proxy. The correct secret
command is:

```
firebase functions:secrets:set APPSPRO_SECRET_KEY
```

The command prompts for the value; the sk\_... value must not be placed in the
command line or in .env. The previously exposed key must be rotated in AppsPro.

## Verification status at time of writing

- TypeScript Functions lint/build path was run successfully after dependency
  installation.
- Flutter formatting was run.
- Flutter analyzer/test execution was started but interrupted by the subsequent
  user request, so it must be rerun before deployment.

## Required human actions

1. Rotate the exposed AppsPro secret.
2. Configure the BDApps portal callback URLs and source-IP allowlist.
3. Upgrade Firebase to Blaze if the automatic proxy/webhook path is required.
4. Set APPSPRO_SECRET_KEY in Secret Manager and deploy the two functions.
5. Set APPSPRO_PROXY_URL and APPSPRO_PUBLISHABLE_KEY in the Flutter .env.
6. Configure the AppsPro signed webhook URL.
7. Test subscription, cancellation, E1951, and webhook flows on a Robi/Airtel
   test SIM.

---

Created branch: fix/appspro-bdapps-proxy
Commit: 2a74284 fix(bdapps): proxy carrier cancellation through Firebase
Returned to main
Removed the untracked implementation files from the working tree.
main is clean and remains at c6f4bd9.
The documentation and implementation are recoverable with:
git switch fix/appspro-bdapps-proxy
Only the ignored functions/node_modules cache remains locally.
