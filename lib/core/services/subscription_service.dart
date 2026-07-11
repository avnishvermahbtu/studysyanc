import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  bool _isPro = true;
  bool get isPro => true;

  // Limits
  final int maxFreeChats = 5;
  final int maxFreeQuizzes = 1;
  final int maxFreeRoadmaps = 1;

  // Local caching variables
  int _dailyAiChatCount = 0;
  int _dailyQuizCount = 0;
  int _dailyRoadmapCount = 0;

  int get dailyAiChatCount => _dailyAiChatCount;
  int get dailyQuizCount => _dailyQuizCount;
  int get dailyRoadmapCount => _dailyRoadmapCount;

  String _getPrefix() {
    final user = FirebaseAuth.instance.currentUser;
    return user != null ? "${user.uid}_" : "guest_";
  }

  // Load subscription status and usage limits
  Future<void> init() async {
    await checkSubscriptionStatus();
    await loadUsageLimits();
  }

  // Fetch Pro status directly from Firestore users collection
  Future<void> checkSubscriptionStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _isPro = false;
        notifyListeners();
        return;
      }

      final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _isPro = data['isPro'] ?? false;
      } else {
        _isPro = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error checking subscription status: $e");
    }
  }

  // Upgrade user to Pro in Firestore (Simulated payment callback)
  Future<bool> upgradeToPro() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Update Firestore user document
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "isPro": true,
        "proExpiry": Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _isPro = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error upgrading to Pro: $e");
      return false;
    }
  }

  // Load local usage limits
  Future<void> loadUsageLimits() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _getPrefix();

    final todayStr = _getTodayDateString();
    final savedDate = prefs.getString("${prefix}last_limit_reset_date") ?? "";

    if (savedDate != todayStr) {
      // It's a new day, reset all usage limits
      await prefs.setString("${prefix}last_limit_reset_date", todayStr);
      await prefs.setInt("${prefix}daily_ai_chat_count", 0);
      await prefs.setInt("${prefix}daily_quiz_count", 0);
      await prefs.setInt("${prefix}daily_roadmap_count", 0);

      _dailyAiChatCount = 0;
      _dailyQuizCount = 0;
      _dailyRoadmapCount = 0;
    } else {
      _dailyAiChatCount = prefs.getInt("${prefix}daily_ai_chat_count") ?? 0;
      _dailyQuizCount = prefs.getInt("${prefix}daily_quiz_count") ?? 0;
      _dailyRoadmapCount = prefs.getInt("${prefix}daily_roadmap_count") ?? 0;
    }
    notifyListeners();
  }

  // Increment usage count in SharedPreferences
  Future<void> incrementUsage(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _getPrefix();
    final todayStr = _getTodayDateString();

    // Ensure limit date is correct
    await prefs.setString("${prefix}last_limit_reset_date", todayStr);

    if (type == "chat") {
      _dailyAiChatCount++;
      await prefs.setInt("${prefix}daily_ai_chat_count", _dailyAiChatCount);
    } else if (type == "quiz") {
      _dailyQuizCount++;
      await prefs.setInt("${prefix}daily_quiz_count", _dailyQuizCount);
    } else if (type == "roadmap") {
      _dailyRoadmapCount++;
      await prefs.setInt("${prefix}daily_roadmap_count", _dailyRoadmapCount);
    }
    notifyListeners();
  }

  // Helper getters for checking query permissions
  bool get canUseAiChat => true;
  bool get canGenerateQuiz => true;
  bool get canGenerateRoadmap => true;

  // Format date helper: YYYY-MM-DD
  String _getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }
}
