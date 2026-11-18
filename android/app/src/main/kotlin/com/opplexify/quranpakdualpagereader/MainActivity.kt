package com.opplexify.quranpakdualpagereader

import android.content.Intent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    private var prayerBridge: PrayerPlatformBridge? = null
    private var recordingBridge: ReaderRecordingBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        prayerBridge = PrayerPlatformBridge(this, flutterEngine)
        recordingBridge = ReaderRecordingBridge(this, flutterEngine)
    }

    override fun onResume() {
        super.onResume()
        prayerBridge?.onResume()
        recordingBridge?.onResume()
    }

    override fun onPause() {
        recordingBridge?.onPause()
        super.onPause()
    }

    override fun onStop() {
        recordingBridge?.onStop()
        super.onStop()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        recordingBridge?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        prayerBridge?.onPermissionsResult(requestCode, grantResults)
        recordingBridge?.onPermissionsResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        recordingBridge?.dispose()
        recordingBridge = null
        prayerBridge?.dispose()
        prayerBridge = null
        super.onDestroy()
    }
}
