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
   - 像素风小方块图标（心形，红色背景 `#e94560`，白色边框）
   - 带边框进度条（背景 `#1a1a2e`，边框 `#444`，宽约 80px，高 10px）
   - 进度条颜色随血量变化：绿色 `#4ecca3`（>60%）→ 黄色（30-60%）→ 红色 `#e94560`（<30%）

2. **XP 条**
   - 像素风小方块图标（星形，深蓝背景 `#3a3a6e`，蓝色 `#6c9bff`）
   - 带边框进度条（比 HP 条略细，高 8px）
   - 右侧等宽字体显示 "Lv3"

3. **金币**
   - 像素风小方块图标（深金背景 `#8a6c00`，金色边框 `#ffd700`）
   - 右侧金色等宽字体显示数字

### 正上方居中

- 像素风小面板（背景 `#1a1a2e`，边框 `#444`，圆角 2px）
- 显示 "第 x 波"（等宽字体，白色）
- 不显示总波次数、不显示倒计时

### 去掉的元素

- 击杀数（Kill: 0）
- Buff 标签（底部条整个移除）
- 倒计时
- 总波次数（原 "Wave x/10" 中的 "/10"）

### 保持不变

- HUD 仍为 CanvasLayer
- ShopOverlay（商店阶段底部面板）不受影响
- `set_battle_phase()` 接口保留（控制 HUD 在商店/战斗阶段的显示）

## 技术方案

### 修改文件

1. **`scenes/ui/hud.tscn`** — 重建场景树：
   - 移除 TopBar (PanelContainer) 和 BottomBar (PanelContainer)
   - 左上角：MarginContainer > VBoxContainer > 三行 HBoxContainer（HP/XP/金币）
   - 正上方：CenterContainer（顶部居中）> PanelContainer（小面板）> Label

2. **`scripts/ui/hud.gd`** — 精简脚本：
   - 移除 `_update_kills()`、`_update_timer()`、`_update_buffs()` 及相关变量
   - 移除 `wave_started`/`wave_completed` 中的 timer 和 kill 逻辑
   - 保留 `_update_hp()`（颜色变化逻辑不变）、`_update_coins()`（弹跳动画保留）
   - 波次显示改为 "第 x 波" 格式
   - `set_battle_phase()` 简化：商店阶段可隐藏波次或显示"准备中"

### 不修改的文件

- `scripts/ui/main.gd` — 调用 HUD 的接口不变
- `scripts/core/event_bus.gd` — 信号保留（其他系统可能用到）
- `scripts/ui/shop_overlay.gd` — 无关

### 样式规范

- 图标方块：14x14px，1px 白色/金色边框，2px 圆角
- 进度条：80px 宽，暗色背景 + 1px 边框，1px 圆角
- 字体：等宽字体（monospace）
- 整体左上角偏移：约 (8, 8) 像素
- 元素间距：2-3px
