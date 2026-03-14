# 自走棋式经济系统重构 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有升级弹窗 + 布置分离系统重构为自走棋式商店 + 背包 + 地图布置一体化系统。

**Architecture:** 分层重构——先改 Resource 数据层（max_level 5→3），再改 GameData 核心状态，然后新建 ShopManager 商店逻辑，最后搭建 shop 场景 UI 和清理旧系统。每层独立可测试。

**Tech Stack:** Godot 4.6 / GDScript / GUT 测试框架 / Jolt Physics

**测试运行命令:** `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

**注意：** 新增带 `class_name` 的脚本后，需手动在 `.godot/global_script_class_cache.cfg` 中补充条目，否则 headless 测试无法识别该类名。

---

## File Map

### 新建文件
| 文件 | 职责 |
|------|------|
| `scripts/resources/shop_config.gd` | ShopConfig Resource 类定义 |
| `resources/shop/shop_config.tres` | ShopConfig 数据文件 |
| `scripts/systems/shop_manager.gd` | 商店逻辑（物品池、刷新、购买、卖出、合成） |
| `scenes/ui/shop.tscn` | 商店场景 |
| `scripts/ui/shop.gd` | 商店场景控制器 |
| `scripts/ui/shop_panel.gd` | 商店栏 UI 组件 |
| `scripts/ui/bag_panel.gd` | 背包栏 UI 组件 |
| `scripts/ui/equip_panel.gd` | 角色装备栏 UI 组件 |
| `tests/unit/test_shop_config.gd` | ShopConfig 测试 |
| `tests/unit/test_shop_manager.gd` | ShopManager 测试 |
| `tests/unit/test_game_data_economy.gd` | GameData 新经济系统测试 |
| `tests/unit/test_merge_system.gd` | 合成系统测试 |

### 修改文件
| 文件 | 改动 |
|------|------|
| `scripts/resources/weapon_data.gd` | max_level→3, 加 rarity 字段, 删 shop_price_per_level, 加 sell_price_per_level |
| `scripts/resources/tower_data.gd` | max_level→3, 加 rarity 字段, 删 place_cost_per_level/shop_price_per_level, 加 sell_price_per_level |
| `scripts/resources/character_data.gd` | default_weapon→recommended_weapon, default_tower→recommended_tower |
| `resources/weapons/*.tres` (10个) | per_level 数组 5→3 元素, 加 sell_price_per_level |
| `resources/towers/*.tres` (15个) | per_level 数组 5→3 元素, 删 place_cost, 加 sell_price_per_level |
| `resources/characters/*.tres` | 字段重命名 |
| `scripts/core/game_data.gd` | 全面重构：删旧状态/API, 加新状态/API |
| `scripts/core/event_bus.gd` | 删 4 信号, 加 6 信号 |
| `scripts/core/scene_manager.gd` | 加 shop 路由, 删 placement |
| `scripts/core/scene_factory.gd` | create_tower 加 level 参数, 删 get_tower_cost |
| `scripts/core/game_config.gd` | 加载 ShopConfig |
| `scripts/entities/player.gd` | 从 deployed_weapons 初始化, 删 add_xp |
| `scripts/entities/weapons/weapon.gd` | 改 level 读取方式 |
| `scripts/entities/weapons/weapon_manager.gd` | initialize 接受 level 信息 |
| `scripts/entities/towers/tower.gd` | level 由创建时注入, 删 tower_upgraded 监听 |
| `scripts/ui/main.gd` | 删升级弹窗, 改塔生成, 波次结束→shop |
| `scripts/ui/hud.gd` | 删除 XP/升级 UI |

### 删除文件
| 文件 | 原因 |
|------|------|
| `scripts/systems/upgrade_generator.gd` | 被 ShopManager 取代 |
| `scripts/ui/upgrade_popup.gd` | 被 shop 场景取代 |
| `scenes/ui/upgrade_popup.tscn` | 被 shop 场景取代 |
| `scripts/ui/placement.gd` | 功能合并到 shop |
| `scripts/ui/placement_panel.gd` | 功能合并到 shop |
| `scenes/levels/placement.tscn` | 被 shop 场景取代 |
| `tests/unit/test_upgrade_generator.gd` | 旧系统测试 |
| `tests/unit/test_placement_panel.gd` | 旧系统测试 |
| `tests/unit/test_game_data_xp.gd` | XP 系统测试 |

---

## Chunk 1: Resource 数据层改造

### Task 1: ShopConfig Resource 类

**Files:**
- Create: `scripts/resources/shop_config.gd`
- Test: `tests/unit/test_shop_config.gd`

- [ ] **Step 1: 写 ShopConfig 测试**

```gdscript
# tests/unit/test_shop_config.gd
extends GutTest

var config: ShopConfig

func before_each() -> void:
	config = ShopConfig.new()

func test_default_values() -> void:
	assert_eq(config.slot_count, 4)
	assert_eq(config.refresh_cost, 2)
	assert_eq(config.bag_capacity, 10)

func test_cost_by_rarity() -> void:
	assert_eq(config.cost_by_rarity[0], 3)
	assert_eq(config.cost_by_rarity[1], 5)
	assert_eq(config.cost_by_rarity[2], 8)

func test_level_up_costs() -> void:
	assert_eq(config.level_up_costs[0], 4)
	assert_eq(config.level_up_costs[5], 36)

func test_population_per_level() -> void:
	assert_eq(config.population_per_level[0], 2)  # Lv1
	assert_eq(config.population_per_level[6], 8)  # Lv7

func test_rarity_weights_structure() -> void:
	assert_eq(config.rarity_weights.size(), 7)
	# Lv1: 100% common
	assert_eq(config.rarity_weights[0][0], 100.0)
	assert_eq(config.rarity_weights[0][1], 0.0)
	# Lv3: 70/30/0
	assert_eq(config.rarity_weights[2][0], 70.0)
	assert_eq(config.rarity_weights[2][1], 30.0)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_shop_config.gd -gexit`
Expected: FAIL — ShopConfig 类不存在

- [ ] **Step 3: 实现 ShopConfig**

```gdscript
# scripts/resources/shop_config.gd
class_name ShopConfig
extends Resource

@export var slot_count: int = 4
@export var refresh_cost: int = 2
@export var bag_capacity: int = 10
@export var cost_by_rarity: PackedInt32Array = PackedInt32Array([3, 5, 8])
@export var level_up_costs: PackedInt32Array = PackedInt32Array([4, 8, 12, 20, 28, 36])
@export var population_per_level: PackedInt32Array = PackedInt32Array([2, 3, 4, 5, 6, 7, 8])
@export var rarity_weights: Array[PackedFloat32Array] = [
	PackedFloat32Array([100.0, 0.0, 0.0]),    # Lv1
	PackedFloat32Array([100.0, 0.0, 0.0]),    # Lv2
	PackedFloat32Array([70.0, 30.0, 0.0]),    # Lv3
	PackedFloat32Array([55.0, 40.0, 5.0]),    # Lv4
	PackedFloat32Array([40.0, 40.0, 20.0]),   # Lv5
	PackedFloat32Array([30.0, 40.0, 30.0]),   # Lv6
	PackedFloat32Array([20.0, 40.0, 40.0]),   # Lv7
]
```

- [ ] **Step 4: 注册 class_name 到 global_script_class_cache.cfg**

在 `.godot/global_script_class_cache.cfg` 中添加 ShopConfig 条目。

- [ ] **Step 5: 运行测试确认通过**

Run: 同 Step 2
Expected: PASS

- [ ] **Step 6: 创建 ShopConfig .tres 数据文件**

```
# resources/shop/shop_config.tres
[gd_resource type="Resource" script_class="ShopConfig" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/shop_config.gd" id="1"]
[resource]
script = ExtResource("1")
```

- [ ] **Step 7: GameConfig 加载 ShopConfig**

修改 `scripts/core/game_config.gd`:
- 新增变量: `var shop_config: ShopConfig = null`
- 在 `_load_resources()` 中加载: `shop_config = load("res://resources/shop/shop_config.tres")`

- [ ] **Step 8: Commit**

```bash
git add scripts/resources/shop_config.gd resources/shop/shop_config.tres tests/unit/test_shop_config.gd scripts/core/game_config.gd .godot/global_script_class_cache.cfg
git commit -m "feat: 新增 ShopConfig Resource 类和数据文件"
```

---

### Task 2: WeaponData 改造 (max_level 5→3)

**Files:**
- Modify: `scripts/resources/weapon_data.gd`
- Modify: `resources/weapons/*.tres` (10 个文件)

- [ ] **Step 1: 修改 weapon_data.gd**

在 `scripts/resources/weapon_data.gd` 中:
- 将 `max_level` 默认值从 5 改为 3: `@export var max_level: int = 3`
- 确认存在 `@export var rarity: int = 0` 字段（如不存在则新增）
- 新增字段: `@export var sell_price_per_level: PackedInt32Array = PackedInt32Array([])`
- 如果存在 `shop_price_per_level` 字段则删除

- [ ] **Step 2: 更新所有 10 个 weapon .tres 文件**

对每个 weapon .tres 文件:
- `max_level = 3`
- 所有 `per_level` 数组从 5 元素缩减为 3 元素（取原 index 0/2/4 即 Lv1/Lv3/Lv5 值）
- 新增 `sell_price_per_level` 根据 rarity:
  - rarity 0 (普通): `[3, 7, 21]`
  - rarity 1 (稀有): `[5, 12, 36]`
  - rarity 2 (史诗): `[8, 19, 57]`
- 删除 `milestones` 字段（如果存在）

**武器文件列表:**
- `resources/weapons/rifle.tres` (rarity 0)
- `resources/weapons/shotgun.tres` (rarity 0)
- `resources/weapons/blade.tres` (rarity 0)
- `resources/weapons/boomerang.tres` (rarity 1)
- `resources/weapons/minigun.tres` (rarity 1)
- `resources/weapons/ice_gun.tres` (rarity 1)
- `resources/weapons/laser.tres` (rarity 1)
- `resources/weapons/rocket.tres` (rarity 2)
- `resources/weapons/lightning.tres` (rarity 2)
- `resources/weapons/flamethrower.tres` (rarity 2)

- [ ] **Step 3: 运行现有测试确认无回归**

Run: 完整测试命令
Expected: 所有不依赖 max_level=5 的测试通过

- [ ] **Step 4: Commit**

```bash
git add scripts/resources/weapon_data.gd resources/weapons/
git commit -m "feat: WeaponData max_level 5→3, 新增 sell_price_per_level"
```

---

### Task 3: TowerData 改造 (max_level 5→3)

**Files:**
- Modify: `scripts/resources/tower_data.gd`
- Modify: `resources/towers/*.tres` (15 个文件)

- [ ] **Step 1: 修改 tower_data.gd**

在 `scripts/resources/tower_data.gd` 中:
- `max_level` 默认值 5 → 3
- 确认存在 `@export var rarity: int = 0` 字段（如不存在则新增）
- 删除 `place_cost_per_level` 字段（line 19）
- 删除 `shop_price_per_level` 字段（line 18）
- 新增: `@export var sell_price_per_level: PackedInt32Array = PackedInt32Array([])`
- 删除 `milestones` 字段（line 20, 如果存在）

- [ ] **Step 2: 更新所有 15 个 tower .tres 文件**

对每个 tower .tres:
- `max_level = 3`
- 所有 `per_level` 数组从 5 元素缩减为 3 元素（取 index 0/2/4）
- 删除 `place_cost_per_level` 和 `shop_price_per_level`
- 新增 `sell_price_per_level` 按 rarity

**塔文件列表:**
- rarity 0: pea_shooter, stump, ice_flower, sunflower
- rarity 1: cactus, rose, mushroom, vine, dandelion, thorn, oak
- rarity 2: pitcher, mint, heal_flower, bamboo

- [ ] **Step 3: 运行测试**

Run: 完整测试命令
Expected: 通过（除了依赖 place_cost 的旧测试）

- [ ] **Step 4: Commit**

```bash
git add scripts/resources/tower_data.gd resources/towers/
git commit -m "feat: TowerData max_level 5→3, 删除 place_cost, 新增 sell_price_per_level"
```

---

### Task 4: CharacterData 改造

**Files:**
- Modify: `scripts/resources/character_data.gd`
- Modify: `resources/characters/*.tres`

- [ ] **Step 1: 修改 character_data.gd**

在 `scripts/resources/character_data.gd` 中:
- Line 14: `default_weapon` → `recommended_weapon`
- Line 16: `default_tower` → `recommended_tower`

- [ ] **Step 2: 更新所有 character .tres 文件**

将每个 .tres 中的 `default_weapon` 重命名为 `recommended_weapon`，`default_tower` 重命名为 `recommended_tower`。

- [ ] **Step 3: 更新 GameData.reset() 中的引用**

在 `scripts/core/game_data.gd` 的 `reset()` 函数中:
- Line 119: `char_data.default_weapon` → `char_data.recommended_weapon`
- Line 120: `char_data.default_tower` → `char_data.recommended_tower`

（注意：这些行后续会在 Task 5 中大改，这里只做字段重命名以保持编译通过）

- [ ] **Step 4: 运行测试**

Run: 完整测试命令
Expected: 通过

- [ ] **Step 5: Commit**

```bash
git add scripts/resources/character_data.gd resources/characters/ scripts/core/game_data.gd
git commit -m "refactor: CharacterData default_weapon/tower → recommended_weapon/tower"
```

---

## Chunk 2: GameData 核心状态重构

### Task 5: EventBus 信号变更

**Files:**
- Modify: `scripts/core/event_bus.gd`

- [ ] **Step 1: 删除旧信号**

在 `scripts/core/event_bus.gd` 中删除:
- Line 25: `signal player_leveled_up(level: int)`
- Line 26: `signal xp_changed(current_xp: int, xp_to_next: int)`
- Line 34: `signal tower_upgraded(tower_type: String)`
- Line 35: `signal tower_purchased(tower_type: String)`

- [ ] **Step 2: 新增信号**

在 `scripts/core/event_bus.gd` 中添加:

```gdscript
# 商店系统
signal item_purchased(item: Dictionary)
signal item_sold(item: Dictionary, refund: int)
signal item_merged(item_id: String, new_level: int)
signal item_deployed(item: Dictionary)
signal item_undeployed(item: Dictionary)
signal player_level_changed(new_level: int)
```

- [ ] **Step 3: 全局搜索旧信号引用并注释/标记**

搜索引用 `player_leveled_up`, `xp_changed`, `tower_upgraded`, `tower_purchased` 的代码，标记为待修改（后续 Task 会处理）。

- [ ] **Step 4: Commit**

```bash
git add scripts/core/event_bus.gd
git commit -m "refactor: EventBus 删除旧 XP/upgrade 信号, 新增商店系统信号"
```

---

### Task 6: GameData 核心重构

**Files:**
- Modify: `scripts/core/game_data.gd`
- Test: `tests/unit/test_game_data_economy.gd`

- [ ] **Step 1: 写新经济系统测试**

```gdscript
# tests/unit/test_game_data_economy.gd
extends GutTest

func before_each() -> void:
	GameData.coins = 100
	GameData.player_level = 1
	GameData.bag = []
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	GameData.shop_slots = []

func test_initial_state() -> void:
	assert_eq(GameData.player_level, 1)
	assert_eq(GameData.get_population_cap(), 2)
	assert_eq(GameData.get_population_used(), 0)

func test_population_cap_by_level() -> void:
	GameData.player_level = 3
	assert_eq(GameData.get_population_cap(), 4)
	GameData.player_level = 7
	assert_eq(GameData.get_population_cap(), 8)

func test_population_used_counts_deployed() -> void:
	GameData.deployed_weapons.append({id = "rifle", level = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0)})
	assert_eq(GameData.get_population_used(), 2)

func test_can_deploy_respects_cap() -> void:
	GameData.player_level = 1  # cap = 2
	GameData.deployed_weapons.append({id = "rifle", level = 1})
	GameData.deployed_weapons.append({id = "shotgun", level = 1})
	assert_false(GameData.can_deploy())

func test_can_buy_respects_bag_capacity() -> void:
	for i in 10:
		GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	assert_false(GameData.can_buy())

func test_buy_level_up() -> void:
	GameData.coins = 100
	GameData.player_level = 1
	var result: bool = GameData.buy_level_up()
	assert_true(result)
	assert_eq(GameData.player_level, 2)
	assert_eq(GameData.coins, 96)  # 100 - 4

func test_buy_level_up_max_level() -> void:
	GameData.player_level = 7
	var result: bool = GameData.buy_level_up()
	assert_false(result)

func test_buy_level_up_insufficient_coins() -> void:
	GameData.coins = 2
	GameData.player_level = 1
	var result: bool = GameData.buy_level_up()
	assert_false(result)
	assert_eq(GameData.player_level, 1)

func test_deploy_weapon() -> void:
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	var result: bool = GameData.deploy_weapon(0)
	assert_true(result)
	assert_eq(GameData.deployed_weapons.size(), 1)
	assert_eq(GameData.bag.size(), 0)

func test_deploy_weapon_population_full() -> void:
	GameData.player_level = 1  # cap = 2
	GameData.deployed_weapons.append({id = "rifle", level = 1})
	GameData.deployed_weapons.append({id = "shotgun", level = 1})
	GameData.bag.append({id = "blade", type = "weapon", level = 1})
	var result: bool = GameData.deploy_weapon(0)
	assert_false(result)

func test_undeploy_weapon() -> void:
	GameData.deployed_weapons.append({id = "rifle", level = 1})
	GameData.undeploy_weapon(0)
	assert_eq(GameData.deployed_weapons.size(), 0)
	assert_eq(GameData.bag.size(), 1)
	assert_eq(GameData.bag[0].id, "rifle")

func test_deploy_tower() -> void:
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	var result: bool = GameData.deploy_tower(0, Vector2i(3, 2))
	assert_true(result)
	assert_eq(GameData.deployed_towers.size(), 1)
	assert_eq(GameData.deployed_towers[0].grid_pos, Vector2i(3, 2))
	assert_eq(GameData.bag.size(), 0)

func test_undeploy_tower() -> void:
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(3, 2)})
	GameData.undeploy_tower(0)
	assert_eq(GameData.deployed_towers.size(), 0)
	assert_eq(GameData.bag.size(), 1)

func test_sell_from_bag_lv1_full_refund() -> void:
	# rifle rarity=0, sell_price_per_level=[3,7,21]
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData.coins = 10
	var refund: int = GameData.sell_from_bag(0)
	assert_eq(refund, 3)
	assert_eq(GameData.coins, 13)
	assert_eq(GameData.bag.size(), 0)

func test_sell_from_bag_lv2_80_percent() -> void:
	GameData.bag.append({id = "rifle", type = "weapon", level = 2})
	GameData.coins = 10
	var refund: int = GameData.sell_from_bag(0)
	assert_eq(refund, 7)
	assert_eq(GameData.coins, 17)
	assert_eq(GameData.bag.size(), 0)

func test_sell_from_deployed_weapon() -> void:
	GameData.deployed_weapons.append({id = "rifle", level = 1})
	GameData.coins = 10
	var refund: int = GameData.sell_from_deployed_weapon(0)
	assert_eq(refund, 3)
	assert_eq(GameData.deployed_weapons.size(), 0)

func test_sell_from_deployed_tower() -> void:
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0)})
	GameData.coins = 10
	var refund: int = GameData.sell_from_deployed_tower(0)
	assert_eq(refund, 3)
	assert_eq(GameData.deployed_towers.size(), 0)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_game_data_economy.gd -gexit`
Expected: FAIL

- [ ] **Step 3: 重构 GameData**

在 `scripts/core/game_data.gd` 中:

**删除变量:**
- `owned_weapons: Dictionary`
- `owned_towers: Dictionary`
- `tower_inventory: Array`
- `current_level: int`
- `current_xp: int`
- `pending_upgrades: int`

**删除函数:**
- `add_xp()`
- `get_xp_to_next_level()`
- `upgrade_weapon()`
- `upgrade_tower()`

**新增变量:**
```gdscript
var player_level: int = 1
var bag: Array[Dictionary] = []
var deployed_weapons: Array[Dictionary] = []
var deployed_towers: Array[Dictionary] = []
var shop_slots: Array[Dictionary] = []
```

**新增函数:**
```gdscript
func get_population_cap() -> int:
	var config: ShopConfig = GameConfig.shop_config
	return config.population_per_level[player_level - 1]

func get_population_used() -> int:
	return deployed_weapons.size() + deployed_towers.size()

func get_bag_count() -> int:
	return bag.size()

func can_deploy() -> bool:
	return get_population_used() < get_population_cap()

func can_buy() -> bool:
	var config: ShopConfig = GameConfig.shop_config
	return bag.size() < config.bag_capacity

func buy_level_up() -> bool:
	var config: ShopConfig = GameConfig.shop_config
	if player_level >= config.population_per_level.size():
		return false
	var cost: int = config.level_up_costs[player_level - 1]
	if coins < cost:
		return false
	coins -= cost
	player_level += 1
	EventBus.player_level_changed.emit(player_level)
	EventBus.coins_changed.emit(-cost, coins)
	return true

func deploy_weapon(bag_index: int) -> bool:
	if not can_deploy():
		return false
	if bag_index < 0 or bag_index >= bag.size():
		return false
	var item: Dictionary = bag[bag_index]
	if item.type != "weapon":
		return false
	bag.remove_at(bag_index)
	deployed_weapons.append({id = item.id, level = item.level})
	EventBus.item_deployed.emit(item)
	return true

func undeploy_weapon(deploy_index: int) -> void:
	if deploy_index < 0 or deploy_index >= deployed_weapons.size():
		return
	var item: Dictionary = deployed_weapons[deploy_index]
	deployed_weapons.remove_at(deploy_index)
	bag.append({id = item.id, type = "weapon", level = item.level})
	EventBus.item_undeployed.emit(item)

func deploy_tower(bag_index: int, grid_pos: Vector2i) -> bool:
	if not can_deploy():
		return false
	if bag_index < 0 or bag_index >= bag.size():
		return false
	var item: Dictionary = bag[bag_index]
	if item.type != "tower":
		return false
	bag.remove_at(bag_index)
	deployed_towers.append({id = item.id, level = item.level, grid_pos = grid_pos})
	EventBus.item_deployed.emit(item)
	return true

func undeploy_tower(deploy_index: int) -> void:
	if deploy_index < 0 or deploy_index >= deployed_towers.size():
		return
	var item: Dictionary = deployed_towers[deploy_index]
	deployed_towers.remove_at(deploy_index)
	bag.append({id = item.id, type = "tower", level = item.level})
	EventBus.item_undeployed.emit(item)

func sell_from_bag(bag_index: int) -> int:
	if bag_index < 0 or bag_index >= bag.size():
		return 0
	var item: Dictionary = bag[bag_index]
	bag.remove_at(bag_index)
	return _apply_sell(item)

func sell_from_deployed_weapon(deploy_index: int) -> int:
	if deploy_index < 0 or deploy_index >= deployed_weapons.size():
		return 0
	var entry: Dictionary = deployed_weapons[deploy_index]
	deployed_weapons.remove_at(deploy_index)
	var item := {id = entry.id, type = "weapon", level = entry.level}
	return _apply_sell(item)

func sell_from_deployed_tower(deploy_index: int) -> int:
	if deploy_index < 0 or deploy_index >= deployed_towers.size():
		return 0
	var entry: Dictionary = deployed_towers[deploy_index]
	deployed_towers.remove_at(deploy_index)
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
```

**修改 reset():**
```gdscript
func reset() -> void:
	# ... 保留角色属性初始化 ...
	coins = GameConfig.PLAYER["initial_coins"] + char_data.starting_gold
	assert(coins >= 6, "初始金币必须 >= 6")
	player_level = 1
	bag = []
	deployed_weapons = []
	deployed_towers = []
	shop_slots = []
	# 不再设置 owned_weapons/owned_towers
```

- [ ] **Step 4: 运行新测试确认通过**

Run: 同 Step 2
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/game_data.gd tests/unit/test_game_data_economy.gd
git commit -m "feat: GameData 核心重构 — 背包/部署/人口/卖出系统"
```

---

### Task 7: 合成系统

**Files:**
- Modify: `scripts/core/game_data.gd` (添加合成逻辑)
- Test: `tests/unit/test_merge_system.gd`

- [ ] **Step 1: 写合成测试**

```gdscript
# tests/unit/test_merge_system.gd
extends GutTest

func before_each() -> void:
	GameData.coins = 100
	GameData.player_level = 1
	GameData.bag = []
	GameData.deployed_weapons = []
	GameData.deployed_towers = []

func test_no_merge_with_two_same_items() -> void:
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData._check_merge("rifle", 1)
	assert_eq(GameData.bag.size(), 2)

func test_merge_three_lv1_to_lv2() -> void:
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData._check_merge("rifle", 1)
	assert_eq(GameData.bag.size(), 1)
	assert_eq(GameData.bag[0].level, 2)

func test_merge_does_not_trigger_at_max_level() -> void:
	GameData.bag.append({id = "rifle", type = "weapon", level = 3})
	GameData.bag.append({id = "rifle", type = "weapon", level = 3})
	GameData.bag.append({id = "rifle", type = "weapon", level = 3})
	GameData._check_merge("rifle", 3)
	assert_eq(GameData.bag.size(), 3)  # 不合成

func test_merge_recalls_deployed_weapons() -> void:
	GameData.deployed_weapons.append({id = "rifle", level = 1})
	GameData.deployed_weapons.append({id = "rifle", level = 1})
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData._check_merge("rifle", 1)
	assert_eq(GameData.deployed_weapons.size(), 0)
	assert_eq(GameData.bag.size(), 1)
	assert_eq(GameData.bag[0].level, 2)

func test_merge_recalls_deployed_towers() -> void:
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0)})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(1, 0)})
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	GameData._check_merge("pea_shooter", 1)
	assert_eq(GameData.deployed_towers.size(), 0)
	assert_eq(GameData.bag.size(), 1)
	assert_eq(GameData.bag[0].level, 2)

func test_recursive_merge() -> void:
	# 2 个 Lv2 + 3 个 Lv1：3 个 Lv1 合成 1 个 Lv2，加上已有 2 个 Lv2 = 3 个 Lv2 → 1 个 Lv3
	GameData.bag.append({id = "rifle", type = "weapon", level = 2})
	GameData.bag.append({id = "rifle", type = "weapon", level = 2})
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData._check_merge("rifle", 1)
	# 3 个 Lv1 → 1 个 Lv2，现在有 3 个 Lv2 → 1 个 Lv3
	assert_eq(GameData.bag.size(), 1)
	assert_eq(GameData.bag[0].level, 3)

func test_merge_different_ids_no_cross() -> void:
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData.bag.append({id = "shotgun", type = "weapon", level = 1})
	GameData._check_merge("rifle", 1)
	assert_eq(GameData.bag.size(), 3)  # 不合成
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_merge_system.gd -gexit`
Expected: FAIL

- [ ] **Step 3: 实现合成逻辑**

在 `scripts/core/game_data.gd` 中添加:

```gdscript
func _check_merge(item_id: String, item_level: int) -> void:
	if item_level >= 3:
		return
	var all_items: Array[Dictionary] = _collect_items_by_id_level(item_id, item_level)
	if all_items.size() < 3:
		return
	# 回收 3 个物品（优先从 bag 取，再从 deployed 取）
	var consumed: int = 0
	var item_type: String = ""
	# 从 bag 回收
	var i: int = bag.size() - 1
	while i >= 0 and consumed < 3:
		if bag[i].id == item_id and bag[i].level == item_level:
			item_type = bag[i].type
			bag.remove_at(i)
			consumed += 1
		i -= 1
	# 从 deployed_weapons 回收
	i = deployed_weapons.size() - 1
	while i >= 0 and consumed < 3:
		if deployed_weapons[i].id == item_id and deployed_weapons[i].level == item_level:
			item_type = "weapon"
			deployed_weapons.remove_at(i)
			consumed += 1
		i -= 1
	# 从 deployed_towers 回收
	i = deployed_towers.size() - 1
	while i >= 0 and consumed < 3:
		if deployed_towers[i].id == item_id and deployed_towers[i].level == item_level:
			item_type = "tower"
			deployed_towers.remove_at(i)
			consumed += 1
		i -= 1
	# 生成合成品
	var new_level: int = item_level + 1
	bag.append({id = item_id, type = item_type, level = new_level})
	EventBus.item_merged.emit(item_id, new_level)
	# 递归检查
	_check_merge(item_id, new_level)

func _collect_items_by_id_level(item_id: String, item_level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in bag:
		if item.id == item_id and item.level == item_level:
			result.append(item)
	for item in deployed_weapons:
		if item.id == item_id and item.level == item_level:
			result.append(item)
	for item in deployed_towers:
		if item.id == item_id and item.level == item_level:
			result.append(item)
	return result
```

- [ ] **Step 4: 运行测试确认通过**

Run: 同 Step 2
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/game_data.gd tests/unit/test_merge_system.gd
git commit -m "feat: 自动三合一合成系统（递归、回收已部署、跨位置检查）"
```

---

## Chunk 3: ShopManager 商店逻辑

### Task 8: ShopManager 核心逻辑

**Files:**
- Create: `scripts/systems/shop_manager.gd`
- Test: `tests/unit/test_shop_manager.gd`

- [ ] **Step 1: 写 ShopManager 测试**

```gdscript
# tests/unit/test_shop_manager.gd
extends GutTest

var manager: ShopManager

func before_each() -> void:
	manager = ShopManager.new()
	GameData.coins = 100
	GameData.player_level = 1
	GameData.bag = []
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	GameData.shop_slots = []

func test_refresh_generates_4_slots() -> void:
	manager.refresh_shop()
	assert_eq(GameData.shop_slots.size(), 4)

func test_refresh_all_common_at_level_1() -> void:
	manager.refresh_shop()
	for slot in GameData.shop_slots:
		assert_eq(slot.rarity, 0, "Lv1 应只出普通物品")

func test_first_shop_has_recommended() -> void:
	# 需要设置 GameData 的角色推荐
	GameData._recommended_weapon = "rifle"
	GameData._recommended_tower = "pea_shooter"
	manager.refresh_shop(true)  # is_first = true
	var ids: Array[String] = []
	for slot in GameData.shop_slots:
		ids.append(slot.id)
	assert_has(ids, "rifle", "首次商店应包含推荐武器")
	assert_has(ids, "pea_shooter", "首次商店应包含推荐塔")

func test_buy_item_deducts_coins() -> void:
	manager.refresh_shop()
	var cost: int = GameData.shop_slots[0].cost
	var initial_coins: int = GameData.coins
	var result: bool = manager.buy_item(0)
	assert_true(result)
	assert_eq(GameData.coins, initial_coins - cost)

func test_buy_item_adds_to_bag() -> void:
	manager.refresh_shop()
	manager.buy_item(0)
	assert_eq(GameData.bag.size(), 1)

func test_buy_item_clears_slot() -> void:
	manager.refresh_shop()
	manager.buy_item(0)
	assert_true(GameData.shop_slots[0].is_empty())

func test_buy_item_insufficient_coins() -> void:
	manager.refresh_shop()
	GameData.coins = 0
	var result: bool = manager.buy_item(0)
	assert_false(result)

func test_buy_item_bag_full() -> void:
	for i in 10:
		GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	manager.refresh_shop()
	var result: bool = manager.buy_item(0)
	assert_false(result)

func test_buy_item_triggers_merge() -> void:
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	# 手动设置 shop slot 为 rifle
	GameData.shop_slots = [
		{id = "rifle", type = "weapon", rarity = 0, cost = 3},
		{id = "shotgun", type = "weapon", rarity = 0, cost = 3},
		{id = "pea_shooter", type = "tower", rarity = 0, cost = 3},
		{id = "stump", type = "tower", rarity = 0, cost = 3},
	]
	manager.buy_item(0)
	# 应触发合成：3 个 Lv1 rifle → 1 个 Lv2
	assert_eq(GameData.bag.size(), 1)
	assert_eq(GameData.bag[0].level, 2)

func test_manual_refresh_costs_2() -> void:
	manager.refresh_shop()
	var initial_coins: int = GameData.coins
	var result: bool = manager.manual_refresh()
	assert_true(result)
	assert_eq(GameData.coins, initial_coins - 2)

func test_manual_refresh_insufficient_coins() -> void:
	GameData.coins = 1
	var result: bool = manager.manual_refresh()
	assert_false(result)

func test_shop_slot_cost_matches_rarity() -> void:
	GameData.player_level = 5  # 可出全部稀有度
	manager.refresh_shop()
	for slot in GameData.shop_slots:
		var expected_cost: int = GameConfig.shop_config.cost_by_rarity[slot.rarity]
		assert_eq(slot.cost, expected_cost)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_shop_manager.gd -gexit`
Expected: FAIL

- [ ] **Step 3: 实现 ShopManager**

```gdscript
# scripts/systems/shop_manager.gd
class_name ShopManager
extends RefCounted

func refresh_shop(is_first: bool = false) -> void:
	var config: ShopConfig = GameConfig.shop_config
	GameData.shop_slots = []
	var guaranteed_ids: Array[String] = []
	if is_first:
		guaranteed_ids.append(GameData._recommended_weapon)
		guaranteed_ids.append(GameData._recommended_tower)
	for i in config.slot_count:
		if i < guaranteed_ids.size():
			var item_id: String = guaranteed_ids[i]
			var item_data: Resource = _get_item_data(item_id)
			GameData.shop_slots.append({
				id = item_id,
				type = _get_item_type(item_id),
				rarity = item_data.rarity,
				cost = config.cost_by_rarity[item_data.rarity],
			})
		else:
			GameData.shop_slots.append(_generate_random_slot())

func manual_refresh() -> bool:
	var config: ShopConfig = GameConfig.shop_config
	if GameData.coins < config.refresh_cost:
		return false
	GameData.coins -= config.refresh_cost
	EventBus.coins_changed.emit(-config.refresh_cost, GameData.coins)
	refresh_shop()
	return true

func buy_item(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= GameData.shop_slots.size():
		return false
	var slot: Dictionary = GameData.shop_slots[slot_index]
	if slot.is_empty():
		return false
	if GameData.coins < slot.cost:
		return false
	if not GameData.can_buy():
		return false
	GameData.coins -= slot.cost
	var item := {id = slot.id, type = slot.type, level = 1}
	GameData.bag.append(item)
	GameData.shop_slots[slot_index] = {}
	EventBus.item_purchased.emit(item)
	EventBus.coins_changed.emit(-slot.cost, GameData.coins)
	# 触发合成检查
	GameData._check_merge(slot.id, 1)
	return true

func _generate_random_slot() -> Dictionary:
	var config: ShopConfig = GameConfig.shop_config
	var weights: PackedFloat32Array = config.rarity_weights[GameData.player_level - 1]
	var rarity: int = _weighted_random_rarity(weights)
	var pool: Array[String] = _get_pool_by_rarity(rarity)
	if pool.is_empty():
		return {}
	var item_id: String = pool[randi() % pool.size()]
	var item_data: Resource = _get_item_data(item_id)
	return {
		id = item_id,
		type = _get_item_type(item_id),
		rarity = rarity,
		cost = config.cost_by_rarity[rarity],
	}

func _weighted_random_rarity(weights: PackedFloat32Array) -> int:
	var total: float = 0.0
	for w in weights:
		total += w
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for i in weights.size():
		cumulative += weights[i]
		if roll < cumulative:
			return i
	return 0

func _get_pool_by_rarity(rarity: int) -> Array[String]:
	var pool: Array[String] = []
	for id: String in GameConfig.weapons:
		if GameConfig.weapons[id].rarity == rarity:
			pool.append(id)
	for id: String in GameConfig.towers:
		if GameConfig.towers[id].rarity == rarity:
			pool.append(id)
	return pool

func _get_item_data(item_id: String) -> Resource:
	if GameConfig.weapons.has(item_id):
		return GameConfig.weapons[item_id]
	return GameConfig.towers[item_id]

func _get_item_type(item_id: String) -> String:
	if GameConfig.weapons.has(item_id):
		return "weapon"
	return "tower"
```

- [ ] **Step 4: 注册 class_name**

在 `.godot/global_script_class_cache.cfg` 中添加 ShopManager 条目。

- [ ] **Step 5: 在 GameData 中添加推荐字段**

在 `scripts/core/game_data.gd` 中添加:
```gdscript
var _recommended_weapon: String = ""
var _recommended_tower: String = ""
var is_first_shop_visit: bool = true
```

在 `reset()` 中设置:
```gdscript
_recommended_weapon = char_data.recommended_weapon
_recommended_tower = char_data.recommended_tower
is_first_shop_visit = true
```

- [ ] **Step 6: 运行测试确认通过**

Run: 同 Step 2
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add scripts/systems/shop_manager.gd tests/unit/test_shop_manager.gd scripts/core/game_data.gd .godot/global_script_class_cache.cfg
git commit -m "feat: ShopManager — 商店刷新、购买、物品池、稀有度权重"
```

---

## Chunk 4: 战斗系统对接

### Task 9: SceneFactory 和武器系统改造

**Files:**
- Modify: `scripts/core/scene_factory.gd`
- Modify: `scripts/entities/weapons/weapon.gd`
- Modify: `scripts/entities/weapons/weapon_manager.gd`
- Modify: `scripts/entities/player.gd`

- [ ] **Step 1: 修改 weapon.gd level 读取**

在 `scripts/entities/weapons/weapon.gd` 中:
- 新增变量: `var _level: int = 1`
- 新增函数: `func set_level(level: int) -> void: _level = level`
- 修改 `get_current_level()` (line 14-15):
  ```gdscript
  func get_current_level() -> int:
      return _level
  ```

- [ ] **Step 2: 修改 weapon_manager.gd**

在 `scripts/entities/weapons/weapon_manager.gd` 中:
- 修改 `initialize()` 签名 (line 8):
  ```gdscript
  func initialize(weapon_entries: Array[Dictionary]) -> void:
      for entry in weapon_entries:
          if not GameConfig.weapons.has(entry.id):
              push_error("未知武器: " + entry.id)
              continue
          var weapon: Weapon = _add_weapon(GameConfig.weapons[entry.id])
          weapon.set_level(entry.level)
  ```

- [ ] **Step 3: 修改 player.gd**

在 `scripts/entities/player.gd` 中:
- 修改武器初始化 (lines 29-33):
  ```gdscript
  _weapon_manager.initialize(GameData.deployed_weapons)
  ```
- 修改 `add_coins()` (lines 104-107): 删除 `GameData.add_xp(amount)` 调用

- [ ] **Step 4: 修改 scene_factory.gd**

在 `scripts/core/scene_factory.gd` 中:
- 修改 `create_tower()` 签名 (line 41): 接受 level 参数
  ```gdscript
  func create_tower(type: String, level: int = 1) -> Node2D:
  ```
- 创建后设置 `tower.current_level = level`
- 删除 `get_tower_cost()` 函数 (lines 53-60)

- [ ] **Step 5: 修改 tower.gd**

在 `scripts/entities/towers/tower.gd` 中:
- 新增变量: `var current_level: int = 1`（不再从 `GameData.owned_towers` 读取）
- 删除监听 `EventBus.tower_upgraded` 的代码（该信号已删除）
- `_apply_level_stats()` 中使用 `current_level` 而非从 GameData 读取
- 等级在 SceneFactory 创建时通过 `tower.current_level = level` 注入

- [ ] **Step 6: Commit**

```bash
git add scripts/entities/weapons/weapon.gd scripts/entities/weapons/weapon_manager.gd scripts/entities/player.gd scripts/core/scene_factory.gd scripts/entities/towers/tower.gd
git commit -m "refactor: 武器/塔系统适配新数据结构（level 注入、删除 get_tower_cost）"
```

---

### Task 10: main.gd 战斗场景对接

**Files:**
- Modify: `scripts/ui/main.gd`
- Modify: `scripts/core/scene_manager.gd`

- [ ] **Step 1: 修改 SceneManager**

在 `scripts/core/scene_manager.gd` 中:
- 删除 placement 路由 (从 SCENES dict)
- 新增: `"shop": "res://scenes/ui/shop.tscn"`
- 在 SCENE_BGM 映射中: 删除 placement, 新增 `"shop": "placement"`

- [ ] **Step 2: 修改 main.gd**

在 `scripts/ui/main.gd` 中:

**删除:**
- `_show_upgrade_popup()` 方法及相关变量
- `UpgradePopup` 引用
- `pending_upgrades` 检查

**修改 `_restore_towers()`** (lines 31-38):
```gdscript
func _restore_towers() -> void:
	for tower_entry in GameData.deployed_towers:
		var tower: Node2D = SceneFactory.create_tower(tower_entry.id, tower_entry.level)
		tower.global_position = _grid_to_world(tower_entry.grid_pos)
		_tower_container.add_child(tower)
```

**修改波次结束处理:**
```gdscript
func _on_wave_transition_ready() -> void:
	SceneManager.go_to("shop")
```

**修改 `_on_coins_generated()`** (lines 62-68): 删除 `GameData.add_xp(amount)` 调用

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/main.gd scripts/core/scene_manager.gd
git commit -m "refactor: main.gd 对接新系统 — 删升级弹窗, 波次结束跳商店"
```

---

### Task 11: 清理旧系统

**Files:**
- Delete: `scripts/systems/upgrade_generator.gd`
- Delete: `scripts/ui/upgrade_popup.gd`
- Delete: `scenes/ui/upgrade_popup.tscn` (如果存在)
- Delete: `scripts/ui/placement.gd`
- Delete: `scripts/ui/placement_panel.gd`
- Delete: `scenes/levels/placement.tscn`
- Delete: `tests/unit/test_upgrade_generator.gd`
- Delete: `tests/unit/test_placement_panel.gd`
- Delete: `tests/unit/test_game_data_xp.gd`

- [ ] **Step 1: 删除旧文件**

```bash
git rm scripts/systems/upgrade_generator.gd
git rm scripts/ui/upgrade_popup.gd
git rm scenes/ui/upgrade_popup.tscn 2>/dev/null || true
git rm scripts/ui/placement.gd
git rm scripts/ui/placement_panel.gd
git rm scenes/levels/placement.tscn
git rm tests/unit/test_upgrade_generator.gd
git rm tests/unit/test_placement_panel.gd
git rm tests/unit/test_game_data_xp.gd
```

- [ ] **Step 2: 搜索并修复残留引用**

搜索所有对已删除文件/API 的引用，逐一修复或删除。

全局搜索关键词:
- `add_xp` — 确保所有调用点已删除（player.gd, main.gd, 其他）
- `owned_weapons` / `owned_towers` — 改为新 API
- `tower_inventory` — 改为 deployed_towers
- `pending_upgrades` / `current_xp` / `current_level`（旧 XP 系统）
- `UpgradePopup` / `upgrade_popup` / `UpgradeGenerator`
- `placement_panel` / `PlacementPanel`
- `get_tower_cost` / `place_cost_per_level`
- `tower_upgraded` / `tower_purchased` / `player_leveled_up` / `xp_changed`（已删信号）
- `.godot/global_script_class_cache.cfg` 中清理 `UpgradeGenerator` 条目

- [ ] **Step 3: 运行完整测试**

Run: 完整测试命令
Expected: 所有新测试通过，无编译错误

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: 删除旧系统（upgrade_popup, placement, XP, upgrade_generator）"
```

---

## Chunk 5: 商店场景 UI

### Task 12: 商店场景基础框架

**Files:**
- Create: `scenes/ui/shop.tscn`
- Create: `scripts/ui/shop.gd`

- [ ] **Step 1: 创建 shop 场景**

使用 MCP 工具 `create_scene` 创建 `scenes/ui/shop.tscn`，根节点 Control (name="Shop")。

场景树结构:
```
Shop (Control, 全屏)
├── TopBar (HBoxContainer) — 金币、等级、人口、波次、按钮
├── ShopBar (HBoxContainer) — 4 个商店栏位 + 刷新按钮
├── MainArea (HSplitContainer)
│   ├── EquipPanel (VBoxContainer) — 角色头像 + 武器槽
│   └── MapArea (Control) — 地图网格布置区
└── BagBar (HBoxContainer) — 10 个背包格 + 卖出区
```

- [ ] **Step 2: 创建 shop.gd 控制器**

```gdscript
# scripts/ui/shop.gd
extends Control

var _shop_manager: ShopManager = ShopManager.new()

@onready var _coins_label: Label = %CoinsLabel
@onready var _level_label: Label = %LevelLabel
@onready var _pop_label: Label = %PopLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _level_up_button: Button = %LevelUpButton
@onready var _start_button: Button = %StartButton
@onready var _refresh_button: Button = %RefreshButton

func _ready() -> void:
	_shop_manager.refresh_shop(GameData.is_first_shop_visit)
	GameData.is_first_shop_visit = false
	_update_ui()
	_start_button.pressed.connect(_on_start_pressed)
	_level_up_button.pressed.connect(_on_level_up_pressed)
	_refresh_button.pressed.connect(_on_refresh_pressed)

func _update_ui() -> void:
	_coins_label.text = "%d" % GameData.coins
	_level_label.text = "Lv%d" % GameData.player_level
	_pop_label.text = "%d/%d" % [GameData.get_population_used(), GameData.get_population_cap()]
	_wave_label.text = "第 %d 波" % (GameData.current_wave + 1)
	_update_level_up_button()
	_update_shop_slots()
	_update_bag()

func _update_level_up_button() -> void:
	if GameData.player_level >= 7:
		_level_up_button.text = "满级"
		_level_up_button.disabled = true
	else:
		var cost: int = GameConfig.shop_config.level_up_costs[GameData.player_level - 1]
		_level_up_button.text = "升本 %d💰 → Lv%d" % [cost, GameData.player_level + 1]
		_level_up_button.disabled = GameData.coins < cost

func _on_start_pressed() -> void:
	SceneManager.go_to("main")

func _on_level_up_pressed() -> void:
	if GameData.buy_level_up():
		_update_ui()

func _on_refresh_pressed() -> void:
	if _shop_manager.manual_refresh():
		_update_ui()

func _update_shop_slots() -> void:
	pass  # 由 ShopPanel 组件实现

func _update_bag() -> void:
	pass  # 由 BagPanel 组件实现
```

- [ ] **Step 3: 挂载脚本到场景**

使用 MCP `attach_script` 将 `scripts/ui/shop.gd` 挂到 Shop 节点。

- [ ] **Step 4: Commit**

```bash
git add scenes/ui/shop.tscn scripts/ui/shop.gd
git commit -m "feat: 商店场景基础框架（顶栏、商店栏、地图区、背包栏）"
```

---

### Task 13: 商店栏 UI 组件

**Files:**
- Create: `scripts/ui/shop_panel.gd`

- [ ] **Step 1: 实现 ShopPanel**

```gdscript
# scripts/ui/shop_panel.gd
extends HBoxContainer

signal item_bought(slot_index: int)

var _slot_buttons: Array[Button] = []

func setup(shop_slots: Array[Dictionary]) -> void:
	_clear_slots()
	for i in shop_slots.size():
		var slot: Dictionary = shop_slots[i]
		var btn: Button = Button.new()
		if slot.is_empty():
			btn.text = "已购买"
			btn.disabled = true
		else:
			var data: Resource = _get_item_data(slot.id)
			btn.text = "%s\n%d💰" % [data.display_name, slot.cost]
			btn.disabled = GameData.coins < slot.cost or not GameData.can_buy()
			var idx: int = i
			btn.pressed.connect(func(): item_bought.emit(idx))
		btn.custom_minimum_size = Vector2(120, 60)
		_slot_buttons.append(btn)
		add_child(btn)

func _clear_slots() -> void:
	for btn in _slot_buttons:
		btn.queue_free()
	_slot_buttons.clear()

func _get_item_data(item_id: String) -> Resource:
	if GameConfig.weapons.has(item_id):
		return GameConfig.weapons[item_id]
	return GameConfig.towers[item_id]
```

- [ ] **Step 2: 连接到 shop.gd**

在 `shop.gd` 中添加 `@onready var _shop_panel: ShopPanel = %ShopPanel`，连接 `item_bought` 信号:

```gdscript
func _on_item_bought(slot_index: int) -> void:
	if _shop_manager.buy_item(slot_index):
		_update_ui()
```

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/shop_panel.gd scripts/ui/shop.gd
git commit -m "feat: ShopPanel 商店栏 UI 组件"
```

---

### Task 14: 背包栏 UI 组件

**Files:**
- Create: `scripts/ui/bag_panel.gd`

- [ ] **Step 1: 实现 BagPanel**

```gdscript
# scripts/ui/bag_panel.gd
extends HBoxContainer

signal item_selected(bag_index: int)
signal item_sell_requested(bag_index: int)

var _slot_buttons: Array[Button] = []
var _selected_index: int = -1

func setup(bag: Array[Dictionary]) -> void:
	_clear_slots()
	var config: ShopConfig = GameConfig.shop_config
	for i in config.bag_capacity:
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(72, 72)
		if i < bag.size():
			var item: Dictionary = bag[i]
			var data: Resource = _get_item_data(item.id)
			var stars: String = "★".repeat(item.level)
			btn.text = "%s\n%s" % [data.display_name, stars]
			var idx: int = i
			btn.pressed.connect(func(): _on_slot_pressed(idx))
			btn.gui_input.connect(func(event: InputEvent): _on_slot_input(event, idx))
		else:
			btn.text = ""
			btn.disabled = true
		_slot_buttons.append(btn)
		add_child(btn)

func _on_slot_pressed(index: int) -> void:
	_selected_index = index
	item_selected.emit(index)

func _on_slot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		item_sell_requested.emit(index)

func _clear_slots() -> void:
	for btn in _slot_buttons:
		btn.queue_free()
	_slot_buttons.clear()

func _get_item_data(item_id: String) -> Resource:
	if GameConfig.weapons.has(item_id):
		return GameConfig.weapons[item_id]
	return GameConfig.towers[item_id]
```

- [ ] **Step 2: 连接到 shop.gd**

在 `shop.gd` 中连接信号:

```gdscript
func _on_bag_item_selected(bag_index: int) -> void:
	var item: Dictionary = GameData.bag[bag_index]
	if item.type == "weapon":
		if GameData.deploy_weapon(bag_index):
			_update_ui()
	# tower 需要拖拽到地图，后续实现

func _on_bag_item_sell(bag_index: int) -> void:
	if bag_index >= GameData.bag.size():
		return
	GameData.sell_from_bag(bag_index)
	_update_ui()
```

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/bag_panel.gd scripts/ui/shop.gd
git commit -m "feat: BagPanel 背包栏 UI 组件（选择、右键卖出）"
```

---

### Task 15: 装备栏 UI 组件

**Files:**
- Create: `scripts/ui/equip_panel.gd`

- [ ] **Step 1: 实现 EquipPanel**

```gdscript
# scripts/ui/equip_panel.gd
extends VBoxContainer

signal weapon_unequipped(deploy_index: int)
signal weapon_sell_requested(deploy_index: int)

var _weapon_buttons: Array[Button] = []

func setup(deployed_weapons: Array[Dictionary]) -> void:
	_clear_weapons()
	for i in deployed_weapons.size():
		var entry: Dictionary = deployed_weapons[i]
		var wd: WeaponData = GameConfig.weapons[entry.id]
		var stars: String = "★".repeat(entry.level)
		var btn: Button = Button.new()
		btn.text = "%s %s" % [wd.display_name, stars]
		btn.custom_minimum_size = Vector2(100, 36)
		var idx: int = i
		btn.pressed.connect(func(): weapon_unequipped.emit(idx))
		btn.gui_input.connect(func(event: InputEvent): _on_weapon_input(event, idx))
		_weapon_buttons.append(btn)
		add_child(btn)

func _on_weapon_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		weapon_sell_requested.emit(index)

func _clear_weapons() -> void:
	for btn in _weapon_buttons:
		btn.queue_free()
	_weapon_buttons.clear()
```

- [ ] **Step 2: 连接到 shop.gd**

```gdscript
func _on_weapon_unequipped(deploy_index: int) -> void:
	GameData.undeploy_weapon(deploy_index)
	_update_ui()

func _on_weapon_sell(deploy_index: int) -> void:
	GameData.sell_from_deployed_weapon(deploy_index)
	_update_ui()
```

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/equip_panel.gd scripts/ui/shop.gd
git commit -m "feat: EquipPanel 角色装备栏 UI（展示已装备武器、点击卸下）"
```

---

### Task 16: 地图布置区

**Files:**
- Modify: `scripts/ui/shop.gd`

- [ ] **Step 1: 实现塔布置逻辑**

在 `scripts/ui/shop.gd` 中添加地图布置功能:
- 复用现有的网格对齐逻辑（从 placement.gd 参考）
- 背包中选择塔 → 点击地图格子 → `GameData.deploy_tower(bag_index, grid_pos)`
- 地图上的塔点击 → `GameData.undeploy_tower(deploy_index)` 回收到背包
- 预览显示（半透明跟随鼠标）
- 位置验证（不重叠、不越界）

关键代码:
```gdscript
# 注意：初版使用点击交互（点击背包武器自动装备，点击背包塔进入布置模式，点击地图放置）
# 拖拽交互作为后续迭代优化
var _placing_tower_index: int = -1  # 正在布置的背包 index

func _on_bag_item_selected(bag_index: int) -> void:
	var item: Dictionary = GameData.bag[bag_index]
	if item.type == "weapon":
		if GameData.deploy_weapon(bag_index):
			_update_ui()
	elif item.type == "tower":
		_placing_tower_index = bag_index
		# 进入塔布置模式，鼠标跟随预览

func _on_map_clicked(grid_pos: Vector2i) -> void:
	if _placing_tower_index >= 0:
		if GameData.deploy_tower(_placing_tower_index, grid_pos):
			_placing_tower_index = -1
			_update_ui()
```

- [ ] **Step 2: 渲染已布置的塔**

在 `_update_ui()` 中根据 `GameData.deployed_towers` 渲染塔的预览图标到地图网格上。

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/shop.gd
git commit -m "feat: 商店场景地图布置区（塔拖放、预览、位置验证）"
```

---

## Chunk 6: 集成测试与收尾

### Task 17: enemy.gd 清理

**Files:**
- Modify: `scripts/entities/enemy.gd`

- [ ] **Step 1: 清理 XP 相关代码**

在 `scripts/entities/enemy.gd` 中:
- `_drop_coins()` 不需要改动（金币掉落本身不触发 XP，是 player.add_coins 调 add_xp 的，已在 Task 9 删除）
- 搜索并删除任何直接引用 `GameData.add_xp` 的代码

- [ ] **Step 2: Commit**

```bash
git add scripts/entities/enemy.gd
git commit -m "chore: enemy.gd 清理 XP 相关引用"
```

---

### Task 18: HUD 清理

**Files:**
- Modify: `scripts/ui/hud.gd`

- [ ] **Step 1: 删除 XP 相关 UI**

在 `scripts/ui/hud.gd` 中:
- 删除经验值条/文字显示
- 删除监听 `EventBus.xp_changed` 和 `EventBus.player_leveled_up` 的代码
- 保留金币显示

- [ ] **Step 2: Commit**

```bash
git add scripts/ui/hud.gd
git commit -m "chore: HUD 删除 XP/升级 UI 元素"
```

---

### Task 19: 完整集成测试

**Files:**
- All

- [ ] **Step 1: 运行完整测试套件**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

- [ ] **Step 2: 修复所有失败测试**

逐一排查失败测试:
- 引用 `owned_weapons`/`owned_towers` 的测试 → 改为新 API
- 引用 `add_xp`/`pending_upgrades` 的测试 → 删除或重写
- 引用 `place_cost` 的测试 → 删除
- 引用 `get_tower_cost` 的测试 → 删除

- [ ] **Step 3: 在编辑器中运行项目**

使用 MCP `play_scene` 运行项目，验证:
1. 角色选择 → 地图选择 → 进入商店（非 placement）
2. 商店显示 4 个物品，包含推荐武器/塔
3. 购买物品进入背包
4. 从背包装备武器/布置塔
5. 合成触发正确
6. 开始战斗正常
7. 波次结束返回商店

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test: 修复集成测试适配新经济系统"
```

---

### Task 20: 最终清理和文档

- [ ] **Step 1: 更新 MEMORY.md**

更新 memory 中的系统描述:
- GameData 部分更新为新 API
- 删除 UpgradeGenerator 相关记录
- 新增 ShopManager、ShopConfig 说明

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "docs: 更新项目记忆文档适配新经济系统"
```
