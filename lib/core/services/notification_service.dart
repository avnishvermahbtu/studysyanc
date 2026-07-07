import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../../features/routine/screens/routine_model.dart';
import '../../features/routine/controller/routine_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone support
    try {
      tz.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      var timeZoneName = timezoneInfo.identifier;
      
      // Map legacy/deprecated Calcutta timezone to Kolkata which exists in the database
      if (timeZoneName == "Asia/Calcutta") {
        timeZoneName = "Asia/Kolkata";
      }

      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint("Notification timezone initialized successfully: $timeZoneName");
    } catch (e) {
      debugPrint("Error initializing timezone: $e");
      try {
        tz.setLocalLocation(tz.UTC);
        debugPrint("Notification timezone fell back to UTC");
      } catch (_) {}
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
    );

    // Request notifications permission for Android 13+
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request exact alarms permission for Android 13+
    try {
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint("Failed to request exact alarms permission: $e");
    }

    _initialized = true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'studysync_geofence_channel',
      'StudySync Geofences',
      channelDescription: 'Notifications for entering and exiting study zones',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotificationsPlugin.show(id, title, body, notificationDetails);
  }

  Future<void> scheduleRoutineNotification(Routine routine) async {
    if (!_initialized) await init();

    debugPrint("Attempting to schedule notification for: ${routine.title}");
    debugPrint("Routine properties -> date: ${routine.date}, startTime: ${routine.startTime}");

    final startDateTime = RoutineController().parseTimeString(routine.startTime, routine.date);
    if (startDateTime == null) {
      debugPrint("WARNING: Could not parse routine start time: '${routine.startTime}'");
      return;
    }

    final now = DateTime.now();
    debugPrint("Parsed startDateTime: $startDateTime | Current system time: $now");

    // Check if the scheduled time is in the future
    if (startDateTime.isBefore(now)) {
      debugPrint("INFO: Routine start time ($startDateTime) is in the past. Skipping notification scheduling.");
      return;
    }

    final id = routine.id.hashCode;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'studysync_routine_channel',
      'StudySync Routines',
      channelDescription: 'Notifications for scheduled classes and routines',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _localNotificationsPlugin.zonedSchedule(
        id,
        'Routine Reminder: ${routine.title} ⏰',
        'Your ${routine.type} is starting now at ${routine.location.isNotEmpty ? routine.location : "its location"}!',
        tz.TZDateTime.from(startDateTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint("Successfully scheduled EXACT notification for routine ${routine.title} at $startDateTime (ID: $id)");
    } catch (e) {
      debugPrint("EXACT alarm scheduling failed (likely permission restriction). Trying fallback to INEXACT mode... Error: $e");
      try {
        await _localNotificationsPlugin.zonedSchedule(
          id,
          'Routine Reminder: ${routine.title} ⏰',
          'Your ${routine.type} is starting now at ${routine.location.isNotEmpty ? routine.location : "its location"}!',
          tz.TZDateTime.from(startDateTime, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint("Successfully scheduled INEXACT notification for routine ${routine.title} at $startDateTime (ID: $id)");
      } catch (innerErr) {
        debugPrint("FAILED to schedule inexact notification for routine ${routine.title}: $innerErr");
      }
    }
  }

  Future<void> cancelRoutineNotification(String routineId) async {
    if (!_initialized) await init();
    final id = routineId.hashCode;
    await _localNotificationsPlugin.cancel(id);
    debugPrint("Cancelled scheduled notification for routine ID: $routineId");
  }

  Future<void> syncUpcomingRoutines(List<Routine> routines) async {
    if (!_initialized) await init();
    
    final now = DateTime.now();
    for (var routine in routines) {
      final start = RoutineController().parseTimeString(routine.startTime, routine.date);
      if (start != null && start.isAfter(now)) {
        await scheduleRoutineNotification(routine);
      }
    }
  }

  // Daily Streak Protection Nudge (Repeats daily at 8:00 PM)
  Future<void> scheduleDailyStreakReminder(String studentName) async {
    if (!_initialized) await init();
    
    const id = 9999;
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 20, 0); // 8:00 PM
    
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'studysync_streak_channel',
      'StudySync Streak Saver',
      channelDescription: 'Daily reminders to save study streaks',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _localNotificationsPlugin.zonedSchedule(
        id,
        'Streak in danger! 😱',
        'Hey $studentName, save your study streak! Spend just 10 mins in Solo Focus to keep it alive today.',
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint("Successfully scheduled repeating daily streak reminder at 8:00 PM");
    } catch (e) {
      debugPrint("Failed to schedule streak reminder: $e");
    }
  }

  // Daily Morning Motivation Alert (Repeats daily at 8:00 AM)
  Future<void> scheduleMorningMotivation(String studentName) async {
    if (!_initialized) await init();
    
    const id = 8888;
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 8, 0); // 8:00 AM
    
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'studysync_motivation_channel',
      'StudySync Morning Motivation',
      channelDescription: 'Morning study quotes and prompts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    final quotes = [
      "Level up your day! Start a 25-minute Pomodoro block now. 🚀",
      "Consistent efforts shape champions. What is your goal today? 🎯",
      "StudySync is ready. Clear a pending backlog task today! 📚",
      "Do it for your future self. Start your focus timer now! 🧠",
    ];
    // Select quote based on weekday
    final randomQuote = quotes[now.weekday % quotes.length];

    try {
      await _localNotificationsPlugin.zonedSchedule(
        id,
        'Good Morning, $studentName! ☀️',
        randomQuote,
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint("Successfully scheduled repeating morning motivation at 8:00 AM");
    } catch (e) {
      debugPrint("Failed to schedule morning motivation: $e");
    }
  }

  // Pomodoro Focus Completion Reminder (Triggers after study session duration)
  Future<void> scheduleFocusCompletionNotification(int seconds, bool isBreak) async {
    if (!_initialized) await init();

    const id = 7777;
    
    // Clear any previous focus alert
    await _localNotificationsPlugin.cancel(id);

    final prefs = await SharedPreferences.getInstance();
    final studentName = prefs.getString('student_name') ?? "Student";

    final scheduledTime = DateTime.now().add(Duration(seconds: seconds));

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'studysync_focus_channel',
      'StudySync Focus Session',
      channelDescription: 'Notifications for Pomodoro session completion',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    final title = isBreak ? "Break is complete! ☕" : "Focus Session Complete! 🌳";
    final body = isBreak 
        ? "Hey $studentName, break is over. Let's start the next study block!" 
        : "Great job, $studentName! You completed your study block. Tap to start your break!";

    try {
      await _localNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint("Successfully scheduled focus completion in $seconds seconds");
    } catch (e) {
      debugPrint("Failed to schedule focus completion notification: $e");
    }
  }

  Future<void> cancelFocusCompletionNotification() async {
    if (!_initialized) await init();
    const id = 7777;
    await _localNotificationsPlugin.cancel(id);
    debugPrint("Cancelled focus completion notification");
  }
}
