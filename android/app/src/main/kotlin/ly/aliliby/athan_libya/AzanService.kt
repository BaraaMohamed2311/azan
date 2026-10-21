package ly.aliliby.athan_libya

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.VolumeProvider
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import java.io.File

/**
 * Plays the azan (res/raw/azan.mp3) from a foreground service and shows a
 * heads-up notification with a "stop" action.
 *
 * Playback stops when:
 *  - the notification's stop button is pressed,
 *  - the notification is swiped away,
 *  - a hardware volume button is pressed (MediaSession volume handler, with a
 *    VOLUME_CHANGED_ACTION broadcast as a fallback for odd OEM builds),
 *  - the audio finishes.
 *
 * It is started by AzanAlarmReceiver, so the app does not have to be open.
 */
class AzanService : Service() {

    companion object {
        const val ACTION_PLAY = "ly.aliliby.athan_libya.action.PLAY"
        const val ACTION_STOP = "ly.aliliby.athan_libya.action.STOP"
        private const val CHANNEL_PLAY = "azan_playback_v1"
        private const val CHANNEL_SILENT = "azan_silent_v1"
        private const val NOTIFICATION_ID = 7001
        private const val SILENT_NOTIFICATION_ID = 7002

        @Volatile
        var instance: AzanService? = null

        fun start(context: Context, title: String, body: String) {
            val intent = Intent(context, AzanService::class.java)
                .setAction(ACTION_PLAY)
                .putExtra("title", title)
                .putExtra("body", body)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop() {
            instance?.stopAzan()
        }

        /** Notification without audio (user chose "silent" mode). */
        fun notifySilent(context: Context, title: String, body: String) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val ch = NotificationChannel(
                    CHANNEL_SILENT, "مواقيت الصلاة بصمت", NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    setSound(null, null)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 250, 180, 250)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
                nm.createNotificationChannel(ch)
            }
            val builder = newBuilder(context, CHANNEL_SILENT, title, body)
            nm.notify(SILENT_NOTIFICATION_ID, builder.build())
        }

        @Suppress("DEPRECATION")
        private fun newBuilder(
            context: Context, channel: String, title: String, body: String
        ): Notification.Builder {
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, channel)
            } else {
                Notification.Builder(context)
                    .setPriority(Notification.PRIORITY_HIGH)
                    .setDefaults(Notification.DEFAULT_VIBRATE)
            }
            val open = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.setSmallIcon(R.drawable.ic_stat_azan)
                .setContentTitle(title)
                .setContentText(body)
                .setContentIntent(open)
                .setAutoCancel(true)
                .setCategory(Notification.CATEGORY_ALARM)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setWhen(System.currentTimeMillis())
                .setShowWhen(true)
            return builder
        }
    }

    private var player: MediaPlayer? = null
    private var focusRequest: AudioFocusRequest? = null
    private var volumeReceiverRegistered = false
    private var startedAt = 0L
    private var wakeLock: PowerManager.WakeLock? = null
    private var session: MediaSession? = null

    private val volumeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (SystemClock.elapsedRealtime() - startedAt < 1500) return
            stopAzan()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopAzan()
            return START_NOT_STICKY
        }
        val title = intent?.getStringExtra("title") ?: "حان وقت الصلاة"
        val body = intent?.getStringExtra("body") ?: "أذان ليبيا — حيّ على الصلاة"

        instance = this
        val notification = buildPlayNotification(title, body)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        startPlayback()
        return START_NOT_STICKY
    }

    private fun buildPlayNotification(title: String, body: String): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_PLAY, "الأذان", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "تشغيل صوت الأذان عند دخول وقت الصلاة"
                setSound(null, null) // audio is played by this service, not the system
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 180, 250)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(ch)
        }

        val stopIntent = Intent(this, AzanService::class.java).setAction(ACTION_STOP)
        val stopPi = PendingIntent.getService(
            this, 1, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = newBuilder(this, CHANNEL_PLAY, title, body)
            .setOngoing(true)
            .setAutoCancel(false)
            .setDeleteIntent(stopPi)
        @Suppress("DEPRECATION")
        builder.addAction(android.R.drawable.ic_media_pause, "إيقاف الأذان", stopPi)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    /** Copies res/raw/azan.mp3 to the cache dir so MediaPlayer can open it by path. */
    private fun azanFile(): File? {
        return try {
            val file = File(cacheDir, "azan.mp3")
            resources.openRawResource(R.raw.azan).use { input ->
                file.outputStream().use { output -> input.copyTo(output) }
            }
            file
        } catch (_: Exception) {
            null
        }
    }

    private fun startPlayback() {
        releasePlayer()
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()

        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                .setAudioAttributes(attrs)
                .setOnAudioFocusChangeListener { }
                .build()
            am.requestAudioFocus(focusRequest!!)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
        }

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "athan_libya:azan").apply {
            setReferenceCounted(false)
            acquire(10 * 60 * 1000L)
        }

        try {
            val mp = MediaPlayer()
            mp.setAudioAttributes(attrs)
            val file = azanFile()
            if (file != null) {
                mp.setDataSource(file.absolutePath)
            } else {
                mp.setDataSource(this, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
            }
            mp.setOnCompletionListener { stopAzan() }
            mp.setOnErrorListener { _, _, _ -> stopAzan(); true }
            mp.prepare()
            mp.start()
            player = mp
        } catch (_: Exception) {
            stopAzan()
            return
        }

        startedAt = SystemClock.elapsedRealtime()
        startSession()
        registerVolumeReceiver()
    }

    /**
     * A MediaSession with a remote VolumeProvider receives hardware volume key
     * presses (even with the screen off / app closed) instead of the system
     * changing the volume — we use that as the "press a volume button to stop" hook.
     */
    private fun startSession() {
        try {
            session?.release()
            val s = MediaSession(this, "AzanSession")
            s.setCallback(object : MediaSession.Callback() {
                override fun onStop() = stopAzan()
                override fun onPause() = stopAzan()
            })
            s.setPlaybackState(
                PlaybackState.Builder()
                    .setActions(PlaybackState.ACTION_STOP or PlaybackState.ACTION_PAUSE)
                    .setState(PlaybackState.STATE_PLAYING, 0L, 1f)
                    .build()
            )
            val provider = object : VolumeProvider(VolumeProvider.VOLUME_CONTROL_RELATIVE, 100, 50) {
                override fun onAdjustVolume(direction: Int) {
                    if (SystemClock.elapsedRealtime() - startedAt < 1500) return
                    stopAzan()
                }
            }
            s.setPlaybackToRemote(provider)
            s.isActive = true
            session = s
        } catch (_: Exception) {
            session = null
        }
    }

    private fun registerVolumeReceiver() {
        if (volumeReceiverRegistered) return
        val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(volumeReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(volumeReceiver, filter)
            }
            volumeReceiverRegistered = true
        } catch (_: Exception) {
        }
    }

    private fun releasePlayer() {
        try {
            player?.stop()
        } catch (_: Exception) {
        }
        player?.release()
        player = null
    }

    private fun releaseSession() {
        try {
            session?.isActive = false
            session?.release()
        } catch (_: Exception) {
        }
        session = null
    }

    fun stopAzan() {
        releasePlayer()
        releaseSession()
        if (volumeReceiverRegistered) {
            try {
                unregisterReceiver(volumeReceiver)
            } catch (_: Exception) {
            }
            volumeReceiverRegistered = false
        }
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { am.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(null)
        }
        focusRequest = null
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {
        }
        wakeLock = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        instance = null
        stopSelf()
    }

    override fun onDestroy() {
        releasePlayer()
        releaseSession()
        if (volumeReceiverRegistered) {
            try {
                unregisterReceiver(volumeReceiver)
            } catch (_: Exception) {
            }
            volumeReceiverRegistered = false
        }
        instance = null
        super.onDestroy()
    }
}
