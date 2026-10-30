<template>
  <scroll-view class="page" scroll-y>
    <view class="header">
      <text class="title">MeshStream P2P</text>
      <text class="subtitle">uni-app App verification</text>
    </view>

    <view class="panel">
      <text class="label">SDK Key</text>
      <input v-model="sdkKey" class="input" placeholder="key_..." placeholder-class="placeholder" />
      <text class="label">Media URL</text>
      <input v-model="mediaUrl" class="input" placeholder="https://example.com/live.m3u8" placeholder-class="placeholder" />
      <text class="label">Content ID (optional)</text>
      <input v-model="contentId" class="input" placeholder="Use the same ID on Web and App" placeholder-class="placeholder" />
      <button class="primary" :disabled="working" @click="start">{{ working ? 'Working...' : 'Create session' }}</button>
      <text v-if="error" class="error">{{ error }}</text>
    </view>

    <view v-if="playbackUrl" class="panel">
      <text class="section-title">Playback</text>
      <video
        class="video"
        :src="playbackUrl"
        autoplay
        controls
        @timeupdate="onTimeUpdate"
        @progress="onProgress"
        @error="onPlayerError"
      />
      <text class="url" selectable>{{ playbackUrl }}</text>
      <button class="danger" :disabled="working" @click="stop">Close session</button>
    </view>

    <view v-if="stats || diagnostics" class="panel">
      <text class="section-title">Telemetry</text>
      <view v-if="status" class="metric"><text>SDK status</text><text>{{ statusText }}</text></view>
      <view class="metric"><text>Mode</text><text>{{ playbackMode || '-' }}</text></view>
      <view class="metric"><text>Peers</text><text>{{ numberField(stats, 'connectedPeers') }}</text></view>
      <view class="metric"><text>P2P download</text><text>{{ bytesField(stats, 'p2pDownloaded') }}</text></view>
      <view class="metric"><text>CDN download</text><text>{{ bytesField(stats, 'httpDownloaded') }}</text></view>
      <view class="metric"><text>Offload</text><text>{{ ratioField(stats, 'downloadOffloadRatio') }}</text></view>
      <view class="metric"><text>Fallback reason</text><text>{{ fallbackReason || 'none' }}</text></view>
      <view class="metric"><text>Fallbacks</text><text>{{ numberField(diagnostics, 'fallbackCount') }}</text></view>
      <view class="metric"><text>Diagnostics</text><text>{{ diagnosticsText }}</text></view>
    </view>

    <view class="panel">
      <text class="section-title">Events</text>
      <text v-if="logs.length === 0" class="muted">Events appear after a playback session is created.</text>
      <text v-for="entry in logs" :key="entry.id" class="log">{{ entry.text }}</text>
    </view>
  </scroll-view>
</template>

<script setup>
import { computed, onBeforeUnmount, ref } from 'vue'
import { MeshStream } from '@/uni_modules/meshstream-p2p/javascript.js'

const sdkKey = ref('')
// Keep the native demo on the same stream as apps/web-demo so both clients
// derive the same swarm when no explicit content ID is supplied.
const mediaUrl = ref('https://test-streams.mux.dev/x36xhzz/url_2/193039199_mp4_h264_aac_ld_7.m3u8')
const contentId = ref('')
const playbackUrl = ref('')
const playbackMode = ref('')
const fallbackReason = ref('')
const stats = ref(null)
const diagnostics = ref(null)
const status = ref(null)
const logs = ref([])
const working = ref(false)
const error = ref('')

let client = null
let session = null
let removeEvents = null
let statsTimer = null
let lastPositionReportAt = 0
let lastBufferReportAt = 0

const diagnosticsText = computed(() => {
  if (!diagnostics.value) return 'loading'
  const tracker = textField(diagnostics.value, 'lastTrackerError') || 'none'
  const peer = textField(diagnostics.value, 'lastPeerError') || 'none'
  return `tracker ${tracker}, peer ${peer}`
})

const statusText = computed(() => {
  if (!status.value) return 'loading'
  const reason = textField(status.value, 'reason') || 'UNKNOWN'
  const enabled = field(status.value, 'effectiveP2pEnabled')
  const pool = field(status.value, 'trackerPoolReady')
  const version = textField(status.value, 'configVersion') || 'none'
  return `${reason}; enabled=${String(enabled)}; pool=${String(pool)}; config=${version}`
})

function appendLog(text) {
  logs.value.unshift({ id: `${Date.now()}-${Math.random()}`, text: `${new Date().toLocaleTimeString()}  ${text}` })
  logs.value = logs.value.slice(0, 60)
}

function field(value, name) {
  if (!value) return null
  if (typeof value.get === 'function') return value.get(name)
  return value[name]
}

function textField(value, name) {
  if (!value) return null
  if (typeof value.getString === 'function') return value.getString(name)
  const result = field(value, name)
  return result == null ? null : String(result)
}

function numberField(value, name) {
  if (!value) return 0
  if (typeof value.getNumber === 'function') return value.getNumber(name) || 0
  const result = Number(field(value, name))
  return Number.isFinite(result) ? result : 0
}

function bytesField(value, name) {
  const bytes = numberField(value, name)
  if (bytes < 1024) return `${Math.round(bytes)} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

function ratioField(value, name) {
  return `${Math.round(numberField(value, name) * 100)}%`
}

async function refreshTelemetry() {
  const activeClient = client
  const activeSession = session
  if (!activeClient || !activeSession) return
  const [nextStats, nextDiagnostics] = await Promise.all([
    MeshStream.getStats(activeClient.clientId, activeSession.sessionId),
    MeshStream.getDiagnostics(activeClient.clientId, activeSession.sessionId),
  ])
  const nextStatus = await MeshStream.getStatus(activeClient.clientId)
  if (client !== activeClient || session !== activeSession) return
  stats.value = nextStats
  diagnostics.value = nextDiagnostics
  status.value = nextStatus
}

async function releaseResources() {
  const currentSession = session
  const currentClient = client
  if (statsTimer) clearInterval(statsTimer)
  statsTimer = null
  session = null
  client = null
  removeEvents?.()
  removeEvents = null
  playbackUrl.value = ''
  playbackMode.value = ''
  fallbackReason.value = ''
  stats.value = null
  diagnostics.value = null
  status.value = null
  lastPositionReportAt = 0
  lastBufferReportAt = 0

  let firstError = null
  try {
    if (currentSession && currentClient) await MeshStream.closeSession(currentClient.clientId, currentSession.sessionId)
  } catch (caught) {
    firstError = caught
  }
  try {
    if (currentClient) await MeshStream.closeClient(currentClient.clientId)
  } catch (caught) {
    if (!firstError) firstError = caught
  }
  if (firstError) throw firstError
}

async function start() {
  if (!sdkKey.value.trim() || !mediaUrl.value.trim()) {
    uni.showToast({ title: 'Enter an SDK Key and media URL', icon: 'none' })
    return
  }
  working.value = true
  error.value = ''
  try {
    await releaseResources()
    client = await MeshStream.create({ key: sdkKey.value.trim(), p2pEnabled: true })
    const subscriptionId = MeshStream.subscribeEvents((event) => {
      if (textField(event, 'clientId') !== client?.clientId) return
      if (textField(event, 'sessionId') !== session?.sessionId) return
      const type = textField(event, 'type') || 'event'
      if (type === 'statistics') stats.value = field(event, 'statistics')
      if (type === 'p2pReady') {
        playbackMode.value = 'NATIVE_P2P'
        fallbackReason.value = ''
      }
      if (type === 'p2pUnavailable') {
        playbackMode.value = 'NATIVE_CDN'
        fallbackReason.value = textField(event, 'reason') || 'UNAVAILABLE'
      }
      if (type === 'trackerError' || type === 'peerConnectError') {
        appendLog(`${type}: ${numberField(event, 'totalErrors')}`)
      } else {
        appendLog(type === 'p2pUnavailable' ? `${type}: ${textField(event, 'reason')}` : type)
      }
    })
    removeEvents = () => MeshStream.unsubscribeEvents(subscriptionId)
    session = await MeshStream.createPlaybackSession(client.clientId, {
      url: mediaUrl.value.trim(),
      ...(contentId.value.trim() ? { contentId: contentId.value.trim() } : {}),
      mimeType: mediaUrl.value.includes('.mpd') ? 'mpd' : 'm3u8',
    })
    playbackUrl.value = session.playbackUrl
    playbackMode.value = session.playbackMode
    fallbackReason.value = session.fallbackReason || ''
    statsTimer = setInterval(() => {
      refreshTelemetry().catch((refreshError) => { error.value = String(refreshError) })
    }, 2000)
    await refreshTelemetry()
    appendLog(`session created (${session.playbackMode})`)
  } catch (caught) {
    const message = String(caught)
    appendLog(`create failed: ${message}`)
    error.value = message
    await releaseResources()
    uni.showToast({ title: 'Unable to create playback session', icon: 'none' })
  } finally {
    working.value = false
  }
}

async function stop() {
  working.value = true
  try {
    await releaseResources()
    appendLog('session closed')
  } catch (caught) {
    const message = `close failed: ${String(caught)}`
    error.value = message
    appendLog(message)
  } finally {
    working.value = false
  }
}

function onTimeUpdate(event) {
  const now = Date.now()
  if (!session || now - lastPositionReportAt < 1000) return
  lastPositionReportAt = now
  if (client && session) MeshStream.updateCurrentPositionMs(client.clientId, session.sessionId, Math.round((event.detail.currentTime || 0) * 1000)).catch(() => {})
}

function onProgress(event) {
  const now = Date.now()
  if (!session || now - lastBufferReportAt < 1000) return
  lastBufferReportAt = now
  const current = event.detail.currentTime || 0
  const buffered = event.detail.buffered || current
  if (client && session) MeshStream.updateBufferedDurationMs(client.clientId, session.sessionId, Math.max(0, Math.round((buffered - current) * 1000))).catch(() => {})
}

function onPlayerError(event) {
  const message = `player error: ${JSON.stringify(event.detail)}`
  error.value = message
  appendLog(message)
}

onBeforeUnmount(() => { releaseResources().catch(() => {}) })
</script>

<style scoped>
.page { box-sizing: border-box; min-height: 100vh; padding: 24rpx; }
.header { margin: 12rpx 0 28rpx; }
.title { color: #f8fafc; display: block; font-size: 48rpx; font-weight: 700; }
.subtitle { color: #94a3b8; display: block; font-size: 26rpx; margin-top: 8rpx; }
.panel { background: #172033; border: 1rpx solid #334155; margin-bottom: 20rpx; padding: 24rpx; }
.label { color: #dbeafe; display: block; font-size: 26rpx; margin: 16rpx 0 10rpx; }
.input { background: #0f172a; border: 1rpx solid #475569; box-sizing: border-box; color: #f8fafc; font-size: 28rpx; height: 76rpx; padding: 0 18rpx; width: 100%; }
.placeholder { color: #64748b; }
.primary, .danger { border: 0; border-radius: 6rpx; color: #fff; font-size: 28rpx; margin: 28rpx 0 0; }
.primary { background: #1677c8; }
.danger { background: #b84152; }
.section-title { color: #f8fafc; display: block; font-size: 32rpx; font-weight: 700; margin-bottom: 16rpx; }
.video { background: #020617; height: 390rpx; width: 100%; }
.url { color: #7dd3fc; display: block; font-size: 22rpx; line-height: 32rpx; margin-top: 14rpx; word-break: break-all; }
.metric { border-bottom: 1rpx solid #334155; color: #cbd5e1; display: flex; font-size: 26rpx; justify-content: space-between; padding: 16rpx 0; }
.metric text:last-child { color: #7dd3fc; text-align: right; }
.muted { color: #94a3b8; font-size: 25rpx; }
.log { color: #cbd5e1; display: block; font-family: monospace; font-size: 22rpx; line-height: 34rpx; margin-bottom: 6rpx; }
</style>
