import Foundation
import MeshStreamKit

/** Swift implementation behind the UTS facade. It owns only resources created by this plugin. */
public final class MeshStreamNative: NSObject {
  private final class ClientState {
    let client: P2PClient
    let listener: NativeListener
    var sessions: [String: PlaybackSession] = [:]
    var nativeSessionIds: [String: String] = [:]
    var pendingEvents: [String: [[String: Any]]] = [:]
    var closed = false

    init(client: P2PClient, listener: NativeListener) {
      self.client = client
      self.listener = listener
    }
  }

  private static let lock = NSLock()
  private static var clients: [String: ClientState] = [:]
  private static var eventListener: ((String) -> Void)?

  public static func getSdkVersion() -> String { P2PSDK.getSdkVersion() }

  public static func setEventListener(_ listener: ((String) -> Void)?) {
    lock.lock(); eventListener = listener; lock.unlock()
  }

  public static func createClient(_ key: String, _ p2pEnabled: Bool?) throws -> String {
    guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw NativeError("key must not be empty")
    }
    let config = P2PConfig(key: key)
    if let enabled = p2pEnabled { config.p2pEnabled = enabled }
    let client = try P2PSDK.client(with: config)
    let clientId = UUID().uuidString
    let listener = NativeListener { nativeId, event in receiveEvent(clientId, nativeId, event) }
    let state = ClientState(client: client, listener: listener)
    lock.lock(); clients[clientId] = state; lock.unlock()
    client.add(listener)
    return encode(["clientId": clientId, "status": status(client.sdkStatus)])
  }

  public static func createPlaybackSession(_ clientId: String, _ optionsJson: String) throws -> String {
    let options = try object(optionsJson)
    guard let rawUrl = options["url"] as? String,
          let url = URL(string: rawUrl),
          let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil else {
      throw NativeError("options.url must be an HTTP(S) URL")
    }
    let state = try client(clientId)
    let nativeOptions = P2PPlaybackOptions()
    nativeOptions.contentId = options["contentId"] as? String
    nativeOptions.mimeType = options["mimeType"] as? String
    nativeOptions.originHeaders = options["originHeaders"] as? [String: String] ?? [:]
    let session = try state.client.createPlaybackSession(with: url, options: nativeOptions)
    let sessionId = UUID().uuidString
    lock.lock()
    guard clients[clientId] === state, !state.closed else { lock.unlock(); session.close(); throw NativeError("MeshStream client was closed") }
    state.sessions[sessionId] = session
    state.nativeSessionIds[session.sessionId] = sessionId
    let pending = state.pendingEvents.removeValue(forKey: session.sessionId) ?? []
    lock.unlock()
    for event in pending { emit(clientId, sessionId, event) }
    var result: [String: Any] = [
      "clientId": clientId, "sessionId": sessionId, "playbackUrl": session.playbackUrl.absoluteString,
      "playbackMode": session.playbackMode == .nativeP2P ? "NATIVE_P2P" : "NATIVE_CDN"
    ]
    if session.playbackMode == .nativeCDN { result["fallbackReason"] = reason(session.fallbackReason) }
    return encode(result)
  }

  public static func preload(_ clientId: String, _ sessionId: String) throws -> Bool { try session(clientId, sessionId).preload() }
  public static func setP2pEnabled(_ clientId: String, _ sessionId: String, _ enabled: Bool) throws { try session(clientId, sessionId).setP2PEnabled(enabled) }
  public static func updateBufferedDurationMs(_ clientId: String, _ sessionId: String, _ durationMs: Int64) throws { try session(clientId, sessionId).updateBufferedDurationMs(max(0, durationMs)) }
  public static func updateCurrentPositionMs(_ clientId: String, _ sessionId: String, _ positionMs: Int64) throws { try session(clientId, sessionId).updateCurrentPositionMs(max(0, positionMs)) }
  public static func getStatus(_ clientId: String) throws -> String { encode(status(try client(clientId).client.sdkStatus)) }
  public static func getStats(_ clientId: String, _ sessionId: String) throws -> String { encode(stats(try session(clientId, sessionId).statistics())) }
  public static func getDiagnostics(_ clientId: String, _ sessionId: String) throws -> String { encode(diagnostics(try session(clientId, sessionId).diagnostics())) }

  public static func closeSession(_ clientId: String, _ sessionId: String) {
    lock.lock()
    let session = clients[clientId]?.sessions.removeValue(forKey: sessionId)
    if let session { clients[clientId]?.nativeSessionIds.removeValue(forKey: session.sessionId); clients[clientId]?.pendingEvents.removeValue(forKey: session.sessionId) }
    lock.unlock()
    session?.close()
  }

  public static func closeClient(_ clientId: String) {
    lock.lock()
    let state = clients.removeValue(forKey: clientId)
    state?.closed = true
    lock.unlock()
    guard let state else { return }
    state.client.remove(state.listener)
    state.sessions.values.forEach { $0.close() }
    state.sessions.removeAll(); state.nativeSessionIds.removeAll(); state.pendingEvents.removeAll()
    state.client.close()
  }

  private static func client(_ clientId: String) throws -> ClientState {
    lock.lock(); defer { lock.unlock() }
    guard let value = clients[clientId] else { throw NativeError("Unknown or closed MeshStream client: \(clientId)") }
    return value
  }

  private static func session(_ clientId: String, _ sessionId: String) throws -> PlaybackSession {
    lock.lock(); defer { lock.unlock() }
    guard let value = clients[clientId]?.sessions[sessionId] else { throw NativeError("Unknown or closed MeshStream session: \(sessionId)") }
    return value
  }

  private static func receiveEvent(_ clientId: String, _ nativeId: String, _ event: [String: Any]) {
    lock.lock()
    guard let state = clients[clientId] else { lock.unlock(); return }
    if let sessionId = state.nativeSessionIds[nativeId] { lock.unlock(); emit(clientId, sessionId, event); return }
    if state.pendingEvents.count < 64 {
      var pending = state.pendingEvents[nativeId] ?? []
      if pending.count < 8 { pending.append(event); state.pendingEvents[nativeId] = pending }
    }
    lock.unlock()
  }

  private static func emit(_ clientId: String, _ sessionId: String, _ event: [String: Any]) {
    var payload = event; payload["clientId"] = clientId; payload["sessionId"] = sessionId
    let text = encode(payload)
    DispatchQueue.main.async {
      lock.lock()
      let listener = clients[clientId]?.sessions[sessionId] == nil ? nil : eventListener
      lock.unlock()
      listener?(text)
    }
  }

  private static func object(_ text: String) throws -> [String: Any] {
    guard let data = text.data(using: .utf8), let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw NativeError("Invalid JSON options") }
    return value
  }
  private static func encode(_ value: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: value), let text = String(data: data, encoding: .utf8) else { return "{}" }
    return text
  }
  private static func status(_ value: P2PSdkStatus) -> [String: Any] {
    var result: [String: Any] = ["accountEnabled": value.accountEnabled, "applicationEnabled": value.applicationEnabled, "keyEnabled": value.keyEnabled, "platformEnabled": value.platformEnabled, "effectiveP2pEnabled": value.effectiveP2PEnabled, "reason": reason(value.reason)]
    if let value = value.configVersion { result["configVersion"] = value }; if let value = value.edgeRegion { result["edgeRegion"] = value }; if let value = value.quotaStatus { result["quotaStatus"] = value }
    return result
  }
  static func stats(_ value: P2PStats) -> [String: Any] {
    let downloaded = Double(value.httpDownloaded) + Double(value.p2pDownloaded)
    let downSegments = Double(value.p2pSegmentDownloadSuccesses + value.p2pSegmentDownloadFailures)
    let upSegments = Double(value.p2pSegmentUploadSuccesses + value.p2pSegmentUploadFailures)
    return ["httpDownloaded": value.httpDownloaded, "p2pDownloaded": value.p2pDownloaded, "p2pUploaded": value.p2pUploaded, "httpSegmentDownloadSuccesses": value.httpSegmentDownloadSuccesses, "httpSegmentDownloadFailures": value.httpSegmentDownloadFailures, "p2pSegmentDownloadSuccesses": value.p2pSegmentDownloadSuccesses, "p2pSegmentDownloadFailures": value.p2pSegmentDownloadFailures, "p2pSegmentUploadSuccesses": value.p2pSegmentUploadSuccesses, "p2pSegmentUploadFailures": value.p2pSegmentUploadFailures, "connectedPeers": value.connectedPeers, "peerConnectErrors": value.peerConnectErrors, "trackerErrors": value.trackerErrors, "downloadOffloadRatio": downloaded == 0 ? 0 : Double(value.p2pDownloaded) / downloaded, "p2pSegmentDownloadSuccessRatio": downSegments == 0 ? 0 : Double(value.p2pSegmentDownloadSuccesses) / downSegments, "p2pSegmentUploadSuccessRatio": upSegments == 0 ? 0 : Double(value.p2pSegmentUploadSuccesses) / upSegments]
  }
  private static func diagnostics(_ value: P2PDiagnostics) -> [String: Any] {
    var result: [String: Any] = ["fallbackCount": value.fallbackCount, "iceAttempts": value.iceAttempts, "iceSuccesses": value.iceSuccesses, "iceFailures": value.iceFailures, "iceDurationMs": value.iceDurationMs]
    if value.firstPeerConnectMs > 0 { result["firstPeerConnectMs"] = value.firstPeerConnectMs }
    if value.coldStartP2PDownloaded > 0 || value.coldStartHTTPDownloaded > 0 { result["coldStart"] = ["p2pDownloaded": value.coldStartP2PDownloaded, "httpDownloaded": value.coldStartHTTPDownloaded] }
    if let value = value.lastTrackerError { result["lastTrackerError"] = value }; if let value = value.lastPeerError { result["lastPeerError"] = value }; if value.lastErrorAtMs > 0 { result["lastErrorAtMs"] = value.lastErrorAtMs }
    return result
  }
  static func reason(_ value: P2PUnavailableReason) -> String {
    switch value {
    case .OK: return "OK"; case .noPeers: return "NO_PEERS"; case .trackerError: return "TRACKER_ERROR"; case .authFailed: return "AUTH_FAILED"; case .accountDisabled: return "ACCOUNT_DISABLED"; case .appDisabled: return "APP_DISABLED"; case .appNotFound: return "APP_NOT_FOUND"; case .keyDisabled: return "KEY_DISABLED"; case .platformDisabled: return "PLATFORM_DISABLED"; case .originDenied: return "ORIGIN_DENIED"; case .packageDenied: return "PACKAGE_DENIED"; case .bundleDenied: return "BUNDLE_DENIED"; case .signingCertDenied: return "SIGNING_CERT_DENIED"; case .teamDenied: return "TEAM_DENIED"; case .configUnavailable: return "CONFIG_UNAVAILABLE"; case .initializationFailed: return "INITIALIZATION_FAILED"; case .unsupported: return "UNSUPPORTED"; case .disabled: return "DISABLED"; case .keyP2PDisabled: return "KEY_P2P_DISABLED"; case .quotaExhausted: return "QUOTA_EXHAUSTED"; case .quotaDisabled: return "QUOTA_DISABLED"; @unknown default: return "INITIALIZATION_FAILED" }
  }
}

private final class NativeListener: NSObject, P2PEventListener {
  let handler: (String, [String: Any]) -> Void
  init(_ handler: @escaping (String, [String: Any]) -> Void) { self.handler = handler }
  func onPlaybackPrepared(withSessionId sessionId: String, playbackUrl: URL) { handler(sessionId, ["type": "playbackPrepared", "playbackUrl": playbackUrl.absoluteString]) }
  func onStatistics(withSessionId sessionId: String, stats: P2PStats) { handler(sessionId, ["type": "statistics", "statistics": MeshStreamNative.stats(stats)]) }
  func onPeerCountChanged(withSessionId sessionId: String, peerCount: Int) { handler(sessionId, ["type": "peerCountChanged", "peerCount": peerCount]) }
  func onP2PReady(withSessionId sessionId: String) { handler(sessionId, ["type": "p2pReady"]) }
  func onP2PUnavailable(withSessionId sessionId: String, reason: P2PUnavailableReason) { handler(sessionId, ["type": "p2pUnavailable", "reason": MeshStreamNative.reason(reason)]) }
  func onCdnFallback(withSessionId sessionId: String, bytes: Int64) { handler(sessionId, ["type": "cdnFallback", "bytes": bytes]) }
  func onTrackerError(withSessionId sessionId: String, totalErrors: Int64) { handler(sessionId, ["type": "trackerError", "totalErrors": totalErrors]) }
  func onPeerConnectError(withSessionId sessionId: String, totalErrors: Int64) { handler(sessionId, ["type": "peerConnectError", "totalErrors": totalErrors]) }
}

private struct NativeError: LocalizedError { let message: String; init(_ message: String) { self.message = message }; var errorDescription: String? { message } }
