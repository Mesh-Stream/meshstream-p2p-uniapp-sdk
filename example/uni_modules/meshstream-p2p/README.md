# MeshStream P2P for uni-app

MeshStream is a player-agnostic P2P playback accelerator for uni-app App targets. It returns a local playback URL for the application's existing video player; it does not supply a player component or decoder.

## Requirements

- HBuilderX 4.25 or later, because the plugin uses UTS native mixed source.
- uni-app App on Android API 24+ or iOS 15+.
- A MeshStream key authorized for the target application's package name or bundle identifier.

Web and mini-program targets are intentionally unsupported: they cannot load the Android or iOS MeshStream engine.

## Release status

Version 1.0.2 is a prepared release candidate, not a published DCloud market release. Android and iOS UTS compilation passed with HBuilderX 5.33. iOS playback acceptance is pending: the bundled Uniapp simulator host is x86_64-only, while current Apple Silicon simulator runtimes are arm64. A signed iOS device custom base or a compatible arm64 simulator custom base is required.

## Installation

Extract the prepared plugin ZIP into the consumer application's `uni_modules/meshstream-p2p` directory (with `package.json` directly under that directory). Do not copy `example/`, release records, or build caches into the module. Vue/JavaScript pages use the JavaScript entry:

```ts
import { MeshStream } from '@/uni_modules/meshstream-p2p/javascript.js'
```

The Android side resolves `io.meshstream:meshstream-android-sdk:1.0.6` from `https://sdk.meshstream.net/maven`. The iOS side resolves `MeshStreamKit` version `1.0.7` through CocoaPods. Native dependency changes require cloud packaging or a custom base; a stock base cannot validate them.

## Playback

```ts
const client = await MeshStream.create({
  key: 'key_your_meshstream_key',
  p2pEnabled: true,
})

const session = await MeshStream.createPlaybackSession(client.clientId, {
  url: 'https://cdn.example.com/live/playlist.m3u8',
  contentId: 'live-channel-42',
  mimeType: 'm3u8',
})

// Bind session.playbackUrl to the application's existing video component.
const subscriptionId = MeshStream.subscribeEvents((event) => {
  const type = event.getString ? event.getString('type') : event.type
  if (type === 'p2pUnavailable') {
    console.warn('P2P unavailable:', event.getString ? event.getString('reason') : event.reason)
  }
})

// Report active-player state at a low frequency, for example every two seconds.
await MeshStream.updateCurrentPositionMs(client.clientId, session.sessionId, positionMs)
await MeshStream.updateBufferedDurationMs(client.clientId, session.sessionId, bufferedDurationMs)

// Destroy in this order when playback ends.
MeshStream.unsubscribeEvents(subscriptionId)
await MeshStream.closeSession(client.clientId, session.sessionId)
await MeshStream.closeClient(client.clientId)
```

Each client can own multiple independent sessions. Closing a session or client only releases the native resources created by that object.

## Events and Diagnostics

Events contain `clientId`, `sessionId`, and a `type`: `peerCountChanged`, `playbackPrepared`, `p2pReady`, `p2pUnavailable`, `statistics`, `cdnFallback`, `trackerError`, or `peerConnectError`.

Use the static `MeshStream` helpers from Vue/JavaScript code for session lifecycle and telemetry operations. This avoids an HBuilderX UTS instance-method proxy limitation observed on App builds. The instance methods remain available to UTS callers.

The JavaScript entry owns the Promises and receives explicit success/error results from UTS. This also makes native failures reject reliably on HBuilderX 5.33, where direct native Promise rejection can leave a page waiting. UTS callers can continue importing the module root; Vue/JavaScript callers should use `javascript.js` for all operations.

For events, use `subscribeEvents(callback)` and pass its numeric ID to `unsubscribeEvents(id)`. The JavaScript entry also provides `addEventListener(callback)` returning a JavaScript cleanup function. The legacy UTS helper's returned function cannot cross the Vue/JavaScript boundary reliably.

```js
await MeshStream.preload(client.clientId, session.sessionId)
await MeshStream.setP2pEnabled(client.clientId, session.sessionId, false)
// Release the session when the player is finished.
await MeshStream.closeSession(client.clientId, session.sessionId)
```

`MeshStream.getStatus(clientId)`, `MeshStream.getStats(clientId, sessionId)`, and `MeshStream.getDiagnostics(clientId, sessionId)` return values with the same field names used by the React Native and Flutter SDKs. At the Vue/JavaScript boundary HBuilderX may materialize a `UTSJSONObject` as a plain object, so consumers should support either `getString` / `getNumber` accessors or normal object fields. The example app contains compatible field readers.

## Network and Privacy

The plugin allows cleartext traffic only to `127.0.0.1` and `localhost`, because `playbackUrl` is backed by the native local proxy. It does not enable app-wide cleartext traffic. Keep origin media URLs on HTTPS.

The iOS configuration includes `NSLocalNetworkUsageDescription`. If the host application already sets this string, ensure the final merged text remains appropriate for the application's review submission.

## HBuilderX 5.33 Android repository workaround

HBuilderX 5.33 generates a temporary Gradle settings file using `PREFER_SETTINGS`. This hides the Maven repository declared by the plugin in `project.repositories`. If the compiler cannot resolve `io.meshstream:meshstream-android-sdk:1.0.6`, configure HBuilderX **Settings > Run Configuration > Gradle** to use a local launcher:

```sh
#!/usr/bin/env bash
export MESHSTREAM_GRADLE_EXECUTABLE="/absolute/path/to/gradle-or-gradlew"
exec "/absolute/path/to/uni_modules/meshstream-p2p/scripts/hbuilderx-gradle.sh" "$@"
```

Make the launcher executable and restart HBuilderX. Use Gradle 7.5 to 8.x and JDK 17. The helper only changes repository preference in HBuilderX temporary dependency-resolution projects; it keeps the public SDK dependency and repository in the plugin configuration. It does not add local AARs or change consumer Gradle projects. Compilation into a stock base is not runtime acceptance: native libraries and network settings require a custom base/cloud build.
