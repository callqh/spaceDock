<p align="center">
  <img src="design/icon-concepts/spacebar-portal-v1.png" width="112" alt="SpaceDock 空格传送门图标">
</p>

# SpaceDock

[English](README.md) | **简体中文**

一个轻巧的原生 macOS 应用启动器。按住空格，再按一个键，把常用应用带到眼前。

- **Space + 自定义按键**：打开应用；当前应用已在前台时，再按一次隐藏。
- **当前桌面唤起**：将应用主窗口带到你所在的普通桌面，切走后窗口留在原处。
- **自由调整**：添加和编辑绑定、调整长按时间、排除应用、暂停快捷键。
- **安静常驻**：支持登录启动、隐藏菜单栏图标；关闭设置不会退出后台。
- **本地保存**：无需账号，配置保存在本机，不记录输入内容。

## 安装

从 [Releases](https://github.com/callqh/spaceDock/releases) 下载最新的
`SpaceDock-版本-macOS-arm64.zip`，解压后将 SpaceDock.app 放到 `~/Applications` 或“应用程序”。

当前发布目标为 **Apple Silicon（M 系列芯片）**，最低部署目标 macOS 13。
最低系统版本未完成真机验证；Intel、全屏 Space 和所有 macOS 版本的兼容性尚未保证。

安装包采用 ad-hoc 签名，尚未使用 Developer ID 签名或经过 Apple 公证。
下载的应用可能需要在“系统设置 → 隐私与安全性”中确认打开。仅对你确认来源的包执行此操作，无需关闭系统安全保护。

首次启动，在“系统设置 → 隐私与安全性 → 辅助功能”开启 SpaceDock。
本地构建或更新后，如果显示“需要授权”，可移除旧条目、重新添加当前安装的 SpaceDock.app 并开启。身份验证由你本人完成。

## 使用

1. 打开设置，点击“添加应用”，选择应用并录入字母或数字。
2. 按住空格，达到等待时间后按对应按键，例如 **Space + W**。
3. 需要应用跟随当前桌面时，开启该行的“当前桌面”。

| 模式 | 行为 |
| --- | --- |
| 当前桌面开启 | 先搬移主窗口，再唤起；切换桌面后不会继续覆盖新桌面 |
| 当前桌面关闭 | 普通应用唤起，是否跳转到原窗口桌面取决于 macOS 设置 |

普通模式需要自动跳到原窗口所在桌面时，请开启系统“桌面与程序坞 → 调度中心 → 切换到某个应用程序时，会切换到包含该应用程序的打开窗口的空间”。

开启“当前桌面”时，SpaceDock 会尝试将该应用 Dock 菜单的“分配给”设为“无”。仅搬移主窗口，不保证同时搬移独立聊天窗口，不支持全屏窗口。该功能依赖 macOS 私有窗口接口，系统升级后可能需要适配。

短按空格仍用于输入。默认长按阈值 200ms，可在偏好设置调整。
关闭设置可点击红色关闭按钮或按 **⌘W**；隐藏菜单栏图标后，通过聚焦搜索或访达再次打开 SpaceDock 即可返回设置。

更多说明见 [使用指南](docs/USER_GUIDE.md)。

## 本地开发

需要 macOS、Swift 6 工具链（测试使用 Swift Testing）及 Xcode 或 Command Line Tools。

```sh
git clone https://github.com/callqh/spaceDock.git
cd spaceDock
bash scripts/test.sh
bash scripts/build.sh
# 先退出正在运行的 SpaceDock
bash scripts/install.sh
```

- SwiftPM 工程，SwiftUI + AppKit，无第三方运行时依赖。
- `VERSION` 是版本号来源；可用 `SPACEDOCK_VERSION=1.1.0 bash scripts/build.sh` 覆盖本地构建版本。
- 构建输出：`dist/SpaceDock.app`、带版本和架构的 ZIP 及 SHA-256 校验文件。
- 安装脚本将旧包移至 `dist/install-backups/`，再完整安装到 `~/Applications/SpaceDock.app`，不删除用户配置。
- 本机 CLT 27 有 SwiftUI 宏插件问题，脚本优先使用已安装的 macOS 26.5 SDK，否则使用当前工具链 SDK。可通过 `SPACEDOCK_SDK` 指定 SDK。
- 测试和构建成功不代表全局按键、权限或跨桌面行为已经完成真机验收。

## 自动打包与 Release

工作流位于 [release.yml](.github/workflows/release.yml)：

- Pull Request 或手动运行：执行测试并上传构建产物，不发布 Release。
- 推送 `vX.Y.Z` 标签：核对标签与 `VERSION` 一致，测试、打包成功后自动发布 GitHub Release，附带 ZIP、SHA-256 和自动生成的更新说明。
- 使用 [GitHub 官方 `macos-15` Apple Silicon runner](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)。发布权限仅授予 Release job，无需额外仓库密钥。
- 当前未配置 Developer ID 签名与公证，CI 包同样为 ad-hoc 签名。

维护者发布示例（先更新 VERSION、提交并合并代码）：

```sh
git tag v1.1.1
git push origin v1.1.1
```

版本标签应指向已审查的提交。失败时先检查 Actions 日志；已发布版本不要移动标签，修复后递增版本。

## 项目资料

- [需求](spec.md) · [意向](INTENT.md) · [决策记录](DECISION.md)
- [架构](docs/architecture.md) · [验证记录](docs/verification.md)
- [设计 token](docs/design-tokens.md) · [设计原型](design/index.html)

HTML 原型是视觉参考，实际应用代码位于 Sources。
