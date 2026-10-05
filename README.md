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
- Subject folders support PDF, DOCX, TXT, and image-based note uploads. Extracted syllabus text is saved with page labels for PDFs, while original documents are retained in Firebase Storage.
- The quiz generator uses extracted text from the selected subject folder, a student-specified quiz prompt, and the chosen question count. Document metadata is excluded from quiz generation.
- Chat lets the student choose a persistent response language and can inspect a specified page of an uploaded PDF for diagram questions.
- AI Summary, Chatbot, Quiz, and Flashcards use the saved subject materials.

Original-file uploads require Firebase Storage to be enabled and Storage Rules
to allow authenticated users to read/write only their own
`users/{uid}/subjects/{subjectId}/files/` objects.

Study Planner, Progress, and Support continue to be developed.

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

6. **Add your AI API keys** to the ignored local file
   `config/dev-keys.json` using the `GEMINI_API_KEY`, `OPENROUTER_API_KEY`,
   and `HUGGINGFACE_API_KEY` fields. The app tries Gemini first for image OCR,
   then OpenRouter, then Hugging Face:
   ```bash
   flutter run -d chrome --dart-define-from-file=config/dev-keys.json
   ```

   Make sure each key belongs to its named provider (Google AI Studio keys
   typically start with `AIza`, OpenRouter keys with `sk-or-`, and Hugging Face
   tokens with `hf_`). Do not paste API keys into source code or chat.

   Dart defines are compiled into the web app. Do not use real API keys in a
   publicly deployed web build; use a server-side proxy for production.

7. **Run on mobile** (optional):
   ```bash
   flutter run --dart-define-from-file=config/dev-keys.json
   ```

   To build a release APK with the same configured providers:
   ```bash
   flutter build apk --release --dart-define-from-file=config/dev-keys.json
   ```
   Rebuild the APK whenever API keys or AI service code changes. The keys are
   embedded in the app package, so do not distribute a public APK containing
   personal development keys.

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
