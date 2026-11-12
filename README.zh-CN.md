# MeshStream P2P uni-app SDK

[English](README.md) · [官网](https://meshstream.net/zh/) · [接入文档](https://meshstream.net/zh/docs/sdk/uniapp-setup/) · [DCloud 插件市场](https://ext.dcloud.net.cn/plugin?name=meshstream-p2p) · [在线 Demo](https://demo.meshstream.net/)

MeshStream 是面向 Android 和 iOS App 的 uni-app P2P 视频与音频流媒体插件。它通过统一的 UTS / JavaScript client/session API 提供现有播放器可使用的本地播放地址、Peer 事件和流量统计，并支持 HTTP/CDN 回退。

当前插件版本：**1.1.0**；双端原生 SDK 版本：**1.1.0**。

## 工作方式

把原始媒体地址交给 SDK 创建会话，再把会话的 `playbackUrl` 交给现有播放器：

```text
应用 → SDK 创建播放会话 → 本地播放地址 → 播放器
                            └─ SDK 从 Peer 或源站/CDN 获取媒体
```

播放器继续负责解码、画面和播放控制；SDK 负责媒体传输、缓存及 P2P 调度。服务配置与 P2P 准备在后台执行，不需要等到 Peer 连接后才开始播放。离开播放页或切换内容时，先停止使用旧播放地址，再关闭旧会话。

## 产品能力

- 通过原生 SDK 接入 HLS、MPEG-DASH 和支持 HTTP Range 的 MP4/MP3。
- 面向 uni-app Vue 3 App 与 HBuilderX，可配合已有 video 播放器使用。
- 支持预加载、播放位置与缓冲回传、Peer 事件和 P2P/CDN 统计。
- 通过 DCloud 插件市场安装，原生依赖使用公开 Maven 与 CocoaPods。

## 接入准备

- 在 [MeshStream 控制台](https://console.meshstream.net/)创建应用和对应平台的 SDK Key；启用身份校验时，登记与运行应用一致的包名或 Bundle ID。
- 准备一个可播放的 HLS `.m3u8`、DASH `.mpd`、支持 Range 的 MP4 或 MP3 地址，建议使用 HTTPS。
- 选择支持该媒体格式的播放器。SDK 提供传输能力，不增加播放器的解码能力；例如 AVPlayer 不原生支持 DASH。

希望先看效果？直接跳到[运行 Demo](#运行-demo)，再按下方步骤接入自己的应用。顶部的在线 Demo 是 Web 体验页，各端示例在本仓库中运行。

## 运行要求

Android 依赖包含 `armeabi-v7a`、`arm64-v8a`、`x86` 和 `x86_64`，可用于相应架构的真机与模拟器；应用仍需满足框架、基座及播放器的系统和架构要求。

- HBuilderX 4.25+、uni-app Vue 3 App。
- 插件 Android 声明下限为 Android 5.0 / API 21；iOS 15+。应用实际下限取插件、HBuilderX 基座及播放器要求的最大值；示例以 API 24 构建。
- Android 公开依赖：`io.meshstream:meshstream-android-sdk:1.1.0`，Maven 地址 `https://sdk.meshstream.net/maven`。
- iOS 公开依赖：CocoaPods `MeshStreamKit = 1.1.0`。Android 和 iOS native 运行时版本均为 `1.1.0`。
- 使用自定义基座或云打包；标准基座无法包含本插件所需的原生 SDK 和配置。

此插件用于 App Android / iOS，不用于 H5、小程序或 uni-app x。

## 安装与接入

从 [DCloud 插件市场](https://ext.dcloud.net.cn/plugin?name=meshstream-p2p)安装，或将已发布插件 ZIP 内的文件解压到应用的 `uni_modules/meshstream-p2p/`，确保 `package.json` 直接位于该目录下。

Vue/JavaScript 页面请使用 `import { MeshStream } from '@/uni_modules/meshstream-p2p/javascript.js'`。此入口为 Vue/JavaScript 页面提供 Promise 异步调用和错误处理。UTS 调用方仍可导入模块根目录。

## 本地播放网络配置

Android 插件已附带 Manifest 和仅放行 `127.0.0.1` / `localhost` 的网络策略；若宿主已有策略，请合并回环规则。在 iOS 应用项目根目录的 `Info.plist` 中，将 `NSAllowsLocalNetworking = true` 合并到 `NSAppTransportSecurity` 字典。公网 HTTP 媒体源需要另行配置，建议使用 HTTPS。

修改原生网络配置后，重新制作基座或打包并安装；页面热更新不会更新配置。文件位置及完整示例见[平台网络配置](https://meshstream.net/zh/docs/sdk/uniapp-setup/#平台网络配置)。

## 快速开始

在页面中准备播放器，`playbackUrl` 为 Vue 的响应式变量：

```html
<video v-if="playbackUrl" :src="playbackUrl" controls />
```

在播放按钮的异步处理函数中创建会话，并更新绑定地址：

```ts
import { ref, nextTick } from 'vue'
import { MeshStream } from '@/uni_modules/meshstream-p2p/javascript.js'

const playbackUrl = ref('')
// 以下在异步播放流程中执行，并由页面持有 client 和 session：
const client = await MeshStream.create({ key: 'key_your_platform_key', p2pEnabled: true })
const session = await MeshStream.createPlaybackSession(client.clientId, {
  url: 'https://cdn.example.com/live/playlist.m3u8',
  contentId: 'live-channel-42',
  mimeType: 'm3u8',
})
playbackUrl.value = session.playbackUrl
```

播放器继续使用 `session.playbackUrl`，无需等待 Peer。离开页面或切换内容时，在退出流程中先清空播放器绑定，再关闭旧会话；不再使用客户端时才关闭它：

```ts
playbackUrl.value = ''
await nextTick()
await MeshStream.closeSession(client.clientId, session.sessionId)
await MeshStream.closeClient(client.clientId)
```

这些片段分别属于初始化与退出流程；可运行页面见 [`example/pages/index/index.vue`](https://github.com/Mesh-Stream/meshstream-p2p-uniapp-sdk/blob/main/example/pages/index/index.vue)。Vue/JavaScript 中使用 `MeshStream` 静态 API，不调用返回对象上的实例方法。

## 运行 Demo

```bash
git clone https://github.com/Mesh-Stream/meshstream-p2p-uniapp-sdk.git
```

1. 在 HBuilderX 中打开仓库的 [`example/`](https://github.com/Mesh-Stream/meshstream-p2p-uniapp-sdk/tree/main/example) 目录（Vue 3 uni-app 工程）。
2. 确认 `uni_modules/meshstream-p2p` 已安装；在 `manifest.json` 中配置自己的应用标识。启用身份校验时，在控制台登记实际包名或 Bundle ID。
3. 制作并选择包含该插件的自定义调试基座，或进行云打包。标准基座不包含所需原生 SDK。Android 打包需保留示例启用的 `VideoPlayer` 模块；iOS 真机需签名证书和描述文件。
4. 运行到 Android / iOS，输入对应平台 Key、HTTPS 媒体地址并开始播放，查看页面的 Peer、P2P/HTTP 流量及诊断。

iOS 模拟器需要匹配架构的自定义基座：Apple Silicon 使用 arm64，Intel Mac 使用 x86_64。完整操作见[示例说明](https://github.com/Mesh-Stream/meshstream-p2p-uniapp-sdk/blob/main/example/README.md)。

## 预加载与事件

预加载使用 `await MeshStream.preload(client.clientId, session.sessionId)`。播放器位置和缓冲反馈分别使用 `updateCurrentPositionMs`、`updateBufferedDurationMs`，单位为毫秒，建议最多每秒更新一次。

通过 `const eventId = MeshStream.subscribeEvents(callback)` 订阅事件，退出前调用 `MeshStream.unsubscribeEvents(eventId)`。多会话时按 `clientId` / `sessionId` 区分事件归属。

<details>
<summary>排查 HBuilderX Android 依赖解析问题</summary>

### Android 仓库解析

若 HBuilderX 5.33 的临时 Gradle 工程因 `PREFER_SETTINGS` 找不到 Maven 依赖，可配置随插件提供的 [Gradle launcher](scripts/hbuilderx-gradle.sh)：

```bash
chmod +x uni_modules/meshstream-p2p/scripts/hbuilderx-gradle.sh
export MESHSTREAM_GRADLE_EXECUTABLE=/absolute/path/to/gradle
```

将变量改为实际 Gradle 可执行文件，并让 HBuilderX 能读取该变量；将 UTS Android 的 Gradle 可执行程序设为该脚本。脚本仅对 HBuilderX 临时依赖解析工程启用 `PREFER_PROJECT`。

</details>

## 网络与隐私

SDK Key 校验、配置获取、tracker 和用量上报会处理应用标识、设备平台、IP/网络连接信息、内容及分片标识、上下行流量和诊断数据。接入方应告知用户 P2P 会使用上行网络流量。不读取相机、麦克风、通讯录或精确定位，无广告。HTTP 明文访问仅对本机代理 `127.0.0.1` / `localhost` 开放。

## 确认 P2P 生效

1. 在两台设备或两个可同时运行的实例中，用各自有效的 Key 播放同一内容，保持相同清晰度和相近播放进度。签名 URL 会变化时，为同一内容使用相同、稳定的内容 ID；不同内容不要共用 ID。
2. 查看 Demo 的 Peer 数和流量统计。Peer 大于 0 表示已连接节点；**P2P 下载或上传字节持续增加**才说明发生了媒体共享。
3. 关闭另一个实例，确认剩余实例仍能通过 HTTP/CDN 播放；然后测试拖动、切换内容和退出页面的释放流程。

只有一个观看者或没有可共享分片时，主要走 HTTP/CDN 属于正常情况。发现 Peer 及实际共享还取决于账户配置、网络连通性和双方缓存内容。

## 更多用法与支持

预加载、直播/点播调度、播放器状态回传、多会话及诊断，请参阅[高级用法](https://meshstream.net/zh/docs/sdk/uniapp-advanced/)。更新记录见 [CHANGELOG](https://github.com/Mesh-Stream/meshstream-p2p-uniapp-sdk/blob/main/CHANGELOG.md)。接入问题请联系 support@meshstream.net，并附 SDK 版本、系统、播放器和脱敏日志。

## 其他 MeshStream SDK

- [Web](https://github.com/Mesh-Stream/meshstream-p2p-web-sdk): JavaScript / TypeScript 与浏览器播放器.
- [iOS / macOS](https://github.com/Mesh-Stream/meshstream-p2p-ios-sdk): MeshStreamKit、Swift / Objective-C、SPM 与 CocoaPods.
- [Android](https://github.com/Mesh-Stream/meshstream-p2p-android-sdk): Kotlin / Java、Maven 与 Media3 / ExoPlayer.
- [Windows](https://github.com/Mesh-Stream/meshstream-p2p-Windows-sdk): Windows 10 / 11 x64 C / C++ 接口.
- [Flutter](https://github.com/Mesh-Stream/meshstream-p2p-flutter-sdk): 面向 iOS / Android 的 Dart 插件.
- [React Native](https://github.com/Mesh-Stream/meshstream-p2p-react-native-sdk): 面向 iOS / Android 的 JavaScript / TypeScript API.
