package com.catalist

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Calendar

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

            val rawStatus = snapshot?.backgroundStatus?.takeIf { it.isNotBlank() } ?: "on_track"
            val status = resolveCelebrateExpiry(rawStatus, snapshot?.mascot)
            val timeBand = snapshot?.backgroundTimeBand?.takeIf { it.isNotBlank() } ?: timeBandFromSystem()
            val variant = snapshot?.backgroundVariant?.takeIf { it in 1..3 } ?: 1
            val bgResId = resolveBackgroundDrawable(context, status, timeBand, variant)
            views.setInt(R.id.widget_container, "setBackgroundResource", bgResId)

            scheduleCelebrateExpiryIfNeeded(context, appWidgetId, rawStatus, snapshot?.mascot)

            if (snapshot != null && snapshot.topGoal != null) {
                val goal = snapshot.topGoal!!

                // When celebrate expired we show on_track background; use neutral CTA so text matches
                val ctaText = if (status != rawStatus) "Let's go!" else (snapshot.cta ?: "Let's go!")
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
                val ctaText = if (status != rawStatus) "Let's go!" else (snapshot?.cta ?: "Let's start!")
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

        /** If status is "celebrate" and mascot has expired, show on_track instead. */
        private fun resolveCelebrateExpiry(status: String, mascot: MascotState?): String {
            if (status != "celebrate" || mascot == null || mascot.expiresAt == null) return status
            if (System.currentTimeMillis() > mascot.expiresAt!!) return "on_track"
            return status
        }

        /** When in celebrate with a future expiry, schedule an inexact widget refresh ~5 min later. No exact-alarm permission needed. */
        private fun scheduleCelebrateExpiryIfNeeded(
            context: Context,
            appWidgetId: Int,
            status: String,
            mascot: MascotState?
        ) {
            if (status != "celebrate" || mascot?.expiresAt == null) return
            val now = System.currentTimeMillis()
            if (mascot.expiresAt!! <= now) return
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, CatalistWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
            }
            val pending = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            // Inexact alarm: no SCHEDULE_EXACT_ALARM needed; system may deliver a few min late
            alarmManager.set(AlarmManager.RTC, mascot.expiresAt!!, pending)
        }

        /** Dawn 5–11, Day 11–17, Dusk 17–22, Night 22–5. Used so background rotates with time of day on every widget refresh. */
        private fun timeBandFromSystem(): String {
            val h = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
            return when {
                h in 5..10 -> "dawn"
                h in 11..16 -> "day"
                h in 17..21 -> "dusk"
                else -> "night"
            }
        }

        private fun resolveBackgroundDrawable(context: Context, status: String, timeBand: String, variant: Int): Int {
            val (s, t) = if (status == "end_of_day") "empty" to "night" else status to timeBand
            val base = "widget_bg_${s}_$t"
            val name = if (variant == 1) base else "${base}_$variant"
            var resId = context.resources.getIdentifier(name, "drawable", context.packageName)
            if (resId == 0 && variant != 1) resId = context.resources.getIdentifier(base, "drawable", context.packageName)
            return if (resId != 0) resId else R.drawable.widget_bg_on_track_day
        }
    }
}
