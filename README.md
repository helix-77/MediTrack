# MediTrack - Flutter Medicine Manager App

**MediTrack** is a smart, comprehensive Android medicine management application built with Flutter. It helps users organize schedules, track daily dosages, scan prescriptions using AI/OCR, store medical records securely, and receive timely local & SMS notifications.

---

## 🌟 Key Features

- 💊 **Medication Tracking & Reminders**: Set precise schedules with local notifications powered by `flutter_local_notifications` and timezone support.
- 🤖 **AI Assistant**: Get medication guidance and health insights powered by Firebase AI (Gemini API).
- 📷 **OCR Prescription Scanner**: Automatically scan and extract medicine details from physical prescription images using Google ML Kit Text Recognition.
- 📁 **Prescription Vault**: Securely upload and manage digital copies of prescriptions and medical records via Firebase Storage.
- 📅 **Calendar & Daily Routine**: View and track past and upcoming medication schedules with interactive calendar controls.
- 🛒 **Medicine Buy List**: Keep track of low-stock medications and manage restocking lists.
- 🔐 **Firebase Authentication**: Support for Anonymous sign-in, Email/Password, and Google Sign-In.
- 📱 **BDApps SMS Integration**: Backend support for SMS subscription alerts and notifications.

---

## 🏗 Tech Stack & Architecture

- **Frontend**: [Flutter](https://flutter.dev) (Dart 3.6+ with Null Safety)
- **Backend & Database**: Firebase Auth, Cloud Firestore, Firebase Storage
- **Machine Learning / AI**: Google ML Kit Text Recognition, Firebase AI (Gemini API)
- **Local Notifications**: `flutter_local_notifications`, `timezone`
- **State Management & UI**: Provider, Material Design 3

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.44+ stable)
- Android Studio / Android SDK
- Java JDK 17+

### Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd App
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables**:
   Ensure `.env` file is configured with necessary API keys and Firebase credentials (refer to `.env.example`).

4. **Run the App**:
   ```bash
   flutter run
   ```

---

## 📦 Building the Release APK

To generate the production APK for Android:

```bash
flutter build apk --release
```

The output binary will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 🧪 Code Quality & Verification

MediTrack follows strict Flutter code conventions:

```bash
flutter analyze
```

All code passes static analysis with 0 errors and 0 warnings.
