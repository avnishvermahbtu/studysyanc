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
import '../../../core/services/subscription_service.dart';
import '../widgets/dashboard_card.dart';
import '../../ai_coach/roadmap_screen.dart';
import '../../ai_coach/backlog_screen.dart';
import 'package:studysync/core/services/tts_service.dart';
import '../../ai_coach/notes_to_quiz_screen.dart';
import '../../ai_coach/leaderboard_screen.dart';
import '../../ai_coach/quiz_revision_screen.dart';
import '../../ai_coach/ai_chatbot_screen.dart';
import '../../analytics/screens/analytics_screen.dart';
import '../../routine/screens/feynman_trainer_screen.dart';
import '../../group_study/screens/group_study_lobby_screen.dart';
import '../../flashcards/screens/deck_list_screen.dart';
import 'package:studysync/core/theme/theme_manager.dart';
import 'package:flutter/services.dart';

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
  int _currentTipIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusController = FocusController();
    _focusController.addListener(_onFocusUpdate);
    _loadStudentName();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _currentTipIndex = DateTime.now().minute % 7;
  }

  Future<void> _loadStudentName() async {
    try {
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
    } catch (e) {
      debugPrint("Error loading student name: $e");
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
      _loadStudentName();
      setState(() {});
      _checkDecayPenalty();
    }
  }

  void _checkDecayPenalty() {
    if (_focusController.lastDecayPenalty > 0) {
      final penalty = _focusController.lastDecayPenalty;
      _focusController.clearDecayPenalty();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xff0f172a),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                SizedBox(width: 10),
                Text(
                  "Inactivity Decay!",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              "You missed study days. Your streak was reset to 0, and you lost $penalty XP.\n\nKeep studying daily to stay at the top of the Hall of Fame!",
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "I WILL DO BETTER",
                  style: TextStyle(color: Color(0xff10b981), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      });
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

  Map<String, Color> _getRankColors(String rank) {
    if (rank.contains("Supreme")) {
      return {
        "accent": const Color(0xfffbbf24), // Gold/Amber
        "bg": const Color(0xfffbbf24).withOpacity(0.12),
        "glow": const Color(0xfff59e0b),
      };
    } else if (rank.contains("Grandmaster")) {
      return {
        "accent": const Color(0xffc084fc), // Purple
        "bg": const Color(0xffc084fc).withOpacity(0.12),
        "glow": const Color(0xffa855f7),
      };
    } else if (rank.contains("Ninja")) {
      return {
        "accent": const Color(0xfff87171), // Red
        "bg": const Color(0xfff87171).withOpacity(0.12),
        "glow": const Color(0xffef4444),
      };
    } else if (rank.contains("Mage")) {
      return {
        "accent": const Color(0xff22d3ee), // Cyan
        "bg": const Color(0xff22d3ee).withOpacity(0.12),
        "glow": const Color(0xff06b6d4),
      };
    } else {
      return {
        "accent": const Color(0xff34d399), // Green
        "bg": const Color(0xff34d399).withOpacity(0.12),
        "glow": const Color(0xff10b981),
      };
    }
  }

  Widget _buildLevelProgress() {
    final xp = _focusController.xp;
    final lvl = _focusController.level;
    final nextLevelXp = _focusController.xpNeededForNextLevel();
    final double pct = (xp / nextLevelXp).clamp(0.0, 1.0);
    final rank = _focusController.getRankName();
    final rankColors = _getRankColors(rank);
    final accentCol = rankColors["accent"]!;
    final bgCol = rankColors["bg"]!;
    final glowCol = rankColors["glow"]!;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showAvatarInventorySheet,
        child: DashboardCard(
          isGlass: true,
          bgOpacity: 0.04,
          gradientBorder: [accentCol.withOpacity(0.65), const Color(0xff6366f1).withOpacity(0.45)],
          glowColor: glowCol,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentCol.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentCol.withOpacity(0.15),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [const Color(0xff4f46e5), accentCol],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: glowCol.withOpacity(0.45),
                            blurRadius: 12,
                            spreadRadius: 1.5,
                          ),
                          BoxShadow(
                            color: const Color(0xff6366f1).withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: -2,
                          ),
                        ],
                        border: Border.all(color: Colors.white.withOpacity(0.45), width: 1.8),
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
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentCol.withOpacity(0.18),
                                  const Color(0xff6366f1).withOpacity(0.06),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: accentCol.withOpacity(0.35),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: glowCol.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  rank.split(" ").first,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  rank.split(" ").sublist(1).join(" ").toUpperCase(),
                                  style: TextStyle(
                                    color: accentCol,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "$xp / ${nextLevelXp} XP",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                              letterSpacing: 0.3,
                              shadows: [
                                Shadow(
                                  color: accentCol.withOpacity(0.45),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            Container(
                              height: 10,
                              color: ThemeManager.isLight 
                                  ? Colors.black.withOpacity(0.05) 
                                  : Colors.white.withOpacity(0.06),
                            ),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: pct,
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xff4f46e5),
                                      accentCol,
                                      const Color(0xffec4899),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentCol.withOpacity(0.55),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "XP PROGRESS: ${(pct * 100).toInt()}%",
                            style: TextStyle(
                              color: accentCol.withOpacity(0.95),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            nextLevelXp - xp <= 0
                                ? "MAX LEVEL REACHED 👑"
                                : "NEED ${nextLevelXp - xp} XP TO LVL ${lvl + 1} 🎯",
                            style: TextStyle(
                              color: ThemeManager.textMuted.withOpacity(0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
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
      bgOpacity: 0.04,
      gradientBorder: [const Color(0xff10b981).withOpacity(0.35), const Color(0xff3b82f6).withOpacity(0.1)],
      glowColor: const Color(0xff10b981).withOpacity(0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Total Streak
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xff10b981).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bar_chart_rounded, color: Color(0xff10b981), size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Weekly Activity & Streak",
                      style: TextStyle(
                        color: ThemeManager.textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orangeAccent.withOpacity(0.2),
                        Colors.orange.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.4), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orangeAccent.withOpacity(0.15),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    "${_focusController.streak} Day Streak 🔥",
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 7 Days Vertical Bars Grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (idx) {
                final dayName = days[idx];
                final minutes = _focusController.weeklyMinutes[dayName] ?? 0;
                final isToday = idx == todayIdx;
                final isFuture = idx > todayIdx;
                
                // Calculate height factor (out of goal)
                final double heightFactor = goal > 0 ? (minutes / goal).clamp(0.0, 1.0) : 0.0;
                final double barHeight = 70 * heightFactor; // Max height 70px
                
                Color barColor = const Color(0xff10b981); // Emerald for studied
                Gradient? barGradient;
                Widget statusIcon;
                
                if (isFuture) {
                  statusIcon = Icon(Icons.lock_rounded, color: Colors.white.withOpacity(0.15), size: 12);
                  barColor = Colors.transparent;
                } else {
                  if (minutes >= goal && goal > 0) {
                    barGradient = const LinearGradient(
                      colors: [Color(0xff6366f1), Color(0xffec4899)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    );
                    statusIcon = const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 14);
                  } else if (minutes > 0) {
                    barGradient = const LinearGradient(
                      colors: [Color(0xff10b981), Color(0xff34d399)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    );
                    statusIcon = const Icon(Icons.flash_on_rounded, color: Colors.amberAccent, size: 13);
                  } else {
                    statusIcon = Icon(
                      isToday ? Icons.hourglass_empty_rounded : Icons.radio_button_off_rounded, 
                      color: isToday ? const Color(0xff818cf8).withOpacity(0.8) : Colors.white.withOpacity(0.15), 
                      size: 12
                    );
                    barColor = Colors.transparent;
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
                      // Status Icon above bar
                      SizedBox(
                        height: 18,
                        child: Center(child: statusIcon),
                      ),
                      const SizedBox(height: 6),
                      // Vertical Bar Box
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Background Channel
                          Container(
                            width: 16,
                            height: 75,
                            decoration: BoxDecoration(
                              color: ThemeManager.isLight 
                                  ? Colors.black.withOpacity(0.04) 
                                  : Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isToday ? const Color(0xff6366f1).withOpacity(0.6) : Colors.white.withOpacity(0.04),
                                width: 1.2,
                              ),
                            ),
                          ),
                          // Filled Bar container
                          if (minutes > 0 && !isFuture)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutBack,
                              width: 16,
                              height: barHeight < 8 ? 8 : barHeight,
                              decoration: BoxDecoration(
                                color: barGradient == null ? barColor : null,
                                gradient: barGradient,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: (minutes >= goal ? const Color(0xffec4899) : const Color(0xff10b981)).withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: -1,
                                  )
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Day text label
                      Text(
                        dayName[0],
                        style: TextStyle(
                          color: isToday 
                              ? const Color(0xff818cf8) 
                              : (isFuture ? ThemeManager.textDim : ThemeManager.textMuted),
                          fontWeight: isToday ? FontWeight.w900 : FontWeight.normal,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Time Text
                      Text(
                        minutes > 0 ? (minutes >= 60 ? "${(minutes / 60).toStringAsFixed(1)}h" : "${minutes}m") : "-",
                        style: TextStyle(
                          color: isToday ? ThemeManager.textColor : ThemeManager.textDim,
                          fontSize: 9.5,
                          fontWeight: isToday ? FontWeight.w900 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                _focusController.streak > 0 
                    ? "Study daily to keep your streak glowing! 🔥" 
                    : "Complete today's goal to start a daily streak! ⚡",
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

  Widget _buildAchievementsSection() {
    final days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    final dayKey = days[DateTime.now().weekday % 7];
    final minutesToday = _focusController.weeklyMinutes[dayKey] ?? 0;
    final hoursToday = minutesToday / 60.0;
    
    final int level = _focusController.level;
    final int streak = _focusController.streak;
    final categoryMinutes = _focusController.categoryMinutes;

    final badges = [
      {
        "emoji": "🌱",
        "title": "Novice Sprout",
        "desc": "Reach Focus Level 2",
        "unlocked": level >= 2,
        "glow": Colors.greenAccent,
      },
      {
        "emoji": "🧙",
        "title": "Concentration Mage",
        "desc": "Reach Focus Level 4",
        "unlocked": level >= 4,
        "glow": Colors.purpleAccent,
      },
      {
        "emoji": "🥷",
        "title": "Deep Work Ninja",
        "desc": "Reach Focus Level 8",
        "unlocked": level >= 8,
        "glow": Colors.pinkAccent,
      },
      {
        "emoji": "🥋",
        "title": "Focus Grandmaster",
        "desc": "Reach Focus Level 15",
        "unlocked": level >= 15,
        "glow": Colors.redAccent,
      },
      {
        "emoji": "🔥",
        "title": "Streak Starter",
        "desc": "Keep a 3-day study streak",
        "unlocked": streak >= 3,
        "glow": Colors.orangeAccent,
      },
      {
        "emoji": "☄️",
        "title": "Streak Overlord",
        "desc": "Keep a 7-day study streak",
        "unlocked": streak >= 7,
        "glow": Colors.amberAccent,
      },
      {
        "emoji": "🧘‍♂️",
        "title": "Study Monk",
        "desc": "Focus for 4+ hours in a day",
        "unlocked": hoursToday >= 4.0,
        "glow": Colors.cyanAccent,
      },
      {
        "emoji": "🎯",
        "title": "Focus Marathoner",
        "desc": "Accumulate 120m in a study category",
        "unlocked": categoryMinutes.values.any((m) => m >= 120),
        "glow": Colors.tealAccent,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Your Study Badges 🏆",
              style: TextStyle(
                color: ThemeManager.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "${badges.where((b) => b['unlocked'] == true).length}/${badges.length} Unlocked",
              style: const TextStyle(
                color: Color(0xff6366f1),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final badge = badges[index];
              final isUnlocked = badge["unlocked"] as bool;
              final glowColor = badge["glow"] as Color;

              return DashboardCard(
                isGlass: true,
                bgOpacity: isUnlocked ? 0.05 : 0.01,
                glowColor: isUnlocked ? glowColor : Colors.transparent,
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Badge Emoji/Icon
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isUnlocked ? glowColor.withOpacity(0.12) : Colors.white.withOpacity(0.04),
                          border: Border.all(
                            color: isUnlocked ? glowColor.withOpacity(0.3) : Colors.white10,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            badge["emoji"] as String,
                            style: TextStyle(
                              fontSize: 20,
                              color: isUnlocked ? null : Colors.white24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              badge["title"] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isUnlocked ? Colors.white : Colors.white30,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              badge["desc"] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isUnlocked ? Colors.white54 : Colors.white24,
                                fontSize: 8.5,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedModes() {
    final List<Map<String, dynamic>> featured = [
      {
        "icon": Icons.timer_rounded,
        "title": "Solo Focus",
        "subtitle": "25m Sprint Timer",
        "onTap": () => widget.onNavigate?.call(2), // Focus is index 2
        "color": const Color(0xff6366f1),
      },
      {
        "icon": Icons.groups_rounded,
        "title": "Co-Study",
        "subtitle": "Join Live Lobby",
        "onTap": () => widget.onNavigate?.call(1), // Co-Study is index 1
        "color": const Color(0xff10b981),
      },
      {
        "icon": Icons.psychology_rounded,
        "title": "AI Mentor",
        "subtitle": "Companion Coaching",
        "onTap": () => widget.onNavigate?.call(4), // Coach is index 4
        "color": Colors.pinkAccent,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Featured Study Hub",
          style: TextStyle(
            color: ThemeManager.textColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 115,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: featured.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = featured[index];
              final Color col = item["color"] as Color;
              return SizedBox(
                width: 160,
                child: DashboardCard(
                  onTap: item["onTap"],
                  isGlass: true,
                  bgOpacity: 0.015,
                  gradientBorder: [col.withOpacity(0.35), col.withOpacity(0.08)],
                  glowColor: col,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: col.withOpacity(0.12),
                            border: Border.all(
                              color: col.withOpacity(0.25),
                              width: 1.0,
                            ),
                          ),
                          child: Icon(item["icon"], color: col, size: 20),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item["title"],
                          style: TextStyle(
                            color: ThemeManager.textColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (item["title"] == "Co-Study") ...[
                          Row(
                            children: [
                              Text(
                                "3 studying",
                                style: TextStyle(
                                  color: const Color(0xff10b981).withOpacity(0.9),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9.5,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const _LiveCounterPulseDot(),
                            ],
                          ),
                        ] else ...[
                          Text(
                            item["subtitle"],
                            style: TextStyle(
                              color: ThemeManager.textDim,
                              fontSize: 9.5,
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
    final double progressPct = goalMinutes > 0 ? (minutesToday / goalMinutes).clamp(0.0, 1.0) : 0.0;

    // Confetti Auto-Trigger on Goal Completion
    if (progressPct >= 1.0 && !_celebratedToday) {
      _celebratedToday = true;
      _confettiController.play();
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.click);
      Future.delayed(const Duration(milliseconds: 500), () {
        TTSService().toggleSpeak("Congratulations! You've achieved your daily study goal! You are a true Study Monk! 🏆");
      });
    } else if (progressPct < 1.0 && _celebratedToday) {
      _celebratedToday = false;
    }

    return Scaffold(
      backgroundColor: ThemeManager.bgColor,
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
                  _buildAchievementsSection(),
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
        // Hamburger Menu Icon
        GestureDetector(
          onTap: () => Scaffold.of(context).openDrawer(),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ThemeManager.isLight 
                  ? Colors.black.withOpacity(0.04) 
                  : Colors.white.withOpacity(0.02),
              border: Border.all(
                color: ThemeManager.isLight 
                    ? Colors.black.withOpacity(0.08) 
                    : Colors.white.withOpacity(0.06),
                width: 1.0,
              ),
            ),
            child: Icon(
              Icons.menu_rounded,
              color: ThemeManager.isLight ? Colors.black87 : Colors.white.withOpacity(0.85),
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _getGreeting(),
                    style: TextStyle(
                      color: ThemeManager.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const _LiveCounterPulseDot(),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                _studentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ThemeManager.textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Action Buttons Row
        Row(
          children: [
            _PremiumIconButton(
              icon: Icons.bar_chart_rounded,
              color: const Color(0xff6366f1),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
            ),
            const SizedBox(width: 8),
            _PremiumIconButton(
              icon: Icons.settings_rounded,
              color: const Color(0xffec4899),
              onTap: () => _showSettingsBottomSheet(context),
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
        bgOpacity: 0.04,
        gradientBorder: const [Color(0xff818cf8), Color(0xfff43f5e)],
        glowColor: const Color(0xff818cf8).withOpacity(0.35),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xffa5b4fc),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xffa5b4fc),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "TODAY'S STUDY GOAL",
                          style: TextStyle(
                            color: Color(0xffa5b4fc),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      h > 0 ? "${h}h ${m}m" : "${m}m",
                      style: TextStyle(
                        fontSize: 36,
                        color: ThemeManager.textColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        shadows: [
                          Shadow(
                            color: const Color(0xff6366f1).withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xff6366f1).withOpacity(0.18),
                                const Color(0xffec4899).withOpacity(0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xff818cf8).withOpacity(0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xff10b981),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xff10b981),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Goal: $goalText",
                                style: const TextStyle(
                                  color: Color(0xffe0e7ff),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.edit_rounded,
                          color: const Color(0xff818cf8),
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              CircularPercentIndicator(
                radius: 48.0,
                lineWidth: 10.0,
                percent: progressPct,
                center: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.03),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedAvatar,
                        style: const TextStyle(
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        "${(progressPct * 100).toInt()}%",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                linearGradient: const LinearGradient(
                  colors: [Color(0xff818cf8), Color(0xfff43f5e)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                backgroundColor: ThemeManager.isLight 
                    ? Colors.black.withOpacity(0.04) 
                    : Colors.white.withOpacity(0.04),
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
        Text(
          "Today's Quests",
          style: TextStyle(
            color: ThemeManager.textColor,
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
      stream: FirebaseFirestore.instance
          .collection("tasks")
          .where("userId", isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? "")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return DashboardCard(
            isGlass: true,
            bgOpacity: 0.02,
            gradientBorder: const [Colors.white10, Colors.white10],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Text(
                  "Unable to load quests ⚠️",
                  style: TextStyle(color: ThemeManager.textMuted, fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          );
        }

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
                  style: TextStyle(color: ThemeManager.textMuted, fontSize: 13, fontStyle: FontStyle.italic),
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
                                style: TextStyle(color: ThemeManager.textColor, fontWeight: FontWeight.bold, fontSize: 14),
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
                                      task.recommendedBy.isNotEmpty ? task.recommendedBy : "Student Notice",
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
                          style: TextStyle(color: ThemeManager.textDim, fontSize: 11),
                        ),
                        trailing: Checkbox(
                          value: task.isDone,
                          activeColor: const Color(0xff6366f1),
                          side: BorderSide(color: ThemeManager.textDim, width: 2),
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
    return Text(
      "Quick Strategy Actions",
      style: TextStyle(
        color: ThemeManager.textColor,
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
        "icon": Icons.record_voice_over_outlined,
        "title": "Feynman Trainer",
        "subtitle": "Oral Active Recall",
        "onTap": () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeynmanTrainerScreen())),
        "color": const Color(0xff10b981),
      },
      {
        "icon": Icons.leaderboard_outlined,
        "title": "Leaderboard",
        "subtitle": "Global Rank Board",
        "onTap": () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
        "color": Colors.amberAccent,
      },
      {
        "icon": Icons.chat_bubble_outline_rounded,
        "title": "Chat with Sync",
        "subtitle": "AI Study Companion",
        "onTap": () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatbotScreen())),
        "color": const Color(0xffa855f7),
      },
      {
        "icon": Icons.amp_stories_outlined,
        "title": "Smart Flashcards",
        "subtitle": "Spaced Revision",
        "onTap": () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeckListScreen())),
        "color": const Color(0xffec4899),
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
          childAspectRatio: 1.4,
        ),
        itemCount: actions.length,
        itemBuilder: (context, idx) {
          final act = actions[idx];
          final Color col = act["color"] as Color;
          return AnimationConfiguration.staggeredGrid(
            position: idx,
            duration: const Duration(milliseconds: 375),
            columnCount: 2,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: DashboardCard(
                  onTap: act["onTap"],
                  isGlass: true,
                  bgOpacity: 0.015,
                  gradientBorder: [
                    col.withOpacity(0.35),
                    col.withOpacity(0.08),
                  ],
                  glowColor: col,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: col.withOpacity(0.1),
                            border: Border.all(
                              color: col.withOpacity(0.2),
                              width: 0.8,
                            ),
                          ),
                          child: Icon(act["icon"], color: col, size: 18),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          act["title"],
                          style: TextStyle(
                            color: ThemeManager.textColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          act["subtitle"],
                          style: TextStyle(
                            color: ThemeManager.textDim,
                            fontSize: 9.5,
                          ),
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
                color: Color(0xff0d0e15),
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // Avatar Initial Preview
                    Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xff6366f1), Color(0xffec4899)],
                          ),
                          border: Border.all(color: Colors.white24, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xff6366f1).withOpacity(0.2),
                              blurRadius: 15,
                              spreadRadius: 1,
                            )
                          ]
                        ),
                        child: Center(
                          child: Text(
                            _studentName.trim().isNotEmpty ? _studentName.trim()[0].toUpperCase() : "S",
                            style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Student Info Section
                    const Text(
                      "STUDENT PROFILE",
                      style: TextStyle(
                        color: Color(0xff6366f1),
                        fontSize: 10,
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
                              _focusController.notifyListeners();
                            }
                          },
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xff6366f1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Verified Email Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.015),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined, color: Colors.white54, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Email Address",
                                  style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  FirebaseAuth.instance.currentUser?.email ?? "Not logged in",
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xff10b981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.verified_user_rounded, color: Color(0xff10b981), size: 10),
                                SizedBox(width: 2),
                                Text(
                                  "VERIFIED",
                                  style: TextStyle(color: Color(0xff10b981), fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Preferences
                    const Text(
                      "PREFERENCES & GOALS",
                      style: TextStyle(
                        color: Color(0xff6366f1),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Goal Box Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.015),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, color: Color(0xff6366f1), size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Daily Study Goal",
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Adjust target minutes anytime",
                                  style: TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _showEditGoalDialog();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xff6366f1).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    "${_focusController.dailyStudyGoal} mins",
                                    style: const TextStyle(color: Color(0xffa5b4fc), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right_rounded, color: Color(0xffa5b4fc), size: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Logout button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffef4444).withOpacity(0.08),
                        foregroundColor: const Color(0xffef4444),
                        side: BorderSide(color: const Color(0xffef4444).withOpacity(0.35), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        _confirmLogout(context);
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: Color(0xffef4444), size: 18),
                          SizedBox(width: 10),
                          Text(
                            "Log Out Session",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
                await FocusController().clearAndReload();
                await SubscriptionService().init();
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xff10b981).withOpacity(0.08),
            const Color(0xff059669).withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xff34d399).withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff10b981).withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LiveCounterPulseDot(),
          SizedBox(width: 6),
          Text(
            "3 active",
            style: TextStyle(
              color: Color(0xff34d399),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherBulletin() {
    final fallbackNotices = [
      {
        "title": "Group Study for Physics Prep",
        "content": "Hey everyone, let's join Lobby Room 3 at 6 PM to review electrostatics notes together!",
        "teacher": "Avnish",
        "tag": "Study Group",
        "color": Colors.orangeAccent,
      },
      {
        "title": "Feynman Summaries Uploaded",
        "content": "I shared active recall voice notes for Chemistry chapter 2 in the co-study lobby chat.",
        "teacher": "Rahul",
        "tag": "Study Share",
        "color": Colors.greenAccent,
      },
      {
        "title": "Study Tip: Focus Mix",
        "content": "Listening to Lofi loops at 40% volume and Rain crackles at 20% blocks hostel noise perfectly!",
        "teacher": "AI Coach",
        "tag": "Study Tip",
        "color": Colors.cyanAccent,
      },
    ];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("bulletins")
          .where("userId", isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? "")
          .snapshots(),
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
            final tag = data["tag"] ?? "Notice";
            Color tagColor;
            switch (tag.toString().toLowerCase()) {
              case 'homework':
              case 'study group':
                tagColor = Colors.orangeAccent;
                break;
              case 'event':
              case 'study share':
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
              "teacher": data["teacher"] ?? "Student",
              "tag": tag,
              "color": tagColor,
            };
          }).toList();
        } else {
          notices = fallbackNotices;
        }

        return _BulletinCarousel(notices: notices, studentName: _studentName);
      },
    );
  }
}

class _BulletinCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> notices;
  final String studentName;
  const _BulletinCarousel({required this.notices, required this.studentName});

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
    final teacherController = TextEditingController(text: widget.studentName);
    String selectedTag = "Notice";
    final tags = ["Notice", "Study Group", "Study Share", "Study Tip", "Exam Alert"];
    
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
                      "Post Student Notice",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Publish a notice, study tip, or updates directly to the student notice board.",
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
                      "Student Name / Author",
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
                          showDialog(
                            context: stateContext,
                            builder: (dialogContext) {
                              return AlertDialog(
                                backgroundColor: const Color(0xff0d0e15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                ),
                                title: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                                    SizedBox(width: 10),
                                    Text(
                                      "Arey Yaar!",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                content: const Text(
                                  "Please fill in all fields before publishing the notice.",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext),
                                    child: const Text(
                                      "OK",
                                      style: TextStyle(
                                        color: Color(0xffec4899),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                          return;
                        }

                        await FirebaseFirestore.instance.collection("bulletins").add({
                          "userId": FirebaseAuth.instance.currentUser?.uid ?? "",
                          "title": titleController.text.trim(),
                          "content": contentController.text.trim(),
                          "teacher": teacherController.text.trim(),
                          "tag": selectedTag,
                          "createdAt": FieldValue.serverTimestamp(),
                        });

                        if (stateContext.mounted) {
                          Navigator.pop(stateContext);
                          showDialog(
                            context: parentContext,
                            builder: (dialogContext) {
                              return AlertDialog(
                                backgroundColor: const Color(0xff0d0e15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                ),
                                title: const Row(
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent),
                                    SizedBox(width: 10),
                                    Text(
                                      "Notice Published",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                content: const Text(
                                  "Notice published successfully! ★",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext),
                                    child: const Text(
                                      "OK",
                                      style: TextStyle(
                                        color: Color(0xffec4899),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
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
            Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Color(0xffec4899), size: 22),
                const SizedBox(width: 8),
                Text(
                  "Student Notice Board",
                  style: TextStyle(
                    color: ThemeManager.textColor,
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
                                      style: TextStyle(
                                        color: ThemeManager.textColor,
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
                                  color: ThemeManager.textMuted,
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
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: ThemeManager.isLight ? Colors.black.withOpacity(0.06) : Colors.white10,
                              child: Icon(Icons.person_rounded, size: 16, color: ThemeManager.textMuted),
                            ),
                            const SizedBox(height: 6),
                             Text(
                              (item["teacher"] ?? "Student").toString().split(" ").last,
                              maxLines: 1,
                              style: TextStyle(color: ThemeManager.textDim, fontSize: 9, fontWeight: FontWeight.bold),
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

class SonarPulseAvatar extends StatelessWidget {
  final String avatar;
  final VoidCallback onTap;

  const SonarPulseAvatar({
    super.key,
    required this.avatar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              color: const Color(0xffec4899).withOpacity(0.35),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
        ),
        child: Center(
          child: Text(
            avatar,
            style: const TextStyle(
              fontSize: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PremiumIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ThemeManager.isLight 
              ? Colors.black.withOpacity(0.04) 
              : Colors.white.withOpacity(0.02),
          border: Border.all(
            color: ThemeManager.isLight 
                ? Colors.black.withOpacity(0.08) 
                : Colors.white.withOpacity(0.06),
            width: 1.0,
          ),
        ),
        child: Icon(
          icon,
          color: ThemeManager.isLight ? Colors.black87 : Colors.white.withOpacity(0.85),
          size: 19,
        ),
      ),
    );
  }
}