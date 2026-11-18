package com.opplexify.quranpakdualpagereader

import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import java.time.Instant
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.concurrent.Executors
import org.json.JSONObject

class PrayerTimesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { updateAsync(context) }
    override fun onDisabled(context: Context) { cancelRefresh(context) }
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in setOf(ACTION_REFRESH, Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) updateAsync(context)
        else super.onReceive(context, intent)
    }
    private fun updateAsync(context: Context) {
        val pending = goAsync()
        executor.execute { try { refresh(context.applicationContext) } finally { pending.finish() } }
    }

    companion object {
        private const val ACTION_REFRESH = "com.opplexify.quran.WIDGET_REFRESH"
        private val executor = Executors.newSingleThreadExecutor()
        private fun component(context: Context) = ComponentName(context, PrayerTimesWidgetProvider::class.java)
        fun status(context: Context): Map<String, Boolean> {
            val manager = context.getSystemService(AppWidgetManager::class.java)
            val supported = context.packageManager.hasSystemFeature(PackageManager.FEATURE_APP_WIDGETS)
            return mapOf("supported" to supported,
                "pinSupported" to (supported && Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported),
                "installed" to manager.getAppWidgetIds(component(context)).isNotEmpty())
        }
        fun pin(activity: Activity): Boolean = try {
            Build.VERSION.SDK_INT >= 26 && activity.hasWindowFocus() &&
                activity.getSystemService(AppWidgetManager::class.java).isRequestPinAppWidgetSupported &&
                activity.getSystemService(AppWidgetManager::class.java).requestPinAppWidget(component(activity), null, null)
        } catch (_: Exception) { false }

        @Synchronized
        fun refresh(context: Context) {
            try {
                val manager = context.getSystemService(AppWidgetManager::class.java)
                if (manager.getAppWidgetIds(component(context)).isEmpty()) { cancelRefresh(context); return }
                val generation = PrayerAlarmScheduler.generation(context)
                val config = PrayerAlarmScheduler.widgetConfiguration(context)
                val language = config?.language ?: "en"
                val locale = Locale.forLanguageTag(language)
                val names = when (language) {
                    "ur" -> listOf("فجر", "ظہر", "عصر", "مغرب", "عشاء")
                    "ar" -> listOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")
                    else -> listOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")
                }
                val views = RemoteViews(context.packageName, R.layout.prayer_times_widget)
                views.setTextViewText(R.id.prayer_widget_title, when (language) { "ur" -> "نماز کے اوقات"; "ar" -> "مواقيت الصلاة"; else -> "Prayer times" })
                val now = System.currentTimeMillis()
                var refreshAt: Long? = null
                views.setViewVisibility(R.id.prayer_widget_countdown, View.GONE)
                views.setChronometer(R.id.prayer_widget_countdown, SystemClock.elapsedRealtime(), null, false)
                val times = if (config == null) emptyMap() else {
                    val date = Instant.ofEpochMilli(now).atZone(config.zone).toLocalDate()
                    views.setTextViewText(R.id.prayer_widget_date, date.format(DateTimeFormatter.ofPattern("EEE, d MMM", locale)))
                    views.setTextViewText(R.id.prayer_widget_city, JSONObject(config.source).getJSONObject("location").getString("label"))
                    val next = (0L..2L).flatMap { offset -> clockTimes(config, date.plusDays(offset)).entries.map { it.key to it.value } }
                        .filter { it.second > now }.minByOrNull { it.second }
                    if (next != null) {
                        if (Build.VERSION.SDK_INT >= 24) {
                            views.setViewVisibility(R.id.prayer_widget_countdown, View.VISIBLE)
                            views.setChronometerCountDown(R.id.prayer_widget_countdown, true)
                            val format = when (language) { "ur" -> "باقی وقت: %s"; "ar" -> "الوقت المتبقي: %s"; else -> "Remaining: %s" }
                            views.setChronometer(R.id.prayer_widget_countdown,
                                SystemClock.elapsedRealtime() + next.second - now, format, true)
                        }
                        val name = names[PrayerTimeCalculator.prayerKeys.indexOf(next.first)]
                        val time = Instant.ofEpochMilli(next.second).atZone(config.zone).format(DateTimeFormatter.ofPattern("HH:mm", locale))
                        views.setTextViewText(R.id.prayer_widget_next, when (language) { "ur" -> "اگلی نماز: "; "ar" -> "الصلاة التالية: "; else -> "Next prayer: " } + name + " · " + time)
                    } else views.setTextViewText(R.id.prayer_widget_next, when (language) { "ur" -> "اوقات کے لیے ایپ کھولیں"; "ar" -> "افتح التطبيق لضبط الأوقات"; else -> "Open app to set prayer times" })
                    val midnight = date.plusDays(1).atStartOfDay(config.zone).toInstant().toEpochMilli() + 1000L
                    refreshAt = minOf(next?.second ?: midnight, midnight)
                    clockTimes(config, date)
                }
                if (config == null) {
                    views.setTextViewText(R.id.prayer_widget_city, when (language) { "ur" -> "ایپ میں شہر منتخب کریں"; "ar" -> "اختر مدينة في التطبيق"; else -> "Choose a city in the app" })
                    views.setTextViewText(R.id.prayer_widget_date, "")
                    views.setTextViewText(R.id.prayer_widget_next, when (language) { "ur" -> "اوقات کے لیے ایپ کھولیں"; "ar" -> "افتح التطبيق لضبط الأوقات"; else -> "Open app to set prayer times" })
                }
                val labels = listOf(R.id.prayer_widget_name_fajr, R.id.prayer_widget_name_dhuhr, R.id.prayer_widget_name_asr, R.id.prayer_widget_name_maghrib, R.id.prayer_widget_name_isha)
                val values = listOf(R.id.prayer_widget_time_fajr, R.id.prayer_widget_time_dhuhr, R.id.prayer_widget_time_asr, R.id.prayer_widget_time_maghrib, R.id.prayer_widget_time_isha)
                for ((index, key) in PrayerTimeCalculator.prayerKeys.withIndex()) {
                    views.setTextViewText(labels[index], names[index])
                    views.setTextViewText(values[index], times[key]?.let { Instant.ofEpochMilli(it).atZone(config!!.zone).format(DateTimeFormatter.ofPattern("HH:mm", locale)) } ?: "—")
                }
                val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent(context, MainActivity::class.java)
                views.setOnClickPendingIntent(R.id.prayer_widget_root, PendingIntent.getActivity(context, 918320,
                    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                views.setTextViewText(R.id.prayer_widget_refresh, when (language) { "ur" -> "تازہ کریں"; "ar" -> "تحديث"; else -> "Refresh" })
                views.setOnClickPendingIntent(R.id.prayer_widget_refresh, refreshIntent(context))
                if (generation != PrayerAlarmScheduler.generation(context)) return
                manager.updateAppWidget(component(context), views)
                if (refreshAt != null) {
                    val alarms = context.getSystemService(AlarmManager::class.java)
                    if (PrayerAlarmScheduler.exactAllowed(context)) {
                        if (Build.VERSION.SDK_INT >= 23) alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, refreshAt, refreshIntent(context))
                        else alarms.setExact(AlarmManager.RTC_WAKEUP, refreshAt, refreshIntent(context))
                    } else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, refreshAt, refreshIntent(context))
                } else cancelRefresh(context)
            } catch (_: Exception) { /* Widget failures must never interrupt a user's prayer alarms. */ }
        }

        private fun clockTimes(config: PrayerConfiguration, date: LocalDate): Map<String, Long> {
            val automatic = try { PrayerTimeCalculator.automaticTimes(config, date) } catch (_: Exception) { emptyMap() }
            return PrayerTimeCalculator.prayerKeys.mapNotNull { key ->
                val rule = config.prayers.getValue(key)
                val base = rule.manualMinutes?.let { date.atTime(it / 60, it % 60).atZone(config.zone).toInstant().toEpochMilli() } ?: automatic[key]
                base?.let { key to it + rule.offsetMinutes * 60000L }
            }.toMap()
        }
        private fun refreshIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(context, 918319,
            Intent(context, PrayerTimesWidgetProvider::class.java).setAction(ACTION_REFRESH).setData(Uri.parse("quran-prayer-widget://refresh")),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        private fun cancelRefresh(context: Context) { context.getSystemService(AlarmManager::class.java).cancel(refreshIntent(context)) }
    }
}