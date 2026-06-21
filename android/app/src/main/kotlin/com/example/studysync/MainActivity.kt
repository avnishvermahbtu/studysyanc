package com.example.studysync

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.studysync/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidgetData") {
                val streak = call.argument<Int>("streak") ?: 0
                val activeTasksCount = call.argument<Int>("activeTasksCount") ?: 0

                val prefs = getSharedPreferences("StudySyncWidgetPrefs", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putInt("streak", streak)
                    putInt("activeTasksCount", activeTasksCount)
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
    }
}
