# Changelog

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

- Upgrade the public iOS dependency to MeshStreamKit 1.0.8 (iOS 15+).
- Upgrade the public Android dependency to meshstream-android-sdk 1.0.7.
- Align the Uniapp bridge with the native SDK shutdown and proxy connection cleanup fix.

## 1.0.2

- Add static `preload` and `setP2pEnabled` helpers for Vue/JavaScript callers.
- Add numeric event subscriptions for Vue/JavaScript and use them in the demo so cleanup does not depend on a returned UTS function.
- Add a JavaScript Promise adapter with explicit UTS result callbacks so native errors reach page catch handlers on HBuilderX 5.33.
- Fix the Android UTS Maven repository to use the canonical public endpoint.
- Restrict the SDK group to its public Maven repository and document the HBuilderX 5.33 repository workaround.
- Fix iOS UTS event unsubscription by comparing subscription IDs instead of callback functions.
- Add DCloud permissions, data collection, advertising, and platform declarations.
- Record pending iOS runtime acceptance before market publication.

## 1.0.1

- Upgrade the public iOS dependency to MeshStreamKit 1.0.7 (iOS 15+).
- Upgrade the public Android dependency to meshstream-android-sdk 1.0.6.
