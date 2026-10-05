import 'package:flutter/material.dart';

/// UC-13/UC-14 Track Progress. TODO: wire fl_chart with Firestore data.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  static const Color primary = Color(0xFF6C3CF7);
  static const Color pageBg = Color(0xFFEEEBFD);
  static const Color textDark = Color(0xFF1A1040);
  static const Color textMuted = Color(0xFF5B5E7A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Progress',
            style: TextStyle(
                color: textDark, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF1D6EF5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF1D6EF5).withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 10))
                ],
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  color: Colors.white, size: 48),
            ),
            const SizedBox(height: 28),
            const Text('Progress Tracking',
                style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 24)),
            const SizedBox(height: 12),
            const Text(
                'View your quiz scores and performance charts.\nComing soon!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: textMuted, fontSize: 15, height: 1.5)),
          ]),
        ),
      ),
    );
  }
}
