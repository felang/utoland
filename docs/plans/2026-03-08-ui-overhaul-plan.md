# UI 全面重做实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 系统性重做全部游戏 UI，建立统一主题系统，重做 HUD/商店/角色选择/地图选择/开始菜单/结算屏。

**Architecture:** 创建全局 Theme 资源 + UI 常量脚本作为基础设施，然后用场景模板化替代硬编码 UI，所有界面使用锚点布局适配分辨率。GameData 新增统计字段支撑结算屏。

**Tech Stack:** Godot 4.6, GDScript, Theme 资源, StyleBoxFlat, GUT 测试

---

### Task 1: UI 常量脚本

**Files:**
- Create: `scripts/core/ui_constants.gd`
- Test: `tests/unit/test_ui_constants.gd`

**Step 1: Write the failing test**

```gdscript
# tests/unit/test_ui_constants.gd
extends GutTest

func test_colors_defined() -> void:
	assert_not_null(UIConstants.COLOR_BG_PRIMARY)
	assert_not_null(UIConstants.COLOR_BG_PANEL)
	assert_not_null(UIConstants.COLOR_ACCENT_DANGER)
	assert_not_null(UIConstants.COLOR_GOLD)
	assert_not_null(UIConstants.COLOR_POSITIVE)
	assert_not_null(UIConstants.COLOR_RARITY_COMMON)
	assert_not_null(UIConstants.COLOR_RARITY_RARE)
	assert_not_null(UIConstants.COLOR_RARITY_EPIC)

func test_font_sizes_defined() -> void:
	assert_eq(UIConstants.FONT_SIZE_TITLE, 32)
	assert_eq(UIConstants.FONT_SIZE_SUBTITLE, 24)
	assert_eq(UIConstants.FONT_SIZE_BODY, 18)
	assert_eq(UIConstants.FONT_SIZE_SMALL, 14)

func test_rarity_color_helper() -> void:
	assert_eq(UIConstants.get_rarity_color("common"), UIConstants.COLOR_RARITY_COMMON)
	assert_eq(UIConstants.get_rarity_color("rare"), UIConstants.COLOR_RARITY_RARE)
	assert_eq(UIConstants.get_rarity_color("epic"), UIConstants.COLOR_RARITY_EPIC)
	# 未知稀有度返回 common 色
	assert_eq(UIConstants.get_rarity_color("unknown"), UIConstants.COLOR_RARITY_COMMON)
```

**Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_ui_constants -gexit`
Expected: FAIL — UIConstants class not found

**Step 3: Write minimal implementation**

```gdscript
# scripts/core/ui_constants.gd
class_name UIConstants

# ===== 配色方案 =====
const COLOR_BG_PRIMARY := Color("#1a1a2e")
const COLOR_BG_PANEL := Color("#16213e")
const COLOR_BG_PANEL_ALPHA := Color(0.086, 0.129, 0.243, 0.9)  # #16213e @ 90%
const COLOR_ACCENT_DANGER := Color("#e94560")
const COLOR_GOLD := Color("#ffd700")
const COLOR_POSITIVE := Color("#4ecca3")
const COLOR_TEXT_PRIMARY := Color("#e0e0e0")
const COLOR_TEXT_SECONDARY := Color("#a0a0a0")
const COLOR_BUTTON_NORMAL := Color("#2a2a4a")
const COLOR_BUTTON_HOVER := Color("#3a3a6a")
const COLOR_BUTTON_PRESSED := Color("#1a1a3a")
const COLOR_BUTTON_DISABLED := Color("#333333")

# 稀有度色
const COLOR_RARITY_COMMON := Color("#9e9e9e")
const COLOR_RARITY_RARE := Color("#4fc3f7")
const COLOR_RARITY_EPIC := Color("#ab47bc")

# 亲和色
const COLOR_AFFINITY_SHOOTER := Color("#3388ff")
const COLOR_AFFINITY_ENGINEER := Color("#33cc55")

# ===== 字号 =====
const FONT_SIZE_TITLE := 32
const FONT_SIZE_SUBTITLE := 24
const FONT_SIZE_BODY := 18
const FONT_SIZE_SMALL := 14

# ===== 间距 =====
const MARGIN_SCREEN := 12
const MARGIN_PANEL := 16
const GAP_ITEMS := 12
const GAP_SECTIONS := 20

# ===== 圆角 =====
const CORNER_RADIUS_BUTTON := 8
const CORNER_RADIUS_PANEL := 12

# ===== 辅助方法 =====

static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		Enums.ItemRarity.RARE:
			return COLOR_RARITY_RARE
		Enums.ItemRarity.EPIC:
			return COLOR_RARITY_EPIC
		_:
			return COLOR_RARITY_COMMON

static func create_panel_stylebox(bg_color := COLOR_BG_PANEL_ALPHA, corner := CORNER_RADIUS_PANEL, border_color := Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_radius_bottom_right = corner
	if border_width > 0:
		style.border_color = border_color
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width
	style.content_margin_left = MARGIN_PANEL
	style.content_margin_right = MARGIN_PANEL
	style.content_margin_top = MARGIN_PANEL
	style.content_margin_bottom = MARGIN_PANEL
	return style

static func create_button_stylebox(color: Color, corner := CORNER_RADIUS_BUTTON) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_radius_bottom_right = corner
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
```

**Step 4: Register class_name in global_script_class_cache.cfg**

需要手动在 `.godot/global_script_class_cache.cfg` 添加 UIConstants 条目，否则 headless 测试无法识别：

```
UIConstants={"base":"RefCounted","icon":"","language":"GDScript","path":"res://scripts/core/ui_constants.gd"}
```

**Step 5: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_ui_constants -gexit`
Expected: PASS — 3 tests

**Step 6: Commit**

```bash
git add scripts/core/ui_constants.gd tests/unit/test_ui_constants.gd
git commit -m "feat: 新增 UIConstants 全局 UI 常量（配色/字号/间距/辅助方法）"
```

---

### Task 2: GameData 统计字段

**Files:**
- Modify: `scripts/core/game_data.gd`
- Test: `tests/unit/test_game_data_stats.gd`

**Step 1: Write the failing test**

```gdscript
# tests/unit/test_game_data_stats.gd
extends GutTest

func test_stats_fields_exist() -> void:
	assert_eq(GameData.total_kills, 0)
	assert_eq(GameData.total_coins_earned, 0)
	assert_eq(GameData.total_damage_taken, 0.0)
	assert_eq(GameData.max_kill_streak, 0)
	assert_eq(GameData.purchased_item_list.size(), 0)
	assert_eq(GameData.current_kill_streak, 0)

func test_record_kill_updates_stats() -> void:
	GameData.reset()
	GameData.record_kill()
	assert_eq(GameData.total_kills, 1)
	assert_eq(GameData.current_kill_streak, 1)
	assert_eq(GameData.max_kill_streak, 1)

	GameData.record_kill()
	assert_eq(GameData.total_kills, 2)
	assert_eq(GameData.current_kill_streak, 2)
	assert_eq(GameData.max_kill_streak, 2)

func test_reset_kill_streak() -> void:
	GameData.reset()
	GameData.record_kill()
	GameData.record_kill()
	GameData.reset_kill_streak()
	assert_eq(GameData.current_kill_streak, 0)
	assert_eq(GameData.max_kill_streak, 2)  # 最高纪录保留

func test_record_damage_taken() -> void:
	GameData.reset()
	GameData.record_damage_taken(25.5)
	assert_eq(GameData.total_damage_taken, 25.5)
	GameData.record_damage_taken(10.0)
	assert_eq(GameData.total_damage_taken, 35.5)

func test_record_coins_earned() -> void:
	GameData.reset()
	GameData.record_coins_earned(15)
	assert_eq(GameData.total_coins_earned, 15)

func test_record_item_purchased() -> void:
	GameData.reset()
	GameData.record_item_purchased("sharp_bullet")
	GameData.record_item_purchased("crit_shot")
	assert_eq(GameData.purchased_item_list, ["sharp_bullet", "crit_shot"])

func test_reset_clears_stats() -> void:
	GameData.record_kill()
	GameData.record_damage_taken(50.0)
	GameData.record_coins_earned(100)
	GameData.record_item_purchased("test")
	GameData.reset()
	assert_eq(GameData.total_kills, 0)
	assert_eq(GameData.total_coins_earned, 0)
	assert_eq(GameData.total_damage_taken, 0.0)
	assert_eq(GameData.max_kill_streak, 0)
	assert_eq(GameData.current_kill_streak, 0)
	assert_eq(GameData.purchased_item_list.size(), 0)
```

**Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_game_data_stats -gexit`
Expected: FAIL — fields/methods not found

**Step 3: Add fields and methods to GameData**

在 `scripts/core/game_data.gd` 中添加：

变量声明区（在 `auto_dash_distance` 后面）：
```gdscript
## ===== 本局统计 =====
var total_kills: int = 0
var total_coins_earned: int = 0
var total_damage_taken: float = 0.0
var max_kill_streak: int = 0
var current_kill_streak: int = 0
var purchased_item_list: Array[String] = []
```

新增方法（在 `reset()` 后面）：
```gdscript
func record_kill() -> void:
	total_kills += 1
	current_kill_streak += 1
	if current_kill_streak > max_kill_streak:
		max_kill_streak = current_kill_streak

func reset_kill_streak() -> void:
	current_kill_streak = 0

func record_damage_taken(amount: float) -> void:
	total_damage_taken += amount

func record_coins_earned(amount: int) -> void:
	total_coins_earned += amount

func record_item_purchased(item_id: String) -> void:
	purchased_item_list.append(item_id)
```

在 `reset()` 方法末尾追加：
```gdscript
	total_kills = 0
	total_coins_earned = 0
	total_damage_taken = 0.0
	max_kill_streak = 0
	current_kill_streak = 0
	purchased_item_list = []
```

**Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_game_data_stats -gexit`
Expected: PASS — 7 tests

**Step 5: Run all tests to verify no regression**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: All 195+ tests PASS

**Step 6: Commit**

```bash
git add scripts/core/game_data.gd tests/unit/test_game_data_stats.gd
git commit -m "feat: GameData 新增本局统计字段和记录方法"
```

---

### Task 3: 统计字段接入（战斗中累计数据）

**Files:**
- Modify: `scripts/entities/player.gd` — 受伤时调用 `record_damage_taken`，被击杀时 `reset_kill_streak`
- Modify: `scripts/ui/main.gd` — 敌人死亡时调用 `record_kill`，金币拾取时调用 `record_coins_earned`
- Modify: `scripts/systems/shop_manager.gd` — 购买时调用 `record_item_purchased`

**Step 1: 查看 player.gd 的受伤回调**

在 player.gd 中找到 `_on_hurtbox_hit` 方法（处理受伤的回调），在扣血后添加：
```gdscript
GameData.record_damage_taken(damage)
```

在 player 死亡时（`health.died` 信号回调），添加：
```gdscript
GameData.reset_kill_streak()
```

**Step 2: 查看 main.gd 的敌人死亡和金币拾取逻辑**

在敌人死亡处理中添加 `GameData.record_kill()`。
在金币拾取处理中添加 `GameData.record_coins_earned(amount)`。

**Step 3: 修改 shop_manager.gd**

在 `_buy_item()` 方法中，`GameData.purchased_items[item.id] = ...` 之后添加：
```gdscript
GameData.record_item_purchased(item.id)
```

**Step 4: Run all tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add scripts/entities/player.gd scripts/ui/main.gd scripts/systems/shop_manager.gd
git commit -m "feat: 战斗/商店中接入统计字段（击杀/金币/伤害/物品）"
```

---

### Task 4: HUD 重做 — 场景和脚本

**Files:**
- Rewrite: `scenes/ui/hud.tscn`
- Rewrite: `scripts/ui/hud.gd`

**Step 1: 重建 hud.tscn 场景**

使用 gdai-mcp 或手动重建。新场景结构：

```
CanvasLayer (hud)
├─ TopBar (MarginContainer, anchors: top full width)
│  └─ HBoxContainer
│     ├─ HPBar (HBoxContainer)
│     │  ├─ HPIcon (Label, text="HP")
│     │  ├─ HPProgress (ProgressBar, custom_minimum_size=120x16)
│     │  └─ HPText (Label)
│     ├─ CoinDisplay (HBoxContainer)
│     │  ├─ CoinIcon (Label, text="金")
│     │  └─ CoinText (Label)
│     ├─ HSeparator (spacer, size_flags_horizontal=EXPAND)
│     ├─ WaveDisplay (Label)
│     ├─ TimerDisplay (Label)
│     └─ KillDisplay (Label)
├─ BottomBar (MarginContainer, anchors: bottom full width)
│  └─ BuffContainer (HBoxContainer, alignment=CENTER)
│     (动态生成 buff 图标)
```

**Step 2: 重写 hud.gd**

```gdscript
# scripts/ui/hud.gd
extends CanvasLayer

@onready var hp_progress: ProgressBar = $TopBar/HBoxContainer/HPBar/HPProgress
@onready var hp_text: Label = $TopBar/HBoxContainer/HPBar/HPText
@onready var coin_text: Label = $TopBar/HBoxContainer/CoinDisplay/CoinText
@onready var wave_display: Label = $TopBar/HBoxContainer/WaveDisplay
@onready var timer_display: Label = $TopBar/HBoxContainer/TimerDisplay
@onready var kill_display: Label = $TopBar/HBoxContainer/KillDisplay
@onready var buff_container: HBoxContainer = $BottomBar/BuffContainer

var player: Node2D = null
var _wave_time_left: float = 0.0
var _is_wave_active: bool = false
var _wave_kills: int = 0

func _ready() -> void:
	player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if not player:
		push_warning("HUD: Player node not found in 'player' group")
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	_style_top_bar()
	_update_buffs()

func _process(delta: float) -> void:
	_update_hp()
	_update_coins()
	_update_timer(delta)
	_update_kills()

func _update_hp() -> void:
	if not player or not is_instance_valid(player):
		return
	var current := player.health.current_hp
	var max_hp := player.health.max_hp
	hp_progress.max_value = max_hp
	hp_progress.value = current
	hp_text.text = "%d/%d" % [int(current), int(max_hp)]
	# HP 颜色：绿 → 黄 → 红
	var ratio := current / max_hp if max_hp > 0 else 0.0
	if ratio > 0.6:
		hp_text.add_theme_color_override("font_color", UIConstants.COLOR_POSITIVE)
	elif ratio > 0.3:
		hp_text.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	else:
		hp_text.add_theme_color_override("font_color", UIConstants.COLOR_ACCENT_DANGER)

func _update_coins() -> void:
	if player and is_instance_valid(player):
		coin_text.text = str(player.coins)

func _update_timer(delta: float) -> void:
	if _is_wave_active:
		_wave_time_left -= delta
		if _wave_time_left < 0:
			_wave_time_left = 0.0
	var seconds := int(_wave_time_left)
	timer_display.text = "%ds" % seconds
	wave_display.text = "Wave %d/10" % GameData.current_wave
	# 最后 5 秒变红
	if _is_wave_active and seconds <= 5:
		timer_display.add_theme_color_override("font_color", UIConstants.COLOR_ACCENT_DANGER)
	else:
		timer_display.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)

func _update_kills() -> void:
	kill_display.text = "Kill: %d" % _wave_kills

func _style_top_bar() -> void:
	var top_bar := $TopBar
	var bg := UIConstants.create_panel_stylebox(
		Color(0.0, 0.0, 0.0, 0.5), 0
	)
	bg.content_margin_left = UIConstants.MARGIN_SCREEN
	bg.content_margin_right = UIConstants.MARGIN_SCREEN
	bg.content_margin_top = 4
	bg.content_margin_bottom = 4
	top_bar.add_theme_stylebox_override("panel", bg)
	# 字号
	for label in [wave_display, timer_display, kill_display]:
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	hp_text.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	coin_text.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	coin_text.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)

func _update_buffs() -> void:
	# 清除旧 buff 图标
	for child in buff_container.get_children():
		child.queue_free()
	# 从 GameData 读取激活状态
	var buffs: Array[String] = []
	if GameData.pierce_count > 0:
		buffs.append("穿甲x%d" % GameData.pierce_count)
	if GameData.multishot_active:
		buffs.append("弹幕")
	if GameData.lifesteal_ratio > 0:
		buffs.append("吸血%d%%" % int(GameData.lifesteal_ratio * 100))
	if GameData.crit_chance > 0:
		buffs.append("暴击%d%%" % int(GameData.crit_chance * 100))
	if GameData.current_shield > 0:
		buffs.append("护盾x%d" % GameData.current_shield)
	if GameData.damage_reduction > 0:
		buffs.append("减伤%d%%" % int(GameData.damage_reduction * 100))
	if GameData.dodge_chance > 0:
		buffs.append("闪避%d%%" % int(GameData.dodge_chance * 100))
	if GameData.slow_aura_active:
		buffs.append("减速光环")
	if GameData.auto_dash_active:
		buffs.append("自动冲刺")
	if GameData.coin_magnet_mult > 1.0:
		buffs.append("磁铁")
	if GameData.split_count > 0:
		buffs.append("分裂x%d" % GameData.split_count)
	if GameData.bullet_speed_mult > 1.0:
		buffs.append("弹速+")
	if GameData.weapon_range_mult > 1.0:
		buffs.append("射程+")

	for buff_text in buffs:
		var label := Label.new()
		label.text = buff_text
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
		var panel := PanelContainer.new()
		var style := UIConstants.create_panel_stylebox(Color(0.0, 0.0, 0.0, 0.6), 6, Color.TRANSPARENT, 0)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		panel.add_theme_stylebox_override("panel", style)
		panel.add_child(label)
		buff_container.add_child(panel)

func _on_wave_started(_wave_number: int, wave_data: WaveData) -> void:
	_is_wave_active = true
	_wave_time_left = wave_data.duration
	_wave_kills = 0
	_update_buffs()  # 刷新 buff（护盾可能在波次开始时重置）

func _on_wave_completed(_wave_number: int) -> void:
	_is_wave_active = false

func add_kill() -> void:
	_wave_kills += 1
```

**Step 3: 构建场景文件**

通过 gdai-mcp `create_scene` + `add_node` 构建 hud.tscn 场景树，或手动编辑 .tscn 文件。关键节点锚点设置：
- TopBar: anchors preset = top wide (10)
- BottomBar: anchors preset = bottom wide (12)

**Step 4: 在 main.gd 中接入 HUD kill 计数**

在敌人死亡回调中调用 `hud.add_kill()`（hud 是 main.tscn 的子节点）。

**Step 5: Run all tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add scenes/ui/hud.tscn scripts/ui/hud.gd scripts/ui/main.gd
git commit -m "feat: HUD 重做 — HP进度条/颜色编码/Buff栏/击杀计数"
```

---

### Task 5: 商店物品卡片模板

**Files:**
- Create: `scenes/ui/shop_item_card.tscn`
- Create: `scripts/ui/shop_item_card.gd`

**Step 1: 设计卡片场景结构**

```
PanelContainer (shop_item_card, custom_minimum_size=240x120)
├─ VBoxContainer
│  ├─ HeaderRow (HBoxContainer)
│  │  ├─ NameLabel (Label, size_flags_horizontal=EXPAND)
│  │  └─ LockButton (Button, custom_minimum_size=28x28)
│  ├─ DescLabel (Label, autowrap_mode=WORD)
│  └─ FooterRow (HBoxContainer)
│     ├─ PriceLabel (Label, size_flags_horizontal=EXPAND)
│     └─ BuyButton (Button, text="购买")
```

**Step 2: 写卡片脚本**

```gdscript
# scripts/ui/shop_item_card.gd
extends PanelContainer

signal buy_pressed(index: int)
signal lock_toggled(index: int)

@onready var name_label: Label = $VBoxContainer/HeaderRow/NameLabel
@onready var lock_button: Button = $VBoxContainer/HeaderRow/LockButton
@onready var desc_label: Label = $VBoxContainer/DescLabel
@onready var price_label: Label = $VBoxContainer/FooterRow/PriceLabel
@onready var buy_button: Button = $VBoxContainer/FooterRow/BuyButton

var slot_index: int = -1
var is_locked: bool = false

func _ready() -> void:
	buy_button.pressed.connect(func(): buy_pressed.emit(slot_index))
	lock_button.pressed.connect(_on_lock_pressed)
	_apply_base_style()

func setup(index: int, item: ShopItemData, price: int, locked: bool, can_afford: bool, can_buy: bool) -> void:
	slot_index = index
	is_locked = locked
	name_label.text = item.display_name
	desc_label.text = item.description
	price_label.text = "%d 金" % price
	price_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	lock_button.text = "L" if locked else "U"
	buy_button.disabled = not can_afford or not can_buy
	buy_button.text = "已满" if not can_buy else "购买"
	_apply_rarity_style(item)

func _apply_base_style() -> void:
	name_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	desc_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	desc_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	price_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	buy_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)

func _apply_rarity_style(item: ShopItemData) -> void:
	var border_color := UIConstants.get_rarity_color(item.rarity)
	# 检查亲和色覆盖
	var affinity_tags := _get_affinity_tags()
	for tag in item.tags:
		if tag in affinity_tags:
			match tag:
				Enums.ItemTag.SHOOTER:
					border_color = UIConstants.COLOR_AFFINITY_SHOOTER
				Enums.ItemTag.ENGINEER:
					border_color = UIConstants.COLOR_AFFINITY_ENGINEER
			break
	var style := UIConstants.create_panel_stylebox(
		UIConstants.COLOR_BG_PANEL_ALPHA, UIConstants.CORNER_RADIUS_PANEL,
		border_color, 2
	)
	add_theme_stylebox_override("panel", style)

func _get_affinity_tags() -> PackedStringArray:
	var char_id := GameData.current_character
	if not GameConfig.characters.has(char_id):
		return PackedStringArray()
	return GameConfig.characters[char_id].affinity_tags

func _on_lock_pressed() -> void:
	is_locked = not is_locked
	lock_button.text = "L" if is_locked else "U"
	lock_toggled.emit(slot_index)
```

**Step 3: 构建 shop_item_card.tscn**

通过 gdai-mcp 或手动创建场景文件，挂载 `shop_item_card.gd` 脚本。

**Step 4: Commit**

```bash
git add scenes/ui/shop_item_card.tscn scripts/ui/shop_item_card.gd
git commit -m "feat: 商店物品卡片模板（稀有度边框/描述/锁定按钮）"
```

---

### Task 6: 商店界面重做

**Files:**
- Rewrite: `scenes/ui/shop.tscn`
- Modify: `scripts/systems/shop_manager.gd` — 重构 UI 部分，保留逻辑方法

**Step 1: 重建 shop.tscn 场景结构**

```
Control (shop, anchors=full rect)
├─ Background (ColorRect, anchors=full rect, color=COLOR_BG_PRIMARY)
├─ MainPanel (MarginContainer, anchors=center, custom_minimum_size=520x420)
│  └─ VBoxContainer
│     ├─ HeaderRow (HBoxContainer)
│     │  ├─ CoinLabel (Label)
│     │  ├─ HSpacer (Control, expand)
│     │  ├─ TitleLabel (Label, text="商店")
│     │  ├─ HSpacer2 (Control, expand)
│     │  └─ WaveLabel (Label)
│     ├─ HSeparator
│     ├─ CardGrid (GridContainer, columns=2)
│     │  (4x shop_item_card 实例动态生成)
│     ├─ StatsPanel (PanelContainer)
│     │  └─ StatsGrid (GridContainer, columns=4)
│     │     (动态生成属性标签)
│     └─ ButtonRow (HBoxContainer, alignment=CENTER)
│        ├─ RefreshButton (Button)
│        └─ ConfirmButton (Button, text="出发")
```

**Step 2: 重构 shop_manager.gd 的 UI 部分**

保留所有逻辑方法（`_generate_shop`, `_buy_item`, `_apply_item_effect`, `_pick_rarity`, `_calculate_price`, `_can_buy`, `_get_rarity_weights`, `_get_affinity_tags`, `_get_affinity_discount`）不变。

替换 UI 相关代码：

```gdscript
# 替换旧的 @onready 引用
@onready var coin_label: Label = $MainPanel/VBoxContainer/HeaderRow/CoinLabel
@onready var wave_label: Label = $MainPanel/VBoxContainer/HeaderRow/WaveLabel
@onready var card_grid: GridContainer = $MainPanel/VBoxContainer/CardGrid
@onready var stats_grid: GridContainer = $MainPanel/VBoxContainer/StatsPanel/StatsGrid
@onready var refresh_button: Button = $MainPanel/VBoxContainer/ButtonRow/RefreshButton
@onready var confirm_button: Button = $MainPanel/VBoxContainer/ButtonRow/ConfirmButton

const SHOP_CARD_SCENE = preload("res://scenes/ui/shop_item_card.tscn")
var _card_nodes: Array = []

func _ready() -> void:
	refresh_button.pressed.connect(_on_refresh_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	_generate_shop()
	_create_card_nodes()
	_update_ui()
	_style_ui()

func _create_card_nodes() -> void:
	for child in card_grid.get_children():
		child.queue_free()
	_card_nodes.clear()
	for i in range(4):
		var card = SHOP_CARD_SCENE.instantiate()
		card.buy_pressed.connect(_buy_item)
		card.lock_toggled.connect(_on_lock_toggled)
		card_grid.add_child(card)
		_card_nodes.append(card)

func _on_lock_toggled(index: int) -> void:
	locked_slots[index] = not locked_slots[index]

# 替换 _update_ui
func _update_ui() -> void:
	coin_label.text = "金币: %d" % GameData.coins
	wave_label.text = "Wave %d/10" % (GameData.current_wave + 1)
	var refresh_cost := _get_refresh_cost()
	refresh_button.disabled = GameData.coins < refresh_cost
	refresh_button.text = "刷新 (%d)" % refresh_cost
	_display_items()
	_update_stats_panel()

# 替换 _display_items — 使用卡片模板
func _display_items() -> void:
	for i in range(min(shop_items.size(), 4)):
		var item := shop_items[i]
		var price := shop_prices[i]
		var card = _card_nodes[i]
		card.setup(i, item, price, locked_slots[i],
			GameData.coins >= price, _can_buy(item))

func _update_stats_panel() -> void:
	for child in stats_grid.get_children():
		child.queue_free()
	var stats: Array[String] = [
		"HP %d/%d" % [int(GameData.character_max_hp), int(GameData.character_max_hp)],
		"攻击 x%.1f" % GameData.player_stats[Enums.Stat.DAMAGE_MULT],
		"速度 x%.1f" % GameData.player_stats[Enums.Stat.MOVE_SPEED_MULT],
		"暴击 %d%%" % int(GameData.crit_chance * 100),
		"穿甲 x%d" % GameData.pierce_count,
		"吸血 %d%%" % int(GameData.lifesteal_ratio * 100),
		"减伤 %d%%" % int(GameData.damage_reduction * 100),
		"闪避 %d%%" % int(GameData.dodge_chance * 100),
	]
	for stat_text in stats:
		var label := Label.new()
		label.text = stat_text
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
		label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
		stats_grid.add_child(label)

func _style_ui() -> void:
	coin_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SUBTITLE)
	coin_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	confirm_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	refresh_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
```

删除旧的 `_connect_slot_buy_button`, `_connect_slot_lock_button`, `_toggle_lock`, `_update_slot_color`, `_get_slot_color` 方法和旧的 `item_containers` 引用。

**Step 3: Run all tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: All tests PASS（注意 `test_shop_manager_logic.gd` 可能需要适配新节点结构）

**Step 4: Commit**

```bash
git add scenes/ui/shop.tscn scripts/systems/shop_manager.gd
git commit -m "feat: 商店界面重做 — 2x2卡片网格/属性面板/统一样式"
```

---

### Task 7: 角色卡片模板

**Files:**
- Create: `scenes/ui/character_card.tscn`
- Create: `scripts/ui/character_card.gd`

**Step 1: 设计卡片场景结构**

```
PanelContainer (character_card, custom_minimum_size=160x240)
├─ VBoxContainer
│  ├─ PortraitRect (ColorRect, custom_minimum_size=140x60, 占位头像区)
│  ├─ NameLabel (Label, horizontal_alignment=CENTER)
│  ├─ StatsContainer (VBoxContainer)
│  │  ├─ HPLabel (Label)
│  │  ├─ SpeedLabel (Label)
│  │  └─ DamageLabel (Label)
│  ├─ AffinityLabel (Label, horizontal_alignment=CENTER)
│  ├─ WeaponLabel (Label, horizontal_alignment=CENTER)
│  └─ SelectButton (Button, text="选择")
```

**Step 2: 写卡片脚本**

```gdscript
# scripts/ui/character_card.gd
extends PanelContainer

signal selected(character_id: String)

@onready var portrait_rect: ColorRect = $VBoxContainer/PortraitRect
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var hp_label: Label = $VBoxContainer/StatsContainer/HPLabel
@onready var speed_label: Label = $VBoxContainer/StatsContainer/SpeedLabel
@onready var damage_label: Label = $VBoxContainer/StatsContainer/DamageLabel
@onready var affinity_label: Label = $VBoxContainer/AffinityLabel
@onready var weapon_label: Label = $VBoxContainer/WeaponLabel
@onready var select_button: Button = $VBoxContainer/SelectButton

var _character_id: String = ""

func _ready() -> void:
	select_button.pressed.connect(func(): selected.emit(_character_id))
	_apply_base_style()
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)

func setup(character_id: String, char_data: CharacterData, weapon_data: WeaponData) -> void:
	_character_id = character_id
	name_label.text = char_data.display_name
	hp_label.text = "HP  %d" % int(char_data.max_hp)
	speed_label.text = "速度  %d" % int(char_data.speed)
	damage_label.text = "攻击  x%.1f" % char_data.damage_mult
	# 亲和标签
	if char_data.affinity_tags.size() > 0:
		var tags := []
		for tag in char_data.affinity_tags:
			tags.append(tag)
		affinity_label.text = "亲和: %s  折扣%d%%" % [
			"/".join(tags), int(char_data.affinity_discount * 100)]
	else:
		affinity_label.text = ""
	weapon_label.text = "武器: %s" % weapon_data.display_name
	# 属性颜色（用基准值 100 对比）
	_color_stat(hp_label, char_data.max_hp, 100.0)
	_color_stat(speed_label, char_data.speed, 100.0)
	_color_stat(damage_label, char_data.damage_mult, 1.0)

func _color_stat(label: Label, value: float, baseline: float) -> void:
	if value > baseline:
		label.add_theme_color_override("font_color", UIConstants.COLOR_POSITIVE)
	elif value < baseline:
		label.add_theme_color_override("font_color", UIConstants.COLOR_ACCENT_DANGER)
	else:
		label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)

func set_selected(is_selected: bool) -> void:
	if is_selected:
		var style := UIConstants.create_panel_stylebox(
			UIConstants.COLOR_BG_PANEL_ALPHA, UIConstants.CORNER_RADIUS_PANEL,
			UIConstants.COLOR_GOLD, 2)
		add_theme_stylebox_override("panel", style)
		select_button.text = "已选择"
	else:
		_apply_base_style()
		select_button.text = "选择"

func _apply_base_style() -> void:
	var style := UIConstants.create_panel_stylebox()
	add_theme_stylebox_override("panel", style)
	name_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SUBTITLE)
	for label in [hp_label, speed_label, damage_label]:
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	affinity_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	weapon_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)

func _on_hover_enter() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)

func _on_hover_exit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)
```

**Step 3: 构建 character_card.tscn 场景**

**Step 4: Commit**

```bash
git add scenes/ui/character_card.tscn scripts/ui/character_card.gd
git commit -m "feat: 角色卡片模板（属性着色/亲和标签/悬停动画）"
```

---

### Task 8: 角色选择界面重做

**Files:**
- Rewrite: `scenes/ui/character_selection.tscn`
- Rewrite: `scripts/ui/character_selection.gd`

**Step 1: 重建场景结构**

```
Control (character_selection, anchors=full rect)
├─ Background (ColorRect, color=COLOR_BG_PRIMARY, anchors=full rect)
├─ VBoxContainer (anchors=center)
│  ├─ TitleLabel (Label, text="选择你的角色", font_size=32, center)
│  ├─ CardContainer (HBoxContainer, alignment=CENTER, separation=20)
│  │  (动态生成 character_card 实例)
│  ├─ DescPanel (PanelContainer, custom_minimum_size=500x60)
│  │  └─ DescLabel (Label, autowrap=WORD, center)
│  └─ BackButton (Button, text="← 返回主菜单")
```

**Step 2: 重写脚本**

```gdscript
# scripts/ui/character_selection.gd
extends Control

const CARD_SCENE = preload("res://scenes/ui/character_card.tscn")

@onready var _container: HBoxContainer = $VBoxContainer/CardContainer
@onready var _desc_label: Label = $VBoxContainer/DescPanel/DescLabel
@onready var _back_button: Button = $VBoxContainer/BackButton

var _cards: Array = []
var _selected_id: String = ""

func _ready() -> void:
	# 样式
	$Background.color = UIConstants.COLOR_BG_PRIMARY
	$VBoxContainer/TitleLabel.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TITLE)
	_back_button.pressed.connect(func(): SceneManager.go_to(Enums.Scene.START_MENU))

	# 生成卡片
	for child in _container.get_children():
		child.queue_free()
	_cards.clear()

	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		var weapon_data: WeaponData = GameConfig.weapons[char_data.default_weapon]
		var card = CARD_SCENE.instantiate()
		_container.add_child(card)
		card.setup(character_id, char_data, weapon_data)
		card.selected.connect(_on_character_selected)
		card.mouse_entered.connect(_on_card_hovered.bind(character_id))
		_cards.append(card)

func _on_card_hovered(character_id: String) -> void:
	var char_data: CharacterData = GameConfig.characters[character_id]
	_desc_label.text = char_data.passive_description if char_data.passive_description != "" else char_data.display_name

func _on_character_selected(character_id: String) -> void:
	_selected_id = character_id
	for card in _cards:
		card.set_selected(card._character_id == character_id)
	# 设置选择并跳转
	var char_data: CharacterData = GameConfig.characters[character_id]
	GameData.current_character = character_id
	GameData.selected_weapon = char_data.default_weapon
	GameData.init_character(character_id)
	SceneManager.go_to(Enums.Scene.MAP_SELECT)
```

**Step 3: Run all tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add scenes/ui/character_selection.tscn scripts/ui/character_selection.gd
git commit -m "feat: 角色选择界面重做 — 模板化卡片/属性着色/悬停说明"
```

---

### Task 9: 开始菜单重做

**Files:**
- Rewrite: `scenes/ui/start_menu.tscn`
- Modify: `scripts/ui/start_menu.gd`

**Step 1: 重建场景结构**

```
Control (start_menu, anchors=full rect)
├─ Background (ColorRect, color=COLOR_BG_PRIMARY, anchors=full rect)
├─ CenterContainer (anchors=full rect)
│  └─ VBoxContainer (alignment=CENTER, separation=20)
│     ├─ TitleLabel (Label, text="Survivor Tower Defense", font_size=32, center)
│     ├─ SubtitleLabel (Label, text="类幸存者塔防射击", font_size=14, center)
│     ├─ Spacer (Control, custom_minimum_size=0x30)
│     ├─ StartButton (Button, text="开始游戏", custom_minimum_size=200x44)
│     ├─ SettingsButton (Button, text="设置", custom_minimum_size=200x44)
│     └─ QuitButton (Button, text="退出", custom_minimum_size=200x44)
├─ VersionLabel (Label, text="v0.1.0", anchors=bottom-right)
```

**Step 2: 重写脚本**

```gdscript
# scripts/ui/start_menu.gd
extends Control

func _ready() -> void:
	$Background.color = UIConstants.COLOR_BG_PRIMARY
	var vbox := $CenterContainer/VBoxContainer
	vbox.get_node("TitleLabel").add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TITLE)
	vbox.get_node("SubtitleLabel").add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	vbox.get_node("SubtitleLabel").add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)

	vbox.get_node("StartButton").pressed.connect(_on_start_pressed)
	vbox.get_node("QuitButton").pressed.connect(func(): get_tree().quit())
	vbox.get_node("SettingsButton").disabled = true  # 占位

	# 按钮悬停效果
	for btn_name in ["StartButton", "SettingsButton", "QuitButton"]:
		var btn: Button = vbox.get_node(btn_name)
		btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
		btn.mouse_entered.connect(_on_button_hover.bind(btn))
		btn.mouse_exited.connect(_on_button_unhover.bind(btn))

func _on_start_pressed() -> void:
	SceneManager.go_to(Enums.Scene.CHARACTER_SELECTION)

func _on_button_hover(btn: Button) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)

func _on_button_unhover(btn: Button) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1)
```

**Step 3: Run all tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add scenes/ui/start_menu.tscn scripts/ui/start_menu.gd
git commit -m "feat: 开始菜单重做 — 新布局/按钮动画/设置占位/退出按钮"
```

---

### Task 10: 地图选择重做

**Files:**
- Rewrite: `scenes/ui/map_select.tscn`
- Rewrite: `scripts/ui/map_select.gd`

**Step 1: 重建场景结构**

```
Control (map_select, anchors=full rect)
├─ Background (ColorRect, color=COLOR_BG_PRIMARY, anchors=full rect)
├─ VBoxContainer (anchors=center)
│  ├─ TitleLabel (Label, text="选择地图", font_size=32, center)
│  ├─ MapContainer (HBoxContainer, alignment=CENTER, separation=20)
│  │  (动态生成地图卡片)
│  └─ BackButton (Button, text="← 返回选角")
```

**Step 2: 重写脚本 — 数据驱动**

```gdscript
# scripts/ui/map_select.gd
extends Control

@onready var _map_container: HBoxContainer = $VBoxContainer/MapContainer
@onready var _back_button: Button = $VBoxContainer/BackButton

func _ready() -> void:
	$Background.color = UIConstants.COLOR_BG_PRIMARY
	$VBoxContainer/TitleLabel.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TITLE)
	_back_button.pressed.connect(func(): SceneManager.go_to(Enums.Scene.CHARACTER_SELECTION))

	# 从 GameConfig.maps 动态生成地图卡片
	for child in _map_container.get_children():
		child.queue_free()

	for map_id in GameConfig.maps:
		var map_data: MapData = GameConfig.maps[map_id]
		_map_container.add_child(_create_map_card(map_id, map_data))

func _create_map_card(map_id: String, map_data: MapData) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 160)
	var style := UIConstants.create_panel_stylebox()
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# 预览色块
	var preview := ColorRect.new()
	preview.custom_minimum_size = Vector2(170, 80)
	preview.color = map_data.fallback_color
	vbox.add_child(preview)

	# 地图名称
	var name_label := Label.new()
	name_label.text = map_data.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SUBTITLE)
	vbox.add_child(name_label)

	# 选择按钮
	var button := Button.new()
	button.text = "选择"
	button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	button.pressed.connect(_on_map_selected.bind(map_id))
	vbox.add_child(button)

	# 悬停效果
	card.mouse_entered.connect(func():
		var tween := create_tween()
		tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.1))
	card.mouse_exited.connect(func():
		var tween := create_tween()
		tween.tween_property(card, "scale", Vector2.ONE, 0.1))

	return card

func _on_map_selected(map_id: String) -> void:
	if not GameConfig.maps.has(map_id):
		push_error("未知地图: " + map_id)
		return
	GameData.selected_map = map_id
	SceneManager.go_to(Enums.Scene.MAIN)
```

**Step 3: Run all tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add scenes/ui/map_select.tscn scripts/ui/map_select.gd
git commit -m "feat: 地图选择重做 — 数据驱动/预览色块/悬停动画/返回按钮"
```

---

### Task 11: 结算屏重做

**Files:**
- Rewrite: `scenes/ui/result.tscn`
- Rewrite: `scripts/ui/result.gd`

**Step 1: 重建场景结构**

```
Control (result, anchors=full rect)
├─ Background (ColorRect, color=rgba(0,0,0,0.85), anchors=full rect)
├─ CenterContainer (anchors=full rect)
│  └─ VBoxContainer (separation=16)
│     ├─ TitleLabel (Label, font_size=32, center)
│     ├─ WaveProgress (HBoxContainer)
│     │  ├─ WaveLabel (Label)
│     │  └─ WaveBar (ProgressBar, max_value=10, custom_minimum_size=200x16)
│     ├─ StatsPanel (PanelContainer)
│     │  └─ StatsGrid (GridContainer, columns=2)
│     │     (动态生成统计项)
│     ├─ ItemsPanel (PanelContainer)
│     │  └─ ItemsFlow (HFlowContainer)
│     │     (动态生成已购物品标签)
│     └─ ButtonRow (HBoxContainer, alignment=CENTER, separation=20)
│        ├─ RestartButton (Button, text="再来一局")
│        └─ MenuButton (Button, text="主菜单")
```

**Step 2: 重写脚本**

```gdscript
# scripts/ui/result.gd
extends Control

func _ready() -> void:
	$Background.color = Color(0, 0, 0, 0.85)
	var vbox := $CenterContainer/VBoxContainer
	var title := vbox.get_node("TitleLabel")
	var is_victory := GameData.current_wave > 10

	# 标题
	title.text = "胜利！" if is_victory else "失败"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color",
		UIConstants.COLOR_GOLD if is_victory else UIConstants.COLOR_ACCENT_DANGER)

	# 波次进度条
	var wave_label: Label = vbox.get_node("WaveProgress/WaveLabel")
	var wave_bar: ProgressBar = vbox.get_node("WaveProgress/WaveBar")
	wave_label.text = "存活波次: %d/10" % min(GameData.current_wave, 10)
	wave_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	wave_bar.max_value = 10
	wave_bar.value = min(GameData.current_wave, 10)

	# 统计面板
	var stats_grid: GridContainer = vbox.get_node("StatsPanel/StatsGrid")
	var stats_panel: PanelContainer = vbox.get_node("StatsPanel")
	stats_panel.add_theme_stylebox_override("panel", UIConstants.create_panel_stylebox())
	_add_stat_row(stats_grid, "击杀总数", str(GameData.total_kills))
	_add_stat_row(stats_grid, "获取金币", str(GameData.total_coins_earned))
	_add_stat_row(stats_grid, "购买物品", str(GameData.purchased_item_list.size()))
	_add_stat_row(stats_grid, "受到伤害", str(int(GameData.total_damage_taken)))
	_add_stat_row(stats_grid, "最高连杀", str(GameData.max_kill_streak))

	# 已购物品
	var items_panel: PanelContainer = vbox.get_node("ItemsPanel")
	var items_flow: HFlowContainer = vbox.get_node("ItemsPanel/ItemsFlow")
	items_panel.add_theme_stylebox_override("panel", UIConstants.create_panel_stylebox())
	if GameData.purchased_item_list.size() > 0:
		for item_id in GameData.purchased_item_list:
			var label := Label.new()
			if GameConfig.items.has(item_id):
				label.text = GameConfig.items[item_id].display_name
			else:
				label.text = item_id
			label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
			var pill := PanelContainer.new()
			var pill_style := UIConstants.create_panel_stylebox(Color(0.2, 0.2, 0.3, 0.8), 6)
			pill_style.content_margin_left = 8
			pill_style.content_margin_right = 8
			pill_style.content_margin_top = 4
			pill_style.content_margin_bottom = 4
			pill.add_theme_stylebox_override("panel", pill_style)
			pill.add_child(label)
			items_flow.add_child(pill)
	else:
		var label := Label.new()
		label.text = "无"
		label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
		items_flow.add_child(label)

	# 按钮
	var restart_btn: Button = vbox.get_node("ButtonRow/RestartButton")
	var menu_btn: Button = vbox.get_node("ButtonRow/MenuButton")
	restart_btn.pressed.connect(_on_restart)
	menu_btn.pressed.connect(_on_menu)
	restart_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	menu_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)

func _add_stat_row(grid: GridContainer, label_text: String, value_text: String) -> void:
	var name_l := Label.new()
	name_l.text = label_text
	name_l.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	name_l.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	grid.add_child(name_l)

	var value_l := Label.new()
	value_l.text = value_text
	value_l.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	value_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(value_l)

func _on_restart() -> void:
	GameData.reset()
	SceneManager.go_to(Enums.Scene.CHARACTER_SELECTION)

func _on_menu() -> void:
	GameData.reset()
	SceneManager.go_to(Enums.Scene.START_MENU)
```

**Step 3: Run all tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add scenes/ui/result.tscn scripts/ui/result.gd
git commit -m "feat: 结算屏重做 — 波次进度条/战绩统计/物品展示/再来一局"
```

---

### Task 12: 更新旧测试适配新 UI 结构

**Files:**
- Modify: `tests/unit/test_ui_scene_dimensions.gd` — 适配新场景节点路径
- Modify: `tests/unit/test_shop_manager_logic.gd` — 适配新 shop_manager UI 接口

**Step 1: 审查并修复 test_ui_scene_dimensions.gd**

检查测试中对旧 UI 节点路径的引用（如 `$VBoxContainer/StartButton`），更新为新路径（如 `$CenterContainer/VBoxContainer/StartButton`）。

**Step 2: 审查并修复 test_shop_manager_logic.gd**

商店测试可能直接引用了旧的 `item_containers` 或 `NameLabel` 等节点。检查测试是否只测试逻辑方法（`_pick_rarity`, `_calculate_price` 等）。如果是，不需要改动。如果测试了 UI 节点，需要适配新结构。

**Step 3: Run all tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: All 195+ tests PASS

**Step 4: Commit**

```bash
git add tests/
git commit -m "fix: 更新测试适配新 UI 结构"
```

---

### Task 13: 视觉验证和微调

**Step 1: 运行游戏，逐个检查每个界面**

用 gdai-mcp `play_scene` 或 Godot 编辑器逐一检查：
1. 开始菜单 — 背景色、按钮布局、悬停动画
2. 角色选择 — 卡片排列、属性着色、悬停说明
3. 地图选择 — 数据驱动、预览色块、返回按钮
4. HUD — HP 进度条颜色、金币显示、Buff 栏
5. 商店 — 2x2 卡片、属性面板、稀有度边框
6. 结算屏 — 统计数据、物品展示

**Step 2: 截图检查并微调**

用 `get_editor_screenshot` / `get_running_scene_screenshot` 逐一检查，调整：
- 间距和对齐
- 字号和颜色
- 按钮大小和位置

**Step 3: Commit**

```bash
git add -A
git commit -m "fix: UI 视觉微调"
```

---

### Task 14: 全量测试 + 最终提交

**Step 1: Run all tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: All tests PASS

**Step 2: 运行完整游戏流程测试**

手动走一遍完整流程：开始 → 选角 → 选图 → 战斗 → 商店 → 战斗 → 结算

**Step 3: Commit and summarize**

```bash
git add -A
git commit -m "feat: UI 全面重做完成 — 主题系统/HUD/商店/角色选择/结算屏"
```
