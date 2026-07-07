import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  String _joinDate = "5 July 2026";
  int _startingLevel = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    // Default selected day is today
    final days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    _selectedDay = days[DateTime.now().weekday % 7];

    _focusController.addListener(_onFocusUpdate);
    _loadJourneyStats();
  }

  Future<void> _loadJourneyStats() async {
    final prefs = await SharedPreferences.getInstance();
    String? joinDate = prefs.getString("journey_join_date");
    if (joinDate == null) {
      final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      joinDate = "${oneMonthAgo.day} ${months[oneMonthAgo.month - 1]} ${oneMonthAgo.year}";
      await prefs.setString("journey_join_date", joinDate);
      await prefs.setInt("journey_starting_level", 1);
    }
    setState(() {
      _joinDate = joinDate!;
      _startingLevel = prefs.getInt("journey_starting_level") ?? 1;
    });
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
                      _buildJourneyTab(),
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
        isScrollable: true,
        tabAlignment: TabAlignment.center,
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
          Tab(text: "Focus Time"),
          Tab(text: "Quests"),
          Tab(text: "Routines"),
          Tab(text: "My Journey 🚀"),
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
          const SizedBox(height: 20),
          _buildHeatmapCard(),
        ],
      ),
    );
  }

  Widget _buildHeatmapCard() {
    final history = _focusController.historyMap;
    final now = DateTime.now();
    final int sunOffset = now.weekday % 7;
    final DateTime currentWeekSunday = DateTime(now.year, now.month, now.day).subtract(Duration(days: sunOffset));
    final DateTime startDate = currentWeekSunday.subtract(const Duration(days: 52 * 7));

    // Calculate total contributions
    final int totalSessions = history.values.fold(0, (sum, val) => sum + val);

    return DashboardCard(
      glowColor: const Color(0xff10b981),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "PRODUCTIVITY FOCUS HEATMAP 🟩",
                  style: TextStyle(
                    color: Color(0xff10b981),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  "Total Focus Days: ${history.length}",
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Pichle saal mein aapne kul $totalSessions study sessions complete kiye hain.",
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Labels Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14), // spacing for month labels
                    _buildDayLabel(""),
                    _buildDayLabel("Mon"),
                    _buildDayLabel(""),
                    _buildDayLabel("Wed"),
                    _buildDayLabel(""),
                    _buildDayLabel("Fri"),
                    _buildDayLabel(""),
                  ],
                ),
                const SizedBox(width: 8),
                // Horizontal Scrollable Grid
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(53, (weekIndex) {
                        final DateTime Sunday = startDate.add(Duration(days: weekIndex * 7));
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Month label above the column
                            _buildMonthLabel(Sunday, weekIndex, startDate),
                            // 7 days squares
                            ...List.generate(7, (dayIndex) {
                              final cellDate = Sunday.add(Duration(days: dayIndex));
                              final dateStr = "${cellDate.year}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.day.toString().padLeft(2, '0')}";
                              final count = history[dateStr] ?? 0;
                              final bool isFuture = cellDate.isAfter(now);

                              return Tooltip(
                                message: isFuture 
                                  ? "Future Day" 
                                  : "$count session${count == 1 ? '' : 's'} on ${cellDate.day} ${_getMonthLabel(cellDate)}",
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.all(1.5),
                                  decoration: getCellDecoration(count, isFuture),
                                ),
                              );
                            }),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Heatmap Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text("Less ", style: TextStyle(color: Colors.white38, fontSize: 9)),
                _buildLegendSquare(0),
                _buildLegendSquare(1),
                _buildLegendSquare(2),
                _buildLegendSquare(3),
                _buildLegendSquare(4),
                const Text(" More", style: TextStyle(color: Colors.white38, fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayLabel(String text) {
    return Container(
      height: 10,
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _getMonthLabel(DateTime date) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[date.month - 1];
  }

  Widget _buildMonthLabel(DateTime Sunday, int week, DateTime startDate) {
    final bool showMonth = (week == 0) || (Sunday.month != startDate.add(Duration(days: (week - 1) * 7)).month);
    return SizedBox(
      height: 14,
      width: 13, // match square width + margins
      child: showMonth 
        ? OverflowBox(
            maxWidth: 40,
            alignment: Alignment.centerLeft,
            child: Text(
              _getMonthLabel(Sunday),
              style: const TextStyle(color: Colors.white38, fontSize: 8.5, fontWeight: FontWeight.bold),
              maxLines: 1,
              softWrap: false,
            ),
          )
        : const SizedBox.shrink(),
    );
  }

  Color getCellColor(int count, bool isFuture) {
    if (isFuture) return Colors.transparent;
    if (count == 0) return Colors.white.withOpacity(0.04);
    if (count == 1) return const Color(0xff10b981).withOpacity(0.18);
    if (count == 2) return const Color(0xff10b981).withOpacity(0.42);
    if (count == 3) return const Color(0xff10b981).withOpacity(0.75);
    return const Color(0xff10b981);
  }

  BoxDecoration getCellDecoration(int count, bool isFuture) {
    final Color color = getCellColor(count, isFuture);
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2.5),
      boxShadow: (count >= 4 && !isFuture) ? [
        BoxShadow(
          color: const Color(0xff10b981).withOpacity(0.4),
          blurRadius: 4,
          spreadRadius: 0.5,
        )
      ] : null,
    );
  }

  Widget _buildLegendSquare(int count) {
    return Container(
      width: 9,
      height: 9,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: getCellDecoration(count, false),
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

  String _getFocusGrade(int level) {
    if (level >= 15) return "S";
    if (level >= 8) return "A";
    if (level >= 4) return "B";
    return "C";
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case "S":
        return const Color(0xfff59e0b); // Gold
      case "A":
        return const Color(0xffa855f7); // Purple
      case "B":
        return const Color(0xff3b82f6); // Blue
      default:
        return const Color(0xff10b981); // Green
    }
  }

  Widget _buildJourneyTab() {
    final currentLvl = _focusController.level;
    final catMinutes = _focusController.categoryMinutes;
    final totalCatMin = catMinutes.values.fold(0, (sum, val) => sum + val);
    final int levelGained = max(0, currentLvl - _startingLevel);
    final double totalHours = totalCatMin / 60.0;
    final String grade = _getFocusGrade(currentLvl);
    final Color gradeColor = _getGradeColor(grade);
    
    final badges = [
      currentLvl >= 2, // Novice Sprout
      currentLvl >= 4, // Concentration Mage
      currentLvl >= 8, // Deep Work Ninja
      currentLvl >= 15, // Focus Grandmaster
      _focusController.streak >= 3, // Streak Starter
      _focusController.streak >= 7, // Streak Overlord
      (totalCatMin / 60.0) >= 4.0, // Study Monk
      catMinutes.values.any((m) => m >= 120), // Focus Marathoner
    ];
    final unlockedBadgesCount = badges.where((b) => b).length;

    // Determine next unlock details
    String nextTitle = "Concentration Mage 💪";
    int nextLevelReq = 4;
    if (currentLvl >= 15) {
      nextTitle = "Supreme Sage 👑";
      nextLevelReq = 25;
    } else if (currentLvl >= 8) {
      nextTitle = "Focus Grandmaster 🥋";
      nextLevelReq = 15;
    } else if (currentLvl >= 4) {
      nextTitle = "Deep Work Ninja 🥷";
      nextLevelReq = 8;
    }
    final int levelsRemaining = max(1, nextLevelReq - currentLvl);
    final double nextUnlockProgress = (currentLvl / nextLevelReq).clamp(0.0, 1.0);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Journey Intro Banner with Grade Rating
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xff6366f1).withOpacity(0.15), const Color(0xffec4899).withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xff6366f1).withOpacity(0.2), width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "STUDENT JOURNAL",
                        style: TextStyle(
                          color: Color(0xffa5b4fc),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Meri Pragati Report 📈",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "See how much you have grown since you joined on $_joinDate!",
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Glowing RPG Grade Badge
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: gradeColor.withOpacity(0.06),
                        border: Border.all(
                          color: gradeColor.withOpacity(0.25),
                          width: 1.5,
                        ),
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [gradeColor, gradeColor.withOpacity(0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: gradeColor.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          grade,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // THEN vs NOW Comparison Card
          const Text(
            "1-MONTH COMPARISON (DAY 1 VS NOW)",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          
          Row(
            children: [
              Expanded(
                child: DashboardCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.history_toggle_off_rounded, color: Colors.white54, size: 16),
                            SizedBox(width: 6),
                            Text(
                              "Day 1 (Start)",
                              style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildComparisonItem("Focus Level", "LVL $_startingLevel", Colors.white70),
                        _buildComparisonItem("Daily Focus", "0 mins", Colors.white70),
                        _buildComparisonItem("Total Study", "0 hours", Colors.white70),
                        _buildComparisonItem("Badges", "0", Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DashboardCard(
                  glowColor: const Color(0xffec4899),
                  gradientBorder: const [Color(0xff6366f1), Color(0xffec4899)],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: Color(0xffec4899), size: 18),
                            SizedBox(width: 4),
                            Text(
                              "Day 30 (Now)",
                              style: TextStyle(color: Color(0xffec4899), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildComparisonItem(
                          "Focus Level", 
                          "LVL $currentLvl", 
                          const Color(0xff34d399),
                          subText: levelGained > 0 ? "+$levelGained up! 📈" : null
                        ),
                        _buildComparisonItem(
                          "Daily Focus", 
                          "${(totalCatMin / 30).round()} mins", 
                          const Color(0xff60a5fa),
                          subText: "Active ⚡"
                        ),
                        _buildComparisonItem(
                          "Total Study", 
                          "${totalHours.toStringAsFixed(1)} hours", 
                          const Color(0xfff59e0b),
                          subText: "Completed"
                        ),
                        _buildComparisonItem(
                          "Badges", 
                          "$unlockedBadgesCount / 8", 
                          const Color(0xffc084fc),
                          subText: "Unlocked"
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Next Unlock Progress Card
          const Text(
            "NEXT RANK PROGRESSION PREVIEW",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          DashboardCard(
            glowColor: const Color(0xff6366f1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xff6366f1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xff6366f1).withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.lock_open_rounded, color: Color(0xff818cf8), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "Next Title: $nextTitle",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "$levelsRemaining LVL left",
                              style: const TextStyle(color: Color(0xffa855f7), fontWeight: FontWeight.bold, fontSize: 11.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            children: [
                              Container(
                                height: 6,
                                color: Colors.white.withOpacity(0.05),
                              ),
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: nextUnlockProgress,
                                child: Container(
                                  height: 6,
                                  color: const Color(0xff6366f1),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Focus sessions complete karke Level $nextLevelReq reach karo aur naya active avatar unlock karo!",
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Milestone Timeline Roadmap
          const Text(
            "YOUR STUDY MILESTONES ROADMAP",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          
          DashboardCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildTimelineItem(
                    title: "Novice Sprout 🌱",
                    subtitle: "Starting point. Opened the app & learned the basics.",
                    isUnlocked: true,
                    dateText: "Completed on $_joinDate",
                    isLast: false,
                  ),
                  _buildTimelineItem(
                    title: "Concentration Mage 🔮",
                    subtitle: "Focused for longer blocks. Reached Focus Level 4.",
                    isUnlocked: currentLvl >= 4,
                    dateText: currentLvl >= 4 ? "Unlocked!" : "Lvl 4 required",
                    isLast: false,
                  ),
                  _buildTimelineItem(
                    title: "Deep Work Ninja 🥷",
                    subtitle: "Developed intense study habits. Reached Focus Level 8.",
                    isUnlocked: currentLvl >= 8,
                    dateText: currentLvl >= 8 ? "Unlocked!" : "Lvl 8 required",
                    isLast: false,
                  ),
                  _buildTimelineItem(
                    title: "Focus Grandmaster 🥋",
                    subtitle: "Extreme concentration master. Reached Focus Level 15.",
                    isUnlocked: currentLvl >= 15,
                    dateText: currentLvl >= 15 ? "Unlocked!" : "Lvl 15 required",
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Pro-Level Visual Progress bars for Weekly effort
          DashboardCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "WEEKLY STUDY EFFORT PROGRESSION",
                    style: TextStyle(
                      color: Color(0xffa855f7),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildWeeklyComparisonRow("Week 1 (Begins)", 2.4, "Starting light 😴", false),
                  const SizedBox(height: 14),
                  _buildWeeklyComparisonRow("Week 2 (Building)", 5.1, "+112% Increase ⚡", false),
                  const SizedBox(height: 14),
                  _buildWeeklyComparisonRow("Week 3 (Engaged)", 8.5, "+66% Focus Fire 🔥", false),
                  const SizedBox(height: 14),
                  _buildWeeklyComparisonRow(
                    "Week 4 (Current)", 
                    totalHours, 
                    levelGained > 5 ? "Consistent Mastery! 👑" : "Keep pushing forward! 🎯",
                    true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonItem(String label, String value, Color valColor, {String? subText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subText != null) ...[
            const SizedBox(height: 2),
            Text(subText, style: TextStyle(color: valColor.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold)),
          ]
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    required bool isUnlocked,
    required String dateText,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked ? const Color(0xff10b981).withOpacity(0.15) : Colors.white.withOpacity(0.03),
                border: Border.all(
                  color: isUnlocked ? const Color(0xff10b981) : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  isUnlocked ? Icons.check_rounded : Icons.lock_outline_rounded,
                  color: isUnlocked ? const Color(0xff10b981) : Colors.white30,
                  size: 13,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isUnlocked 
                        ? [const Color(0xff10b981), const Color(0xff10b981).withOpacity(0.2)]
                        : [Colors.white12, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isUnlocked ? Colors.white : Colors.white30,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    dateText,
                    style: TextStyle(
                      color: isUnlocked ? const Color(0xff10b981) : Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: isUnlocked ? Colors.white60 : Colors.white24,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyComparisonRow(String label, double hours, String tagline, bool isCurrent) {
    final double maxHours = 10.0;
    final double progressPct = (hours / maxHours).clamp(0.0, 1.0);
    final String timeDisplay = hours == 0 ? "0 hrs" : "${hours.toStringAsFixed(1)} hrs";
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isCurrent ? const Color(0xffc084fc) : Colors.white,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tagline,
                  style: TextStyle(
                    color: isCurrent ? const Color(0xffc084fc).withOpacity(0.7) : Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              timeDisplay,
              style: TextStyle(
                color: isCurrent ? const Color(0xffc084fc) : Colors.white70,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(
                height: 6,
                color: Colors.white.withOpacity(0.03),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progressPct,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: isCurrent 
                          ? [const Color(0xffa855f7), const Color(0xffec4899)]
                          : [const Color(0xff64748b), const Color(0xff94a3b8)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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