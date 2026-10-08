package com.example.hobby_hubv2

import android.app.usage.UsageStatsManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hobbyhub/usage")
            .setMethodCallHandler { call, result ->
                if (call.method == "usage") {
                    try {
                        val days = call.argument<Int>("days") ?: 7
                        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                        val end = System.currentTimeMillis()
                        val start = end - days * 24L * 60L * 60L * 1000L
                        val stats = usm.queryAndAggregateUsageStats(start, end)
                        val pm = packageManager
                        val out = ArrayList<Map<String, Any>>()
                        for ((pkg, s) in stats) {
                            if (s.totalTimeInForeground <= 0L) continue
                            val name = try {
                                pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
                            } catch (e: Exception) {
                                pkg
                            }
                            out.add(mapOf("pkg" to pkg, "name" to name, "ms" to s.totalTimeInForeground))
                        }
                        result.success(out)
                    } catch (e: Exception) {
                        result.success(ArrayList<Map<String, Any>>())
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}