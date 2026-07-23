# Design Specification - Grok AI Integration & AI Assistant Tab

## Overview
Integrate xAI Grok API (`https://api.x.ai/v1`) into MediTrack to provide an interactive AI Health Assistant. The assistant enables users to:
1. Create new medicine routines directly from conversation.
2. Add grocery/buy list items automatically.
3. Attach/paste prescription images for vision analysis (`grok-2-vision-1212`) to extract dosage and schedule details.
4. Get instant answers to health queries, medication usage, side effects, and general wellness tips.
5. Access the assistant via a primary bottom navigation tab replacing the Routine tab (while preserving Routine access on the Home screen).

---

## API Credentials & Key Location
Users can specify their Grok API Key in two places:
1. **Code Location**: `lib/config/api_config.dart`:
   ```dart
   class ApiConfig {
     static const String grokApiKey = 'YOUR_GROK_API_KEY_HERE';
     static const String grokBaseUrl = 'https://api.x.ai/v1';
     static const String grokTextModel = 'grok-beta';
     static const String grokVisionModel = 'grok-2-vision-1212';
   }
   ```
2. **In-App Runtime Setting**:
   - Settings icon in `AiAssistantScreen` app bar allows users to view, input, and save their Grok API Key locally via `SharedPreferences`.

---

## Architecture & Components

### 1. `lib/config/api_config.dart`
- Centralized configuration file holding default API key, base URL, model identifiers, and system prompt.

### 2. `lib/services/grok_ai_service.dart`
- Responsible for HTTP communication with `https://api.x.ai/v1/chat/completions`.
- **Text Chat**: Sends history of messages with system prompt instructing Grok to return natural language responses along with optional JSON action blocks:
  ```json
  {
    "action": "ADD_MEDICINE",
    "name": "Paracetamol",
    "dosage": "500mg",
    "frequency": "2 times daily",
    "times": ["08:00", "20:00"],
    "stock": 30
  }
  ```
  or
  ```json
  {
    "action": "ADD_BUY_ITEM",
    "name": "Vitamin C 1000mg",
    "quantity": 1
  }
  ```
- **Vision Chat**: Converts picked image (`File`) to base64 `data:image/jpeg;base64,...` URL payload and invokes `grok-2-vision-1212`.

### 3. `lib/screens/ai_assistant_screen.dart`
- Primary view for the AI Assistant tab.
- Includes:
  - Scrollable message history list with distinct styling for User and AI messages.
  - Interactive Action Cards rendered inline whenever Grok suggests adding a medicine or buy list item.
  - Image Attachment button (Camera/Gallery) displaying attached thumbnail before sending.
  - Quick Suggestion Chips (*"Add new medicine"*, *"Buy list item"*, *"Analyze prescription"*, *"Health tip"*).
  - API Key Settings Dialog.

### 4. `lib/screens/main_navigation_shell.dart`
- Replaces index 1 (`CalendarRoutineScreen`) with `AiAssistantScreen`.
- Navigation label: `AI Assistant`, Icon: `Icons.auto_awesome`.

### 5. `lib/screens/home_screen.dart`
- Adds a clear button/tile in the header or routine section to open `CalendarRoutineScreen` directly so users can still view their interactive calendar routine.

---

## Verification Plan

### Automated Testing
- `flutter test test/services/grok_ai_service_test.dart` to test payload generation, base64 image encoding, and action JSON parsing.
- `flutter analyze` to ensure 0 errors and 0 warnings.

### Manual Verification
- Verify Grok API Key input in `api_config.dart` and settings dialog.
- Test text prompt sending & receiving AI response.
- Test 1-tap confirmation card for creating routines & buy list items.
- Test attaching prescription image and receiving vision analysis.
