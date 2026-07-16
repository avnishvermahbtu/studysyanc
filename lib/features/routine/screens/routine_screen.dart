import 'dart:async';
import 'dart:ui';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controller/routine_controller.dart';
import 'routine_model.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/notification_service.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  final firestore = FirebaseFirestore.instance;
  
  // Form controllers
  final titleController = TextEditingController();
  final locationController = TextEditingController();
  String selectedType = "Lecture";
  final List<String> routineTypes = ["Lecture", "Lab", "Exam", "Study", "Personal"];
  
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  late RoutineController _controller;
  String _studentName = "Student";

  Stream<QuerySnapshot>? _routineStream;
  DateTime? _lastSelectedDate;

  Timer? _countdownTimer;
  bool _pulseActive = false;

  String _selectedFilter = "All";
  bool _isAnalyticsExpanded = false;
  Stream<QuerySnapshot>? _weeklyRoutineStream;
  DateTime? _lastWeekStart;

  void _updateWeeklyRoutineStream(DateTime weekStart) {
    DateTime startOfWeek = DateTime(weekStart.year, weekStart.month, weekStart.day);
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 7));
    _weeklyRoutineStream = firestore
        .collection("routine")
        .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .where("date", isLessThan: Timestamp.fromDate(endOfWeek))
        .snapshots();
  }

  void _updateRoutineStream(DateTime targetDate) {
    DateTime startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));
    _routineStream = firestore
        .collection("routine")
        .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where("date", isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots();
  }

  List<Routine> _getClashingRoutines(Routine current, List<Routine> allRoutines) {
    final currentStart = _controller.parseTimeString(current.startTime, current.date);
    final currentEnd = _controller.parseTimeString(current.endTime, current.date);
    if (currentStart == null || currentEnd == null) return [];

    List<Routine> clashes = [];
    for (var other in allRoutines) {
      if (other.id == current.id) continue;
      final otherStart = _controller.parseTimeString(other.startTime, other.date);
      final otherEnd = _controller.parseTimeString(other.endTime, other.date);
      if (otherStart == null || otherEnd == null) continue;

      // Check overlap: Start A < End B AND End A > Start B
      if (currentStart.isBefore(otherEnd) && currentEnd.isAfter(otherStart)) {
        clashes.add(other);
      }
    }
    return clashes;
  }

  final Map<String, Color> typeColors = {
    "Lecture": Colors.blueAccent,
    "Lab": Colors.purpleAccent,
    "Exam": Colors.redAccent,
    "Study": Colors.greenAccent,
    "Personal": Colors.orangeAccent,
  };

  final Map<String, IconData> typeIcons = {
    "Lecture": Icons.menu_book_rounded,
    "Lab": Icons.biotech_rounded,
    "Exam": Icons.assignment_late_rounded,
    "Study": Icons.school_rounded,
    "Personal": Icons.self_improvement_rounded,
  };

  @override
  void initState() {
    super.initState();
    _controller = RoutineController();
    _controller.addListener(_onControllerUpdate);
    TTSService().addListener(_onTtsStateChanged);

    _lastSelectedDate = DateTime(
      _controller.selectedDate.year,
      _controller.selectedDate.month,
      _controller.selectedDate.day,
    );
    _updateRoutineStream(_lastSelectedDate!);

    _lastWeekStart = _controller.currentWeek.subtract(
      Duration(days: _controller.currentWeek.weekday - 1),
    );
    _updateWeeklyRoutineStream(_lastWeekStart!);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _pulseActive = !_pulseActive;
        });
      }
    });

    _loadStudentName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAllUpcomingRoutines();
    });
  }

  void _onTtsStateChanged(String? text, bool isSpeaking) {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadStudentName() async {
    try {
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
    } catch (e) {
      debugPrint("Error loading student name in RoutineScreen: $e");
    }
  }

  Future<void> _syncAllUpcomingRoutines() async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      
      final querySnapshot = await firestore
          .collection("routine")
          .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .get();

      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
      final routines = querySnapshot.docs
          .map((doc) => Routine.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .where((r) => r.userId == currentUid)
          .toList();

      await NotificationService().syncUpcomingRoutines(routines);
    } catch (e) {
      debugPrint("Error syncing routine notifications: $e");
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      final newDate = DateTime(
        _controller.selectedDate.year,
        _controller.selectedDate.month,
        _controller.selectedDate.day,
      );
      if (_lastSelectedDate == null || !DateUtils.isSameDay(_lastSelectedDate, newDate)) {
        _lastSelectedDate = newDate;
        _updateRoutineStream(newDate);
      }

      final weekStart = _controller.currentWeek.subtract(
        Duration(days: _controller.currentWeek.weekday - 1),
      );
      if (_lastWeekStart == null || !DateUtils.isSameDay(_lastWeekStart, weekStart)) {
        _lastWeekStart = weekStart;
        _updateWeeklyRoutineStream(weekStart);
      }

      setState(() {});
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    TTSService().removeListener(_onTtsStateChanged);
    TTSService().stop(); // Stop speaking if screen is exited
    titleController.dispose();
    locationController.dispose();
    super.dispose();
  }

  // Refined Glassmorphic card (Optimized for performance)
  Widget _buildGlassCard({required Widget child, double blur = 15, double opacity = 0.05, Color borderColor = Colors.white10}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity + 0.015),
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }

  // AI Briefing Dynamic Spark Card
  Widget _buildDailySparkCard(List<Routine> routines) {
    String message = _controller.compileDailyBrief(routines);
    Color themeColor = routines.isNotEmpty ? Colors.blueAccent : Colors.amberAccent;

    return _buildGlassCard(
      opacity: 0.06,
      borderColor: themeColor.withOpacity(0.15),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: themeColor.withOpacity(0.12),
              ),
              child: Icon(Icons.bolt_rounded, color: themeColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "DAILY BRIEFING",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                TTSService().toggleSpeak(message);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Icon(
                  TTSService().isSpeakingText(message)
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: themeColor,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Active / Up Next Live Status Panel
  Widget _buildLiveCountdownPanel(List<Routine> routines) {
    final scheduleStates = _controller.getLiveScheduleStates(routines);
    final Routine? active = scheduleStates["active"];
    final Routine? next = scheduleStates["next"];

    if (active != null) {
      final Color accent = typeColors[active.type] ?? Colors.blueAccent;
      final start = _controller.parseTimeString(active.startTime, active.date);
      final end = _controller.parseTimeString(active.endTime, active.date);

      String countdownText = "";
      double progress = 0.0;

      if (start != null && end != null) {
        final now = DateTime.now();
        final totalDuration = end.difference(start).inSeconds;
        final elapsed = now.difference(start).inSeconds;
        final remainingSecs = end.difference(now).inSeconds;

        progress = (elapsed / totalDuration).clamp(0.0, 1.0);

        if (remainingSecs > 0) {
          if (remainingSecs >= 3600) {
            final hours = remainingSecs ~/ 3600;
            final mins = (remainingSecs % 3600) ~/ 60;
            final secs = remainingSecs % 60;
            countdownText = "${hours}h ${mins}m ${secs}s left";
          } else if (remainingSecs >= 60) {
            final mins = remainingSecs ~/ 60;
            final secs = remainingSecs % 60;
            countdownText = "${mins}m ${secs}s left";
          } else {
            countdownText = "${remainingSecs}s left";
          }
        } else {
          countdownText = "Class ending...";
        }
      }

      return _buildGlassCard(
        opacity: 0.08,
        borderColor: accent.withOpacity(0.3),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Pulsing Live Dot
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _pulseActive ? accent : accent.withOpacity(0.3),
                          shape: BoxShape.circle,
                          boxShadow: _pulseActive
                              ? [
                                  BoxShadow(
                                    color: accent.withOpacity(0.6),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  )
                                ]
                              : [],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "CURRENT CLASS",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accent, letterSpacing: 1),
                      ),
                    ],
                  ),
                  Text(
                    countdownText.isNotEmpty ? countdownText : "${active.startTime} - ${active.endTime}",
                    style: TextStyle(
                      color: countdownText.isNotEmpty ? accent : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      active.title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${active.startTime} - ${active.endTime}",
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Dynamic progress bar with LayoutBuilder
              LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  return Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        height: 6,
                        width: totalWidth * progress,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent.withOpacity(0.6), accent],
                          ),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    if (next != null) {
      final start = _controller.parseTimeString(next.startTime, next.date);
      if (start != null) {
        final now = DateTime.now();
        final diffSecs = start.difference(now).inSeconds;
        if (diffSecs > 0 && diffSecs <= 3600) {
          final Color accent = typeColors[next.type] ?? Colors.blueAccent;
          
          final mins = diffSecs ~/ 60;
          final secs = diffSecs % 60;
          final countdownStr = mins > 0 ? "${mins}m ${secs}s" : "${secs}s";

          return _buildGlassCard(
            opacity: 0.08,
            borderColor: accent.withOpacity(0.2),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.alarm_on_rounded, color: accent, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "UP NEXT IN $countdownStr",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: accent,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          next.title,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildAnalyticsDashboard() {
    if (_weeklyRoutineStream == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _weeklyRoutineStream,
      builder: (context, snapshot) {
        List<Routine> weeklyRoutines = [];
        if (snapshot.hasData) {
          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
          weeklyRoutines = snapshot.data!.docs
              .map((doc) => Routine.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .where((r) => r.userId == currentUid)
              .toList();
        }

        // Calculations
        double classHours = 0.0;
        double studyHours = 0.0;
        int checkedInClasses = 0;
        int totalClasses = 0;

        for (var r in weeklyRoutines) {
          double duration = 1.0;
          final start = _controller.parseTimeString(r.startTime, r.date);
          final end = _controller.parseTimeString(r.endTime, r.date);
          if (start != null && end != null) {
            duration = end.difference(start).inMinutes / 60.0;
          }

          if (r.type == 'Lecture' || r.type == 'Lab' || r.type == 'Exam') {
            classHours += duration;
            totalClasses++;
            if (r.isCheckedIn) {
              checkedInClasses++;
            }
          } else if (r.type == 'Study') {
            studyHours += duration;
          }
        }

        double attendanceRate = totalClasses > 0 ? (checkedInClasses / totalClasses) * 100 : 0.0;
        int weeklyXp = checkedInClasses * 35;
        double xpProgress = (weeklyXp / 210).clamp(0.0, 1.0); // 210 XP target

        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: _buildGlassCard(
            opacity: _isAnalyticsExpanded ? 0.08 : 0.04,
            borderColor: _isAnalyticsExpanded ? Colors.purpleAccent.withOpacity(0.2) : Colors.white10,
            child: Column(
              children: [
                // Header (Tap to Expand/Collapse)
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isAnalyticsExpanded = !_isAnalyticsExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purpleAccent.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.analytics_rounded, color: Colors.purpleAccent, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "WEEKLY PRODUCTIVITY STATS",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isAnalyticsExpanded ? "Tap to collapse" : "Tap to view weekly stats",
                                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Icon(
                          _isAnalyticsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  ),
                ),

                // Collapsible Body
                if (_isAnalyticsExpanded) ...[
                  const Divider(color: Colors.white10, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Section: Hours Comparison
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatRow(
                                title: "Class Hours",
                                value: "${classHours.toStringAsFixed(1)}h",
                                color: Colors.blueAccent,
                                icon: Icons.school_rounded,
                              ),
                              const SizedBox(height: 12),
                              _buildStatRow(
                                title: "Self Study",
                                value: "${studyHours.toStringAsFixed(1)}h",
                                color: Colors.greenAccent,
                                icon: Icons.menu_book_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Center Section: Attendance %
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                "${attendanceRate.toStringAsFixed(0)}%",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Attendance Rate",
                                style: TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 4,
                                width: 70,
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: (attendanceRate / 100).clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: attendanceRate >= 75 ? Colors.greenAccent : Colors.orangeAccent,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Right Section: Radial XP Progress Gauge
                        Column(
                          children: [
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CircularProgressIndicator(
                                    value: xpProgress,
                                    strokeWidth: 4.5,
                                    backgroundColor: Colors.white10,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                                  ),
                                  Center(
                                    child: Icon(
                                      Icons.bolt_rounded,
                                      color: xpProgress >= 1.0 ? Colors.amberAccent : Colors.purpleAccent,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "+${weeklyXp} XP",
                              style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow({required String title, required String value, required Color color, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: color.withOpacity(0.7), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  // Calendar Header and Title
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${_controller.getGreeting()}, $_studentName 👋",
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                "My Schedule",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _showTemplateManagerSheet,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffa855f7).withOpacity(0.12),
                    border: Border.all(color: const Color(0xffa855f7).withOpacity(0.3), width: 1.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xffa855f7).withOpacity(0.2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.copy_all_rounded, color: Color(0xffd8b4fe), size: 20),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _controller.selectDate(DateTime.now());
                  _controller.setWeek(DateTime.now());
                },
                child: _buildGlassCard(
                  opacity: 0.08,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.today_rounded, color: Colors.white70, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Week Strip Selector
  Widget _buildWeekStrip() {
    DateTime startOfWeek = _controller.currentWeek.subtract(
      Duration(days: _controller.currentWeek.weekday - 1),
    );

    return Column(
      children: [
        // Navigation Month row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_controller.currentWeek),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white60, size: 26),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _controller.previousWeek();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white60, size: 26),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _controller.nextWeek();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),

        // Date selection cards
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: 7,
            itemBuilder: (context, index) {
              DateTime date = startOfWeek.add(Duration(days: index));
              bool isSelected = DateUtils.isSameDay(date, _controller.selectedDate);
              bool isToday = DateUtils.isSameDay(date, DateTime.now());

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _controller.selectDate(date);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 58,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blueAccent
                        : Colors.white.withOpacity(0.03),
                    border: Border.all(
                      color: isSelected
                          ? Colors.blueAccent
                          : isToday
                              ? Colors.white24
                              : Colors.transparent,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.35),
                              blurRadius: 12,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(date).toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('d').format(date),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }

  // Attendance Check-In celebration overlay
  void _playCelebration() {
    HapticFeedback.heavyImpact();
    // Confetti or visual celebration (can hook into a snackbar)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Text("🎓 ", style: TextStyle(fontSize: 22)),
            Expanded(
              child: Text(
                "Check-In Complete! Attended class & earned +35 Focus XP!",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Slide drawer to display detailed Notes & Homework notepad
  void _showClassDetailsDrawer(Routine routine) {
    final TextEditingController notesFieldController = TextEditingController(text: routine.notes);
    final Color accent = typeColors[routine.type] ?? Colors.blueAccent;
    bool isDeleted = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff0f172a),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              border: Border.all(
                color: accent.withOpacity(0.25),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pull notch
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),

                // Class Name and Type
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        routine.title,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accent.withOpacity(0.3)),
                      ),
                      child: Text(
                        routine.type.toUpperCase(),
                        style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Location & Time metadata
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, color: accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "${routine.startTime} — ${routine.endTime}",
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(width: 20),
                    Icon(Icons.location_on_rounded, color: accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        routine.location.isNotEmpty ? routine.location : "No Location",
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // Lecture Notes Area
                const Text(
                  "Lecture Notes & Tasks",
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesFieldController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Add homework details, links, or notes from this class...",
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // Action row
                Row(
                  children: [
                    // Delete Class
                    GestureDetector(
                      onTap: () {
                        AwesomeDialog(
                          context: context,
                          dialogType: DialogType.warning,
                          title: "Delete Class?",
                          desc: "Are you sure you want to delete ${routine.title}?",
                          btnCancelOnPress: () {},
                          btnOkOnPress: () {
                            isDeleted = true;
                            Navigator.pop(context);
                            if (routine.id != null) {
                              firestore.collection("routine").doc(routine.id).delete();
                              NotificationService().cancelRoutineNotification(routine.id!);
                            }
                          },
                        ).show();
                      },
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.red.withOpacity(0.12),
                        child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Save changes
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "SAVE NOTES",
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) async {
      if (!isDeleted && routine.id != null) {
        try {
          final text = notesFieldController.text.trim();
          await firestore.collection("routine").doc(routine.id).update({
            "notes": text,
          });
        } catch (e) {
          // ignore
        }
      }
      notesFieldController.dispose();
    });
  }

  // Redesigned Add Routine bottom sheet
  void _showAddRoutineSheet() {
    titleController.clear();
    locationController.clear();
    selectedType = "Lecture";
    startTime = null;
    endTime = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final Color accent = typeColors[selectedType] ?? Colors.blueAccent;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xff0f172a),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: accent.withOpacity(0.25),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Add Class Block",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: accent.withOpacity(0.3), blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Subject Name",
                        labelStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        prefixIcon: Icon(Icons.book_rounded, color: accent),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Location
                    TextField(
                      controller: locationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Room / Location",
                        labelStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        prefixIcon: Icon(Icons.location_on_rounded, color: accent),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Type selector Wrap
                    const Text("Type", style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: routineTypes.map((type) {
                        bool isSel = selectedType == type;
                        Color color = typeColors[type] ?? Colors.blueAccent;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedType = type),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? color.withOpacity(0.18) : Colors.white.withOpacity(0.03),
                              border: Border.all(color: isSel ? color : Colors.white12, width: 1.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                color: isSel ? Colors.white : Colors.white38,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Times
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePickerBox(
                            "Start Time",
                            startTime,
                            () async {
                              TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: startTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setSheetState(() => startTime = picked);
                              }
                            },
                            accent,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildTimePickerBox(
                            "End Time",
                            endTime,
                            () async {
                              TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: endTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setSheetState(() => endTime = picked);
                              }
                            },
                            accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Save Button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: accent.withOpacity(0.4),
                        ),
                        onPressed: () {
                          if (titleController.text.trim().isEmpty || locationController.text.trim().isEmpty) {
                            AwesomeDialog(
                              context: context,
                              dialogType: DialogType.warning,
                              title: "Missing Info",
                              desc: "Please fill in Subject and Room details.",
                              btnOkOnPress: () {},
                            ).show();
                            return;
                          }
                          if (startTime == null || endTime == null) {
                            AwesomeDialog(
                              context: context,
                              dialogType: DialogType.warning,
                              title: "Select Time",
                              desc: "Please choose Start and End time.",
                              btnOkOnPress: () {},
                            ).show();
                            return;
                          }

                          _saveRoutine();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "ADD TO TIMETABLE",
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper widget for showing time boxes
  Widget _buildTimePickerBox(String label, TimeOfDay? time, VoidCallback onTap, Color accent) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(
              time == null ? "-- : --" : time.format(context),
              style: TextStyle(color: time == null ? Colors.white24 : Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // Firestore save routine
  void _saveRoutine() async {
    DateTime date = DateTime(
      _controller.selectedDate.year,
      _controller.selectedDate.month,
      _controller.selectedDate.day,
    );

    final routineData = {
      "userId": FirebaseAuth.instance.currentUser?.uid ?? "",
      "title": titleController.text.trim(),
      "location": locationController.text.trim(),
      "type": selectedType,
      "startTime": startTime?.format(context),
      "endTime": endTime?.format(context),
      "date": Timestamp.fromDate(date),
      "notes": "",
      "isCheckedIn": false,
      "createdAt": FieldValue.serverTimestamp(),
    };

    final docRef = await firestore.collection("routine").add(routineData);

    // Schedule notification for the newly added routine
    final routineObj = Routine.fromMap(routineData, docRef.id);
    await NotificationService().scheduleRoutineNotification(routineObj);
  }

  // --- Quick Day Templates (Firestore CRUD & Cloning logic) ---

  Future<List<Routine>> _fetchRoutinesForSelectedDate() async {
    DateTime startOfDay = DateTime(
      _controller.selectedDate.year,
      _controller.selectedDate.month,
      _controller.selectedDate.day,
    );
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    final querySnapshot = await firestore
        .collection("routine")
        .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where("date", isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return querySnapshot.docs
        .map((doc) => Routine.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((r) => r.userId == currentUid)
        .toList();
  }

  Future<void> _saveCurrentDayAsTemplate() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final List<Routine> todayRoutines = await _fetchRoutinesForSelectedDate();

    if (todayRoutines.isEmpty) {
      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.warning,
          title: "Khali Din! 📭",
          desc: "Aaj ke din koi class scheduled nahi hai. Pehle timetable me classes add kijiye!",
          btnOkOnPress: () {},
        ).show();
      }
      return;
    }

    final nameController = TextEditingController();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff0f172a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10),
          ),
          title: const Text("Save Schedule as Template", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "e.g. Monday Lectures, Exam Prep Day",
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () async {
                final templateName = nameController.text.trim();
                if (templateName.isEmpty) return;
                Navigator.pop(context);

                final routinesList = todayRoutines.map((r) => {
                  "title": r.title,
                  "type": r.type,
                  "location": r.location,
                  "startTime": r.startTime,
                  "endTime": r.endTime,
                  "notes": r.notes,
                }).toList();

                await firestore.collection("routine_templates").add({
                  "userId": currentUid,
                  "templateName": templateName,
                  "routines": routinesList,
                  "createdAt": FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Template '$templateName' saved successfully! 📋"),
                      backgroundColor: Colors.purple.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text("Save", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyTemplate(Map<String, dynamic> templateData) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final templateName = templateData["templateName"] ?? "Template";
    final routinesList = templateData["routines"] as List<dynamic>?;
    final targetDate = DateTime(
      _controller.selectedDate.year,
      _controller.selectedDate.month,
      _controller.selectedDate.day,
    );

    if (routinesList == null || routinesList.isEmpty) return;

    for (var rMap in routinesList) {
      if (rMap is Map) {
        final cleanMap = Map<String, dynamic>.from(rMap);
        final routineData = {
          "userId": currentUid,
          "title": cleanMap["title"] ?? "",
          "location": cleanMap["location"] ?? "",
          "type": cleanMap["type"] ?? "Lecture",
          "startTime": cleanMap["startTime"] ?? "",
          "endTime": cleanMap["endTime"] ?? "",
          "date": Timestamp.fromDate(targetDate),
          "notes": cleanMap["notes"] ?? "",
          "isCheckedIn": false,
          "createdAt": FieldValue.serverTimestamp(),
        };

        final docRef = await firestore.collection("routine").add(routineData);

        // Schedule notification
        final routineObj = Routine.fromMap(routineData, docRef.id);
        await NotificationService().scheduleRoutineNotification(routineObj);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text("📋 ", style: TextStyle(fontSize: 22)),
              Expanded(
                child: Text(
                  "Applied '$templateName' template to ${DateFormat('yMMMMd').format(targetDate)}!",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  }

  void _showTemplateManagerSheet() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xff090d16),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white12, width: 1.2),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Timetable Templates 📋",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white38),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffa855f7).withOpacity(0.12),
                      foregroundColor: const Color(0xffd8b4fe),
                      side: BorderSide(color: const Color(0xffa855f7).withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _saveCurrentDayAsTemplate();
                    },
                    icon: const Icon(Icons.add_box_outlined, size: 20),
                    label: const Text(
                      "SAVE CURRENT DAY AS TEMPLATE",
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: firestore
                          .collection("routine_templates")
                          .where("userId", isEqualTo: currentUid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.copy_all_rounded, color: Colors.white12, size: 48),
                                const SizedBox(height: 12),
                                const Text(
                                  "No templates saved yet",
                                  style: TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Save a schedule to reuse it later",
                                  style: TextStyle(color: Colors.white24, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: docs.length,
                          itemBuilder: (context, idx) {
                            final data = docs[idx].data() as Map<String, dynamic>;
                            final docId = docs[idx].id;
                            final name = data["templateName"] ?? "Unnamed Template";
                            final routines = data["routines"] as List<dynamic>?;
                            final count = routines?.length ?? 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.2),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffa855f7).withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.style_rounded, color: Color(0xffc084fc), size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "$count Class Block${count > 1 ? 's' : ''}",
                                          style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xff10b981).withOpacity(0.15),
                                      foregroundColor: const Color(0xff34d399),
                                      side: BorderSide(color: const Color(0xff10b981).withOpacity(0.3)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _applyTemplate(data);
                                    },
                                    child: const Text("Apply", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                    onPressed: () {
                                      AwesomeDialog(
                                        context: context,
                                        dialogType: DialogType.warning,
                                        title: "Delete Template?",
                                        desc: "Are you sure you want to delete template '$name'?",
                                        btnCancelOnPress: () {},
                                        btnOkOnPress: () {
                                          firestore.collection("routine_templates").doc(docId).delete();
                                        },
                                      ).show();
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Stream-based schedule layout
  Widget _buildRoutineList() {
    if (_routineStream == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _routineStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        }

        var list = <Routine>[];
        if (snapshot.hasData) {
          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
          list = snapshot.data!.docs
              .map((doc) => Routine.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .where((r) => r.userId == currentUid)
              .toList();

          // Sort items chronologically by parsed time
          list.sort((a, b) {
            final t1 = _controller.parseTimeString(a.startTime, a.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final t2 = _controller.parseTimeString(b.startTime, b.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return t1.compareTo(t2);
          });

          // Apply category filter locally
          if (_selectedFilter != "All") {
            list = list.where((r) => r.type.toLowerCase() == _selectedFilter.toLowerCase()).toList();
          }
        }

        // Render Dynamic spark and active countdown trackers
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: _buildDailySparkCard(list),
            ),
            if (list.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
                child: _buildLiveCountdownPanel(list),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: list.isEmpty ? _buildEmptyState() : _buildTimeline(list),
            ),
          ],
        );
      },
    );
  }

  // Sleek Timeline path with nodes
  Widget _buildTimeline(List<Routine> routines) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        physics: const BouncingScrollPhysics(),
        itemCount: routines.length,
        itemBuilder: (context, index) {
          final r = routines[index];
          final clashing = _getClashingRoutines(r, routines);
          final bool hasClash = clashing.isNotEmpty;
          final Color accent = typeColors[r.type] ?? Colors.blueAccent;

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 450),
            child: SlideAnimation(
              verticalOffset: 40.0,
              child: FadeInAnimation(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline Node
                    Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: hasClash ? Colors.redAccent : accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (hasClash ? Colors.redAccent : accent).withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                        ),
                        Container(
                          width: 2,
                          height: hasClash ? 140 : 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [hasClash ? Colors.redAccent : accent, Colors.white10],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Main Info Card
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showClassDetailsDrawer(r),
                        child: _buildGlassCard(
                          opacity: 0.06,
                          borderColor: hasClash ? Colors.redAccent.withOpacity(0.8) : accent.withOpacity(0.18),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title and Icon
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r.title,
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(typeIcons[r.type] ?? Icons.book, color: hasClash ? Colors.redAccent : accent.withOpacity(0.8), size: 18),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Room details
                                Text(
                                  r.location.isNotEmpty ? r.location : "No Location Details",
                                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                                if (hasClash) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.08),
                                      border: Border.all(color: Colors.redAccent.withOpacity(0.25), width: 1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            "Timing clash with: ${clashing.map((c) => c.title).join(', ')}",
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),

                                // Time and Attendance Check-In row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "${r.startTime} — ${r.endTime}",
                                      style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),

                                    // Attendance trigger
                                    GestureDetector(
                                      onTap: () {
                                        if (r.isCheckedIn) return;
                                        _controller.checkIn(r, (updated) async {
                                          if (r.id != null) {
                                            await firestore.collection("routine").doc(r.id).update({
                                              "isCheckedIn": true,
                                            });
                                          }
                                          _playCelebration();
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: r.isCheckedIn ? Colors.green.withOpacity(0.15) : accent.withOpacity(0.1),
                                          border: Border.all(
                                            color: r.isCheckedIn ? Colors.green : accent,
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              r.isCheckedIn ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                                              size: 11,
                                              color: r.isCheckedIn ? Colors.green : accent,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              r.isCheckedIn ? "ATTENDED (+35 XP)" : "CHECK IN (+35 XP)",
                                              style: TextStyle(
                                                color: r.isCheckedIn ? Colors.green : accent,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Schedule empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.02),
            ),
            child: const Icon(Icons.school_outlined, size: 72, color: Colors.white12),
          ),
          const SizedBox(height: 20),
          const Text(
            "No classes scheduled",
            style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            "Tap + to customize your daily timetable 📚",
            style: TextStyle(color: Colors.white30, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final categories = ["All", "Lecture", "Lab", "Exam", "Study", "Personal"];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedFilter == cat;
          final Color catColor = typeColors[cat] ?? Colors.purpleAccent;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedFilter = cat;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? catColor.withOpacity(0.15) : Colors.white.withOpacity(0.02),
                border: Border.all(
                  color: isSelected ? catColor : Colors.white.withOpacity(0.06),
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: catColor.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 0.5,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  cat.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712), // Deep carbon cyber color
      body: Stack(
        children: [
          // Background soft glows
          Positioned(
            top: -100,
            right: -80,
            child: CircleAvatar(radius: 180, backgroundColor: Colors.blue.withOpacity(0.04)),
          ),
          Positioned(
            bottom: -50,
            left: -80,
            child: CircleAvatar(radius: 180, backgroundColor: Colors.purple.withOpacity(0.03)),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                _buildAnalyticsDashboard(),
                _buildWeekStrip(),
                const SizedBox(height: 14),
                _buildFilterChips(),
                const SizedBox(height: 10),
                Expanded(child: _buildRoutineList()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'routine_fab',
        onPressed: _showAddRoutineSheet,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.blue]),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          child: const Icon(Icons.add_rounded, size: 30, color: Colors.white),
        ),
      ),
    );
  }
}
