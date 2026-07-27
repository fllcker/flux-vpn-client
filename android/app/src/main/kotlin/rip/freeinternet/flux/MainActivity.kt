package rip.freeinternet.flux

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes the VpnService permission flow, start/stop of FluxVpnService, and
 * its status/error stream to Dart — see xray_engine_android.dart, which is
 * the only consumer of both channels.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "flux/vpn"
    private val statusChannelName = "flux/vpn/status"
    private val deepLinkChannelName = "flux/deeplink"
    private val deepLinkEventChannelName = "flux/deeplink/stream"
    private val requestVpnPermissionCode = 4242
    private var pendingPermissionResult: MethodChannel.Result? = null

    // Повторные ссылки, пока приложение уже открыто, — см. onNewIntent
    // ниже (launchMode="singleTop" в AndroidManifest.xml гарантирует, что
    // ОС переиспользует эту же Activity вместо второй копии). Тот же
    // паттерн (nullable sink, живёт независимо от вызовов метода), что
    // VpnStatusBridge — тут не нужен отдельный top-level object, диплинк
    // всегда приходит именно в Activity, а не в оторванный от неё Service.
    private var deepLinkEventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Without this, POST_NOTIFICATIONS stays unrequested on API 33+ and
        // FluxVpnService's startForeground() notification just silently
        // doesn't show (the VPN itself keeps working either way — this is
        // only about the notification being visible).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 0)
            }
        }
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
                    val geoipUrl = call.argument<String>("geoipUrl")
                    val geositeUrl = call.argument<String>("geositeUrl")
                    if (configJson == null || serverHost == null) {
                        result.error("bad_args", "configJson/serverHost required", null)
                    } else {
                        startVpn(configJson, serverHost, mtu, geoipUrl, geositeUrl)
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
        // FluxVpnService runs detached from any Activity/MethodChannel call —
        // VpnStatusBridge is the only way for it to push async status/error
        // events (e.g. xray-core failing after startLoop already returned
        // successfully) back to XrayEngineAndroid's statusStream.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, statusChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    VpnStatusBridge.sink = events
                }

                override fun onCancel(arguments: Any?) {
                    VpnStatusBridge.sink = null
                }
            },
        )
        // flux://... — см. deep_link.dart. Холодный старт: intent.data уже
        // сидит на этой Activity к моменту первого вызова getInitialLink,
        // возвращаем один раз. Повторные ссылки, пока приложение уже
        // открыто, идут через onNewIntent -> deepLinkEventSink.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deepLinkChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> result.success(intent?.data?.toString())
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, deepLinkEventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    deepLinkEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    deepLinkEventSink = null
                }
            },
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.toString()?.let { deepLinkEventSink?.success(it) }
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

    private fun startVpn(
        configJson: String,
        serverHost: String,
        mtu: Int,
        geoipUrl: String?,
        geositeUrl: String?,
    ) {
        val intent = Intent(this, FluxVpnService::class.java).apply {
            putExtra(FluxVpnService.EXTRA_CONFIG_JSON, configJson)
            putExtra(FluxVpnService.EXTRA_SERVER_HOST, serverHost)
            putExtra(FluxVpnService.EXTRA_MTU, mtu)
            if (geoipUrl != null) putExtra(FluxVpnService.EXTRA_GEOIP_URL, geoipUrl)
            if (geositeUrl != null) putExtra(FluxVpnService.EXTRA_GEOSITE_URL, geositeUrl)
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
