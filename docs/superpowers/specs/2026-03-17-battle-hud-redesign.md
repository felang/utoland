# 战斗 HUD 精简重设计

## 目标

去掉当前上下两条全屏半透明黑框，改为角落浮动的像素风小元素，减少视野遮挡。

## 当前状态

- **顶部条** (PanelContainer, 30px高, 横贯全屏): HP条、XP条、金币、波次、倒计时、击杀数
- **底部条** (PanelContainer, 30px高, 横贯全屏): Buff标签（穿甲/弹幕/暴击等）
- 两条黑框遮挡游戏视野

## 新设计

### 左上角（垂直排列，无背景面板）

1. **HP 条**
   - 像素风小方块图标（心形，红色背景，白色边框）— 用 PanelContainer + StyleBoxFlat 实现
   - 带边框进度条（宽约 80px，高 10px）
   - 进度条颜色随血量变化：绿色（>60%）→ 黄色（30-60%）→ 红色（<30%）
   - 不显示 HP 数值文字，只有进度条

2. **XP 条**（占位，经验值系统正在另一个会话中开发）
   - 像素风小方块图标（星形，深蓝背景，蓝色）
   - 带边框进度条（比 HP 条略细，高 8px）— 暂时填充 0%
   - 右侧等宽字体显示 "Lv.X"（读取 `GameData.player_level`）
   - 预留接口：当经验值系统就绪后，只需更新进度条的 `value` 即可

3. **金币**
   - 像素风小方块图标（深金背景，金色边框）
   - 右侧金色等宽字体显示数字
   - 保留金币变化时的弹跳动画

### 正上方居中

- 像素风小面板（暗色背景 + 边框）
- 显示 "第 x 波"（等宽字体，白色）
- 不显示总波次数、不显示倒计时

### 去掉的元素

- 击杀数（Kill: 0）
- Buff 标签（底部条整个移除）
- 倒计时
- 总波次数（原 "Wave x/10" 中的 "/10"）
- HP 数值文字（原 "100/100"）

### 保持不变

- HUD 仍为 CanvasLayer
- ShopOverlay（商店阶段底部面板）不受影响
- `set_battle_phase()` 接口保留

## 技术方案

### 修改文件

1. **`scenes/ui/hud.tscn`** — 重建场景树：
   - 移除 TopBar (PanelContainer) 和 BottomBar (PanelContainer)
   - 左上角：MarginContainer（锚点左上）> VBoxContainer > 三行 HBoxContainer（HP/XP/金币）
   - 正上方：CenterContainer（锚点顶部居中）> PanelContainer（小面板）> Label
   - 图标用 PanelContainer + StyleBoxFlat（colored background + border），内部放 Label 显示符号

2. **`scripts/ui/hud.gd`** — 精简脚本：
   - 移除 `_update_kills()`、`_update_timer()`、`_update_buffs()` 及相关变量
   - 移除 `wave_started`/`wave_completed` 中的 timer 和 kill 逻辑
   - 保留 `_update_hp()`（颜色变化逻辑不变）、`_update_coins()`（弹跳动画保留）
   - 波次显示改为 "第 x 波" 格式，通过 `wave_started` 信号更新
   - `set_battle_phase(false)` 时隐藏波次面板，`set_battle_phase(true)` 时显示
   - 颜色常量添加到 `UIConstants`（不硬编码）

### 不修改的文件

- `scripts/ui/main.gd` — 调用 HUD 的接口不变
- `scripts/core/event_bus.gd` — 信号保留（其他系统可能用到）
- `scripts/ui/shop_overlay.gd` — 无关

### 样式规范

- 图标方块：14x14px，PanelContainer + StyleBoxFlat，1px 边框，2px 圆角
- 进度条：80px 宽，StyleBoxFlat 背景 + 1px 边框，1px 圆角
- 字体：项目现有主题字体，无需额外字体资源
- 整体左上角偏移：约 (8, 8) 像素（通过 MarginContainer 的 margin 属性）
- 元素间距：2-3px（VBoxContainer 的 separation）
- 新增颜色常量到 `scripts/core/ui_constants.gd`：HUD 背景色、边框色、XP 蓝色等
