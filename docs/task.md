# fix:

D/FlutterJNI(22345): Sending viewport metrics to the engine.
I/ImeTracker(22345): com.meditrack.app.meditrack:8f355dfc: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false userId 0 displayId 0
D/InsetsController(22345): show(ime())
I/ImeTracker(22345): com.meditrack.app.meditrack:8f355dfc: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/flutter (22345): Firebase AI Gemini Error: [firebase_app_check/unknown] com.google.firebase.FirebaseException: Error returned from API. code: 403 body: App attestation failed.

---

## Future

- Add a paid BD Apps SMS reminder channel.
- Send one Bangla SMS containing only today's active doses shortly before the first dose time.

---

# List (working or not )

[x] Test SMS service
[] Subscription service
[x] ai service
[x] prescription ocr
[x] Ui revamp
[x] add buy list, automatically add low stock product in buy list with separate field
[x] add medicine dataset integration
[x] add options to set morning, noon, evening, night time schedule
[x] after marking as taken, medicine should move to the bottom in routine dashboard
[x] switch to openrouter from firebase ai completely. use openrouter/free model (https://openrouter.ai/openrouter/free)
for flutter integration follow:https://pub.dev/packages/openrouter
[] not subscribed users can do 1 prescription ocr, 3 ai messages in total, 3 generic price lookup
[] migrate from firebase storeg to supabase storeg, other backend stuffs should remain in firebase (later)
[] fetch and update the medicine dataset latest price
[x] The AI should be able to add, update, query and delete item if the user request. currently it can only add
[x] The AI should also be able to look the the db for reference
[] improve the ai chat ui, add more features like new chat, archived chat (later)
