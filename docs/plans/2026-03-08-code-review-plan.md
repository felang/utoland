# Code Review 全面优化 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 三轮 code review — 架构重构、无用代码清理、代码质量优化

**Architecture:** 拆分 shop_manager.gd 为三个模块（流程控制/物品生成/效果应用），消除 game_data.gd 初始化重复，删除废弃文件，全面扫描代码质量

**Tech Stack:** GDScript (Godot 4.6), GUT 测试框架

---

## 第一轮：架构重构

### Task 1: 提取 shop_item_generator.gd

**Files:**
- Create: `scripts/systems/shop_item_generator.gd`
- Modify: `scripts/systems/shop_manager.gd`
- Test: `tests/unit/test_shop_manager_logic.gd` (现有测试必须继续通过)

**Step 1: 创建 shop_item_generator.gd**

从 shop_manager.gd 提取以下方法和常量到新文件：

```gdscript
class_name ShopItemGenerator
extends RefCounted

# 稀有度概率表（按波次）
const RARITY_TABLE: Array = [
	{"from": 1,  "weights": {"common": 100, "rare": 0,  "epic": 0}},
	{"from": 4,  "weights": {"common": 70,  "rare": 30, "epic": 0}},
	{"from": 7,  "weights": {"common": 40,  "rare": 50, "epic": 10}},
	{"from": 10, "weights": {"common": 20,  "rare": 50, "epic": 30}},
]
# 塔相关 effect_type 黑名单（幸存者模式下过滤）
const TOWER_EFFECT_TYPES: Array = [
	Enums.ItemEffect.TOWER_STAT,
	Enums.ItemEffect.TOWER_LINK,
	Enums.ItemEffect.WAVE_HEAL_TOWERS,
	Enums.ItemEffect.TOWER_REGEN,
	Enums.ItemEffect.SYMBIOSIS,
	Enums.ItemEffect.WAR_MACHINE,
]

func get_rarity_weights(wave: int) -> Dictionary:
	var result: Dictionary = {}
	for entry in RARITY_TABLE:
		if wave >= entry["from"]:
			result = entry["weights"]
	return result

func pick_rarity(wave: int) -> String:
	var weights := get_rarity_weights(wave)
	var total: int = 0
	for w in weights.values():
		total += w
	if total == 0:
		return Enums.ItemRarity.COMMON
	var roll := randi_range(0, total - 1)
	var cumulative := 0
	for rarity in weights:
		cumulative += weights[rarity]
		if roll < cumulative:
			return rarity
	return Enums.ItemRarity.COMMON

func calculate_price(item: ShopItemData, affinity_tags: PackedStringArray, affinity_discount: float) -> int:
	var base := randi_range(item.cost_min, item.cost_max)
	for tag in item.tags:
		if tag in affinity_tags:
			return max(1, int(base * (1.0 - affinity_discount)))
	return base

func can_buy(item: ShopItemData) -> bool:
	if item.max_stack == -1:
		return true
	var bought: int = GameData.purchased_items.get(item.id, 0)
	return bought < item.max_stack

func generate_items(wave: int, affinity_tags: PackedStringArray, affinity_discount: float,
		locked_slots: Array[bool], current_items: Array[ShopItemData],
		current_prices: Array[int]) -> Dictionary:
	# 按稀有度分类物品池
	var by_rarity: Dictionary = {
		Enums.ItemRarity.COMMON: [],
		Enums.ItemRarity.RARE: [],
		Enums.ItemRarity.EPIC: [],
	}
	for item in GameConfig.items.values():
		if item.effect_type in TOWER_EFFECT_TYPES:
			continue
		if by_rarity.has(item.rarity):
			by_rarity[item.rarity].append(item)

	var destiny_bought: bool = GameData.purchased_items.get("destiny", 0) > 0
	var items: Array[ShopItemData] = current_items.duplicate()
	var prices: Array[int] = current_prices.duplicate()

	for i in range(4):
		if locked_slots[i] and i < items.size():
			continue
		var rarity := pick_rarity(wave)
		var pool: Array = by_rarity[rarity].filter(func(it: ShopItemData) -> bool:
			if it.id == "destiny" and destiny_bought:
				return false
			return can_buy(it)
		)
		var weighted_pool: Array = []
		for item in pool:
			weighted_pool.append(item)
			for tag in item.tags:
				if tag in affinity_tags:
					weighted_pool.append(item)
					break
		if weighted_pool.is_empty():
			weighted_pool = by_rarity[Enums.ItemRarity.COMMON]
		if weighted_pool.is_empty():
			continue

		var picked: ShopItemData = weighted_pool.pick_random()
		if i < items.size():
			items[i] = picked
			prices[i] = calculate_price(picked, affinity_tags, affinity_discount)
		else:
			items.append(picked)
			prices.append(calculate_price(picked, affinity_tags, affinity_discount))

	return {"items": items, "prices": prices}
```

**Step 2: 创建 shop_effect_applier.gd**

从 shop_manager.gd 提取效果应用逻辑：

```gdscript
class_name ShopEffectApplier
extends RefCounted

func apply_effect(item: ShopItemData) -> void:
	var p := item.effect_params
	match item.effect_type:
		Enums.ItemEffect.STAT_BOOST:
			_apply_stat_boost(p)
		Enums.ItemEffect.TOWER_STAT:
			_apply_tower_stat(p)
		Enums.ItemEffect.CONSUMABLE:
			if p.get("effect") == "heal":
				GameData.pending_heal += p["value"]
		Enums.ItemEffect.PIERCE:
			GameData.pierce_count += p.get("pierce_count", 1)
		Enums.ItemEffect.MULTISHOT:
			GameData.multishot_active = true
			GameData.multishot_damage_mult = p.get("damage_mult", 1.0)
		Enums.ItemEffect.LIFESTEAL:
			GameData.lifesteal_ratio += p.get("ratio", 0.05)
		Enums.ItemEffect.KILL_STACK:
			GameData.kill_stack_max = max(GameData.kill_stack_max, p.get("max_stacks", 3))
			GameData.kill_stack_damage_per_stack += p.get("damage_per_stack", 0.2)
		Enums.ItemEffect.TOWER_LINK:
			GameData.tower_link_damage_per_tower += p.get("damage_per_tower", 0.04)
		Enums.ItemEffect.WAVE_GOLD:
			GameData.wave_gold_bonus += p.get("gold", 15)
		Enums.ItemEffect.WAVE_HEAL_TOWERS:
			GameData.wave_tower_heal_ratio += p.get("ratio", 0.20)
		Enums.ItemEffect.TOWER_REGEN:
			GameData.tower_regen_active = true
			GameData.tower_regen_hp += p.get("hp_per_interval", 5)
			GameData.tower_regen_interval = p.get("interval", 5.0)
		Enums.ItemEffect.SYMBIOSIS:
			GameData.symbiosis_hp_threshold = max(GameData.symbiosis_hp_threshold, p.get("hp_threshold", 0.30))
			GameData.symbiosis_tower_bonus += p.get("tower_damage_bonus", 0.60)
		Enums.ItemEffect.WAR_MACHINE:
			GameData.player_stats[Enums.Stat.DAMAGE_MULT] += p.get("damage_mult", 0.20)
			GameData.player_stats[Enums.Stat.TOWER_MULT] += p.get("tower_mult", 0.20)
			GameData.war_machine_active = true
			GameData.war_machine_wave_hp_cost += p.get("wave_hp_cost", 8)
		Enums.ItemEffect.BULLET_SPEED:
			GameData.bullet_speed_mult += p.get("mult", 0.2)
		Enums.ItemEffect.WEAPON_RANGE:
			GameData.weapon_range_mult += p.get("mult", 0.15)
		Enums.ItemEffect.CRIT:
			GameData.crit_chance += p.get("chance", 0.10)
		Enums.ItemEffect.SPLIT:
			GameData.split_count += p.get("count", 2)
			GameData.split_damage_mult = p.get("damage_mult", 0.5)
		Enums.ItemEffect.WAVE_SHIELD:
			GameData.wave_shield_count += p.get("count", 1)
		Enums.ItemEffect.WAVE_HEAL_PLAYER:
			GameData.wave_heal_ratio += p.get("ratio", 0.10)
		Enums.ItemEffect.DAMAGE_REDUCTION:
			GameData.damage_reduction += p.get("ratio", 0.10)
		Enums.ItemEffect.DODGE:
			GameData.dodge_chance += p.get("chance", 0.15)
		Enums.ItemEffect.MAGNET:
			GameData.coin_magnet_mult += p.get("mult", 0.50)
		Enums.ItemEffect.SLOW_AURA:
			GameData.slow_aura_active = true
			GameData.slow_aura_ratio += p.get("ratio", 0.15)
			GameData.slow_aura_range = max(GameData.slow_aura_range, p.get("range", 100.0))
		Enums.ItemEffect.AUTO_DASH:
			GameData.auto_dash_active = true
			GameData.auto_dash_interval = min(GameData.auto_dash_interval, p.get("interval", 10.0))
			GameData.auto_dash_distance = max(GameData.auto_dash_distance, p.get("distance", 80.0))
		Enums.ItemEffect.DESTINY:
			pass

func _apply_stat_boost(p: Dictionary) -> void:
	if p.has("stat"):
		GameData.player_stats[p["stat"]] += p["value"]
	elif p.has("stats"):
		for entry in p["stats"]:
			GameData.player_stats[entry["stat"]] += entry["value"]

func _apply_tower_stat(p: Dictionary) -> void:
	if p.has("stat"):
		_set_tower_stat(p["stat"], p["value"])
	elif p.has("stats"):
		for entry in p["stats"]:
			_set_tower_stat(entry["stat"], entry["value"])

func _set_tower_stat(stat: String, value: float) -> void:
	match stat:
		"tower_hp_mult":
			GameData.tower_hp_mult += value
		"tower_range_mult":
			GameData.tower_range_mult += value
		"tower_attack_speed_mult":
			GameData.tower_attack_speed_mult += value
		"tower_cost_mult":
			GameData.tower_cost_mult += value
		"tower_mult":
			GameData.player_stats[Enums.Stat.TOWER_MULT] += value
		"hp_mult":
			GameData.player_stats[Enums.Stat.HP_MULT] += value
```

**Step 3: 重写 shop_manager.gd 使用新模块**

shop_manager.gd 精简为流程控制 + UI：

```gdscript
extends Control

const REFRESH_COSTS: Array = [0, 5, 5, 5, 5, 8, 8, 8, 8, 12, 12]
const SHOP_CARD_SCENE = preload("res://scenes/ui/shop_item_card.tscn")

var shop_items: Array[ShopItemData] = []
var shop_prices: Array[int] = []
var locked_slots: Array[bool] = [false, false, false, false]

var _generator := ShopItemGenerator.new()
var _effect_applier := ShopEffectApplier.new()
var _card_nodes: Array = []

@onready var coin_label: Label = $MainPanel/VBoxContainer/HeaderRow/CoinLabel
@onready var wave_label: Label = $MainPanel/VBoxContainer/HeaderRow/WaveLabel
@onready var title_label: Label = $MainPanel/VBoxContainer/HeaderRow/TitleLabel
@onready var card_grid: GridContainer = $MainPanel/VBoxContainer/CardGrid
@onready var stats_grid: GridContainer = $MainPanel/VBoxContainer/StatsPanel/StatsGrid
@onready var stats_panel: PanelContainer = $MainPanel/VBoxContainer/StatsPanel
@onready var refresh_button: Button = $MainPanel/VBoxContainer/ButtonRow/RefreshButton
@onready var confirm_button: Button = $MainPanel/VBoxContainer/ButtonRow/ConfirmButton

func _ready() -> void:
	if not card_grid:
		return
	refresh_button.pressed.connect(_on_refresh_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	_generate_shop()
	_create_card_nodes()
	_update_ui()
	_style_ui()

# ===== 商店逻辑 =====

func _generate_shop() -> void:
	var wave := GameData.current_wave + 1
	var affinity_tags := _get_affinity_tags()
	var affinity_discount := _get_affinity_discount()
	var result := _generator.generate_items(wave, affinity_tags, affinity_discount,
		locked_slots, shop_items, shop_prices)
	shop_items = result["items"]
	shop_prices = result["prices"]

func _buy_item(index: int) -> void:
	if index >= shop_items.size():
		return
	var item: ShopItemData = shop_items[index]
	var price: int = shop_prices[index]
	if GameData.coins < price:
		return
	if not _generator.can_buy(item):
		return
	GameData.coins -= price
	GameData.purchased_items[item.id] = GameData.purchased_items.get(item.id, 0) + 1
	GameData.record_item_purchased(item.id)
	_effect_applier.apply_effect(item)
	_update_ui()

func _get_refresh_cost() -> int:
	var wave := GameData.current_wave + 1
	if wave >= REFRESH_COSTS.size():
		return REFRESH_COSTS[-1]
	return REFRESH_COSTS[wave]

func _get_affinity_tags() -> PackedStringArray:
	var char_id := GameData.current_character
	if not GameConfig.characters.has(char_id):
		return PackedStringArray()
	return GameConfig.characters[char_id].affinity_tags

func _get_affinity_discount() -> float:
	var char_id := GameData.current_character
	if not GameConfig.characters.has(char_id):
		return 0.0
	return GameConfig.characters[char_id].affinity_discount

# ===== UI =====

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

func _update_ui() -> void:
	if not coin_label:
		return
	coin_label.text = "金币: %d" % GameData.coins
	wave_label.text = "Wave %d/10" % (GameData.current_wave + 1)
	var refresh_cost := _get_refresh_cost()
	refresh_button.disabled = GameData.coins < refresh_cost
	refresh_button.text = "刷新 (%d)" % refresh_cost
	_display_items()
	_update_stats_panel()

func _display_items() -> void:
	for i in range(min(shop_items.size(), _card_nodes.size())):
		var item := shop_items[i]
		var price := shop_prices[i]
		var card = _card_nodes[i]
		card.setup(i, item, price, locked_slots[i],
			GameData.coins >= price, _generator.can_buy(item))

func _update_stats_panel() -> void:
	for child in stats_grid.get_children():
		child.queue_free()
	var stats: Array[String] = [
		"HP %d" % int(GameData.player_stats[Enums.Stat.MAX_HP] * GameData.player_stats[Enums.Stat.HP_MULT]),
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
	$Background.color = UIConstants.COLOR_BG_PRIMARY
	title_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SUBTITLE)
	title_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
	coin_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SUBTITLE)
	coin_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	wave_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	wave_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	stats_panel.add_theme_stylebox_override("panel", UIConstants.create_panel_stylebox())
	confirm_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	refresh_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)

func _on_refresh_pressed() -> void:
	var cost := _get_refresh_cost()
	if GameData.coins < cost:
		return
	GameData.coins -= cost
	_generate_shop()
	_update_ui()

func _on_confirm_pressed() -> void:
	SceneManager.go_to(Enums.Scene.MAIN)
```

**Step 4: 更新测试，适配新结构**

测试文件 `test_shop_manager_logic.gd` 需要更新：原来测试 `manager._get_rarity_weights()` 等方法现在移到了 `ShopItemGenerator`。

- 方法名从 `_get_rarity_weights` → `get_rarity_weights`（去掉下划线前缀，变为公共方法）
- 方法名从 `_pick_rarity` → `pick_rarity`
- 方法名从 `_calculate_price` → `calculate_price`（新增 affinity_tags, affinity_discount 参数）
- 方法名从 `_can_buy` → `can_buy`
- 测试 `before_each` 中创建 `ShopItemGenerator.new()` 替代 `shop_manager.gd` script-only 实例

```gdscript
extends GutTest

var generator: ShopItemGenerator

func before_each():
	generator = ShopItemGenerator.new()

func test_rarity_weights_early_waves():
	var weights: Dictionary = generator.get_rarity_weights(2)
	assert_eq(weights["common"], 100)
	assert_eq(weights.get("rare", 0), 0)
	assert_eq(weights.get("epic", 0), 0)

func test_rarity_weights_mid_waves():
	var weights: Dictionary = generator.get_rarity_weights(5)
	assert_gt(weights.get("rare", 0), 0)
	assert_eq(weights.get("epic", 0), 0)

func test_rarity_weights_final_wave():
	var weights: Dictionary = generator.get_rarity_weights(10)
	assert_gt(weights.get("epic", 0), 0)

func test_affinity_discount_applied():
	GameData.current_character = "warrior"
	var item: ShopItemData = GameConfig.items["sharp_bullet"]
	var char_data: CharacterData = GameConfig.characters["warrior"]
	var price: int = generator.calculate_price(item, char_data.affinity_tags, char_data.affinity_discount)
	assert_lt(price, item.cost_max)

func test_no_discount_for_non_affinity():
	GameData.current_character = "warrior"
	var item: ShopItemData = GameConfig.items["engineer_manual"]
	var char_data: CharacterData = GameConfig.characters["warrior"]
	var price: int = generator.calculate_price(item, char_data.affinity_tags, char_data.affinity_discount)
	assert_gte(price, item.cost_min)
	assert_lte(price, item.cost_max)

func test_can_buy_unlimited_item():
	GameData.purchased_items = {}
	var item: ShopItemData = GameConfig.items["medkit"]
	assert_true(generator.can_buy(item))
	GameData.purchased_items["medkit"] = 99
	assert_true(generator.can_buy(item))

func test_cannot_buy_maxed_item():
	GameData.purchased_items = {"sharp_bullet": 3}
	var item: ShopItemData = GameConfig.items["sharp_bullet"]
	assert_false(generator.can_buy(item))
```

**Step 5: 更新 global_script_class_cache.cfg**

新增 `ShopItemGenerator` 和 `ShopEffectApplier` 两个 class_name，需在 `.godot/global_script_class_cache.cfg` 中补充条目，否则 headless 测试无法识别。

**Step 6: 运行全部测试验证**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 195 tests passing

**Step 7: Commit**

```bash
git add scripts/systems/shop_item_generator.gd scripts/systems/shop_effect_applier.gd scripts/systems/shop_manager.gd tests/unit/test_shop_manager_logic.gd .godot/global_script_class_cache.cfg
git commit -m "refactor: 拆分 shop_manager 为三模块 — generator/effect_applier/manager"
```

---

### Task 2: 消除 game_data.gd 初始化重复

**Files:**
- Modify: `scripts/core/game_data.gd`
- Test: `tests/unit/test_game_data_stats.gd` (现有测试必须继续通过)

**Step 1: 定义默认值常量字典**

在 game_data.gd 顶部定义一个 `_DEFAULTS` 常量字典，包含所有需要 reset 的字段默认值。注意：`player_stats`、`selected_weapon`、`selected_map` 的 reset 值依赖角色数据，需在 reset() 中动态计算，不放入 _DEFAULTS。

```gdscript
# 所有可 reset 字段的默认值（不含依赖角色数据的字段）
const _DEFAULTS: Dictionary = {
	"coins_key": "initial_coins",  # 特殊：从 GameConfig.PLAYER 读取
	"current_wave": 0,
	"tower_inventory": [],
	"purchased_towers": [],
	"pending_heal": 0,
	"purchased_items": {},
	"wave_gold_bonus": 0,
	"pierce_count": 0,
	"multishot_active": false,
	"multishot_damage_mult": 1.0,
	"lifesteal_ratio": 0.0,
	"kill_stack_count": 0,
	"kill_stack_max": 0,
	"kill_stack_damage_per_stack": 0.0,
	"tower_link_damage_per_tower": 0.0,
	"wave_tower_heal_ratio": 0.0,
	"tower_regen_active": false,
	"tower_regen_hp": 0.0,
	"tower_regen_interval": 5.0,
	"symbiosis_hp_threshold": 0.0,
	"symbiosis_tower_bonus": 0.0,
	"war_machine_active": false,
	"war_machine_wave_hp_cost": 0,
	"tower_hp_mult": 1.0,
	"tower_range_mult": 1.0,
	"tower_attack_speed_mult": 1.0,
	"tower_cost_mult": 1.0,
	"bullet_speed_mult": 1.0,
	"weapon_range_mult": 1.0,
	"crit_chance": 0.0,
	"crit_damage_mult": 2.0,
	"split_count": 0,
	"split_damage_mult": 0.5,
	"wave_shield_count": 0,
	"current_shield": 0,
	"wave_heal_ratio": 0.0,
	"damage_reduction": 0.0,
	"dodge_chance": 0.0,
	"coin_magnet_mult": 1.0,
	"slow_aura_active": false,
	"slow_aura_ratio": 0.0,
	"slow_aura_range": 100.0,
	"auto_dash_active": false,
	"auto_dash_interval": 10.0,
	"auto_dash_distance": 80.0,
	"total_kills": 0,
	"total_coins_earned": 0,
	"total_damage_taken": 0.0,
	"max_kill_streak": 0,
	"current_kill_streak": 0,
}
```

**Step 2: 重写 reset() 使用 _DEFAULTS**

```gdscript
func reset() -> void:
	init_character(current_character)
	var char_data: CharacterData = GameConfig.characters[current_character]
	selected_weapon = char_data.default_weapon
	selected_map = Enums.Map.FOREST
	player_stats = {
		Enums.Stat.MAX_HP: character_max_hp,
		Enums.Stat.HP_MULT: 1.0,
		Enums.Stat.HP_REGEN: character_hp_regen,
		Enums.Stat.DAMAGE_MULT: character_damage_mult,
		Enums.Stat.ATTACK_SPEED_MULT: character_attack_speed_mult,
		Enums.Stat.MOVE_SPEED_MULT: character_move_speed_mult,
		Enums.Stat.TOWER_MULT: 1.0
	}
	coins = GameConfig.PLAYER["initial_coins"]
	for key in _DEFAULTS:
		var val = _DEFAULTS[key]
		# Array 和 Dictionary 需要 duplicate 避免引用共享
		if val is Array or val is Dictionary:
			set(key, val.duplicate())
		else:
			set(key, val)
	purchased_item_list = []
```

**Step 3: 运行测试验证**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 195 tests passing

**Step 4: Commit**

```bash
git add scripts/core/game_data.gd
git commit -m "refactor: game_data.gd 用 _DEFAULTS 常量消除 reset() 重复"
```

---

## 第二轮：清理删除

### Task 3: 删除 scenes/backup/ 废弃文件

**Files:**
- Delete: `scenes/backup/` (6 files)

**Step 1: 确认无引用**

搜索 `scenes/backup` 引用，确保无代码依赖。

**Step 2: 删除目录**

```bash
rm -rf scenes/backup/
```

**Step 3: Commit**

```bash
git add -A scenes/backup/
git commit -m "chore: 删除 scenes/backup/ 废弃场景文件"
```

### Task 4: 扫描并清理死代码

**Files:**
- Scan: 所有 `scripts/` 下 .gd 文件（跳过 placement 相关）

**Step 1: 扫描未使用的函数、变量、信号**

使用 Grep 搜索每个公共函数/信号的引用次数。重点关注：
- 只在声明处出现一次的公共函数
- 只在声明处出现的信号
- 未使用的 preload/load 语句

**Step 2: 消除 _get_affinity_tags() 重复**

`_get_affinity_tags()` 在 `shop_manager.gd:73` 和 `shop_item_card.gd:63` 中重复。
- 保留 `shop_manager.gd` 中的版本（shop_item_card.gd 也需要，但可以保持各自独立的简单实现，因为它们在不同上下文运行且逻辑只有 3 行）
- 或者：如果发现其他地方也有类似查询，考虑提取到 GameData 中作为辅助方法

**Step 3: 清理发现的死代码并 commit**

```bash
git commit -m "chore: 清理未使用的代码和重复引用"
```

---

## 第三轮：广度扫描

### Task 5: 类型标注补全

**Files:**
- Scan+Modify: 所有 `scripts/` 下 .gd 文件

**Step 1: 扫描缺少返回类型标注的函数**

搜索 `func ` 但不含 ` -> ` 的行（排除 `_ready`, `_process`, `_physics_process` 等生命周期方法，这些返回 void 可以省略但最好补上）。

**Step 2: 补充类型标注**

逐文件补充函数参数和返回值类型标注。

**Step 3: 运行测试验证**

**Step 4: Commit**

```bash
git commit -m "refactor: 补充函数类型标注"
```

### Task 6: 魔法数字提取 + 代码风格扫描

**Step 1: 扫描硬编码数字**

搜索脚本中直接使用的数字字面量（排除 0, 1, -1, 2 等常见值），判断是否应提取为常量。

**Step 2: 检查脚本内成员顺序**

按规范：信号 → 常量 → @export → @onready → 变量 → 生命周期 → 公共方法 → 私有方法。检查是否有违反。

**Step 3: 修复发现的问题并 commit**

```bash
git commit -m "refactor: 提取魔法数字为常量，修正脚本成员顺序"
```

### Task 7: 最终验证

**Step 1: 运行全部测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: All 195 tests passing

**Step 2: 确认无回归**

检查 git diff 总览，确认所有修改合理。
