package com.catalist

import android.content.Context
import android.util.Log
import org.json.JSONObject

// Data classes for widget snapshot
data class WidgetSnapshot(
    val version: Int,
    val generatedAt: Long,
    val topGoal: TopGoal?,
    val mascot: MascotState
)

data class TopGoal(
    val id: String,
    val title: String,
    val progress: Double,        // 0-1 normalized progress
    val goalType: String,        // "daily" or "longTerm"
    val progressType: String,    // "completion", "percentage", "milestones", "numeric"
    val nextDueEpoch: Long?,
    val urgency: Double,
    val progressLabel: String?   // Human-readable progress text
) {
    val isDaily: Boolean get() = goalType == "daily"
    val isLongTerm: Boolean get() = goalType == "longTerm"
}

data class MascotState(
    val emotion: String,
    val frameIndex: Int
)

// Helper functions for loading and parsing snapshot
fun loadSnapshot(context: Context): WidgetSnapshot? {
    return try {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val snapshotJson = prefs.getString("flutter.widget_snapshot", null)
        
        if (snapshotJson != null) {
            parseSnapshot(snapshotJson)
        } else {
            null
        }
    } catch (e: Exception) {
        Log.e("WidgetData", "Error loading snapshot", e)
        null
    }
}

fun parseSnapshot(json: String): WidgetSnapshot? {
    return try {
        val obj = JSONObject(json)
        val topGoalObj = obj.optJSONObject("topGoal")
        val topGoal = topGoalObj?.let {
            TopGoal(
                id = it.getString("id"),
                title = it.getString("title"),
                progress = it.getDouble("progress"),
                goalType = it.optString("goalType", "daily"),
                progressType = it.optString("progressType", "completion"),
                nextDueEpoch = if (it.has("nextDueEpoch") && !it.isNull("nextDueEpoch")) it.getLong("nextDueEpoch") else null,
                urgency = it.getDouble("urgency"),
                progressLabel = if (it.has("progressLabel") && !it.isNull("progressLabel")) it.getString("progressLabel") else null
            )
        }

        val mascotObj = obj.getJSONObject("mascot")
        val mascot = MascotState(
            emotion = mascotObj.getString("emotion"),
            frameIndex = mascotObj.getInt("frameIndex")
        )

        WidgetSnapshot(
            version = obj.getInt("version"),
            generatedAt = obj.getLong("generatedAt"),
            topGoal = topGoal,
            mascot = mascot
        )
    } catch (e: Exception) {
        Log.e("WidgetData", "Error parsing snapshot", e)
        null
    }
}
