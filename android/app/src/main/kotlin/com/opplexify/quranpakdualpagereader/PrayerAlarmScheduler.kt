package com.opplexify.quranpakdualpagereader

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import java.io.File
import java.time.Instant

internal object PrayerAlarmScheduler {
    const val ACTION_FIRE = "com.opplexify.quran.PRAYER_ALARM"
    const val ACTION_REFRESH = "com.opplexify.quran.PRAYER_REFRESH"
    const val CHANNEL_AZAN = "quran_prayer_azan_v1"
    const val CHANNEL_TONE = "quran_prayer_reminder_v1"
    const val CHANNEL_SILENT = "quran_prayer_silent_v1"
    const val AZAN_NOTIFICATION_ID = 918313
    private val slots = listOf("primary", "aux", "refresh")

    private fun storage(context: Context): Context =
        if (Build.VERSION.SDK_INT >= 24) context.createDeviceProtectedStorageContext() else context

    private fun preferences(context: Context): SharedPreferences =
        storage(context).getSharedPreferences("quran_prayer_alarm_v1", Context.MODE_PRIVATE)

    fun exactAllowed(context: Context): Boolean =
        Build.VERSION.SDK_INT < 31 ||
            context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    fun notificationsAllowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        return Build.VERSION.SDK_INT < 24 ||
            context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()
    }

    @Synchronized
    fun configure(context: Context, source: String): Map<String, Any?> {
        val config = PrayerConfiguration.parse(source)
        val prefs = preferences(context)
        val generation = prefs.getLong("generation", 0L) + 1L
        cancelPending(context)
        context.stopService(Intent(context, PrayerAzanService::class.java))
        check(prefs.edit().putString("configuration", source).putLong("generation", generation)
            .remove("primary").remove("aux").remove("error").commit()) {
            "Prayer settings could not be saved."
        }
        restore(context)
        return status(context)
    }

    @Synchronized
    fun cancel(context: Context): Map<String, Any?> {
        cancelPending(context)
        context.stopService(Intent(context, PrayerAzanService::class.java))
        val prefs = preferences(context)
        check(prefs.edit().remove("configuration").remove("primary").remove("aux")
            .remove("error").putLong("generation", prefs.getLong("generation", 0L) + 1L).commit()) {
            "Prayer reminders could not be disabled."
        }
        PrayerTimesWidgetProvider.refresh(context)
        return status(context)
    }

    @Synchronized
    fun restore(context: Context) {
        val prefs = preferences(context)
        cancelPending(context)
        prefs.edit().remove("primary").remove("aux").remove("error").commit()
        val source = prefs.getString("configuration", null) ?: return
        try {
            val config = PrayerConfiguration.parse(source)
            if (!config.hasReminders) return
            createChannels(context)
            if (!notificationsAllowed(context)) {
                prefs.edit().putString("error", "Allow notifications to enable prayer reminders.").commit()
                return
            }
            if (!exactAllowed(context)) {
                prefs.edit().putString("error", "Allow alarms and reminders to enable precise prayer alerts.").commit()
                return
            }
            if (config.enabled && config.prayers.values.any { it.enabled && it.sound == "azan" }) ensureAudio(context)
            val now = System.currentTimeMillis()
            val events = PrayerTimeCalculator.upcoming(config, now, consumed(prefs))
            val primary = events.filter { it.kind == "adhan" }
            val auxiliary = events.filter { it.kind != "adhan" }
            arm(context, "primary", primary, prefs.getLong("generation", 0L))
            arm(context, "aux", auxiliary, prefs.getLong("generation", 0L))
            armRefresh(context, config, now, prefs.getLong("generation", 0L))
        } catch (error: Exception) {
            cancelPending(context)
            prefs.edit().remove("primary").remove("aux")
                .putString("error", error.message ?: "Prayer reminders could not be scheduled.").commit()
            try {
                val config = PrayerConfiguration.parse(source)
                if (config.hasReminders && exactAllowed(context) && notificationsAllowed(context)) {
                    armRefresh(context, config, System.currentTimeMillis(), prefs.getLong("generation", 0L))
                }
            } catch (_: Exception) {
                // Invalid saved settings must not create an alarm.
            }
        } finally { PrayerTimesWidgetProvider.refresh(context) }
    }

    @Synchronized
    fun status(context: Context): Map<String, Any?> {
        val prefs = preferences(context)
        val next = slots.take(2).flatMap { readEvents(prefs, it) }.minByOrNull { it.atUtcMs }
        return mapOf(
            "supported" to true,
            "exactAlarmAllowed" to exactAllowed(context),
            "notificationsAllowed" to notificationsAllowed(context),
            "scheduled" to (next != null && exactAllowed(context) && notificationsAllowed(context)),
            "nextEventUtcMs" to next?.atUtcMs,
            "nextEventId" to next?.id,
            "playing" to PrayerAzanService.playing,
            "playingEventId" to PrayerAzanService.playingEventId,
            "error" to prefs.getString("error", null)
        )
    }

    @Synchronized
    fun consume(context: Context, intent: Intent): Pair<PrayerConfiguration, List<PrayerEvent>>? {
        val prefs = preferences(context)
        if (intent.getLongExtra("generation", -1L) != prefs.getLong("generation", 0L)) return null
        val slot = intent.getStringExtra("slot") ?: return null
        if (slot !in slots) return null
        val source = prefs.getString("configuration", null) ?: return null
        val config = try { PrayerConfiguration.parse(source) } catch (_: Exception) { return null }
        if (!config.hasReminders || !notificationsAllowed(context) || !exactAllowed(context)) return null
        if (slot == "refresh") {
            restore(context)
            return null
        }
        val pending = readEvents(prefs, slot)
        val first = pending.firstOrNull() ?: return null
        if (intent.getLongExtra("atUtcMs", -1L) != first.atUtcMs ||
            intent.getStringExtra("eventId") != first.id) return null
        val now = System.currentTimeMillis()
        if (now < first.atUtcMs) {
            restore(context)
            return null
        }
        val consumed = consumed(prefs).toMutableSet()
        val ready = slots.take(2).flatMap { readEvents(prefs, it) }.filter { it.atUtcMs <= now }
        val due = ready.filter { it.id !in consumed && now - it.atUtcMs in 0L..120000L }
        ready.forEach { consumed.add(it.id) }
        check(prefs.edit().putString("consumed", JSONArray(consumed.toList().takeLast(512)).toString()).commit()) {
            "Prayer delivery state could not be saved."
        }
        restore(context)
        return config to due
    }

    @Synchronized
    fun isCurrent(context: Context, generation: Long): Boolean {
        val prefs = preferences(context)
        if (generation != prefs.getLong("generation", 0L)) return false
        return try {
            val source = prefs.getString("configuration", null) ?: return false
            PrayerConfiguration.parse(source).enabled && notificationsAllowed(context)
        } catch (_: Exception) { false }
    }

    fun generation(context: Context): Long = preferences(context).getLong("generation", 0L)

    fun widgetConfiguration(context: Context): PrayerConfiguration? = try {
        preferences(context).getString("configuration", null)?.let { PrayerConfiguration.parse(it) }
    } catch (_: Exception) { null }

    fun runtimeError(context: Context, message: String) {
        preferences(context).edit().putString("error", message.take(300)).commit()
    }

    private fun consumed(prefs: SharedPreferences): Set<String> = try {
        val values = JSONArray(prefs.getString("consumed", "[]"))
        (0 until values.length()).map { values.getString(it) }.toSet()
    } catch (_: Exception) { emptySet() }

    private fun readEvents(prefs: SharedPreferences, slot: String): List<PrayerEvent> = try {
        val values = JSONArray(prefs.getString(slot, "[]"))
        (0 until values.length()).map { PrayerEvent.parse(values.getJSONObject(it)) }
    } catch (_: Exception) { emptyList() }

    private fun pendingIntent(
        context: Context, slot: String, generation: Long = 0L,
        event: PrayerEvent? = null, existingOnly: Boolean = false
    ): PendingIntent? {
        val intent = Intent(context, PrayerAlarmReceiver::class.java)
            .setAction(if (slot == "refresh") ACTION_REFRESH else ACTION_FIRE)
            .setData(Uri.parse("quran-prayer://alarm/" + slot))
            .putExtra("slot", slot).putExtra("generation", generation)
        if (event != null) intent.putExtra("atUtcMs", event.atUtcMs).putExtra("eventId", event.id)
        val flag = if (existingOnly) PendingIntent.FLAG_NO_CREATE else PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getBroadcast(
            context, 918310 + slots.indexOf(slot), intent, flag or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun cancelPending(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        for (slot in slots) pendingIntent(context, slot, existingOnly = true)?.let {
            alarms.cancel(it)
            it.cancel()
        }
    }

    private fun arm(context: Context, slot: String, events: List<PrayerEvent>, generation: Long) {
        val first = events.firstOrNull() ?: return
        val simultaneous = events.takeWhile { it.atUtcMs == first.atUtcMs }
        check(preferences(context).edit().putString(
            slot, JSONArray(simultaneous.map { it.json() }).toString()
        ).commit()) { "Prayer schedule could not be saved." }
        val pending = pendingIntent(context, slot, generation, first)!!
        val alarms = context.getSystemService(AlarmManager::class.java)
        if (slot == "primary") {
            alarms.setAlarmClock(AlarmManager.AlarmClockInfo(first.atUtcMs, openApp(context)), pending)
        } else {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, first.atUtcMs, pending)
        }
    }

    private fun armRefresh(context: Context, config: PrayerConfiguration, now: Long, generation: Long) {
        val local = Instant.ofEpochMilli(now).atZone(config.zone)
        val refresh = local.toLocalDate().plusDays(1).atTime(0, 5)
            .atZone(config.zone).toInstant().toEpochMilli()
        context.getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP, refresh, pendingIntent(context, "refresh", generation)!!
        )
    }

    fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(
            CHANNEL_AZAN, "Prayer Azan playback", NotificationManager.IMPORTANCE_LOW
        ).apply { description = "Stop or control an Azan you enabled."; setSound(null, null) })
        manager.createNotificationChannel(NotificationChannel(
            CHANNEL_TONE, "Prayer reminders", NotificationManager.IMPORTANCE_DEFAULT
        ).apply { description = "Prayer, Jamaat and custom reminder notifications." })
        manager.createNotificationChannel(NotificationChannel(
            CHANNEL_SILENT, "Silent prayer reminders", NotificationManager.IMPORTANCE_LOW
        ).apply { setSound(null, null); enableVibration(false) })
    }

    fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context, 918319,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    @Suppress("DEPRECATION")
    fun showReminder(context: Context, event: PrayerEvent, forceSilent: Boolean = false) {
        if (!notificationsAllowed(context)) return
        createChannels(context)
        val audible = event.sound != "silent" && !forceSilent
        val channel = if (audible) CHANNEL_TONE else CHANNEL_SILENT
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, channel)
        } else Notification.Builder(context)
        builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(event.title).setContentText(event.body)
            .setWhen(event.atUtcMs).setContentIntent(openApp(context)).setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
        if (Build.VERSION.SDK_INT < 26 && audible) builder.setDefaults(Notification.DEFAULT_SOUND)
        context.getSystemService(NotificationManager::class.java).notify("prayer:" + event.id, 918314, builder.build())
    }

    fun ensureAudio(context: Context) {
        val root = File(storage(context).filesDir, "prayer_audio").apply { mkdirs() }
        val prefs = preferences(context)
        @Suppress("DEPRECATION")
        val stamp = context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime
        for (key in listOf("general", "fajr")) {
            val target = File(root, "adhan_" + key + ".mp3")
            if (prefs.getLong("audioStamp", -1L) == stamp && target.length() > 0L) continue
            val temp = File(root, "adhan_" + key + ".tmp")
            try {
                context.assets.open("flutter_assets/assets/prayer_audio/adhan_" + key + ".mp3").use { input ->
                    temp.outputStream().use { output -> input.copyTo(output) }
                }
                check(temp.length() in 1L..15728640L) { "The bundled Azan audio is unavailable." }
                check(temp.renameTo(target)) { "Azan audio could not be saved for offline playback." }
            } finally { temp.delete() }
        }
        check(prefs.edit().putLong("audioStamp", stamp).commit()) { "Azan audio settings could not be saved." }
    }

    fun audioFile(context: Context, key: String): File {
        require(key in setOf("general", "fajr")) { "Unsupported Azan recording." }
        return File(File(storage(context).filesDir, "prayer_audio"), "adhan_" + key + ".mp3")
    }
}
