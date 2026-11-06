# v0.5 固定色对检查

2026-11-06。由 build_preview.py 根据 tokens.json 计算 sRGB 相对亮度。正文目标 4.5:1，必要边界与焦点目标 3:1。禁用文字与装饰分隔线不承担上述角色；此检查仅覆盖不透明回退色，不证明任意背景上的玻璃材质对比度，也不等于完整无障碍验收。

| 模式 | 色对 | 比值 |
|---|---|---|
| light | textPrimary / surface | 16.83:1 |
| light | textSecondary / surface | 6.06:1 |
| light | textSecondary / canvas | 5.12:1 |
| light | onAccent / accent | 5.57:1 |
| light | accent / accentSubtle | 4.94:1 |
| light | success / successSubtle | 5.72:1 |
| light | warning / warningSubtle | 5.53:1 |
| light | danger / dangerSubtle | 5.40:1 |
| light | controlBorder / surface | 3.76:1 |
| light | focus / surface | 5.57:1 |
| light | sparkInk / spark | 5.99:1 |
| dark | textPrimary / surface | 12.94:1 |
| dark | textSecondary / surface | 7.15:1 |
| dark | textSecondary / canvas | 8.53:1 |
| dark | onAccent / accent | 7.99:1 |
| dark | accent / accentSubtle | 6.44:1 |
| dark | success / successSubtle | 6.45:1 |
| dark | warning / warningSubtle | 6.62:1 |
| dark | danger / dangerSubtle | 6.19:1 |
| dark | controlBorder / surface | 4.57:1 |
| dark | focus / surface | 8.09:1 |
| dark | sparkInk / spark | 7.40:1 |
