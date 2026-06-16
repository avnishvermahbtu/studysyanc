import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../tasks/models/task_model.dart';
import '../../focus/controller/focus_controller.dart';
import '../widgets/dashboard_card.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late FocusController _focusController;

  @override
  void initState() {
    super.initState();
    _focusController = FocusController();
    _focusController.addListener(_onFocusUpdate);
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
              radius: 150,
              backgroundColor: const Color(0xff6366f1).withOpacity(0.1),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: Colors.blue.withOpacity(0.05),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildProgressCard(minutesToday, progressPct),
                  const SizedBox(height: 20),
                  _buildStatsRow(),
                  const SizedBox(height: 28),
                  _buildQuestsHeader(),
                  const SizedBox(height: 12),
                  _buildQuestsList(),
                  const SizedBox(height: 28),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome Back 👋",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Aao Parhein! 📚",
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white70),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xff6366f1).withOpacity(0.3), width: 2),
              ),
              child: const CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage("https://i.pravatar.cc/150"),
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
        const SizedBox(width: 16),
        Expanded(
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
        "icon": Icons.timer_outlined,
        "title": "Start Focus",
        "subtitle": "Pomodoro Timer",
        "tabIndex": 3,
        "color": const Color(0xff6366f1),
      },
      {
        "icon": Icons.calendar_today_outlined,
        "title": "Timetable",
        "subtitle": "Daily Schedule",
        "tabIndex": 2,
        "color": Colors.greenAccent,
      },
      {
        "icon": Icons.task_outlined,
        "title": "Questboard",
        "subtitle": "Add Study Tasks",
        "tabIndex": 1,
        "color": Colors.amberAccent,
      },
      {
        "icon": Icons.smart_toy_outlined,
        "title": "AI Coach",
        "subtitle": "Backlog Recovery",
        "tabIndex": 4,
        "color": Colors.pinkAccent,
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
          onTap: () => widget.onNavigate?.call(act["tabIndex"]),
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
}