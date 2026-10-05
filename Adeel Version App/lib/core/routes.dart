import 'package:flutter/material.dart';

import '../screens/register_screen.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/subjects_screen.dart';
import '../screens/notes_upload_screen.dart';
import '../screens/ai_summary_screen.dart';
import '../screens/chatbot_screen.dart';
import '../screens/quiz_screen.dart';
import '../screens/flashcards_screen.dart';
import '../screens/study_planner_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/support_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String welcome = '/';
  static const String register = '/register';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String subjects = '/subjects';
  static const String notesUpload = '/notes-upload';
  static const String aiSummary = '/ai-summary';
  static const String chatbot = '/chatbot';
  static const String quiz = '/quiz';
  static const String flashcards = '/flashcards';
  static const String studyPlanner = '/study-planner';
  static const String progress = '/progress';
  static const String support = '/support';

  static Map<String, WidgetBuilder> get routes => {
        register: (_) => const RegisterScreen(),
        login: (_) => const LoginScreen(),
        dashboard: (_) => const DashboardScreen(),
        subjects: (_) => const SubjectsScreen(),
        notesUpload: (_) => const NotesUploadScreen(),
        aiSummary: (_) => const AiSummaryScreen(),
        chatbot: (_) => const ChatbotScreen(),
        quiz: (_) => const QuizScreen(),
        flashcards: (_) => const FlashcardsScreen(),
        studyPlanner: (_) => const StudyPlannerScreen(),
        progress: (_) => const ProgressScreen(),
        support: (_) => const SupportScreen(),
      };
}
