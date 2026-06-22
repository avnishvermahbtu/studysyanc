import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../ai_coach/ai_coach_screen.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../tasks/screens/task_screen.dart';
import '../routine/screens/routine_screen.dart';
import '../focus/screens/focus_screen.dart';
import '../group_study/screens/group_study_lobby_screen.dart';
import '../ai_coach/leaderboard_screen.dart';
import '../../core/services/widget_service.dart';
import '../focus/controller/focus_controller.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}
class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;
  late final List<Widget> screens;
  StreamSubscription<QuerySnapshot>? _tasksSubscription;

  void navigateToTab(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    screens = [
      DashboardScreen(onNavigate: navigateToTab),
      const GroupStudyLobbyScreen(),
      const FocusScreen(),
      const TaskScreen(),
      const AICoachScreen(),
      const RoutineScreen(),
      const LeaderboardScreen(),
    ];

    // Setup real-time updates for native home screen widget
    FocusController().addListener(_onWidgetUpdate);
    _tasksSubscription = FirebaseFirestore.instance.collection("tasks").snapshots().listen((event) {
      _onWidgetUpdate();
    });
    // Trigger initial widget update
    _onWidgetUpdate();
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

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> navigationItems = [
      {"icon": Icons.home_rounded, "label": "Home"},
      {"icon": Icons.groups_rounded, "label": "Co-Study"},
      {"icon": Icons.timer_rounded, "label": "Focus"},
      {"icon": Icons.emoji_events_rounded, "label": "Quests"},
      {"icon": Icons.forum_rounded, "label": "Coach"},
      {"icon": Icons.calendar_today_rounded, "label": "Schedule"},
      {"icon": Icons.leaderboard_rounded, "label": "Leaderboard"},
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
        backgroundColor: const Color(0xff020617),
        body: IndexedStack(
          index: currentIndex,
          children: screens,
        ),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xff0f172a).withOpacity(0.9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff6366f1).withOpacity(0.12),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navigationItems.length, (index) {
              final isSelected = currentIndex == index;
              final item = navigationItems[index];
    
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    currentIndex = index;
                  });
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
                        color: isSelected ? const Color(0xff6366f1) : Colors.white38,
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
                                style: const TextStyle(
                                  color: Colors.white,
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