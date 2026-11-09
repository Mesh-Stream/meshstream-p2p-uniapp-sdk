# MeshStream P2P uni-app SDK

[简体中文](README.zh-CN.md) · [Website](https://meshstream.net/) · [Documentation](https://meshstream.net/docs/sdk/uniapp-setup/) · [DCloud plugin](https://ext.dcloud.net.cn/plugin?name=meshstream-p2p) · [Live demo](https://demo.meshstream.net/)

MeshStream is a uni-app P2P video and audio streaming plugin for Android and iOS apps. It provides a shared UTS / JavaScript client/session API, a local playback URL for your existing player, peer events and traffic statistics, with HTTP/CDN fallback.

Current plugin: **1.0.7**. Both native SDK dependencies are **1.0.10**.

## Features

- HLS, MPEG-DASH and HTTP Range MP4/MP3 delivery through the native SDKs.
- Integration with uni-app Vue 3 App, HBuilderX and an existing video player.
- Preload, playback position/buffer updates, peer events and P2P/CDN statistics.
- DCloud plugin distribution with public Maven and CocoaPods native dependencies.

Media decoding and format support depend on your chosen player and platform. P2P availability depends on network conditions and peers with matching content.

## Requirements

The Android dependency includes `armeabi-v7a`, `arm64-v8a`, `x86`, and `x86_64` for matching devices and emulators. The application must also meet the architecture and OS requirements of its framework, base and player.

- HBuilderX 4.25+ and uni-app Vue 3 App.
- Plugin minimums: Android 5.0 / API 21 and iOS 15+. The actual application minimum is the highest requirement from the plugin, HBuilderX base and player; the example targets Android API 24.
- Android dependency: `io.meshstream:meshstream-android-sdk:1.0.10` from `https://sdk.meshstream.net/maven`.
- iOS dependency: CocoaPods `MeshStreamKit = 1.0.10`. Both native runtime versions are `1.0.10`.
- Use a custom base or cloud packaging to include the native SDKs and configuration.

## Install

Install the plugin from the [DCloud plugin market](https://ext.dcloud.net.cn/plugin?name=meshstream-p2p), or extract a released plugin ZIP into `uni_modules/meshstream-p2p/` in your application. Its `package.json` must be directly inside that directory.

Vue / JavaScript pages should import `MeshStream` from `@/uni_modules/meshstream-p2p/javascript.js`. This facade manages JavaScript Promises and propagates asynchronous results and errors through UTS. UTS callers can import the module root.

## Quick start

Create a client and playback session with the static `MeshStream` API. Give `session.playbackUrl` to the player and prefer HTTPS media origins:

```ts
import { MeshStream } from '@/uni_modules/meshstream-p2p/javascript.js'

const client = await MeshStream.create({
  key: 'key_your_meshstream_key',
  p2pEnabled: true,
})
const session = await MeshStream.createPlaybackSession(client.clientId, {
  url: 'https://cdn.example.com/live/playlist.m3u8',
  contentId: 'live-channel-42',
  mimeType: 'm3u8',
})

// Bind session.playbackUrl to your existing video player.
const eventId = MeshStream.subscribeEvents((event) => {
  const type = event.getString ? event.getString('type') : event.type
  console.log('MeshStream event:', type)
})

await MeshStream.updateCurrentPositionMs(client.clientId, session.sessionId, positionMs)
await MeshStream.updateBufferedDurationMs(client.clientId, session.sessionId, bufferedDurationMs)

MeshStream.unsubscribeEvents(eventId)
await MeshStream.closeSession(client.clientId, session.sessionId)
await MeshStream.closeClient(client.clientId)
```

In Vue / JavaScript pages, use the static API rather than calling instance methods on returned objects. Preload with `await MeshStream.preload(client.clientId, session.sessionId)` and toggle P2P with `await MeshStream.setP2pEnabled(client.clientId, session.sessionId, enabled)`.

Register events with `const id = MeshStream.subscribeEvents(callback)` and remove the subscription with `MeshStream.unsubscribeEvents(id)`. The JavaScript facade also provides `addEventListener`, which returns a local unsubscribe function. Functions returned across the UTS-to-JavaScript boundary are not a reliable unsubscribe mechanism.

## iOS simulator

Use a custom base matching your simulator architecture: arm64 on Apple Silicon and x86_64 on Intel Macs.

## Android repository resolution

If HBuilderX 5.33 cannot resolve the MeshStream Maven dependency because its temporary Gradle project uses `PREFER_SETTINGS`, use the bundled [Gradle launcher](scripts/hbuilderx-gradle.sh):

```sh
chmod +x uni_modules/meshstream-p2p/scripts/hbuilderx-gradle.sh
export MESHSTREAM_GRADLE_EXECUTABLE=/absolute/path/to/gradle
```

Point HBuilderX's UTS Android Gradle executable setting to that script and make the environment variable available to HBuilderX. Set the variable to the actual Gradle binary. The script changes repository priority to `PREFER_PROJECT` only for HBuilderX temporary dependency-resolution projects. It keeps the exact public Maven dependency.

## Network and privacy

SDK Key validation, configuration, tracker signaling and usage reporting process application identity, device platform, IP/network information, content/segment identifiers, transferred bytes and diagnostics. Explain to users that P2P uses upload bandwidth. The plugin does not access the camera, microphone, contacts or precise location and includes no advertising. Cleartext HTTP access is allowed only for the local proxy at `127.0.0.1` / `localhost`.

## Other MeshStream SDKs

- [Web](https://github.com/Mesh-Stream/meshstream-p2p-web-sdk): JavaScript / TypeScript and browser players.
- [iOS / macOS](https://github.com/Mesh-Stream/meshstream-p2p-ios-sdk): MeshStreamKit, Swift / Objective-C, SPM and CocoaPods.
- [Android](https://github.com/Mesh-Stream/meshstream-p2p-android-sdk): Kotlin / Java, Maven and Media3 / ExoPlayer.
- [Windows](https://github.com/Mesh-Stream/meshstream-p2p-Windows-sdk): C / C++ API for Windows 10 / 11 x64.
- [Flutter](https://github.com/Mesh-Stream/meshstream-p2p-flutter-sdk): Dart plugin for iOS / Android.
- [React Native](https://github.com/Mesh-Stream/meshstream-p2p-react-native-sdk): JavaScript / TypeScript API for iOS / Android.
