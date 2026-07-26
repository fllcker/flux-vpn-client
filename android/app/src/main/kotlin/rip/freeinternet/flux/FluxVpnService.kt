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
        val builder = Builder()
            .setSession("Flux")
            .setMtu(mtu)
            .addAddress("10.10.10.1", 30)
            .addDnsServer("1.1.1.1")
            .addDnsServer("8.8.8.8")
        for ((network, prefix) in RouteExclusion.ipv4RoutesExcluding(serverHost)) {
            builder.addRoute(network, prefix)
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
