package com.goalwidget

import android.content.Context
import android.content.Intent
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import org.json.JSONObject
import java.io.File

class LogGoalAction : ActionCallback {
    companion object {
        val goalIdKey = ActionParameters.Key<String>("goalId")
    }

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val goalId = parameters[goalIdKey] ?: return

        // Write action to shared storage for Flutter app to process
        try {
            val actionData = JSONObject().apply {
                put("action", "log_progress")
                put("goalId", goalId)
                put("timestamp", System.currentTimeMillis() / 1000)
            }

            val file = File(context.filesDir, "widget_action.json")
            file.writeText(actionData.toString())

            // Open app to process action
            val intent = Intent(context, Class.forName("com.goalwidget.MainActivity")).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("action", "log_progress")
                putExtra("goalId", goalId)
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
