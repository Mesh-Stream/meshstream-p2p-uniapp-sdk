# MeshStream P2P Uniapp SDK

当前版本：**1.0.4**。1.0.2 已发布到 DCloud 插件市场；本版本将市场主说明、插件描述和变更记录统一为中文。

## 运行要求

- HBuilderX 4.25+、uni-app Vue 3 App；当前候选验证使用 HBuilderX 5.33。
- Android 7.0 / API 24+；iOS 15+。
- Android 公开依赖：`io.meshstream:meshstream-android-sdk:1.0.7`，Maven 地址 `https://sdk.meshstream.net/maven`。
- iOS 公开依赖：CocoaPods `MeshStreamKit = 1.0.8`。两个平台 native 运行时版本返回 `1.0.7`。
- 使用自定义基座或云打包；标准基座无法包含本插件所需的原生 SDK 和配置。

## 安装与接入

将插件 ZIP 内的文件解压到应用的 `uni_modules/meshstream-p2p/`，确保 `package.json` 直接位于该目录下。不要将仓库的 `example/`、发行记录或编译缓存复制到模块内。

Vue/JavaScript 页面请使用 `import { MeshStream } from '@/uni_modules/meshstream-p2p/javascript.js'`。此入口在 JavaScript 中管理 Promise，通过 UTS 明确回传成功或错误，避免 HBuilderX 5.33 原生异步拒绝无法传回页面而卡住。UTS 调用方仍可导入模块根目录。

## 快速开始

使用 `MeshStream` 静态 API 创建客户端和播放会话。播放器使用 `session.playbackUrl`，源媒体地址应使用 HTTPS：

```ts
import { MeshStream } from '@/uni_modules/meshstream-p2p/javascript.js'

const client = await MeshStream.create({
  key: 'key_你的 MeshStream Key',
  p2pEnabled: true,
})
const session = await MeshStream.createPlaybackSession(client.clientId, {
  url: 'https://cdn.example.com/live/playlist.m3u8',
  contentId: 'live-channel-42',
  mimeType: 'm3u8',
})

// 将 session.playbackUrl 绑定到现有 video 播放器。
const eventId = MeshStream.subscribeEvents((event) => {
  const type = event.getString ? event.getString('type') : event.type
  console.log('MeshStream 事件:', type)
})

await MeshStream.updateCurrentPositionMs(client.clientId, session.sessionId, positionMs)
await MeshStream.updateBufferedDurationMs(client.clientId, session.sessionId, bufferedDurationMs)

MeshStream.unsubscribeEvents(eventId)
await MeshStream.closeSession(client.clientId, session.sessionId)
await MeshStream.closeClient(client.clientId)
```

Vue/JavaScript 页面不要直接调用返回对象上的实例方法。预加载使用 `await MeshStream.preload(client.clientId, session.sessionId)`，切换 P2P 使用 `await MeshStream.setP2pEnabled(client.clientId, session.sessionId, enabled)`。

事件使用 `const id = MeshStream.subscribeEvents(callback)` 注册，再用 `MeshStream.unsubscribeEvents(id)` 取消。JavaScript 入口也支持 `addEventListener` 返回本地取消函数；旧的 UTS 入口返回函数无法可靠跨越 Vue/JavaScript 边界。

## 当前验收状态

Android/iOS UTS 编译已通过。Uniapp iOS 已在真实 iPhone 上完成播放验收，确认本地代理、P2P 统计和 CDN 回退链路可用；Android 也已完成真机播放和 P2P 验收。HBuilderX 5.33 自带的 Uniapp 模拟器基座只有 x86_64，Apple Silicon 模拟器不能直接使用该基座，因此 iOS 模拟器验收仍需 arm64 自定义基座。

## Android 仓库解析

HBuilderX 5.33 临时 Gradle 工程使用 `PREFER_SETTINGS`，会忽略插件配置里的 Maven 仓库。若提示找不到 SDK，可按英文 README 配置 `scripts/hbuilderx-gradle.sh` 和实际 Gradle 可执行文件，仅对 HBuilderX 临时依赖解析工程启用 `PREFER_PROJECT`。不需要拷贝本地 AAR，也不要修改已发布的原生 SDK。

## 网络与隐私

SDK Key 校验、配置获取、tracker 和用量上报会处理应用标识、设备平台、IP/网络连接信息、内容及分片标识、上下行流量和诊断数据。接入方应告知用户 P2P 会使用上行网络流量。不读取相机、麦克风、通讯录或精确定位，无广告。HTTP 明文访问仅对本机代理 `127.0.0.1` / `localhost` 开放。
