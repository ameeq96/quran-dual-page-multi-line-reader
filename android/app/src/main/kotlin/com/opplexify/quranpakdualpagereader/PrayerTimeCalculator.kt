package com.opplexify.quranpakdualpagereader

import com.batoulapps.adhan.CalculationMethod
import com.batoulapps.adhan.Coordinates
import com.batoulapps.adhan.HighLatitudeRule
import com.batoulapps.adhan.Madhab
import com.batoulapps.adhan.PrayerTimes
import com.batoulapps.adhan.PrayerAdjustments
import com.batoulapps.adhan.data.DateComponents
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

internal data class PrayerRule(
    val enabled: Boolean,
    val sound: String,
    val offsetMinutes: Int,
    val manualMinutes: Int?,
    val jamaatMinutes: Int?
)

internal data class PrayerCustomReminder(
    val id: String,
    val label: String,
    val minutes: Int,
    val weekdays: Set<Int>,
    val enabled: Boolean,
    val sound: String
)

internal data class WorshipRamadanPlan(val startDate: LocalDate, val days: Int, val enabled: Boolean,
    val sehriLeadMinutes: Int, val iftarLeadMinutes: Int)
internal data class WorshipMasjidPlan(val name: String, val source: String, val verified: Boolean,
    val enabled: Boolean, val validFrom: LocalDate, val validUntil: LocalDate, val times: Map<String, Int>,
    val zone: ZoneId, val latitude: Double, val longitude: Double)
internal data class WorshipPlans(val ramadan: WorshipRamadanPlan? = null, val masjid: WorshipMasjidPlan? = null)

internal data class PrayerConfiguration(
    val source: String,
    val profileId: String,
    val enabled: Boolean,
    val language: String,
    val latitude: Double,
    val longitude: Double,
    val zone: ZoneId,
    val method: String,
    val madhab: String,
    val highLatitudeRule: String,
    val preReminderMinutes: Int,
    val volume: Float,
    val respectSilent: Boolean,
    val prayers: Map<String, PrayerRule>,
    val customReminders: List<PrayerCustomReminder>,
    val worship: WorshipPlans = WorshipPlans()
) {
    val hasReminders: Boolean get() = enabled || worship.ramadan?.enabled == true ||
        worship.masjid?.let { it.enabled && it.verified && masjidMatchesLocation(it) } == true
    fun masjidMatchesLocation(plan: WorshipMasjidPlan): Boolean = plan.zone == zone &&
        kotlin.math.abs(plan.latitude - latitude) < 0.02 && kotlin.math.abs(plan.longitude - longitude) < 0.02
    companion object {
        fun parse(value: String): PrayerConfiguration {
            require(value.length <= 32768) { "Prayer settings are too large." }
            val json = JSONObject(value)
            require(integer(json, "version", 1, 1) == 1) { "Unsupported prayer settings." }
            val profile = text(json, "profileId", 100)
            require(profile.matches(Regex("[A-Za-z0-9_.:-]+"))) { "Invalid prayer profile." }
            val location = json.getJSONObject("location")
            val latitude = number(location, "latitude", -90.0, 90.0)
            val longitude = number(location, "longitude", -180.0, 180.0)
            val zoneName = text(location, "zone", 80)
            require(ZoneId.getAvailableZoneIds().contains(zoneName)) { "Choose a valid city time zone." }
            text(location, "label", 100)
            val method = text(json, "method", 30)
            require(method in setOf("karachi", "mwl", "ummAlQura", "egyptian", "northAmerica", "dubai")) {
                "Choose a supported prayer calculation method."
            }
            val madhab = text(json, "madhab", 10)
            require(madhab in setOf("hanafi", "shafi")) { "Choose a valid Asr method." }
            val latitudeRule = text(json, "highLatitudeRule", 30)
            require(latitudeRule in setOf("recommended", "middleOfNight", "seventhOfNight", "twilightAngle")) {
                "Choose a valid high-latitude rule."
            }
            val before = integer(json, "preReminderMinutes", 0, 30)
            require(before in setOf(0, 5, 10, 15, 30)) { "Choose a supported advance reminder." }
            val rules = json.getJSONObject("prayers")
            val prayers = PrayerTimeCalculator.prayerKeys.associateWith { key ->
                val rule = rules.getJSONObject(key)
                val sound = text(rule, "sound", 10)
                require(sound in setOf("azan", "tone", "silent")) { "Invalid prayer sound." }
                PrayerRule(
                    boolean(rule, "enabled"), sound,
                    integer(rule, "offsetMinutes", -60, 60),
                    optionalMinutes(rule, "manualMinutes"),
                    optionalMinutes(rule, "jamaatMinutes")
                )
            }
            val custom = json.getJSONArray("customReminders")
            require(custom.length() <= 10) { "At most ten custom prayer reminders are supported." }
            val customIds = mutableSetOf<String>()
            val reminders = (0 until custom.length()).map { index ->
                val item = custom.getJSONObject(index)
                val id = text(item, "id", 64)
                require(id.matches(Regex("[A-Za-z0-9_-]+")) && customIds.add(id)) {
                    "Custom reminder IDs must be unique."
                }
                val weekdaysJson = item.getJSONArray("weekdays")
                val enabled = boolean(item, "enabled")
                require(weekdaysJson.length() in 0..7 &&
                    (!enabled || weekdaysJson.length() > 0)) { "Choose reminder weekdays." }
                val days = (0 until weekdaysJson.length()).map { day ->
                    val raw = weekdaysJson.get(day)
                    require(raw is Number && raw.toDouble() == raw.toInt().toDouble() && raw.toInt() in 1..7) {
                        "Invalid reminder weekday."
                    }
                    raw.toInt()
                }.toSet()
                val sound = text(item, "sound", 10)
                require(sound in setOf("tone", "silent")) { "Invalid custom reminder sound." }
                PrayerCustomReminder(
                    id, text(item, "label", 100), integer(item, "minutes", 0, 1439),
                    days, enabled, sound
                )
            }
            val language = text(json, "language", 5)
            require(language in setOf("en", "ur", "ar")) { "Unsupported prayer reminder language." }
            return PrayerConfiguration(
                value, profile, boolean(json, "enabled"), language, latitude, longitude,
                ZoneId.of(zoneName), method, madhab, latitudeRule, before,
                number(json, "volume", 0.0, 1.0).toFloat(), boolean(json, "respectSilent"),
                prayers, reminders, parseWorship(json)
            )
        }

        private fun boolean(json: JSONObject, key: String): Boolean {
            val value = json.get(key)
            require(value is Boolean) { "Invalid prayer setting: " + key }
            return value
        }

        private fun text(json: JSONObject, key: String, limit: Int): String {
            val value = json.get(key)
            require(value is String && value.isNotBlank() && value.length <= limit &&
                value.none { it.code < 32 }) { "Invalid prayer setting: " + key }
            return value
        }

        private fun number(json: JSONObject, key: String, minimum: Double, maximum: Double): Double {
            val value = json.get(key)
            require(value is Number && value.toDouble().isFinite() && value.toDouble() in minimum..maximum) {
                "Invalid prayer setting: " + key
            }
            return value.toDouble()
        }

        private fun integer(json: JSONObject, key: String, minimum: Int, maximum: Int): Int {
            val value = number(json, key, minimum.toDouble(), maximum.toDouble())
            require(value == value.toInt().toDouble()) { "Invalid prayer setting: " + key }
            return value.toInt()
        }

        private fun exactKeys(json: JSONObject, allowed: Set<String>) {
            require(json.keys().asSequence().all { it in allowed }) { "Unknown worship setting." }
        }
        private fun day(json: JSONObject, key: String): LocalDate {
            val value = text(json, key, 10)
            require(value.matches(Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}"))) { "Choose a valid worship date." }
            val date = LocalDate.parse(value)
            require(date.year in 1900..2200) { "Choose a supported worship date." }
            return date
        }
        private fun parseWorship(root: JSONObject): WorshipPlans {
            if (!root.has("worship") || root.isNull("worship")) return WorshipPlans()
            val json = root.getJSONObject("worship")
            exactKeys(json, setOf("ramadan", "masjid"))
            val ramadan = if (!json.has("ramadan") || json.isNull("ramadan")) null else {
                val plan = json.getJSONObject("ramadan")
                exactKeys(plan, setOf("startDate", "days", "enabled", "sehriLeadMinutes", "iftarLeadMinutes"))
                WorshipRamadanPlan(day(plan, "startDate"), integer(plan, "days", 29, 30),
                    boolean(plan, "enabled"), integer(plan, "sehriLeadMinutes", 0, 60),
                    integer(plan, "iftarLeadMinutes", 0, 30))
            }
            val masjid = if (!json.has("masjid") || json.isNull("masjid")) null else {
                val plan = json.getJSONObject("masjid")
                exactKeys(plan, setOf("name", "source", "verified", "enabled", "validFrom", "validUntil", "times", "zone", "latitude", "longitude"))
                val from = day(plan, "validFrom"); val until = day(plan, "validUntil")
                require(!until.isBefore(from)) { "Timetable end precedes start." }
                val timesJson = plan.getJSONObject("times")
                exactKeys(timesJson, PrayerTimeCalculator.prayerKeys.toSet())
                val times = timesJson.keys().asSequence().associateWith { integer(timesJson, it, 0, 1439) }
                val enabled = boolean(plan, "enabled"); val verified = boolean(plan, "verified")
                require(!enabled || (verified && times.isNotEmpty())) { "Confirm your Masjid timetable first." }
                val zone = text(plan, "zone", 80)
                require(ZoneId.getAvailableZoneIds().contains(zone)) { "Choose a valid Masjid time zone." }
                WorshipMasjidPlan(text(plan, "name", 80), text(plan, "source", 160), verified,
                    enabled, from, until, times, ZoneId.of(zone), number(plan, "latitude", -89.0, 89.0),
                    number(plan, "longitude", -180.0, 180.0))
            }
            return WorshipPlans(ramadan, masjid)
        }

        private fun optionalMinutes(json: JSONObject, key: String): Int? =
            if (!json.has(key) || json.isNull(key)) null else integer(json, key, 0, 1439)
    }
}

internal data class PrayerEvent(
    val id: String,
    val atUtcMs: Long,
    val title: String,
    val body: String,
    val kind: String,
    val sound: String,
    val audioKey: String = "general"
) {
    fun json(): JSONObject = JSONObject()
        .put("id", id).put("atUtcMs", atUtcMs).put("title", title).put("body", body)
        .put("kind", kind).put("sound", sound).put("audioKey", audioKey)

    companion object {
        fun parse(json: JSONObject): PrayerEvent = PrayerEvent(
            json.getString("id"), json.getLong("atUtcMs"), json.getString("title"),
            json.getString("body"), json.getString("kind"), json.getString("sound"),
            json.optString("audioKey", "general")
        )
    }
}

internal object PrayerTimeCalculator {
    val prayerKeys = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")

    fun upcoming(config: PrayerConfiguration, nowUtcMs: Long, consumed: Set<String>): List<PrayerEvent> {
        if (!config.hasReminders) return emptyList()
        val today = Instant.ofEpochMilli(nowUtcMs).atZone(config.zone).toLocalDate()
        val result = mutableListOf<PrayerEvent>()
        for (dayOffset in -1L..8L) {
            val date = today.plusDays(dayOffset)
            val ramadanNeedsTimes = config.worship.ramadan?.let { it.enabled &&
                !date.isBefore(it.startDate) && date.isBefore(it.startDate.plusDays(it.days.toLong())) &&
                listOf("fajr", "maghrib").any { key -> config.prayers.getValue(key).manualMinutes == null } } == true
            val automatic = if ((config.enabled && config.prayers.values.any { it.enabled && it.manualMinutes == null }) || ramadanNeedsTimes) {
                automaticTimes(config, date)
            } else emptyMap()
            for (key in prayerKeys) {
                val rule = config.prayers.getValue(key)
                if (!config.enabled || !rule.enabled) continue
                val rawTime = rule.manualMinutes?.let { clock(date, it, config.zone) }
                    ?: automatic.getValue(key)
                val at = rawTime + rule.offsetMinutes * 60000L
                val name = prayerName(config.language, key)
                val prefix = config.profileId + ":" + date + ":" + key + ":"
                result.add(PrayerEvent(
                    prefix + "adhan", at, name, prayerBody(config.language, name),
                    "adhan", rule.sound, if (key == "fajr") "fajr" else "general"
                ))
                if (config.preReminderMinutes > 0) {
                    val minutes = config.preReminderMinutes
                    val body = when (config.language) {
                        "ur" -> name + " میں " + minutes + " منٹ باقی ہیں۔"
                        "ar" -> "بقي " + minutes + " دقيقة على صلاة " + name + "."
                        else -> name + " begins in " + minutes + " minutes."
                    }
                    result.add(PrayerEvent(
                        prefix + "before", at - minutes * 60000L, name, body,
                        "before", if (rule.sound == "silent") "silent" else "tone"
                    ))
                }
                rule.jamaatMinutes?.let { minutes ->
                    val jamaatDate = if (key == "isha" && minutes < 720) date.plusDays(1) else date
                    result.add(PrayerEvent(
                        prefix + "jamaat", clock(jamaatDate, minutes, config.zone), name,
                        when (config.language) {
                            "ur" -> "آپ کی مقرر کردہ جماعت کا وقت ہو گیا ہے۔"
                            "ar" -> "حان وقت الجماعة الذي حددته."
                            else -> "It is your saved Jamaat time."
                        }, "jamaat", if (rule.sound == "silent") "silent" else "tone"
                    ))
                }
            }
            result.addAll(worshipEvents(config, date, automatic))
            for (custom in config.customReminders) {
                if (!config.enabled || !custom.enabled || date.dayOfWeek.value !in custom.weekdays) continue
                result.add(PrayerEvent(
                    config.profileId + ":" + date + ":custom:" + custom.id,
                    clock(date, custom.minutes, config.zone), custom.label, custom.label,
                    "custom", custom.sound
                ))
            }
        }
        val azanTimes = result.filter { it.kind == "adhan" && it.sound == "azan" }.map { it.atUtcMs }.toSet()
        return result.map { if (it.kind == "worship" && it.atUtcMs in azanTimes) it.copy(sound = "silent") else it }
            .filter { it.atUtcMs > nowUtcMs && it.id !in consumed }
            .sortedWith(compareBy<PrayerEvent> { it.atUtcMs }.thenBy { it.id })
    }

    private fun worshipEvents(config: PrayerConfiguration, date: LocalDate, automatic: Map<String, Long>): List<PrayerEvent> {
        val result = mutableListOf<PrayerEvent>()
        val prefix = config.profileId + ":" + date + ":worship:"
        config.worship.ramadan?.let { plan ->
            if (plan.enabled && !date.isBefore(plan.startDate) && date.isBefore(plan.startDate.plusDays(plan.days.toLong()))) {
                for ((key, title, lead) in listOf(Triple("fajr", "Sehri reminder", plan.sehriLeadMinutes),
                    Triple("maghrib", "Iftar reminder", plan.iftarLeadMinutes))) {
                    val rule = config.prayers.getValue(key)
                    val base = rule.manualMinutes?.let { clock(date, it, config.zone) } ?: automatic.getValue(key)
                    result.add(PrayerEvent(prefix + key, base + (rule.offsetMinutes - lead) * 60000L,
                        title, title, "worship", "tone"))
                }
            }
        }
        config.worship.masjid?.let { plan ->
            if (plan.enabled && plan.verified && config.masjidMatchesLocation(plan) &&
                !date.isBefore(plan.validFrom) && !date.isAfter(plan.validUntil)) {
                for ((key, minutes) in plan.times) {
                    val title = plan.name + " · " + key + " Jamaat"
                    val jamaatDate = if (key == "isha" && minutes < 720) date.plusDays(1) else date
                    result.add(PrayerEvent(prefix + "jamaat:" + key, clock(jamaatDate, minutes, config.zone),
                        title, title, "worship", "tone"))
                }
            }
        }
        return result
    }

    fun automaticTimes(config: PrayerConfiguration, date: LocalDate): Map<String, Long> {
        val parameters = when (config.method) {
            "karachi" -> CalculationMethod.KARACHI
            "mwl" -> CalculationMethod.MUSLIM_WORLD_LEAGUE
            "ummAlQura" -> CalculationMethod.UMM_AL_QURA
            "egyptian" -> CalculationMethod.EGYPTIAN
            "northAmerica" -> CalculationMethod.NORTH_AMERICA
            "dubai" -> CalculationMethod.DUBAI
            else -> throw IllegalArgumentException("Unsupported prayer calculation method.")
        }.parameters
        parameters.methodAdjustments = when (config.method) {
            "dubai" -> PrayerAdjustments(0, -3, 3, 3, 3, 0)
            "ummAlQura" -> PrayerAdjustments(0, 0, 0, 0, 0, 0)
            else -> PrayerAdjustments(0, 0, 1, 0, 0, 0)
        }
        parameters.madhab = if (config.madhab == "hanafi") Madhab.HANAFI else Madhab.SHAFI
        parameters.highLatitudeRule = when (config.highLatitudeRule) {
            "seventhOfNight" -> HighLatitudeRule.SEVENTH_OF_THE_NIGHT
            "twilightAngle" -> HighLatitudeRule.TWILIGHT_ANGLE
            "middleOfNight" -> HighLatitudeRule.MIDDLE_OF_THE_NIGHT
            else -> if (kotlin.math.abs(config.latitude) >= 48) {
                HighLatitudeRule.SEVENTH_OF_THE_NIGHT
            } else HighLatitudeRule.MIDDLE_OF_THE_NIGHT
        }
        val times = PrayerTimes(
            Coordinates(config.latitude, config.longitude),
            DateComponents(date.year, date.monthValue, date.dayOfMonth), parameters
        )
        val dates = listOf(times.fajr, times.dhuhr, times.asr, times.maghrib, times.isha)
        require(dates.all { it != null }) {
            "Prayer times cannot be calculated for this location and date. Choose manual times or another location."
        }
        return prayerKeys.zip(dates.map { Math.floorDiv(it!!.time, 60000L) * 60000L }).toMap()
    }

    private fun clock(date: LocalDate, minutes: Int, zone: ZoneId): Long =
        date.atTime(minutes / 60, minutes % 60).atZone(zone).toInstant().toEpochMilli()

    private fun prayerName(language: String, key: String): String {
        val index = prayerKeys.indexOf(key)
        return when (language) {
            "ur" -> listOf("فجر", "ظہر", "عصر", "مغرب", "عشاء")[index]
            "ar" -> listOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")[index]
            else -> listOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")[index]
        }
    }

    private fun prayerBody(language: String, name: String): String = when (language) {
        "ur" -> name + " کا وقت ہو گیا ہے۔"
        "ar" -> "حان وقت صلاة " + name + "."
        else -> "It is time for " + name + "."
    }
}
