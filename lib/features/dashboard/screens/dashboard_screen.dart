import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysync/login_page.dart';

import '../../tasks/models/task_model.dart';
import '../../focus/controller/focus_controller.dart';
import '../widgets/dashboard_card.dart';
import '../../ai_coach/roadmap_screen.dart';
import '../../ai_coach/backlog_screen.dart';
import '../../ai_coach/notes_to_quiz_screen.dart';
import '../../ai_coach/leaderboard_screen.dart';
import '../../ai_coach/quiz_revision_screen.dart';
import '../../analytics/screens/analytics_screen.dart';
import '../../routine/screens/study_zones_screen.dart';
import '../../group_study/screens/group_study_lobby_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late FocusController _focusController;
  String _studentName = "Student";

  @override
  void initState() {
    super.initState();
    _focusController = FocusController();
    _focusController.addListener(_onFocusUpdate);
    _loadStudentName();
  }

  Future<void> _loadStudentName() async {
    final prefs = await SharedPreferences.getInstance();
    final localName = prefs.getString('student_name');
    if (localName != null && localName.isNotEmpty) {
      if (mounted) {
        setState(() {
          _studentName = localName;
        });
      }
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        final updatedUser = FirebaseAuth.instance.currentUser;
        if (updatedUser?.displayName != null && updatedUser!.displayName!.isNotEmpty) {
          if (mounted) {
            setState(() {
              _studentName = updatedUser.displayName!;
            });
          }
          await prefs.setString('student_name', updatedUser.displayName!);
        }
      }
    }
  }

  @override
  void dispose() {
    _focusController.removeListener(_onFocusUpdate);
    super.dispose();
  }

  void _onFocusUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showEditGoalDialog() {
    int selectedMinutes = _focusController.dailyStudyGoal;
    final presets = [60, 120, 180, 240, 360, 480]; // 1h, 2h, 3h, 4h, 6h, 8h
    final customController = TextEditingController(text: selectedMinutes.toString());

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xff0f172a),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.white10),
              ),
              title: const Row(
                children: [
                  Icon(Icons.track_changes_rounded, color: Color(0xff6366f1)),
                  SizedBox(width: 10),
                  Text(
                    "Set Daily Goal",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Choose a daily study goal:",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    
                    // Presets Grid
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presets.map((mins) {
                        final isSelected = selectedMinutes == mins;
                        final int hours = mins ~/ 60;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedMinutes = mins;
                              customController.text = mins.toString();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xff6366f1) : const Color(0xff1e293b),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? const Color(0xff6366f1) : Colors.white10,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              "${hours}h",
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    
                    // Custom Minutes Input
                    TextField(
                      controller: customController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: "Custom Minutes",
                        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.timer_outlined, color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xff6366f1)),
                        ),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null && parsed > 0) {
                          setModalState(() {
                            selectedMinutes = parsed;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff6366f1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: () async {
                    if (selectedMinutes > 0) {
                      await _focusController.setDailyStudyGoal(selectedMinutes);
                      if (mounted) setState(() {});
                    }
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Set Goal",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color getPriorityColor(String priority) {
    switch (priority) {
      case "High":
        return Colors.redAccent;
      case "Medium":
        return Colors.amberAccent;
      case "Low":
        return Colors.cyanAccent;
      default:
        return Colors.grey;
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "Good Morning 🌅";
    } else if (hour >= 12 && hour < 17) {
      return "Good Afternoon ☀️";
    } else if (hour >= 17 && hour < 21) {
      return "Good Evening 🌆";
    } else {
      return "Good Night 🌌";
    }
  }

  Widget _buildLevelProgress() {
    final xp = _focusController.xp;
    final lvl = _focusController.level;
    final nextLevelXp = _focusController.xpNeededForNextLevel();
    final double pct = (xp / nextLevelXp).clamp(0.0, 1.0);
    final rank = _focusController.getRankName();

    return DashboardCard(
      bgOpacity: 0.03,
      glowColor: const Color(0xff6366f1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      "Level $lvl — $rank",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  "$xp / ${nextLevelXp} XP",
                  style: const TextStyle(
                    color: Color(0xffa5b4fc),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(
                    height: 8,
                    color: Colors.white.withOpacity(0.05),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: pct,
                    child: Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xff6366f1), Colors.pinkAccent],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedModes() {
    final List<Map<String, dynamic>> featured = [
      {
        "icon": Icons.timer_rounded,
        "title": "Solo Focus",
        "subtitle": "Pomodoro Timer",
        "onTap": () => widget.onNavigate?.call(2), // Focus is index 2
        "color": const Color(0xff6366f1),
      },
      {
        "icon": Icons.groups_rounded,
        "title": "Co-Study",
        "subtitle": "Join Slide Rooms",
        "onTap": () => widget.onNavigate?.call(1), // Co-Study is index 1
        "color": const Color(0xff10b981),
      },
      {
        "icon": Icons.psychology_rounded,
        "title": "AI Mentor",
        "subtitle": "Holographic Coach",
        "onTap": () => widget.onNavigate?.call(4), // Coach is index 4
        "color": Colors.pinkAccent,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Featured Study Hub",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: featured.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = featured[index];
              return SizedBox(
                width: 155,
                child: DashboardCard(
                  onTap: item["onTap"],
                  bgOpacity: 0.05,
                  glowColor: item["color"],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item["color"].withOpacity(0.12),
                          ),
                          child: Icon(item["icon"], color: item["color"], size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item["title"],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          item["subtitle"],
                          style: const TextStyle(
                            color: Colors.white30,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    final dayKey = days[DateTime.now().weekday % 7];
    final minutesToday = _focusController.weeklyMinutes[dayKey] ?? 0;
    final double goalMinutes = _focusController.dailyStudyGoal.toDouble();
    final double progressPct = (minutesToday / goalMinutes).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xff020617),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -50,
            child: CircleAvatar(
              radius: 180,
              backgroundColor: const Color(0xff6366f1).withOpacity(0.12),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: CircleAvatar(
              radius: 180,
              backgroundColor: Colors.blue.withOpacity(0.08),
            ),
          ),
          Positioned(
            top: 300,
            left: -100,
            child: CircleAvatar(
              radius: 140,
              backgroundColor: Colors.pink.withOpacity(0.05),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildLevelProgress(),
                  const SizedBox(height: 20),
                  _buildProgressCard(minutesToday, progressPct),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildFeaturedModes(),
                  const SizedBox(height: 24),
                  _buildQuestsHeader(),
                  const SizedBox(height: 12),
                  _buildQuestsList(),
                  const SizedBox(height: 24),
                  _buildActionsHeader(),
                  const SizedBox(height: 12),
                  _buildActionsGrid(),
                  const SizedBox(height: 24),
                  _buildMotivationBanner(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${_getGreeting()}, $_studentName 👋",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xff6366f1), Colors.pinkAccent],
                ).createShader(bounds),
                child: const Text(
                  "Ready to Conquer? ⚡",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.12),
                  border: Border.all(color: Colors.blue.withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Color(0xff93c5fd),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _showSettingsBottomSheet(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xff6366f1).withOpacity(0.12),
                  border: Border.all(color: const Color(0xff6366f1).withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff6366f1).withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xffa5b4fc),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressCard(int minutesToday, double progressPct) {
    final int h = minutesToday ~/ 60;
    final int m = minutesToday % 60;
    
    final int goalMins = _focusController.dailyStudyGoal;
    final int goalH = goalMins ~/ 60;
    final int goalM = goalMins % 60;
    final String goalText = goalM == 0 ? "$goalH hours" : "${goalH}h ${goalM}m";

    return GestureDetector(
      onTap: _showEditGoalDialog,
      child: DashboardCard(
        glowColor: const Color(0xff6366f1),
        bgOpacity: 0.08,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "TODAY'S STUDY GOAL",
                      style: TextStyle(
                        color: Color(0xff6366f1),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      h > 0 ? "${h}h ${m}m" : "${m}m",
                      style: const TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          "Daily Goal: $goalText",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.edit_rounded,
                          color: const Color(0xff6366f1).withOpacity(0.6),
                          size: 13,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 85,
                    width: 85,
                    child: CircularProgressIndicator(
                      value: progressPct,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff6366f1)),
                    ),
                  ),
                  Text(
                    "${(progressPct * 100).toInt()}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final streak = _focusController.streak;
    final lvl = _focusController.level;
    final rank = _focusController.getRankName();

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              );
            },
            child: DashboardCard(
              bgOpacity: 0.05,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Streak",
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 22),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "$streak Days",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      streak > 0 ? "Keep it hot! 🔥" : "Start today! ⏱️",
                      style: const TextStyle(color: Colors.white30, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              );
            },
            child: DashboardCard(
              bgOpacity: 0.05,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Rank Level",
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        Icon(Icons.stars, color: Colors.amberAccent, size: 22),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Lvl $lvl",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rank,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.amberAccent.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Today's Quests",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: () => widget.onNavigate?.call(1), // Switch to Tasks tab
          child: const Row(
            children: [
              Text("See All", style: TextStyle(color: Color(0xff6366f1))),
              Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xff6366f1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("tasks").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allTasks = snapshot.data!.docs
            .map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((t) => !t.isDone && t.dueDateTime != null && DateUtils.isSameDay(t.dueDateTime, DateTime.now()))
            .toList();

        if (allTasks.isEmpty) {
          return DashboardCard(
            bgOpacity: 0.03,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Text(
                  "All critical quests completed! 🎉",
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          );
        }

        // Display top 3 tasks
        final displayTasks = allTasks.take(3).toList();

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayTasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final task = displayTasks[index];
            return DashboardCard(
              bgOpacity: 0.05,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: getPriorityColor(task.priority),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                title: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  task.description.isNotEmpty ? task.description : "No description",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                trailing: Checkbox(
                  value: task.isDone,
                  activeColor: const Color(0xff6366f1),
                  side: const BorderSide(color: Colors.white24, width: 2),
                  onChanged: (val) async {
                    if (val == true) {
                      int xpAward;
                      if (task.priority == "High") {
                        xpAward = 50;
                      } else if (task.priority == "Medium") {
                        xpAward = 30;
                      } else {
                        xpAward = 15;
                      }

                      _focusController.addXp(xpAward);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Quest Clear! +$xpAward XP"),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );

                      await FirebaseFirestore.instance
                          .collection("tasks")
                          .doc(task.id)
                          .update({'isDone': true});
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionsHeader() {
    return const Text(
      "Quick Strategy Actions",
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildActionsGrid() {
    final List<Map<String, dynamic>> actions = [
      {
        "icon": Icons.calendar_today_outlined,
        "title": "Timetable",
        "subtitle": "Daily Schedule",
        "onTap": () => widget.onNavigate?.call(5), // Schedule is index 5
        "color": Colors.greenAccent,
      },
      {
        "icon": Icons.task_outlined,
        "title": "Questboard",
        "subtitle": "Add Study Tasks",
        "onTap": () => widget.onNavigate?.call(3), // Quests is index 3
        "color": Colors.amberAccent,
      },
      {
        "icon": Icons.route_rounded,
        "title": "AI Roadmap",
        "subtitle": "Milestone Routes",
        "onTap": () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoadmapScreen())),
        "color": const Color(0xff818cf8),
      },
      {
        "icon": Icons.menu_book_rounded,
        "title": "Backlog Plan",
        "subtitle": "Recover Chapters",
        "onTap": () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BacklogScreen())),
        "color": const Color(0xfffb923c),
      },
      {
        "icon": Icons.quiz_rounded,
        "title": "Quiz Arena",
        "subtitle": "Textbook MCQs",
        "onTap": () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesToQuizScreen())),
        "color": const Color(0xff34d399),
      },
      {
        "icon": Icons.auto_stories_outlined,
        "title": "Revision Bank",
        "subtitle": "Smart Mistakes",
        "onTap": () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizRevisionScreen())),
        "color": Colors.redAccent,
      },
      {
        "icon": Icons.add_location_alt_outlined,
        "title": "Study Zones",
        "subtitle": "Geofenced Reminders",
        "onTap": () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyZonesScreen())),
        "color": const Color(0xff10b981),
      },
      {
        "icon": Icons.leaderboard_outlined,
        "title": "Leaderboard",
        "subtitle": "Global Rank Board",
        "onTap": () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
        "color": Colors.amberAccent,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: actions.length,
      itemBuilder: (context, idx) {
        final act = actions[idx];
        return DashboardCard(
          onTap: act["onTap"],
          bgOpacity: 0.06,
          glowColor: act["color"],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(act["icon"], color: act["color"], size: 24),
                const SizedBox(height: 10),
                Text(
                  act["title"],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  act["subtitle"],
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMotivationBanner() {
    final streak = _focusController.streak;

    return DashboardCard(
      bgOpacity: 0.04,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Colors.amberAccent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                streak > 0
                    ? "Consistency is key! You are maintaining a solid $streak-day streak. Keep pushing! 🔥"
                    : "Consistency is key. Start your first study focus block today and build your streak! 🎯",
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    final nameEditController = TextEditingController(text: _studentName);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 30,
              ),
              decoration: const BoxDecoration(
                color: Color(0xff0f172a),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(top: BorderSide(color: Colors.white10, width: 1.5)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Header title
                    const Row(
                      children: [
                        Icon(Icons.settings_suggest_rounded, color: Color(0xff6366f1), size: 28),
                        SizedBox(width: 12),
                        Text(
                          "App Settings",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    
                    // Student Info Section
                    const Text(
                      "STUDENT PROFILE",
                      style: TextStyle(
                        color: Color(0xff6366f1),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Name Field Edit
                    TextField(
                      controller: nameEditController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.white54),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xff10b981)),
                          onPressed: () async {
                            final newName = nameEditController.text.trim();
                            if (newName.isNotEmpty) {
                              // Save name
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await user.updateDisplayName(newName);
                                await user.reload();
                              }
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('student_name', newName);
                              
                              setState(() {
                                _studentName = newName;
                              });
                              setModalState(() {});
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Name updated to $newName successfully!"),
                                    backgroundColor: const Color(0xff10b981),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xff6366f1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Email
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.email_outlined, color: Colors.white54),
                      title: const Text("Email Address", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      subtitle: Text(
                        FirebaseAuth.instance.currentUser?.email ?? "Not logged in",
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 30),
                    
                    // Preferences
                    const Text(
                      "PREFERENCES & GOALS",
                      style: TextStyle(
                        color: Color(0xff6366f1),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _showEditGoalDialog();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: Colors.white70),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "Edit Daily Study Goal",
                                style: TextStyle(color: Colors.white, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${_focusController.dailyStudyGoal} mins",
                              style: const TextStyle(color: Color(0xff6366f1), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white30),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 35),
                    
                    // Logout button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffef4444).withOpacity(0.1),
                        foregroundColor: const Color(0xffef4444),
                        side: BorderSide(color: const Color(0xffef4444).withOpacity(0.3), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        _confirmLogout(context);
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: Color(0xffef4444)),
                          SizedBox(width: 10),
                          Text(
                            "Log Out Session",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xff0f172a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xffef4444)),
              SizedBox(width: 10),
              Text("Log Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            "Are you sure you want to log out of StudySync? Your local stats will remain saved.",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffef4444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.pop(ctx); // close dialog
                Navigator.pop(context); // close bottom sheet
                
                await FirebaseAuth.instance.signOut();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('student_name'); // Clear name cache
                
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
              child: const Text("Log Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}