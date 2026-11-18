# 发布语言规范

本仓库面向 DCloud 和国内 uni-app 用户，Uniapp 的公开发布材料统一以简体中文为主。

每个版本发布前必须检查：

- `package.json` 的插件描述、权限声明和数据处理声明使用中文；
- `README.md` 是面向 DCloud 和 GitHub 默认展示的中文接入说明；
- `README.zh-CN.md` 与 `README.md` 内容保持同步；
- `CHANGELOG.md` 的当前版本和未发布条目使用中文；
- `scripts/prepare-marketplace.py` 生成的 `readme.md`、`README.zh-CN.md` 和 `changelog.md` 保持中文主说明；
- iOS 权限提示等随插件进入宿主应用的用户可见文案使用中文，除非平台要求固定英文标识。

英文文档保存在 `README.en-US.md`，用于海外开发者参考，不作为 DCloud 插件市场的默认说明。发布包不依赖本地源码路径、内部凭据或未公开验收信息。

Flutter 和 React Native SDK 按各自仓库规范继续使用英文发布材料；本规则只适用于本 Uniapp 仓库和 DCloud 插件发布。
