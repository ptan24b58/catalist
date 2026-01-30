package com.catalist

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/**
 * Native Kotlin goal data models and parsing — mirrors Dart's Goal domain model.
 * Reads goals directly from Flutter SharedPreferences (key: "flutter.goals").
 */

data class NativeGoal(
    val id: String,
    val title: String,
    val goalType: String,        // "daily" or "longTerm"
    val progressType: String,    // "completion", "percentage", "milestones", "numeric"
    val targetValue: Double?,
    val currentValue: Double,
    val unit: String?,
    val percentComplete: Double,
    val milestones: List<NativeMilestone>,
    val deadline: Long?,         // epoch millis (null if none)
    val todayCompletions: List<Long>, // epoch millis list
    val currentStreak: Int,
    val longestStreak: Int,
    val lastCompletedAt: Long?,  // epoch millis
    val createdAt: Long          // epoch millis
) {
    val isDaily: Boolean get() = goalType == "daily"
    val isLongTerm: Boolean get() = goalType == "longTerm"

    /** Check if this goal is completed (mirrors Dart's Goal.isCompleted) */
    val isCompleted: Boolean get() {
        return when (progressType) {
            "completion" -> {
                if (isDaily) {
                    lastCompletedAt != null && isSameDay(lastCompletedAt, System.currentTimeMillis())
                } else {
                    lastCompletedAt != null
                }
            }
            "percentage" -> percentComplete >= 100.0
            "milestones" -> milestones.isNotEmpty() && milestones.all { it.completed }
            "numeric" -> targetValue != null && currentValue >= targetValue
            else -> false
        }
    }

    /** Get overall progress as 0-1 (mirrors Dart's Goal.getProgress) */
    fun getProgress(): Double {
        return when (progressType) {
            "completion" -> if (isCompleted) 1.0 else 0.0
            "percentage" -> (percentComplete / 100.0).coerceIn(0.0, 1.0)
            "milestones" -> {
                if (milestones.isEmpty()) 0.0
                else milestones.count { it.completed }.toDouble() / milestones.size
            }
            "numeric" -> {
                if (targetValue == null || targetValue == 0.0) 0.0
                else (currentValue / targetValue).coerceIn(0.0, 1.0)
            }
            else -> 0.0
        }
    }

    /** Get progress for today (for daily goals) */
    fun getProgressToday(nowMillis: Long): Double {
        if (!isDaily) return getProgress()

        return when (progressType) {
            "completion" -> {
                if (lastCompletedAt != null && isSameDay(lastCompletedAt, nowMillis)) 1.0 else 0.0
            }
            "numeric" -> {
                todayCompletions.count { isSameDay(it, nowMillis) }.toDouble()
            }
            else -> getProgress()
        }
    }

    /** Whether this daily goal is completed today */
    fun isCompletedToday(nowMillis: Long): Boolean {
        if (!isDaily) return isCompleted
        return getProgressToday(nowMillis) >= dailyTarget
    }

    val dailyTarget: Int get() = targetValue?.toInt() ?: 1

    val completedMilestones: Int get() = milestones.count { it.completed }

    /** Get days remaining until deadline */
    fun getDaysRemaining(nowMillis: Long): Int? {
        if (deadline == null) return null
        return ((deadline - nowMillis) / (24 * 60 * 60 * 1000)).toInt()
    }

    /** Check if goal is overdue */
    fun isOverdue(nowMillis: Long): Boolean {
        if (deadline == null) return false
        return nowMillis > deadline && !isCompleted
    }

    /** Get next due time epoch millis (for daily: end of day; for long-term: deadline) */
    fun getNextDueTime(nowMillis: Long): Long? {
        if (isLongTerm) return deadline
        // Daily goal — due at end of day
        return getEndOfDay(nowMillis)
    }

    /** Get progress label (mirrors Dart's ProgressFormatter) */
    fun getProgressLabel(nowMillis: Long): String {
        return when (progressType) {
            "completion" -> {
                val done = if (isDaily && lastCompletedAt != null && isSameDay(lastCompletedAt, nowMillis)) 1 else if (isDaily) 0 else if (isCompleted) 1 else 0
                "$done/1"
            }
            "percentage" -> "${percentComplete.toInt()}%"
            "milestones" -> "$completedMilestones/${milestones.size}"
            "numeric" -> {
                val current = currentValue.toInt()
                val target = targetValue?.toInt()?.toString() ?: "?"
                "$current/$target ${unit ?: ""}".trim()
            }
            else -> ""
        }
    }
}

data class NativeMilestone(
    val id: String,
    val title: String,
    val completed: Boolean,
    val completedAt: Long?  // epoch millis
)

// ─── Date helpers (mirrors Dart DateUtils) ───

/** Normalize epoch millis to midnight (start of day) in local timezone */
fun normalizeToDay(epochMillis: Long): Long {
    val cal = Calendar.getInstance().apply { timeInMillis = epochMillis }
    cal.set(Calendar.HOUR_OF_DAY, 0)
    cal.set(Calendar.MINUTE, 0)
    cal.set(Calendar.SECOND, 0)
    cal.set(Calendar.MILLISECOND, 0)
    return cal.timeInMillis
}

/** Check if two epoch millis are on the same calendar day */
fun isSameDay(a: Long, b: Long): Boolean = normalizeToDay(a) == normalizeToDay(b)

/** Get end of day for the given epoch millis */
fun getEndOfDay(epochMillis: Long): Long {
    val cal = Calendar.getInstance().apply { timeInMillis = epochMillis }
    cal.set(Calendar.HOUR_OF_DAY, 23)
    cal.set(Calendar.MINUTE, 59)
    cal.set(Calendar.SECOND, 59)
    cal.set(Calendar.MILLISECOND, 0)
    return cal.timeInMillis
}

/** Get yesterday (normalized to midnight) */
fun getYesterday(epochMillis: Long): Long {
    return normalizeToDay(epochMillis) - 24 * 60 * 60 * 1000
}

// ─── ISO 8601 date parsing ───

private val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).apply {
    timeZone = TimeZone.getDefault()
}
private val isoFormatNoMillis = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply {
    timeZone = TimeZone.getDefault()
}

fun parseIsoDate(dateString: String?): Long? {
    if (dateString == null) return null
    return try {
        // Strip trailing Z or timezone offset for simplicity, parse as local
        val clean = dateString.replace("Z", "").replace(Regex("[+-]\\d{2}:\\d{2}$"), "")
        try {
            isoFormat.parse(clean)?.time
        } catch (_: Exception) {
            isoFormatNoMillis.parse(clean)?.time
        }
    } catch (e: Exception) {
        Log.w("NativeGoalData", "Failed to parse date: $dateString", e)
        null
    }
}

// ─── Goal loading from SharedPreferences ───

/** Load all goals from Flutter SharedPreferences */
fun loadGoals(context: Context): List<NativeGoal> {
    return try {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val goalsJson = prefs.getString("flutter.goals", null) ?: return emptyList()

        if (goalsJson.length > 1_000_000) {
            Log.e("NativeGoalData", "Goals JSON too large, skipping")
            return emptyList()
        }

        val arr = JSONArray(goalsJson)
        val goals = mutableListOf<NativeGoal>()
        for (i in 0 until arr.length()) {
            try {
                val obj = arr.getJSONObject(i)
                goals.add(parseGoal(obj))
            } catch (e: Exception) {
                Log.w("NativeGoalData", "Skipping invalid goal at index $i", e)
            }
        }
        goals
    } catch (e: Exception) {
        Log.e("NativeGoalData", "Error loading goals", e)
        emptyList()
    }
}

private fun parseGoal(obj: JSONObject): NativeGoal {
    val milestones = mutableListOf<NativeMilestone>()
    val milestonesArr = obj.optJSONArray("milestones")
    if (milestonesArr != null) {
        for (i in 0 until milestonesArr.length()) {
            val m = milestonesArr.getJSONObject(i)
            milestones.add(
                NativeMilestone(
                    id = m.getString("id"),
                    title = m.getString("title"),
                    completed = m.optBoolean("completed", false),
                    completedAt = parseIsoDate(m.optString("completedAt", null))
                )
            )
        }
    }

    val todayCompletions = mutableListOf<Long>()
    val completionsArr = obj.optJSONArray("todayCompletions")
    if (completionsArr != null) {
        for (i in 0 until completionsArr.length()) {
            parseIsoDate(completionsArr.getString(i))?.let { todayCompletions.add(it) }
        }
    }

    return NativeGoal(
        id = obj.getString("id"),
        title = obj.getString("title"),
        goalType = obj.optString("goalType", "daily"),
        progressType = obj.optString("progressType", "completion"),
        targetValue = if (obj.has("targetValue") && !obj.isNull("targetValue")) obj.getDouble("targetValue") else null,
        currentValue = obj.optDouble("currentValue", 0.0),
        unit = if (obj.has("unit") && !obj.isNull("unit")) obj.getString("unit") else null,
        percentComplete = obj.optDouble("percentComplete", 0.0),
        milestones = milestones,
        deadline = parseIsoDate(if (obj.has("deadline") && !obj.isNull("deadline")) obj.getString("deadline") else null),
        todayCompletions = todayCompletions,
        currentStreak = obj.optInt("currentStreak", 0),
        longestStreak = obj.optInt("longestStreak", 0),
        lastCompletedAt = parseIsoDate(if (obj.has("lastCompletedAt") && !obj.isNull("lastCompletedAt")) obj.getString("lastCompletedAt") else null),
        createdAt = parseIsoDate(obj.getString("createdAt")) ?: System.currentTimeMillis()
    )
}
