import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysync/features/ai_coach/backlog_screen.dart';
import 'package:studysync/features/ai_coach/notes_to_quiz_screen.dart';
import 'package:studysync/features/ai_coach/roadmap_screen.dart';
import '../tasks/screens/ai_service.dart';
import '../focus/controller/focus_controller.dart';
import 'backlog_service.dart';
import '../dashboard/widgets/offline_banner.dart';
import '../../core/services/network_service.dart';

class AICoachScreen extends StatefulWidget {
  const AICoachScreen({super.key});

  @override
  State<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends State<AICoachScreen> with SingleTickerProviderStateMixin {
  late FocusController _focusController;
  final AIService _aiService = AIService();
  
  String _coachingMessage = "Analyzing your study scope... 🤖";
  bool _isCoachingLoading = false;
  late AnimationController _refreshAnimController;

  bool _isOffline = false;
  bool _isCheckingConnection = false;

  @override
  void initState() {
    super.initState();
    _focusController = FocusController();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _loadCoachingAdvice();
  }

  @override
  void dispose() {
    _refreshAnimController.dispose();
    super.dispose();
  }

  Future<void> _checkInternetConnection() async {
    if (_isCheckingConnection) return;
    setState(() {
      _isCheckingConnection = true;
    });
    final hasInternet = await NetworkService().hasInternet();
    setState(() {
      _isOffline = !hasInternet;
      _isCheckingConnection = false;
    });
    if (hasInternet) {
      _loadCoachingAdvice(forceRefresh: true);
    } else {
      HapticFeedback.vibrate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Still offline. Check your internet connection."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Load or generate dynamic advice using student context metrics
  Future<void> _loadCoachingAdvice({bool forceRefresh = false}) async {
    if (_isCoachingLoading) return;

    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      final prefs = await SharedPreferences.getInstance();
      final cachedMsg = prefs.getString("cached_coaching_msg") ?? "";
      setState(() {
        _isOffline = true;
        _isCoachingLoading = false;
        if (cachedMsg.isNotEmpty) {
          _coachingMessage = "$cachedMsg\n\n⚠️ (Offline mode: Advice is cached)";
        } else {
          _coachingMessage = "StudySync Coach is offline. Please check your internet connection and try again. ⚡";
        }
      });
      return;
    }

    setState(() {
      _isOffline = false;
      _isCoachingLoading = true;
      if (forceRefresh) {
        _coachingMessage = "Sync is compiling recommendations... 🤖";
        _refreshAnimController.repeat();
      }
    });

    try {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month}-${now.day}";
      final prefs = await SharedPreferences.getInstance();

      if (!forceRefresh) {
        final cachedDate = prefs.getString("coaching_msg_date") ?? "";
        final cachedMsg = prefs.getString("cached_coaching_msg") ?? "";
        if (cachedDate == todayStr && cachedMsg.isNotEmpty) {
          setState(() {
            _coachingMessage = cachedMsg;
            _isCoachingLoading = false;
          });
          return;
        }
      }

      // Query real-time data for context
      // 1. Fetch pending tasks due today
      final tasksQuery = await FirebaseFirestore.instance
          .collection("tasks")
          .where("isDone", isEqualTo: false)
          .get();
      
      final todayTasks = tasksQuery.docs.where((doc) {
        final data = doc.data();
        if (data['dueDateTime'] == null) return false;
        final due = (data['dueDateTime'] as Timestamp).toDate();
        return DateUtils.isSameDay(due, now);
      }).map((doc) => (doc.data()['title'] ?? '').toString()).toList();

      // 2. Fetch backlog counts
      final backlogCount = await BacklogService().getPendingCount().first;

      // 3. Fetch study minutes today
      final days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
      final dayKey = days[now.weekday % 7];
      final minutesToday = _focusController.weeklyMinutes[dayKey] ?? 0;

      // Generate coaching suggestion from Gemini
      final advice = await _aiService.generateCoachingMessage(
        minutesToday: minutesToday,
        pendingBacklogs: backlogCount,
        focusLevel: _focusController.level,
        focusRank: _focusController.getRankName(),
        todayTasks: todayTasks,
      );

      // Save to cache
      await prefs.setString("coaching_msg_date", todayStr);
      await prefs.setString("cached_coaching_msg", advice);

      setState(() {
        _coachingMessage = advice;
        _isCoachingLoading = false;
      });
    } catch (e) {
      setState(() {
        _coachingMessage = "Ready to conquer today's study block? Pick a task, start focus zone, and let's crush it! ⚡";
        _isCoachingLoading = false;
      });
    } finally {
      _refreshAnimController.stop();
      _refreshAnimController.reset();
    }
  }

  // Premium Glassmorphic card structure
  Widget _buildGlassCard({required Widget child, double blur = 15, double opacity = 0.05, Color borderColor = Colors.white10}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            border: Border.all(color: borderColor, width: 1.2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    final dayKey = days[now.weekday % 7];
    final minutesToday = _focusController.weeklyMinutes[dayKey] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xff020617),
      appBar: AppBar(
        title: const Text("🤖 AI Coach", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Cyber-glass background glows
          Positioned(
            top: -80,
            left: -80,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: const Color(0xff6366f1).withOpacity(0.08),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: const Color(0xffa855f7).withOpacity(0.06),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isOffline) ...[
                    OfflineBanner(
                      onRetry: _checkInternetConnection,
                      isRetrying: _isCheckingConnection,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 1. Student Info Rank Badge (Top Card)
                  _buildStudentHeaderCard(minutesToday),
                  const SizedBox(height: 20),

                  // 2. Holographic Coach Says Chat Card (Dynamic)
                  _buildCoachingSaysCard(),
                  const SizedBox(height: 24),

                  // 3. Today's Plan Row
                  _buildTodayPlanCard(),
                  const SizedBox(height: 24),

                  // 4. Feature Navigation Layout (Roadmap, Backlog, Notes to Quiz)
                  const Text("AI Study Modules", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  _buildModulesGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Header metric card
  Widget _buildStudentHeaderCard(int minutesToday) {
    final lvl = _focusController.level;
    final rank = _focusController.getRankName();
    final int nextLvlXp = _focusController.xpNeededForNextLevel();
    final double lvlProgress = (_focusController.xp / nextLvlXp).clamp(0.0, 1.0);

    return _buildGlassCard(
      opacity: 0.08,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff6366f1).withOpacity(0.12),
                border: Border.all(color: const Color(0xff6366f1).withOpacity(0.3), width: 1.5),
              ),
              child: const Icon(Icons.school_rounded, color: Color(0xff6366f1), size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rank.toUpperCase(),
                    style: const TextStyle(color: Color(0xff6366f1), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Focus Level $lvl",
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: lvlProgress,
                      minHeight: 5,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff6366f1)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${_focusController.xp} / ${nextLvlXp} XP",
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                      Text(
                        "Today: ${minutesToday}m",
                        style: const TextStyle(color: Color(0xff10b981), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Coaching advice bubble
  Widget _buildCoachingSaysCard() {
    return _buildGlassCard(
      opacity: 0.05,
      borderColor: const Color(0xff6366f1).withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Mascot Glow dot
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(radius: 6, backgroundColor: _isCoachingLoading ? Colors.amber : const Color(0xff10b981)),
                        if (!_isCoachingLoading)
                          Positioned(
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xff10b981).withOpacity(0.25),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "SYNC COACH ADVICE",
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
                RotationTransition(
                  turns: _refreshAnimController,
                  child: IconButton(
                    icon: Icon(Icons.refresh_rounded, color: const Color(0xff6366f1).withOpacity(0.8), size: 20),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _loadCoachingAdvice(forceRefresh: true);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _coachingMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Today's study task planner list
  Widget _buildTodayPlanCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("tasks")
          .where("isDone", isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildStaticCard(title: "Today's Plan", icon: Icons.calendar_today, content: "Compiling schedule...", iconColor: Colors.purpleAccent);
        }

        final docs = snapshot.data!.docs;
        final todayTasks = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['dueDateTime'] == null) return false;
          final due = (data['dueDateTime'] as Timestamp).toDate();
          return DateUtils.isSameDay(due, DateTime.now());
        }).toList();

        if (todayTasks.isEmpty) {
          return _buildStaticCard(
            title: "Today's Plan",
            icon: Icons.check_circle_outline_rounded,
            content: "🎉 All tasks cleared for today! Enjoy your free time or recover a backlog chapter.",
            iconColor: const Color(0xff10b981),
          );
        }

        String content = "";
        for (var doc in todayTasks.take(3)) {
          final data = doc.data() as Map<String, dynamic>;
          final priority = data['priority'] ?? 'Medium';
          String prioSymbol = "🔵";
          if (priority == "High") prioSymbol = "🔴";
          if (priority == "Medium") prioSymbol = "🟡";

          content += "📚 ${data['title']} ($prioSymbol $priority)\n";
        }

        return _buildStaticCard(
          title: "Today's Plan",
          icon: Icons.calendar_today_rounded,
          content: content.trim(),
          iconColor: const Color(0xffa855f7),
        );
      },
    );
  }

  // Flat info card helper
  Widget _buildStaticCard({
    required String title,
    required IconData icon,
    required String content,
    required Color iconColor,
  }) {
    return _buildGlassCard(
      opacity: 0.05,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(color: iconColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // Themed grid buttons to modules
  Widget _buildModulesGrid() {
    return Column(
      children: [
        // AI Roadmap Button
        _buildModuleButton(
          title: "AI Study Roadmap",
          subtitle: "Map custom subject milestone paths",
          icon: Icons.route_rounded,
          gradientColors: [const Color(0xff6366f1), const Color(0xff4f46e5)],
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoadmapScreen())),
        ),
        const SizedBox(height: 12),

        // Backlog Recovery Button
        StreamBuilder<int>(
          stream: BacklogService().getPendingCount(),
          builder: (context, snapshot) {
            final pending = snapshot.data ?? 0;
            final subtitle = pending == 0
                ? "No pending nodes. Great job!"
                : "Recover $pending pending syllabus chapters";

            return _buildModuleButton(
              title: "Backlog Recovery Plan",
              subtitle: subtitle,
              icon: Icons.menu_book_rounded,
              gradientColors: pending == 0
                  ? [const Color(0xff10b981), const Color(0xff059669)]
                  : [const Color(0xfff97316), const Color(0xffea580c)],
              badgeCount: pending > 0 ? pending : null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BacklogScreen())),
            );
          },
        ),
        const SizedBox(height: 12),

        // Notes to Quiz Button
        _buildModuleButton(
          title: "Notes To Quiz Arena",
          subtitle: "Generate dynamic MCQs from textbook notes",
          icon: Icons.quiz_rounded,
          gradientColors: [const Color(0xff10b981), const Color(0xff059669)],
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesToQuizScreen())),
        ),
      ],
    );
  }

  // Themed module selection row button
  Widget _buildModuleButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.12),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              border: Border.all(color: Colors.white10, width: 1.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    // Visual icon container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),

                    // Titles
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Badge counter or Arrow right icon
                    if (badgeCount != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xffef4444),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "$badgeCount",
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}