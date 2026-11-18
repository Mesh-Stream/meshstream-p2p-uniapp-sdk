# MeshStream UniApp Demo

请使用 HBuilderX 将本目录作为 Vue 3 uni-app 项目打开。先通过 DCloud 插件市场安装 MeshStream P2P 插件，或将插件复制到本项目的 `uni_modules/meshstream-p2p` 目录。

请先运行到包含该插件的 Android 或 iOS 自定义基座，再进行云打包。输入已授权的 SDK Key 和 HTTPS 媒体地址。默认地址与 Web Demo 使用同一媒体，便于 Android 与 Web 实例加入同一个 swarm；如果地址会变化（例如签名地址或本地中转地址），请在两端填写相同且稳定的 `Content ID`。Demo 每两秒刷新一次统计，播放器位置和缓冲状态最多每秒回传一次；停止播放或页面销毁时会释放会话和客户端。Android 云打包时需保留 `manifest.json` 中配置的 `VideoPlayer` 模块。

详细接入步骤请参阅插件根目录的 [中文 README](../README.md)。
