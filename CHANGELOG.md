# 更新日志

## 1.1.4 - candidate

- 为 iOS `MeshStreamKit 1.1.2` 依赖显式指定公开 CocoaPods Specs source，避免云端构建使用滞后的镜像索引。
- 修正 iOS bootstrap 延迟完成时 Uniapp 会话仍显示初始 `CONFIG_UNAVAILABLE` 快照的问题；真实 P2P 传输仍以下载/上传字节为准。
- 修正双端 Telemetry 在 tracker 短暂报错后继续显示 CDN 的问题；有实时 P2P peer 或下载字节时刷新为 P2P 状态并清除过期回退原因。

## 1.1.3 - 2026-11-18

- 从原生会话刷新播放模式和回退状态，使延迟完成的 bootstrap 与 P2P 状态变化能同步给 Uniapp 调用方。
- Android 和 iOS 原生公开依赖继续固定为 1.1.2。
- 更新验收示例，同时展示 P2P 上传字节和下载统计。
- 已用官方市场精确包完成 HBuilderX 5.34 Android UTS 编译，生成并校验 `index.jar` 与 `classes.dex`。

## 1.1.1 - 2026-11-14

- Android 和 iOS 原生 SDK 依赖升级至 1.1.1。
- 使用公开 Maven 与 CocoaPods 依赖发布到 DCloud 插件市场。

## 未发布

- JavaScript API 拒绝 iOS 原生错误响应，包括会话关闭后的统计和诊断查询。
- 增加可重复的 HBuilderX 5.33/5.34 本地 Gradle 配置与恢复命令；启动器保留已配置的 Gradle 可执行文件，无需 GUI 环境变量，并仅在 HBuilderX 依赖解析工程中启用仓库临时配置。
- 固化 Uniapp 发布语言规范：DCloud 主说明、更新日志和用户可见文案默认使用简体中文，英文说明单独保存在 `README.en-US.md`。

## 1.1.0 - 2026-11-12

- Android 和 iOS 原生 SDK 依赖固定为 1.1.0。
- 采用原生 Peer 发现调度更新，同时保持现有公开 API 不变。

## 1.0.7 - 2026-11-09

- 将 iOS MeshStreamKit 和 Android 原生依赖统一升级至 1.0.10。
- 保持 Android API 21+、iOS 15+ 及 Android 四种 ABI 支持。
- 同步双端依赖配置、版本检查和接入说明。

## 1.0.6 - 2026-11-01

- 升级 Android 原生依赖至 1.0.9，包含 armeabi-v7a、arm64-v8a、x86、x86_64 四种 ABI。
- 保持 iOS MeshStreamKit 1.0.8、Android API 21+ 与 iOS 15+ 的插件要求。
- 更新接入说明、模拟器架构说明和示例。

## 1.0.5 - 2026-11-01

- 修复新版 UTS/Kotlin 编译器的只读属性初始化错误，公开属性保持只读。
- 升级 Android 公共依赖至 meshstream-android-sdk 1.0.8，沿用 iOS MeshStreamKit 1.0.8。
- 将插件 Android 声明下限从 API 24 调整为 API 21，应用仍需满足框架和播放器要求。
- 区分插件声明下限、示例构建目标与真机验收范围。

## 1.0.4

- iOS 公开依赖升级至 MeshStreamKit 1.0.8（iOS 15+）。
- Android 公开依赖升级至 meshstream-android-sdk 1.0.7。
- Uniapp bridge 与原生 SDK 的关闭流程和代理连接清理修复保持一致。

## 1.0.2

- 为 Vue/JavaScript 调用方增加静态 `preload` 和 `setP2pEnabled` 方法。
- 增加数字事件订阅，并在 Demo 中使用，使清理流程不依赖 UTS 返回的函数。
- 增加带明确 UTS 结果回调的 JavaScript Promise 适配器，使 HBuilderX 5.33 能将原生错误传递给页面的 catch 处理。
- 修复 Android UTS Maven 仓库地址，使用规范的公开入口。
- 将 SDK 依赖组限制到公开 Maven 仓库，并记录 HBuilderX 5.33 的仓库解析处理。
- 修复 iOS UTS 事件取消订阅，按订阅 ID 比较而不是比较函数。
- 增加 DCloud 权限、数据处理、广告和平台声明。
- 记录市场发布前 iOS 运行时验收待完成状态。

## 1.0.1

- iOS 公开依赖升级至 MeshStreamKit 1.0.7（iOS 15+）。
- Android 公开依赖升级至 meshstream-android-sdk 1.0.6。
