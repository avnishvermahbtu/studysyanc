import 'package:flutter/material.dart';

import '../ai coach/ai_coach_screen.dart';
import '../dasboard/screens/dashboard_screen.dart';
import '../tasks/screens/task_screen.dart';
import '../routine/screens/routine_screen.dart';
import '../focus/screens/focus_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}
class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;
  final screens = [
    DashboardScreen(),
    TaskScreen(),
    RoutineScreen(),
   FocusScreen(),
    AICoachScreen()

  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[currentIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 15,
              spreadRadius: 2,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.black,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
            onTap: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: "Home",
              ),

              BottomNavigationBarItem(
                icon: Icon(Icons.task_outlined),
                activeIcon: Icon(Icons.task),
                label: "Tasks",
              ),

              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_outlined),
                activeIcon: Icon(Icons.calendar_today),
                label: "Routine",
              ),

              BottomNavigationBarItem(
                icon: Icon(Icons.timer_outlined),
                activeIcon: Icon(Icons.timer),
                label: "Focus",
              ),

              BottomNavigationBarItem(
                icon: Icon(Icons.forum_outlined),
                activeIcon: Icon(Icons.forum),
                label: "Skill Swap",
              ),
            ],
          ),
        ),
      ),
    );
  }
}