# MediTrack - Flutter Medicine Manager App

**MediTrack** is a smart, comprehensive Android medicine management application built with Flutter. It helps users organize schedules, track daily dosages, scan prescriptions using AI/OCR, store medical records securely, and receive timely local & SMS notifications.

---

## 🌟 Key Features

- 💊 **Medication Tracking & Reminders**: Set precise schedules with local notifications powered by `flutter_local_notifications` and timezone support (Free forever).
- 📷 **OCR Box Scanner & Vault**: Fast on-device medicine box recognition and secure prescription storage (Free forever).
- 📅 **Calendar & Daily Routine**: Interactive calendar medication schedules and refill tracker (Free forever).
- 🛒 **Medicine Buy List**: Keep track of low-stock medications and restocking lists (Free forever).
- ⭐ **MediTrack Premium (BD Apps Carrier Micro-Subscription - ৳2.78/day)**:
  - 🤖 **AI Assistant**: Multimodal Gemini 3.6 Flash health insights and advice.
  - 📝 **AI Prescription OCR**: Structured dosage and schedule extraction from prescription photos.
  - 🔍 **Medicine Price & Generic Lookup**: Price checking and generic alternative finder.
  - 🏥 **Nearby Pharmacies**: Real-time pharmacy locator with GPS and direct dialing.
- 🔐 **Firebase Authentication**: Seamless Anonymous Guest, Email/Password, and Google Sign-In.
- 📱 **BD Apps Carrier Billing**: Direct Robi / Airtel carrier billing integration with OTP fallback.

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
