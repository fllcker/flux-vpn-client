package rip.freeinternet.flux

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import go.Seq
import java.io.File
import libv2ray.CoreCallbackHandler
import libv2ray.CoreController
import libv2ray.Libv2ray

/**
 * Phase 2 skeleton (see the Android engine architecture plan) — establishes a
 * TUN via VpnService and hands its fd straight to xray-core's own `tun`
 * inbound (gVisor-based netstack, see proxy/tun/tun_android.go in xray-core —
 * no separate tun2socks process needed, unlike the Windows sing-box bridge).
 * Not wired into ConnectionController/CoreEngine yet — that's Phase 3.
 */
class FluxVpnService : VpnService() {
    companion object {
        const val ACTION_STOP = "rip.freeinternet.flux.STOP_VPN"
        const val EXTRA_CONFIG_JSON = "configJson"
        const val EXTRA_SERVER_HOST = "serverHost"
        const val EXTRA_MTU = "mtu"
        private const val NOTIFICATION_CHANNEL_ID = "flux_vpn"
        private const val NOTIFICATION_ID = 1
        private const val TAG = "FluxVpnService"
    }

    private var tunInterface: ParcelFileDescriptor? = null
    private var coreController: CoreController? = null

    override fun onCreate() {
        super.onCreate()
        // golang.org/x/mobile/asset (used by xray-core's NewFileReader fallback
        // to reach geoip.dat/geosite.dat bundled inside libv2ray.aar's assets/)
        // needs the JavaVM + Context registered explicitly — without this call
        // it silently has no AssetManager and every asset lookup fails as if
        // the file didn't exist.
        Seq.setContext(applicationContext)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopTunnel()
            stopSelf()
            return START_NOT_STICKY
        }

        val configJson = intent?.getStringExtra(EXTRA_CONFIG_JSON)
        val serverHost = intent?.getStringExtra(EXTRA_SERVER_HOST)
        val mtu = intent?.getIntExtra(EXTRA_MTU, 1500) ?: 1500
        if (configJson == null || serverHost == null) {
            Log.e(TAG, "Missing configJson/serverHost extras, stopping")
            stopSelf()
            return START_NOT_STICKY
        }

        startForeground(NOTIFICATION_ID, buildNotification())
        try {
            startTunnel(configJson, serverHost, mtu)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start tunnel", e)
            stopTunnel()
            stopSelf()
        }
        return START_STICKY
    }

    private fun startTunnel(configJson: String, serverHost: String, mtu: Int) {
        // xray-core resolves geoip.dat/geosite.dat with a plain os.Stat/os.Open
        // against a real filesystem path *before* NewFileReader/mobile-asset
        // hooks ever get a chance to run (common/platform/filesystem.
        // getAssetFileLocation calls os.Stat directly) — so InitCoreEnv/
        // Seq.setContext alone can't make it read the .dat files bundled
        // inside libv2ray.aar's assets/ (those are only reachable via
        // Android's AssetManager, which isn't a real path). Extract them to
        // a real file once and point xray.location.asset there instead.
        Libv2ray.initCoreEnv(ensureGeoAssetsExtracted().absolutePath, "")

        val builder = Builder()
            .setSession("Flux")
            .setMtu(mtu)
            .addAddress("10.10.10.1", 30)
            .addDnsServer("1.1.1.1")
            .addDnsServer("8.8.8.8")
        for ((network, prefix) in RouteExclusion.ipv4RoutesExcluding(serverHost)) {
            builder.addRoute(network, prefix)
        }
        try {
            // Without this, xray-core's own outbound connections — both to
            // the VLESS/Hysteria2 server (RouteExclusion covers only this
            // one case) and to "direct"-routed destinations picked by
            // routing rules (any arbitrary IP, can't be pre-excluded) — are
            // themselves subject to this same VPN and loop back into the
            // tun. Excluding our own app is what real VPN apps do for their
            // own core process; it also means RouteExclusion above is now
            // mostly a defense-in-depth belt-and-suspenders, not the only
            // thing preventing the proxy-dial loop.
            builder.addDisallowedApplication(packageName)
        } catch (e: android.content.pm.PackageManager.NameNotFoundException) {
            Log.w(TAG, "addDisallowedApplication(self) failed", e)
        }
        val pfd = builder.establish()
            ?: throw IllegalStateException("VpnService.Builder.establish() returned null — permission not granted?")
        tunInterface = pfd

        val controller = Libv2ray.newCoreController(object : CoreCallbackHandler {
            override fun startup(): Long {
                Log.i(TAG, "xray-core started")
                return 0
            }

            override fun shutdown(): Long {
                Log.i(TAG, "xray-core stopped")
                return 0
            }

            override fun onEmitStatus(code: Long, message: String?): Long {
                Log.i(TAG, "xray-core status $code: $message")
                return 0
            }
        })
        coreController = controller
        controller.startLoop(configJson, pfd.fd)
    }

    private fun stopTunnel() {
        try {
            coreController?.stopLoop()
        } catch (e: Exception) {
            Log.w(TAG, "stopLoop failed", e)
        }
        coreController = null
        try {
            tunInterface?.close()
        } catch (e: Exception) {
            Log.w(TAG, "closing tun fd failed", e)
        }
        tunInterface = null
    }

    /** Copies geoip.dat/geosite.dat out of the app's assets (merged in from
     * libv2ray.aar) into a real file the first time, and reuses it after —
     * both files together are ~27MB, not something to redo on every connect. */
    private fun ensureGeoAssetsExtracted(): File {
        val dir = File(filesDir, "xray-assets")
        dir.mkdirs()
        for (name in arrayOf("geoip.dat", "geosite.dat")) {
            val dest = File(dir, name)
            if (dest.exists()) continue
            assets.open(name).use { input ->
                dest.outputStream().use { output -> input.copyTo(output) }
            }
        }
        return dir
    }

    override fun onRevoke() {
        // User pulled the "always-on VPN"/system VPN-off switch outside the app.
        stopTunnel()
        stopSelf()
        super.onRevoke()
    }

    override fun onDestroy() {
        stopTunnel()
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Flux VPN",
                NotificationManager.IMPORTANCE_LOW,
            )
            manager.createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Flux")
            .setContentText("VPN connected")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()
    }
}
