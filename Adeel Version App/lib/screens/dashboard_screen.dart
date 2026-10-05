import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/routes.dart';
import 'support_screen.dart';
import 'account_settings_screen.dart'; // 👈 Account Settings screen import

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Exact theme colors from the visual mockup
  static const Color textDark = Color(0xFF1E1348);
  static const Color textMuted = Color(0xFF757692);
  static const Color bgCanvas = Color(0xFFF2EFFD);
  static const Color primaryPurple = Color(0xFF5B32E8);

  @override
  void initState() {
    super.initState();

    // ── Welcome Pop-up: App open hotay hi ya Login ke baad show hoga ─────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeDialogIfNeeded();
    });
  }

  /// Displays the interactive Welcome Pop-up Dialog
  void _showWelcomeDialogIfNeeded() {
    final user = _auth.currentUser;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email?.split('@').first ?? 'Student');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Icon Badge with gradient
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA855F7), Color(0xFF5B32E8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryPurple.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // Welcome Pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'WELCOME BACK',
                    style: TextStyle(
                      color: primaryPurple,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Greeting Heading
                Text(
                  'Hello, $displayName! 👋',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 8),

                // Welcome message
                const Text(
                  'Ready to boost your study productivity today? Your subjects, handouts, and AI tutor are synced.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: textMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),

                // Pro Tip Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F5FD),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: primaryPurple.withValues(alpha: 0.15),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded,
                          color: primaryPurple, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tip: Ask the AI Tutor to generate a practice quiz',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Let's Study! 🚀",
                      style:
                          TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Opens the Account Settings Screen
  void _openAccountSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgCanvas,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildStudyToolsGrid(context),
                  const SizedBox(height: 26),
                  _buildRecentFilesSection(),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _buildBottomNavigation(),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final User? user = _auth.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid ?? '')
          .snapshots(),
      builder: (context, snapshot) {
        String displayName = '';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          displayName =
              data?['username'] ?? data?['name'] ?? data?['displayName'] ?? '';
        }

        if (displayName.trim().isEmpty) {
          displayName = user?.displayName ?? '';
        }
        if (displayName.trim().isEmpty && user?.email != null) {
          displayName = user!.email!.split('@').first;
        }
        if (displayName.trim().isEmpty) {
          displayName = 'Student';
        }

        final initialLetter =
            displayName.isNotEmpty ? displayName.trim()[0].toUpperCase() : 'S';

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -30,
              left: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD6C8FF).withValues(alpha: 0.45),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $displayName!',
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: textDark,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: const [
                          Flexible(
                            child: Text(
                              "Let's boost your study productivity",
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          Text('🚀', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Profile Avatar Button (Tapping opens Account Settings) ──
                GestureDetector(
                  onTap: _openAccountSettings,
                  child: Tooltip(
                    message: 'Account & Settings',
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF38BDF8)],
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFFE0E7FF),
                          child: Text(
                            initialLetter,
                            style: const TextStyle(
                              color: primaryPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStudyToolsGrid(BuildContext context) {
    final modules = [
      const _ModuleData(
        'Scan Notes',
        Icons.crop_free_rounded,
        AppRoutes.notesUpload,
        [Color(0xFF38BDF8), Color(0xFF2563EB)],
        Color(0xFFE3F2FD),
      ),
      const _ModuleData(
        'AI Chat',
        Icons.forum_rounded,
        AppRoutes.chatbot,
        [Color(0xFFA855F7), Color(0xFF7C3AED)],
        Color(0xFFF3E8FF),
      ),
      const _ModuleData(
        'Study Planner',
        Icons.event_note_rounded,
        AppRoutes.studyPlanner,
        [Color(0xFF34D399), Color(0xFF059669)],
        Color(0xFFD1FAE5),
      ),
      const _ModuleData(
        'Quizzes',
        Icons.help_outline_rounded,
        AppRoutes.quiz,
        [Color(0xFFFBBF24), Color(0xFFD97706)],
        Color(0xFFFEF3C7),
      ),
      const _ModuleData(
        'AI Summaries',
        Icons.article_outlined,
        AppRoutes.aiSummary,
        [Color(0xFFF472B6), Color(0xFFE11D48)],
        Color(0xFFFCE7F3),
      ),
      const _ModuleData(
        'VU Flashcards',
        Icons.style_outlined,
        AppRoutes.flashcards,
        [Color(0xFF818CF8), Color(0xFF4F46E5)],
        Color(0xFFE0E7FF),
      ),
      const _ModuleData(
        'My Subjects',
        Icons.folder_special_rounded,
        AppRoutes.subjects,
        [Color(0xFF6366F1), Color(0xFF4338CA)],
        Color(0xFFEDE9FE),
      ),
      const _ModuleData(
        'Tech Support',
        Icons.support_agent_rounded,
        'support',
        [Color(0xFF9333EA), Color(0xFF581C87)],
        Color(0xFFF5F3FF),
      ),
    ];

    return GridView.builder(
      itemCount: modules.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        return _buildModuleCard(context, modules[index]);
      },
    );
  }

  Widget _buildModuleCard(BuildContext context, _ModuleData module) {
    return GestureDetector(
      onTap: () {
        if (module.route == 'support') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupportScreen()),
          );
        } else if (module.route.isNotEmpty) {
          Navigator.pushNamed(context, module.route);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: module.cardBg.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: module.iconGradient.first.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: module.iconGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: module.iconGradient.first.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                module.icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                module.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentFilesSection() {
    final recentFiles = [
      (
        'Physics-Ch2-\nHandwritten',
        const Color(0xFF7C3AED),
        'Oct 18, 12:45 PM',
      ),
      (
        'Bio-Lecture-\nNotes',
        const Color(0xFF059669),
        'Oct 18, 12:45 PM',
      ),
      (
        'Math-\nFormulas',
        const Color(0xFFEA580C),
        'Oct 18, 12:45 PM',
      ),
      (
        'Water-Cycle-\nDiagram',
        const Color(0xFF0284C7),
        'Oct 17, 04:20 PM',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Files',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: textDark,
                letterSpacing: -0.4,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.subjects);
              },
              child: const Row(
                children: [
                  Text(
                    'View all ',
                    style: TextStyle(
                      color: primaryPurple,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: primaryPurple,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: recentFiles.length,
            itemBuilder: (context, index) {
              final file = recentFiles[index];
              return _buildFileCard(file.$1, file.$2, file.$3);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileCard(String title, Color iconColor, String date) {
    return Container(
      width: 124,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E0F5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 78,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  height: 4,
                  width: 50,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _dummyTextLine(width: 80),
                _dummyTextLine(width: 65),
                _dummyTextLine(width: 75),
                _dummyTextLine(width: 45),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F1F8)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2, right: 5),
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: iconColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Icon(
                        Icons.article_outlined,
                        color: Colors.white,
                        size: 9,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: textDark,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.more_vert_rounded,
                      size: 13,
                      color: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  date,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 7.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dummyTextLine({required double width}) {
    return Container(
      height: 3,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.folder_outlined, 'Folders'),
      (Icons.auto_awesome_rounded, 'AI Assistant'),
      (Icons.settings_outlined, 'Settings'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [Color(0xFF5A31F4), Color(0xFF22D3EE)],
          ),
          boxShadow: [
            BoxShadow(
              color: primaryPurple.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final selected = _currentIndex == index;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _currentIndex = index);

                if (index == 1) {
                  Navigator.pushNamed(context, AppRoutes.subjects);
                } else if (index == 2) {
                  Navigator.pushNamed(context, AppRoutes.chatbot);
                } else if (index == 3) {
                  // ── Settings tap opens Account Settings Screen ──
                  _openAccountSettings();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: selected ? 14 : 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Icon(
                      items[index].$1,
                      color: selected ? primaryPurple : Colors.white,
                      size: 21,
                    ),
                    if (selected) ...[
                      const SizedBox(width: 6),
                      Text(
                        items[index].$2,
                        style: const TextStyle(
                          color: primaryPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ModuleData {
  final String title;
  final IconData icon;
  final String route;
  final List<Color> iconGradient;
  final Color cardBg;

  const _ModuleData(
    this.title,
    this.icon,
    this.route,
    this.iconGradient,
    this.cardBg,
  );
}