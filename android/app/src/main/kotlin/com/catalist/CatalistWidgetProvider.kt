package com.catalist

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import org.json.JSONObject

class CatalistWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, CatalistWidgetProvider::class.java)
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
            val snapshot = loadSnapshot(context)
            val views = RemoteViews(context.packageName, R.layout.catalist_widget_layout)
            
            if (snapshot != null && snapshot.topGoal != null) {
                val goal = snapshot.topGoal!!
                
                views.setInt(R.id.widget_container, "setBackgroundColor", getEmotionColorRes(snapshot.mascot.emotion))
                
                // Set CTA text
                val ctaText = snapshot.cta ?: "Let's go!"
                views.setTextViewText(R.id.cta_text, ctaText)
                
                val clickIntent = Intent(context, MainActivity::class.java).apply {
                    putExtra("action", "log_progress")
                    putExtra("goalId", goal.id)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                views.setOnClickPendingIntent(
                    R.id.widget_container,
                    android.app.PendingIntent.getActivity(
                        context, 0, clickIntent,
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                    )
                )
            } else {
                views.setInt(R.id.widget_container, "setBackgroundColor", 0xFFE6F0F9.toInt())
                
                // Set CTA for empty state
                val ctaText = snapshot?.cta ?: "Let's start!"
                views.setTextViewText(R.id.cta_text, ctaText)
                
                val clickIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                views.setOnClickPendingIntent(
                    R.id.widget_container,
                    android.app.PendingIntent.getActivity(
                        context, 0, clickIntent,
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                    )
                )
            }
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
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
