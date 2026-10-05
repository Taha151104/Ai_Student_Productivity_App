import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/routes.dart';
import 'account_settings_screen.dart';
import 'subjects_screen.dart';
import 'support_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 🎨 EDIT ALL YOUR DASHBOARD WIDGET COLORS RIGHT HERE:
// ─────────────────────────────────────────────────────────────────────────────
class DashboardTheme {
  // 1. SCAN NOTES (Blue)
  static const Color scanCard = Color.fromARGB(255, 206, 234, 248);
  static const Color scanBorder = Color.fromARGB(255, 85, 198, 254);
  static const List<Color> scanIcon = [Color(0xFF38BDF8), Color(0xFF0284C7)];

  // 2. AI CHAT (Purple)
  static const Color chatCard = Color.fromARGB(255, 230, 212, 250);
  static const Color chatBorder = Color.fromARGB(255, 189, 119, 255);
  static const List<Color> chatIcon = [Color(0xFFA855F7), Color(0xFF7E22CE)];

  // 3. STUDY PLANNER (Mint / Green)
  static const Color plannerCard = Color.fromARGB(255, 212, 253, 234);
  static const Color plannerBorder = Color.fromARGB(255, 125, 252, 212);
  static const List<Color> plannerIcon = [Color(0xFF34D399), Color(0xFF059669)];

  // 4. QUIZZES (Pure Sunny Yellow)
  static const Color quizCard = Color.fromARGB(255, 255, 250, 210);
  static const Color quizBorder = Color.fromARGB(255, 255, 236, 112);
  static const List<Color> quizIcon = [Color(0xFFFFEA00), Color(0xFFFFB300)];

  // 5. AI SUMMARIES (Vivid Pink-Red)
  static const Color summaryCard = Color.fromARGB(255, 248, 210, 215);
  static const Color summaryBorder = Color.fromARGB(255, 255, 102, 135);
  static const List<Color> summaryIcon = [Color(0xFFFF2E63), Color(0xFFBE123C)];

  // 6. VU FLASHCARDS (Vivid Tangerine Orange)
  static const Color flashcardCard = Color.fromARGB(255, 252, 224, 191);
  static const Color flashcardBorder = Color.fromARGB(255, 255, 150, 93);
  static const List<Color> flashcardIcon = [
    Color(0xFFFF9100),
    Color(0xFFFF5722)
  ];
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Color textDark = Color(0xFF1E1348);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color primaryPurple = Color(0xFF5B32E8);

  void _openAccountSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Atmosphere
          Positioned(
            top: -50,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE9D5FF).withOpacity(0.40),
              ),
            ),
          ),
          Positioned(
            top: 140,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBAE6FD).withOpacity(0.35),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 115),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 22),
                      _buildStudyToolsGrid(context),
                      const SizedBox(height: 18),
                      _buildSupportBanner(context),
                      const SizedBox(height: 26),
                      _buildSubjectFoldersSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
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
          // Check all possible registration keys
          displayName = data?['fullName'] ??
              data?['username'] ??
              data?['name'] ??
              data?['displayName'] ??
              data?['studentName'] ??
              '';
        }

        // Check Firebase Auth profile
        if (displayName.trim().isEmpty &&
            user?.displayName != null &&
            user!.displayName!.isNotEmpty) {
          displayName = user.displayName!;
        }

        // Clean fallback
        if (displayName.trim().isEmpty) {
          displayName = 'Taha';
        }

        final initialLetter =
            displayName.isNotEmpty ? displayName.trim()[0].toUpperCase() : 'T';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showEditNameDialog(context, displayName, user),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Hello, $displayName!',
                            style: const TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.w900,
                              color: textDark,
                              letterSpacing: -0.7,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.edit_rounded,
                            size: 16, color: primaryPurple.withOpacity(0.5)),
                      ],
                    ),
                    const SizedBox(height: 4),
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
            ),
            GestureDetector(
              onTap: () => _showEditNameDialog(context, displayName, user),
              child: CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFFEDE9FE),
                child: Text(
                  initialLetter,
                  style: const TextStyle(
                    color: primaryPurple,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Dialog to edit and permanently save your name in Firestore
  void _showEditNameDialog(
      BuildContext context, String currentName, User? user) {
    if (user == null) return;
    final nameController = TextEditingController(
        text: currentName == 'Taha' ? 'Taha' : currentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Your Name',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Display Name',
            hintText: 'e.g. Taha',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                // Save to Firestore and Firebase Auth
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set({
                  'fullName': newName,
                  'username': newName,
                  'name': newName,
                }, SetOptions(merge: true));
                await user.updateDisplayName(newName);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyToolsGrid(BuildContext context) {
    final modules = [
      _ModuleData(
        title: 'Scan Notes',
        subtitle: 'Scan and digitize\nyour notes',
        icon: Icons.document_scanner_rounded,
        route: AppRoutes.notesUpload,
        cardBg: DashboardTheme.scanCard,
        borderColor: DashboardTheme.scanBorder,
        iconGradient: DashboardTheme.scanIcon,
      ),
      _ModuleData(
        title: 'AI Chat',
        subtitle: 'Ask anything,\nget instant help',
        icon: Icons.chat_bubble_outline_rounded,
        route: AppRoutes.chatbot,
        cardBg: DashboardTheme.chatCard,
        borderColor: DashboardTheme.chatBorder,
        iconGradient: DashboardTheme.chatIcon,
      ),
      _ModuleData(
        title: 'Study Planner',
        subtitle: 'Plan your study\nschedule easily',
        icon: Icons.calendar_month_rounded,
        route: AppRoutes.studyPlanner,
        cardBg: DashboardTheme.plannerCard,
        borderColor: DashboardTheme.plannerBorder,
        iconGradient: DashboardTheme.plannerIcon,
      ),
      _ModuleData(
        title: 'Quizzes',
        subtitle: 'Test your knowledge\nwith quizzes',
        icon: Icons.emoji_events_rounded,
        route: AppRoutes.quiz,
        cardBg: DashboardTheme.quizCard,
        borderColor: DashboardTheme.quizBorder,
        iconGradient: DashboardTheme.quizIcon,
      ),
      _ModuleData(
        title: 'AI Summaries',
        subtitle: 'Get quick summaries\nof your notes',
        icon: Icons.auto_stories_rounded,
        route: AppRoutes.aiSummary,
        cardBg: DashboardTheme.summaryCard,
        borderColor: DashboardTheme.summaryBorder,
        iconGradient: DashboardTheme.summaryIcon,
      ),
      _ModuleData(
        title: 'VU Flashcards',
        subtitle: 'Smart flashcards for\nbetter learning',
        icon: Icons.style_outlined,
        route: AppRoutes.flashcards,
        cardBg: DashboardTheme.flashcardCard,
        borderColor: DashboardTheme.flashcardBorder,
        iconGradient: DashboardTheme.flashcardIcon,
      ),
    ];

    return GridView.builder(
      itemCount: modules.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 11,
        mainAxisSpacing: 13,
        childAspectRatio: 0.74,
      ),
      itemBuilder: (context, index) =>
          _buildModuleCard(context, modules[index]),
    );
  }

  Widget _buildModuleCard(BuildContext context, _ModuleData module) {
    return GestureDetector(
      onTap: () {
        if (module.route.isNotEmpty) Navigator.pushNamed(context, module.route);
      },
      child: Container(
        decoration: BoxDecoration(
          color: module.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: module.borderColor,
            width: 2.0, // Solid border
          ),
          boxShadow: [
            BoxShadow(
              color: module.borderColor.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: module.iconGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: module.iconGradient.first.withOpacity(0.45),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(module.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 9),
            Text(
              module.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: textDark,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              module.subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w600,
                fontSize: 10,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SupportScreen()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC7D2FE), width: 1.4),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF818CF8), Color(0xFF4F46E5)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Need Help with Your Courses?',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: textDark)),
                  Text('Student technical & study support desk',
                      style: TextStyle(color: textMuted, fontSize: 10.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectFoldersSection() {
    final User? user = _auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('subjects')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const SizedBox.shrink();
        final docs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('My Subject Folders',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: textDark)),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.subjects),
                  child: const Text('Manage all →',
                      style: TextStyle(
                          color: primaryPurple,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 165,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Subject Folder';
                  final folderStyle = subjectFolderStyleAt(index);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubjectDetailScreen(
                              userId: user.uid,
                              subjectId: doc.id,
                              subjectName: name,
                              folderStyle: folderStyle),
                        ),
                      );
                    },
                    child: Container(
                      width: 130,
                      decoration: BoxDecoration(
                        color: folderStyle.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: folderStyle.border,
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: folderStyle.accent.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: folderStyle.accent,
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      folderStyle.accent.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.folder_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          const Spacer(),
                          Text(name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: folderStyle.accent,
                              )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
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
              colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)]),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final selected = _currentIndex == index;
            return GestureDetector(
              onTap: () {
                setState(() => _currentIndex = index);
                if (index == 1) {
                  Navigator.pushNamed(context, AppRoutes.subjects);
                } else if (index == 2) {
                  Navigator.pushNamed(context, AppRoutes.chatbot);
                } else if (index == 3) {
                  _openAccountSettings();
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Icon(items[index].$1,
                        color: selected ? primaryPurple : Colors.white,
                        size: 21),
                    if (selected) ...[
                      const SizedBox(width: 6),
                      Text(items[index].$2,
                          style: const TextStyle(
                              color: primaryPurple,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
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
  final String subtitle;
  final IconData icon;
  final String route;
  final Color cardBg;
  final Color borderColor;
  final List<Color> iconGradient;

  _ModuleData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.cardBg,
    required this.borderColor,
    required this.iconGradient,
  });
}
