import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysync/core/theme/theme_manager.dart';
import 'package:studysync/features/focus/controller/focus_controller.dart';
import 'package:studysync/login_page.dart';

import '../../ai_coach/roadmap_screen.dart';
import '../../ai_coach/backlog_screen.dart';
import '../../ai_coach/notes_to_quiz_screen.dart';
import '../../ai_coach/quiz_revision_screen.dart';
import '../../routine/screens/feynman_trainer_screen.dart';
import '../../ai_coach/leaderboard_screen.dart';

class CustomDrawer extends StatefulWidget {
  final Function(int) onNavigate;

  const CustomDrawer({
    super.key,
    required this.onNavigate,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  late FocusController _focusController;
  String _studentName = "Student";
  String _selectedAvatar = "📚";

  @override
  void initState() {
    super.initState();
    _focusController = FocusController();
    _focusController.addListener(_onFocusUpdate);
    _loadStudentData();
  }

  @override
  void dispose() {
    _focusController.removeListener(_onFocusUpdate);
    super.dispose();
  }

  void _onFocusUpdate() {
    if (mounted) {
      _loadStudentData();
      setState(() {});
    }
  }

  Future<void> _loadStudentData() async {
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
    } catch (e) {
      debugPrint("Error loading student data in drawer: $e");
    }
  }

  void _showEditProfileSheet() {
    final nameEditController = TextEditingController(text: _studentName);
    final avatars = ["📚", "⚡", "⚔️", "🧠", "🧙‍♂️", "👑", "🌟", "🔥", "🌌", "🔮"];
    String tempAvatar = _selectedAvatar;

    showModalBottomSheet(
      context: context,
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
                    const Row(
                      children: [
                        Icon(Icons.edit_note_rounded, color: Color(0xffec4899), size: 28),
                        SizedBox(width: 12),
                        Text(
                          "Edit Profile",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "STUDENT NAME",
                      style: TextStyle(
                        color: Color(0xff818cf8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameEditController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xff6366f1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "CHOOSE AVATAR TITLE",
                      style: TextStyle(
                        color: Color(0xff818cf8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: avatars.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, idx) {
                          final av = avatars[idx];
                          final isSel = tempAvatar == av;
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                tempAvatar = av;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xffec4899).withOpacity(0.12) : Colors.white.withOpacity(0.02),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel ? const Color(0xffec4899) : Colors.white10,
                                  width: isSel ? 1.5 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(av, style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff6366f1),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
                          await prefs.setString('student_avatar', tempAvatar);
                          
                          if (mounted) {
                            setState(() {
                              _studentName = newName;
                              _selectedAvatar = tempAvatar;
                            });
                          }
                          _focusController.notifyListeners();
                        }
                        if (stateContext.mounted) {
                          Navigator.pop(stateContext);
                        }
                      },
                      child: const Text(
                        "Save Profile Changes",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
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

  void _confirmLogOut() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xff0d0e15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white10, width: 1.2),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Text("Log Out?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            "Are you sure you want to log out? Your streak and profile settings are stored in the cloud.",
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: TextStyle(color: ThemeManager.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffef4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await FirebaseAuth.instance.signOut();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('student_name');
                
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

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final accentColor = color ?? ThemeManager.textMuted;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: accentColor, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: ThemeManager.textColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: ThemeManager.textDim, size: 18),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lvl = _focusController.level;
    final xp = _focusController.xp;
    final rank = _focusController.getRankName();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.82,
        backgroundColor: const Color(0xff0d0e15).withOpacity(0.95),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white10, width: 1.0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Profile Avatar
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xff6366f1), Color(0xffec4899)],
                            ),
                            border: Border.all(color: Colors.white24, width: 1.5),
                          ),
                            child: Center(
                            child: Text(
                              _studentName.trim().isNotEmpty
                                  ? _studentName.trim()[0].toUpperCase()
                                  : "S",
                              style: const TextStyle(
                                fontSize: 26,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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
                                "Hi, $_studentName",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: _showEditProfileSheet,
                                child: const Row(
                                  children: [
                                    Text(
                                      "Edit Profile",
                                      style: TextStyle(
                                        color: Color(0xffa5b4fc),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.edit_rounded, color: Color(0xffa5b4fc), size: 12),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Rank & Stats Badges
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xff6366f1).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xff6366f1).withOpacity(0.3), width: 0.8),
                          ),
                          child: Text(
                            "Level $lvl • $rank",
                            style: const TextStyle(
                              color: Color(0xffa5b4fc),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orangeAccent.withOpacity(0.3), width: 0.8),
                          ),
                          child: Text(
                            "$xp XP",
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Menu shortcuts list
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      _buildDrawerItem(
                        icon: Icons.dashboard_rounded,
                        title: "Home Dashboard",
                        color: const Color(0xff6366f1),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onNavigate(0);
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.groups_rounded,
                        title: "Co-Study Lobby",
                        color: const Color(0xff10b981),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onNavigate(1);
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.timer_rounded,
                        title: "Solo Focus Timer",
                        color: Colors.pinkAccent,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onNavigate(2);
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.calendar_today_rounded,
                        title: "Daily Schedule",
                        color: Colors.cyanAccent,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onNavigate(5);
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.leaderboard_rounded,
                        title: "Leaderboard",
                        color: Colors.amberAccent,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onNavigate(6);
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.forum_rounded,
                        title: "AI Coach Companion",
                        color: const Color(0xffa855f7),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onNavigate(4);
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Divider(color: Colors.white10),
                      ),
                      _buildDrawerItem(
                        icon: Icons.quiz_rounded,
                        title: "Quiz Arena",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesToQuizScreen()));
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.record_voice_over_rounded,
                        title: "Feynman Trainer",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const FeynmanTrainerScreen()));
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.menu_book_rounded,
                        title: "Backlog Planner",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const BacklogScreen()));
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.auto_stories_rounded,
                        title: "Quiz Revision Bank",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizRevisionScreen()));
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Log Out & info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white10, width: 1.0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _confirmLogOut,
                    ),
                    const SizedBox(height: 14),
                    const Center(
                      child: Text(
                        "StudySync v1.0.0",
                        style: TextStyle(color: Colors.white30, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Center(
                      child: Text(
                        "Made with ❤️ for Students",
                        style: TextStyle(color: Colors.white30, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
