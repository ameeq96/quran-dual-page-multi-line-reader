package com.opplexify.quranpakdualpagereader

import android.Manifest
import android.app.Activity
import android.app.Application
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.media.AudioAttributes
import java.util.Locale
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.TimeZone
import java.util.concurrent.Executors

internal class PrayerPlatformBridge(private val activity: Activity, engine: FlutterEngine) {
    private val channel = MethodChannel(
        engine.dartExecutor.binaryMessenger, "com.opplexify.quran/prayer_reminders"
    )
    private val compass = QiblaCompass(activity, engine)
    private val speech = WorshipNativeSpeech(activity)
    private val worker = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())
    private var notificationResult: MethodChannel.Result? = null
    private var locationResult: MethodChannel.Result? = null
    private var locationListener: LocationListener? = null
    private var locationTimeout: Runnable? = null
    private var awaitingExactPermission = false

    init { channel.setMethodCallHandler(::handle) }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "worshipSpeak" -> speech.speak(call.arguments, result)
            "worshipSpeechStop" -> { speech.stop(); result.success(null) }
            "compassStart" -> {
                try { result.success(compass.start(call.arguments)) }
                catch (error: Exception) { result.error("compass", error.message ?: "Compass is unavailable.", null) }
            }
            "compassStop" -> { compass.stop(); result.success(null) }
            "widgetStatus" -> result.success(PrayerTimesWidgetProvider.status(activity))
            "pinWidget" -> result.success(mapOf("requested" to PrayerTimesWidgetProvider.pin(activity)))
            "status" -> background(result) { PrayerAlarmScheduler.status(activity) }
            "configure" -> background(result) {
                val source = when (val arguments = call.arguments) {
                    is String -> arguments
                    is Map<*, *> -> JSONObject(arguments).toString()
                    else -> throw IllegalArgumentException("Prayer settings are required.")
                }
                PrayerAlarmScheduler.configure(activity, source)
            }
            "cancel" -> background(result) { PrayerAlarmScheduler.cancel(activity) }
            "stop" -> {
                activity.stopService(Intent(activity, PrayerAzanService::class.java))
                result.success(PrayerAlarmScheduler.status(activity))
            }
            "requestExactAlarm" -> {
                try {
                    if (Build.VERSION.SDK_INT >= 31 && !PrayerAlarmScheduler.exactAllowed(activity)) {
                        awaitingExactPermission = true
                        activity.startActivity(Intent(
                            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                            Uri.parse("package:" + activity.packageName)
                        ))
                    }
                    result.success(PrayerAlarmScheduler.status(activity))
                } catch (error: Exception) {
                    result.error("alarm_permission", "Open Alarms and reminders in device settings.", null)
                }
            }
            "requestNotificationPermission" -> {
                if (notificationResult != null) {
                    result.error("busy", "Finish the current notification permission request.", null)
                } else if (Build.VERSION.SDK_INT >= 33 &&
                    activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    notificationResult = result
                    activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION)
                } else background(result) {
                    PrayerAlarmScheduler.restore(activity)
                    PrayerAlarmScheduler.status(activity)
                }
            }
            "location" -> {
                if (locationResult != null) {
                    result.error("busy", "Finish the current location request.", null)
                } else if (!activity.hasWindowFocus()) {
                    result.error("location_foreground", "Open this screen to use your current location.", null)
                } else {
                    locationResult = result
                    if (activity.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                        activity.requestPermissions(arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION), LOCATION_PERMISSION)
                    } else obtainLocation()
                }
            }
            "preview" -> background(result) {
                val arguments = call.arguments as? Map<*, *>
                    ?: throw IllegalArgumentException("Choose an Azan recording.")
                val sound = arguments["sound"] as? String ?: "general"
                require(sound in setOf("general", "fajr")) { "Choose a valid Azan recording." }
                val volume = (arguments["volume"] as? Number)?.toDouble() ?: 1.0
                require(volume.isFinite() && volume in 0.0..1.0) { "Choose a valid Azan volume." }
                val respectSilent = arguments["respectSilent"] as? Boolean ?: true
                val language = (arguments["language"] as? String)?.takeIf { it in setOf("en", "ur", "ar") } ?: "en"
                require(PrayerAlarmScheduler.notificationsAllowed(activity)) {
                    "Allow notifications before testing Azan playback."
                }
                PrayerAlarmScheduler.ensureAudio(activity)
                val title = when (language) {
                    "ur" -> "اذان کی آزمائش"
                    "ar" -> "معاينة الأذان"
                    else -> "Azan preview"
                }
                val event = PrayerEvent(
                    "preview:" + System.currentTimeMillis(), System.currentTimeMillis(),
                    title, title, "adhan", "azan", sound
                )
                PrayerAzanService.start(
                    activity, event, volume.toFloat(), respectSilent, language,
                    PrayerAlarmScheduler.generation(activity), preview = true
                )
                PrayerAlarmScheduler.status(activity)
            }
            else -> result.notImplemented()
        }
    }

    fun onResume() {
        if (!awaitingExactPermission) return
        awaitingExactPermission = false
        worker.execute { PrayerAlarmScheduler.restore(activity) }
    }

    fun onPermissionsResult(requestCode: Int, grantResults: IntArray) {
        when (requestCode) {
            NOTIFICATION_PERMISSION -> {
                val result = notificationResult ?: return
                notificationResult = null
                background(result) {
                    PrayerAlarmScheduler.restore(activity)
                    PrayerAlarmScheduler.status(activity)
                }
            }
            LOCATION_PERMISSION -> {
                if (locationResult == null) return
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    obtainLocation()
                } else finishLocationError("location_permission", "Allow approximate location or choose a city manually.")
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun obtainLocation() {
        val manager = activity.getSystemService(LocationManager::class.java)
        try {
            val providers = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
            val recent = providers.mapNotNull { provider ->
                if (manager.allProviders.contains(provider)) manager.getLastKnownLocation(provider) else null
            }.filter {
                val age = SystemClock.elapsedRealtimeNanos() - it.elapsedRealtimeNanos
                age in 0L..600000000000L
            }.maxByOrNull { it.elapsedRealtimeNanos }
            if (recent != null) {
                finishLocation(recent)
                return
            }
            if (!manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                finishLocationError("location_unavailable", "Turn on location services or choose a city manually.")
                return
            }
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) { finishLocation(location) }
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {
                    finishLocationError("location_unavailable", "Location is unavailable. Choose a city manually.")
                }
                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            }
            locationListener = listener
            val timeout = Runnable {
                finishLocationError("location_timeout", "Location timed out. Try again or choose a city manually.")
            }
            locationTimeout = timeout
            handler.postDelayed(timeout, 12000L)
            manager.requestSingleUpdate(LocationManager.NETWORK_PROVIDER, listener, Looper.getMainLooper())
        } catch (_: Exception) {
            finishLocationError("location_unavailable", "Location is unavailable. Choose a city manually.")
        }
    }

    private fun finishLocation(location: Location) {
        val result = locationResult ?: return
        clearLocation()
        locationResult = null
        if (!location.latitude.isFinite() || !location.longitude.isFinite()) {
            result.error("location_unavailable", "Location is unavailable. Choose a city manually.", null)
            return
        }
        result.success(mapOf(
            "latitude" to location.latitude, "longitude" to location.longitude,
            "accuracyMeters" to location.accuracy.toDouble(),
            "zone" to TimeZone.getDefault().id, "label" to "Current location"
        ))
    }

    private fun finishLocationError(code: String, message: String) {
        val result = locationResult ?: return
        clearLocation()
        locationResult = null
        result.error(code, message, null)
    }

    private fun clearLocation() {
        locationTimeout?.let { handler.removeCallbacks(it) }
        locationTimeout = null
        locationListener?.let {
            try { activity.getSystemService(LocationManager::class.java).removeUpdates(it) } catch (_: Exception) {}
        }
        locationListener = null
    }

    private fun background(result: MethodChannel.Result, action: () -> Map<String, Any?>) {
        worker.execute {
            try {
                val value = action()
                handler.post { result.success(value) }
            } catch (error: Exception) {
                handler.post { result.error("prayer_reminder", error.message ?: "Prayer reminder operation failed.", null) }
            }
        }
    }

    fun dispose() {
        speech.dispose()
        compass.dispose()
        channel.setMethodCallHandler(null)
        clearLocation()
        locationResult?.error("cancelled", "Location request was cancelled.", null)
        notificationResult?.error("cancelled", "Notification request was cancelled.", null)
        locationResult = null
        notificationResult = null
        worker.shutdown()
    }

    companion object {
        private const val NOTIFICATION_PERMISSION = 35001
        private const val LOCATION_PERMISSION = 35002
    }
}


private class WorshipNativeSpeech(private val activity: Activity) : Application.ActivityLifecycleCallbacks {
    private val handler = Handler(Looper.getMainLooper())
    private var engine: TextToSpeech? = null
    private var pending: MethodChannel.Result? = null
    private var generation = 0L
    private var initTimeout: Runnable? = null
    private var resumed = activity.hasWindowFocus()
    private var disposed = false
    init { activity.application.registerActivityLifecycleCallbacks(this) }

    fun speak(arguments: Any?, result: MethodChannel.Result) {
        val text = (arguments as? Map<*, *>)?.get("text") as? String
        if (text == null || text.isBlank() || text.length > 2000 ||
            text.any { (it.code < 32 && it.code !in setOf(9, 10, 13)) || it.code == 127 } ||
            !Regex("[ء-يٮ-ۓۺ-ۼ]").containsMatchIn(text)) {
            result.error("speech_text", "Choose an Arabic dhikr of at most 2,000 characters.", null); return
        }
        if (disposed || !resumed || !activity.hasWindowFocus()) {
            result.error("speech_inactive", "Open this screen before using the device voice.", null); return
        }
        stop()
        val request = generation
        pending = result
        initTimeout = Runnable { fail(request, "speech_timeout", "The device voice took too long to start. Try again.") }
        handler.postDelayed(initTimeout!!, 15000L)
        try {
            engine = TextToSpeech(activity.applicationContext) { status -> handler.post {
                if (request != generation || pending == null || disposed) return@post
                initTimeout?.let { handler.removeCallbacks(it) }; initTimeout = null
                val current = engine
                if (status != TextToSpeech.SUCCESS || current == null) {
                    fail(request, "speech_unavailable", "The device voice could not start."); return@post
                }
                if (!resumed || !activity.hasWindowFocus()) { stop(); return@post }
                try {
                    if (current.setLanguage(Locale.forLanguageTag("ar")) < TextToSpeech.LANG_AVAILABLE) {
                        fail(request, "speech_arabic", "An Arabic device voice is unavailable. Install one in device speech settings."); return@post
                    }
                    current.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                    current.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(id: String?) {}
                        override fun onDone(id: String?) { handler.post { release(request) } }
                        @Deprecated("Android compatibility callback")
                        override fun onError(id: String?) { handler.post { fail(request, "speech_playback", "The device voice could not play this text.") } }
                    })
                    if (current.speak(text.trim(), TextToSpeech.QUEUE_FLUSH, null, "worship-" + request) != TextToSpeech.SUCCESS) {
                        fail(request, "speech_playback", "The device voice could not play this text."); return@post
                    }
                    val completion = pending; pending = null
                    completion?.success(mapOf("started" to true))
                } catch (_: Exception) { fail(request, "speech_unavailable", "The Arabic device voice is unavailable.") }
            } }
        } catch (_: Exception) { fail(request, "speech_unavailable", "The device voice could not start.") }
    }
    private fun fail(request: Long, code: String, message: String) {
        if (request != generation) return
        val completion = pending; pending = null
        release(request)
        completion?.error(code, message, null)
    }
    private fun release(request: Long) {
        if (request != generation) return
        generation++
        initTimeout?.let { handler.removeCallbacks(it) }; initTimeout = null
        val current = engine; engine = null
        try { current?.stop() } catch (_: Exception) {}
        try { current?.shutdown() } catch (_: Exception) {}
    }
    fun stop() {
        val completion = pending; pending = null
        release(generation)
        completion?.error("speech_cancelled", "Device speech was stopped.", null)
    }
    override fun onActivityResumed(owner: Activity) { if (owner === activity) resumed = true }
    override fun onActivityPaused(owner: Activity) { if (owner === activity) { resumed = false; stop() } }
    override fun onActivityCreated(owner: Activity, state: Bundle?) {}
    override fun onActivityStarted(owner: Activity) {}
    override fun onActivityStopped(owner: Activity) {}
    override fun onActivitySaveInstanceState(owner: Activity, state: Bundle) {}
    override fun onActivityDestroyed(owner: Activity) { if (owner === activity) stop() }
    fun dispose() { disposed = true; stop(); activity.application.unregisterActivityLifecycleCallbacks(this) }
}
