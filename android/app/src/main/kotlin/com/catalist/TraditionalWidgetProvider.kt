package com.catalist

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import org.json.JSONObject

class TraditionalWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d("TraditionalWidget", "📢 onUpdate called for ${appWidgetIds.size} widget(s)")
        
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d("TraditionalWidget", "Widget enabled")
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        Log.d("TraditionalWidget", "Widget disabled")
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, TraditionalWidgetProvider::class.java)
            )
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            Log.d("TraditionalWidget", "🔄 Updating widget $appWidgetId")
            
            val snapshot = loadSnapshot(context)
            val views = RemoteViews(context.packageName, R.layout.catalist_widget_layout)
            
            if (snapshot != null && snapshot.topGoal != null) {
                val goal = snapshot.topGoal!!
                val emotion = snapshot.mascot.emotion
                
                // Set progress label
                views.setTextViewText(R.id.progress_label, goal.progressLabel ?: "${(goal.progress * 100).toInt()}%")
                
                // Set background color based on emotion
                val backgroundColor = getEmotionColorRes(emotion)
                views.setInt(R.id.widget_container, "setBackgroundColor", backgroundColor)
                
                // Set click action to log progress
                val clickIntent = Intent(context, MainActivity::class.java).apply {
                    putExtra("action", "log_progress")
                    putExtra("goalId", goal.id)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    0,
                    clickIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                
                Log.d("TraditionalWidget", "✅ Widget updated with goal: ${goal.title}, emotion: $emotion")
            } else {
                // No goals state
                views.setTextViewText(R.id.progress_label, "Add a goal!")
                views.setInt(R.id.widget_container, "setBackgroundColor", 0xFFE6F0F9.toInt())
                
                val clickIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    0,
                    clickIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                
                Log.d("TraditionalWidget", "✅ Widget updated (no goals)")
            }
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d("TraditionalWidget", "✅ Widget $appWidgetId update completed")
        }
        
        private fun getEmotionColorRes(emotion: String): Int {
            // Return actual color values (ARGB)
            return when (emotion) {
                "happy" -> 0xFFE6F5E6.toInt()      // Light green
                "neutral" -> 0xFFE6F0F9.toInt()    // Light blue
                "worried" -> 0xFFFFF4E6.toInt()    // Light orange
                "sad" -> 0xFFFFE6E6.toInt()        // Light red
                "celebrate" -> 0xFFFFFBE6.toInt() // Light gold
                else -> 0xFFE6F0F9.toInt()         // Default to neutral
            }
        }
    }
}
