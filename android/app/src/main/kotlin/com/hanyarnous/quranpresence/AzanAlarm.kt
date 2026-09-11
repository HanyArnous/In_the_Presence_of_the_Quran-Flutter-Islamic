package com.hanyarnous.quranpresence

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

// ✅ يستقبل منبه الأذان المضبوط عبر AlarmManager ويشغّل الخدمة الأمامية فوراً
class AzanAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "AzanAlarmReceiver"
        const val ACTION_AZAN_ALARM = "com.hanyarnous.quranpresence.AZAN_ALARM"
        const val EXTRA_ALARM_ID = "alarm_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        try {
            if (intent.action != null && intent.action != ACTION_AZAN_ALARM) return
            val prayerName = intent.getStringExtra(AzanForegroundService.EXTRA_PRAYER_NAME) ?: "الصلاة"
            val prayerEn = intent.getStringExtra(AzanForegroundService.EXTRA_PRAYER_EN) ?: ""
            Log.d(TAG, "Alarm fired for $prayerName ($prayerEn)")

            val serviceIntent = Intent(context, AzanForegroundService::class.java).apply {
                action = AzanForegroundService.ACTION_START
                putExtra(AzanForegroundService.EXTRA_PRAYER_NAME, prayerName)
                putExtra(AzanForegroundService.EXTRA_PRAYER_EN, prayerEn)
            }
            // بدء خدمة أمامية يعمل حتى لو التطبيق مقتول
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "onReceive failed: ${e.message}", e)
        }
    }
}

// ✅ إعادة جدولة منبهات الأذان بعد إعادة التشغيل (تُجدول من Flutter عند أول فتح)
class AzanBootReceiver : BroadcastReceiver() {
    companion object { const val TAG = "AzanBootReceiver" }
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val a = intent.action
            if (a == Intent.ACTION_BOOT_COMPLETED ||
                a == Intent.ACTION_MY_PACKAGE_REPLACED ||
                a == "android.intent.action.QUICKBOOT_POWERON"
            ) {
                // علّم أن الجهاز أعاد التشغيل؛ سيعيد Flutter الجدولة عند الفتح.
                // (منبهات flutter_local_notifications المجدولة تُستعاد تلقائياً عبر مستقبلها الخاص)
                Log.d(TAG, "Boot completed - awaiting Flutter reschedule")
                context.getSharedPreferences("azan_prefs", Context.MODE_PRIVATE).edit()
                    .putBoolean("needs_reschedule", true)
                    .apply()
            }
        } catch (e: Exception) {
            Log.e(TAG, "boot receiver failed: ${e.message}")
        }
    }
}

// ✅ أدوات مساعدة لضبط/إلغاء المنبهات الدقيقة من MainActivity
object AzanScheduler {
    private const val PREFS = "azan_prefs"
    private const val KEY_IDS = "scheduled_ids"

    fun schedule(context: Context, id: Int, timeMillis: Long, prayerName: String, prayerEn: String): Boolean {
        return try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AzanAlarmReceiver::class.java).apply {
                action = AzanAlarmReceiver.ACTION_AZAN_ALARM
                putExtra(AzanAlarmReceiver.EXTRA_ALARM_ID, id)
                putExtra(AzanForegroundService.EXTRA_PRAYER_NAME, prayerName)
                putExtra(AzanForegroundService.EXTRA_PRAYER_EN, prayerEn)
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            val pi = PendingIntent.getBroadcast(context, id, intent, flags)

            // لو الوقت فات تخطَّ
            if (timeMillis <= System.currentTimeMillis()) return false

            val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                am.canScheduleExactAlarms()
            } else true

            if (canExact) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMillis, pi)
            } else {
                // fallback عند غياب إذن المنبه الدقيق
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMillis, pi)
            }
            rememberId(context, id)
            true
        } catch (e: Exception) {
            Log.e("AzanScheduler", "schedule $id failed: ${e.message}")
            false
        }
    }

    fun cancel(context: Context, id: Int) {
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AzanAlarmReceiver::class.java).apply {
                action = AzanAlarmReceiver.ACTION_AZAN_ALARM
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            val pi = PendingIntent.getBroadcast(context, id, intent, flags)
            am.cancel(pi)
            pi.cancel()
            forgetId(context, id)
        } catch (e: Exception) {
            Log.e("AzanScheduler", "cancel $id failed: ${e.message}")
        }
    }

    fun cancelAll(context: Context) {
        try {
            for (id in getIds(context)) cancel(context, id)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_IDS, "").apply()
        } catch (e: Exception) {
            Log.e("AzanScheduler", "cancelAll failed: ${e.message}")
        }
    }

    private fun rememberId(context: Context, id: Int) {
        try {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val current = prefs.getString(KEY_IDS, "") ?: ""
            val set = current.split(",").filter { it.isNotBlank() }.toMutableSet()
            set.add(id.toString())
            prefs.edit().putString(KEY_IDS, set.joinToString(",")).apply()
        } catch (_: Exception) {}
    }

    private fun forgetId(context: Context, id: Int) {
        try {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val current = prefs.getString(KEY_IDS, "") ?: ""
            val set = current.split(",").filter { it.isNotBlank() && it != id.toString() }.toSet()
            prefs.edit().putString(KEY_IDS, set.joinToString(",")).apply()
        } catch (_: Exception) {}
    }

    private fun getIds(context: Context): List<Int> {
        return try {
            val current = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_IDS, "") ?: ""
            current.split(",").mapNotNull { it.toIntOrNull() }
        } catch (_: Exception) { emptyList() }
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
    }
}
