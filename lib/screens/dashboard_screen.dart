import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/routes.dart';
import 'support_screen.dart';
import 'subjects_screen.dart';

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
                  const SizedBox(height: 24),
                  // Dynamic Subject Folders (invisible when empty)
                  _buildSubjectFoldersSection(),
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
                  color: const Color(0xFFD6C8FF).withOpacity(0.45),
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
                Container(
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
              ],
            ),
          ],
        );
      },
    );
  }

  // "My Subjects" removed from Dashboard Grid (accessible via bottom navigation)
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
          color: module.cardBg.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: module.iconGradient.first.withOpacity(0.12),
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
                    color: module.iconGradient.first.withOpacity(0.35),
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

  // Dynamic Subject Folders Section: Invisible initially until folders are created
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
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // If no folders exist, keep section completely invisible
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subject Folders',
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
                        'Manage all ',
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
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unnamed Subject';

                  // Palette rotation for distinct folder gradients
                  final gradients = [
                    [const Color(0xFF6366F1), const Color(0xFF38BDF8)],
                    [const Color(0xFFA855F7), const Color(0xFF7C3AED)],
                    [const Color(0xFF34D399), const Color(0xFF059669)],
                    [const Color(0xFFFBBF24), const Color(0xFFEA580C)],
                  ];
                  final gradient = gradients[index % gradients.length];

                  return _buildSubjectFolderCard(
                    context: context,
                    userId: user.uid,
                    subjectId: doc.id,
                    name: name,
                    gradient: gradient,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Folder card with identical dimensions (124px width, 160px height)
  Widget _buildSubjectFolderCard({
    required BuildContext context,
    required String userId,
    required String subjectId,
    required String name,
    required List<Color> gradient,
  }) {
    return GestureDetector(
      onTap: () {
        // Direct navigation to files & images upload screen for this folder
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubjectDetailScreen(
              userId: userId,
              subjectId: subjectId,
              subjectName: name,
            ),
          ),
        );
      },
      child: Container(
        width: 124,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E0F5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Preview Area
            Container(
              height: 78,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    gradient.first.withOpacity(0.12),
                    gradient.last.withOpacity(0.06),
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: gradient.first.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.folder_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F1F8)),
            // Bottom Info Area
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: textDark,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Real file count stream from subcollection
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('subjects')
                        .doc(subjectId)
                        .collection('files')
                        .snapshots(),
                    builder: (context, fileSnap) {
                      final count = fileSnap.data?.docs.length ?? 0;
                      return Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 10,
                            color: gradient.first,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$count ${count == 1 ? 'file' : 'files'}',
                            style: const TextStyle(
                              color: textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
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
              color: primaryPurple.withOpacity(0.35),
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
