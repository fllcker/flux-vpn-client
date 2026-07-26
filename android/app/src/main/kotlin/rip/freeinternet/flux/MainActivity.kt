package rip.freeinternet.flux

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import libv2ray.Libv2ray

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Phase 1 smoke check (see tool/android-xray-lite) — proves libv2ray.aar
        // actually links and its Go-bound code runs, nothing more. Replace with
        // the real CoreController/VpnService wiring in Phase 2.
        Log.i("Flux", "libv2ray xray-core version: " + Libv2ray.checkVersionX())
    }
}
