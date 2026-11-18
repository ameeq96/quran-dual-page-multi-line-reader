package com.opplexify.quranpakdualpagereader

import android.app.Activity
import android.app.Application
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Bundle
import android.os.SystemClock
import android.view.Surface
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

internal class QiblaCompass(private val activity: Activity, engine: FlutterEngine) :
    EventChannel.StreamHandler, SensorEventListener, Application.ActivityLifecycleCallbacks {
    private val channel = EventChannel(engine.dartExecutor.binaryMessenger,
        "com.opplexify.quran/prayer_reminders/compass")
    private val manager = activity.getSystemService(SensorManager::class.java)
    private val rotation = manager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private val accelerometer = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val magnetic = manager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
    private val supported = rotation != null || (accelerometer != null && magnetic != null)
    private var sink: EventChannel.EventSink? = null
    private var requested = false
    private var resumed = activity.hasWindowFocus()
    private var registered = false
    private var latitude = 0.0
    private var longitude = 0.0
    private var gravityReady = false
    private var magneticReady = false
    private var magneticAccuracy = SensorManager.SENSOR_STATUS_UNRELIABLE
    private var magneticTimestamp = 0L
    private var accuracy = SensorManager.SENSOR_STATUS_UNRELIABLE
    private var lastEmission = 0L
    private val gravity = FloatArray(3)
    private val field = FloatArray(3)
    private val matrix = FloatArray(9)
    private val remapped = FloatArray(9)
    private val orientation = FloatArray(3)

    init {
        channel.setStreamHandler(this)
        activity.application.registerActivityLifecycleCallbacks(this)
    }

    fun start(arguments: Any?): Map<String, Boolean> {
        val args = arguments as? Map<*, *> ?: throw IllegalArgumentException("Choose a Qibla location.")
        val lat = (args["latitude"] as? Number)?.toDouble()
        val lon = (args["longitude"] as? Number)?.toDouble()
        require(lat != null && lat.isFinite() && lat in -90.0..90.0 &&
            lon != null && lon.isFinite() && lon in -180.0..180.0) { "Choose a valid Qibla location." }
        latitude = lat; longitude = lon; requested = true
        if (!supported) sink?.error("compass_unavailable", "This device has no usable compass sensor.", null)
        else register()
        return mapOf("supported" to supported)
    }

    fun stop() { requested = false; unregister() }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events; register() }
    override fun onCancel(arguments: Any?) { sink = null; stop() }

    private fun register() {
        if (!supported || registered || !requested || !resumed || sink == null) return
        gravityReady = false; magneticReady = false; lastEmission = 0L
        magneticAccuracy = SensorManager.SENSOR_STATUS_UNRELIABLE; magneticTimestamp = 0L
        accuracy = SensorManager.SENSOR_STATUS_UNRELIABLE
        val success = if (rotation != null) manager.registerListener(this, rotation, SensorManager.SENSOR_DELAY_UI) &&
            (magnetic == null || manager.registerListener(this, magnetic, SensorManager.SENSOR_DELAY_UI))
        else manager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_UI) &&
            manager.registerListener(this, magnetic, SensorManager.SENSOR_DELAY_UI)
        registered = success
        if (!success) {
            manager.unregisterListener(this)
            sink?.error("compass_unavailable", "Compass readings are unavailable. Try again.", null)
        }
    }
    private fun unregister() { manager.unregisterListener(this); registered = false }

    @Suppress("DEPRECATION")
    override fun onSensorChanged(event: SensorEvent) {
        if (!registered || sink == null) return
        var fieldStrengthUnusual = false
        if (event.sensor.type == Sensor.TYPE_MAGNETIC_FIELD) {
            event.values.take(3).forEachIndexed { i, value -> field[i] = value }
            magneticReady = event.values.size >= 3
            magneticAccuracy = event.accuracy; magneticTimestamp = event.timestamp
        }
        if (magneticReady) {
            val strengthSquared = field.sumOf { it.toDouble() * it.toDouble() }
            val age = SystemClock.elapsedRealtimeNanos() - magneticTimestamp
            fieldStrengthUnusual = strengthSquared > 10000.0
            if (!strengthSquared.isFinite() || strengthSquared < 100.0 ||
                magneticAccuracy < SensorManager.SENSOR_STATUS_UNRELIABLE || age !in 0L..2_000_000_000L) {
                gravityReady = false
                val now = SystemClock.elapsedRealtime()
                if (now - lastEmission >= 100L) {
                    lastEmission = now
                    sink?.success(mapOf("message" to "Move away from metal and calibrate your compass."))
                }
                return
            }
        }
        if (rotation != null) {
            if (event.sensor.type != rotation.type || (magnetic != null && !magneticReady)) return
            SensorManager.getRotationMatrixFromVector(matrix, event.values)
            accuracy = if (magnetic == null) event.accuracy else minOf(event.accuracy, magneticAccuracy)
        } else {
            if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
                event.values.take(3).forEachIndexed { i, value -> gravity[i] = if (gravityReady) .8f * gravity[i] + .2f * value else value }
                gravityReady = true
            }
            accuracy = magneticAccuracy
            if (!gravityReady || !magneticReady || !SensorManager.getRotationMatrix(matrix, null, gravity, field)) return
        }
        if (fieldStrengthUnusual) accuracy = minOf(accuracy, SensorManager.SENSOR_STATUS_ACCURACY_LOW)
        val now = SystemClock.elapsedRealtime()
        if (now - lastEmission < 100L) return
        val displayRotation = activity.windowManager.defaultDisplay.rotation
        val axes = when (displayRotation) {
            Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
            Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
            Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
            else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
        }
        if (!SensorManager.remapCoordinateSystem(matrix, axes.first, axes.second, remapped)) return
        SensorManager.getOrientation(remapped, orientation)
        val declination = GeomagneticField(latitude.toFloat(), longitude.toFloat(), 0f, System.currentTimeMillis()).declination
        val heading = ((Math.toDegrees(orientation[0].toDouble()) + declination) % 360.0 + 360.0) % 360.0
        if (!heading.isFinite()) return
        lastEmission = now
        sink?.success(mapOf("heading" to heading, "trueNorth" to true, "accuracy" to accuracy))
    }
    override fun onAccuracyChanged(sensor: Sensor?, value: Int) { if (sensor?.type == Sensor.TYPE_MAGNETIC_FIELD) magneticAccuracy = value; if (sensor?.type == rotation?.type || sensor?.type == Sensor.TYPE_MAGNETIC_FIELD) accuracy = value }
    override fun onActivityResumed(owner: Activity) { if (owner === activity) { resumed = true; register() } }
    override fun onActivityPaused(owner: Activity) { if (owner === activity) { resumed = false; unregister() } }
    override fun onActivityCreated(owner: Activity, state: Bundle?) {}
    override fun onActivityStarted(owner: Activity) {}
    override fun onActivityStopped(owner: Activity) {}
    override fun onActivitySaveInstanceState(owner: Activity, state: Bundle) {}
    override fun onActivityDestroyed(owner: Activity) { if (owner === activity) stop() }
    fun dispose() { stop(); sink = null; channel.setStreamHandler(null); activity.application.unregisterActivityLifecycleCallbacks(this) }
}