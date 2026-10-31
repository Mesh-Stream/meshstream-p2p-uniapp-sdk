# Changelog

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
