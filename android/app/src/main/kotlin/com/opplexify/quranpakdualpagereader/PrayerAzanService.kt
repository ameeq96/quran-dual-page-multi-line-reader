package com.opplexify.quranpakdualpagereader

import android.app.Notification
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
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import org.json.JSONObject

class PrayerAzanService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var focusRequest: AudioFocusRequest? = null
    private var currentId: String? = null
    private var closing = false
    private var noisyRegistered = false
    private val prepareTimeout = Runnable { finishPlayback() }
    private val playbackTimeout = Runnable { finishPlayback() }
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change < 0) finishPlayback()
    }
    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) finishPlayback()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            finishPlayback()
            return START_NOT_STICKY
        }
        if (intent?.action != ACTION_PLAY) {
            stopSelf()
            return START_NOT_STICKY
        }
        val event = try {
            PrayerEvent.parse(JSONObject(intent.getStringExtra("event") ?: ""))
        } catch (_: Exception) {
            stopSelf()
            return START_NOT_STICKY
        }
        val preview = intent.getBooleanExtra("preview", false)
        if ((!preview && !PrayerAlarmScheduler.isCurrent(this, intent.getLongExtra("generation", -1L))) ||
            !PrayerAlarmScheduler.notificationsAllowed(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (currentId == event.id && player != null) return START_NOT_STICKY
        return try {
            playEvent(event, intent)
        } catch (error: Exception) {
            PrayerAlarmScheduler.runtimeError(this, error.message ?: "Azan playback could not start.")
            PrayerAlarmScheduler.showReminder(this, event, forceSilent = true)
            finishPlayback()
            START_NOT_STICKY
        }
    }

    private fun playEvent(event: PrayerEvent, intent: Intent): Int {
        releaseAudio()
        closing = false
        currentId = event.id
        PrayerAlarmScheduler.createChannels(this)
        val notification = playbackNotification(event, intent.getStringExtra("language") ?: "en")
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(
                PrayerAlarmScheduler.AZAN_NOTIFICATION_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else startForeground(PrayerAlarmScheduler.AZAN_NOTIFICATION_ID, notification)
        val volume = intent.getFloatExtra("volume", 1f).coerceIn(0f, 1f)
        val respectSilent = intent.getBooleanExtra("respectSilent", true)
        val audio = getSystemService(AudioManager::class.java)
        val interruption = getSystemService(NotificationManager::class.java).currentInterruptionFilter
        if (volume <= 0f || respectSilent &&
            (audio.ringerMode != AudioManager.RINGER_MODE_NORMAL ||
                interruption == NotificationManager.INTERRUPTION_FILTER_NONE ||
                interruption == NotificationManager.INTERRUPTION_FILTER_PRIORITY)) {
            PrayerAlarmScheduler.showReminder(this, event, forceSilent = true)
            finishPlayback()
            return START_NOT_STICKY
        }
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
        @Suppress("DEPRECATION")
        val focused = if (Build.VERSION.SDK_INT >= 26) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes).setWillPauseWhenDucked(true)
                .setOnAudioFocusChangeListener(focusListener, handler).build()
            focusRequest = request
            audio.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            audio.requestAudioFocus(
                focusListener, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
        if (!focused) {
            PrayerAlarmScheduler.showReminder(this, event, forceSilent = true)
            finishPlayback()
            return START_NOT_STICKY
        }
        try {
            val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
            if (Build.VERSION.SDK_INT >= 33) registerReceiver(noisyReceiver, filter, RECEIVER_NOT_EXPORTED)
            else registerReceiver(noisyReceiver, filter)
            noisyRegistered = true
            player = MediaPlayer().apply {
                setAudioAttributes(attributes)
                setWakeMode(this@PrayerAzanService, PowerManager.PARTIAL_WAKE_LOCK)
                setDataSource(PrayerAlarmScheduler.audioFile(this@PrayerAzanService, event.audioKey).absolutePath)
                setVolume(volume, volume)
                setOnPreparedListener {
                    handler.removeCallbacks(prepareTimeout)
                    playing = true
                    playingEventId = event.id
                    it.start()
                    handler.postDelayed(playbackTimeout, 600000L)
                }
                setOnCompletionListener { finishPlayback() }
                setOnErrorListener { _, _, _ ->
                    PrayerAlarmScheduler.runtimeError(this@PrayerAzanService, "Azan playback failed. Try the audio preview.")
                    finishPlayback()
                    true
                }
                prepareAsync()
            }
            handler.postDelayed(prepareTimeout, 30000L)
        } catch (error: Exception) {
            PrayerAlarmScheduler.runtimeError(this, error.message ?: "Azan playback could not start.")
            finishPlayback()
        }
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun playbackNotification(event: PrayerEvent, language: String): Notification {
        val stop = PendingIntent.getService(
            this, 918316,
            Intent(this, PrayerAzanService::class.java).setAction(ACTION_STOP)
                .setData(Uri.parse("quran-prayer://stop")),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, PrayerAlarmScheduler.CHANNEL_AZAN)
        } else Notification.Builder(this)
        val stopLabel = when (language) { "ur" -> "بند کریں"; "ar" -> "إيقاف"; else -> "Stop" }
        return builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(event.title).setContentText(event.body)
            .setContentIntent(PrayerAlarmScheduler.openApp(this)).setOngoing(true)
            .setCategory(Notification.CATEGORY_ALARM).setOnlyAlertOnce(true)
            .addAction(Notification.Action.Builder(null, stopLabel, stop).build()).build()
    }

    private fun finishPlayback() {
        if (closing) return
        closing = true
        releaseAudio()
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE)
        else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun releaseAudio() {
        handler.removeCallbacks(prepareTimeout)
        handler.removeCallbacks(playbackTimeout)
        player?.release()
        player = null
        playing = false
        playingEventId = null
        if (noisyRegistered) {
            unregisterReceiver(noisyReceiver)
            noisyRegistered = false
        }
        val audio = getSystemService(AudioManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) focusRequest?.let { audio.abandonAudioFocusRequest(it) }
        else {
            @Suppress("DEPRECATION")
            audio.abandonAudioFocus(focusListener)
        }
        focusRequest = null
        currentId = null
    }

    override fun onDestroy() {
        releaseAudio()
        super.onDestroy()
    }

    companion object {
        private const val ACTION_PLAY = "com.opplexify.quran.PLAY_AZAN"
        private const val ACTION_STOP = "com.opplexify.quran.STOP_AZAN"
        @Volatile var playing = false
            private set
        @Volatile var playingEventId: String? = null
            private set

        internal fun start(
            context: Context, event: PrayerEvent, volume: Float, respectSilent: Boolean,
            language: String, generation: Long, preview: Boolean = false
        ) {
            if (!PrayerAlarmScheduler.notificationsAllowed(context)) return
            PrayerAlarmScheduler.createChannels(context)
            if (Build.VERSION.SDK_INT >= 26 &&
                context.getSystemService(NotificationManager::class.java)
                    .getNotificationChannel(PrayerAlarmScheduler.CHANNEL_AZAN)?.importance == NotificationManager.IMPORTANCE_NONE) {
                PrayerAlarmScheduler.runtimeError(context, "The Azan notification channel is blocked in device settings.")
                return
            }
            val intent = Intent(context, PrayerAzanService::class.java).setAction(ACTION_PLAY)
                .putExtra("event", event.json().toString()).putExtra("generation", generation)
                .putExtra("volume", volume).putExtra("respectSilent", respectSilent)
                .putExtra("language", language).putExtra("preview", preview)
            try {
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent)
                else context.startService(intent)
            } catch (error: Exception) {
                PrayerAlarmScheduler.runtimeError(context, "Android prevented Azan playback. Check alarm and battery settings.")
                PrayerAlarmScheduler.showReminder(context, event, forceSilent = true)
            }
        }
    }
}
