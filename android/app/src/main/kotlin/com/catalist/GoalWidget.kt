package com.catalist

import android.content.Context
import android.util.Log
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.layout.*
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.layout.ContentScale
import org.json.JSONObject

// Duolingo-inspired color palette
object EmotionColors {
    val happy = Color(0xFF58CC02)      // Green
    val neutral = Color(0xFF1CB0F6)    // Blue
    val worried = Color(0xFFFF9600)    // Orange
    val sad = Color(0xFFFF4B4B)        // Red
    val celebrate = Color(0xFFFFD700)  // Gold

    fun fromEmotion(emotion: String): Color {
        return when (emotion) {
            "happy" -> happy
            "neutral" -> neutral
            "worried" -> worried
            "sad" -> sad
            "celebrate" -> celebrate
            else -> neutral
        }
    }

    fun backgroundFromEmotion(emotion: String): Color {
        val baseColor = fromEmotion(emotion)
        // Create a light tinted background (15% opacity simulation)
        return Color(
            red = baseColor.red * 0.15f + 0.85f,
            green = baseColor.green * 0.15f + 0.85f,
            blue = baseColor.blue * 0.15f + 0.85f,
            alpha = 1f
        )
    }
}

class CatalistWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Single

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        Log.d("CatalistWidget", "provideGlance called")
        provideContent {
            GlanceTheme {
                CatalistWidgetContent(context)
            }
        }
    }
}

@androidx.compose.runtime.Composable
fun CatalistWidgetContent(context: Context) {
    val snapshot = loadSnapshot(context)
    val emotion = snapshot?.mascot?.emotion ?: "neutral"
    val backgroundColor = EmotionColors.backgroundFromEmotion(emotion)
    val accentColor = EmotionColors.fromEmotion(emotion)

    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .cornerRadius(24.dp)
            .background(backgroundColor)
    ) {
        if (snapshot != null && snapshot.topGoal != null) {
            val goal = snapshot.topGoal!!

            Box(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .clickable(
                        onClick = actionRunCallback<LogGoalAction>(
                            parameters = actionParametersOf(LogGoalAction.goalIdKey to goal.id)
                        )
                    )
            ) {
                // Cat image - fills the widget
                Column(
                    modifier = GlanceModifier.fillMaxSize(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Spacer(modifier = GlanceModifier.height(36.dp))

                    Image(
                        provider = ImageProvider(R.drawable.cat),
                        contentDescription = "Cat mascot",
                        modifier = GlanceModifier.fillMaxSize(),
                        contentScale = ContentScale.Fit
                    )
                }

                // Progress label at top
                Column(
                    modifier = GlanceModifier.fillMaxWidth().padding(12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Box(
                        modifier = GlanceModifier
                            .cornerRadius(8.dp)
                            .background(Color.White.copy(alpha = 0.9f))
                            .padding(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = goal.progressLabel ?: "${(goal.progress * 100).toInt()}%",
                            style = TextStyle(
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Medium,
                                color = ColorProvider(accentColor)
                            )
                        )
                    }
                }
            }
        } else {
            // No goals state - consistent with goal state layout
            Box(modifier = GlanceModifier.fillMaxSize()) {
                // Cat image - fills the widget (same as goal state)
                Column(
                    modifier = GlanceModifier.fillMaxSize(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Spacer(modifier = GlanceModifier.height(36.dp))

                    Image(
                        provider = ImageProvider(R.drawable.cat),
                        contentDescription = "Cat mascot",
                        modifier = GlanceModifier.fillMaxSize(),
                        contentScale = ContentScale.Fit
                    )
                }

                // Label at top (same pill style as progress label)
                Column(
                    modifier = GlanceModifier.fillMaxWidth().padding(12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Box(
                        modifier = GlanceModifier
                            .cornerRadius(8.dp)
                            .background(Color.White.copy(alpha = 0.9f))
                            .padding(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = "Add a goal!",
                            style = TextStyle(
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Medium,
                                color = ColorProvider(accentColor)
                            )
                        )
                    }
                }
            }
        }
    }
}

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

fun loadSnapshot(context: Context): WidgetSnapshot? {
    return try {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val snapshotJson = prefs.getString("flutter.widget_snapshot", null)
        Log.d("CatalistWidget", "Snapshot JSON: $snapshotJson")
        if (snapshotJson != null) {
            parseSnapshot(snapshotJson)
        } else {
            Log.d("CatalistWidget", "No snapshot found in SharedPreferences")
            null
        }
    } catch (e: Exception) {
        Log.e("CatalistWidget", "Error loading snapshot", e)
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
        Log.e("CatalistWidget", "Error parsing snapshot", e)
        null
    }
}

class CatalistWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = CatalistWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d("CatalistWidget", "Widget enabled")
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: android.appwidget.AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        Log.d("CatalistWidget", "Widget onUpdate called for ${appWidgetIds.size} widgets")
    }
}
