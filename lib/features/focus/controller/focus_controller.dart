import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Map<String, int> get weeklyData => _weeklyData;
  bool get isSoundscapeActive => _isSoundscapeActive;
  String get activeSoundscape => _activeSoundscape;


  // Load state from SharedPreferences
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    _streak = prefs.getInt("streak") ?? 0;
    _lastDate = prefs.getString("lastDate") ?? "";
    _xp = prefs.getInt("focus_xp") ?? 0;
    _level = prefs.getInt("focus_level") ?? 1;

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

  // Toggle ambient soundscapes
  void toggleSoundscape(bool active, {String? soundType}) {
    _isSoundscapeActive = active;
    if (soundType != null) {
      _activeSoundscape = soundType;
    }
    notifyListeners();
  }

  // Set Timer values
  void setTimerDuration(int minutes, int seconds) {
    if (_isRunning) return;
    _maxSeconds = (minutes * 60) + seconds;
    _totalSeconds = _maxSeconds;
    _isBreak = false;
    notifyListeners();
  }

  // Start timer ticking
  void startTimer() {
    if (_isRunning) return;

    _isRunning = true;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_totalSeconds <= 0) {
        timer.cancel();
        _isRunning = false;
        HapticFeedback.vibrate();
        
        // Award XP and complete session
        completeSession();
      } else {
        _totalSeconds--;
        
        // Award 1 XP for focus every 2 seconds
        if (!_isBreak && _totalSeconds % 2 == 0) {
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
  }

  // Reset Timer
  void resetTimer() {
    _timer?.cancel();
    _isRunning = false;
    _totalSeconds = _maxSeconds;
    notifyListeners();
  }

  // Complete Focus Session
  Future<void> completeSession() async {
    if (_isBreak) {
      // Break is complete. Switch back to focus state
      _isBreak = false;
      _totalSeconds = _maxSeconds;
      notifyListeners();
      return;
    }

    // Award bonus XP for completing a session
    addXp(50);

    // Save streak & updates
    await updateStreak();
    await updateWeekly();

    // Call onSessionCompleted callback
    onSessionCompleted?.call();

    // Auto trigger a 5 minute break if focus was completed
    _isBreak = true;
    _totalSeconds = 300; // 5 min break
    _maxSeconds = 300;
    notifyListeners();
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

  // XP addition and level-up detection
  Future<void> addXp(int amount) async {
    _xp += amount;
    
    // Check level-up
    int needed = xpNeededForNextLevel();
    bool leveledUp = false;
    while (_xp >= needed) {
      _xp -= needed;
      _level++;
      needed = xpNeededForNextLevel();
      leveledUp = true;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("focus_xp", _xp);
    await prefs.setInt("focus_level", _level);

    if (leveledUp) {
      onLevelUp?.call();
    }
    notifyListeners();
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
  }

  // Update Weekly Completion stats
  Future<void> updateWeekly() async {
    final prefs = await SharedPreferences.getInstance();
    final days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    final day = days[DateTime.now().weekday % 7];

    _weeklyData[day] = (_weeklyData[day] ?? 0) + 1;
    await prefs.setInt(day, _weeklyData[day]!);
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
