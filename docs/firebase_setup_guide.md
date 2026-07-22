# Firebase Setup Guide for MediTrack

This step-by-step guide will help you set up Firebase for **MediTrack** so your app can seamlessly authenticate users anonymously and sync medicine & dose data with Cloud Firestore.

---

## Step 1: Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Click **Create a project** (or **Add project**).
3. Enter a project name (e.g., `meditrack-app`).
4. (Optional) Disable or Enable Google Analytics according to your preference.
5. Click **Create project** and wait for provisioning to finish.

---

## Step 2: Enable Anonymous Authentication

1. In the left navigation menu, expand **Build** and select **Authentication**.
2. Click **Get Started**.
3. Under the **Sign-in method** tab, click **Anonymous**.
4. Toggle **Enable** to `ON` and click **Save**.

---

## Step 3: Set Up Cloud Firestore & Security Rules

1. In the left menu, select **Build** -> **Firestore Database**.
2. Click **Create database**.
3. Choose a location closest to your target region (e.g., `asia-south1` for South Asia) and click **Next**.
4. Choose **Start in production mode** (or test mode) and click **Create**.
5. Once created, go to the **Rules** tab in Firestore and replace the existing rules with the following user-isolated security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

6. Click **Publish**.

---

## Step 4: Enable Firebase Storage (Tier 2 - Medicine Photos)

1. Select **Build** -> **Storage** from the left menu.
2. Click **Get started**.
3. Keep default security rules or start in test mode, select your location, and click **Done**.

---

## Step 5: Connect Firebase to your Flutter App

### Option A: Automatic Configuration via FlutterFire CLI (Recommended)

1. Ensure you have Node.js installed, then install Firebase Tools:
   ```bash
   npm install -g firebase-tools
   ```
2. Log into your Firebase account:
   ```bash
   firebase login
   ```
3. Activate the FlutterFire CLI tool:
   ```bash
   dart pub global activate flutterfire_cli
   ```
4. Run configuration inside the Flutter workspace directory (`/home/rahi/Documents/CodeSpace/Flutter/App`):
   ```bash
   flutterfire configure
   ```
   - Select your Firebase project from the list.
   - Select **android** (and any other platforms like ios/web).
   - This automatically generates `lib/firebase_options.dart`.

5. Update `lib/main.dart` to use generated options:
   ```dart
   import 'firebase_options.dart';

   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```

---

### Option B: Manual Android Configuration (`google-services.json`)

If you prefer manual setup for Android:

1. In your Firebase Console Project Overview, click the **Android icon** to register an app.
2. Enter the Android Package Name:
   ```
   com.meditrack.app.meditrack
   ```
3. Click **Register app**.
4. Download the `google-services.json` file.
5. Place `google-services.json` inside the directory:
   ```
   android/app/google-services.json
   ```

---

## Step 6: Verify and Run

Run your Flutter application on an emulator or connected device:

```bash
flutter run
```

Your app will automatically sign in anonymously in the background, allowing you to add medicines and manage dose schedules seamlessly!
