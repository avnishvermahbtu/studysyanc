package com.example.studysync

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews

class StudySyncWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "com.example.studysync.ACTION_TOGGLE_TIMER") {
            // Toggle local preference for instant UI update
            val prefs = context.getSharedPreferences("StudySyncWidgetPrefs", Context.MODE_PRIVATE)
            val isRunning = prefs.getBoolean("is_timer_running", false)
            prefs.edit().putBoolean("is_timer_running", !isRunning).apply()

            // Update widgets instantly
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, StudySyncWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }

            // Launch MainActivity to perform the actual toggle in Flutter
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = "ACTION_TOGGLE_TIMER"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            context.startActivity(launchIntent)
        } else {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, StudySyncWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences("StudySyncWidgetPrefs", Context.MODE_PRIVATE)
            val streak = prefs.getInt("streak", 0)
            val activeTasksCount = prefs.getInt("activeTasksCount", 0)
            val isRunning = prefs.getBoolean("is_timer_running", false)

            // Construct the RemoteViews object using the layout resource id
            val views = RemoteViews(context.packageName, R.layout.study_sync_widget)
            
            views.setTextViewText(R.id.widget_streak_text, "$streak Days")
            views.setTextViewText(R.id.widget_tasks_text, "$activeTasksCount Active")

            // Update play/pause icon based on running state
            if (isRunning) {
                views.setImageViewResource(R.id.widget_play_btn, android.R.drawable.ic_media_pause)
            } else {
                views.setImageViewResource(R.id.widget_play_btn, android.R.drawable.ic_media_play)
            }

            // Intent to launch the MainActivity when clicking the widget container
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            // PendingIntent for play/pause toggle button
            val actionIntent = Intent(context, StudySyncWidgetProvider::class.java).apply {
                action = "com.example.studysync.ACTION_TOGGLE_TIMER"
            }
            val pendingActionIntent = PendingIntent.getBroadcast(
                context, 1, actionIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_play_btn, pendingActionIntent)

            // Instruct the widget manager to update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
