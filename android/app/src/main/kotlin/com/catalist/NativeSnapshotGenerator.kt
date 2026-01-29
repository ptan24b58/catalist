package com.catalist

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.util.Calendar
import kotlin.math.abs

/**
 * Native Kotlin snapshot generator — replaces the Flutter/Dart WidgetSnapshotService.
 * Reads goals directly from SharedPreferences and generates a complete widget snapshot
 * without needing the Flutter engine or background app updates.
 *
 * Priority flow (matches Dart):
 *   1. Empty (no goals)
 *   2. 5-min celebration (recently completed goal)
 *   3. End of day (23:00–05:00)
 *   4. Long-term focus hour (14:00, 20:00)
 *   5. All daily goals complete
 *   6. Daily in-progress (fallback to long-term if no dailies)
 */
object NativeSnapshotGenerator {

    private const val TAG = "NativeSnapshotGen"
    private const val SNAPSHOT_VERSION = 2
    private const val FIVE_MIN_MS = 5 * 60 * 1000L

    // Urgency thresholds (matches Dart AppConstants)
    private const val URGENCY_HAPPY = 0.2
    private const val URGENCY_NEUTRAL = 0.5
    private const val URGENCY_WORRIED = 0.8

    // Urgency weights (daily)
    private const val PROGRESS_WEIGHT = 0.5
    private const val TIME_WEIGHT = 0.4
    private const val STREAK_WEIGHT = 0.1

    // Urgency weights (long-term)
    private const val DEADLINE_WEIGHT = 0.6
    private const val LONG_TERM_PROGRESS_WEIGHT = 0.4

    // Time constants
    private const val END_OF_DAY_START = 23
    private const val END_OF_DAY_END = 5
    private val LONG_TERM_FOCUS_HOURS = listOf(14, 20)

    /**
     * Generate a fresh snapshot from goals stored in SharedPreferences.
     * Returns null only on error; otherwise always produces a valid snapshot.
     */
    fun generate(context: Context): WidgetSnapshot? {
        return try {
            val nowMillis = System.currentTimeMillis()
            val cal = Calendar.getInstance()
            val hour = cal.get(Calendar.HOUR_OF_DAY)
            val minute = cal.get(Calendar.MINUTE)
            val goals = loadGoals(context)

            val snapshot = generateFromGoals(goals, nowMillis, hour, minute)
            saveSnapshot(context, snapshot)
            snapshot
        } catch (e: Exception) {
            Log.e(TAG, "Error generating native snapshot", e)
            null
        }
    }

    /**
     * Generate snapshot from a list of goals (testable without Context).
     */
    fun generateFromGoals(
        goals: List<NativeGoal>,
        nowMillis: Long,
        hour: Int,
        minute: Int
    ): WidgetSnapshot {
        val nowSec = nowMillis / 1000

        // 1. Empty state
        if (goals.isEmpty()) {
            return buildSnapshot(
                nowSec = nowSec,
                hour = hour,
                minute = minute,
                ctaContext = NativeCtaEngine.CTAContext.EMPTY,
            )
        }

        val dailyGoals = goals.filter { it.isDaily }
        val longTermGoals = goals.filter { it.isLongTerm }
        val incompleteDailies = dailyGoals.filter { !it.isCompleted }
        val incompleteLongTerm = longTermGoals.filter { !it.isCompleted }

        // 2. 5-min celebration (recently completed goal)
        val recentlyCompleted = findRecentlyCompleted(goals, nowMillis)
        if (recentlyCompleted != null) {
            val ctaContext = if (recentlyCompleted.isDaily)
                NativeCtaEngine.CTAContext.DAILY_COMPLETED_ONE_5MIN
            else
                NativeCtaEngine.CTAContext.LONG_TERM_COMPLETED_5MIN
            return buildSnapshot(
                nowSec = nowSec,
                hour = hour,
                minute = minute,
                ctaContext = ctaContext,
                goal = recentlyCompleted,
                nowMillis = nowMillis,
                emotion = "celebrate",
                emotionExpiresAt = nowMillis + FIVE_MIN_MS,
                status = "celebrate",
            )
        }

        // 3. End of day (11pm–5am)
        if (isEndOfDay(hour)) {
            val mostUrgent = findMostUrgent(goals, nowMillis)
            return buildSnapshot(
                nowSec = nowSec,
                hour = hour,
                minute = minute,
                ctaContext = NativeCtaEngine.CTAContext.END_OF_DAY,
                goal = mostUrgent,
                nowMillis = nowMillis,
                emotion = "neutral",
                status = "end_of_day",
            )
        }

        // 4. Long-term focus hour (14:00, 20:00)
        if (isLongTermHour(hour) && incompleteLongTerm.isNotEmpty()) {
            val mostUrgent = findMostUrgent(incompleteLongTerm, nowMillis) ?: incompleteLongTerm.first()
            val urgency = calculateUrgency(mostUrgent, nowMillis)
            return buildSnapshot(
                nowSec = nowSec,
                hour = hour,
                minute = minute,
                ctaContext = NativeCtaEngine.CTAContext.LONG_TERM_IN_PROGRESS,
                goal = mostUrgent,
                nowMillis = nowMillis,
                emotion = emotionFromUrgency(urgency),
                status = statusFromUrgency(urgency),
            )
        }

        // 5. All daily goals complete
        if (dailyGoals.isNotEmpty() && incompleteDailies.isEmpty()) {
            val lastCompleted = findMostRecentlyCompleted(dailyGoals)
            return buildSnapshot(
                nowSec = nowSec,
                hour = hour,
                minute = minute,
                ctaContext = NativeCtaEngine.CTAContext.DAILY_ALL_COMPLETE,
                goal = lastCompleted,
                nowMillis = nowMillis,
                emotion = "celebrate",
                emotionExpiresAt = nowMillis + FIVE_MIN_MS,
                status = "celebrate",
            )
        }

        // 6. Daily in-progress (or fallback to long-term if no dailies)
        val targetGoals = if (incompleteDailies.isNotEmpty()) incompleteDailies else incompleteLongTerm
        if (targetGoals.isEmpty()) {
            return buildSnapshot(
                nowSec = nowSec,
                hour = hour,
                minute = minute,
                ctaContext = NativeCtaEngine.CTAContext.EMPTY,
            )
        }

        val mostUrgent = findMostUrgent(targetGoals, nowMillis) ?: targetGoals.first()
        val urgency = calculateUrgency(mostUrgent, nowMillis)
        val ctaContext = if (mostUrgent.isDaily)
            NativeCtaEngine.CTAContext.DAILY_IN_PROGRESS
        else
            NativeCtaEngine.CTAContext.LONG_TERM_IN_PROGRESS

        val progressLabel = if (ctaContext == NativeCtaEngine.CTAContext.DAILY_IN_PROGRESS)
            mostUrgent.getProgressLabel(nowMillis) else null

        return buildSnapshot(
            nowSec = nowSec,
            hour = hour,
            minute = minute,
            ctaContext = ctaContext,
            goal = mostUrgent,
            nowMillis = nowMillis,
            emotion = emotionFromUrgency(urgency),
            status = statusFromUrgency(urgency),
            progressLabel = progressLabel,
        )
    }

    // ─── Snapshot builder ───

    private fun buildSnapshot(
        nowSec: Long,
        hour: Int,
        minute: Int,
        ctaContext: NativeCtaEngine.CTAContext,
        goal: NativeGoal? = null,
        nowMillis: Long? = null,
        emotion: String = "neutral",
        emotionExpiresAt: Long? = null,
        status: String = "empty",
        progressLabel: String? = null,
    ): WidgetSnapshot {
        val effectiveNowMillis = nowMillis ?: System.currentTimeMillis()

        var topGoal: TopGoal? = null
        if (goal != null) {
            val urgency = calculateUrgency(goal, effectiveNowMillis)
            val nextDue = goal.getNextDueTime(effectiveNowMillis)
            topGoal = TopGoal(
                id = goal.id,
                title = goal.title,
                progress = goal.getProgress(),
                goalType = goal.goalType,
                progressType = goal.progressType,
                nextDueEpoch = nextDue?.let { it / 1000 },
                urgency = urgency,
                progressLabel = goal.getProgressLabel(effectiveNowMillis),
            )
        }

        val cta = NativeCtaEngine.generate(ctaContext, hour, minute, progressLabel)
        val timeBand = timeBandFromHour(hour)
        val variant = getVariant(effectiveNowMillis, hour, status)

        return WidgetSnapshot(
            version = SNAPSHOT_VERSION,
            generatedAt = nowSec,
            topGoal = topGoal,
            mascot = MascotState(
                emotion = emotion,
                frameIndex = 0,
                expiresAt = emotionExpiresAt,
            ),
            cta = cta,
            backgroundStatus = status,
            backgroundTimeBand = timeBand,
            backgroundVariant = variant,
        )
    }

    // ─── Urgency engine (mirrors Dart UrgencyEngine) ───

    fun calculateUrgency(goal: NativeGoal, nowMillis: Long): Double {
        if (goal.isCompleted) return 0.0
        return if (goal.isDaily) calculateDailyUrgency(goal, nowMillis)
        else calculateLongTermUrgency(goal, nowMillis)
    }

    private fun calculateDailyUrgency(goal: NativeGoal, nowMillis: Long): Double {
        val progress = goal.getProgressToday(nowMillis)
        val nextDue = goal.getNextDueTime(nowMillis) ?: return 0.0

        // Progress component (0–0.5 weight)
        val progressScore = when (goal.progressType) {
            "completion" -> if (progress < 1.0) PROGRESS_WEIGHT else 0.0
            "numeric" -> {
                val target = goal.dailyTarget
                val ratio = progress / target
                (1.0 - ratio.coerceIn(0.0, 1.0)) * PROGRESS_WEIGHT
            }
            else -> 0.0
        }

        // Time component (0–0.4 weight)
        val timeRemainingSec = (nextDue - nowMillis) / 1000.0
        val totalWindowSec = 24 * 60 * 60.0
        val timeRatio = (timeRemainingSec / totalWindowSec).coerceIn(0.0, 1.0)
        val timeScore = (1.0 - timeRatio) * TIME_WEIGHT

        // Streak risk component (0–0.1 weight)
        var streakScore = 0.0
        if (goal.currentStreak > 0) {
            val yesterday = getYesterday(nowMillis)
            val lastCompleted = goal.lastCompletedAt
            if (lastCompleted == null || normalizeToDay(lastCompleted) < yesterday) {
                streakScore = STREAK_WEIGHT
            }
        }

        return (progressScore + timeScore + streakScore).coerceIn(0.0, 1.0)
    }

    private fun calculateLongTermUrgency(goal: NativeGoal, nowMillis: Long): Double {
        val progress = goal.getProgress()
        val deadline = goal.deadline

        // No deadline = lower urgency based on progress stagnation
        if (deadline == null) {
            return ((1.0 - progress) * 0.5).coerceIn(0.0, 0.5)
        }

        // Overdue = max urgency
        if (goal.isOverdue(nowMillis)) return 1.0

        val daysRemaining = goal.getDaysRemaining(nowMillis) ?: 0
        val totalDays = ((deadline - goal.createdAt) / (24 * 60 * 60 * 1000)).toInt()
        if (totalDays <= 0) return 1.0

        val daysElapsed = totalDays - daysRemaining
        val expectedProgress = daysElapsed.toDouble() / totalDays
        val progressDeficit = (expectedProgress - progress).coerceIn(0.0, 1.0)
        val timePressure = 1.0 - (daysRemaining.toDouble() / totalDays).coerceIn(0.0, 1.0)

        val deadlineScore = timePressure * DEADLINE_WEIGHT
        val progressScore = progressDeficit * LONG_TERM_PROGRESS_WEIGHT

        return (deadlineScore + progressScore).coerceIn(0.0, 1.0)
    }

    // ─── Mascot engine (mirrors Dart MascotEngine) ───

    private fun emotionFromUrgency(urgency: Double): String {
        return when {
            urgency < URGENCY_HAPPY -> "happy"
            urgency < URGENCY_NEUTRAL -> "neutral"
            urgency < URGENCY_WORRIED -> "worried"
            else -> "sad"
        }
    }

    // ─── Status helpers ───

    private fun statusFromUrgency(urgency: Double): String {
        return when {
            urgency >= URGENCY_WORRIED -> "urgent"
            urgency >= URGENCY_HAPPY -> "behind"
            else -> "on_track"
        }
    }

    private fun isEndOfDay(hour: Int): Boolean = hour >= END_OF_DAY_START || hour < END_OF_DAY_END

    private fun isLongTermHour(hour: Int): Boolean = hour in LONG_TERM_FOCUS_HOURS

    // ─── Goal selection helpers ───

    private fun findMostUrgent(goals: List<NativeGoal>, nowMillis: Long): NativeGoal? {
        var best: NativeGoal? = null
        var bestUrgency = -1.0
        for (goal in goals) {
            if (goal.isCompleted) continue
            val u = calculateUrgency(goal, nowMillis)
            if (u > bestUrgency) {
                bestUrgency = u
                best = goal
            }
        }
        return best
    }

    /** Find goal completed within last 5 minutes (most recent) */
    private fun findRecentlyCompleted(goals: List<NativeGoal>, nowMillis: Long): NativeGoal? {
        var recent: NativeGoal? = null
        var recentTime: Long? = null
        for (g in goals) {
            val completedAt = g.lastCompletedAt ?: continue
            if (g.isCompleted && (nowMillis - completedAt) < FIVE_MIN_MS) {
                if (recentTime == null || completedAt > recentTime) {
                    recent = g
                    recentTime = completedAt
                }
            }
        }
        return recent
    }

    /** Find the most recently completed goal from a list */
    private fun findMostRecentlyCompleted(goals: List<NativeGoal>): NativeGoal? {
        var recent: NativeGoal? = null
        var recentTime: Long? = null
        for (g in goals) {
            if (!g.isCompleted) continue
            val completedAt = g.lastCompletedAt ?: g.createdAt
            if (recentTime == null || completedAt > recentTime) {
                recent = g
                recentTime = completedAt
            }
        }
        return recent
    }

    // ─── Background theme helpers (mirrors Dart WidgetBackgroundTheme) ───

    private fun timeBandFromHour(hour: Int): String {
        return when {
            hour in 5..10 -> "dawn"
            hour in 11..16 -> "day"
            hour in 17..21 -> "dusk"
            else -> "night"
        }
    }

    /** Variant 1–3, deterministic by day + hour + status (matches Dart logic). */
    private fun getVariant(nowMillis: Long, hour: Int, statusName: String): Int {
        val cal = Calendar.getInstance().apply { timeInMillis = nowMillis }
        val day = cal.get(Calendar.YEAR) * 1000 + cal.get(Calendar.DAY_OF_YEAR)
        val seed = day + hour * 10 + abs(statusName.hashCode())
        return (seed % 3) + 1
    }

    // ─── Snapshot persistence ───

    /** Save snapshot to SharedPreferences (same key Flutter reads). */
    fun saveSnapshot(context: Context, snapshot: WidgetSnapshot) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val json = serializeSnapshot(snapshot)
            prefs.edit().putString("flutter.widget_snapshot", json).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error saving native snapshot", e)
        }
    }

    /** Serialize snapshot to JSON string (matches Dart's WidgetSnapshot.toJson). */
    fun serializeSnapshot(snapshot: WidgetSnapshot): String {
        val obj = JSONObject()
        obj.put("version", snapshot.version)
        obj.put("generatedAt", snapshot.generatedAt)

        if (snapshot.topGoal != null) {
            val goalObj = JSONObject()
            goalObj.put("id", snapshot.topGoal.id)
            goalObj.put("title", snapshot.topGoal.title)
            goalObj.put("progress", snapshot.topGoal.progress)
            goalObj.put("goalType", snapshot.topGoal.goalType)
            goalObj.put("progressType", snapshot.topGoal.progressType)
            if (snapshot.topGoal.nextDueEpoch != null) {
                goalObj.put("nextDueEpoch", snapshot.topGoal.nextDueEpoch)
            } else {
                goalObj.put("nextDueEpoch", JSONObject.NULL)
            }
            goalObj.put("urgency", snapshot.topGoal.urgency)
            if (snapshot.topGoal.progressLabel != null) {
                goalObj.put("progressLabel", snapshot.topGoal.progressLabel)
            } else {
                goalObj.put("progressLabel", JSONObject.NULL)
            }
            obj.put("topGoal", goalObj)
        } else {
            obj.put("topGoal", JSONObject.NULL)
        }

        val mascotObj = JSONObject()
        mascotObj.put("emotion", snapshot.mascot.emotion)
        mascotObj.put("frameIndex", snapshot.mascot.frameIndex)
        if (snapshot.mascot.expiresAt != null) {
            mascotObj.put("expiresAt", snapshot.mascot.expiresAt)
        } else {
            mascotObj.put("expiresAt", JSONObject.NULL)
        }
        obj.put("mascot", mascotObj)

        if (snapshot.cta != null) obj.put("cta", snapshot.cta) else obj.put("cta", JSONObject.NULL)
        if (snapshot.backgroundStatus != null) obj.put("backgroundStatus", snapshot.backgroundStatus) else obj.put("backgroundStatus", JSONObject.NULL)
        if (snapshot.backgroundTimeBand != null) obj.put("backgroundTimeBand", snapshot.backgroundTimeBand) else obj.put("backgroundTimeBand", JSONObject.NULL)
        if (snapshot.backgroundVariant != null) obj.put("backgroundVariant", snapshot.backgroundVariant) else obj.put("backgroundVariant", JSONObject.NULL)

        return obj.toString()
    }
}
