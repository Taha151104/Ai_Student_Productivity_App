import 'package:flutter/material.dart';
import '../core/routes.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color primary = Color(0xFF6C3CF7);
  static const Color pageBg = Color(0xFFEEEBFD);
  static const Color textDark = Color(0xFF1A1040);
  static const Color textMuted = Color(0xFF5B5E7A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Hero icon
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C3CF7), Color(0xFF06B6D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: primary.withValues(alpha: 0.45),
                          blurRadius: 30,
                          offset: const Offset(0, 12)),
                    ],
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.white, size: 54),
                ),
              ),
              const SizedBox(height: 32),

              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: textDark,
                      height: 1.2),
                  children: [
                    TextSpan(text: 'AI Student\n'),
                    TextSpan(
                        text: 'Productivity', style: TextStyle(color: primary)),
                    TextSpan(text: ' Ecosystem'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Upload notes, get AI summaries,\nand study smarter.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 15, height: 1.5),
              ),

              const Spacer(),

              // Get Started
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6C3CF7), Color(0xFF9B6CF9)]),
                  boxShadow: [
                    BoxShadow(
                        color: primary.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 7))
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.register),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Get Started',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 14),

              // Sign in
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(
                      color: primary.withValues(alpha: 0.5), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('I already have an account',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
