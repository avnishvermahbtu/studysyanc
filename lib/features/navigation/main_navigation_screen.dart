import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../ai_coach/ai_coach_screen.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../tasks/screens/task_screen.dart';
import '../routine/screens/routine_screen.dart';
import '../focus/screens/focus_screen.dart';
import '../group_study/screens/group_study_lobby_screen.dart';
import '../ai_coach/leaderboard_screen.dart';
import '../../core/services/widget_service.dart';
import '../focus/controller/focus_controller.dart';
import '../../core/services/subscription_service.dart';
import 'package:studysync/core/theme/theme_manager.dart';
import 'widgets/custom_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}
class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;
  StreamSubscription<QuerySnapshot>? _tasksSubscription;

  void navigateToTab(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _setupDefaultAgoraConfig();
    _setupDailyReminders();

    // Reload FocusController data for the logged-in user
    FocusController().loadData();

    // Reload Subscription and limits data for the logged-in user
    SubscriptionService().init();

    // Setup real-time updates for native home screen widget
    FocusController().addListener(_onWidgetUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tasksSubscription = FirebaseFirestore.instance
          .collection("tasks")
          .where("userId", isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? "")
          .snapshots()
          .listen((event) {
        _onWidgetUpdate();
      });
      // Trigger initial widget update
      _onWidgetUpdate();
    });
  }

  Future<void> _setupDefaultAgoraConfig() async {
    try {
      final db = FirebaseFirestore.instance;
      final docRef = db.collection('settings').doc('agora');
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'appId': 'a854d19b489a425390977bdcf234032d', // Default testing App ID (no token required)
          'token': '',
        });
        debugPrint("Auto-created default settings/agora document in Firestore!");
      }
    } catch (e) {
      debugPrint("Error creating default settings/agora document: $e");
    }
  }

  Future<void> _setupDailyReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('student_name') ?? "Student";
      
      final notificationService = NotificationService();
      await notificationService.scheduleDailyStreakReminder(name);
      await notificationService.scheduleMorningMotivation(name);
    } catch (e) {
      debugPrint("Error setting up daily reminders: $e");
    }
  }

  void _onWidgetUpdate() {
    WidgetService.updateWidgetData();
  }

  @override
  void dispose() {
    FocusController().removeListener(_onWidgetUpdate);
    _tasksSubscription?.cancel();
    super.dispose();
  }

  void _showMoreBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xff0d0e15).withOpacity(0.98),
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
                "More Features",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMoreItem(
                    sheetContext,
                    index: 4,
                    label: "Coach",
                    icon: Icons.forum_rounded,
                    color: const Color(0xff818cf8),
                  ),
                  _buildMoreItem(
                    sheetContext,
                    index: 5,
                    label: "Schedule",
                    icon: Icons.calendar_today_rounded,
                    color: const Color(0xffec4899),
                  ),
                  _buildMoreItem(
                    sheetContext,
                    index: 6,
                    label: "Leaderboard",
                    icon: Icons.leaderboard_rounded,
                    color: const Color(0xfff59e0b),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoreItem(
    BuildContext context, {
    required int index,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isCurrent = currentIndex == index;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        navigateToTab(index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: isCurrent ? color.withOpacity(0.15) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCurrent ? color : Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.15),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: isCurrent ? color : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isCurrent ? Colors.white : Colors.white60,
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> navigationItems = [
      {"icon": Icons.home_rounded, "label": "Home"},
      {"icon": Icons.groups_rounded, "label": "Co-Study"},
      {"icon": Icons.timer_rounded, "label": "Focus"},
      {"icon": Icons.emoji_events_rounded, "label": "Quests"},
      {
        "icon": currentIndex < 4
            ? Icons.grid_view_rounded
            : currentIndex == 4
                ? Icons.forum_rounded
                : currentIndex == 5
                    ? Icons.calendar_today_rounded
                    : Icons.leaderboard_rounded,
        "label": currentIndex < 4
            ? "More"
            : currentIndex == 4
                ? "Coach"
                : currentIndex == 5
                    ? "Schedule"
                    : "Leaderboard",
      },
    ];

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentIndex != 0) {
          setState(() {
            currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        backgroundColor: ThemeManager.bgColor,
        drawer: CustomDrawer(onNavigate: navigateToTab),
        body: IndexedStack(
          index: currentIndex,
          children: [
            DashboardScreen(onNavigate: navigateToTab),
            const GroupStudyLobbyScreen(),
            FocusScreen(isActive: currentIndex == 2),
            const TaskScreen(),
            const AICoachScreen(),
            const RoutineScreen(),
            const LeaderboardScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: ThemeManager.cardBg.withOpacity(0.95),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: ThemeManager.border,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff6366f1).withOpacity(ThemeManager.isLight ? 0.05 : 0.12),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(ThemeManager.isLight ? 0.05 : 0.35),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navigationItems.length, (index) {
              final isSelected = index == 4 ? currentIndex >= 4 : currentIndex == index;
              final item = navigationItems[index];
    
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (index == 4) {
                    _showMoreBottomSheet(context);
                  } else {
                    setState(() {
                      currentIndex = index;
                    });
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(horizontal: isSelected ? 8 : 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xff6366f1).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xff6366f1).withOpacity(0.3)
                          : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       Icon(
                        item["icon"],
                        color: isSelected ? const Color(0xff6366f1) : ThemeManager.textMuted,
                        size: 19,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: Row(
                          children: [
                            if (isSelected) ...[
                              const SizedBox(width: 4),
                              Text(
                                item["label"],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: ThemeManager.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}