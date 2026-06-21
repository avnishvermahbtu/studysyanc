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
        // Check if ACTION_APPWIDGET_UPDATE or generic intent to trigger update
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val thisWidget = ComponentName(context, StudySyncWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
        onUpdate(context, appWidgetManager, appWidgetIds)
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences("StudySyncWidgetPrefs", Context.MODE_PRIVATE)
            val streak = prefs.getInt("streak", 0)
            val activeTasksCount = prefs.getInt("activeTasksCount", 0)

            // Construct the RemoteViews object using the layout resource id
            val views = RemoteViews(context.packageName, R.layout.study_sync_widget)
            
            views.setTextViewText(R.id.widget_streak_text, "$streak Days")
            views.setTextViewText(R.id.widget_tasks_text, "$activeTasksCount Active")

            // Intent to launch the MainActivity when clicking the widget container
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            // Instruct the widget manager to update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
