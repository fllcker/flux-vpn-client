package rip.freeinternet.flux

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.service.quicksettings.TileService
import android.util.Log
import androidx.core.app.NotificationCompat
import go.Seq
import java.io.File
import java.net.URL
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
        const val EXTRA_SERVER_NAME = "serverName"
        const val EXTRA_MTU = "mtu"
        const val EXTRA_GEOIP_URL = "geoipUrl"
        const val EXTRA_GEOSITE_URL = "geositeUrl"
        // Тот же апстрим, что и дефолт в lib/core_abstraction/app_settings.dart
        // (`defaultGeoipUrl`/`defaultGeositeUrl`) — держать в синхроне вручную,
        // общего конфига ради двух строк заводить не стали (см. ROADMAP.md,
        // трек 20).
        private const val DEFAULT_GEOIP_URL =
            "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
        private const val DEFAULT_GEOSITE_URL =
            "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
        private const val NOTIFICATION_CHANNEL_ID = "flux_vpn"
        private const val NOTIFICATION_ID = 1
        private const val TAG = "FluxVpnService"

        // Кэш последнего успешного подключения — не часть Flutter/Dart вовсе,
        // читается и пишется полностью нативно, чтобы Quick Settings-плитка
        // (`FluxQuickTile.kt`, ROADMAP.md — Android Quick Settings Tile) могла
        // поднять/погасить тоннель без открытия приложения и без Flutter-
        // движка. Пишется в onStartCommand на каждый реальный старт (в т.ч.
        // если стартовала сама плитка из уже сохранённых значений —
        // идемпотентно, ничего не меняется).
        const val PREFS_NAME = "flux_last_connection"
        const val PREF_CONFIG_JSON = "configJson"
        const val PREF_SERVER_HOST = "serverHost"
        const val PREF_SERVER_NAME = "serverName"
        const val PREF_MTU = "mtu"
        const val PREF_GEOIP_URL = "geoipUrl"
        const val PREF_GEOSITE_URL = "geositeUrl"

        // Плитка не может биндиться напрямую к работающему Service, чтобы
        // узнать состояние — читает этот флаг (тот же процесс, один class
        // loader) и просит систему обновить себя через requestTileUpdate,
        // когда флаг меняется вне собственного onClick/onStartListening.
        @Volatile
        var isRunning: Boolean = false
            private set

        private fun requestTileUpdate(context: Context) {
            TileService.requestListeningState(
                context,
                ComponentName(context, FluxQuickTile::class.java),
            )
        }
    }

    private var tunInterface: ParcelFileDescriptor? = null
    private var coreController: CoreController? = null
    private var activeServerName: String? = null

    override fun onCreate() {
        super.onCreate()
        // golang.org/x/mobile/asset needs the JavaVM + Context registered
        // explicitly for gomobile's Android bindings in general — required by
        // libv2ray regardless of where geoip.dat/geosite.dat come from (those
        // are fetched over the network now, see ensureGeoAssetsExtracted, not
        // read through this asset bridge anymore).
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
        val serverName = intent?.getStringExtra(EXTRA_SERVER_NAME)
        val mtu = intent?.getIntExtra(EXTRA_MTU, 1500) ?: 1500
        val geoipUrl = intent?.getStringExtra(EXTRA_GEOIP_URL) ?: DEFAULT_GEOIP_URL
        val geositeUrl = intent?.getStringExtra(EXTRA_GEOSITE_URL) ?: DEFAULT_GEOSITE_URL
        if (configJson == null || serverHost == null) {
            Log.e(TAG, "Missing configJson/serverHost extras, stopping")
            stopSelf()
            return START_NOT_STICKY
        }
        activeServerName = serverName
        cacheLastConnection(configJson, serverHost, serverName, mtu, geoipUrl, geositeUrl)

        startForeground(NOTIFICATION_ID, buildNotification())
        Log.d(TAG, "configJson: $configJson")
        // ensureGeoAssetsExtracted now does a network fetch (see below) —
        // startTunnel can no longer run synchronously on whatever thread
        // onStartCommand is called on (that's the main thread, and blocking
        // network I/O there trips StrictMode's NetworkOnMainThreadException).
        Thread {
            try {
                startTunnel(configJson, serverHost, mtu, geoipUrl, geositeUrl)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start tunnel", e)
                VpnStatusBridge.emitError(e.message)
                stopTunnel()
                stopSelf()
            }
        }.start()
        return START_STICKY
    }

    private fun startTunnel(
        configJson: String,
        serverHost: String,
        mtu: Int,
        geoipUrl: String,
        geositeUrl: String,
    ) {
        // xray-core resolves geoip.dat/geosite.dat with a plain os.Stat/os.Open
        // against a real filesystem path *before* NewFileReader/mobile-asset
        // hooks ever get a chance to run (common/platform/filesystem.
        // getAssetFileLocation calls os.Stat directly) — so InitCoreEnv/
        // Seq.setContext alone can't make it read the .dat files bundled
        // inside libv2ray.aar's assets/ (those are only reachable via
        // Android's AssetManager, which isn't a real path). Extract them to
        // a real file once and point xray.location.asset there instead.
        Libv2ray.initCoreEnv(ensureGeoAssetsExtracted(geoipUrl, geositeUrl).absolutePath, "")

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
            // startup/onEmitStatus are lifecycle markers, not a running
            // health monitor — libv2ray_main.go only calls Startup() +
            // OnEmitStatus(0, "Started successfully, running") once xray has
            // already initialized. Shutdown() is never actually invoked by
            // this AAR version (checked tool/android-xray-lite/src —
            // StopLoop() only calls OnEmitStatus, not CallbackHandler.
            // Shutdown()), so "stopped" is emitted from our own
            // stopTunnel() below instead. Anything that fails *before*
            // Startup() comes back as an exception from startLoop() below
            // (caught in onStartCommand), not through this callback.
            override fun startup(): Long {
                Log.i(TAG, "xray-core started")
                isRunning = true
                requestTileUpdate(applicationContext)
                VpnStatusBridge.emitStarted()
                return 0
            }

            override fun shutdown(): Long {
                Log.i(TAG, "xray-core stopped (Shutdown callback)")
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
        val wasRunning = coreController != null
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
        activeServerName = null
        if (wasRunning) {
            isRunning = false
            requestTileUpdate(applicationContext)
            VpnStatusBridge.emitStopped()
        }
    }

    /** Пишется на каждый реальный старт (включая старт самой плиткой из уже
     * сохранённых значений — идемпотентно). См. doc-комментарий у [PREFS_NAME]. */
    private fun cacheLastConnection(
        configJson: String,
        serverHost: String,
        serverName: String?,
        mtu: Int,
        geoipUrl: String,
        geositeUrl: String,
    ) {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit()
            .putString(PREF_CONFIG_JSON, configJson)
            .putString(PREF_SERVER_HOST, serverHost)
            .putString(PREF_SERVER_NAME, serverName)
            .putInt(PREF_MTU, mtu)
            .putString(PREF_GEOIP_URL, geoipUrl)
            .putString(PREF_GEOSITE_URL, geositeUrl)
            .apply()
    }

    /** Downloads geoip.dat/geosite.dat into a real file the first time, and
     * reuses it after — both files together are several MB, not something to
     * redo on every connect. Used to extract from the app's assets (merged in
     * from libv2ray.aar); now fetched at runtime instead, same as the Windows
     * side (`lib/engines/geo_assets.dart`, ROADMAP.md трек 20) — independent
     * of libv2ray.aar's own bundled copies and updatable without a rebuild. */
    private fun ensureGeoAssetsExtracted(geoipUrl: String, geositeUrl: String): File {
        val dir = File(filesDir, "xray-assets")
        dir.mkdirs()
        for ((name, url) in arrayOf("geoip.dat" to geoipUrl, "geosite.dat" to geositeUrl)) {
            val dest = File(dir, name)
            if (dest.exists()) continue
            val tmp = File(dir, "$name.tmp")
            URL(url).openStream().use { input ->
                tmp.outputStream().use { output -> input.copyTo(output) }
            }
            tmp.renameTo(dest)
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
            .setContentText(activeServerName?.let { "VPN connected — $it" } ?: "VPN connected")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()
    }
}
