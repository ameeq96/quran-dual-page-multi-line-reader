package com.opplexify.quranpakdualpagereader

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.time.Instant
import java.util.concurrent.Executors

internal class ReaderRecordingBridge(private val activity: Activity, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.opplexify.quran/lesson_recording")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val filesLock = FILES_LOCK
    @Volatile private var disposed = false
    private var foreground = false
    private var permissionResult: MethodChannel.Result? = null
    private var exportResult: MethodChannel.Result? = null
    private var exportFile: File? = null
    private var recorder: MediaRecorder? = null
    private var sessionId: String? = null
    private var captureProfile: String? = null
    private var captureFile: File? = null
    private var capturePhase = "idle"
    private var captureStarted = 0L
    private var captureDuration = 0L
    private var captureError: String? = null
    private var player: MediaPlayer? = null
    private var preparing = false
    private var audioOwner: String? = null
    private var pendingPlaybackOwner: String? = null
    private var playbackGeneration = 0L
    private var audioFiles = emptyList<File>()
    private var audioIds = emptyList<String>()
    private var audioIndex = 0
    private var previewFile: File? = null
    private var lastAudioOwner: String? = null
    private var lastAudioError: String? = null
    private var cleaned = false
    private val stopAtLimit = Runnable { finishCapture() }

    init {
        channel.setMethodCallHandler(::handle)
    }

    private fun cleanupTemps() {
        if (cleaned) return
        val staleBefore = System.currentTimeMillis() - 15 * 60 * 1000L
        File(activity.noBackupFilesDir, "reader_lessons").listFiles()?.filter { validProfile(it.name) }?.forEach { profile ->
                    listOf("capture", "preview").forEach { name ->
                        File(profile, name).listFiles()?.filter { it.isFile && it.lastModified() < staleBefore && it != captureFile && it != previewFile }?.forEach { it.delete() }
                    }
                    File(profile, "clips").listFiles()?.filter { it.name.endsWith(".pending") && it.lastModified() < staleBefore }?.forEach { it.delete() }
        }
        cleaned = true
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) { result.error("closed", "Lesson recording is closed.", null); return }
        try {
            val a = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            when (call.method) {
                "captureStart" -> requestCapture(a, result)
                "captureStatus" -> { ownCapture(a); result.success(captureStatus()) }
                "captureStop" -> { ownCapture(a); finishCapture(); result.success(captureStatus()) }
                "captureCancel" -> {
                    if (a["sessionId"] == sessionId && a["profileId"] == captureProfile) clearCapture()
                    result.success(null)
                }
                "captureRead" -> {
                    ownCapture(a)
                    val file = readyCapture()
                    background(result, { readAudio(file, MAX_BYTES) })
                }
                "capturePlay" -> {
                    ownCapture(a)
                    require(foreground) { "Return to the app before playing a lesson." }
                    val owner = "capture_" + sessionId
                    if (audioOwner == owner) stopAudio(owner)
                    else playFiles(owner, listOf(readyCapture()), emptyList())
                    result.success(captureStatus())
                }
                "captureExport" -> exportCapture(a, result)
                "storeList" -> {
                    val profile = profile(a); val limits = limits(a)
                    background(result, { synchronized(filesLock) { listClips(profile, limits) } })
                }
                "storeSave" -> {
                    val profile = profile(a); val limits = limits(a)
                    val bytes = audioBytes(a, limits.single)
                    val metadata = metadata(a["metadata"] as? Map<*, *>, profile)
                    require((metadata["bytes"] as Number).toInt() == bytes.size) { "Lesson audio size does not match its metadata." }
                    background(result, { synchronized(filesLock) { saveClip(profile, metadata, bytes, limits) } })
                }
                "storeRead" -> {
                    val profile = profile(a); val id = clipId(a["id"]); val limits = limits(a)
                    background(result, { synchronized(filesLock) { readClip(profile, id, limits.single) } })
                }
                "storeDelete" -> {
                    val profile = profile(a); val id = clipId(a["id"])
                    val file = File(clips(profile), "$id.audio")
                    if (audioFiles.any { it == file }) stopAudio()
                    background(result, {
                        synchronized(filesLock) {
                            listOf(file, File(clips(profile), "$id.json")).forEach {
                                require(!it.exists() || it.delete()) { "The lesson recording could not be deleted." }
                            }
                            null
                        }
                    })
                }
                "storePlay" -> {
                    val profile = profile(a); val owner = owner(a)
                    require(foreground && recorder == null) { "Stop recording and return to the app before playback." }
                    val ids = (a["ids"] as? List<*>)?.map { clipId(it) } ?: error("Choose a lesson recording.")
                    require(ids.size in 1..2 && ids.distinct().size == ids.size) { "Choose one or two different recordings." }
                    val files = ids.map {
                        val metadata = readMetadata(profile, it)
                        val file = File(clips(profile), "$it.audio")
                        require(file.isFile && file.length() == (metadata["bytes"] as Number).toLong()) { "Lesson recording not found." }
                        file
                    }
                    playFiles(owner, files, ids)
                    result.success(audioStatus(owner))
                }
                "lessonPlayBytes" -> {
                    val profile = profile(a); val owner = owner(a)
                    require(foreground && recorder == null) { "Stop recording and return to the app before playback." }
                    val bytes = audioBytes(a, MAX_BYTES)
                    val mime = a["mimeType"] as? String ?: ""
                    require(validMime(mime)) { "Choose a supported audio format." }
                    stopAudio()
                    val generation = playbackGeneration
                    pendingPlaybackOwner = owner
                    background(result, {
                        synchronized(filesLock) {
                            File.createTempFile("preview_", ".audio", directory(profile, "preview")).also { file ->
                                try { FileOutputStream(file).use { it.write(bytes); it.fd.sync() } }
                                catch (error: Exception) { file.delete(); throw error }
                            }
                        }
                    }, { file ->
                        if (!foreground || disposed || recorder != null ||
                            generation != playbackGeneration || pendingPlaybackOwner != owner) {
                            file.delete()
                            if (generation == playbackGeneration && pendingPlaybackOwner == owner) pendingPlaybackOwner = null
                            result.error("cancelled", "The lesson playback was cancelled.", null)
                        } else {
                            pendingPlaybackOwner = null
                            previewFile = file
                            playFiles(owner, listOf(file), emptyList(), keepPreview = true)
                            result.success(audioStatus(owner))
                        }
                    })
                }
                "lessonStopPlayback" -> { stopAudio(owner(a)); result.success(null) }
                "lessonPlaybackStatus" -> result.success(audioStatus(owner(a)))
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("lesson_recording", safeError(error), null)
        }
    }

    private fun requestCapture(a: Map<*, *>, result: MethodChannel.Result) {
        val profile = profile(a)
        val session = clipId(a["sessionId"])
        require(foreground && !activity.isFinishing) { "Return to the app before recording." }
        require(permissionResult == null && recorder == null) { "A lesson recording is already active." }
        stopAudio()
        clearCapture()
        sessionId = session; captureProfile = profile
        capturePhase = "requesting"; captureError = null
        permissionResult = result
        if (Build.VERSION.SDK_INT >= 23 &&
            activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), MICROPHONE_PERMISSION)
        } else startRecorder()
    }

    @Suppress("DEPRECATION")
    private fun startRecorder() {
        val result = permissionResult ?: return
        if (!foreground || disposed) return
        permissionResult = null
        try {
            stopAudio()
            val file = synchronized(filesLock) {
                cleanupTemps()
                File.createTempFile("capture_", ".m4a", directory(captureProfile!!, "capture")).also { captureFile = it }
            }
            val next = MediaRecorder()
            recorder = next
            next.setAudioSource(MediaRecorder.AudioSource.MIC)
            next.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            next.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            next.setAudioEncodingBitRate(64000)
            next.setAudioSamplingRate(44100)
            next.setOutputFile(file.absolutePath)
            next.setMaxDuration(MAX_DURATION.toInt())
            next.setMaxFileSize(MAX_BYTES.toLong())
            next.setOnInfoListener { source, what, _ ->
                if (recorder === source && (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED ||
                    what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_FILESIZE_REACHED)) finishCapture()
            }
            next.setOnErrorListener { source, _, _ ->
                if (recorder === source) {
                    captureError = "The microphone stopped. Record the lesson again."
                    finishCapture(discard = true)
                }
            }
            next.prepare()
            next.start()
            captureStarted = SystemClock.elapsedRealtime()
            captureDuration = 0L
            capturePhase = "recording"
            main.postDelayed(stopAtLimit, MAX_DURATION)
            result.success(captureStatus())
        } catch (error: Exception) {
            captureError = "The microphone could not start. Check its permission and close other recording apps."
            finishCapture(discard = true)
            result.error("microphone", captureError, null)
        }
    }

    private fun finishCapture(discard: Boolean = false) {
        main.removeCallbacks(stopAtLimit)
        val current = recorder
        recorder = null
        var valid = !discard
        var stopped = true
        if (current != null) {
            captureDuration = (SystemClock.elapsedRealtime() - captureStarted).coerceIn(0L, MAX_DURATION)
            try { current.stop() } catch (_: RuntimeException) { stopped = false }
            try { current.reset() } catch (_: Exception) { }
            try { current.release() } catch (_: Exception) { }
        }
        val file = captureFile
        if (!stopped && valid) valid = usableCapture(file)
        if (!valid || file == null || !file.isFile || file.length() !in 1..MAX_BYTES.toLong()) {
            file?.delete()
            captureFile = null
            capturePhase = "idle"
            if (current != null && !discard) captureError = "No usable audio was captured. Record for a little longer."
        } else capturePhase = "ready"
    }

    private fun usableCapture(file: File?): Boolean {
        if (file == null || !file.isFile || file.length() !in 1..MAX_BYTES.toLong()) return false
        val metadata = MediaMetadataRetriever()
        return try {
            metadata.setDataSource(file.absolutePath)
            val duration = metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
            duration != null && duration in 1..(MAX_DURATION + 1000L)
        } catch (_: Exception) { false }
        finally { try { metadata.release() } catch (_: Exception) { } }
    }

    private fun clearCapture() {
        permissionResult?.error("cancelled", "The lesson recording was cancelled.", null)
        permissionResult = null
        stopAudio("capture_" + sessionId)
        finishCapture(discard = true)
        captureFile?.delete(); captureFile = null
        sessionId = null; captureProfile = null
        captureDuration = 0L; capturePhase = "idle"; captureError = null
    }

    private fun captureStatus(): Map<String, Any?> {
        val duration = if (recorder != null) (SystemClock.elapsedRealtime() - captureStarted).coerceIn(0L, MAX_DURATION) else captureDuration
        return mapOf("phase" to capturePhase, "durationMillis" to duration,
            "hasRecording" to (capturePhase == "ready" && captureFile?.isFile == true),
            "playing" to (audioOwner == "capture_" + sessionId && player != null), "error" to captureError)
    }
    private fun ownCapture(a: Map<*, *>) {
        require(profile(a) == captureProfile && clipId(a["sessionId"]) == sessionId) { "This lesson recording is no longer available." }
    }
    private fun readyCapture(): File {
        require(capturePhase == "ready" && recorder == null) { "Finish the lesson recording first." }
        return captureFile?.takeIf { it.isFile && it.length() in 1..MAX_BYTES.toLong() }
            ?: throw IllegalArgumentException("No completed lesson recording is available.")
    }

    private fun exportCapture(a: Map<*, *>, result: MethodChannel.Result) {
        ownCapture(a)
        require(foreground && exportResult == null) { "Finish the current export first." }
        exportFile = readyCapture()
        exportResult = result
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "audio/mp4"
                putExtra(Intent.EXTRA_TITLE, "quran-lesson.m4a")
            }, EXPORT_AUDIO)
        } catch (error: Exception) {
            exportFile = null; exportResult = null
            throw error
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != EXPORT_AUDIO) return
        val result = exportResult ?: return
        val file = exportFile
        exportResult = null; exportFile = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return }
        if (uri.scheme != "content" || file == null || !file.isFile) {
            result.error("export", "The lesson recording could not be exported.", null); return
        }
        background(result, {
            activity.contentResolver.openOutputStream(uri, "w")?.use { output ->
                file.inputStream().use { input -> input.copyTo(output) }
            } ?: throw IllegalArgumentException("The selected document could not be opened.")
            null
        })
    }

    private fun playFiles(owner: String, files: List<File>, ids: List<String>, keepPreview: Boolean = false) {
        require(recorder == null) { "Stop recording before playback." }
        if (!keepPreview) stopAudio()
        audioOwner = owner; audioFiles = files; audioIds = ids; audioIndex = 0
        lastAudioOwner = null; lastAudioError = null
        startAudio(owner)
    }
    private fun startAudio(owner: String) {
        player?.release(); player = null
        val next = MediaPlayer()
        player = next; preparing = true
        try {
        next.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
        next.setDataSource(audioFiles[audioIndex].absolutePath)
        next.setOnPreparedListener {
            if (disposed || !foreground || player !== it || audioOwner != owner) {
                if (player === it) stopAudio(owner) else it.release()
            } else {
                try { preparing = false; it.start() }
                catch (_: Exception) { playbackFailed(owner) }
            }
        }
        next.setOnCompletionListener {
            if (player === it && audioOwner == owner) {
                if (audioIndex + 1 < audioFiles.size) {
                    audioIndex++
                    try { startAudio(owner) } catch (_: Exception) { playbackFailed(owner) }
                }
                else stopAudio(owner)
            }
        }
        next.setOnErrorListener { current, _, _ ->
            if (player === current && audioOwner == owner) {
                playbackFailed(owner)
            }
            true
        }
        next.prepareAsync()
        } catch (error: Exception) { playbackFailed(owner); throw error }
    }
    private fun playbackFailed(owner: String) {
        stopAudio(owner)
        lastAudioOwner = owner
        lastAudioError = "This lesson audio could not be played."
    }
    private fun stopAudio(owner: String? = null) {
        if (owner == null || owner == pendingPlaybackOwner) {
            playbackGeneration++
            pendingPlaybackOwner = null
        }
        if (owner != null && owner != audioOwner) return
        val current = player; player = null; preparing = false
        current?.setOnPreparedListener(null); current?.setOnCompletionListener(null); current?.setOnErrorListener(null)
        current?.release()
        previewFile?.delete(); previewFile = null
        audioOwner = null; audioFiles = emptyList(); audioIds = emptyList(); audioIndex = 0
    }
    private fun audioStatus(owner: String): Map<String, Any?> = mapOf(
        "playing" to (audioOwner == owner && player != null),
        "id" to if (audioOwner == owner) audioIds.getOrNull(audioIndex) else null,
        "comparisonIndex" to if (audioOwner == owner && audioIds.size == 2) audioIndex + 1 else 0,
        "error" to if (lastAudioOwner == owner) lastAudioError else null)

    private data class Limits(val count: Int, val total: Long, val single: Int)
    private fun limits(a: Map<*, *>): Limits {
        val count = number(a["countLimit"] ?: 50, 1, 50).toInt()
        val single = number(a["singleLimit"] ?: MAX_BYTES, 1, MAX_BYTES.toLong()).toInt()
        val total = number(a["totalLimit"] ?: MAX_TOTAL, single.toLong(), MAX_TOTAL)
        return Limits(count, total, single)
    }
    private fun profile(a: Map<*, *>): String =
        (a["profileId"] as? String)?.takeIf(::validProfile)
            ?: throw IllegalArgumentException("Choose a valid lesson profile.")
    private fun validProfile(value: String) = value == "default" || Regex("^p_[a-f0-9]{24}$").matches(value)
    private fun clipId(value: Any?): String = (value as? String)?.takeIf { Regex("^[A-Za-z0-9_-]{22}$").matches(it) }
        ?: throw IllegalArgumentException("Choose a valid lesson recording.")
    private fun owner(a: Map<*, *>): String = (a["ownerId"] as? String)?.takeIf { Regex("^[A-Za-z0-9_-]{1,64}$").matches(it) }
        ?: throw IllegalArgumentException("Choose a valid playback session.")
    private fun validMime(value: String) = Regex("^audio/(webm|mp4|ogg|mpeg|wav)(?:;[A-Za-z0-9=, ._-]{1,60})?$").matches(value)
    private fun number(value: Any?, minimum: Long, maximum: Long): Long {
        val n = value as? Number ?: throw IllegalArgumentException("Invalid lesson recording metadata.")
        val long = n.toLong()
        require(long in minimum..maximum && n.toDouble() == long.toDouble()) { "Invalid lesson recording limits." }
        return long
    }
    private fun audioBytes(a: Map<*, *>, maximum: Int): ByteArray =
        (a["bytes"] as? ByteArray)?.takeIf { it.isNotEmpty() && it.size <= maximum }?.copyOf()
            ?: throw IllegalArgumentException("Lesson audio is empty or exceeds its limit.")
    private fun root(): File = File(activity.noBackupFilesDir, "reader_lessons").apply {
        require(isDirectory || mkdirs()) { "Private lesson storage is unavailable." }
    }
    private fun directory(profile: String, child: String): File {
        require(validProfile(profile)) { "Invalid lesson profile." }
        return File(File(root(), profile), child).apply {
            require(isDirectory || mkdirs()) { "Private lesson storage is unavailable." }
        }
    }
    private fun clips(profile: String) = directory(profile, "clips")
    private fun metadata(value: Map<*, *>?, profile: String): Map<String, Any?> {
        require(value != null && value["profileId"] == profile) { "The recording belongs to another profile." }
        val id = clipId(value["id"])
        val created = value["createdAt"] as? String ?: throw IllegalArgumentException("Invalid recording date.")
        require(created.length <= 40) { "Invalid recording date." }
        Instant.parse(created)
        val duration = number(value["durationMillis"], 0, MAX_DURATION)
        val bytes = number(value["bytes"], 1, MAX_BYTES.toLong())
        val mime = value["mimeType"] as? String ?: ""
        val label = value["label"] as? String ?: throw IllegalArgumentException("Invalid recording label.")
        val reference = value["reference"] as? String ?: throw IllegalArgumentException("Invalid recording reference.")
        require(validMime(mime) && label.length <= 120 && reference.length <= 120) { "Invalid recording metadata." }
        val chapter = value["chapterId"]?.let { number(it, 1, 114).toInt() }
        return mapOf("id" to id, "profileId" to profile, "createdAt" to created,
            "durationMillis" to duration, "bytes" to bytes, "mimeType" to mime,
            "label" to label, "reference" to reference, "chapterId" to chapter)
    }
    private fun readMetadata(profile: String, id: String): Map<String, Any?> {
        val file = File(clips(profile), "$id.json")
        require(file.isFile && file.length() in 1..16384) { "Lesson recording not found." }
        val json = JSONObject(file.readText(Charsets.UTF_8))
        val map = json.keys().asSequence().associateWith { key -> json.opt(key).takeUnless { it == JSONObject.NULL } }
        return metadata(map, profile).also { require(it["id"] == id) { "Invalid recording identifier." } }
    }
    private fun listClips(profile: String, limits: Limits): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        clips(profile).listFiles()?.filter { it.name.endsWith(".json") }?.forEach { file ->
            try {
                val id = clipId(file.name.removeSuffix(".json"))
                val metadata = readMetadata(profile, id)
                val audio = File(clips(profile), "$id.audio")
                if (audio.isFile && audio.length() == (metadata["bytes"] as Number).toLong() && audio.length() <= limits.single) results.add(metadata)
            } catch (_: Exception) { /* Keep unreadable private files; never treat them as another profile's recording. */ }
        }
        return results.sortedByDescending { Instant.parse(it["createdAt"] as String) }
    }
    private fun saveClip(profile: String, metadata: Map<String, Any?>, bytes: ByteArray, limits: Limits): Map<String, Any?> {
        val dir = clips(profile)
        val audioFiles = dir.listFiles()?.filter { it.name.endsWith(".audio") } ?: emptyList()
        require(audioFiles.size < limits.count && audioFiles.sumOf { it.length() } + bytes.size <= limits.total) {
            "Lesson storage is full. Delete an older lesson recording first."
        }
        val id = metadata["id"] as String
        val audio = File(dir, "$id.audio"); val json = File(dir, "$id.json")
        require(!audio.exists() && !json.exists()) { "This lesson recording is already saved." }
        val audioTemp = File.createTempFile("save_", ".pending", dir)
        val jsonTemp = File.createTempFile("meta_", ".pending", dir)
        try {
            FileOutputStream(audioTemp).use { it.write(bytes); it.fd.sync() }
            FileOutputStream(jsonTemp).use { it.write(JSONObject(metadata).toString().toByteArray(Charsets.UTF_8)); it.fd.sync() }
            require(audioTemp.renameTo(audio)) { "Lesson audio could not be saved." }
            if (!jsonTemp.renameTo(json)) {
                audio.delete()
                throw IllegalArgumentException("Lesson metadata could not be saved.")
            }
        } finally { audioTemp.delete(); jsonTemp.delete() }
        return metadata
    }
    private fun readAudio(file: File, maximum: Int): ByteArray {
        require(file.isFile && file.length() in 1..maximum.toLong()) { "Lesson recording not found." }
        val bytes = file.readBytes()
        require(bytes.isNotEmpty() && bytes.size <= maximum) { "Lesson audio exceeds its limit." }
        return bytes
    }
    private fun readClip(profile: String, id: String, maximum: Int): ByteArray {
        val metadata = readMetadata(profile, id)
        val bytes = readAudio(File(clips(profile), "$id.audio"), maximum)
        require(bytes.size.toLong() == (metadata["bytes"] as Number).toLong()) { "Lesson audio is incomplete." }
        return bytes
    }
    private fun safeError(error: Exception): String =
        if (error is IllegalArgumentException) error.message ?: "Invalid lesson recording."
        else "Lesson recording or private storage is unavailable."
    private fun <T> background(result: MethodChannel.Result, action: () -> T, complete: (T) -> Unit = { result.success(it) }) {
        if (disposed) { result.error("closed", "Lesson recording is closed.", null); return }
        worker.execute {
            try {
                synchronized(filesLock) { cleanupTemps() }
                val value = action()
                main.post {
                    if (disposed) {
                        if (value is File) value.delete()
                        result.error("closed", "Lesson recording is closed.", null)
                    } else {
                        try { complete(value) }
                        catch (error: Exception) { result.error("lesson_recording", safeError(error), null) }
                    }
                }
            } catch (error: Exception) { main.post { result.error("lesson_recording", safeError(error), null) } }
        }
    }

    fun onResume() {
        foreground = true
        if (permissionResult != null && (Build.VERSION.SDK_INT < 23 ||
            activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED)) startRecorder()
    }
    fun onPause() {
        foreground = false
        if (recorder != null) finishCapture()
        stopAudio()
    }
    fun onStop() {
        if (permissionResult != null) clearCapture()
    }
    fun onPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != MICROPHONE_PERMISSION || permissionResult == null) return
        if (grantResults.firstOrNull() != PackageManager.PERMISSION_GRANTED) {
            val result = permissionResult; permissionResult = null
            clearCapture()
            result?.error("microphone_permission", "Microphone permission was not granted.", null)
        } else if (foreground) startRecorder()
    }
    fun dispose() {
        disposed = true
        clearCapture()
        stopAudio()
        exportResult?.error("closed", "Lesson export was closed.", null)
        exportResult = null; exportFile = null
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }

    companion object {
        private val FILES_LOCK = Any()
        private const val MICROPHONE_PERMISSION = 23105
        private const val EXPORT_AUDIO = 23106
        private const val MAX_DURATION = 60000L
        private const val MAX_BYTES = 8 * 1024 * 1024
        private const val MAX_TOTAL = 100L * 1024 * 1024
    }
}
