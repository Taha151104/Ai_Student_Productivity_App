import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'core/routes.dart';
import 'screens/dashboard_screen.dart';
import 'screens/welcome_screen.dart';
import 'widgets/auth_page_shell.dart';

void main() async {
  // Ensure Flutter engine bindings are ready before running async code
  WidgetsFlutterBinding.ensureInitialized();

  bool isFirebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(MyApp(isFirebaseInitialized: isFirebaseInitialized));
}

class MyApp extends StatelessWidget {
  final bool isFirebaseInitialized;

  const MyApp({super.key, required this.isFirebaseInitialized});

  @override
  Widget build(BuildContext context) {
    // Centralized brand colors
    const primaryPurple = Color(0xFF5B32E8);
    const backgroundLight = Color(0xFFF2EFFD);

    return MaterialApp(
      title: 'AI Student Productivity App',
      debugShowCheckedModeBanner: false,

      // Clean, centralized theme configuration
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryPurple,
          primary: primaryPurple,
          surface: backgroundLight,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: backgroundLight,
      ),

      // Handle Firebase failure gracefully at startup
      home: isFirebaseInitialized
          ? const AuthGate()
          : const InitializationErrorScreen(),

      routes: AppRoutes.routes,
      onUnknownRoute: AppRoutes.onUnknownRoute,
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _initialAuthStateResolved = false;

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AuthBrandMark(),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              color: Color(0xFF6C3CF7),
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 14),
            Text(
              'Getting your study space ready…',
              style: TextStyle(
                color: Colors.deepPurple.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Stream<User?> _authStream() {
    if (Firebase.apps.isEmpty) {
      return const Stream<User?>.empty();
    }

    try {
      return FirebaseAuth.instance.authStateChanges();
    } catch (_) {
      return const Stream<User?>.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return _buildLoadingScreen();
    }

    return StreamBuilder<User?>(
      stream: _authStream(),
      builder: (context, snapshot) {
        // ConnectionState.waiting happens briefly on fresh boot
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        final isInitialResolution = !_initialAuthStateResolved;
        _initialAuthStateResolved = true;

        // Active session found
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          if (!isInitialResolution) return const DashboardScreen();
          final username = user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : user.email?.split('@').first ?? 'there';
          return PostAuthWelcomeScreen(username: username);
        }

        // Give signed-out users a warm introduction before authentication.
        return const WelcomeScreen();
      },
    );
  }
}

// Fallback screen if Firebase fails entirely (e.g., config error, critical network blockage)
class InitializationErrorScreen extends StatelessWidget {
  const InitializationErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(24.0),
        key: Key('fb_init_error'),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
              SizedBox(height: 16),
              Text(
                'Connection Error',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'We could not connect to the productivity servers. Please restart the app or check your internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
