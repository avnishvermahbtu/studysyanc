import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:studysync/features/focus/controller/focus_controller.dart';
import 'package:studysync/features/dashboard/widgets/dashboard_card.dart';
import 'package:studysync/features/tasks/models/task_model.dart';
import 'package:studysync/features/routine/screens/routine_model.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FocusController _focusController = FocusController();

  // Weekly study chart state
  String _selectedDay = "Mon";

  // Category donut chart state
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    // Default selected day is today
    final days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    _selectedDay = days[DateTime.now().weekday % 7];

    _focusController.addListener(_onFocusUpdate);
  }

  void _onFocusUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _focusController.removeListener(_onFocusUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff020617),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            left: -50,
            child: CircleAvatar(
              radius: 180,
              backgroundColor: const Color(0xff6366f1).withOpacity(0.08),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: CircleAvatar(
              radius: 180,
              backgroundColor: const Color(0xff10b981).withOpacity(0.05),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                _buildTabsSelector(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFocusTab(),
                      _buildTasksTab(),
                      _buildClassesTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            "Performance Hub",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xff6366f1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff6366f1).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: "Focus Sessions"),
          Tab(text: "Tasks Complete"),
          Tab(text: "Routine Blocks"),
        ],
      ),
    );
  }

  // --- FOCUS TAB ---
  Widget _buildFocusTab() {
    final weeklyMin = _focusController.weeklyMinutes;
    final totalWeeklyMin = weeklyMin.values.fold(0, (sum, val) => sum + val);
    final avgDailyMin = (totalWeeklyMin / 7).round();

    final catMinutes = _focusController.categoryMinutes;
    final totalCatMin = catMinutes.values.fold(0, (sum, val) => sum + val);

    final currentLvl = _focusController.level;
    final currentXp = _focusController.xp;
    final neededXp = _focusController.xpNeededForNextLevel();
    final progressPct = (currentXp / neededXp).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Weekly Study Time Card (Interactive Bar Chart)
          DashboardCard(
            glowColor: const Color(0xff6366f1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "WEEKLY STUDY TIMELINE",
                        style: TextStyle(
                          color: Color(0xff6366f1),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        "Total: ${totalWeeklyMin}m",
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Selected Day Study Time: ${weeklyMin[_selectedDay] ?? 0} mins",
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  _buildBarChart(weeklyMin),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      "Daily Average: $avgDailyMin minutes",
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Gamification progress details
          DashboardCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircularPercentIndicator(
                    radius: 40.0,
                    lineWidth: 8.0,
                    percent: progressPct,
                    center: Text(
                      "Lvl $currentLvl",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    progressColor: const Color(0xff6366f1),
                    backgroundColor: Colors.white12,
                    circularStrokeCap: CircularStrokeCap.round,
                    animateFromLastPercent: true,
                    animation: true,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _focusController.getRankName(),
                          style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "XP: $currentXp / $neededXp to Level Up",
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressPct,
                            color: const Color(0xff6366f1),
                            backgroundColor: Colors.white12,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Focus category distribution (Interactive Pie/Donut Chart)
          DashboardCard(
            glowColor: const Color(0xff10b981),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "FOCUS CATEGORIES",
                    style: TextStyle(
                      color: Color(0xff10b981),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                        ),
                      ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Donut representation
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: DonutChartPainter(
                            categoryData: catMinutes,
                            selectedCategory: _selectedCategory,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _selectedCategory != null
                                      ? "${((catMinutes[_selectedCategory] ?? 0) / (totalCatMin > 0 ? totalCatMin : 1) * 100).round()}%"
                                      : "${totalCatMin}m",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                Text(
                                  _selectedCategory != null
                                      ? _selectedCategory!.toUpperCase()
                                      : "TOTAL TIME",
                                  style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Legends
                      Expanded(
                        child: Column(
                          children: catMinutes.keys.map((cat) {
                            final min = catMinutes[cat] ?? 0;
                            final colors = {
                              "study": const Color(0xff6366f1),
                              "coding": const Color(0xff10b981),
                              "writing": const Color(0xfff59e0b),
                              "science": const Color(0xffec4899),
                              "meditation": const Color(0xff8b5cf6),
                            };
                            final isSelected = _selectedCategory == cat;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (_selectedCategory == cat) {
                                    _selectedCategory = null;
                                  } else {
                                    _selectedCategory = cat;
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white.withOpacity(0.06) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: colors[cat],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        cat.toUpperCase(),
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white60,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      "${min}m",
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(Map<String, int> weeklyMin) {
    final daysOrder = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final maxMins = weeklyMin.values.fold(60, (maxVal, val) => max(maxVal, val)).toDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: daysOrder.map((day) {
        final val = weeklyMin[day] ?? 0;
        final double barHeight = max(10.0, (val / maxMins) * 120);
        final isSelected = _selectedDay == day;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDay = day;
            });
          },
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    height: 120,
                    width: 22,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: barHeight,
                    width: 22,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected
                            ? [const Color(0xff818cf8), const Color(0xff6366f1)]
                            : [const Color(0xff1e293b), const Color(0xff475569)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: isSelected
                          ? [BoxShadow(color: const Color(0xff6366f1).withOpacity(0.4), blurRadius: 8, spreadRadius: 0)]
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                day,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- TASKS TAB ---
  Widget _buildTasksTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("tasks").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasksList = snapshot.data!.docs
            .map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList();

        final totalTasks = tasksList.length;
        final completedTasks = tasksList.where((t) => t.isDone).length;
        final double completePct = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

        final highPriority = tasksList.where((t) => t.priority == 'High').toList();
        final highDone = highPriority.where((t) => t.isDone).length;

        final medPriority = tasksList.where((t) => t.priority == 'Medium').toList();
        final medDone = medPriority.where((t) => t.isDone).length;

        final lowPriority = tasksList.where((t) => t.priority == 'Low').toList();
        final lowDone = lowPriority.where((t) => t.isDone).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardCard(
                glowColor: const Color(0xffa855f7),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      CircularPercentIndicator(
                        radius: 50.0,
                        lineWidth: 10.0,
                        percent: completePct,
                        center: Text(
                          "${(completePct * 100).toInt()}%",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        progressColor: const Color(0xffa855f7),
                        backgroundColor: Colors.white12,
                        circularStrokeCap: CircularStrokeCap.round,
                        animateFromLastPercent: true,
                        animation: true,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "QUEST COMPLETION RATE",
                              style: TextStyle(color: Color(0xffa855f7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "$completedTasks of $totalTasks Quests",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              totalTasks - completedTasks > 0
                                  ? "${totalTasks - completedTasks} remaining items in backlog."
                                  : "All clean! Awesome job. 🎉",
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text("PRIORITY BREAKDOWN", style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              _buildPriorityStatCard("High Priority", highDone, highPriority.length, Colors.redAccent),
              const SizedBox(height: 10),
              _buildPriorityStatCard("Medium Priority", medDone, medPriority.length, Colors.amberAccent),
              const SizedBox(height: 10),
              _buildPriorityStatCard("Low Priority", lowDone, lowPriority.length, Colors.cyanAccent),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriorityStatCard(String label, int done, int total, Color color) {
    final double pct = total > 0 ? (done / total) : 0.0;
    return DashboardCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 16,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 10),
                    Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                Text("$done / $total Complete", style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                color: color,
                backgroundColor: Colors.white.withOpacity(0.03),
                minHeight: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CLASSES TAB ---
  Widget _buildClassesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("routine").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final routines = snapshot.data!.docs
            .map((doc) => Routine.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList();

        final totalClasses = routines.length;
        final attendedClasses = routines.where((r) => r.isCheckedIn).length;
        final double attendancePct = totalClasses > 0 ? (attendedClasses / totalClasses) : 0.0;

        // Group by type
        final typeCounts = <String, int>{};
        final typeAttended = <String, int>{};
        for (final r in routines) {
          typeCounts[r.type] = (typeCounts[r.type] ?? 0) + 1;
          if (r.isCheckedIn) {
            typeAttended[r.type] = (typeAttended[r.type] ?? 0) + 1;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardCard(
                glowColor: Colors.blueAccent,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      CircularPercentIndicator(
                        radius: 50.0,
                        lineWidth: 10.0,
                        percent: attendancePct,
                        center: Text(
                          "${(attendancePct * 100).toInt()}%",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        progressColor: Colors.blueAccent,
                        backgroundColor: Colors.white12,
                        circularStrokeCap: CircularStrokeCap.round,
                        animateFromLastPercent: true,
                        animation: true,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "CLASS ATTENDANCE RATE",
                              style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "$attendedClasses of $totalClasses Blocks",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Earn +35 Focus XP per check-in!",
                              style: TextStyle(color: Colors.blueAccent.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text("ATTENDANCE BY BLOCK TYPE", style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              if (typeCounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      "No routines configured in schedule.",
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontStyle: FontStyle.italic, fontSize: 13),
                    ),
                  ),
                )
              else
                ...typeCounts.keys.map((type) {
                  final total = typeCounts[type] ?? 0;
                  final attended = typeAttended[type] ?? 0;
                  final double pct = attended / total;
                  final colors = {
                    "Lecture": Colors.blueAccent,
                    "Lab": Colors.purpleAccent,
                    "Exam": Colors.redAccent,
                    "Study": Colors.greenAccent,
                    "Personal": Colors.orangeAccent,
                  };

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DashboardCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.school_rounded, color: colors[type] ?? Colors.white54, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  type.toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            Text(
                              "$attended / $total Attended (${(pct * 100).toInt()}%)",
                              style: TextStyle(color: colors[type] ?? Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        );
      },
    );
  }
}

// Donut Chart Painter
class DonutChartPainter extends CustomPainter {
  final Map<String, int> categoryData;
  final String? selectedCategory;

  DonutChartPainter({required this.categoryData, this.selectedCategory});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = categoryData.values.fold(0, (sum, val) => sum + val).toDouble();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.20;

    if (total == 0) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    final colors = {
      "study": const Color(0xff6366f1),
      "coding": const Color(0xff10b981),
      "writing": const Color(0xfff59e0b),
      "science": const Color(0xffec4899),
      "meditation": const Color(0xff8b5cf6),
    };

    double startAngle = -pi / 2;
    categoryData.forEach((cat, val) {
      if (val == 0) return;
      final sweepAngle = (val / total) * pi * 2;
      final isSelected = selectedCategory == cat;

      final paint = Paint()
        ..color = colors[cat] ?? Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth + 4 : strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle - 0.05,
        false,
        paint,
      );

      startAngle += sweepAngle;
    });
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.categoryData != categoryData || oldDelegate.selectedCategory != selectedCategory;
  }
}