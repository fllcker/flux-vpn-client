package rip.freeinternet.flux

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import libv2ray.Libv2ray

/**
 * Phase 2 skeleton (see the Android engine architecture plan) — exposes the
 * VpnService permission flow and start/stop of FluxVpnService over a
 * MethodChannel. Not wired into the Dart-side CoreEngine/ConnectionController
 * yet (Phase 3); nothing in the Flutter UI calls this channel today.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "flux/vpn"
    private val requestVpnPermissionCode = 4242
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Phase 1 smoke check (see tool/android-xray-lite) — proves libv2ray.aar
        // actually links and its Go-bound code runs.
        Log.i("Flux", "libv2ray xray-core version: " + Libv2ray.checkVersionX())
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "preparePermission" -> preparePermission(result)
                "start" -> {
                    val configJson = call.argument<String>("configJson")
                    val serverHost = call.argument<String>("serverHost")
                    val mtu = call.argument<Int>("mtu") ?: 1500
                    if (configJson == null || serverHost == null) {
                        result.error("bad_args", "configJson/serverHost required", null)
                    } else {
                        startVpn(configJson, serverHost, mtu)
                        result.success(null)
                    }
                }
                "stop" -> {
                    stopVpn()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Returns true (via [result]) if permission is already granted; otherwise
     * launches the system consent dialog and resolves [result] once the user
     * answers (see [onActivityResult]). */
    private fun preparePermission(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent == null) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        startActivityForResult(intent, requestVpnPermissionCode)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == requestVpnPermissionCode) {
            pendingPermissionResult?.success(resultCode == Activity.RESULT_OK)
            pendingPermissionResult = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun startVpn(configJson: String, serverHost: String, mtu: Int) {
        val intent = Intent(this, FluxVpnService::class.java).apply {
            putExtra(FluxVpnService.EXTRA_CONFIG_JSON, configJson)
            putExtra(FluxVpnService.EXTRA_SERVER_HOST, serverHost)
            putExtra(FluxVpnService.EXTRA_MTU, mtu)
        }
        startForegroundService(intent)
    }

    private fun stopVpn() {
        val intent = Intent(this, FluxVpnService::class.java).apply {
            action = FluxVpnService.ACTION_STOP
        }
        startService(intent)
    }
}
