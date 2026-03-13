# XP/等级系统与升级弹窗重构 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 添加经验值/等级系统，将武器和塔的升级合并到波次结束弹窗中，简化布置阶段移除商店。

**Architecture:** 金币拾取同步触发 XP 累积（GameData.add_xp），升级次数存入 pending_upgrades。波次结束后 upgrade_popup 弹出 N 轮 3 选 1（武器+塔混合池），由新的 UpgradeGenerator 生成选项。布置阶段移除商店 Tab，只保留塔放置。

**Tech Stack:** Godot 4.6 / GDScript / GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-13-xp-level-upgrade-design.md`

---

## Chunk 1: 核心数据层（GameData + EventBus）

### Task 1: EventBus 新增 XP/等级信号

**Files:**
- Modify: `scripts/core/event_bus.gd:19-21`
- Test: `tests/unit/test_event_bus.gd`

- [ ] **Step 1: 在 EventBus 添加信号**

在 `scripts/core/event_bus.gd` 的经济事件区块（第 19-21 行）后添加：

```gdscript
# 等级系统
signal player_leveled_up(level: int)
signal xp_changed(current_xp: int, xp_to_next: int)
```

- [ ] **Step 2: 验证现有测试通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gprefix=test_event_bus -gexit`
Expected: 所有测试 PASS

- [ ] **Step 3: Commit**

```bash
git add scripts/core/event_bus.gd
git commit -m "feat: EventBus 新增 player_leveled_up/xp_changed 信号"
```

---

### Task 2: GameData 新增 XP/等级字段和方法

**Files:**
- Modify: `scripts/core/game_data.gd:22-29` (新增字段), `:49-69` (_DEFAULTS), `:88-111` (reset()), 末尾新增方法
- Test: `tests/unit/test_game_data_xp.gd` (新建)

- [ ] **Step 1: 编写 XP 系统测试**

创建 `tests/unit/test_game_data_xp.gd`：

```gdscript
extends GutTest

func before_each() -> void:
	GameData.reset()

func test_xp_fields_initialized() -> void:
	assert_eq(GameData.current_level, 1)
	assert_eq(GameData.current_xp, 0)
	assert_eq(GameData.pending_upgrades, 0)

func test_get_xp_to_next_level_formula() -> void:
	# 公式: 20 + (current_level - 1) * 15
	GameData.current_level = 1
	assert_eq(GameData.get_xp_to_next_level(), 20)
	GameData.current_level = 2
	assert_eq(GameData.get_xp_to_next_level(), 35)
	GameData.current_level = 5
	assert_eq(GameData.get_xp_to_next_level(), 80)

func test_add_xp_accumulates() -> void:
	GameData.add_xp(10)
	assert_eq(GameData.current_xp, 10)
	assert_eq(GameData.current_level, 1)
	assert_eq(GameData.pending_upgrades, 0)

func test_add_xp_triggers_level_up() -> void:
	GameData.add_xp(20)  # 正好升级 (1→2 需要 20)
	assert_eq(GameData.current_level, 2)
	assert_eq(GameData.current_xp, 0)
	assert_eq(GameData.pending_upgrades, 1)

func test_add_xp_multiple_levels() -> void:
	GameData.add_xp(60)  # 20(→Lv2) + 35(→Lv3) = 55，剩余 5
	assert_eq(GameData.current_level, 3)
	assert_eq(GameData.current_xp, 5)
	assert_eq(GameData.pending_upgrades, 2)

func test_add_xp_emits_signals() -> void:
	var level_ups: Array[int] = []
	var xp_changes: Array[Dictionary] = []
	EventBus.player_leveled_up.connect(func(level: int): level_ups.append(level))
	EventBus.xp_changed.connect(func(xp: int, to_next: int): xp_changes.append({"xp": xp, "to_next": to_next}))
	GameData.add_xp(25)  # 升到 Lv2，剩 5 XP
	assert_eq(level_ups, [2])
	assert_true(xp_changes.size() > 0)
	# 断开信号（清理）
	for conn in EventBus.player_leveled_up.get_connections():
		EventBus.player_leveled_up.disconnect(conn["callable"])
	for conn in EventBus.xp_changed.get_connections():
		EventBus.xp_changed.disconnect(conn["callable"])

func test_reset_clears_xp_fields() -> void:
	GameData.add_xp(50)
	GameData.reset()
	assert_eq(GameData.current_level, 1)
	assert_eq(GameData.current_xp, 0)
	assert_eq(GameData.pending_upgrades, 0)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gprefix=test_game_data_xp -gexit`
Expected: FAIL（字段/方法不存在）

- [ ] **Step 3: 实现 GameData XP 系统**

在 `scripts/core/game_data.gd` 中：

1. 在第 29 行 `owned_towers` 后添加字段：
```gdscript
## 经验值/等级系统
var current_level: int = 1
var current_xp: int = 0
var pending_upgrades: int = 0
```

2. 在 `_DEFAULTS` 字典（第 49-69 行）中追加：
```gdscript
"current_level": 1,
"current_xp": 0,
"pending_upgrades": 0,
```

3. 在文件末尾添加方法：
```gdscript
func get_xp_to_next_level() -> int:
	return 20 + (current_level - 1) * 15

func add_xp(amount: int) -> void:
	current_xp += amount
	while current_xp >= get_xp_to_next_level():
		current_xp -= get_xp_to_next_level()
		current_level += 1
		pending_upgrades += 1
		EventBus.player_leveled_up.emit(current_level)
	EventBus.xp_changed.emit(current_xp, get_xp_to_next_level())
```

注意：`reset()` 已通过 `_DEFAULTS` 字典自动处理新字段的重置。

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gprefix=test_game_data -gexit`
Expected: 所有 test_game_data_xp 和 test_game_data_stats 测试 PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/game_data.gd tests/unit/test_game_data_xp.gd
git commit -m "feat: GameData 新增 XP/等级系统 (add_xp, get_xp_to_next_level)"
```

---

### Task 3: Player 拾取金币触发 XP

**Files:**
- Modify: `scripts/entities/player.gd:113-115`

- [ ] **Step 1: 修改 add_coins 方法**

在 `scripts/entities/player.gd` 第 113-115 行，`add_coins` 方法中追加 `GameData.add_xp(amount)`：

```gdscript
func add_coins(amount: int) -> void:
	coins += amount
	GameData.coins = coins  # 同步到 GameData
	GameData.add_xp(amount)
```

- [ ] **Step 2: 运行全量测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试 PASS

- [ ] **Step 3: Commit**

```bash
git add scripts/entities/player.gd
git commit -m "feat: 金币拾取同步触发 XP 累积"
```

---

## Chunk 2: UpgradeGenerator 合并生成器

### Task 4: 创建 UpgradeGenerator

**Files:**
- Create: `scripts/systems/upgrade_generator.gd`
- Test: `tests/unit/test_upgrade_generator.gd` (新建)

- [ ] **Step 1: 编写测试**

创建 `tests/unit/test_upgrade_generator.gd`：

```gdscript
extends GutTest

var _original_owned_weapons: Dictionary
var _original_owned_towers: Dictionary
var _generator: UpgradeGenerator

func before_each():
	_original_owned_weapons = GameData.owned_weapons.duplicate()
	_original_owned_towers = GameData.owned_towers.duplicate()
	_generator = UpgradeGenerator.new()

func after_each():
	GameData.owned_weapons = _original_owned_weapons
	GameData.owned_towers = _original_owned_towers

func test_generates_mixed_options():
	GameData.owned_weapons = {"rifle": 1}
	GameData.owned_towers = {"shooter": 1}
	var options: Array[Dictionary] = _generator.generate_options()
	assert_gt(options.size(), 0, "应生成至少 1 个选项")
	assert_lte(options.size(), 3, "最多 3 个选项")
	# 每个选项必须有 type 字段
	for opt in options:
		assert_true(opt["type"] in ["weapon", "tower"], "type 应为 weapon 或 tower")
		assert_true(opt.has("id"), "应有 id 字段")
		assert_true(opt.has("target_level"), "应有 target_level 字段")
		assert_true(opt.has("is_new"), "应有 is_new 字段")
		assert_true(opt.has("current_level"), "应有 current_level 字段")

func test_new_item_has_level_1():
	GameData.owned_weapons = {"rifle": 5, "boomerang": 5, "laser": 5}
	GameData.owned_towers = {"shooter": 5, "wall": 5}
	# 只剩 slow 塔可以作为新的
	var options: Array[Dictionary] = _generator.generate_options()
	for opt in options:
		if opt["is_new"]:
			assert_eq(opt["target_level"], 1, "新物品应为 Lv1")
			assert_eq(opt["current_level"], 0, "新物品 current_level 应为 0")

func test_upgrade_has_next_level():
	GameData.owned_weapons = {"rifle": 2}
	GameData.owned_towers = {"shooter": 3}
	var options: Array[Dictionary] = _generator.generate_options()
	for opt in options:
		if opt["id"] == "rifle":
			assert_eq(opt["target_level"], 3)
			assert_eq(opt["current_level"], 2)
		if opt["id"] == "shooter":
			assert_eq(opt["target_level"], 4)
			assert_eq(opt["current_level"], 3)

func test_max_level_excluded():
	GameData.owned_weapons = {"rifle": 5, "boomerang": 5, "laser": 5}
	GameData.owned_towers = {"shooter": 5, "wall": 5, "slow": 5}
	var options: Array[Dictionary] = _generator.generate_options()
	assert_eq(options.size(), 0, "全部满级应返回空")

func test_no_duplicate_options():
	GameData.owned_weapons = {"rifle": 1}
	GameData.owned_towers = {"shooter": 1}
	var options: Array[Dictionary] = _generator.generate_options()
	var keys: Array[String] = []
	for opt in options:
		var key: String = opt["type"] + ":" + opt["id"]
		assert_false(key in keys, "不应有重复选项")
		keys.append(key)

func test_exclude_filters_options():
	GameData.owned_weapons = {"rifle": 1}
	GameData.owned_towers = {"shooter": 1}
	# 先生成一组
	var first: Array[Dictionary] = _generator.generate_options()
	if first.size() > 0:
		# 排除第一组，再生成
		var second: Array[Dictionary] = _generator.generate_options(first)
		for opt in second:
			var key: String = opt["type"] + ":" + opt["id"]
			for excluded in first:
				var ex_key: String = excluded["type"] + ":" + excluded["id"]
				assert_ne(key, ex_key, "排除的选项不应再出现")

func test_refresh_cost_formula():
	assert_eq(_generator.get_refresh_cost(0), 0, "首次刷新免费")
	assert_eq(_generator.get_refresh_cost(1), 5, "第二次刷新 5 金币")
	assert_eq(_generator.get_refresh_cost(2), 10, "第三次刷新 10 金币")
	assert_eq(_generator.get_refresh_cost(3), 15, "第四次刷新 15 金币")
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gprefix=test_upgrade_generator -gexit`
Expected: FAIL（UpgradeGenerator 类不存在）

- [ ] **Step 3: 实现 UpgradeGenerator**

创建 `scripts/systems/upgrade_generator.gd`：

```gdscript
class_name UpgradeGenerator
extends RefCounted

## 合并的武器+塔升级选项生成器
## 从武器和塔的池子中加权随机抽取 3 个选项

func generate_options(exclude: Array[Dictionary] = []) -> Array[Dictionary]:
	var pool: Array[Dictionary] = _build_pool(exclude)
	_apply_weights(pool)
	# 加权随机抽取（轮盘赌算法）
	var result: Array[Dictionary] = []
	for _i in mini(pool.size(), 3):
		if pool.is_empty():
			break
		var total_weight: float = 0.0
		for opt in pool:
			total_weight += opt["_weight"]
		var roll: float = randf() * total_weight
		var cumulative: float = 0.0
		var selected_idx: int = 0
		for j in pool.size():
			cumulative += pool[j]["_weight"]
			if roll <= cumulative:
				selected_idx = j
				break
		var selected: Dictionary = pool[selected_idx].duplicate()
		selected.erase("_weight")
		result.append(selected)
		pool.remove_at(selected_idx)
	return result

func get_refresh_cost(refresh_count: int) -> int:
	if refresh_count == 0:
		return 0
	return 5 * refresh_count

func _build_pool(exclude: Array[Dictionary]) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var exclude_keys: Array[String] = []
	for ex in exclude:
		exclude_keys.append(ex.get("type", "") + ":" + ex.get("id", ""))
	# 武器池
	for weapon_id: String in GameConfig.weapons:
		if ("weapon:" + weapon_id) in exclude_keys:
			continue
		var current_level: int = GameData.owned_weapons.get(weapon_id, 0)
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		if current_level == 0:
			pool.append({
				"type": "weapon", "id": weapon_id,
				"target_level": 1, "is_new": true, "current_level": 0,
				"_weight": 1.0
			})
		elif current_level < wd.max_level:
			pool.append({
				"type": "weapon", "id": weapon_id,
				"target_level": current_level + 1, "is_new": false,
				"current_level": current_level, "_weight": 1.0
			})
	# 塔池
	for tower_id: String in GameConfig.towers:
		if ("tower:" + tower_id) in exclude_keys:
			continue
		var current_level: int = GameData.owned_towers.get(tower_id, 0)
		var td: TowerData = GameConfig.towers[tower_id]
		if current_level == 0:
			pool.append({
				"type": "tower", "id": tower_id,
				"target_level": 1, "is_new": true, "current_level": 0,
				"_weight": 1.0
			})
		elif current_level < td.max_level:
			pool.append({
				"type": "tower", "id": tower_id,
				"target_level": current_level + 1, "is_new": false,
				"current_level": current_level, "_weight": 1.0
			})
	return pool

func _apply_weights(pool: Array[Dictionary]) -> void:
	var weapon_count: int = GameData.owned_weapons.size()
	var tower_count: int = GameData.owned_towers.size()
	for opt in pool:
		# 平衡加权：少的类型权重更高
		if opt["type"] == "tower" and tower_count < weapon_count:
			opt["_weight"] *= 1.5
		elif opt["type"] == "weapon" and weapon_count < tower_count:
			opt["_weight"] *= 1.5
		# 新物品加权
		if opt["is_new"]:
			opt["_weight"] *= 1.2
```

注意：需要在 `.godot/global_script_class_cache.cfg` 中注册 `UpgradeGenerator` class_name，否则 headless 测试无法识别。检查是否需要手动添加（若能打开 Godot 编辑器则自动注册）。

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gprefix=test_upgrade_generator -gexit`
Expected: 所有测试 PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/systems/upgrade_generator.gd tests/unit/test_upgrade_generator.gd
git commit -m "feat: 新建 UpgradeGenerator 合并武器+塔升级选项生成"
```

---

## Chunk 3: 升级弹窗重构

### Task 5: 重构 weapon_select_popup → upgrade_popup

**Files:**
- Rename: `scripts/ui/weapon_select_popup.gd` → `scripts/ui/upgrade_popup.gd`
- Rename: `scenes/ui/weapon_select_popup.tscn` → `scenes/ui/upgrade_popup.tscn`
- Modify: `scripts/ui/main.gd`（更新引用）

这是最大的改动任务。先重命名文件，再重写弹窗逻辑。

- [ ] **Step 1: 重命名文件**

```bash
git mv scripts/ui/weapon_select_popup.gd scripts/ui/upgrade_popup.gd
git mv scenes/ui/weapon_select_popup.tscn scenes/ui/upgrade_popup.tscn
# 同步移动 .uid 文件（Godot 4.6 使用 .uid 追踪资源）
if [ -f scripts/ui/weapon_select_popup.gd.uid ]; then git mv scripts/ui/weapon_select_popup.gd.uid scripts/ui/upgrade_popup.gd.uid; fi
if [ -f scenes/ui/weapon_select_popup.tscn.uid ]; then git mv scenes/ui/weapon_select_popup.tscn.uid scenes/ui/upgrade_popup.tscn.uid; fi
```

然后更新 `scenes/ui/upgrade_popup.tscn` 中的脚本引用路径（将 `weapon_select_popup.gd` 改为 `upgrade_popup.gd`）。

- [ ] **Step 2: 重写 upgrade_popup.gd**

用以下内容完全替换 `scripts/ui/upgrade_popup.gd`：

```gdscript
extends CanvasLayer
## 波次结束升级弹窗 — 多轮 3 选 1（武器+塔混合池）

signal upgrade_selected(type: String, id: String)
signal all_upgrades_completed
signal skipped

const CARD_WIDTH: int = 180
const CARD_HEIGHT: int = 200
const CARD_GAP: int = 16

var _total_rounds: int = 0
var _current_round: int = 0
var _refresh_count: int = 0
var _options: Array[Dictionary] = []
var _generator: UpgradeGenerator = UpgradeGenerator.new()

# UI 节点引用
var _title_label: Label
var _coins_label: Label
var _cards_container: HBoxContainer
var _refresh_button: Button
var _container: VBoxContainer

func show_upgrades(count: int) -> void:
	_total_rounds = count
	_current_round = 0
	if _total_rounds <= 0:
		skipped.emit()
		queue_free()
		return
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_ui()
	_start_round()

func _start_round() -> void:
	_refresh_count = 0
	_options = _generator.generate_options()
	if _options.size() == 0:
		_finish()
		return
	_update_display()

func _update_display() -> void:
	_title_label.text = "选择升级 (%d/%d)" % [_current_round + 1, _total_rounds]
	_coins_label.text = "金币: %d" % GameData.coins
	_rebuild_cards()
	_update_refresh_button()

func _rebuild_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()
	for i in _options.size():
		var card: PanelContainer = _create_card(i)
		_cards_container.add_child(card)

func _create_card(index: int) -> PanelContainer:
	var opt: Dictionary = _options[index]
	var is_weapon: bool = opt["type"] == "weapon"

	# 颜色配置
	var border_color: Color = Color("#4fc3f7") if is_weapon else Color("#66bb6a")
	var bg_color: Color = Color("#1a1a3a") if is_weapon else Color("#1a2a1a")
	var type_label_text: String = "⚔ 武器" if is_weapon else "🏗 塔"
	var type_label_color: Color = border_color

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# 类型标签
	var type_lbl := Label.new()
	type_lbl.text = type_label_text
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.add_theme_color_override("font_color", type_label_color)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_lbl)

	# 名称
	var name_lbl := Label.new()
	name_lbl.text = _get_display_name(opt)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# 等级信息
	var level_lbl := Label.new()
	if opt["is_new"]:
		var new_text: String = "新武器! Lv1" if is_weapon else "新塔! Lv1"
		level_lbl.text = new_text
		level_lbl.add_theme_color_override("font_color", Color("#4caf50"))
	else:
		level_lbl.text = "Lv%d → Lv%d" % [opt["current_level"], opt["target_level"]]
		level_lbl.add_theme_color_override("font_color", Color("#ffd700"))
	level_lbl.add_theme_font_size_override("font_size", 12)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_lbl)

	# 属性预览
	var stats_lbl := Label.new()
	stats_lbl.text = _get_stats_text(opt)
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_lbl)

	# 点击事件
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_option_selected(index)
	)

	return panel

func _get_display_name(opt: Dictionary) -> String:
	if opt["type"] == "weapon":
		var wd: WeaponData = GameConfig.weapons[opt["id"]]
		return wd.display_name
	else:
		var td: TowerData = GameConfig.towers[opt["id"]]
		return td.display_name

func _get_stats_text(opt: Dictionary) -> String:
	var level: int = opt["target_level"]
	var idx: int = level - 1
	if opt["type"] == "weapon":
		var wd: WeaponData = GameConfig.weapons[opt["id"]]
		var lines: Array[String] = []
		if wd.damage_per_level.size() > idx:
			lines.append("伤害: %d" % int(wd.damage_per_level[idx]))
		if wd.fire_rate_per_level.size() > idx:
			lines.append("射速: %.1f" % wd.fire_rate_per_level[idx])
		if wd.weapon_range_per_level.size() > idx:
			lines.append("范围: %d" % int(wd.weapon_range_per_level[idx]))
		return "\n".join(lines)
	else:
		var td: TowerData = GameConfig.towers[opt["id"]]
		var lines: Array[String] = []
		if td.damage_per_level.size() > idx and td.damage_per_level[idx] > 0:
			lines.append("伤害: %d" % int(td.damage_per_level[idx]))
		if td.fire_rate_per_level.size() > idx and td.fire_rate_per_level[idx] > 0:
			lines.append("射速: %.1f" % td.fire_rate_per_level[idx])
		if td.attack_range_per_level.size() > idx and td.attack_range_per_level[idx] > 0:
			lines.append("范围: %d" % int(td.attack_range_per_level[idx]))
		if td.slow_ratio_per_level.size() > idx and td.slow_ratio_per_level[idx] > 0:
			lines.append("减速: %d%%" % int(td.slow_ratio_per_level[idx] * 100))
		if td.hp_per_level.size() > idx and td.hp_per_level[idx] > 0:
			lines.append("HP: %d" % int(td.hp_per_level[idx]))
		return "\n".join(lines)

func _on_option_selected(index: int) -> void:
	var opt: Dictionary = _options[index]
	if opt["type"] == "weapon":
		GameData.upgrade_weapon(opt["id"])
	elif opt["type"] == "tower":
		GameData.upgrade_tower(opt["id"])
	upgrade_selected.emit(opt["type"], opt["id"])
	GameData.pending_upgrades -= 1
	_current_round += 1
	if _current_round < _total_rounds:
		_start_round()
	else:
		_finish()

func _on_refresh_pressed() -> void:
	var cost: int = _generator.get_refresh_cost(_refresh_count)
	if cost > 0 and GameData.coins < cost:
		return
	if cost > 0:
		GameData.coins -= cost
	_refresh_count += 1
	_options = _generator.generate_options(_options)
	if _options.size() == 0:
		_finish()
		return
	_update_display()

func _finish() -> void:
	get_tree().paused = false
	all_upgrades_completed.emit()
	queue_free()

func _update_refresh_button() -> void:
	var cost: int = _generator.get_refresh_cost(_refresh_count)
	if cost == 0:
		_refresh_button.text = "🔄 刷新 (免费)"
		_refresh_button.disabled = false
	else:
		_refresh_button.text = "🔄 刷新 (%d金币)" % cost
		_refresh_button.disabled = GameData.coins < cost

func _build_ui() -> void:
	# 半透明遮罩
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# 主容器
	_container = VBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_CENTER)
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_theme_constant_override("separation", 12)
	overlay.add_child(_container)

	# 让 VBoxContainer 居中
	_container.set_anchors_preset(Control.PRESET_CENTER)
	_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_container.grow_vertical = Control.GROW_DIRECTION_BOTH

	# 标题
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(_title_label)

	# 金币显示
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 14)
	_coins_label.add_theme_color_override("font_color", Color("#ffd700"))
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(_coins_label)

	# 卡片容器
	_cards_container = HBoxContainer.new()
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_container.add_theme_constant_override("separation", CARD_GAP)
	_container.add_child(_cards_container)

	# 刷新按钮
	_refresh_button = Button.new()
	_refresh_button.add_theme_font_size_override("font_size", 14)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_child(_refresh_button)
	_container.add_child(btn_container)
```

- [ ] **Step 3: 更新 main.gd（精确编辑，不全量替换）**

在 `scripts/ui/main.gd` 中进行以下修改：

1. 第 3 行：更新 preload 路径和变量名
```gdscript
# 旧:
var _weapon_popup_scene: PackedScene = preload("res://scenes/ui/weapon_select_popup.tscn")
# 新:
var _upgrade_popup_scene: PackedScene = preload("res://scenes/ui/upgrade_popup.tscn")
```

2. 第 39-41 行：更新 `_on_wave_transition_ready`
```gdscript
func _on_wave_transition_ready() -> void:
	await get_tree().process_frame
	_show_upgrade_popup()
```

3. 第 43-54 行：替换 `_show_weapon_select` 及后续方法
```gdscript
func _show_upgrade_popup() -> void:
	var count: int = GameData.pending_upgrades
	if count <= 0:
		SceneManager.go_to(Enums.Scene.PLACEMENT)
		return
	var popup: CanvasLayer = _upgrade_popup_scene.instantiate()
	add_child(popup)
	popup.all_upgrades_completed.connect(_on_upgrades_completed)
	popup.skipped.connect(_on_upgrades_skipped)
	popup.show_upgrades(count)

func _on_upgrades_completed() -> void:
	SceneManager.go_to(Enums.Scene.PLACEMENT)

func _on_upgrades_skipped() -> void:
	SceneManager.go_to(Enums.Scene.PLACEMENT)
```

- [ ] **Step 4: 更新 upgrade_popup.tscn 的脚本路径**

读取 `scenes/ui/upgrade_popup.tscn`，将其中 `weapon_select_popup.gd` 的路径更新为 `upgrade_popup.gd`。

- [ ] **Step 5: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试 PASS（旧的 weapon_select_popup 相关测试可能需要调整引用）

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/upgrade_popup.gd scenes/ui/upgrade_popup.tscn scripts/ui/main.gd
git commit -m "feat: 重构武器选择弹窗为统一升级弹窗 (upgrade_popup)"
```

---

## Chunk 4: 布置阶段简化

### Task 6: 简化 placement 移除商店

**Files:**
- Modify: `scripts/ui/placement.gd` — 移除 Tab 切换逻辑
- Modify: `scenes/levels/placement.tscn` — 移除商店 UI 节点
- Modify: `scripts/ui/placement_panel.gd` — 移除 EventBus 信号监听
- Delete: `scripts/ui/shop_panel.gd`

- [ ] **Step 1: 修改 placement.gd**

从 `scripts/ui/placement.gd` 中：
1. 移除 `_placement_tab`、`_shop_tab`、`_shop_content`、`_placement_content` 的 `@onready` 引用（如果有的话）
2. 移除 `_switch_tab()` 方法
3. 移除 `_ready()` 中的 Tab 按钮信号连接和首波特殊处理（`current_wave == 0` 隐藏商店）
4. 移除 shop_panel 的初始化代码

具体改动取决于实际代码行数，需要仔细读取 placement.gd 后精确编辑。

- [ ] **Step 2: 修改 placement.tscn**

从 `scenes/levels/placement.tscn` 中移除以下节点：
- `TabBar`（及其子节点 `PlacementTab`、`ShopTab`）
- `ShopContent`（及其子节点 `ShopScroll`、`ShopItemList`、`RefreshButton`）

保留：`CoinsLabel`、`PlacementContent`（含 `PlacementScroll` → `TowerList`）、`StartBattleButton`

- [ ] **Step 3: 修改 placement_panel.gd**

在 `scripts/ui/placement_panel.gd` 的 `initialize()` 方法中：
1. 移除 `EventBus.tower_purchased.connect(...)` 连接（约第 22 行）
2. 移除 `EventBus.tower_upgraded.connect(...)` 连接（约第 23 行）
3. 移除 `_on_tower_purchased()` 和 `_on_tower_upgraded()` 回调方法

- [ ] **Step 4: 删除 shop_panel.gd**

```bash
git rm scripts/ui/shop_panel.gd
```

- [ ] **Step 5: 更新测试**

- 删除或更新 `tests/unit/test_tower_shop_panel.gd`（测试的是已删除的 shop_panel）
- 确认 `tests/unit/test_placement_panel.gd` 不依赖商店逻辑

```bash
git rm tests/unit/test_tower_shop_panel.gd
```

- [ ] **Step 6: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试 PASS

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/placement.gd scenes/levels/placement.tscn scripts/ui/placement_panel.gd
git add tests/
git commit -m "refactor: 简化布置阶段，移除商店 Tab 和 shop_panel"
```

---

## Chunk 5: HUD 经验条 + 清理

### Task 7: HUD 新增经验条和等级显示

**Files:**
- Modify: `scripts/ui/hud.gd`
- Modify: `scenes/ui/hud.tscn` — 添加经验条 UI 节点

- [ ] **Step 1: 在 hud.tscn 中添加经验条节点**

在 HUD 场景的 `TopBar/MarginContainer/HBoxContainer/HPBar` 下方添加经验条相关节点。具体结构：

```
HPBar/
  HPIcon
  HPProgress
  HPText
XPBar/  ← 新增
  XPIcon (Label, "Lv.1")
  XPProgress (ProgressBar)
```

使用 gdai-mcp 的节点操作工具或手动编辑 .tscn 文件。

- [ ] **Step 2: 修改 hud.gd**

在 `scripts/ui/hud.gd` 中添加：

1. 新增 `@onready` 引用（在第 17 行后）：
```gdscript
@onready var xp_progress: ProgressBar = $TopBar/MarginContainer/HBoxContainer/XPBar/XPProgress
@onready var xp_icon: Label = $TopBar/MarginContainer/HBoxContainer/XPBar/XPIcon
```

2. 在 `_ready()` 中连接信号（在第 30 行后）：
```gdscript
EventBus.xp_changed.connect(_on_xp_changed)
EventBus.player_leveled_up.connect(_on_player_leveled_up)
```

3. 在 `_style_ui()` 中添加经验条样式：
```gdscript
xp_icon.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
xp_icon.add_theme_color_override("font_color", Color("#bb86fc"))
xp_icon.text = "Lv.%d" % GameData.current_level
```

4. 新增回调方法：
```gdscript
func _on_xp_changed(current_xp: int, xp_to_next: int) -> void:
	xp_progress.max_value = xp_to_next
	xp_progress.value = current_xp

func _on_player_leveled_up(level: int) -> void:
	xp_icon.text = "Lv.%d" % level
	# 经验条闪白
	var tween: Tween = create_tween()
	tween.tween_property(xp_progress, "modulate", Color.WHITE * 2, 0.15)
	tween.tween_property(xp_progress, "modulate", Color.WHITE, 0.15)
	# 浮动文字（spawn_damage_number 只接受 float，需自行创建 Label）
	if player and is_instance_valid(player):
		_spawn_level_up_text(player.global_position + Vector2(0, -30))

func _spawn_level_up_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "Level Up!"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#bb86fc"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = pos
	label.z_index = 100
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(label)
	else:
		add_child(label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", pos.y - 30, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.4)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)
```

- [ ] **Step 3: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试 PASS

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/hud.gd scenes/ui/hud.tscn
git commit -m "feat: HUD 新增经验条和等级显示"
```

---

### Task 8: 删除旧生成器文件

**Files:**
- Delete: `scripts/systems/weapon_upgrade_generator.gd`
- Delete: `scripts/systems/tower_shop_generator.gd`
- Delete: `tests/unit/test_weapon_upgrade_generator.gd`
- Delete: `tests/unit/test_tower_shop_generator.gd`

- [ ] **Step 1: 确认无其他引用**

搜索项目中对旧文件的引用：
```bash
grep -r "WeaponUpgradeGenerator\|TowerShopGenerator\|weapon_upgrade_generator\|tower_shop_generator" scripts/ scenes/ tests/ --include="*.gd" --include="*.tscn"
```
Expected: 无结果（或仅在待删除文件中）

- [ ] **Step 2: 删除文件**

```bash
git rm scripts/systems/weapon_upgrade_generator.gd
git rm scripts/systems/tower_shop_generator.gd
git rm tests/unit/test_weapon_upgrade_generator.gd
git rm tests/unit/test_tower_shop_generator.gd
# 清理对应 .uid 文件
git rm -f scripts/systems/weapon_upgrade_generator.gd.uid 2>/dev/null || true
git rm -f scripts/systems/tower_shop_generator.gd.uid 2>/dev/null || true
```

- [ ] **Step 3: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试 PASS

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: 删除旧的 WeaponUpgradeGenerator/TowerShopGenerator 及其测试"
```

---

### Task 9: 最终验证

- [ ] **Step 1: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试 PASS，无 FAIL

- [ ] **Step 2: 在 Godot 编辑器中运行游戏手动验证**

验证要点：
1. 战斗中拾取金币 → HUD 经验条增长
2. 升级时 → "Level Up!" 浮动文字 + 经验条闪白
3. 波次结束 → 弹窗显示正确轮数（与本波升级次数一致）
4. 弹窗中武器蓝色边框、塔绿色边框
5. 刷新按钮：首次免费，之后收费
6. 选完后进入布置阶段 → 无商店 Tab，只有塔放置
7. 本波没升级 → 跳过弹窗直接进布置

- [ ] **Step 3: 更新 CLAUDE.md**

更新 `CLAUDE.md` 中的架构描述：
- 游戏流程部分：更新波次结束流程（upgrade_popup 替代 weapon_select_popup）
- 系统脚本部分：添加 UpgradeGenerator，移除 WeaponUpgradeGenerator/TowerShopGenerator
- 代码组织：更新文件列表

- [ ] **Step 4: Final commit**

```bash
git add CLAUDE.md
git commit -m "docs: 更新 CLAUDE.md 适配 XP/等级系统和升级弹窗重构"
```
