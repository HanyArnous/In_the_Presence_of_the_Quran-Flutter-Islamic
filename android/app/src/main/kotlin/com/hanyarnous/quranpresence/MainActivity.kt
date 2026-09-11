package com.hanyarnous.quranpresence

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ✅ هذه الـ Activity يجب أن ترث من AudioServiceActivity عند استخدام just_audio_background/audio_service
//   حتى يتمكن الـ plugin من الحصول على FlutterEngine الصحيح للتحكم في مشغّل الصوت بالخلفية.
class MainActivity : AudioServiceActivity() {

    companion object {
        const val AZAN_CHANNEL = "com.hanyarnous.quranpresence/azan"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AZAN_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "scheduleAzan" -> {
                        @Suppress("UNCHECKED_CAST")
                        val items = call.argument<List<Map<String, Any>>>("items") ?: emptyList()
                        var ok = 0
                        for (item in items) {
                            try {
                                val id = (item["id"] as? Number)?.toInt() ?: continue
                                val timeMillis = (item["timeMillis"] as? Number)?.toLong() ?: continue
                                val prayerName = item["prayerName"] as? String ?: "الصلاة"
                                val prayerEn = item["prayerEn"] as? String ?: ""
                                if (AzanScheduler.schedule(this, id, timeMillis, prayerName, prayerEn)) ok++
                            } catch (e: Exception) {
                                Log.e("AzanChannel", "item failed: ${e.message}")
                            }
                        }
                        result.success(ok)
                    }
                    "cancelAzan" -> {
                        @Suppress("UNCHECKED_CAST")
                        val ids = call.argument<List<Int>>("ids")
                        if (ids != null) {
                            for (id in ids) AzanScheduler.cancel(this, id)
                        } else {
                            AzanScheduler.cancelAll(this)
                        }
                        result.success(true)
                    }
                    "playAzan" -> {
                        val prayerName = call.argument<String>("prayerName") ?: "الصلاة"
                        val prayerEn = call.argument<String>("prayerEn") ?: ""
                        val i = Intent(this, AzanForegroundService::class.java).apply {
                            action = AzanForegroundService.ACTION_START
                            putExtra(AzanForegroundService.EXTRA_PRAYER_NAME, prayerName)
                            putExtra(AzanForegroundService.EXTRA_PRAYER_EN, prayerEn)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(i)
                        } else {
                            startService(i)
                        }
                        result.success(true)
                    }
                    "stopAzan" -> {
                        val i = Intent(this, AzanForegroundService::class.java).apply {
                            action = AzanForegroundService.ACTION_STOP
                        }
                        startService(i)
                        result.success(true)
                    }
                    "getPendingAzan" -> {
                        try {
                            val prefs = getSharedPreferences("azan_prefs", Context.MODE_PRIVATE)
                            val name = prefs.getString("pending_azan_name", null)
                            val en = prefs.getString("pending_azan_en", null)
                            val at = prefs.getLong("pending_azan_at", 0L)
                            // اعتبر الـ pending صالحاً لمدة 10 دقائق فقط
                            val fresh = name != null && (System.currentTimeMillis() - at) < 10 * 60 * 1000L
                            if (fresh) {
                                result.success(mapOf("prayerName" to name, "prayerEn" to (en ?: "")))
                            } else {
                                result.success(null)
                            }
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                    "clearPendingAzan" -> {
                        try {
                            getSharedPreferences("azan_prefs", Context.MODE_PRIVATE).edit()
                                .remove("pending_azan_name")
                                .remove("pending_azan_en")
                                .remove("pending_azan_at")
                                .apply()
                        } catch (_: Exception) {}
                        result.success(true)
                    }
                    "needsReschedule" -> {
                        val v = getSharedPreferences("azan_prefs", Context.MODE_PRIVATE)
                            .getBoolean("needs_reschedule", false)
                        getSharedPreferences("azan_prefs", Context.MODE_PRIVATE).edit()
                            .putBoolean("needs_reschedule", false).apply()
                        result.success(v)
                    }
                    "canScheduleExact" -> {
                        try {
                            val am = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                            val v = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                am.canScheduleExactAlarms()
                            } else true
                            result.success(v)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "openExactAlarmSettings" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                val i = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                                i.data = android.net.Uri.parse("package:$packageName")
                                startActivity(i)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("AZAN_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e("AzanChannel", "${call.method} failed: ${e.message}", e)
                result.error("AZAN_ERROR", e.message, null)
            }
        }
    }
}
