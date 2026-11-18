package com.opplexify.quranpakdualpagereader

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.concurrent.Executors

class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        executor.execute {
            try {
                when (intent.action) {
                    PrayerAlarmScheduler.ACTION_FIRE, PrayerAlarmScheduler.ACTION_REFRESH -> {
                        val delivery = PrayerAlarmScheduler.consume(context, intent)
                        if (delivery != null) {
                            val (config, events) = delivery
                            val azan = events.firstOrNull { it.kind == "adhan" && it.sound == "azan" }
                            for (event in events) {
                                if (event == azan) {
                                    PrayerAzanService.start(
                                        context, event, config.volume, config.respectSilent,
                                        config.language, intent.getLongExtra("generation", -1L)
                                    )
                                } else {
                                    PrayerAlarmScheduler.showReminder(context, event, forceSilent = event.sound == "azan")
                                }
                            }
                        }
                    }
                    Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_LOCKED_BOOT_COMPLETED,
                    Intent.ACTION_MY_PACKAGE_REPLACED, Intent.ACTION_DATE_CHANGED,
                    Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED,
                    AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED ->
                        PrayerAlarmScheduler.restore(context)
                }
            } catch (error: Exception) {
                PrayerAlarmScheduler.runtimeError(context, error.message ?: "Prayer reminders could not be refreshed.")
            } finally { pending.finish() }
        }
    }

    companion object {
        private val executor = Executors.newSingleThreadExecutor()
    }
}
