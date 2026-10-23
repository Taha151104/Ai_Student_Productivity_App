# AI Student Productivity Ecosystem App — Framework

This is the navigation/architecture skeleton for the CS619 prototype. It matches
the Design Document's Three-Tier architecture (Client / Logic / Data) and the
ERD's 10 entities. Every module has a placeholder screen wired into navigation,
so the app runs end-to-end from day one — features get filled in one at a time.

## What's included

```\
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
- Subject folders support PDF, DOCX, TXT, and image-based note uploads. Extracted syllabus text is saved with page labels for PDFs, while original documents are retained in Firebase Storage.
- The quiz generator uses extracted text from the selected subject folder, a student-specified quiz prompt, and the chosen question count. Document metadata is excluded from quiz generation.
- Chat lets the student choose a persistent response language and can inspect a specified page of an uploaded PDF for diagram questions.
- AI Summary, Chatbot, Quiz, and Flashcards use the saved subject materials.

Original-file uploads require Firebase Storage to be enabled and Storage Rules
to allow authenticated users to read/write only their own
`users/{uid}/subjects/{subjectId}/files/` objects.

Study Planner, Progress, and Support continue to be developed.

## Firebase feature setup

- Enable Email/Password and Google providers in Firebase Authentication.
- Enable Firestore and Firebase Storage, and configure rules so signed-in users
  can access only their own data and uploaded files.
- AI features call the Gemini API directly from the app. For local runs and
  APK builds, pass the key from the ignored `config/dev-keys.json`:
  ```powershell
  flutter run -d chrome --dart-define-from-file=config\dev-keys.json
  flutter build apk --release --dart-define-from-file=config\dev-keys.json
  ```
  The API key is embedded in the built app and can be extracted from the APK.
  Keep the APK private, restrict the key in Google AI Studio where possible,
  and rotate the key if the APK is shared or lost. No Node.js proxy or Firebase
  Functions deployment is needed for AI requests.
- Mobile study reminders use local notifications. Web reminders use browser
  notifications and are scheduled only while the app tab stays open; background
  web push requires a separate push-service setup.

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

6. **Configure Gemini.** Put your Gemini API key in the ignored
   `config/dev-keys.json` as the `GEMINI_API_KEY` value. Run the app or build
   the APK with the key supplied at compile time:
   ```bash
   flutter run -d chrome --dart-define-from-file=config/dev-keys.json
   flutter build apk --release --dart-define-from-file=config/dev-keys.json
   ```
   The key is included in the app binary. Do not commit the key file or share
   APKs built with your personal key. No Node.js proxy or Firebase Functions
   deployment is needed for AI requests.

7. **Run on mobile** (optional):
   ```bash
   flutter run
   ```

   To build a release APK with the same configured providers:
   ```bash
   flutter build apk --release
   ```
   Rebuild the APK whenever the app code changes.

## Suggested build order (matches the "framework first, features one by one" plan)

1. Firebase Auth end-to-end (Register → Login → Dashboard) — mostly done, just needs Firebase connected
2. Subjects/folders (simplest CRUD, good warm-up)
3. Notes upload + OCR (already scaffolded)
4. AI Summary (already scaffolded — this + #3 completes the required workflow)
5. AI Chatbot (already scaffolded)
6. Quiz generation
7. Flashcards
8. Study Planner + Notifications
9. Progress tracking
10. Technical Support

Steps 1–5 alone satisfy all 12 official prototype requirements. Steps 6–9
cover the additional features your supervisor said must be included.
