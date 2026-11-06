# SpaceDock Design Tokens v0.5

日期：2026-11-06。状态：视觉提案。用户明确要求使用 frontend-design 技能按 Apple 设计风格重做。交付为 HTML 设计原型，不代表技术决策已获批准或已实现原生应用。

## 设计计划与自审

场景是每天使用的 Mac 启动器，采用 macOS 设置工具的组织方式。系统字体负责中文与英文；只在按键里使用等宽字体。浅色核心值：雾灰 #E9ECF2、内容白 #FFFFFF、分组背景 #F5F5F7、正文 #1D1D1F、辅助文字 #626268、操作蓝 #0066CC。蓝橙灰的小图标保留用户希望的活力，不把整窗染成主题色。

```text
原稿：大键帽 + 自由排列列表       v0.5：Mac 设置层级
┌──────┬─────────────────┐      ┌──────┬─────────────────┐
│导航  │大号 space + W   │      │彩色  │图标  标题与说明 │
│      │应用列表         │      │小图标│紧凑快捷键提示   │
│      │散落说明         │      │导航  │分组列表 + 操作  │
└──────┴─────────────────┘      │      │相关帮助         │
                                └──────┴─────────────────┘
```

全部左对齐；应用、按键、开关固定列对齐，窄屏换行。自审后删除大号杏橙键帽，减弱整窗背景染色，缩短控件和行高。分组边界用于区分快捷键说明、应用绑定和输入说明，不使用重复投影卡片。唯一明显的彩色区域是小型页面图标和操作按钮。

## 参考与解释范围

- [Apple HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)：材质帮助区分导航与内容，并与背景融合。
- [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)：优先使用平台标准组件；玻璃用于顶层导航和控制层。

上述为设计依据，具体 CSS 是视觉近似。没有复刻官方系统资源、没有调用原生 Liquid Glass，也不保证所有 macOS 版本完全相同。未来实现应优先采用系统控件并尊重系统外观及辅助功能偏好。

## 数值来源与文件

- [tokens.json](../design/tokens.json)：唯一 token 数值来源，项目自定义格式，非 DTCG 导入包。
- [build_preview.py](../design/build_preview.py)：生成 [tokens.css](../design/tokens.css) 与 [对比度报告](../design/contrast-check.md)。
- [index.html](../design/index.html)：交互原型，直接打开可用，无远程字体或图片。
- [页面设计与验证](pages.md)、[浅色截图](../design/preview.png)、[深色截图](../design/preview-dark.png)、[窄屏截图](../design/preview-mobile.png)。

v0.4 备份位于工作空间 `.workspace-history/20261106-093123/`，含 manifest。功能范围不变；权威 spec 仅追加已确认的视觉方向。

## 语义 token

| Token | 用途 |
|---|---|
| canvas / surface / surfaceSubtle | 外部画布、内容分组、设置页背景。内容保持不透明。 |
| textPrimary / textSecondary / textDisabled | 正文、帮助、真正不可操作的文字。 |
| border / controlBorder | 装饰性分隔 / 必须能辨认的控件边界。 |
| accent / onAccent / accentSubtle | 主操作、按钮文字、轻量选择底色。 |
| iconBlue / iconOrange / iconGray | 导航的小型彩色图标底色，不用于正文。白色图形同时有文字标签，非唯一信息通道。 |
| spark / sparkInk | 温和的帮助图标底色及图形，不表示警告。 |
| success / warning / danger | 已启用、需要授权、冲突与失败，始终搭配文字。 |
| focus | 2pt 焦点外环，偏移 2pt。 |

深色表面采用中性灰，不沿用上一版的大片松绿色。深浅主题独立配置文字和操作色；主题按钮只是审阅工具，产品默认跟随系统。

## 字体与尺寸

系统字体；标题 20/28pt、正文与分组 13/20pt、辅助 12/18pt。预览少量表格标签使用 10–11px，原生实现需结合系统字号、缩放和真实字体指标验收，不将网页数值当作平台硬性要求。

4pt 间距基数。窗口候选宽 820pt、侧栏 184pt、内容边距 28pt；行高候选 64pt，原型为内容留出 66px。控件最低 30pt，绑定工具栏的紧凑按钮在网页中为 27px。所有尺寸应允许字体增长和内容换行，不能靠截断关键提示实现密度。

键帽圆角 6pt、分组 10pt、窗口 16pt。键帽底边 2pt。玻璃仅用于窗口外层、侧栏、标题栏及浮层；内容分组不透明，无重复阴影。全局模糊候选 32px、饱和度 1.35，仅代表网页效果，不对应 Apple 原生材质参数。

## 状态与可访问性

添加/编辑保留输入，按键冲突说明占用者；无绑定提供添加入口。未授权状态同步到侧栏和菜单栏，不能继续显示已启用。暂停具有明确的恢复操作。重复绑定、单应用隐藏、全局暂停等行为仍是前端模拟。

减少透明度、增强对比度或浏览器不支持模糊时回退到不透明语义色。减少动态效果时取消过渡。CSS 阴影、高光和示意交通灯不是交互必需信息。网页包含原生 dialog、Esc 关闭、输入标签、焦点、switch 状态与状态播报。

22 组固定色对检查针对不透明颜色，正文目标 4.5:1，必要控件边界及焦点目标 3:1。检查不覆盖任意背景上的透明合成，也不能替代原生 VoiceOver、系统键盘导航和真实壁纸验收。
