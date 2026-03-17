# GameData 拆分实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 GameData 拆分为 4 个独立 Autoload（PlayerState、PlayerProgression、InventoryManager、StatsTracker），删除未使用的里程碑字段，一步到位更新所有引用。

**Architecture:** 从 GameData 中按职责提取 4 个 Autoload 单例。PlayerState 管理角色身份/属性/被动，PlayerProgression 管理经验/等级/人口上限，InventoryManager 管理金币/装备/商店/合成，StatsTracker 管理战斗统计。InventoryManager 依赖 PlayerState（角色数据）和 PlayerProgression（人口上限）。

**Tech Stack:** Godot 4.6 / GDScript / GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-17-gamedata-split-design.md`

**测试命令:** `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

---

## Chunk 1: 创建 4 个新 Autoload + 注册

### Task 1: 创建 StatsTracker

**Files:**
- Create: `scripts/core/stats_tracker.gd`
- Test: `tests/unit/test_stats_tracker.gd`

- [ ] **Step 1: 写 StatsTracker 脚本**

```gdscript
extends Node

var total_kills: int = 0
var total_coins_earned: int = 0
var total_damage_taken: float = 0.0
var max_kill_streak: int = 0
var current_kill_streak: int = 0

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

func reset() -> void:
	total_kills = 0
	total_coins_earned = 0
	total_damage_taken = 0.0
	max_kill_streak = 0
	current_kill_streak = 0
```

- [ ] **Step 2: 写 StatsTracker 测试**

创建 `tests/unit/test_stats_tracker.gd`：

```gdscript
extends GutTest

func before_each() -> void:
	StatsTracker.reset()

func test_record_kill_increments_total() -> void:
	StatsTracker.record_kill()
	StatsTracker.record_kill()
	assert_eq(StatsTracker.total_kills, 2)

func test_record_kill_tracks_streak() -> void:
	StatsTracker.record_kill()
	StatsTracker.record_kill()
	StatsTracker.record_kill()
	assert_eq(StatsTracker.current_kill_streak, 3)
	assert_eq(StatsTracker.max_kill_streak, 3)

func test_reset_kill_streak() -> void:
	StatsTracker.record_kill()
	StatsTracker.record_kill()
	StatsTracker.reset_kill_streak()
	assert_eq(StatsTracker.current_kill_streak, 0)
	assert_eq(StatsTracker.max_kill_streak, 2)

func test_record_damage_taken() -> void:
	StatsTracker.record_damage_taken(25.5)
	StatsTracker.record_damage_taken(10.0)
	assert_almost_eq(StatsTracker.total_damage_taken, 35.5, 0.01)

func test_record_coins_earned() -> void:
	StatsTracker.record_coins_earned(50)
	StatsTracker.record_coins_earned(30)
	assert_eq(StatsTracker.total_coins_earned, 80)

func test_reset_clears_all() -> void:
	StatsTracker.record_kill()
	StatsTracker.record_coins_earned(100)
	StatsTracker.record_damage_taken(50.0)
	StatsTracker.reset()
	assert_eq(StatsTracker.total_kills, 0)
	assert_eq(StatsTracker.total_coins_earned, 0)
	assert_almost_eq(StatsTracker.total_damage_taken, 0.0, 0.01)
	assert_eq(StatsTracker.max_kill_streak, 0)
	assert_eq(StatsTracker.current_kill_streak, 0)
```

- [ ] **Step 3: Commit**

```
git add scripts/core/stats_tracker.gd tests/unit/test_stats_tracker.gd
git commit -m "feat: 创建 StatsTracker Autoload"
```

### Task 2: 创建 PlayerState

**Files:**
- Create: `scripts/core/player_state.gd`
- Test: `tests/unit/test_player_state.gd`

- [ ] **Step 1: 写 PlayerState 脚本**

从 `game_data.gd` 的角色系统部分提取。`init_character()` 和 `reset()` 逻辑直接搬过来。

```gdscript
extends Node

# 角色身份
var current_character: String = Enums.Character.DORA
var selected_map: String = Enums.Map.FOREST
var current_wave: int = 0
var pending_heal: int = 0

# 角色属性（从 CharacterData 初始化）
var character_max_hp: float = 0.0
var character_speed: float = 0.0
var character_damage_mult: float = 1.0
var character_attack_speed_mult: float = 1.0

# 被动系统
var new_passive_id: String = ""
var new_passive_value: float = 0.0
var new_passive_value_2: float = 0.0

# 运行时属性集
var player_stats: Dictionary = {
	Enums.Stat.MAX_HP: 100.0,
	Enums.Stat.HP_MULT: 1.0,
	Enums.Stat.DAMAGE_MULT: 1.0,
	Enums.Stat.ATTACK_SPEED_MULT: 1.0,
	Enums.Stat.TOWER_MULT: 1.0
}

func _ready() -> void:
	init_character(current_character)

func init_character(character_id: String) -> void:
	if not GameConfig.characters.has(character_id):
		push_error("未知角色: " + character_id)
		character_id = Enums.Character.DORA
	current_character = character_id
	var char_data: CharacterData = GameConfig.characters[character_id]
	character_max_hp = char_data.max_hp
	character_speed = char_data.speed
	character_damage_mult = char_data.damage_mult
	character_attack_speed_mult = char_data.attack_speed_mult
	new_passive_id = char_data.new_passive_id
	new_passive_value = char_data.new_passive_value
	new_passive_value_2 = char_data.new_passive_value_2

func reset() -> void:
	init_character(current_character)
	selected_map = Enums.Map.FOREST
	current_wave = 0
	pending_heal = 0
	player_stats = {
		Enums.Stat.MAX_HP: character_max_hp,
		Enums.Stat.HP_MULT: 1.0,
		Enums.Stat.DAMAGE_MULT: character_damage_mult,
		Enums.Stat.ATTACK_SPEED_MULT: character_attack_speed_mult,
		Enums.Stat.TOWER_MULT: 1.0
	}
```

- [ ] **Step 2: 写 PlayerState 测试**

创建 `tests/unit/test_player_state.gd`：

```gdscript
extends GutTest

func before_each() -> void:
	PlayerState.current_character = Enums.Character.DORA
	PlayerState.reset()

func test_init_character_sets_attributes() -> void:
	var char_data: CharacterData = GameConfig.characters[Enums.Character.DORA]
	assert_eq(PlayerState.character_max_hp, char_data.max_hp)
	assert_eq(PlayerState.character_speed, char_data.speed)
	assert_eq(PlayerState.character_damage_mult, char_data.damage_mult)

func test_init_character_sets_passives() -> void:
	PlayerState.init_character("kaze")
	assert_eq(PlayerState.new_passive_id, "swift_combo")

func test_reset_restores_defaults() -> void:
	PlayerState.current_wave = 5
	PlayerState.pending_heal = 10
	PlayerState.selected_map = "desert"
	PlayerState.reset()
	assert_eq(PlayerState.current_wave, 0)
	assert_eq(PlayerState.pending_heal, 0)
	assert_eq(PlayerState.selected_map, Enums.Map.FOREST)

func test_reset_rebuilds_player_stats() -> void:
	PlayerState.player_stats[Enums.Stat.DAMAGE_MULT] = 99.0
	PlayerState.reset()
	assert_eq(PlayerState.player_stats[Enums.Stat.DAMAGE_MULT], PlayerState.character_damage_mult)

func test_init_unknown_character_falls_back() -> void:
	PlayerState.init_character("nonexistent")
	assert_eq(PlayerState.current_character, Enums.Character.DORA)
```

- [ ] **Step 3: Commit**

```
git add scripts/core/player_state.gd tests/unit/test_player_state.gd
git commit -m "feat: 创建 PlayerState Autoload"
```

### Task 3: 创建 PlayerProgression

**Files:**
- Create: `scripts/core/player_progression.gd`
- Test: `tests/unit/test_player_progression.gd`

- [ ] **Step 1: 写 PlayerProgression 脚本**

从 `game_data.gd` 的经验系统部分提取。

```gdscript
extends Node

var player_level: int = 1
var current_exp: int = 0
var total_exp_earned: int = 0

func exp_for_level(level: int) -> int:
	var config: ExpConfig = GameConfig.exp_config
	return int(floor(config.base_exp * pow(level, config.exp_exponent)))

func add_exp(amount: int) -> void:
	current_exp += amount
	total_exp_earned += amount
	while current_exp >= exp_for_level(player_level + 1):
		player_level += 1
		EventBus.player_level_changed.emit(player_level)
	var next_threshold: int = exp_for_level(player_level + 1)
	EventBus.exp_changed.emit(current_exp, next_threshold)

func get_population_cap() -> int:
	var config: ExpConfig = GameConfig.exp_config
	return config.initial_population + (player_level - 1) * config.population_per_level

func reset() -> void:
	player_level = 1
	current_exp = 0
	total_exp_earned = 0
```

- [ ] **Step 2: 写 PlayerProgression 测试**

创建 `tests/unit/test_player_progression.gd`：

```gdscript
extends GutTest

func before_each() -> void:
	PlayerProgression.reset()

func test_initial_state() -> void:
	assert_eq(PlayerProgression.player_level, 1)
	assert_eq(PlayerProgression.current_exp, 0)
	assert_eq(PlayerProgression.total_exp_earned, 0)

func test_exp_for_level_formula() -> void:
	var config: ExpConfig = GameConfig.exp_config
	var expected: int = int(floor(config.base_exp * pow(2, config.exp_exponent)))
	assert_eq(PlayerProgression.exp_for_level(2), expected)

func test_add_exp_accumulates() -> void:
	PlayerProgression.add_exp(3)
	assert_eq(PlayerProgression.current_exp, 3)
	assert_eq(PlayerProgression.total_exp_earned, 3)

func test_add_exp_triggers_level_up() -> void:
	var threshold: int = PlayerProgression.exp_for_level(2)
	PlayerProgression.add_exp(threshold)
	assert_eq(PlayerProgression.player_level, 2)

func test_population_cap_at_level_1() -> void:
	var config: ExpConfig = GameConfig.exp_config
	assert_eq(PlayerProgression.get_population_cap(), config.initial_population)

func test_population_cap_increases_with_level() -> void:
	var config: ExpConfig = GameConfig.exp_config
	PlayerProgression.player_level = 3
	var expected: int = config.initial_population + 2 * config.population_per_level
	assert_eq(PlayerProgression.get_population_cap(), expected)

func test_reset_clears_all() -> void:
	PlayerProgression.add_exp(100)
	PlayerProgression.player_level = 5
	PlayerProgression.reset()
	assert_eq(PlayerProgression.player_level, 1)
	assert_eq(PlayerProgression.current_exp, 0)
	assert_eq(PlayerProgression.total_exp_earned, 0)
```

- [ ] **Step 3: Commit**

```
git add scripts/core/player_progression.gd tests/unit/test_player_progression.gd
git commit -m "feat: 创建 PlayerProgression Autoload"
```

### Task 4: 创建 InventoryManager

**Files:**
- Create: `scripts/core/inventory_manager.gd`
- Test: existing tests will be migrated in Chunk 2

- [ ] **Step 1: 写 InventoryManager 脚本**

从 `game_data.gd` 的经济/部署/合成部分提取。`can_deploy()` 调用 `PlayerProgression.get_population_cap()`；`reset()` 读 `PlayerState.current_character`。

```gdscript
extends Node

var coins: int = GameConfig.PLAYER["initial_coins"]
var deployed_weapons: Array[Dictionary] = []
var deployed_towers: Array[Dictionary] = []
var shop_slots: Array[Dictionary] = []
var is_first_shop_visit: bool = true
var _recommended_weapon: String = ""
var _recommended_tower: String = ""
var _next_deploy_id: int = 1

func get_population_used() -> int:
	return deployed_weapons.size() + deployed_towers.size()

func can_deploy() -> bool:
	return get_population_used() < PlayerProgression.get_population_cap()

func can_buy_item(item_id: String, item_level: int) -> bool:
	if can_deploy():
		return true
	var count: int = 0
	for w in deployed_weapons:
		if w.id == item_id and w.level == item_level:
			count += 1
	for t in deployed_towers:
		if t.id == item_id and t.level == item_level:
			count += 1
	return count >= 2

func buy_and_equip_weapon(weapon_id: String, cost: int) -> bool:
	if not can_buy_item(weapon_id, 1):
		return false
	if coins < cost:
		return false
	coins -= cost
	deployed_weapons.append({id = weapon_id, level = 1})
	var item := {id = weapon_id, type = "weapon", level = 1}
	EventBus.item_purchased.emit(item)
	EventBus.coins_changed.emit(-cost, coins)
	_check_merge(weapon_id, 1)
	return true

func buy_and_place_tower(tower_id: String, cost: int, grid_pos: Vector2i) -> int:
	if not can_buy_item(tower_id, 1):
		return 0
	if coins < cost:
		return 0
	coins -= cost
	var deploy_id: int = _next_deploy_id
	_next_deploy_id += 1
	deployed_towers.append({id = tower_id, level = 1, grid_pos = grid_pos, deploy_id = deploy_id})
	var item := {id = tower_id, type = "tower", level = 1}
	EventBus.item_purchased.emit(item)
	EventBus.coins_changed.emit(-cost, coins)
	_check_merge(tower_id, 1)
	return deploy_id

func move_tower(deploy_id: int, new_grid_pos: Vector2i) -> bool:
	if new_grid_pos.x < 0 or new_grid_pos.x >= GameConfig.MAP_GRID_WIDTH:
		return false
	if new_grid_pos.y < 0 or new_grid_pos.y >= GameConfig.MAP_GRID_HEIGHT:
		return false
	var tower_index := -1
	for i in range(deployed_towers.size()):
		if deployed_towers[i].deploy_id == deploy_id:
			tower_index = i
			break
	if tower_index == -1:
		return false
	for i in range(deployed_towers.size()):
		if i != tower_index and deployed_towers[i].grid_pos == new_grid_pos:
			return false
	var old_pos: Vector2i = deployed_towers[tower_index].grid_pos
	deployed_towers[tower_index].grid_pos = new_grid_pos
	EventBus.tower_moved.emit(deploy_id, old_pos, new_grid_pos)
	return true

func sell_from_deployed_weapon(deploy_index: int) -> int:
	if deploy_index < 0 or deploy_index >= deployed_weapons.size():
		return 0
	var entry: Dictionary = deployed_weapons[deploy_index]
	deployed_weapons.remove_at(deploy_index)
	var item := {id = entry.id, type = "weapon", level = entry.level}
	return _apply_sell(item)

func sell_from_deployed_tower(deploy_id: int) -> int:
	var tower_index := -1
	for i in range(deployed_towers.size()):
		if deployed_towers[i].deploy_id == deploy_id:
			tower_index = i
			break
	if tower_index == -1:
		return 0
	var entry: Dictionary = deployed_towers[tower_index]
	deployed_towers.remove_at(tower_index)
	var item := {id = entry.id, type = "tower", level = entry.level}
	return _apply_sell(item)

func _apply_sell(item: Dictionary) -> int:
	var data: Resource
	if item.type == "weapon":
		data = GameConfig.weapons[item.id]
	else:
		data = GameConfig.towers[item.id]
	var refund: int = data.sell_price_per_level[item.level - 1]
	coins += refund
	EventBus.item_sold.emit(item, refund)
	EventBus.coins_changed.emit(refund, coins)
	return refund

func _check_merge(item_id: String, item_level: int) -> void:
	if item_level >= 3:
		return
	var all_items: Array[Dictionary] = _collect_items_by_id_level(item_id, item_level)
	if all_items.size() < 3:
		return
	var consumed: int = 0
	var item_type: String = ""
	var kept_tower_pos: Vector2i = Vector2i.ZERO
	var kept_tower_deploy_id: int = 0
	var i: int = deployed_weapons.size() - 1
	while i >= 0 and consumed < 3:
		if deployed_weapons[i].id == item_id and deployed_weapons[i].level == item_level:
			item_type = "weapon"
			deployed_weapons.remove_at(i)
			consumed += 1
		i -= 1
	i = deployed_towers.size() - 1
	while i >= 0 and consumed < 3:
		if deployed_towers[i].id == item_id and deployed_towers[i].level == item_level:
			item_type = "tower"
			if kept_tower_deploy_id == 0:
				kept_tower_pos = deployed_towers[i].grid_pos
				kept_tower_deploy_id = deployed_towers[i].deploy_id
			deployed_towers.remove_at(i)
			consumed += 1
		i -= 1
	var new_level: int = item_level + 1
	if item_type == "weapon":
		deployed_weapons.append({id = item_id, level = new_level})
	elif item_type == "tower":
		deployed_towers.append({id = item_id, level = new_level, grid_pos = kept_tower_pos, deploy_id = kept_tower_deploy_id})
	EventBus.item_merged.emit(item_id, new_level)
	_check_merge(item_id, new_level)

func _collect_items_by_id_level(item_id: String, item_level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in deployed_weapons:
		if item.id == item_id and item.level == item_level:
			result.append(item)
	for item in deployed_towers:
		if item.id == item_id and item.level == item_level:
			result.append(item)
	return result

func reset() -> void:
	# 必须在 PlayerState.reset() 之后调用
	var char_data: CharacterData = GameConfig.characters[PlayerState.current_character]
	coins = GameConfig.PLAYER["initial_coins"] + char_data.starting_gold
	assert(coins >= 6, "初始金币必须 >= 6")
	deployed_weapons = []
	deployed_towers = []
	shop_slots = []
	is_first_shop_visit = true
	_recommended_weapon = char_data.recommended_weapon
	_recommended_tower = char_data.recommended_tower
	_next_deploy_id = 1
	if char_data.starting_weapon != "":
		deployed_weapons.append({id = char_data.starting_weapon, level = 1})
```

- [ ] **Step 2: Commit**

```
git add scripts/core/inventory_manager.gd
git commit -m "feat: 创建 InventoryManager Autoload"
```

### Task 5: 注册新 Autoload（保留 GameData 共存）

**Files:**
- Modify: `project.godot:18-26`

> **重要**：此步骤只新增 4 个 Autoload，**暂时保留 GameData**。因为 ~30 个文件仍引用 GameData，移除后项目将无法编译。GameData 的移除推迟到 Task 16（所有引用迁移完成后）。

- [ ] **Step 1: 修改 project.godot autoload 段**

将 `[autoload]` 段改为（GameData 保留，新增 4 个）：

```ini
[autoload]

GameConfig="*res://scripts/core/game_config.gd"
GameData="*res://scripts/core/game_data.gd"
PlayerState="*res://scripts/core/player_state.gd"
PlayerProgression="*res://scripts/core/player_progression.gd"
InventoryManager="*res://scripts/core/inventory_manager.gd"
StatsTracker="*res://scripts/core/stats_tracker.gd"
SceneFactory="*res://scripts/core/scene_factory.gd"
EffectsManager="*res://scripts/systems/effects_manager.gd"
EventBus="*res://scripts/core/event_bus.gd"
SceneManager="*res://scripts/core/scene_manager.gd"
GDAIMCPRuntime="*uid://dcne7ryelpxmn"
AudioManager="*res://scripts/systems/audio_manager.gd"
```

- [ ] **Step 2: Commit**

```
git add project.godot
git commit -m "chore: 注册新 Autoload（保留 GameData 共存）"
```

---

## Chunk 2: 迁移生产代码引用（~16 个文件）

### Task 6: 迁移 player.gd

**Files:**
- Modify: `scripts/entities/player.gd`

- [ ] **Step 1: 替换所有 GameData 引用**

逐行替换映射（不改逻辑，仅替换前缀）：

| 行 | 旧 | 新 |
|----|----|----|
| 21 | `GameData.player_stats` (×2) | `PlayerState.player_stats` |
| 23 | `GameData.character_speed` | `PlayerState.character_speed` |
| 26-28 | `GameData.pending_heal` (×3) | `PlayerState.pending_heal` |
| 31 | `GameData.deployed_weapons` | `InventoryManager.deployed_weapons` |
| 34 | `GameData.coins` | `InventoryManager.coins` |
| 41 | `GameData.current_character` | `PlayerState.current_character` |
| 99 | `GameData.record_damage_taken` | `StatsTracker.record_damage_taken` |
| 106 | `GameData.reset_kill_streak` | `StatsTracker.reset_kill_streak` |
| 113 | `GameData.coins = coins` | `InventoryManager.coins = coins` |
| 116 | `GameData.add_exp` | `PlayerProgression.add_exp` |
| 151,159,163,166,172,174,178,192,196 | `GameData.new_passive_id/value/value_2` | `PlayerState.new_passive_id/value/value_2` |

- [ ] **Step 2: Commit**

```
git add scripts/entities/player.gd
git commit -m "refactor: player.gd 迁移到新 Autoload"
```

### Task 7: 迁移 weapon_manager.gd + 删除里程碑代码

**Files:**
- Modify: `scripts/entities/weapons/weapon_manager.gd`

- [ ] **Step 1: 替换引用 + 删除分裂弹代码**

替换：
| 行 | 旧 | 新 |
|----|----|----|
| 72 | `GameData.deployed_weapons` | `InventoryManager.deployed_weapons` |
| 133 | `GameData.player_stats` | `PlayerState.player_stats` |
| 134 | `GameData.player_stats` | `PlayerState.player_stats` |

删除分裂弹相关代码（行 143-163）：
- 删除 `_on_weapon_projectile_created` 方法体内的全部逻辑（保留空方法或直接删除方法）
- 删除 `_on_projectile_hit_for_split` 方法
- 删除行 103 中对 `projectile_created` 信号的连接：`weapon.projectile_created.connect(_on_weapon_projectile_created)`
- 在 `_add_weapon` 中删除行 102 注释和行 103 连接

也可以保留 `projectile_created` 信号连接但删除方法体中对 `GameData.split_count` 和 `GameData.split_damage_mult` 的引用。最简方案是删除整个分裂系统：
- 删除行 102-103（注释 + connect）
- 删除行 143-163（`_on_weapon_projectile_created` 和 `_on_projectile_hit_for_split` 两个方法）

- [ ] **Step 2: Commit**

```
git add scripts/entities/weapons/weapon_manager.gd
git commit -m "refactor: weapon_manager 迁移 + 删除分裂弹系统"
```

### Task 8: 迁移 weapon.gd + shuriken_weapon.gd（删除 pierce_count）

**Files:**
- Modify: `scripts/entities/weapons/weapon.gd:51`
- Modify: `scripts/entities/weapons/shuriken_weapon.gd:12`

- [ ] **Step 1: weapon.gd 行 51**

将：
```gdscript
var extra_pierce: int = GameData.pierce_count
```
改为：
```gdscript
var extra_pierce: int = 0
```

- [ ] **Step 2: shuriken_weapon.gd 行 12**

将：
```gdscript
var extra_pierce: int = GameData.pierce_count
```
改为：
```gdscript
var extra_pierce: int = 0
```

- [ ] **Step 3: Commit**

```
git add scripts/entities/weapons/weapon.gd scripts/entities/weapons/shuriken_weapon.gd
git commit -m "refactor: 移除 pierce_count 里程碑引用"
```

### Task 9: 迁移 main.gd

**Files:**
- Modify: `scripts/ui/main.gd`

- [ ] **Step 1: 替换引用**

| 行 | 旧 | 新 |
|----|----|----|
| 93 | `GameData.coins += reward` | `InventoryManager.coins += reward` |
| 94 | `GameData.record_coins_earned(reward)` | `StatsTracker.record_coins_earned(reward)` |
| 95 | `GameData.coins` | `InventoryManager.coins` |
| 99 | `GameData.coins` | `InventoryManager.coins` |
| 162 | `GameData.selected_map` | `PlayerState.selected_map` |
| 164 | `GameData.selected_map` | `PlayerState.selected_map` |
| 178 | `GameData.coins += amount` | `InventoryManager.coins += amount` |

- [ ] **Step 2: Commit**

```
git add scripts/ui/main.gd
git commit -m "refactor: main.gd 迁移到新 Autoload"
```

### Task 10: 迁移 result.gd

**Files:**
- Modify: `scripts/ui/result.gd`

- [ ] **Step 1: 替换引用**

| 行 | 旧 | 新 |
|----|----|----|
| 7 | `GameData.current_wave` | `PlayerState.current_wave` |
| 18 | `GameData.current_wave` | `PlayerState.current_wave` |
| 22 | `GameData.current_wave` | `PlayerState.current_wave` |
| 28 | `GameData.total_kills` | `StatsTracker.total_kills` |
| 29 | `GameData.total_coins_earned` | `StatsTracker.total_coins_earned` |
| 30 | `GameData.total_exp_earned` | `PlayerProgression.total_exp_earned` |
| 31 | `GameData.deployed_weapons` | `InventoryManager.deployed_weapons` |
| 32 | `GameData.deployed_towers` | `InventoryManager.deployed_towers` |
| 33 | `GameData.total_damage_taken` | `StatsTracker.total_damage_taken` |
| 34 | `GameData.max_kill_streak` | `StatsTracker.max_kill_streak` |
| 43 | `GameData.deployed_weapons` | `InventoryManager.deployed_weapons` |
| 45 | `GameData.deployed_towers` | `InventoryManager.deployed_towers` |
| 108,113 | `GameData.reset()` | 4 行 reset 调用 |

行 108 和 113 的 `GameData.reset()` 替换为：
```gdscript
PlayerState.reset()
PlayerProgression.reset()
InventoryManager.reset()
StatsTracker.reset()
```

- [ ] **Step 2: Commit**

```
git add scripts/ui/result.gd
git commit -m "refactor: result.gd 迁移到新 Autoload"
```

### Task 11: 迁移 character_selection.gd

**Files:**
- Modify: `scripts/ui/character_selection.gd:253-254`

- [ ] **Step 1: 替换引用**

行 253-254：
```gdscript
GameData.current_character = _selected_id
GameData.reset()
```
改为：
```gdscript
PlayerState.current_character = _selected_id
PlayerState.reset()
PlayerProgression.reset()
InventoryManager.reset()
StatsTracker.reset()
```

- [ ] **Step 2: Commit**

```
git add scripts/ui/character_selection.gd
git commit -m "refactor: character_selection.gd 迁移到新 Autoload"
```

### Task 12: 迁移剩余 UI 文件（hud, shop_overlay, map_select, debug_panel）

**Files:**
- Modify: `scripts/ui/hud.gd`
- Modify: `scripts/ui/shop_overlay.gd`
- Modify: `scripts/ui/map_select.gd`
- Modify: `scripts/ui/debug_panel.gd`

- [ ] **Step 1: hud.gd**

| 行 | 旧 | 新 |
|----|----|----|
| 109 | `GameData.exp_for_level(GameData.player_level + 1)` | `PlayerProgression.exp_for_level(PlayerProgression.player_level + 1)` |
| 111 | `GameData.current_exp` | `PlayerProgression.current_exp` |
| 112 | `GameData.player_level` | `PlayerProgression.player_level` |
| 132 | `GameData.player_level` | `PlayerProgression.player_level` |
| 159 | `GameData.current_wave` | `PlayerState.current_wave` |

- [ ] **Step 2: shop_overlay.gd**

所有 `GameData.coins` → `InventoryManager.coins`
所有 `GameData.deployed_weapons` → `InventoryManager.deployed_weapons`
所有 `GameData.deployed_towers` → `InventoryManager.deployed_towers`
所有 `GameData.shop_slots` → `InventoryManager.shop_slots`
所有 `GameData.can_buy_item` → `InventoryManager.can_buy_item`
所有 `GameData.sell_from_deployed_weapon` → `InventoryManager.sell_from_deployed_weapon`
`GameData.player_level` → `PlayerProgression.player_level`
`GameData.get_population_cap()` → `PlayerProgression.get_population_cap()`
`GameData.current_wave` → `PlayerState.current_wave`

- [ ] **Step 3: map_select.gd 行 117**

```gdscript
GameData.selected_map = map_id
```
改为：
```gdscript
PlayerState.selected_map = map_id
```

- [ ] **Step 4: debug_panel.gd**

| 行 | 旧 | 新 |
|----|----|----|
| 27 | `GameData.coins += 100` | `InventoryManager.coins += 100` |
| 75 | `GameData.player_stats` | `PlayerState.player_stats` |
| 90 | `GameData.coins` | `InventoryManager.coins` |

- [ ] **Step 5: Commit**

```
git add scripts/ui/hud.gd scripts/ui/shop_overlay.gd scripts/ui/map_select.gd scripts/ui/debug_panel.gd
git commit -m "refactor: UI 文件迁移到新 Autoload"
```

### Task 13: 迁移系统文件（wave_manager, shop_manager, drag_manager）

**Files:**
- Modify: `scripts/systems/wave_manager.gd`
- Modify: `scripts/systems/shop_manager.gd`
- Modify: `scripts/systems/drag_manager.gd`

- [ ] **Step 1: wave_manager.gd**

| 行 | 旧 | 新 |
|----|----|----|
| 18 | `GameData.selected_map` | `PlayerState.selected_map` |
| 22 | `GameData.current_wave` | `PlayerState.current_wave` |
| 23 | `GameData.current_wave` | `PlayerState.current_wave` |
| 34 | `GameData.current_wave = current_wave` | `PlayerState.current_wave = current_wave` |

- [ ] **Step 2: shop_manager.gd**

所有 `GameData.shop_slots` → `InventoryManager.shop_slots`
所有 `GameData.coins` → `InventoryManager.coins`
所有 `GameData._recommended_weapon` → `InventoryManager._recommended_weapon`
所有 `GameData._recommended_tower` → `InventoryManager._recommended_tower`
所有 `GameData.buy_and_equip_weapon` → `InventoryManager.buy_and_equip_weapon`
所有 `GameData.buy_and_place_tower` → `InventoryManager.buy_and_place_tower`
所有 `GameData.can_buy_item` → `InventoryManager.can_buy_item`

- [ ] **Step 3: drag_manager.gd**

所有 `GameData.deployed_towers` → `InventoryManager.deployed_towers`
所有 `GameData.deployed_weapons` → `InventoryManager.deployed_weapons`
所有 `GameData.sell_from_deployed_tower` → `InventoryManager.sell_from_deployed_tower`
所有 `GameData.move_tower` → `InventoryManager.move_tower`

- [ ] **Step 4: Commit**

```
git add scripts/systems/wave_manager.gd scripts/systems/shop_manager.gd scripts/systems/drag_manager.gd
git commit -m "refactor: 系统文件迁移到新 Autoload"
```

### Task 14: 迁移实体文件（enemy, coin, tower_shooter）

**Files:**
- Modify: `scripts/entities/enemy.gd:107`
- Modify: `scripts/entities/coin.gd:33`
- Modify: `scripts/entities/towers/tower_shooter.gd:26`

- [ ] **Step 1: enemy.gd 行 107**

`GameData.record_kill()` → `StatsTracker.record_kill()`

- [ ] **Step 2: coin.gd 行 33**

`GameData.record_coins_earned(value)` → `StatsTracker.record_coins_earned(value)`

- [ ] **Step 3: tower_shooter.gd 行 26**

`GameData.player_stats` → `PlayerState.player_stats`

- [ ] **Step 4: Commit**

```
git add scripts/entities/enemy.gd scripts/entities/coin.gd scripts/entities/towers/tower_shooter.gd
git commit -m "refactor: 实体文件迁移到新 Autoload"
```

---

## Chunk 3: 迁移测试文件 + 删除 GameData + 验证

### Task 15: 迁移测试文件中的 GameData 引用

**Files:**
- Modify: `tests/unit/test_game_data.gd` — 引用替换为 InventoryManager + PlayerProgression
- Modify: `tests/unit/test_game_data_economy.gd` — 引用替换为 InventoryManager + PlayerProgression
- Modify: `tests/unit/test_game_data_stats.gd` — 引用替换为 StatsTracker
- Modify: `tests/unit/test_merge_system.gd` — `GameData` → `InventoryManager`
- Modify: `tests/unit/test_shop_manager.gd` — `GameData` → `InventoryManager` + `PlayerProgression`
- Modify: `tests/unit/test_shop_overlay.gd` — `GameData` → `InventoryManager` + `PlayerProgression`
- Modify: `tests/unit/test_drag_manager.gd` — `GameData` → `InventoryManager` + `PlayerProgression`
- Modify: `tests/unit/test_weapon_manager.gd` — `GameData` → `InventoryManager`
- Modify: `tests/unit/test_new_passives.gd` — `GameData` → `PlayerState` + `PlayerProgression` + `InventoryManager`
- Modify: `tests/unit/test_character_selection.gd` — `GameData` → `PlayerState`
- Modify: `tests/integration/test_tower_placement.gd` — `GameData` → `InventoryManager`
- Modify: `tests/integration/test_combat_flow.gd` — `GameData` → `PlayerState`

- [ ] **Step 1: 逐文件替换**

对每个测试文件，按引用迁移映射表将 `GameData.xxx` 替换为对应的新 Autoload。

关键替换模式：
- `GameData.reset()` → 依次调用 `PlayerState.reset()` + `PlayerProgression.reset()` + `InventoryManager.reset()` + `StatsTracker.reset()`
- `GameData.deployed_weapons` / `deployed_towers` / `coins` / `shop_slots` / `_recommended_weapon` / `_recommended_tower` / `player_level` / `is_first_shop_visit` → `InventoryManager.*` 或 `PlayerProgression.*`
- `GameData.init_character()` / `current_character` / `new_passive_id` / `new_passive_value*` / `player_stats` → `PlayerState.*`
- `GameData._check_merge()` → `InventoryManager._check_merge()`
- `GameData.can_buy_item()` → `InventoryManager.can_buy_item()`

注意 `test_game_data_stats.gd`：
- `GameData.record_kill/reset_kill_streak/record_damage_taken/record_coins_earned` → `StatsTracker.*`
- `before_each` 中的 `GameData.reset()` → `StatsTracker.reset()`

注意 `test_new_passives.gd`：
- `GameData.init_character(id)` → `PlayerState.init_character(id)`
- `GameData.new_passive_id/value/value_2` → `PlayerState.*`
- `GameData.current_character = X` → `PlayerState.current_character = X`
- `GameData.reset()` → 4 行 reset
- `GameData.coins` → `InventoryManager.coins`
- `GameData.player_stats` → `PlayerState.player_stats`

- [ ] **Step 2: Commit**

```
git add tests/
git commit -m "refactor: 测试文件迁移到新 Autoload"
```

### Task 16: 删除 game_data.gd + 从 project.godot 移除 GameData

**Files:**
- Delete: `scripts/core/game_data.gd`
- Modify: `project.godot` — 移除 GameData 行

- [ ] **Step 1: 删除文件**

```bash
git rm scripts/core/game_data.gd
```

- [ ] **Step 2: 从 project.godot 移除 GameData autoload 行**

删除 `GameData="*res://scripts/core/game_data.gd"` 行。

- [ ] **Step 3: Commit**

```
git add project.godot
git commit -m "chore: 删除 game_data.gd 及其 Autoload 注册"
```

### Task 17: 全量搜索验证 + 运行测试

- [ ] **Step 1: 搜索残留引用**

```bash
grep -r "GameData" scripts/ tests/ --include="*.gd"
```

期望结果：无匹配（或仅注释中残留，需清理）。

- [ ] **Step 2: 运行全部测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

期望结果：全部通过。

- [ ] **Step 3: 修复测试失败（如有）**

逐个修复失败测试，每次修复后重新运行。

- [ ] **Step 4: Commit（如有修复）**

```
git add -A
git commit -m "fix: 修复 GameData 拆分后的测试问题"
```

### Task 18: 更新 CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 更新 Autoload 单例文档**

将 CLAUDE.md 中 `### Autoload 单例` 段的 GameData 描述替换为 4 个新 Autoload 的描述：

- **PlayerState** (`scripts/core/player_state.gd`) — 角色身份、属性、被动系统、player_stats、selected_map、current_wave、pending_heal。`init_character(id)` 从 CharacterData 初始化属性，`reset()` 重置为默认值。
- **PlayerProgression** (`scripts/core/player_progression.gd`) — 经验/等级/人口上限。`add_exp(amount)` 累加经验自动升级，`exp_for_level(n)` 经验公式，`get_population_cap()` 公式化人口上限。
- **InventoryManager** (`scripts/core/inventory_manager.gd`) — 金币、deployed_weapons/towers、shop_slots、buy/sell/merge、deploy_id。依赖 PlayerState（角色数据）和 PlayerProgression（人口上限）。`buy_and_equip_weapon()`/`buy_and_place_tower()` 购买即部署，`can_buy_item()` 智能人口判断，`_check_merge()` 合成系统。
- **StatsTracker** (`scripts/core/stats_tracker.gd`) — 战斗统计：击杀、金币、伤害、连杀。`record_kill()`/`record_damage_taken()`/`record_coins_earned()`。

同时更新文档中所有 `GameData` 引用为对应的新 Autoload 名称。

- [ ] **Step 2: Commit**

```
git add CLAUDE.md
git commit -m "docs: 更新 CLAUDE.md Autoload 文档"
```
