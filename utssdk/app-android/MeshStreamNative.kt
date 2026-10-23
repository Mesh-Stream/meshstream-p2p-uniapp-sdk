package uts.sdk.modules.meshstreamP2p

import android.os.Handler
import android.os.Looper
import io.dcloud.uts.UTSAndroid
import io.meshstream.sdk.P2pClient
import io.meshstream.sdk.P2pConfig
import io.meshstream.sdk.P2pEventListener
import io.meshstream.sdk.P2pSdk
import io.meshstream.sdk.P2pStats
import io.meshstream.sdk.PlaybackOptions
import io.meshstream.sdk.PlaybackSession
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/** Native state is keyed by UTS-visible IDs so multiple players are isolated. */
object MeshStreamNative {
    private class ClientState(val client: P2pClient) {
        val sessions = ConcurrentHashMap<String, PlaybackSession>()
        val nativeSessionIds = ConcurrentHashMap<Long, String>()
        val pendingEvents = ConcurrentHashMap<Long, MutableList<JSONObject>>()
        var closed = false
    }

    private val clients = ConcurrentHashMap<String, ClientState>()
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var eventListener: ((String) -> Unit)? = null

    @JvmStatic fun getSdkVersion(): String = P2pSdk.version

    @JvmStatic fun setEventListener(listener: ((String) -> Unit)?) {
        eventListener = listener
    }

    @JvmStatic fun createClient(key: String, p2pEnabled: Boolean?): String {
        require(key.isNotBlank()) { "key must not be empty" }
        val context = requireNotNull(UTSAndroid.getAppContext()) { "Application context is unavailable" }
        val client = P2pSdk.create(context, P2pConfig(key = key, p2pEnabled = p2pEnabled ?: true))
        val clientId = UUID.randomUUID().toString()
        val state = ClientState(client)
        clients[clientId] = state
        client.addEventListener(listener(clientId, state))
        return JSONObject().put("clientId", clientId).put("status", statusJson(client.status)).toString()
    }

    @JvmStatic fun createPlaybackSession(clientId: String, optionsJson: String): String {
        val state = client(clientId)
        val options = JSONObject(optionsJson)
        val url = options.optString("url").trim()
        require(url.startsWith("https://") || url.startsWith("http://")) { "options.url must be an HTTP(S) URL" }
        val headers = linkedMapOf<String, String>()
        options.optJSONObject("originHeaders")?.let { source ->
            source.keys().forEach { name -> headers[name] = source.optString(name) }
        }
        val session = state.client.createPlaybackSession(url, PlaybackOptions(
            contentId = options.optString("contentId").takeIf { it.isNotBlank() },
            mimeType = options.optString("mimeType").takeIf { it.isNotBlank() },
            originHeaders = headers,
        ))
        val sessionId = UUID.randomUUID().toString()
        val pending = synchronized(state) {
            if (state.closed || clients[clientId] !== state) {
                session.close()
                error("Unknown or closed MeshStream client: $clientId")
            }
            state.sessions[sessionId] = session
            state.nativeSessionIds[session.sessionId] = sessionId
            state.pendingEvents.remove(session.sessionId)?.toList().orEmpty()
        }
        pending.forEach { emit(clientId, sessionId, state, it) }
        return JSONObject()
            .put("clientId", clientId)
            .put("sessionId", sessionId)
            .put("playbackUrl", session.playbackUrl)
            .put("playbackMode", session.playbackMode.name)
            .apply { session.fallbackReason?.let { put("fallbackReason", it.name) } }
            .toString()
    }

    @JvmStatic fun preload(clientId: String, sessionId: String): Boolean = session(clientId, sessionId).preload()
    @JvmStatic fun setP2pEnabled(clientId: String, sessionId: String, enabled: Boolean) = session(clientId, sessionId).setP2pEnabled(enabled)
    @JvmStatic fun updateBufferedDurationMs(clientId: String, sessionId: String, durationMs: Number) = session(clientId, sessionId).updateBufferedDurationMs(durationMs.toLong().coerceAtLeast(0))
    @JvmStatic fun updateCurrentPositionMs(clientId: String, sessionId: String, positionMs: Number) = session(clientId, sessionId).updateCurrentPositionMs(positionMs.toLong().coerceAtLeast(0))
    @JvmStatic fun getStatus(clientId: String): String = statusJson(client(clientId).client.status).toString()
    @JvmStatic fun getStats(clientId: String, sessionId: String): String = statsJson(session(clientId, sessionId).statistics()).toString()
    @JvmStatic fun getDiagnostics(clientId: String, sessionId: String): String = diagnosticsJson(session(clientId, sessionId).diagnostics()).toString()

    @JvmStatic fun closeSession(clientId: String, sessionId: String) {
        val state = clients[clientId] ?: return
        val session = synchronized(state) {
            state.sessions.remove(sessionId)?.also {
                state.nativeSessionIds.remove(it.sessionId)
                state.pendingEvents.remove(it.sessionId)
            }
        }
        session?.close()
    }

    @JvmStatic fun closeClient(clientId: String) {
        clients.remove(clientId)?.let { state ->
            val sessions = synchronized(state) {
                if (state.closed) return
                state.closed = true
                state.sessions.values.toList().also {
                    state.sessions.clear()
                    state.nativeSessionIds.clear()
                    state.pendingEvents.clear()
                }
            }
            sessions.forEach { it.close() }
            state.client.close()
        }
    }

    private fun client(clientId: String): ClientState = clients[clientId] ?: error("Unknown or closed MeshStream client: $clientId")
    private fun session(clientId: String, sessionId: String): PlaybackSession = client(clientId).sessions[sessionId] ?: error("Unknown or closed MeshStream session: $sessionId")

    private fun listener(clientId: String, state: ClientState) = object : P2pEventListener {
        private fun event(nativeId: Long, type: String, payload: JSONObject = JSONObject()) {
            val sessionId = synchronized(state) {
                if (state.closed || clients[clientId] !== state) return
                payload.put("type", type)
                val currentSessionId = state.nativeSessionIds[nativeId]
                if (currentSessionId == null && state.pendingEvents.size < 64) {
                    state.pendingEvents.getOrPut(nativeId) { mutableListOf() }.let { if (it.size < 8) it += payload }
                }
                currentSessionId
            }
            if (sessionId != null) emit(clientId, sessionId, state, payload)
        }
        override fun onStatistics(sessionId: Long, stats: P2pStats) = event(sessionId, "statistics", JSONObject().put("statistics", statsJson(stats)))
        override fun onPeerCountChanged(sessionId: Long, peerCount: Int) = event(sessionId, "peerCountChanged", JSONObject().put("peerCount", peerCount))
        override fun onPlaybackPrepared(sessionId: Long, playbackUrl: String) = event(sessionId, "playbackPrepared", JSONObject().put("playbackUrl", playbackUrl))
        override fun onP2pReady(sessionId: Long) = event(sessionId, "p2pReady")
        override fun onP2pUnavailable(sessionId: Long, reason: io.meshstream.sdk.P2pUnavailableReason) = event(sessionId, "p2pUnavailable", JSONObject().put("reason", reason.name))
        override fun onTrackerError(sessionId: Long, totalErrors: Long) = event(sessionId, "trackerError", JSONObject().put("totalErrors", totalErrors))
        override fun onPeerConnectError(sessionId: Long, totalErrors: Long) = event(sessionId, "peerConnectError", JSONObject().put("totalErrors", totalErrors))
        override fun onCdnFallback(sessionId: Long, bytes: Long) = event(sessionId, "cdnFallback", JSONObject().put("bytes", bytes))
    }

    private fun emit(clientId: String, sessionId: String, state: ClientState, event: JSONObject) {
        event.put("clientId", clientId).put("sessionId", sessionId)
        mainHandler.post {
            val active = synchronized(state) {
                !state.closed && clients[clientId] === state && state.sessions.containsKey(sessionId)
            }
            if (active) eventListener?.invoke(event.toString())
        }
    }

    private fun statusJson(status: io.meshstream.sdk.P2pSdkStatus) = JSONObject()
        .put("accountEnabled", status.accountEnabled).put("applicationEnabled", status.applicationEnabled)
        .put("keyEnabled", status.keyEnabled).put("platformEnabled", status.platformEnabled)
        .put("effectiveP2pEnabled", status.effectiveP2pEnabled).put("reason", status.reason.name)
        .apply { status.configVersion?.let { put("configVersion", it) }; status.edgeRegion?.let { put("edgeRegion", it) }; status.quotaStatus?.let { put("quotaStatus", it) }; status.trackerPoolReady?.let { put("trackerPoolReady", it) } }

    private fun statsJson(stats: P2pStats) = JSONObject()
        .put("httpDownloaded", stats.httpDownloaded).put("p2pDownloaded", stats.p2pDownloaded).put("p2pUploaded", stats.p2pUploaded)
        .put("httpSegmentDownloadSuccesses", stats.httpSegmentDownloadSuccesses).put("httpSegmentDownloadFailures", stats.httpSegmentDownloadFailures)
        .put("p2pSegmentDownloadSuccesses", stats.p2pSegmentDownloadSuccesses).put("p2pSegmentDownloadFailures", stats.p2pSegmentDownloadFailures)
        .put("p2pSegmentUploadSuccesses", stats.p2pSegmentUploadSuccesses).put("p2pSegmentUploadFailures", stats.p2pSegmentUploadFailures)
        .put("connectedPeers", stats.connectedPeers).put("peerConnectErrors", stats.peerConnectErrors).put("trackerErrors", stats.trackerErrors)
        .put("downloadOffloadRatio", stats.downloadOffloadRatio).put("p2pSegmentDownloadSuccessRatio", stats.p2pSegmentDownloadSuccessRatio).put("p2pSegmentUploadSuccessRatio", stats.p2pSegmentUploadSuccessRatio)

    private fun diagnosticsJson(value: io.meshstream.sdk.P2pDiagnosticsSnapshot) = JSONObject()
        .put("fallbackCount", value.fallbackCount).put("iceAttempts", value.iceAttempts).put("iceSuccesses", value.iceSuccesses).put("iceFailures", value.iceFailures).put("iceDurationMs", value.iceDurationMs)
        .apply {
            value.firstPeerConnectMs?.let { put("firstPeerConnectMs", it) }
            value.coldStart?.let { put("coldStart", JSONObject().put("p2pDownloaded", it.p2pDownloaded).put("httpDownloaded", it.httpDownloaded)) }
            value.lastTrackerError?.let { put("lastTrackerError", it) }; value.lastPeerError?.let { put("lastPeerError", it) }; value.lastErrorAtMs?.let { put("lastErrorAtMs", it) }
        }
}
