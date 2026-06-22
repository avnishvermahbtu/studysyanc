import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysync/login_page.dart';
import 'package:confetti/confetti.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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
  late ConfettiController _confettiController;
  String _studentName = "Student";
  String _selectedAvatar = "📚";
  bool _celebratedToday = false;

  @override
  void initState() {
    super.initState();
    _focusController = FocusController();
    _focusController.addListener(_onFocusUpdate);
    _loadStudentName();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  Future<void> _loadStudentName() async {
    final prefs = await SharedPreferences.getInstance();
    final localName = prefs.getString('student_name');
    final localAvatar = prefs.getString('student_avatar') ?? "📚";
    if (mounted) {
      setState(() {
        _selectedAvatar = localAvatar;
        if (localName != null && localName.isNotEmpty) {
          _studentName = localName;
        }
      });
    }
    
    if (localName == null || localName.isEmpty) {
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
    _confettiController.dispose();
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

  void _showAvatarInventorySheet() {
    final currentLevel = _focusController.level;
    final avatars = [
      {"emoji": "📚", "name": "Freshman Novice", "level": 1, "tier": "Bronze Scholar"},
      {"emoji": "⚡", "name": "Focus Apprentice", "level": 2, "tier": "Bronze Scholar"},
      {"emoji": "⚔️", "name": "Quiz Crusader", "level": 3, "tier": "Silver Pioneer"},
      {"emoji": "🧠", "name": "Mind Palace Guru", "level": 5, "tier": "Silver Pioneer"},
      {"emoji": "🧙‍♂️", "name": "Deep Work Wizard", "level": 7, "tier": "Gold Sage"},
      {"emoji": "👑", "name": "Omniscient Sage", "level": 10, "tier": "Gold Sage"},
      {"emoji": "🌟", "name": "Nebula Voyager", "level": 12, "tier": "Platinum Hero"},
      {"emoji": "🔥", "name": "Phoenix Ascendant", "level": 15, "tier": "Platinum Hero"},
      {"emoji": "🌌", "name": "Cosmos Weaver", "level": 18, "tier": "Diamond Hero"},
      {"emoji": "🔮", "name": "Eternal Legend", "level": 20, "tier": "Diamond Hero"},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (stateContext, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xff0d0e15).withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Icon(Icons.military_tech_rounded, color: Colors.amberAccent, size: 28),
                        SizedBox(width: 8),
                        Text(
                          "Avatar Inventory",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Padhai karke XP kamao aur unique avatars unlock karo! Select your active title:",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: avatars.length,
                      itemBuilder: (context, index) {
                        final avatar = avatars[index];
                        final name = avatar["name"] as String;
                        final emoji = avatar["emoji"] as String;
                        final reqLvl = avatar["level"] as int;
                        final tier = avatar["tier"] as String;
                        
                        final isUnlocked = currentLevel >= reqLvl;
                        final isActive = _selectedAvatar == emoji;
                        
                        Color borderCol = Colors.white.withOpacity(0.06);
                        if (isActive) {
                          borderCol = const Color(0xffec4899);
                        } else if (isUnlocked) {
                          borderCol = Colors.white24;
                        }
                        
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            if (!isUnlocked) {
                              showDialog(
                                context: stateContext,
                                builder: (dialogContext) {
                                  return AlertDialog(
                                    backgroundColor: const Color(0xff0d0e15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                                    ),
                                    title: Row(
                                      children: [
                                        const Icon(Icons.lock_rounded, color: Colors.orangeAccent, size: 24),
                                        const SizedBox(width: 8),
                                        const Text(
                                          "Title Locked! 🔒",
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                        ),
                                      ],
                                    ),
                                    content: Text(
                                      "Arey yaar, ye avatar abhi locked hai!\n\nTitle: $name\nRequired Level: $reqLvl\nYour Current Level: $currentLevel\n\nDaily study block complete karo aur XP gain karke level up karo! 💪",
                                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.45),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xffec4899), Color(0xff818cf8)],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            "Got it!",
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                              return;
                            }
                            
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('student_avatar', emoji);
                            
                            setState(() {
                              _selectedAvatar = emoji;
                            });
                            setModalState(() {});
                            
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            
                            if (this.context.mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text("Active avatar updated to $emoji $name!"),
                                  backgroundColor: const Color(0xff10b981),
                                ),
                              );
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isActive 
                                  ? const Color(0xffec4899).withOpacity(0.1)
                                  : (isUnlocked ? Colors.white.withOpacity(0.03) : Colors.black26),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: borderCol,
                                width: isActive ? 1.5 : 1,
                              ),
                              boxShadow: isActive ? [
                                BoxShadow(
                                  color: const Color(0xffec4899).withOpacity(0.15),
                                  blurRadius: 10,
                                  spreadRadius: -2,
                                )
                              ] : null,
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        emoji,
                                        style: const TextStyle(
                                          fontSize: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        name,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isUnlocked ? Colors.white : Colors.white30,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isUnlocked ? tier.split(" ").first : "Lvl $reqLvl",
                                        style: TextStyle(
                                          color: isUnlocked ? Colors.white54 : Colors.redAccent.withOpacity(0.6),
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isUnlocked)
                                  const Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Icon(Icons.lock_rounded, color: Colors.white30, size: 14),
                                  ),
                                if (isActive)
                                  const Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Icon(Icons.check_circle_rounded, color: Color(0xff10b981), size: 14),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLevelProgress() {
    final xp = _focusController.xp;
    final lvl = _focusController.level;
    final nextLevelXp = _focusController.xpNeededForNextLevel();
    final double pct = (xp / nextLevelXp).clamp(0.0, 1.0);
    final rank = _focusController.getRankName();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showAvatarInventorySheet,
        child: DashboardCard(
          isGlass: true,
          bgOpacity: 0.02,
          gradientBorder: const [Colors.white12, Colors.white10],
          glowColor: const Color(0xff6366f1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xff6366f1), Color(0xffa855f7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff6366f1).withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ],
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "LVL",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "$lvl",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                            rank,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            "$xp / ${nextLevelXp} XP",
                            style: const TextStyle(
                              color: Color(0xffa5b4fc),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                                    colors: [Color(0xff6366f1), Color(0xffec4899)],
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreakFlameTimeline() {
    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final todayIdx = DateTime.now().weekday - 1; // 0 = Mon, 6 = Sun
    final goal = _focusController.dailyStudyGoal;
    
    return DashboardCard(
      isGlass: true,
      bgOpacity: 0.02,
      gradientBorder: const [Colors.white12, Colors.white10],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Total Streak
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      "Weekly Streak",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.3), width: 1),
                  ),
                  child: Text(
                    "${_focusController.streak} Day Streak 🔥",
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 7 Days Grid/Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (idx) {
                final dayName = days[idx];
                final minutes = _focusController.weeklyMinutes[dayName] ?? 0;
                final isToday = idx == todayIdx;
                final isPast = idx < todayIdx;
                final isFuture = idx > todayIdx;
                
                // Determine flame style
                Widget flameIcon;
                Color flameBg;
                Color flameBorder;
                
                if (isFuture) {
                  flameIcon = const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 16);
                  flameBg = Colors.white.withOpacity(0.02);
                  flameBorder = Colors.white.withOpacity(0.05);
                } else {
                  if (minutes >= goal) {
                    // Goal Reached
                    flameIcon = const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 20);
                    flameBg = Colors.orangeAccent.withOpacity(0.15);
                    flameBorder = Colors.orangeAccent.withOpacity(0.4);
                  } else if (minutes > 0) {
                    // Studied but not reached goal
                    flameIcon = const Icon(Icons.flash_on_rounded, color: Colors.amberAccent, size: 18);
                    flameBg = Colors.amberAccent.withOpacity(0.1);
                    flameBorder = Colors.amberAccent.withOpacity(0.3);
                  } else {
                    // No study (today or past)
                    flameIcon = Icon(
                      isToday ? Icons.hourglass_empty_rounded : Icons.circle_outlined, 
                      color: Colors.white30, 
                      size: 16
                    );
                    flameBg = Colors.white.withOpacity(0.03);
                    flameBorder = Colors.white.withOpacity(0.08);
                  }
                }
                
                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          backgroundColor: const Color(0xff0d0e15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                          ),
                          title: Row(
                            children: [
                              Icon(
                                isFuture 
                                    ? Icons.lock_outline_rounded 
                                    : (minutes >= goal ? Icons.local_fire_department_rounded : Icons.flash_on_rounded),
                                color: isFuture 
                                    ? Colors.white38 
                                    : (minutes >= goal ? Colors.orangeAccent : Colors.amberAccent),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isToday ? "Today ($dayName)" : dayName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ],
                          ),
                          content: Text(
                            isFuture 
                                ? "This day is locked. Padho aur consistency maintain karo jab ye din aayega! 🔒" 
                                : "You studied $minutes minutes on $dayName.\nDaily Goal: $goal minutes.\n\n${minutes >= goal ? "Great job! Goal completed! 🔥" : minutes > 0 ? "Good start, but keep pushing to hit the goal! ⚡" : "No study block recorded for this day yet. 🎯"}",
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.45),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xffec4899), Color(0xff818cf8)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "Awesome",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Column(
                    children: [
                      Text(
                        dayName[0], // Display 'M', 'T', 'W', etc.
                        style: TextStyle(
                          color: isToday 
                              ? const Color(0xff6366f1) 
                              : (isFuture ? Colors.white30 : Colors.white70),
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: flameBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isToday && minutes < goal
                                ? const Color(0xff6366f1)
                                : flameBorder,
                            width: isToday ? 1.5 : 1,
                          ),
                          boxShadow: minutes >= goal && !isFuture
                              ? [
                                  BoxShadow(
                                    color: Colors.orangeAccent.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: -1,
                                  )
                                ]
                              : null,
                        ),
                        child: Center(child: flameIcon),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _focusController.streak > 0 
                    ? "Study daily to keep your flame alive! 🔥" 
                    : "Complete today's goal to start a streak! ⚡",
                style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
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
          height: 105,
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
                  isGlass: true,
                  bgOpacity: 0.02,
                  gradientBorder: const [Colors.white12, Colors.white10],
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
                        const SizedBox(height: 10),
                        Text(
                          item["title"],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (item["title"] == "Co-Study") ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                "3 studying",
                                style: TextStyle(
                                  color: const Color(0xff10b981).withOpacity(0.85),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const _LiveCounterPulseDot(),
                            ],
                          ),
                        ] else ...[
                          Text(
                            item["subtitle"],
                            style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 9,
                            ),
                          ),
                        ],
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

    // Confetti Auto-Trigger on Goal Completion
    if (progressPct >= 1.0 && !_celebratedToday) {
      _celebratedToday = true;
      _confettiController.play();
    } else if (progressPct < 1.0 && _celebratedToday) {
      _celebratedToday = false;
    }

    return Scaffold(
      backgroundColor: const Color(0xff020617),
      body: Stack(
        children: [
          // Dynamic space backgrounds radial glowing orbs
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xff6366f1).withOpacity(0.16),
                    const Color(0xffa855f7).withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(0.12),
                    const Color(0xff06b6d4).withOpacity(0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 250,
            left: -150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.pinkAccent.withOpacity(0.08),
                    const Color(0xffec4899).withOpacity(0.01),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 520,
            right: -140,
            child: Container(
              width: 330,
              height: 330,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xff818cf8).withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Screen Scroll Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildLevelProgress(),
                  const SizedBox(height: 18),
                  _buildProgressCard(minutesToday, progressPct),
                  const SizedBox(height: 18),
                  _buildStreakFlameTimeline(),
                  const SizedBox(height: 24),
                  _buildTeacherBulletin(),
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

          // Top Center Confetti Blast on goal completion
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xff6366f1),
                Colors.orangeAccent,
                Colors.pinkAccent,
                Colors.greenAccent,
                Colors.amberAccent,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Premium Profile Avatar
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showSettingsBottomSheet(context),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xff6366f1), Color(0xffec4899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff6366f1).withOpacity(0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: Center(
                child: Text(
                  _selectedAvatar,
                  style: const TextStyle(
                    fontSize: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${_getGreeting()} 👋",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildLivePulseCounter(),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Action Buttons Row
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(color: Colors.white10, width: 1),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Color(0xff93c5fd),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _showSettingsBottomSheet(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(color: Colors.white10, width: 1),
                ),
                child: const Icon(
                  Icons.settings_rounded,
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
        isGlass: true,
        bgOpacity: 0.02,
        gradientBorder: const [Color(0xff6366f1), Color(0xffec4899)],
        glowColor: const Color(0xff6366f1),
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
                        color: Color(0xffa5b4fc),
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
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.edit_rounded,
                          color: const Color(0xff6366f1).withOpacity(0.7),
                          size: 13,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              CircularPercentIndicator(
                radius: 42.0,
                lineWidth: 8.0,
                percent: progressPct,
                center: Text(
                  "${(progressPct * 100).toInt()}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                progressColor: const Color(0xff6366f1),
                backgroundColor: Colors.white.withOpacity(0.05),
                circularStrokeCap: CircularStrokeCap.round,
                animateFromLastPercent: true,
                animation: true,
              ),
            ],
          ),
        ),
      ),
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
          onPressed: () => widget.onNavigate?.call(3), // Switch to Questboard is index 3
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
            isGlass: true,
            bgOpacity: 0.02,
            gradientBorder: const [Colors.white10, Colors.white10],
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

        return AnimationLimiter(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayTasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final task = displayTasks[index];
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 30.0,
                  child: FadeInAnimation(
                    child: DashboardCard(
                      isGlass: true,
                      bgOpacity: 0.02,
                      gradientBorder: const [Colors.white10, Colors.white10],
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
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            if (task.isRecommended) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.orange.withOpacity(0.4), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 10, color: Colors.orange),
                                    const SizedBox(width: 2),
                                    Text(
                                      task.recommendedBy.isNotEmpty ? task.recommendedBy : "Recommended",
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
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
                    ),
                  ),
                ),
              );
            },
          ),
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

    return AnimationLimiter(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
        ),
        itemCount: actions.length,
        itemBuilder: (context, idx) {
          final act = actions[idx];
          return AnimationConfiguration.staggeredGrid(
            position: idx,
            duration: const Duration(milliseconds: 375),
            columnCount: 2,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: DashboardCard(
                  onTap: act["onTap"],
                  isGlass: true,
                  bgOpacity: 0.02,
                  gradientBorder: const [Colors.white10, Colors.white10],
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
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMotivationBanner() {
    final streak = _focusController.streak;

    return DashboardCard(
      isGlass: true,
      bgOpacity: 0.02,
      gradientBorder: const [Colors.white10, Colors.white10],
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

  void _showSettingsBottomSheet(BuildContext parentContext) {
    final nameEditController = TextEditingController(text: _studentName);
    
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (stateContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(stateContext).viewInsets.bottom + 30,
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
                              
                              if (stateContext.mounted) {
                                Navigator.pop(stateContext);
                              }
                              
                              if (parentContext.mounted) {
                                ScaffoldMessenger.of(parentContext).showSnackBar(
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

  Widget _buildLivePulseCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xff10b981).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff10b981).withOpacity(0.3), width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LiveCounterPulseDot(),
          SizedBox(width: 4),
          Text(
            "3 active",
            style: TextStyle(
              color: Color(0xff34d399),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherBulletin() {
    final fallbackNotices = [
      {
        "title": "Solve AI Quiz Arena MCQ Set 3",
        "content": "Prof. Amit Verma recommends practicing 15 MCQs on Chapter 4. Complete to earn bonus points!",
        "teacher": "Prof. Amit Verma",
        "tag": "Homework",
        "color": Colors.orangeAccent,
      },
      {
        "title": "Main Lobby Group Study Session",
        "content": "Join the class study session today at 5 PM. We will go through the exam preparation timeline.",
        "teacher": "Class Coordinator",
        "tag": "Event",
        "color": Colors.greenAccent,
      },
      {
        "title": "Smart Deep Work Study Tip",
        "content": "A 5-minute offline breathing break every 25 minutes of Pomodoro increases focus retention by 30%.",
        "teacher": "AI Coach",
        "tag": "Study Tip",
        "color": Colors.cyanAccent,
      },
    ];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("bulletins").snapshots(),
      builder: (context, snapshot) {
        List<Map<String, dynamic>> notices = [];
        
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final docs = List.from(snapshot.data!.docs);
          // Sort in memory to avoid Firestore index requirement error
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData["createdAt"] as Timestamp?;
            final bTime = bData["createdAt"] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
          
          notices = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final tag = data["tag"] ?? "Announcement";
            Color tagColor;
            switch (tag.toString().toLowerCase()) {
              case 'homework':
                tagColor = Colors.orangeAccent;
                break;
              case 'event':
                tagColor = Colors.greenAccent;
                break;
              case 'study tip':
              case 'tip':
                tagColor = Colors.cyanAccent;
                break;
              case 'exam alert':
              case 'exam':
                tagColor = const Color(0xffec4899);
                break;
              default:
                tagColor = const Color(0xff6366f1);
            }
            return {
              "id": doc.id,
              "title": data["title"] ?? "Notice",
              "content": data["content"] ?? "",
              "teacher": data["teacher"] ?? "Teacher",
              "tag": tag,
              "color": tagColor,
            };
          }).toList();
        } else {
          notices = fallbackNotices;
        }

        return _BulletinCarousel(notices: notices);
      },
    );
  }
}

class _BulletinCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> notices;
  const _BulletinCarousel({required this.notices});

  @override
  State<_BulletinCarousel> createState() => _BulletinCarouselState();
}

class _BulletinCarouselState extends State<_BulletinCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (widget.notices.isEmpty) return;
      if (_currentPage < widget.notices.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _showAddNoticeSheet(BuildContext parentContext) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final teacherController = TextEditingController();
    String selectedTag = "Homework";
    final tags = ["Homework", "Notice", "Event", "Study Tip", "Exam Alert"];
    
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext stateContext, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(stateContext).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: const Color(0xff0d0e15).withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Post Teacher's Notice",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Publish an announcement or study tip directly to the student dashboard.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Notice Title",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        hintText: "e.g., Tomorrow's Practice Quiz Set 3",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xffec4899)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Announcement Details",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contentController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        hintText: "Enter the details of the notice for the students...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xffec4899)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Teacher's Name / Signature",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: teacherController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        hintText: "e.g., Prof. Amit Verma",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xffec4899)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Select Notice Tag",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((tag) {
                        final isSelected = selectedTag == tag;
                        return ChoiceChip(
                          label: Text(
                            tag,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xffec4899).withOpacity(0.4),
                          backgroundColor: Colors.white.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? const Color(0xffec4899) : Colors.white.withOpacity(0.1),
                              width: 1.2,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() {
                                selectedTag = tag;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        if (titleController.text.trim().isEmpty ||
                            contentController.text.trim().isEmpty ||
                            teacherController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(stateContext).showSnackBar(
                            const SnackBar(
                              content: Text("Arey yaar! Please fill in all fields before publishing."),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        await FirebaseFirestore.instance.collection("bulletins").add({
                          "title": titleController.text.trim(),
                          "content": contentController.text.trim(),
                          "teacher": teacherController.text.trim(),
                          "tag": selectedTag,
                          "createdAt": FieldValue.serverTimestamp(),
                        });

                        if (stateContext.mounted) {
                          Navigator.pop(stateContext);
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text("Notice published successfully! ★"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xffec4899), Color(0xff818cf8)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xffec4899).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            "Publish Notice",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notices.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.campaign_rounded, color: Color(0xffec4899), size: 22),
                SizedBox(width: 8),
                Text(
                  "Teacher's Bulletin",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showAddNoticeSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xffec4899), Color(0xff818cf8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xffec4899).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        "Post Notice",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.notices.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, index) {
              final item = widget.notices[index];
              final Color tagColor = (item["color"] is Color) ? item["color"] as Color : const Color(0xff6366f1);
              return Container(
                margin: const EdgeInsets.only(right: 2),
                child: DashboardCard(
                  isGlass: true,
                  bgOpacity: 0.02,
                  gradientBorder: const [Colors.white12, Colors.white10],
                  glowColor: tagColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: tagColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: tagColor.withOpacity(0.35), width: 0.8),
                                    ),
                                    child: Text(
                                      item["tag"].toString().toUpperCase(),
                                      style: TextStyle(
                                        color: tagColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item["title"] ?? "",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item["content"] ?? "",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.65),
                                  fontSize: 11.5,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.white10,
                              child: Icon(Icons.person_rounded, size: 16, color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (item["teacher"] ?? "Teacher").toString().split(" ").last,
                              maxLines: 1,
                              style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.notices.length,
            (index) => Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index ? const Color(0xffec4899) : Colors.white12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveCounterPulseDot extends StatefulWidget {
  const _LiveCounterPulseDot();

  @override
  State<_LiveCounterPulseDot> createState() => _LiveCounterPulseDotState();
}

class _LiveCounterPulseDotState extends State<_LiveCounterPulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _pulseAnimation,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Color(0xff34d399),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0xff10b981),
              blurRadius: 4,
              spreadRadius: 1,
            )
          ],
        ),
      ),
    );
  }
}