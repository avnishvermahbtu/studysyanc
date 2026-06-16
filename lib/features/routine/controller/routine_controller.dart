import 'package:flutter/material.dart';
import '../../focus/controller/focus_controller.dart';
import '../screens/routine_model.dart';

class RoutineController extends ChangeNotifier {
  // Singleton implementation
  static final RoutineController _instance = RoutineController._internal();
  factory RoutineController() => _instance;

  RoutineController._internal();

  DateTime _selectedDate = DateTime.now();
  DateTime _currentWeek = DateTime.now();

  // Getters
  DateTime get selectedDate => _selectedDate;
  DateTime get currentWeek => _currentWeek;

  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void setWeek(DateTime week) {
    _currentWeek = week;
    notifyListeners();
  }

  void nextWeek() {
    _currentWeek = _currentWeek.add(const Duration(days: 7));
    notifyListeners();
  }

  void previousWeek() {
    _currentWeek = _currentWeek.subtract(const Duration(days: 7));
    notifyListeners();
  }

  // Formatting greeting based on hour
  String getGreeting() {
    int hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  // Dynamically compiles a student-friendly briefing
  String compileDailyBrief(List<Routine> routines) {
    if (routines.isEmpty) {
      return "Enjoy your day! No classes scheduled. Perfect time to focus or rest! 🧘";
    }

    int lectures = routines.where((r) => r.type == 'Lecture').length;
    int labs = routines.where((r) => r.type == 'Lab').length;
    int exams = routines.where((r) => r.type == 'Exam' || r.type.toUpperCase() == 'EXAM').length;
    int studies = routines.where((r) => r.type == 'Study').length;

    List<String> loadList = [];
    if (lectures > 0) loadList.add("$lectures Lecture${lectures > 1 ? 's' : ''}");
    if (labs > 0) loadList.add("$labs Lab${labs > 1 ? 's' : ''}");
    if (exams > 0) loadList.add("$exams Exam${exams > 1 ? 's' : ''}");
    if (studies > 0) loadList.add("$studies Study Block${studies > 1 ? 's' : ''}");

    String loadedText = loadList.join(", ");
    return "Today: $loadedText. Complete attendance to gain study XP! ⚡";
  }

  // Parse string like "09:30 AM" or "14:15" to DateTime on selected day
  DateTime? parseTimeString(String timeStr, DateTime baseDate) {
    try {
      final clean = timeStr.trim().toUpperCase();
      int hour = 0;
      int minute = 0;

      if (clean.contains("AM") || clean.contains("PM")) {
        // 12-hour format e.g., "09:30 AM"
        final parts = clean.split(RegExp(r'\s+'));
        final hm = parts[0].split(":");
        hour = int.parse(hm[0]);
        minute = int.parse(hm[1]);
        final isPm = parts.length > 1 && parts[1] == "PM";
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
      } else {
        // 24-hour format e.g., "14:30"
        final hm = clean.split(":");
        hour = int.parse(hm[0]);
        minute = int.parse(hm[1]);
      }
      return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  // Check if class is active or up next
  // Returns: Map with activeRoutine, nextRoutine, countdownMinutes
  Map<String, dynamic> getLiveScheduleStates(List<Routine> routines) {
    final now = DateTime.now();
    Routine? activeRoutine;
    Routine? nextRoutine;
    int nextCountdown = 9999;

    for (final r in routines) {
      final start = parseTimeString(r.startTime, r.date);
      final end = parseTimeString(r.endTime, r.date);

      if (start == null || end == null) continue;

      // Check if active
      if (now.isAfter(start) && now.isBefore(end)) {
        activeRoutine = r;
        break; // Active takes precedence
      }

      // Check if upcoming
      if (start.isAfter(now)) {
        final diffMin = start.difference(now).inMinutes;
        if (diffMin < nextCountdown) {
          nextCountdown = diffMin;
          nextRoutine = r;
        }
      }
    }

    return {
      "active": activeRoutine,
      "next": nextRoutine,
      "countdown": nextCountdown,
    };
  }

  // Attendance check-in with Focus XP reward
  Future<void> checkIn(Routine routine, Function(Routine) onUpdated) async {
    if (routine.isCheckedIn) return;
    
    routine.isCheckedIn = true;
    onUpdated(routine);

    // Call FocusController singleton to award +35 XP!
    FocusController().addXp(35);
  }
}
