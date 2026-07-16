package com.example.studysync

import android.app.NotificationManager
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.example.studysync/widget"
    private val DND_CHANNEL = "com.example.studysync/dnd"
    private var pendingAction: String? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent != null && intent.action == "ACTION_TOGGLE_TIMER") {
            pendingAction = "toggle_timer"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        handleIntent(intent)
        
        // Widget Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getPendingAction") {
                result.success(pendingAction)
                pendingAction = null
            } else if (call.method == "updateWidgetData") {
                val streak = call.argument<Int>("streak") ?: 0
                val activeTasksCount = call.argument<Int>("activeTasksCount") ?: 0
                val isTimerRunning = call.argument<Boolean>("isTimerRunning") ?: false

                val prefs = getSharedPreferences("StudySyncWidgetPrefs", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putInt("streak", streak)
                    putInt("activeTasksCount", activeTasksCount)
                    putBoolean("is_timer_running", isTimerRunning)
                    apply()
                }

                // Trigger App Widget update by broadcasting a change intent
                val intent = Intent(this, StudySyncWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                }
                sendBroadcast(intent)

                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        // DND Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DND_CHANNEL).setMethodCallHandler { call, result ->
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            when (call.method) {
                "isPermissionGranted" -> {
                    val granted = notificationManager.isNotificationPolicyAccessGranted
                    result.success(granted)
                }
                "requestPermission" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "setDND" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    val mode = call.argument<String>("mode") ?: "priority"
                    val granted = notificationManager.isNotificationPolicyAccessGranted
                    if (granted) {
                        if (enable) {
                            when (mode) {
                                "none" -> notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                                "alarms" -> notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALARMS)
                                else -> notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                            }
                        } else {
                            notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                        }
                        result.success(true)
                    } else {
                        result.error("PERMISSION_DENIED", "Notification Policy Access is not granted", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
