package com.catalist

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.catalist/widget"

    override fun onResume() {
        super.onResume()
        // Check if this is a snapshot regeneration trigger
        if (intent?.action == "com.catalist.REGENERATE_SNAPSHOT") {
            regenerateSnapshot()
        } else {
            updateWidget()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == "com.catalist.REGENERATE_SNAPSHOT") {
            regenerateSnapshot()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    updateWidget()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun regenerateSnapshot() {
        // Trigger snapshot regeneration via method channel (Flutter side)
        CoroutineScope(Dispatchers.Main).launch {
            try {
                // Wait for Flutter engine to be ready
                kotlinx.coroutines.delay(500)
                
                // Get Flutter engine and call method channel to trigger Dart-side regeneration
                flutterEngine?.let { engine ->
                    MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(
                        "regenerateSnapshot",
                        null
                    )
                }
                
                // Update widget after snapshot regenerates
                kotlinx.coroutines.delay(1500)
                updateWidget()
            } catch (e: Exception) {
                Log.e("MainActivity", "Error regenerating snapshot", e)
                // Fallback: just update widget
                updateWidget()
            }
        }
    }

    private fun updateWidget() {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(this)
            val widgetProvider = ComponentName(this, CatalistWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(widgetProvider)
            
            if (widgetIds.isEmpty()) return
            
            CoroutineScope(Dispatchers.Main).launch {
                try {
                    // Wait for SharedPreferences to flush
                    kotlinx.coroutines.delay(300)
                    
                    // Update each widget
                    widgetIds.forEach { widgetId ->
                        try {
                            CatalistWidgetProvider.updateAppWidget(
                                this@MainActivity,
                                appWidgetManager,
                                widgetId
                            )
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Error updating widget $widgetId", e)
                        }
                    }
                    
                    // Send broadcast as backup
                    val intent = android.content.Intent(this@MainActivity, CatalistWidgetProvider::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
                    }
                    sendBroadcast(intent)
                } catch (e: Exception) {
                    Log.e("MainActivity", "Error updating widget", e)
                }
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error updating widget", e)
        }
    }
}
