# MeshStream P2P for uni-app

MeshStream is a player-agnostic P2P playback accelerator for uni-app App targets. It returns a local playback URL for the application's existing video player; it does not supply a player component or decoder.

## Requirements

- HBuilderX 4.25 or later, because the plugin uses UTS native mixed source.
- uni-app App on Android API 24+ or iOS 13+.
- A MeshStream key authorized for the target application's package name or bundle identifier.

Web and mini-program targets are intentionally unsupported: they cannot load the Android or iOS MeshStream engine.

## Installation

Copy this repository into the consumer application's `uni_modules/meshstream-p2p` directory, then import it from the module root:

```ts
import { MeshStream } from '@/uni_modules/meshstream-p2p'
```

The Android side resolves `io.meshstream:meshstream-android-sdk:1.0.2` from the MeshStream Maven repository. The iOS side resolves `MeshStreamKit` version `1.0.2` through CocoaPods. Native dependency changes require cloud packaging or a custom base; a stock base cannot validate them.

## Playback

```ts
const client = await MeshStream.create({
  key: 'key_your_meshstream_key',
  p2pEnabled: true,
})

const session = await client.createPlaybackSession({
  url: 'https://cdn.example.com/live/playlist.m3u8',
  contentId: 'live-channel-42',
  mimeType: 'm3u8',
})

// Bind session.playbackUrl to the application's existing video component.
const stopEvents = MeshStream.addEventListener((event) => {
  if (event.getString('type') == 'p2pUnavailable') {
    console.warn('P2P unavailable:', event.getString('reason'))
  }
})

// Report active-player state at a low frequency, for example every two seconds.
await session.updateCurrentPositionMs(positionMs)
await session.updateBufferedDurationMs(bufferedDurationMs)

// Destroy in this order when playback ends.
stopEvents()
await session.close()
await client.close()
```

Each client can own multiple independent sessions. Closing a session or client only releases the native resources created by that object.

## Events and Diagnostics

Events contain `clientId`, `sessionId`, and a `type`: `peerCountChanged`, `playbackPrepared`, `p2pReady`, `p2pUnavailable`, `statistics`, `cdnFallback`, `trackerError`, or `peerConnectError`.

`client.getStatus()`, `session.getStats()`, and `session.getDiagnostics()` return `UTSJSONObject` values with the same field names used by the React Native and Flutter SDKs. Call `getString`, `getNumber`, `getBoolean`, or `get` to read them.

## Network and Privacy

The plugin allows cleartext traffic only to `127.0.0.1` and `localhost`, because `playbackUrl` is backed by the native local proxy. It does not enable app-wide cleartext traffic. Keep origin media URLs on HTTPS.

The iOS configuration includes `NSLocalNetworkUsageDescription`. If the host application already sets this string, ensure the final merged text remains appropriate for the application's review submission.
