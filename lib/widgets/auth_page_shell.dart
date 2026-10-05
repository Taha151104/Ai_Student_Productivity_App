import 'package:flutter/material.dart';

class AuthPageShell extends StatelessWidget {
  final Widget child;

  const AuthPageShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -75,
            right: -55,
            child: _PastelOrb(
              size: 230,
              color: const Color(0xFFE9D5FF).withValues(alpha: 0.7),
            ),
          ),
          Positioned(
            top: 245,
            left: -110,
            child: _PastelOrb(
              size: 210,
              color: const Color(0xFFBAE6FD).withValues(alpha: 0.5),
            ),
          ),
          Positioned(
            bottom: -105,
            right: -55,
            child: _PastelOrb(
              size: 230,
              color: const Color(0xFFFBCFE8).withValues(alpha: 0.45),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFF1EDFF)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C3CF7).withValues(alpha: 0.1),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color:
                              const Color(0xFF06B6D4).withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: child,
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

class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3CF7).withValues(alpha: 0.26),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child:
          const Icon(Icons.auto_awesome_rounded, size: 36, color: Colors.white),
    );
  }
}

class _PastelOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _PastelOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
