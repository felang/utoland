# 战斗 HUD 精简重设计 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将战斗 HUD 从上下两条全屏黑框改为角落浮动的像素风小元素，减少视野遮挡。

**Architecture:** 完全重写 `hud.tscn` 场景树和 `hud.gd` 脚本。新场景树分为两个锚定区域：左上角（HP/XP/金币垂直排列）和顶部居中（波次显示）。图标用 PanelContainer + StyleBoxFlat 实现像素风方块，进度条用 ProgressBar + StyleBoxFlat 自定义样式。

**Tech Stack:** Godot 4.6, GDScript

**Spec:** `docs/superpowers/specs/2026-03-17-battle-hud-redesign.md`

---

## Chunk 1: UIConstants 扩展 + HUD 场景重建 + 脚本重写

### Task 1: 添加 HUD 颜色常量到 UIConstants

**Files:**
- Modify: `scripts/core/ui_constants.gd:1-75`

- [ ] **Step 1: 添加 HUD 专用颜色常量**

在 `# 亲和色` 段落之后添加：

```gdscript
# HUD 像素风颜色
const COLOR_HUD_BG := Color("#1a1a2e")          # 进度条/面板背景
const COLOR_HUD_BORDER := Color("#444444")       # 进度条/面板边框
const COLOR_HUD_XP := Color("#6c9bff")           # 经验条蓝色
const COLOR_HUD_XP_BG := Color("#3a3a6e")        # 经验图标背景
const COLOR_HUD_COIN_BG := Color("#8a6c00")      # 金币图标背景
const COLOR_HUD_HP_YELLOW := Color("#e6c84b")    # HP 中等血量黄色

# HUD 尺寸
const HUD_ICON_SIZE := 14                        # 像素图标方块尺寸
const HUD_ICON_BORDER := 1                       # 图标边框宽度
const HUD_ICON_CORNER := 2                       # 图标圆角
const HUD_BAR_WIDTH := 80                        # 进度条宽度
const HUD_HP_BAR_HEIGHT := 10                    # HP 条高度
const HUD_XP_BAR_HEIGHT := 8                     # XP 条高度
const HUD_BAR_CORNER := 1                        # 进度条圆角
const HUD_MARGIN := 8                            # 左上角边距
const HUD_SPACING := 2                           # 元素间距
```

- [ ] **Step 2: 提交**

```bash
git add scripts/core/ui_constants.gd
git commit -m "feat: 添加 HUD 像素风颜色和尺寸常量到 UIConstants"
```

---

### Task 2: 重建 HUD 场景文件

**Files:**
- Rewrite: `scenes/ui/hud.tscn`

- [ ] **Step 1: 用新场景树完全重写 hud.tscn**

新场景树结构：
```
HUD (CanvasLayer)                          ← 保持不变
├── LeftTop (MarginContainer)              ← 锚点左上，margin 8px
│   └── VBox (VBoxContainer, separation=2)
│       ├── HPRow (HBoxContainer, separation=3)
│       │   ├── HPIcon (PanelContainer)    ← 14x14, 红底白框, 内含 Label "♥"
│       │   └── HPProgress (ProgressBar)   ← 80x10, 自定义样式
│       ├── XPRow (HBoxContainer, separation=3)
│       │   ├── XPIcon (PanelContainer)    ← 14x14, 深蓝底蓝框, 内含 Label "★"
│       │   ├── XPProgress (ProgressBar)   ← 80x8, 自定义样式
│       │   └── LevelLabel (Label)         ← "Lv.1"
│       └── CoinRow (HBoxContainer, separation=3)
│           ├── CoinIcon (PanelContainer)  ← 14x14, 深金底金框, 内含 Label "$"
│           └── CoinText (Label)           ← "0"
└── WaveCenter (MarginContainer)           ← 锚点顶部居中
    └── WavePanel (PanelContainer)         ← 暗色背景+边框
        └── WaveLabel (Label)              ← "第 1 波"
```

写入完整的 `.tscn` 文件：

```
[gd_scene format=3 uid="uid://cw1ribon6hcfu"]

[ext_resource type="Script" uid="uid://b5nyvbx3m1il2" path="res://scripts/ui/hud.gd" id="1_0mwgc"]

[node name="HUD" type="CanvasLayer" unique_id=1731831904]
script = ExtResource("1_0mwgc")

[node name="LeftTop" type="MarginContainer" parent="."]
anchors_preset = 0
offset_left = 8.0
offset_top = 8.0
offset_right = 200.0
offset_bottom = 80.0

[node name="VBox" type="VBoxContainer" parent="LeftTop"]
layout_mode = 2
theme_override_constants/separation = 2

[node name="HPRow" type="HBoxContainer" parent="LeftTop/VBox"]
layout_mode = 2
theme_override_constants/separation = 3

[node name="HPIcon" type="PanelContainer" parent="LeftTop/VBox/HPRow"]
custom_minimum_size = Vector2(14, 14)
layout_mode = 2
size_flags_vertical = 4

[node name="Label" type="Label" parent="LeftTop/VBox/HPRow/HPIcon"]
layout_mode = 2
horizontal_alignment = 1
vertical_alignment = 1

[node name="HPProgress" type="ProgressBar" parent="LeftTop/VBox/HPRow"]
custom_minimum_size = Vector2(80, 10)
layout_mode = 2
size_flags_vertical = 4
max_value = 100.0
value = 100.0
show_percentage = false

[node name="XPRow" type="HBoxContainer" parent="LeftTop/VBox"]
layout_mode = 2
theme_override_constants/separation = 3

[node name="XPIcon" type="PanelContainer" parent="LeftTop/VBox/XPRow"]
custom_minimum_size = Vector2(14, 14)
layout_mode = 2
size_flags_vertical = 4

[node name="Label" type="Label" parent="LeftTop/VBox/XPRow/XPIcon"]
layout_mode = 2
horizontal_alignment = 1
vertical_alignment = 1

[node name="XPProgress" type="ProgressBar" parent="LeftTop/VBox/XPRow"]
custom_minimum_size = Vector2(80, 8)
layout_mode = 2
size_flags_vertical = 4
max_value = 100.0
value = 0.0
show_percentage = false

[node name="LevelLabel" type="Label" parent="LeftTop/VBox/XPRow"]
layout_mode = 2
text = "Lv.1"

[node name="CoinRow" type="HBoxContainer" parent="LeftTop/VBox"]
layout_mode = 2
theme_override_constants/separation = 3

[node name="CoinIcon" type="PanelContainer" parent="LeftTop/VBox/CoinRow"]
custom_minimum_size = Vector2(14, 14)
layout_mode = 2
size_flags_vertical = 4

[node name="Label" type="Label" parent="LeftTop/VBox/CoinRow/CoinIcon"]
layout_mode = 2
horizontal_alignment = 1
vertical_alignment = 1

[node name="CoinText" type="Label" parent="LeftTop/VBox/CoinRow"]
layout_mode = 2
text = "0"

[node name="WaveCenter" type="MarginContainer" parent="."]
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -50.0
offset_top = 8.0
offset_right = 50.0
offset_bottom = 32.0
grow_horizontal = 2

[node name="WavePanel" type="PanelContainer" parent="WaveCenter"]
layout_mode = 2

[node name="WaveLabel" type="Label" parent="WaveCenter/WavePanel"]
layout_mode = 2
text = "第 1 波"
horizontal_alignment = 1
```

- [ ] **Step 2: 提交**

```bash
git add scenes/ui/hud.tscn
git commit -m "feat: 重建 HUD 场景树为像素风浮动布局"
```

---

### Task 3: 重写 HUD 脚本

**Files:**
- Rewrite: `scripts/ui/hud.gd`

- [ ] **Step 1: 完全重写 hud.gd**

```gdscript
extends CanvasLayer

## 精简战斗 HUD：左上角 HP/XP/金币，顶部居中波次显示

const HP_COLOR_HIGH_THRESHOLD: float = 0.6
const HP_COLOR_LOW_THRESHOLD: float = 0.3

# 节点引用 — 左上角
@onready var hp_icon: PanelContainer = $LeftTop/VBox/HPRow/HPIcon
@onready var hp_progress: ProgressBar = $LeftTop/VBox/HPRow/HPProgress
@onready var xp_icon: PanelContainer = $LeftTop/VBox/XPRow/XPIcon
@onready var xp_progress: ProgressBar = $LeftTop/VBox/XPRow/XPProgress
@onready var level_label: Label = $LeftTop/VBox/XPRow/LevelLabel
@onready var coin_icon: PanelContainer = $LeftTop/VBox/CoinRow/CoinIcon
@onready var coin_text: Label = $LeftTop/VBox/CoinRow/CoinText
# 节点引用 — 顶部居中
@onready var wave_panel: PanelContainer = $WaveCenter/WavePanel
@onready var wave_label: Label = $WaveCenter/WavePanel/WaveLabel

var player: Node2D = null
var _last_coins: int = -1

func _ready() -> void:
	player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if not player:
		push_warning("HUD: Player node not found in 'player' group")
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.player_level_changed.connect(_on_player_level_changed)
	_style_ui()

func _process(_delta: float) -> void:
	_update_hp()
	_update_coins()

# ===== HP 更新 =====

func _update_hp() -> void:
	if not player or not is_instance_valid(player):
		return
	var current: float = player.health.current_hp
	var max_hp: float = player.health.max_hp
	hp_progress.max_value = max_hp
	hp_progress.value = current
	# 进度条颜色编码：绿 → 黄 → 红
	var ratio := current / max_hp if max_hp > 0 else 0.0
	var color: Color
	if ratio > HP_COLOR_HIGH_THRESHOLD:
		color = UIConstants.COLOR_POSITIVE
	elif ratio > HP_COLOR_LOW_THRESHOLD:
		color = UIConstants.COLOR_HUD_HP_YELLOW
	else:
		color = UIConstants.COLOR_ACCENT_DANGER
	var fill_style := hp_progress.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		fill_style.bg_color = color

# ===== 金币更新 =====

func _update_coins() -> void:
	if player and is_instance_valid(player):
		var current_coins: int = player.coins
		coin_text.text = str(current_coins)
		if _last_coins >= 0 and current_coins != _last_coins:
			_bounce_label(coin_text)
		_last_coins = current_coins

func _bounce_label(label: Control) -> void:
	label.pivot_offset = label.size / 2
	var tween: Tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(label, "scale", Vector2.ONE, 0.1)

# ===== 阶段切换 =====

func set_battle_phase(is_battle: bool) -> void:
	wave_panel.visible = is_battle

# ===== 信号回调 =====

func _on_wave_started(wave_number: int, _wave_data: WaveData) -> void:
	wave_label.text = "第 %d 波" % wave_number

func _on_player_level_changed(new_level: int) -> void:
	level_label.text = "Lv.%d" % new_level

# ===== 样式初始化 =====

func _style_ui() -> void:
	# HP 图标 — 红底白框小方块
	_style_icon(hp_icon, "♥", UIConstants.COLOR_ACCENT_DANGER, Color.WHITE)
	# XP 图标 — 深蓝底蓝框小方块
	_style_icon(xp_icon, "★", UIConstants.COLOR_HUD_XP_BG, UIConstants.COLOR_HUD_XP)
	# 金币图标 — 深金底金框小方块
	_style_icon(coin_icon, "$", UIConstants.COLOR_HUD_COIN_BG, UIConstants.COLOR_GOLD)

	# HP 进度条样式
	_style_progress_bar(hp_progress, UIConstants.COLOR_POSITIVE, UIConstants.HUD_HP_BAR_HEIGHT)
	# XP 进度条样式
	_style_progress_bar(xp_progress, UIConstants.COLOR_HUD_XP, UIConstants.HUD_XP_BAR_HEIGHT)

	# 等级标签
	level_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	level_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	level_label.text = "Lv.%d" % GameData.player_level

	# 金币文字
	coin_text.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	coin_text.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)

	# 波次面板
	var wave_style := StyleBoxFlat.new()
	wave_style.bg_color = UIConstants.COLOR_HUD_BG
	wave_style.border_color = UIConstants.COLOR_HUD_BORDER
	wave_style.border_width_left = UIConstants.HUD_ICON_BORDER
	wave_style.border_width_right = UIConstants.HUD_ICON_BORDER
	wave_style.border_width_top = UIConstants.HUD_ICON_BORDER
	wave_style.border_width_bottom = UIConstants.HUD_ICON_BORDER
	wave_style.corner_radius_top_left = UIConstants.HUD_ICON_CORNER
	wave_style.corner_radius_top_right = UIConstants.HUD_ICON_CORNER
	wave_style.corner_radius_bottom_left = UIConstants.HUD_ICON_CORNER
	wave_style.corner_radius_bottom_right = UIConstants.HUD_ICON_CORNER
	wave_style.content_margin_left = 8
	wave_style.content_margin_right = 8
	wave_style.content_margin_top = 2
	wave_style.content_margin_bottom = 2
	wave_panel.add_theme_stylebox_override("panel", wave_style)

	# 波次标签
	wave_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	wave_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
	wave_label.text = "第 %d 波" % max(GameData.current_wave, 1)

func _style_icon(panel: PanelContainer, symbol: String, bg_color: Color, border_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = UIConstants.HUD_ICON_BORDER
	style.border_width_right = UIConstants.HUD_ICON_BORDER
	style.border_width_top = UIConstants.HUD_ICON_BORDER
	style.border_width_bottom = UIConstants.HUD_ICON_BORDER
	style.corner_radius_top_left = UIConstants.HUD_ICON_CORNER
	style.corner_radius_top_right = UIConstants.HUD_ICON_CORNER
	style.corner_radius_bottom_left = UIConstants.HUD_ICON_CORNER
	style.corner_radius_bottom_right = UIConstants.HUD_ICON_CORNER
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = panel.get_child(0)
	label.text = symbol
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color.WHITE)

func _style_progress_bar(bar: ProgressBar, fill_color: Color, height: int) -> void:
	# 背景样式
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = UIConstants.COLOR_HUD_BG
	bg_style.border_color = UIConstants.COLOR_HUD_BORDER
	bg_style.border_width_left = UIConstants.HUD_ICON_BORDER
	bg_style.border_width_right = UIConstants.HUD_ICON_BORDER
	bg_style.border_width_top = UIConstants.HUD_ICON_BORDER
	bg_style.border_width_bottom = UIConstants.HUD_ICON_BORDER
	bg_style.corner_radius_top_left = UIConstants.HUD_BAR_CORNER
	bg_style.corner_radius_top_right = UIConstants.HUD_BAR_CORNER
	bg_style.corner_radius_bottom_left = UIConstants.HUD_BAR_CORNER
	bg_style.corner_radius_bottom_right = UIConstants.HUD_BAR_CORNER
	bg_style.content_margin_left = 0
	bg_style.content_margin_right = 0
	bg_style.content_margin_top = 0
	bg_style.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", bg_style)
	# 填充样式
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = UIConstants.HUD_BAR_CORNER
	fill_style.corner_radius_top_right = UIConstants.HUD_BAR_CORNER
	fill_style.corner_radius_bottom_left = UIConstants.HUD_BAR_CORNER
	fill_style.corner_radius_bottom_right = UIConstants.HUD_BAR_CORNER
	fill_style.content_margin_left = 0
	fill_style.content_margin_right = 0
	fill_style.content_margin_top = 0
	fill_style.content_margin_bottom = 0
	bar.add_theme_stylebox_override("fill", fill_style)
	bar.custom_minimum_size = Vector2(UIConstants.HUD_BAR_WIDTH, height)
```

- [ ] **Step 2: 提交**

```bash
git add scripts/ui/hud.gd
git commit -m "feat: 重写 HUD 脚本为像素风浮动布局"
```

---

### Task 4: 运行验证

- [ ] **Step 1: 在 Godot 编辑器中运行游戏**

通过 gdai-mcp 的 `play_scene` 运行 main 场景，截图确认：
1. 左上角显示 HP 条（绿色进度条 + 红色心形图标）
2. 左上角显示 XP 条（蓝色进度条 + 蓝色星形图标 + Lv 文字）
3. 左上角显示金币（金色图标 + 金色数字）
4. 顶部居中显示"第 x 波"小面板
5. 上下黑框已消失
6. 商店阶段波次面板隐藏
7. 战斗阶段波次面板显示

- [ ] **Step 2: 最终提交（如有调整）**
