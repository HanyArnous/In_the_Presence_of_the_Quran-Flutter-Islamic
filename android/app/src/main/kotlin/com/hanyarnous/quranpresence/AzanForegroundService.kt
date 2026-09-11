package com.hanyarnous.quranpresence

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

// ✅ خدمة أمامية لتشغيل الأذان كاملاً على مسار المنبه حتى لو التطبيق مغلق
class AzanForegroundService : Service() {

    companion object {
        const val TAG = "AzanService"
        const val CHANNEL_ID = "azan_playback"
        const val NOTIF_ID = 1001
        const val ACTION_START = "com.hanyarnous.quranpresence.START_AZAN"
        const val ACTION_STOP = "com.hanyarnous.quranpresence.STOP_AZAN"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_PRAYER_EN = "prayer_en"
    }

    private var mediaPlayer: android.media.MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_STOP) {
            Log.d(TAG, "Stop action received")
            stopPlayback()
            stopSelf()
            return START_NOT_STICKY
        }

        val prayerName = intent?.getStringExtra(EXTRA_PRAYER_NAME) ?: "الصلاة"
        val prayerEn = intent?.getStringExtra(EXTRA_PRAYER_EN) ?: ""

        // احفظ الأذان الحالي كـ pending حتى تفتحه واجهة Flutter عند الضغط
        savePendingAzan(prayerName, prayerEn)

        startForeground(NOTIF_ID, buildNotification(prayerName))
        startPlayback()

        // لو النظام قتل الخدمة لا تعيد التشغيل تلقائياً (تجنب أذان مكرر)
        return START_NOT_STICKY
    }

    private fun startPlayback() {
        try {
            stopPlayerOnly()
            // WakeLock جزئي حتى لا يتوقف الصوت مع نوم المعالج
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "QuranPresence:AzanWakeLock").apply {
                acquire(10 * 60 * 1000L) // 10 دقائق حد أقصى
            }

            mediaPlayer = android.media.MediaPlayer().apply {
                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
                setAudioAttributes(attrs)
                setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                // ملف الأذان الكامل من res/raw
                val afd = resources.openRawResourceFd(R.raw.azan)
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                isLooping = false
                setOnCompletionListener {
                    Log.d(TAG, "Azan completed - stopping service")
                    stopPlayback()
                    stopSelf()
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error what=$what extra=$extra")
                    stopPlayback()
                    stopSelf()
                    true
                }
                prepare()
                start()
            }
            Log.d(TAG, "Azan playback started (full file)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start azan playback: ${e.message}", e)
            stopPlayback()
            stopSelf()
        }
    }

    private fun stopPlayerOnly() {
        try { mediaPlayer?.stop() } catch (_: Exception) {}
        try { mediaPlayer?.release() } catch (_: Exception) {}
        mediaPlayer = null
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {}
        wakeLock = null
    }

    private fun stopPlayback() {
        stopPlayerOnly()
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NOTIF_ID)
        } catch (_: Exception) {}
        clearPendingAzan()
    }

    override fun onDestroy() {
        stopPlayerOnly()
        super.onDestroy()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                    val ch = NotificationChannel(
                        CHANNEL_ID,
                        "تشغيل الأذان",
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "قناة تشغيل صوت الأذان كاملاً"
                        // الصوت عبر MediaPlayer وليس صوت الإشعار حتى يكتمل الملف
                        setSound(null, null)
                        enableVibration(true)
                    }
                    nm.createNotificationChannel(ch)
                }
            } catch (e: Exception) {
                Log.e(TAG, "createChannel failed: ${e.message}")
            }
        }
    }

    private fun buildNotification(prayerName: String): Notification {
        val stopIntent = Intent(this, AzanForegroundService::class.java).apply { action = ACTION_STOP }
        val stopFlags = PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        val stopPi = PendingIntent.getService(this, 2001, stopIntent, stopFlags)

        // الضغط على الإشعار يفتح التطبيق على شاشة الأذان
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            putExtra("show_azan", true)
            putExtra(EXTRA_PRAYER_NAME, prayerName)
        }
        val openFlags = PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        val openPi = openIntent?.let { PendingIntent.getActivity(this, 2002, it, openFlags) }

        val builder: Notification.Builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder.setContentTitle("حان وقت $prayerName")
            .setContentText("جاري تشغيل الأذان كاملاً - اضغط إيقاف لإسكاته")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(openPi)
            .addAction(android.R.drawable.ic_media_pause, "إيقاف", stopPi)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setTimeoutAfter(10 * 60 * 1000L) // أمان: إخفاء بعد 10 دقائق
        } else {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_MAX)
        }
        return builder.build()
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
    }

    private fun savePendingAzan(prayerName: String, prayerEn: String) {
        try {
            getSharedPreferences("azan_prefs", Context.MODE_PRIVATE).edit()
                .putString("pending_azan_name", prayerName)
                .putString("pending_azan_en", prayerEn)
                .putLong("pending_azan_at", System.currentTimeMillis())
                .apply()
        } catch (_: Exception) {}
    }

    private fun clearPendingAzan() {
        try {
            getSharedPreferences("azan_prefs", Context.MODE_PRIVATE).edit()
                .remove("pending_azan_name")
                .remove("pending_azan_en")
                .remove("pending_azan_at")
                .apply()
        } catch (_: Exception) {}
    }
}
