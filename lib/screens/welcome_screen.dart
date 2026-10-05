import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/routes.dart';
import 'dashboard_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color primary = Color(0xFF6C3CF7);
  static const Color textDark = Color(0xFF1E1348);
  static const Color textMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const _WelcomeOrb(
            alignment: Alignment(-1.25, -1.15),
            size: 250,
            color: Color(0x66E9D5FF),
          ),
          const _WelcomeOrb(
            alignment: Alignment(1.2, -0.5),
            size: 190,
            color: Color(0x55BAE6FD),
          ),
          const _WelcomeOrb(
            alignment: Alignment(1.15, 1.1),
            size: 240,
            color: Color(0x55FBCFE8),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 116,
                        height: 116,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF8B5CF6),
                              Color(0xFF06B6D4),
                              Color(0xFF34D399),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.24),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 56,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'YOUR NEXT BIG IDEA\nSTARTS HERE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF6C3CF7),
                          fontSize: 11,
                          letterSpacing: 2,
                          height: 1.4,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Make study time\n✨ your time ✨',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textDark,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1.12,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'A colorful little space to learn, create, and feel good about your progress.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 15,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 9,
                        runSpacing: 9,
                        children: [
                          _FeaturePill(
                            icon: Icons.auto_awesome_rounded,
                            label: 'AI study tools',
                            color: Color(0xFF7E22CE),
                            background: Color(0xFFF3E8FF),
                          ),
                          _FeaturePill(
                            icon: Icons.menu_book_rounded,
                            label: 'Your notes',
                            color: Color(0xFF0284C7),
                            background: Color(0xFFE0F2FE),
                          ),
                          _FeaturePill(
                            icon: Icons.trending_up_rounded,
                            label: 'Your progress',
                            color: Color(0xFF059669),
                            background: Color(0xFFD1FAE5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 34),
                      _GradientButton(
                        label: 'Get Started',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.register),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.login),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primary,
                            side: const BorderSide(
                              color: Color(0xFFD8B4FE),
                              width: 1.4,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'I already have an account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PostAuthWelcomeScreen extends StatefulWidget {
  final String username;

  const PostAuthWelcomeScreen({super.key, required this.username});

  @override
  State<PostAuthWelcomeScreen> createState() => _PostAuthWelcomeScreenState();
}

class _PostAuthWelcomeScreenState extends State<PostAuthWelcomeScreen> {
  static const Color primary = Color(0xFF6C3CF7);
  static const Color textDark = Color(0xFF1E1348);
  static const Color textMuted = Color(0xFF64748B);
  static const String _welcomeShownKey = 'has_seen_dashboard_welcome';
  late String _welcomeUsername;

  @override
  void initState() {
    super.initState();
    _welcomeUsername =
        widget.username.trim().isEmpty ? 'there' : widget.username;
    unawaited(_loadAppAndContinue());
  }

  Future<void> _loadAppAndContinue() async {
    final startedAt = DateTime.now();
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_welcomeShownKey) == true) {
      _openDashboard();
      return;
    }

    final remaining =
        const Duration(seconds: 5) - DateTime.now().difference(startedAt);
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    if (!mounted) return;

    await preferences.setBool(_welcomeShownKey, true);
    _openDashboard();
  }

  void _openDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const _WelcomeOrb(
            alignment: Alignment(-1.2, -1.1),
            size: 240,
            color: Color(0x66E9D5FF),
          ),
          const _WelcomeOrb(
            alignment: Alignment(1.2, 1.05),
            size: 230,
            color: Color(0x55BAE6FD),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF8B5CF6),
                            Color(0xFF06B6D4),
                            Color(0xFF34D399),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.waving_hand_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '$_greeting,',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: textMuted,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_welcomeUsername! 🎉',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'We’re happy you’re here.\nYour study space is getting ready…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const SizedBox(
                      width: 25,
                      height: 25,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6C3CF7), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3CF7).withValues(alpha: 0.23),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 17),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _WelcomeOrb extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final Color color;

  const _WelcomeOrb({
    required this.alignment,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}
