import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../core/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 🎨 EDIT STUDY PLANNER THEME & COLORS RIGHT HERE:
// ─────────────────────────────────────────────────────────────────────────────
class StudyPlannerTheme {
  static const Color pageBg = Colors.white; // Pure White Canvas
  static const Color emeraldGreen = Color(0xFF059669); // Deep Emerald Primary
  static const Color mintAccent = Color(0xFF10B981); // Bright Mint Green
  static const Color pastelMint = Color(0xFFD1FAE5); // Soft Mint Fill
  static const Color mintBorder = Color(0xFFA7F3D0); // Mint Border Outline
  static const Color copperAccent =
      Color(0xFFC2410C); // Metallic Antique Copper
  static const Color copperLight =
      Color(0xFFFED7AA); // Soft Copper / Peach Tint
  static const Color textDark = Color(0xFF0F172A); // Deep Navy Slate Text
  static const Color textMuted = Color(0xFF64748B); // Muted Slate Grey

  // Gradients
  static const List<Color> emeraldGradient = [
    Color(0xFF34D399),
    Color(0xFF059669)
  ];
  static const List<Color> copperGradient = [
    Color(0xFFFB923C),
    Color(0xFFC2410C)
  ];
}

class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key});

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen>
    with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  final _auth = FirebaseAuth.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _notificationService.init();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentUserId {
    return _auth.currentUser?.uid ?? 'guest_user';
  }

  CollectionReference get _plannerCollection {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('study_plans');
  }

  Future<void> _openAddTaskModal() async {
    final savedTask = await showModalBottomSheet<_SavedStudyTask>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTaskSheet(
        plannerCollection: _plannerCollection,
        notificationService: _notificationService,
        userId: _currentUserId,
      ),
    );
    if (!mounted || savedTask == null) return;

    if (!savedTask.setReminder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study plan saved!')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Study plan saved. Setting up reminder…')),
    );
    try {
      await _notificationService
          .scheduleStudyReminder(
            id: savedTask.notificationId,
            title: savedTask.title,
            subject: savedTask.subject,
            scheduledDate: savedTask.scheduledDate,
          )
          .timeout(const Duration(seconds: 20));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Study reminder scheduled on this phone.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Plan saved, but the reminder could not be set: $error',
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleTaskStatus(DocumentSnapshot doc) async {
    final bool currentStatus = doc['isCompleted'] ?? false;
    await doc.reference.update({'isCompleted': !currentStatus});

    if (!currentStatus && doc['notificationId'] != null) {
      await _notificationService.cancelReminder(doc['notificationId']);
    }
  }

  Future<void> _deleteTask(DocumentSnapshot doc) async {
    if (doc['notificationId'] != null) {
      await _notificationService.cancelReminder(doc['notificationId']);
    }
    await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudyPlannerTheme.pageBg,
      body: Stack(
        children: [
          // ── Atmospheric Background Ambient Circles (Mint & Copper) ──
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StudyPlannerTheme.pastelMint.withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StudyPlannerTheme.copperLight.withOpacity(0.35),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSubjectMasteryTab(),
                      _buildStudyTimersTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTaskModal,
        backgroundColor: StudyPlannerTheme.emeraldGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.alarm_add_rounded),
        label: const Text(
          'Set Study Timer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back,
                color: StudyPlannerTheme.textDark, size: 22),
            onPressed: () => Navigator.maybePop(context),
          ),
          Column(
            children: const [
              Text(
                'Study Planner & Mastery',
                style: TextStyle(
                  color: StudyPlannerTheme.textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(
                'Read-Only Exam Readiness & Timers',
                style: TextStyle(
                  color: StudyPlannerTheme.emeraldGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: StudyPlannerTheme.pastelMint.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StudyPlannerTheme.mintBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: StudyPlannerTheme.emeraldGreen, width: 1.3),
          boxShadow: [
            BoxShadow(
              color: StudyPlannerTheme.emeraldGreen.withOpacity(0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: StudyPlannerTheme.emeraldGreen,
        unselectedLabelColor: StudyPlannerTheme.textMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(
            icon: Icon(Icons.analytics_outlined, size: 18),
            text: 'Subject Mastery (Last 10 Quizzes)',
          ),
          Tab(
            icon: Icon(Icons.alarm_rounded, size: 18),
            text: 'Study Timers & Reminders',
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: Read-Only Subject Preparation Level (Last 10 Quizzes Average)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSubjectMasteryTab() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(
          child: Text('Log in to see your subject preparation level.'));
    }

    return StreamBuilder<QuerySnapshot>(
      // 1. Fetch user's subject folders
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('subjects')
          .snapshots(),
      builder: (context, subjectSnap) {
        if (subjectSnap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: StudyPlannerTheme.emeraldGreen));
        }

        final subjects = subjectSnap.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot>(
          // 2. Fetch all recorded quizzes for this user
          stream: FirebaseFirestore.instance
              .collection(AppConstants.progressCollection)
              .where('userId', isEqualTo: user.uid)
              .orderBy('recordedAt', descending: true)
              .snapshots(),
          builder: (context, quizSnap) {
            final allQuizzes = quizSnap.data?.docs ?? [];

            if (subjects.isEmpty && allQuizzes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: StudyPlannerTheme.pastelMint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          size: 40,
                          color: StudyPlannerTheme.emeraldGreen,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Subject Data Yet',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: StudyPlannerTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create subject folders and take quizzes. The app will calculate your average percentage over the last 10 quizzes automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: StudyPlannerTheme.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Create a list of subjects to display (including user subjects or general fallback)
            final subjectNames = subjects.isNotEmpty
                ? subjects
                    .map((s) =>
                        (s.data() as Map<String, dynamic>)['name'] ?? 'Course')
                    .toList()
                : ['CS101 (Sample Subject)'];

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: subjectNames.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final subjectName = subjectNames[index].toString();

                // Filter the last 10 quizzes relevant to this subject
                final matchingQuizzes = allQuizzes
                    .where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final topic =
                          (data['quizTopic'] ?? '').toString().toLowerCase();
                      return (index < subjects.length &&
                              data['subjectId'] == subjects[index].id) ||
                          topic.contains(subjectName.toLowerCase()) ||
                          subjects.length == 1;
                    })
                    .take(10)
                    .toList();

                // Compute Average Percentage
                double avgPercentage = 0.0;
                int totalCalculated = matchingQuizzes.length;

                if (totalCalculated > 0) {
                  int totalScore = 0;
                  int totalQuestions = 0;
                  for (final q in matchingQuizzes) {
                    final data = q.data() as Map<String, dynamic>;
                    totalScore += (data['score'] ?? 0) as int;
                    totalQuestions += (data['totalQuestions'] ?? 1) as int;
                  }
                  if (totalQuestions > 0) {
                    avgPercentage = (totalScore / totalQuestions) * 100;
                  }
                }

                return _buildSubjectMasteryCard(
                  subjectName: subjectName,
                  quizzesCount: totalCalculated,
                  averagePercentage: avgPercentage,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSubjectMasteryCard({
    required String subjectName,
    required int quizzesCount,
    required double averagePercentage,
  }) {
    final int roundedPercent = averagePercentage.round();

    // Preparation level categorization (Read-only)
    String prepLabel = 'No Quizzes Taken';
    Color levelColor = StudyPlannerTheme.textMuted;
    if (quizzesCount > 0) {
      if (roundedPercent >= 75) {
        prepLabel = 'High Exam Readiness';
        levelColor = StudyPlannerTheme.emeraldGreen;
      } else if (roundedPercent >= 50) {
        prepLabel = 'Moderate Preparation';
        levelColor = const Color(0xFFD97706); // Amber
      } else {
        prepLabel = 'Needs More Revision';
        levelColor = StudyPlannerTheme.copperAccent;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: quizzesCount > 0
              ? StudyPlannerTheme.mintBorder
              : const Color(0xFFE2E8F0),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: StudyPlannerTheme.emeraldGreen.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: StudyPlannerTheme.emeraldGradient,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_special_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    subjectName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: StudyPlannerTheme.textDark,
                    ),
                  ),
                ],
              ),
              // Read-only indicator pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: StudyPlannerTheme.copperLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: StudyPlannerTheme.copperAccent.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 11, color: StudyPlannerTheme.copperAccent),
                    SizedBox(width: 3),
                    Text(
                      'READ-ONLY EVALUATION',
                      style: TextStyle(
                        color: StudyPlannerTheme.copperAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Metric: "How well the user knows the subject"
          Text(
            quizzesCount > 0
                ? 'How well the user knows the subject: $roundedPercent%'
                : 'How well the user knows the subject: Pending Quizzes',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: levelColor,
            ),
          ),
          const SizedBox(height: 6),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: quizzesCount > 0 ? (roundedPercent / 100) : 0.05,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(levelColor),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                quizzesCount > 0
                    ? 'Based on last $quizzesCount quiz attempts'
                    : 'Take quizzes in Quiz Studio to evaluate',
                style: const TextStyle(
                  color: StudyPlannerTheme.textMuted,
                  fontSize: 11.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  prepLabel,
                  style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: Study Timers & Local Notifications
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildStudyTimersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _plannerCollection.orderBy('dueDate', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: StudyPlannerTheme.emeraldGreen));
        }

        final tasks = snapshot.data?.docs ?? [];

        if (tasks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: StudyPlannerTheme.pastelMint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.alarm_on_rounded,
                      size: 38,
                      color: StudyPlannerTheme.emeraldGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Study Timers Scheduled',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: StudyPlannerTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap "Set Study Timer" below to schedule exam reminders on your device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: StudyPlannerTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = tasks[index];
            final data = doc.data() as Map<String, dynamic>;

            final title = data['title'] ?? 'Study Plan';
            final subject = data['subject'] ?? 'General';
            final isCompleted = data['isCompleted'] ?? false;
            final Timestamp? dueTimestamp = data['dueDate'];
            final dueDate = dueTimestamp?.toDate() ?? DateTime.now();
            final isOverdue = dueDate.isBefore(DateTime.now()) && !isCompleted;

            return Dismissible(
              key: Key(doc.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              onDismissed: (_) => _deleteTask(doc),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOverdue
                        ? StudyPlannerTheme.copperAccent.withOpacity(0.5)
                        : StudyPlannerTheme.mintBorder,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Checkbox(
                    value: isCompleted,
                    activeColor: StudyPlannerTheme.emeraldGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => _toggleTaskStatus(doc),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: isCompleted
                          ? Colors.grey
                          : StudyPlannerTheme.textDark,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: StudyPlannerTheme.pastelMint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          subject,
                          style: const TextStyle(
                            color: StudyPlannerTheme.emeraldGreen,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: isOverdue
                            ? StudyPlannerTheme.copperAccent
                            : StudyPlannerTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, h:mm a').format(dueDate),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              isOverdue ? FontWeight.bold : FontWeight.normal,
                          color: isOverdue
                              ? StudyPlannerTheme.copperAccent
                              : StudyPlannerTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.grey, size: 20),
                    onPressed: () => _deleteTask(doc),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal Bottom Sheet: Schedule New Timer & Local Notification
// ─────────────────────────────────────────────────────────────────────────────
class _AddTaskSheet extends StatefulWidget {
  final CollectionReference plannerCollection;
  final NotificationService notificationService;
  final String userId;

  const _AddTaskSheet({
    required this.plannerCollection,
    required this.notificationService,
    required this.userId,
  });

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _SavedStudyTask {
  final int notificationId;
  final String title;
  final String subject;
  final DateTime scheduledDate;
  final bool setReminder;

  const _SavedStudyTask({
    required this.notificationId,
    required this.title,
    required this.subject,
    required this.scheduledDate,
    required this.setReminder,
  });
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleController = TextEditingController();
  String? _selectedSubject;
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  bool _setReminder = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );

    if (pickedTime == null) return;

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    final subject = _selectedSubject ?? 'General';

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a study task title')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final int notificationId =
          DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await widget.plannerCollection.add({
        'title': title,
        'subject': subject,
        'dueDate': Timestamp.fromDate(_selectedDate),
        'isCompleted': false,
        'notificationId': _setReminder ? notificationId : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(
          context,
          _SavedStudyTask(
            notificationId: notificationId,
            title: title,
            subject: subject,
            scheduledDate: _selectedDate,
            setReminder: _setReminder,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Schedule Study Session',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: StudyPlannerTheme.textDark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'What are you studying?',
              hintText: 'e.g., Chapter 1 MCQs, Midterm Revision',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          // Subject Selector from user's Cloud Subject folders
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .collection('subjects')
                .snapshots(),
            builder: (context, snap) {
              final subjects = snap.data?.docs ?? [];
              return DropdownButtonFormField<String>(
                value: _selectedSubject,
                decoration: InputDecoration(
                  labelText: 'Subject Folder',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                hint: const Text('Select Subject'),
                items: subjects.map((d) {
                  final name = d['name'] ?? 'Subject';
                  return DropdownMenuItem<String>(
                      value: name, child: Text(name));
                }).toList(),
                onChanged: (val) => setState(() => _selectedSubject = val),
              );
            },
          ),

          const SizedBox(height: 14),

          // Date & Time Picker
          InkWell(
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: StudyPlannerTheme.mintBorder),
                borderRadius: BorderRadius.circular(12),
                color: StudyPlannerTheme.pastelMint.withOpacity(0.3),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm,
                      color: StudyPlannerTheme.emeraldGreen),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scheduled Date & Time',
                        style: TextStyle(
                            fontSize: 11, color: StudyPlannerTheme.textMuted),
                      ),
                      Text(
                        DateFormat('EEEE, MMM d, yyyy - h:mm a')
                            .format(_selectedDate),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Set Local Alarm Notification',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            subtitle: const Text(
              'Notifies you on this phone when it is time to study',
              style:
                  TextStyle(fontSize: 11.5, color: StudyPlannerTheme.textMuted),
            ),
            activeColor: StudyPlannerTheme.emeraldGreen,
            value: _setReminder,
            onChanged: (val) => setState(() => _setReminder = val),
          ),

          const SizedBox(height: 14),

          ElevatedButton(
            onPressed: _isSaving ? null : _saveTask,
            style: ElevatedButton.styleFrom(
              backgroundColor: StudyPlannerTheme.emeraldGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Save Plan & Set Timer',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
