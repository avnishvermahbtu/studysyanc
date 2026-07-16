import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/focus/controller/focus_controller.dart';

class WidgetService {
  static const MethodChannel _channel = MethodChannel('com.example.studysync/widget');
  static int _cachedActiveCount = 0;

  // Trigger home screen widget update with streak and active task counts
  static Future<void> updateWidgetData([int? activeCount]) async {
    try {
      if (activeCount != null) {
        _cachedActiveCount = activeCount;
      }
      final FocusController focusController = FocusController();
      final int streak = focusController.streak;

      await _channel.invokeMethod('updateWidgetData', {
        'streak': streak,
        'activeTasksCount': _cachedActiveCount,
        'isTimerRunning': focusController.isRunning,
      });
    } on PlatformException catch (_) {
      // safe fallback for unsupported platforms or configurations
    } catch (_) {
      // safe catch
    }
  }
}
