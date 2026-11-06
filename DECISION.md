# 技术决策

当前结论：普通唤起使用系统桌面切换设置；当前桌面唤起先搬移再 reopen。预测隐藏及专用窗口焦点实验均已移除。以下按时间保留决定和被后续取代的依据，当前实现见 [架构](docs/architecture.md)。

日期：2026-11-05。状态：**Accepted**。2026-11-06 用户明确要求按照本版设计和架构完成产品。

## 依据

意向见 [INTENT.md](INTENT.md)，需求以 [spec.md](spec.md) 为准。当前是新项目，无既有实现或框架负担。

Apple 提供桌面变化通知、应用隐藏与唤起、全局事件过滤等接口，支持进行原型验证。接口存在不代表组合场景已可靠运行，尤其不能据此保证微信焦点、切换动画和第三方窗口层级。

## 选择及原因

1. **Swift + AppKit，SwiftUI 用于设置界面。** 单进程菜单栏应用，无服务器或后台特权守护进程。系统交互由 AppKit/CoreGraphics 适配层负责，设置界面不直接控制事件监听。符合个人小工具的体量，也方便定位权限与生命周期问题。
2. **过滤式 CGEvent tap + 独立按键状态机。** 普通观察器不能满足消费快捷键、避免把组合键打进当前应用的要求。按键处理与系统调用隔离，回调不执行磁盘读写或启动应用。
3. **桌面切换后隐藏受管应用，而非修改第三方窗口层级。** 使用 NSWorkspace 通知和 NSRunningApplication 隐藏接口；不使用私有 Spaces API，不宣称掌握桌面编号。全局隐藏是用户已接受的取舍。
4. **显式唤起建立管理资格。** 仅配置开启自动隐藏且通过本工具成功唤起的进程参与后续桌面隐藏。资格在成功隐藏、退出、关闭开关或暂停时清除。避免启动工具后批量干预已有应用。
5. **本地配置、无输入记录。** 绑定用应用 bundle identifier 与定位信息，配置为带版本的本地 Codable 文件，原子写入；运行时 PID 和临时事件状态不持久化。不引入数据库、遥测或网络服务。
6. **先面向本机直接运行。** 建议最低 macOS 13，以方便后续使用 SMAppService；兼容下限尚未验证。应用签名身份和固定安装路径需在可运行阶段验证，公开分发、公证与 App Store 不属于首版范围。

## 实际替代方案

| 方案 | 取舍 |
|---|---|
| 基于 Hammerspoon 等现有工具配置 | 可快速验证交互，但依赖外部宿主，配置体验和分发不符合独立简单应用的方向；可作为实验参照。 |
| Electron/Tauri 界面加原生桥接 | 仍需原生键盘及桌面控制，首版额外增加运行时或桥接边界，没有明显收益。 |
| 重新激活新桌面原应用，间接把微信压后 | 需要可靠确定目标及窗口，可能抢走焦点，也不能保证置底；不作为基础策略。 |
| 私有窗口/Spaces 接口实现真正置底 | 系统升级维护成本高，且超出已确认需求，不采用。 |

## 后果与可逆性

隐藏作用于整个应用，可能包括其独立聊天窗口和其他显示器上的窗口。多显示器作为明确验证边界，不能将全局通知解释成某个显示器的桌面编号。切换通知是在变化发生后收到，可能出现过渡帧。

空格候选事件需要短暂延迟，中文选词及快速输入是主要风险。若状态机实验不能满足输入验收，应调整触发方式并向用户说明，而非静默改变习惯。权限撤销或安全输入下不能保证全局快捷键始终可用。

模块通过小接口隔离系统行为，后续可替换触发策略或桌面策略。配置有 schemaVersion；改策略不应迫使用户重新设置绑定。具体流程见 [架构设计](docs/architecture.md)。

## 官方依据

查阅日期：2026-11-05。下列来源支持 API 能力；方案组合与产品表现仍待验证。

- [CGEvent 与 event tap](https://developer.apple.com/documentation/coregraphics/cgevent)
- [tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))
- [事件监听超时通知](https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout)
- [activeSpaceDidChangeNotification](https://developer.apple.com/documentation/appkit/nsworkspace/activespacedidchangenotification)
- [NSRunningApplication.hide](https://developer.apple.com/documentation/appkit/nsrunningapplication/hide())
- [AppKit 应用激活机制，WWDC23](https://developer.apple.com/videos/play/wwdc2023/10054/)
- [SMAppService.mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp)


## 2026-11-06：预测性隐藏（已确认的架构例外）

用户明确接受预测：四指明确横滑即可提前隐藏；取消滑动或到达桌面边缘也不自动恢复，使用原快捷键唤回。该决定取代此前对所有私有接口的一概排除，仅允许隔离的触摸检测；不引入私有窗口层级或 Spaces 控制。

实验性开关默认关闭，旧配置保持兼容。独立辅助进程读取已连接触控板（含外接 Magic Trackpad）四指同向横移，只向主进程发送固定手势信号，不保存触点或内容。仅对已受管应用生效；无法启动或进程退出时回退到桌面通知。原型与构建通过不代表本机真实识别或延迟验收通过。


## 2026-11-06：当前桌面召回（当前微信策略）

用户确认独立原型“微信过来了，桌面没跳转”，同意接入 Space + W。微信使用按应用开关 `summonHere`，开启时关闭自动隐藏；原预测实验已关闭。这一决定取代微信此前的“所有桌面 + 切换后隐藏”策略，并允许下述私有窗口搬移接口。其他绑定保留原行为。

先捕获当前普通桌面，在不激活应用的条件下定位主窗口，使用 SkyLight 桥接搬移操作；轮询确认窗口归属已变成目标桌面，且请求仍有效、当前桌面未变，才激活。搬移失败不回退为直接激活，以免跳桌面。桌面切换、暂停、新请求或配置保存使旧请求失效。已提交给系统的异步搬移本身不能取消，因此连续操作仍需实测。

Dock 分配须设为“无”；暂不支持全屏源/目标。按已验证原型，选择应用面积最大的普通窗口作为主窗口。仅搬移主窗口，独立窗口和跨显示器坐标尚未保证。桥接代码在原生模块内运行，动态检查入口；不改 SIP、不注入 Dock。私有接口系统升级兼容性需重新验证。旧配置缺少 summonHere 时不开启，维持 schema 1 兼容。

独立原型系统状态及用户视觉确认已通过，正式 Space + W 已安装并恢复授权，最终双向唤回验收待用户反馈。验证详情见 docs/summon-space-probe.md。


2026-11-06 后续纠正：首次正式快捷键验收未通过，用户反馈微信未出现且跳桌面。独立原型通过不能视为正式流程通过。已改为直接处理已运行应用，不再提前发送 NSWorkspace 打开请求；窗口选择与成功原型保持一致，激活结果以随后实际状态确认。预测功能的 UI、主程序调用和打包辅助程序已移除（历史源码仅留在诊断目录/未打包目标），新版已安装并恢复授权，等待重新验收。


## 2026-11-06：移除旧自动隐藏，按应用管理当前桌面唤起

用户批准设置做减法并要求开启时自动取消 Dock 固定分配。删除旧运行时而不只是隐藏控件，保留解码字段兼容；不将旧 autoHide 自动等同 summonHere，避免未经设置的应用意外搬移窗口。现有微信召回行为保留。

自动分配采用已有辅助功能权限访问目标 Dock 图标的菜单，用应用 URL 精确匹配；只操作“选项 → 无”，读回后启用。已无分配的应用使用系统偏好只读检查直接通过（必须成功读取 app-bindings 字典；读取失败不等于无分配）。不修改整份系统配置、不重启 Dock。失败提供明确的手动设置路径。参考系统分配存储研究：https://github.com/cehbz/spacekit/blob/main/macos-spaces-research.md 。自动菜单转换仍需在实际有固定分配的应用上验证，已为“无”的应用通过不等于转换路径通过。


## 2026-11-06：区分进程激活与窗口重新打开

用户报告 Chrome 普通模式不返回原桌面，微信出现一次、关闭窗口后无法再打开。实际失败复现中，诊断记录确认组合键进入 trigger；微信搬移 completion=success；两应用 activate() 均返回 true，但用户仍未看到窗口。此处不能将进程 active 等同窗口显示。

修正版在完成必要的搬移并校验目标桌面后，通过 NSWorkspace.openApplication(activates=true) 请求重新显示窗口；普通模式直接进入该显示步骤。仍不在搬移已有窗口之前发送 reopen。前台同键隐藏增加主窗口当前可见条件，避免没有可见窗口时反而隐藏应用。1.5 秒后的提示检查窗口可见性，而非只检查 active。临时启动诊断已从 Sources 移除。构建与 18 项核心测试通过，真实窗口行为仍需用户验收；没有用纯状态单元测试冒充跨桌面/外部应用窗口回归。


## 2026-11-06：保持全局设置关闭的普通窗口唤起

用户选择只让 SpaceDock 单独处理。参考 AltTab 的窗口级激活方式，动态查找 `_SLPSSetFrontProcessWithOptions` 并使用目标窗口 ID 与 userGenerated(0x200)，辅以 AX 恢复最小化/置为主窗口/raise。仅在普通模式 reopen 完成后调用；summonHere 分支不使用此方法。未设置或注入 Dock，不改 SIP，不读窗口标题/内容。此接口为私有接口，系统升级后需复验；动态入口不可用或没有窗口时提示失败。参考：https://github.com/lwouis/alt-tab-macos/blob/master/src/switcher/state/Window.swift 。本地构建与现有 18 项核心测试通过不等同桌面行为通过。

上述初版仅 front-process + AX raise 在本机 Chrome 实测失败。按 AltTab 完整流程补上目标窗口 make-key 事件：SLPSPostEventRecordTo，0x100 零初始化记录，窗口 ID 定向，坐标远离内容（300000,300000），仅 mouse-down，不构成完整点击。接口动态检查，仅普通模式使用；系统升级兼容性仍需复验。


2026-11-06 代码收敛：用户确认开启系统桌面切换设置后“可以了”，并要求移除排查期间的无用代码后提交。普通模式最终依赖 NSWorkspace reopen 与系统设置；失败的 SLPS 窗口焦点/合成事件分支已删除。触控板预测、隐藏计时和搬移试验原型移出仓库并存入工作空间历史快照。旧 autoHide/predictiveHide 模型字段删除，Codable 仍可忽略旧字段读取 schema 1，新增迁移回归测试确保快捷键与 summonHere 不丢失。
