package com.adeeteya.classipod

import android.os.Bundle
import android.os.Process
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import uk.dotfound.pixelpod.PixelPodKiosk

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // A background podcast sync can start this process with no screen,
        // and the audio plugin then boots the app headless. Attaching a
        // screen to that engine renders black, so start again in a clean
        // process instead. PixelPod is the home app, so Android relaunches
        // it straight away.
        val startedHeadless = !hadActivity &&
            FlutterEngineCache.getInstance().contains(AUDIO_ENGINE_ID)
        hadActivity = true
        super.onCreate(savedInstanceState)
        if (startedHeadless) {
            finish()
            startActivity(intent)
            Process.killProcess(Process.myPid())
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PixelPodKiosk.attach(this, flutterEngine)
    }

    override fun onResume() {
        super.onResume()
        PixelPodKiosk.lock(this)
    }

    companion object {
        private const val AUDIO_ENGINE_ID = "audio_service_engine"
        private var hadActivity = false
    }
}
