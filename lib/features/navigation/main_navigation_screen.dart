import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ai_coach/ai_coach_screen.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../tasks/screens/task_screen.dart';
import '../routine/screens/routine_screen.dart';
import '../focus/screens/focus_screen.dart';
import '../group_study/screens/group_study_lobby_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}
class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;
  late final List<Widget> screens;

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
    ];
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
    ];

    return Scaffold(
      backgroundColor: const Color(0xff020617),
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
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
                padding: EdgeInsets.symmetric(horizontal: isSelected ? 10 : 8, vertical: 8),
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
                      size: 22,
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Row(
                        children: [
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Text(
                              item["label"],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
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
    );
  }
}