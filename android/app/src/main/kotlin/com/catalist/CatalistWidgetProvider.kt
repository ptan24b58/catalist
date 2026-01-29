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
            scheduleStateTransitions(context, appWidgetId)
            // Trigger snapshot regeneration for dynamic hourly updates
            triggerSnapshotRegeneration(context)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, CatalistWidgetProvider::class.java)
        )
        for (appWidgetId in appWidgetIds) {
            scheduleStateTransitions(context, appWidgetId)
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
        // Long-term focus hours (must match Flutter's AppConstants.longTermFocusHours)
        private val LONG_TERM_FOCUS_HOURS = listOf(14, 20)

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val snapshot = loadSnapshot(context)
            val views = RemoteViews(context.packageName, R.layout.catalist_widget_layout)
            val now = System.currentTimeMillis()
            val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)

            // Check if snapshot is stale (older than 35 min)
            val snapshotAge = if (snapshot != null) now / 1000 - snapshot.generatedAt else Long.MAX_VALUE
            val isStale = snapshotAge > 2100 // 35 minutes in seconds

            val rawStatus = snapshot?.backgroundStatus?.takeIf { it.isNotBlank() } ?: "on_track"
            val status = resolveCelebrateExpiry(rawStatus, snapshot?.mascot)

            // Determine time-aware status when stale
            val effectiveStatus = if (isStale) statusFromTime(hour) else status

            val timeBand = snapshot?.backgroundTimeBand?.takeIf { it.isNotBlank() } ?: timeBandFromSystem()
            val variant = snapshot?.backgroundVariant?.takeIf { it in 1..3 } ?: 1
            val bgResId = resolveBackgroundDrawable(context, effectiveStatus, timeBand, variant)
            views.setInt(R.id.widget_container, "setBackgroundResource", bgResId)

            scheduleCelebrateExpiryIfNeeded(context, appWidgetId, rawStatus, snapshot?.mascot)

            // If celebration just expired or snapshot is stale, trigger regeneration
            val celebrateExpired = status != rawStatus
            if (celebrateExpired || isStale) {
                triggerSnapshotRegeneration(context, forceRegenerate = true)
            }

            // Determine CTA: use time-aware CTA when stale, otherwise use snapshot
            val ctaText = if (isStale || snapshot?.cta == null) {
                ctaFromTime(hour, snapshot?.topGoal != null)
            } else {
                snapshot.cta
            }

            if (snapshot != null && snapshot.topGoal != null) {
                val goal = snapshot.topGoal!!

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

        /** Trigger snapshot regeneration via MainActivity (for 30‑min updates to feel dynamic). */
        private fun triggerSnapshotRegeneration(context: Context, forceRegenerate: Boolean = false) {
            // Check if snapshot is stale (older than 25 minutes) before regenerating
            val snapshot = loadSnapshot(context)
            val now = System.currentTimeMillis() / 1000 // generatedAt is in seconds
            val snapshotAge = if (snapshot != null) {
                now - snapshot.generatedAt
            } else {
                Long.MAX_VALUE // No snapshot, definitely regenerate
            }

            // Regenerate if forced (e.g., celebration expired) or snapshot is older than 25 min
            if (forceRegenerate || snapshotAge > 1500) {
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = "com.catalist.REGENERATE_SNAPSHOT"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                try {
                    context.startActivity(intent)
                } catch (e: Exception) {
                    // If app isn't running, this will fail silently - that's okay
                    // The 30‑min refresh will still update the widget with existing snapshot
                }
            }
        }

        /** State transition hours: end-of-day (5, 23) and long-term focus (14, 15, 20, 21) */
        private val STATE_TRANSITION_HOURS = listOf(5, 14, 15, 20, 21, 23)

        /** Schedule alarms at state transition times to refresh the widget */
        private fun scheduleStateTransitions(context: Context, appWidgetId: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val now = System.currentTimeMillis()

            for ((index, hour) in STATE_TRANSITION_HOURS.withIndex()) {
                val calendar = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                var targetTime = calendar.timeInMillis
                if (targetTime <= now) {
                    calendar.add(Calendar.DAY_OF_YEAR, 1)
                    targetTime = calendar.timeInMillis
                }

                // Use broadcast to widget provider (works when app is killed)
                val intent = Intent(context, CatalistWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
                }
                val pending = PendingIntent.getBroadcast(
                    context,
                    appWidgetId * 100 + index, // Unique request code per hour
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.set(AlarmManager.RTC_WAKEUP, targetTime, pending)
            }
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

        /** Determine widget status from current hour (for stale snapshots) */
        private fun statusFromTime(hour: Int): String {
            return when {
                hour >= 23 || hour < 5 -> "end_of_day"
                hour in LONG_TERM_FOCUS_HOURS -> "on_track"
                else -> "on_track"
            }
        }

        /** Generate time-aware CTA when snapshot is stale */
        private fun ctaFromTime(hour: Int, hasGoal: Boolean): String {
            return when {
                hour >= 23 || hour < 5 -> "Time to rest, Vivian"
                hour in LONG_TERM_FOCUS_HOURS -> if (hasGoal) "Focus on the big picture" else "Let's start!"
                hour in 5..10 -> if (hasGoal) "Good morning! Let's go" else "Start your day right"
                hour in 11..16 -> if (hasGoal) "Keep the momentum going" else "Let's start!"
                else -> if (hasGoal) "You've got this, Vivian" else "Let's start!"
            }
        }
    }
}
