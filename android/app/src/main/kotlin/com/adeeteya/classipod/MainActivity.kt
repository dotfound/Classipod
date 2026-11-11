package com.adeeteya.classipod

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import uk.dotfound.pixelpod.PixelPodKiosk

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PixelPodKiosk.attach(this, flutterEngine)
    }

    override fun onResume() {
        super.onResume()
        PixelPodKiosk.lock(this)
    }
}
