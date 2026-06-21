import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/focus/controller/focus_controller.dart';

class WidgetService {
  static const MethodChannel _channel = MethodChannel('com.example.studysync/widget');

  // Trigger home screen widget update with streak and active task counts
  static Future<void> updateWidgetData() async {
    try {
      final FocusController focusController = FocusController();
      final int streak = focusController.streak;

      // Query active tasks count from Firestore
      int activeTasksCount = 0;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection("tasks")
            .where("isDone", isEqualTo: false)
            .get();
        activeTasksCount = querySnapshot.docs.length;
      }

      await _channel.invokeMethod('updateWidgetData', {
        'streak': streak,
        'activeTasksCount': activeTasksCount,
      });
    } on PlatformException catch (_) {
      // safe fallback for unsupported platforms or configurations
    } catch (_) {
      // safe catch
    }
  }
}
