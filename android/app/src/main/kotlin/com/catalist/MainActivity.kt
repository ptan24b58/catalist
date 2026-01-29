package com.catalist

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.catalist/widget"

    override fun onResume() {
        super.onResume()
        // Always update widget on resume — native snapshot generator handles freshness
        updateWidget()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
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

                    // Update each widget (native snapshot generation happens inside if needed)
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
                    val intent = Intent(this@MainActivity, CatalistWidgetProvider::class.java).apply {
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
