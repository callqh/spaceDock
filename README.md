# SpaceDock

原生 macOS 菜单栏启动器：按住空格加一个键唤起应用，再次按键隐藏；可将应用主窗口召到当前桌面。普通唤起使用系统桌面切换设置。界面采用已确认的 Apple 风格 v0.5。

## 构建与使用

```sh
scripts/test.sh
scripts/build.sh
scripts/install.sh
```

- 安装位置：`~/Applications/SpaceDock.app`。
- 构建产物：`dist/SpaceDock.app`、`dist/SpaceDock-1.0.0-macOS.zip`。
- 首次运行需要用户授予辅助功能权限。详细流程见 [使用说明](docs/USER_GUIDE.md)。
- SwiftPM 原生工程，无第三方运行时依赖；Swift + AppKit + SwiftUI，目标 macOS 13+，当前只构建和验证 Apple Silicon 本机。
- 当前 CLT 27 的 SwiftUI 宏插件缺失，构建脚本选择已安装的 macOS 26.5 SDK。`SPACEDOCK_SDK` 可覆盖路径。测试使用 CLT 附带的 Swift Testing。
- ad-hoc 本地签名，未公证，不是已完成商业分发的安装包。测试工具需 macOS 14+，不代表产品最低版本已实测。

## 资料

- [需求](spec.md)、[意向](INTENT.md)、[已批准的决策](DECISION.md)。
- [架构](docs/architecture.md)、[运行验证记录](docs/verification.md)。
- [设计 token](docs/design-tokens.md)、[token JSON](design/tokens.json)。
- [设计原型](design/index.html)、[页面设计](docs/pages.md)。HTML 原型不控制系统，原生产品位于 Sources。

当前行为与实测边界以 [使用说明](docs/USER_GUIDE.md) 和 [验证记录](docs/verification.md) 为准。
