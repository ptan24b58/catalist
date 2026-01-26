package com.catalist

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
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

    private fun updateWidget() {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(this)
            val widgetProvider = ComponentName(this, TraditionalWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(widgetProvider)
            
            if (widgetIds.isNotEmpty()) {
                Log.d("MainActivity", "Triggering widget update for ${widgetIds.size} widget(s)")
                
                // Wait a bit to ensure SharedPreferences is flushed
                CoroutineScope(Dispatchers.Main).launch {
                    try {
                        Log.d("MainActivity", "🔄 Updating traditional widget...")
                        // Wait to ensure SharedPreferences is flushed to disk
                        kotlinx.coroutines.delay(300)
                        
                        // Update each widget directly - this always works with traditional widgets
                        widgetIds.forEach { widgetId ->
                            try {
                                TraditionalWidgetProvider.updateAppWidget(
                                    this@MainActivity,
                                    appWidgetManager,
                                    widgetId
                                )
                                Log.d("MainActivity", "✅ Widget $widgetId updated")
                            } catch (e: Exception) {
                                Log.e("MainActivity", "❌ Error updating widget $widgetId", e)
                            }
                        }
                        
                        // Also send broadcast as backup
                        val intent = android.content.Intent(this@MainActivity, TraditionalWidgetProvider::class.java).apply {
                            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
                        }
                        sendBroadcast(intent)
                        Log.d("MainActivity", "📡 Sent broadcast intent")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "❌ Error updating widget", e)
                    }
                }
            } else {
                Log.d("MainActivity", "No widgets to update")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error updating widget", e)
        }
    }
}
