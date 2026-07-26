package rip.freeinternet.flux

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * FluxVpnService (a Service, not tied to any single MethodChannel call) needs
 * a way to push async status/error events to Dart — e.g. xray-core failing
 * *after* CoreController.startLoop already returned successfully, which
 * XrayEngineAndroid's optimistic "connected" status (set right after the
 * initial `start` MethodChannel call succeeds) can't see on its own. This is
 * a process-wide singleton because the Service and MainActivity's
 * EventChannel.StreamHandler are otherwise unrelated objects.
 */
object VpnStatusBridge {
    var sink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /** [EventSink] methods must be called on the platform thread —
     * CoreCallbackHandler callbacks arrive from Go/native threads. */
    private fun emit(event: Map<String, Any?>) {
        mainHandler.post { sink?.success(event) }
    }

    fun emitStarted() = emit(mapOf("event" to "started"))

    fun emitStopped() = emit(mapOf("event" to "stopped"))

    fun emitError(message: String?) = emit(mapOf("event" to "error", "message" to message))
}
