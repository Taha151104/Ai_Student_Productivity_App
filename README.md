# AI Student Productivity Ecosystem App — Framework

This is the navigation/architecture skeleton for the CS619 prototype. It matches
the Design Document's Three-Tier architecture (Client / Logic / Data) and the
ERD's 10 entities. Every module has a placeholder screen wired into navigation,
so the app runs end-to-end from day one — features get filled in one at a time.

## What's included

```
lib/
  core/           # theme, routes, constants — shared config
  models/         # 10 data models matching the ERD exactly
  services/       # AuthService, FirestoreService, OcrService, AiService, NotificationService
  screens/        # one screen per module (Welcome, Register, Login, Dashboard,
                  # Subjects, Notes Upload+OCR, AI Summary, Chatbot, Quiz,
                  # Flashcards, Study Planner, Progress, Support)
  main.dart       # app entry point, Firebase init, auth-aware routing
pubspec.yaml      # all dependencies pre-added
```

**Already functional (not just placeholders):**
- Welcome → Register/Login → Dashboard navigation
- Firebase Auth (email/password + Google Sign-In) wiring in `auth_service.dart`
- Image picker → ML Kit OCR text extraction (`notes_upload_screen.dart`)
- Gemini API call for AI Summary + Chatbot (`ai_service.dart`)

**Still placeholders (Quiz, Flashcards, Study Planner, Progress, Support):**
Each screen has a comment block telling you exactly what to wire up and to
which use case it maps.

## Setup steps (run these locally — this sandbox can't run Flutter)

1. **Create the Flutter project shell** (generates android/ios folders this
   skeleton doesn't include):
   ```bash
   flutter create --org com.cs619.aistudent ai_student_productivity_app
   ```

2. **Copy this `lib/` folder and `pubspec.yaml`** into the generated project,
   overwriting the defaults.

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Connect Firebase:**
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This generates `firebase_options.dart`. Then in `main.dart`, swap:
   ```dart
   await Firebase.initializeApp();
   ```
   for:
   ```dart
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
   ```

5. **Enable Firebase Auth methods** (Email/Password + Google) and **create a
   Firestore database** in the Firebase Console.

6. **Add your Gemini API key** at run time (never hardcode it):
   ```bash
   flutter run --dart-define=GEMINI_API_KEY=your_key_here
   ```

7. **Run it:**
   ```bash
   flutter run --dart-define=GEMINI_API_KEY=your_key_here
   ```

## Suggested build order (matches the "framework first, features one by one" plan)

1. Firebase Auth end-to-end (Register → Login → Dashboard) — mostly done, just needs Firebase connected
2. Subjects/folders (simplest CRUD, good warm-up)
3. Notes upload + OCR (already scaffolded)
4. AI Summary (already scaffolded — this + #3 completes the required demo workflow)
5. AI Chatbot (already scaffolded)
6. Quiz generation
7. Flashcards
8. Study Planner + Notifications
9. Progress tracking
10. Technical Support

Steps 1–5 alone satisfy all 12 official prototype requirements. Steps 6–9
cover the additional features your supervisor said must be included.
