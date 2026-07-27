package rip.freeinternet.flux

import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.core.content.ContextCompat

/**
 * Android Quick Settings-плитка — включает/выключает VPN из шторки без
 * открытия приложения, как у WireGuard. Работает полностью нативно, в обход
 * Flutter: читает конфиг последнего успешного подключения, закэшированный
 * [FluxVpnService] (`FluxVpnService.PREFS_NAME`), и стартует/останавливает
 * сервис напрямую.
 *
 * Фоллбек на "просто открыть приложение" — в двух случаях: кэша ещё нет
 * (ни разу не подключались через приложение) или пользователь ещё не выдал
 * системное согласие на VPN (`VpnService.prepare` != null — без Activity
 * показать этот диалог из TileService нельзя).
 */
class FluxQuickTile : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()

        if (FluxVpnService.isRunning) {
            startService(
                Intent(this, FluxVpnService::class.java).apply {
                    action = FluxVpnService.ACTION_STOP
                },
            )
            return
        }

        val prefs = getSharedPreferences(FluxVpnService.PREFS_NAME, MODE_PRIVATE)
        val configJson = prefs.getString(FluxVpnService.PREF_CONFIG_JSON, null)
        val serverHost = prefs.getString(FluxVpnService.PREF_SERVER_HOST, null)
        val noCache = configJson == null || serverHost == null
        // VpnService.prepare возвращает non-null Intent, только пока согласие
        // ещё не выдано — без Activity показать этот системный диалог нельзя.
        val notConsented = VpnService.prepare(this) != null
        if (noCache || notConsented) {
            openApp()
            return
        }

        val intent = Intent(this, FluxVpnService::class.java).apply {
            putExtra(FluxVpnService.EXTRA_CONFIG_JSON, configJson)
            putExtra(FluxVpnService.EXTRA_SERVER_HOST, serverHost)
            putExtra(FluxVpnService.EXTRA_MTU, prefs.getInt(FluxVpnService.PREF_MTU, 1500))
            prefs.getString(FluxVpnService.PREF_SERVER_NAME, null)?.let {
                putExtra(FluxVpnService.EXTRA_SERVER_NAME, it)
            }
            prefs.getString(FluxVpnService.PREF_GEOIP_URL, null)?.let {
                putExtra(FluxVpnService.EXTRA_GEOIP_URL, it)
            }
            prefs.getString(FluxVpnService.PREF_GEOSITE_URL, null)?.let {
                putExtra(FluxVpnService.EXTRA_GEOSITE_URL, it)
            }
        }
        ContextCompat.startForegroundService(this, intent)
    }

    private fun openApp() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        // startActivityAndCollapse(Intent) is deprecated from API 34 in favor
        // of the PendingIntent overload (plain Intent no longer collapses the
        // shade reliably on newer Android) — branch on SDK to use whichever
        // one is actually supported.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                PendingIntent.getActivity(
                    this,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(launchIntent)
        }
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        val running = FluxVpnService.isRunning
        tile.state = if (running) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = "Flux"
        tile.subtitle = if (running) {
            getSharedPreferences(FluxVpnService.PREFS_NAME, MODE_PRIVATE)
                .getString(FluxVpnService.PREF_SERVER_NAME, null)
        } else {
            null
        }
        tile.updateTile()
    }
}
