# Firebase Setup Guide for MediTrack

This guide configures Firebase Authentication, Cloud Firestore, and Cloud Storage for MediTrack.

## 1. Create a Firebase project

1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Create or select the MediTrack project.
3. Choose the Firebase region appropriate for the Bangladesh user base.

## 2. Enable authentication providers

Under **Build → Authentication → Sign-in method**:

1. Enable **Email/Password**.
2. Enable **Google** and configure the Android SHA-1/SHA-256 fingerprints for debug and release signing certificates.
3. Anonymous Authentication is not used for new accounts. Existing anonymous users from earlier releases are routed through a mandatory credential-linking flow so their Firebase UID and data are preserved.

## 3. Create Firestore and Storage

1. Create Cloud Firestore in production mode.
2. Enable Cloud Storage.
3. Deploy the repository-controlled owner-only rules:

```bash
firebase deploy --only firestore:rules,storage
```

The rules allow authenticated users to access only `users/{uid}/...` paths matching their Firebase UID. Do not replace them with test-mode or public rules.

## 4. Connect Firebase to Flutter

Install and authenticate the Firebase and FlutterFire CLIs, then run from the project root:

```bash
flutterfire configure
```

Select the required platforms. The generated `lib/firebase_options.dart` and platform configuration files provide public Firebase client configuration; do not place backend credentials in `.env`.

## 5. Verify locally

Run:

```bash
flutter analyze
flutter test
flutter run
```

Verify these account states:

- A signed-out user sees email/password and Google authentication options.
- A previously anonymous user sees the mandatory account-upgrade screen and retains the same UID after linking.
- A registered user enters the main app.
- One authenticated user cannot read or write another user's Firestore or Storage paths.

Production verification also requires deploying the rules and testing Google Sign-In with the release signing certificate registered in Firebase Console.
