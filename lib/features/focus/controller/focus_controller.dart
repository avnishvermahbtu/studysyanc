import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studysync/core/services/widget_service.dart';
import 'package:studysync/core/services/notification_service.dart';

enum FocusTheme { forest, cosmic, cyberpunk, zen }
enum FocusCategory { study, coding, writing, science, meditation }

class FocusController extends ChangeNotifier {
  // Singleton implementation
  static final FocusController _instance = FocusController._internal();
  factory FocusController() => _instance;

  FocusController._internal() {
    loadData();
  }

  // Timer State
  int _totalSeconds = 1500;
  int _maxSeconds = 1500;
  int _configuredFocusSeconds = 1500;
  int _lastCompletedFocusMinutes = 25;
  bool _isRunning = false;
  bool _isBreak = false;
  Timer? _timer;

  // Selected config
  FocusTheme _currentTheme = FocusTheme.forest;
  FocusCategory _currentCategory = FocusCategory.study;

  // Gamification & Streak State
  int _streak = 0;
  String _lastDate = "";
  int _xp = 0;
  int _level = 1;
  int _dailyStudyGoal = 240; // Default daily goal in minutes (4 hours)
  int _lastDecayPenalty = 0;

  // Weekly study sessions counter
  Map<String, int> _weeklyData = {
    "Mon": 0,
    "Tue": 0,
    "Wed": 0,
    "Thu": 0,
    "Fri": 0,
    "Sat": 0,
    "Sun": 0,
  };

  // Weekly study minutes counter
  Map<String, int> _weeklyMinutes = {
    "Mon": 0,
    "Tue": 0,
    "Wed": 0,
    "Thu": 0,
    "Fri": 0,
    "Sat": 0,
    "Sun": 0,
  };

  // Focus Category minutes counter
  Map<String, int> _categoryMinutes = {
    "study": 0,
    "coding": 0,
    "writing": 0,
    "science": 0,
    "meditation": 0,
  };

  // Focus History daily map
  Map<String, int> _historyMap = {};

  // Soundscape (ambient)
  bool _isSoundscapeActive = false;
  String _activeSoundscape = "Lofi Beats"; // "Lofi Beats", "Rain & Storm", "Campfire"

  // Level Up event callback
  VoidCallback? onLevelUp;
  VoidCallback? onSessionCompleted;

  // Getters
  int get totalSeconds => _totalSeconds;
  int get maxSeconds => _maxSeconds;
  bool get isRunning => _isRunning;
  bool get isBreak => _isBreak;
  FocusTheme get currentTheme => _currentTheme;
  FocusCategory get currentCategory => _currentCategory;
  int get streak => _streak;
  String get lastDate => _lastDate;
  int get xp => _xp;
  int get level => _level;
  int get dailyStudyGoal => _dailyStudyGoal;
  Map<String, int> get weeklyData => _weeklyData;
  Map<String, int> get weeklyMinutes => _weeklyMinutes;
  Map<String, int> get categoryMinutes => _categoryMinutes;
  bool get isSoundscapeActive => _isSoundscapeActive;
  String get activeSoundscape => _activeSoundscape;
  int get lastDecayPenalty => _lastDecayPenalty;
  Map<String, int> get historyMap => _historyMap;
  int get lastCompletedFocusMinutes => _lastCompletedFocusMinutes;

  void clearDecayPenalty() {
    _lastDecayPenalty = 0;
    notifyListeners();
  }


  // Load state from SharedPreferences
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    _streak = prefs.getInt("streak") ?? 0;
    _lastDate = prefs.getString("lastDate") ?? "";
    _xp = prefs.getInt("focus_xp") ?? 0;
    _level = prefs.getInt("focus_level") ?? 1;
    _dailyStudyGoal = prefs.getInt("daily_study_goal") ?? 240;
    _configuredFocusSeconds = 1500;
    _maxSeconds = 1500;
    _totalSeconds = 1500;

    // Load Theme
    final themeStr = prefs.getString("focus_theme") ?? "forest";
    _currentTheme = FocusTheme.values.firstWhere(
      (e) => e.toString().split('.').last == themeStr,
      orElse: () => FocusTheme.forest,
    );

    // Load Category
    final catStr = prefs.getString("focus_category") ?? "study";
    _currentCategory = FocusCategory.values.firstWhere(
      (e) => e.toString().split('.').last == catStr,
      orElse: () => FocusCategory.study,
    );

    // Load weekly session stats
    _weeklyData = {
      "Mon": prefs.getInt("Mon") ?? 0,
      "Tue": prefs.getInt("Tue") ?? 0,
      "Wed": prefs.getInt("Wed") ?? 0,
      "Thu": prefs.getInt("Thu") ?? 0,
      "Fri": prefs.getInt("Fri") ?? 0,
      "Sat": prefs.getInt("Sat") ?? 0,
      "Sun": prefs.getInt("Sun") ?? 0,
    };

    // Load weekly session minutes
    _weeklyMinutes = {
      "Mon": prefs.getInt("Mon_minutes") ?? ((prefs.getInt("Mon") ?? 0) * 25),
      "Tue": prefs.getInt("Tue_minutes") ?? ((prefs.getInt("Tue") ?? 0) * 25),
      "Wed": prefs.getInt("Wed_minutes") ?? ((prefs.getInt("Wed") ?? 0) * 25),
      "Thu": prefs.getInt("Thu_minutes") ?? ((prefs.getInt("Thu") ?? 0) * 25),
      "Fri": prefs.getInt("Fri_minutes") ?? ((prefs.getInt("Fri") ?? 0) * 25),
      "Sat": prefs.getInt("Sat_minutes") ?? ((prefs.getInt("Sat") ?? 0) * 25),
      "Sun": prefs.getInt("Sun_minutes") ?? ((prefs.getInt("Sun") ?? 0) * 25),
    };

    // Load category study minutes
    _categoryMinutes = {
      "study": prefs.getInt("cat_study") ?? 0,
      "coding": prefs.getInt("cat_coding") ?? 0,
      "writing": prefs.getInt("cat_writing") ?? 0,
      "science": prefs.getInt("cat_science") ?? 0,
      "meditation": prefs.getInt("cat_meditation") ?? 0,
    };

    // Load Focus History Map for Heatmap
    final historyJson = prefs.getString("focus_history_map") ?? "";
    if (historyJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(historyJson) as Map<String, dynamic>;
        _historyMap = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (e) {
        _historyMap = {};
      }
    }

    if (_historyMap.isEmpty) {
      // Pre-populate with beautiful mock data for testing/demo
      final random = Random();
      final now = DateTime.now();
      for (int i = 0; i < 150; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        // 45% chance of study sessions on any day, with 1 to 4 sessions
        if (random.nextDouble() < 0.45) {
          _historyMap[dateStr] = random.nextInt(4) + 1; // 1 to 4 sessions
        }
      }
      // Save it
      await prefs.setString("focus_history_map", jsonEncode(_historyMap));
    }

    await checkInactivityDecay();

    notifyListeners();
  }

  // Set selected Theme
  Future<void> setTheme(FocusTheme theme) async {
    _currentTheme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("focus_theme", theme.toString().split('.').last);
  }

  // Set selected Category
  Future<void> setCategory(FocusCategory category) async {
    _currentCategory = category;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("focus_category", category.toString().split('.').last);
  }

  // Set Daily Study Goal in minutes
  Future<void> setDailyStudyGoal(int minutes) async {
    _dailyStudyGoal = minutes;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("daily_study_goal", minutes);
  }

  // Toggle ambient soundscapes
  void toggleSoundscape(bool active, {String? soundType}) {
    _isSoundscapeActive = active;
    if (soundType != null) {
      _activeSoundscape = soundType;
    }
    notifyListeners();
  }

  // Set Timer values
  Future<void> setTimerDuration(int minutes, int seconds) async {
    if (_isRunning) return;
    _maxSeconds = (minutes * 60) + seconds;
    _totalSeconds = _maxSeconds;
    _configuredFocusSeconds = _maxSeconds;
    _isBreak = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("configured_focus_seconds", _configuredFocusSeconds);
  }

  // Start timer ticking
  void startTimer() {
    if (_isRunning) return;

    _isRunning = true;
    notifyListeners();
    WidgetService.updateWidgetData();
    NotificationService().scheduleFocusCompletionNotification(_totalSeconds, _isBreak);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_totalSeconds <= 0) {
        timer.cancel();
        _isRunning = false;
        HapticFeedback.vibrate();
        
        // Award XP and complete session
        completeSession();
      } else {
        _totalSeconds--;
        
        // Award 1 XP for focus every 60 seconds (1 minute) of active work
        final elapsedSeconds = _maxSeconds - _totalSeconds;
        if (!_isBreak && elapsedSeconds > 0 && elapsedSeconds % 60 == 0) {
          addXp(1);
        }
        notifyListeners();
      }
    });
  }

  // Pause Timer
  void pauseTimer() {
    _timer?.cancel();
    _isRunning = false;
    notifyListeners();
    WidgetService.updateWidgetData();
    NotificationService().cancelFocusCompletionNotification();
  }

  void toggleTimerState() {
    if (_isRunning) {
      pauseTimer();
    } else {
      startTimer();
    }
    WidgetService.updateWidgetData();
  }

  // Reset Timer
  void resetTimer() {
    _timer?.cancel();
    _isRunning = false;
    if (_isBreak) {
      _isBreak = false;
    }
    _totalSeconds = _configuredFocusSeconds;
    _maxSeconds = _configuredFocusSeconds;
    notifyListeners();
    WidgetService.updateWidgetData();
    NotificationService().cancelFocusCompletionNotification();
  }

  Future<void> completeSession() async {
    NotificationService().cancelFocusCompletionNotification();
    if (_isBreak) {
      // Break is complete. Switch back to focus state
      _isBreak = false;
      _totalSeconds = _configuredFocusSeconds;
      _maxSeconds = _configuredFocusSeconds;
      notifyListeners();
      WidgetService.updateWidgetData();
      return;
    }

    final focusMinutes = _maxSeconds ~/ 60;
    _lastCompletedFocusMinutes = focusMinutes;

    // 1. Instantly trigger UI transition to break mode (5 minutes)
    _isBreak = true;
    _totalSeconds = 300; // 5 min break
    _maxSeconds = 300;
    notifyListeners();

    // 2. Instantly call completion celebration callback (Confetti & dynamic SnackBar)
    onSessionCompleted?.call();

    // 3. Perform background gamification XP addition and async DB saves
    final catKey = _currentCategory.toString().split('.').last;
    _categoryMinutes[catKey] = (_categoryMinutes[catKey] ?? 0) + focusMinutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("cat_$catKey", _categoryMinutes[catKey]!);

    final completionBonus = max(1, focusMinutes);
    await addXp(completionBonus);
    await updateWeekly(focusMinutes);

    final now = DateTime.now();
    final days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    final dayKey = days[now.weekday % 7];
    final minutesToday = _weeklyMinutes[dayKey] ?? 0;
    if (minutesToday >= 15) {
      await updateStreak();
    }

    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _historyMap[todayStr] = (_historyMap[todayStr] ?? 0) + 1;
    await prefs.setString("focus_history_map", jsonEncode(_historyMap));
  }

  // Start short break or focus break manually
  void setBreak(int minutes) {
    _timer?.cancel();
    _isRunning = false;
    _isBreak = true;
    _maxSeconds = minutes * 60;
    _totalSeconds = _maxSeconds;
    notifyListeners();
  }

  // Calculate required XP for a given level
  // Level 1: 0 XP
  // Level 2: 100 XP
  // Level 3: 300 XP
  // Level 4: 600 XP ... and so on (Formula: level * 200)
  int xpNeededForNextLevel() {
    return _level * 250;
  }

  // XP addition and level-up/down wraps
  Future<void> addXp(int amount) async {
    _xp += amount;
    
    bool levelChanged = false;

    // Check level-up
    int needed = xpNeededForNextLevel();
    while (_xp >= needed) {
      _xp -= needed;
      _level++;
      needed = xpNeededForNextLevel();
      levelChanged = true;
    }

    // Check level-down
    while (_xp < 0 && _level > 1) {
      _level--;
      int prevNeeded = xpNeededForNextLevel();
      _xp += prevNeeded;
      levelChanged = true;
    }

    if (_xp < 0 && _level == 1) {
      _xp = 0;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("focus_xp", _xp);
    await prefs.setInt("focus_level", _level);

    if (levelChanged && amount > 0) {
      onLevelUp?.call();
    }
    notifyListeners();
    await syncToFirestore();
  }

  // Update Streak counts
  Future<void> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = "${now.year}-${now.month}-${now.day}";

    if (_lastDate.isEmpty) {
      _streak = 1;
    } else {
      try {
        final last = DateTime.parse(_lastDate);
        final diff = now.difference(last).inDays;

        if (diff == 1) {
          _streak++;
        } else if (diff > 1) {
          _streak = 1;
        }
      } catch (e) {
        _streak = 1;
      }
    }

    _lastDate = today;

    await prefs.setInt("streak", _streak);
    await prefs.setString("lastDate", _lastDate);
    notifyListeners();
    await syncToFirestore();
  }

  // Sync user metrics dynamically to global leaderboard collection
  Future<void> syncToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final name = user.displayName ?? "Student";
        final email = user.email ?? "";
        final cumulativeXp = ((_level - 1) * _level ~/ 2) * 250 + _xp;
        
        // Sum total focus minutes from all categories
        final totalMinutes = _categoryMinutes.values.fold(0, (sum, val) => sum + val);

        await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
          "uid": user.uid,
          "name": name,
          "email": email,
          "xp": _xp,
          "level": _level,
          "streak": _streak,
          "cumulativeXp": cumulativeXp,
          "totalFocusMinutes": totalMinutes,
          "lastUpdated": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // safe fallback
    }
  }

  // Update Weekly Completion stats
  Future<void> updateWeekly(int completedMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    final days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    final day = days[DateTime.now().weekday % 7];

    _weeklyData[day] = (_weeklyData[day] ?? 0) + 1;
    await prefs.setInt(day, _weeklyData[day]!);

    _weeklyMinutes[day] = (_weeklyMinutes[day] ?? 0) + completedMinutes;
    await prefs.setInt("${day}_minutes", _weeklyMinutes[day]!);

    notifyListeners();
  }

  // Formatted countdown time string MM:SS
  String formatTime() {
    int m = _totalSeconds ~/ 60;
    int s = _totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // Format category to readable string
  String getCategoryName(FocusCategory cat) {
    switch (cat) {
      case FocusCategory.study:
        return "Study";
      case FocusCategory.coding:
        return "Coding";
      case FocusCategory.writing:
        return "Writing";
      case FocusCategory.science:
        return "Science";
      case FocusCategory.meditation:
        return "Zen Mode";
    }
  }

  // Get current rank name based on level
  String getRankName() {
    if (_level >= 25) return "👑 Supreme Sage";
    if (_level >= 15) return "🥋 Focus Grandmaster";
    if (_level >= 8) return "🔥 Deep Work Ninja";
    if (_level >= 4) return "💪 Concentration Mage";
    return "🌱 Novice Sprout";
  }

  // Check daily inactivity decay and apply penalties
  Future<void> checkInactivityDecay() async {
    if (_lastDate.isEmpty) return;

    try {
      final last = DateTime.parse(_lastDate);
      final now = DateTime.now();
      
      // Compare calendar days ignoring times
      final lastDay = DateTime(last.year, last.month, last.day);
      final today = DateTime(now.year, now.month, now.day);
      final diffDays = today.difference(lastDay).inDays;

      if (diffDays > 1) {
        final missedDays = diffDays - 1;
        final penalty = 20 * missedDays; // 20 XP decay per missed study day

        _streak = 0;
        _lastDecayPenalty = penalty;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt("streak", _streak);

        await addXp(-penalty);

        // Set lastDate to yesterday to avoid duplicate decay calculations on restarts
        final yesterday = today.subtract(const Duration(days: 1));
        _lastDate = "${yesterday.year}-${yesterday.month}-${yesterday.day}";
        await prefs.setString("lastDate", _lastDate);
      }
    } catch (e) {
      // safe fallback
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
