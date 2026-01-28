package com.catalist

import android.content.Context
import android.util.Log
import org.json.JSONObject

// Data classes for widget snapshot
data class WidgetSnapshot(
    val version: Int,
    val generatedAt: Long,
    val topGoal: TopGoal?,
    val mascot: MascotState,
    val cta: String? = null,
    val backgroundStatus: String? = null,   // celebrate, on_track, behind, urgent, empty
    val backgroundTimeBand: String? = null, // dawn, day, dusk, night
    val backgroundVariant: Int? = null     // 1, 2, or 3
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
    val frameIndex: Int,
    val expiresAt: Long? = null  // epoch ms; when set, celebrate is valid until this time
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
            frameIndex = mascotObj.optInt("frameIndex", 0),
            expiresAt = if (mascotObj.has("expiresAt") && !mascotObj.isNull("expiresAt")) mascotObj.getLong("expiresAt") else null
        )

        WidgetSnapshot(
            version = obj.getInt("version"),
            generatedAt = obj.getLong("generatedAt"),
            topGoal = topGoal,
            mascot = mascot,
            cta = if (obj.has("cta") && !obj.isNull("cta")) obj.getString("cta") else null,
            backgroundStatus = if (obj.has("backgroundStatus") && !obj.isNull("backgroundStatus")) obj.getString("backgroundStatus") else null,
            backgroundTimeBand = if (obj.has("backgroundTimeBand") && !obj.isNull("backgroundTimeBand")) obj.getString("backgroundTimeBand") else null,
            backgroundVariant = if (obj.has("backgroundVariant") && !obj.isNull("backgroundVariant")) obj.getInt("backgroundVariant") else null
        )
    } catch (e: Exception) {
        Log.e("WidgetData", "Error parsing snapshot", e)
        null
    }
}
