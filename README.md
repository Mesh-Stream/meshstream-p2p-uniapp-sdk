# MeshStream P2P uni-app SDK

[简体中文](README.zh-CN.md) · [Website](https://meshstream.net/) · [Documentation](https://meshstream.net/docs/sdk/uniapp-setup/) · [DCloud plugin](https://ext.dcloud.net.cn/plugin?name=meshstream-p2p) · [Live demo](https://demo.meshstream.net/)

MeshStream is a uni-app P2P video and audio streaming plugin for Android and iOS apps. It provides a shared UTS / JavaScript client/session API, a local playback URL for your existing player, peer events and traffic statistics, with HTTP/CDN fallback.

Current plugin: **1.1.0**. Both native SDK dependencies are **1.1.0**.

## How it works

Create a session from your media URL, then give its `playbackUrl` to your existing player:

```text
App → SDK playback session → Local playback URL → Player
                              └─ SDK fetches from peers or origin/CDN
```

Your player handles decoding, rendering and playback controls. The SDK handles media delivery, caching and P2P scheduling. Configuration and P2P preparation run in the background; playback need not wait for a peer connection. Stop using the old playback URL before closing its session when leaving the page or switching content.

## Features

- HLS, MPEG-DASH and HTTP Range MP4/MP3 delivery through the native SDKs.
- Integration with uni-app Vue 3 App, HBuilderX and an existing video player.
- Preload, playback position/buffer updates, peer events and P2P/CDN statistics.
- DCloud plugin distribution with public Maven and CocoaPods native dependencies.

## Before you start

- Create an application and a platform-specific SDK Key in the [MeshStream console](https://console.meshstream.net/). If application identity validation is enabled, register the package name or Bundle ID of the app you run.
- Have a playable HLS `.m3u8`, DASH `.mpd`, or HTTP Range-capable MP4 / MP3 URL. Prefer HTTPS.
- Choose a player that supports your source format. The SDK adds delivery capabilities, not codecs; AVPlayer, for example, does not natively play DASH.

To try it first, jump to [Run the demo](#run-the-demo). The online demo linked above is a Web experience; run this repository's example for this platform.

## Requirements

The Android dependency includes `armeabi-v7a`, `arm64-v8a`, `x86`, and `x86_64` for matching devices and emulators. The application must also meet the architecture and OS requirements of its framework, base and player.

- HBuilderX 4.25+ and uni-app Vue 3 App.
- Plugin minimums: Android 5.0 / API 21 and iOS 15+. The actual application minimum is the highest requirement from the plugin, HBuilderX base and player; the example targets Android API 24.
- Android dependency: `io.meshstream:meshstream-android-sdk:1.1.0` from `https://sdk.meshstream.net/maven`.
- iOS dependency: CocoaPods `MeshStreamKit = 1.1.0`. Both native runtime versions are `1.1.0`.
- Use a custom base or cloud packaging to include the native SDKs and configuration.

This plugin targets App Android / iOS, not H5, mini-programs or uni-app x.

## Install

Install the plugin from the [DCloud plugin market](https://ext.dcloud.net.cn/plugin?name=meshstream-p2p), or extract a released plugin ZIP into `uni_modules/meshstream-p2p/` in your application. Its `package.json` must be directly inside that directory.

Vue / JavaScript pages should import `MeshStream` from `@/uni_modules/meshstream-p2p/javascript.js`. This facade manages JavaScript Promises and propagates asynchronous results and errors through UTS. UTS callers can import the module root.

## Local playback network configuration

The Android plugin includes a manifest and network policy allowing HTTP only for `127.0.0.1` / `localhost`. Merge the loopback rules if your host app already defines a policy. In the iOS app project's root `Info.plist`, merge `NSAllowsLocalNetworking = true` into `NSAppTransportSecurity`. Public HTTP media origins need separate configuration; prefer HTTPS.

After changing native network settings, rebuild and reinstall the custom base or packaged app; page hot reload does not update these settings. See [platform network configuration](https://meshstream.net/docs/sdk/uniapp-setup/) for file locations and examples.

## Start playback

Prepare a player in the page, with a reactive Vue `playbackUrl`:

```html
<video v-if="playbackUrl" :src="playbackUrl" controls />
```

Create a session in your asynchronous play handler and update the bound URL:

```ts
import { ref, nextTick } from 'vue'
import { MeshStream } from '@/uni_modules/meshstream-p2p/javascript.js'

const playbackUrl = ref('')
// In the async play flow; retain client and session in the page owner:
const client = await MeshStream.create({ key: 'key_your_platform_key', p2pEnabled: true })
const session = await MeshStream.createPlaybackSession(client.clientId, {
  url: 'https://cdn.example.com/live/playlist.m3u8',
  contentId: 'live-channel-42',
  mimeType: 'm3u8',
})
playbackUrl.value = session.playbackUrl
```

Keep playing `session.playbackUrl`; do not wait for peers. On teardown or media switch, clear the player binding before closing the old session. Close the client when its owner no longer needs it:

```ts
playbackUrl.value = ''
await nextTick()
await MeshStream.closeSession(client.clientId, session.sessionId)
await MeshStream.closeClient(client.clientId)
```

These snippets belong in separate startup and teardown steps. See [`example/pages/index/index.vue`](https://github.com/Mesh-Stream/meshstream-p2p-uniapp-sdk/blob/main/example/pages/index/index.vue) for a runnable page. Vue/JavaScript callers use the static `MeshStream` API, not instance methods on returned objects.

## Run the demo

```bash
git clone https://github.com/Mesh-Stream/meshstream-p2p-uniapp-sdk.git
```

1. Open the repository's [`example/`](https://github.com/Mesh-Stream/meshstream-p2p-uniapp-sdk/tree/main/example) directory in HBuilderX as a Vue 3 uni-app project.
2. Confirm `uni_modules/meshstream-p2p` is installed and configure your app identity in `manifest.json`. If identity validation is enabled, register the actual package name or Bundle ID in the console.
3. Build and select a custom debug base containing the plugin, or cloud-package the app. The standard base lacks the native SDK. Keep the example's `VideoPlayer` module for Android packaging. iOS devices require signing certificates and a provisioning profile.
4. Run on Android / iOS, enter the matching platform Key and HTTPS media URL, then start playback and inspect peers, P2P/HTTP traffic and diagnostics.

iOS simulators require a matching custom base: arm64 for Apple Silicon or x86_64 for Intel Macs. See the [example guide](https://github.com/Mesh-Stream/meshstream-p2p-uniapp-sdk/blob/main/example/README.md).

## Preload and events

Preload with `await MeshStream.preload(client.clientId, session.sessionId)`. Forward player position and buffered duration through `updateCurrentPositionMs` and `updateBufferedDurationMs` in milliseconds, at most about once per second.

Subscribe with `const eventId = MeshStream.subscribeEvents(callback)` and call `MeshStream.unsubscribeEvents(eventId)` before teardown. Use `clientId` / `sessionId` to distinguish multiple sessions.

<details>
<summary>Troubleshoot HBuilderX Android dependency resolution</summary>

### Android repository resolution

If HBuilderX 5.33 cannot resolve the MeshStream Maven dependency because its temporary Gradle project uses `PREFER_SETTINGS`, use the bundled [Gradle launcher](scripts/hbuilderx-gradle.sh):

```sh
chmod +x uni_modules/meshstream-p2p/scripts/hbuilderx-gradle.sh
export MESHSTREAM_GRADLE_EXECUTABLE=/absolute/path/to/gradle
```

Point HBuilderX's UTS Android Gradle executable setting to that script and make the environment variable available to HBuilderX. Set the variable to the actual Gradle binary. The script changes repository priority to `PREFER_PROJECT` only for HBuilderX temporary dependency-resolution projects. It keeps the exact public Maven dependency.

</details>

## Network and privacy

SDK Key validation, configuration, tracker signaling and usage reporting process application identity, device platform, IP/network information, content/segment identifiers, transferred bytes and diagnostics. Explain to users that P2P uses upload bandwidth. The plugin does not access the camera, microphone, contacts or precise location and includes no advertising. Cleartext HTTP access is allowed only for the local proxy at `127.0.0.1` / `localhost`.

## Verify P2P delivery

1. Play the same content in two devices or independently running instances, each with a valid Key. Use the same rendition and nearby playback positions. For rotating signed URLs, use the same stable content ID for the same content, and different IDs for different content.
2. Watch peers and traffic in the demo. A nonzero peer count means a connection exists; **increasing P2P download or upload bytes** confirms media sharing.
3. Close the other instance and check that HTTP/CDN playback continues. Also check seeking, switching content and cleanup when leaving playback.

HTTP/CDN delivery is normal with one viewer or no shareable segments. Discovery and sharing also depend on account configuration, network connectivity and the content cached by both viewers.

## More examples and support

See [advanced usage](https://meshstream.net/docs/sdk/uniapp-advanced/) for preload, live/VOD scheduling, player feedback, multiple sessions and diagnostics. See [CHANGELOG](https://github.com/Mesh-Stream/meshstream-p2p-uniapp-sdk/blob/main/CHANGELOG.md) for updates. Contact support@meshstream.net with the SDK version, OS, player and redacted logs.

## Other MeshStream SDKs

- [Web](https://github.com/Mesh-Stream/meshstream-p2p-web-sdk): JavaScript / TypeScript and browser players.
- [iOS / macOS](https://github.com/Mesh-Stream/meshstream-p2p-ios-sdk): MeshStreamKit, Swift / Objective-C, SPM and CocoaPods.
- [Android](https://github.com/Mesh-Stream/meshstream-p2p-android-sdk): Kotlin / Java, Maven and Media3 / ExoPlayer.
- [Windows](https://github.com/Mesh-Stream/meshstream-p2p-Windows-sdk): C / C++ API for Windows 10 / 11 x64.
- [Flutter](https://github.com/Mesh-Stream/meshstream-p2p-flutter-sdk): Dart plugin for iOS / Android.
- [React Native](https://github.com/Mesh-Stream/meshstream-p2p-react-native-sdk): JavaScript / TypeScript API for iOS / Android.
