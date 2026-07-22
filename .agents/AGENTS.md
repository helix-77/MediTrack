# Workspace Rules for MediTrack

## Version Control Rule

- **Run `git add` and `git commit` after completing any big task**
- Provide a clear, descriptive commit message summarizing the work accomplished.

## Stack & Architecture Guidelines

- Project: MediTrack (Flutter medicine manager app for Android).
- Stack: Flutter 3.44 stable, Dart 3.6+, Null safety.
- Backend: Firebase (firebase_auth anonymous sign-in + cloud_firestore + firebase_storage).
- Local Notifications: `flutter_local_notifications` + `timezone`.
- Code conventions: `flutter analyze` must pass with 0 errors and 0 warnings before declaring tasks done.
