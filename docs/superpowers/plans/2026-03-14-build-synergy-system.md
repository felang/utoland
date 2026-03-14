# 构筑协同系统实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现标签羁绊系统（5 标签 × 2/3/5 三档）、6 对手工配对协同、5 个角色被动重设计，替换旧被动系统。

**Architecture:** 数据层新增 Tag 枚举和 Resource 字段 → SynergyManager（RefCounted，纯计算）计算标签计数和羁绊档位 → SynergyEffectProcessor（Node，挂在战斗场景下）处理需要计时器的羁绊效果（狂热、轰炸等） → PairSynergyManager（RefCounted）检测配对协同 → 旧 PassiveType 系统完全移除并替换为新被动。

**关键架构约束：** SynergyManager 和 PairSynergyManager 作为 RefCounted 不能使用 Timer/_process，所有需要帧更新或计时的效果由 SynergyEffectProcessor（Node）处理。SynergyEffectProcessor 在 main 战斗场景 _ready() 中创建并 add_child，战斗结束时销毁。

**Tech Stack:** Godot 4.6 / GDScript / GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-14-build-synergy-system-design.md`

---

## File Structure

### 新增文件
| 文件 | 职责 |
|------|------|
| `scripts/systems/synergy_manager.gd` | 标签计数、羁绊档位计算、2 档数值加成查询 (RefCounted) |
| `scripts/systems/synergy_effect_processor.gd` | 需要计时器的羁绊效果处理（狂热、轰炸、护盾冷却等），挂在战斗场景下 (Node) |
| `scripts/systems/pair_synergy_manager.gd` | 6 对配对协同检测与效果管理 (RefCounted) |
| `scripts/resources/synergy_data.gd` | 羁绊效果配置 Resource（每个标签的 2/3/5 档效果数据） |
| `resources/synergies/assault.tres` | 猛攻羁绊配置 |
| `resources/synergies/control.tres` | 控制羁绊配置 |
| `resources/synergies/blast.tres` | 爆破羁绊配置 |
| `resources/synergies/fortify.tres` | 坚守羁绊配置 |
| `resources/synergies/boost.tres` | 增益羁绊配置 |
| `tests/unit/test_synergy_manager.gd` | SynergyManager 单元测试 |
| `tests/unit/test_pair_synergy.gd` | 配对协同单元测试 |
| `tests/unit/test_new_passives.gd` | 新角色被动单元测试 |

### 修改文件
| 文件 | 修改内容 |
|------|----------|
| `scripts/core/enums.gd` | 新增 Tag 常量类，删除 PassiveType 类 |
| `scripts/resources/character_data.gd` | 新增 `tag` 字段，替换 `passive_type/passive_value` 为新被动字段 |
| `scripts/resources/weapon_data.gd` | 新增 `tag` 字段 |
| `scripts/resources/tower_data.gd` | 新增 `tag` 字段 |
| `scripts/core/game_data.gd` | 新增羁绊状态字段，替换旧被动初始化逻辑，`deploy/undeploy` 触发羁绊重算 |
| `scripts/core/event_bus.gd` | 新增羁绊/协同信号 |
| `scripts/entities/player.gd` | 替换旧被动消费代码为新被动实现 |
| `scripts/entities/towers/tower.gd` | 替换旧被动消费代码，接入羁绊效果 |
| `scripts/entities/weapons/weapon.gd` | 替换旧被动消费代码，接入羁绊效果 |
| `scripts/entities/enemy.gd` | 移除 `coin_drop_mult` 引用 |
| `scripts/core/game_config.gd` | 加载 synergy .tres 配置 |
| `resources/characters/*.tres` (5 个) | 更新 tag 和新被动字段值 |
| `resources/weapons/*.tres` (10 个) | 新增 tag 字段值 |
| `resources/towers/*.tres` (15 个) | 新增 tag 字段值，bamboo rarity 改为 1 |
| `tests/unit/test_character_passive.gd` | 重写为新被动测试 |
| `tests/unit/test_game_data_economy.gd` | 更新受影响的测试 |
| `.godot/global_script_class_cache.cfg` | 注册新 class_name |

---

## Chunk 1: 数据基础层

### Task 1: Tag 枚举与 Resource 字段

**Files:**
- Modify: `scripts/core/enums.gd`
- Modify: `scripts/resources/weapon_data.gd`
- Modify: `scripts/resources/tower_data.gd`
- Modify: `scripts/resources/character_data.gd`

- [ ] **Step 1: 在 enums.gd 中添加 Tag 常量类**

在 `scripts/core/enums.gd` 中添加 Tag 类（保留旧 PassiveType 暂不删除，后续 Task 删除）：

```gdscript
class Tag:
	const ASSAULT = "assault"
	const CONTROL = "control"
	const BLAST = "blast"
	const FORTIFY = "fortify"
	const BOOST = "boost"

	const ALL = [ASSAULT, CONTROL, BLAST, FORTIFY, BOOST]
```

- [ ] **Step 2: 在 WeaponData 中添加 tag 字段**

在 `scripts/resources/weapon_data.gd` 的 `@export` 区域添加：

```gdscript
@export var tag: String = ""
```

- [ ] **Step 3: 在 TowerData 中添加 tag 字段**

在 `scripts/resources/tower_data.gd` 的 `@export` 区域添加：

```gdscript
@export var tag: String = ""
```

- [ ] **Step 4: 在 CharacterData 中添加 tag 和新被动字段**

在 `scripts/resources/character_data.gd` 中：
1. 添加 `tag` 字段
2. 添加新被动字段（替代旧 passive_type/passive_value，但旧字段暂保留）

```gdscript
@export var tag: String = ""
@export var new_passive_id: String = ""  # 新被动标识：swift_combo / field_master / blood_rage / fortify_regen / amplify_field
@export var new_passive_value: float = 0.0  # 被动数值参数
@export var new_passive_value_2: float = 0.0  # 第二数值参数（如 Dora 回复翻倍阈值）
```

- [ ] **Step 5: 提交**

```bash
git add scripts/core/enums.gd scripts/resources/weapon_data.gd scripts/resources/tower_data.gd scripts/resources/character_data.gd
git commit -m "feat: 新增 Tag 枚举和 Resource tag 字段"
```

### Task 2: 更新所有 .tres 配置文件

**Files:**
- Modify: `resources/weapons/*.tres` (10 个)
- Modify: `resources/towers/*.tres` (15 个)
- Modify: `resources/characters/*.tres` (5 个)

- [ ] **Step 1: 更新武器 .tres 文件添加 tag**

按照 spec 标签分配，为每个武器 .tres 添加 `tag = "xxx"`：

| 文件 | tag 值 |
|------|--------|
| `resources/weapons/rifle.tres` | `"assault"` |
| `resources/weapons/shotgun.tres` | `"assault"` |
| `resources/weapons/minigun.tres` | `"assault"` |
| `resources/weapons/ice_gun.tres` | `"control"` |
| `resources/weapons/boomerang.tres` | `"control"` |
| `resources/weapons/rocket.tres` | `"blast"` |
| `resources/weapons/lightning.tres` | `"blast"` |
| `resources/weapons/blade.tres` | `"fortify"` |
| `resources/weapons/flamethrower.tres` | `"fortify"` |
| `resources/weapons/laser.tres` | `"boost"` |

- [ ] **Step 2: 更新塔 .tres 文件添加 tag，bamboo rarity 改为 1**

| 文件 | tag 值 | 额外修改 |
|------|--------|----------|
| `resources/towers/cactus.tres` | `"assault"` | |
| `resources/towers/rose.tres` | `"assault"` | |
| `resources/towers/ice_flower.tres` | `"control"` | |
| `resources/towers/vine.tres` | `"control"` | |
| `resources/towers/dandelion.tres` | `"control"` | |
| `resources/towers/bamboo.tres` | `"blast"` | `rarity = 1` (从 2 改为 1) |
| `resources/towers/mushroom.tres` | `"blast"` | |
| `resources/towers/pitcher.tres` | `"blast"` | |
| `resources/towers/stump.tres` | `"fortify"` | |
| `resources/towers/oak.tres` | `"fortify"` | |
| `resources/towers/heal_flower.tres` | `"fortify"` | |
| `resources/towers/sunflower.tres` | `"boost"` | |
| `resources/towers/mint.tres` | `"boost"` | |
| `resources/towers/thorn.tres` | `"boost"` | |
| `resources/towers/pea_shooter.tres` | `"boost"` | |

- [ ] **Step 3: 更新角色 .tres 文件添加 tag 和新被动字段**

| 文件 | tag | new_passive_id | new_passive_value | new_passive_value_2 |
|------|-----|----------------|-------------------|---------------------|
| `resources/characters/kaze.tres` | `"assault"` | `"swift_combo"` | `0.05` (每次叠加 5%) | `0.3` (最高 30%) |
| `resources/characters/nemo.tres` | `"control"` | `"field_master"` | `0.3` (范围 +30%) | `0.0` |
| `resources/characters/gorg.tres` | `"blast"` | `"blood_rage"` | `0.05` (每 10% 生命 +5%) | `0.5` (最高 +50%) |
| `resources/characters/dora.tres` | `"fortify"` | `"fortify_regen"` | `0.02` (每 5 秒 2% 回复) | `3.0` (≥3 坚守单位翻倍) |
| `resources/characters/merlin.tres` | `"boost"` | `"amplify_field"` | `0.4` (范围 +40%) | `0.0` |

- [ ] **Step 4: 提交**

```bash
git add resources/weapons/ resources/towers/ resources/characters/
git commit -m "feat: 为所有武器/塔/角色配置 tag 标签和新被动参数"
```

### Task 3: 更新 global_script_class_cache.cfg

**Files:**
- Modify: `.godot/global_script_class_cache.cfg`

- [ ] **Step 1: 运行后续 Task 创建 class_name 脚本后统一更新**

此步骤在 Task 4 创建 SynergyData 后执行。暂时跳过。

---

## Chunk 2: SynergyManager 核心

### Task 4: SynergyData Resource 类

**Files:**
- Create: `scripts/resources/synergy_data.gd`
- Create: `resources/synergies/*.tres` (5 个)
- Modify: `scripts/core/game_config.gd`

- [ ] **Step 1: 创建 SynergyData Resource 类**

创建 `scripts/resources/synergy_data.gd`：

```gdscript
class_name SynergyData
extends Resource

# 标签标识
@export var tag: String = ""
@export var display_name: String = ""

# 各档位触发所需数量
@export var tier_thresholds: PackedInt32Array = PackedInt32Array([2, 3, 5])

# 2 档效果参数（纯数值加成）
@export var tier2_stat: String = ""  # 加成属性名：damage_mult / control_duration / aoe_range / max_hp / boost_strength
@export var tier2_value: float = 0.0  # 加成值

# 3 档效果参数（机制型）
@export var tier3_id: String = ""  # 机制标识：frenzy / vulnerable / chain_blast / emergency_shield / self_boost
@export var tier3_value: float = 0.0  # 机制参数 1
@export var tier3_value_2: float = 0.0  # 机制参数 2
@export var tier3_duration: float = 0.0  # 持续时间

# 5 档效果参数（终极机制型）
@export var tier5_id: String = ""  # 机制标识：overkill / chain_freeze / tactical_bomb / undying / global_boost
@export var tier5_value: float = 0.0
@export var tier5_value_2: float = 0.0
@export var tier5_duration: float = 0.0
```

- [ ] **Step 2: 创建 5 个 synergy .tres 配置文件**

创建 `resources/synergies/` 目录，然后创建每个标签的配置：

**`resources/synergies/assault.tres`:**
```
[gd_resource type="Resource" script_class="SynergyData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/synergy_data.gd" id="1"]
[resource]
script = ExtResource("1")
tag = "assault"
display_name = "猛攻"
tier_thresholds = PackedInt32Array(2, 3, 5)
tier2_stat = "damage_mult"
tier2_value = 0.15
tier3_id = "frenzy"
tier3_value = 2.0
tier3_value_2 = 0.0
tier3_duration = 3.0
tier5_id = "overkill"
tier5_value = 0.3
tier5_value_2 = 0.0
tier5_duration = 0.0
```

**`resources/synergies/control.tres`:**
```
tag = "control", display_name = "控制"
tier2_stat = "control_duration", tier2_value = 0.25
tier3_id = "vulnerable", tier3_value = 0.2, tier3_duration = 0.0
tier5_id = "chain_freeze", tier5_value = 1.0 (冻结秒数), tier5_duration = 0.0
```

**`resources/synergies/blast.tres`:**
```
tag = "blast", display_name = "爆破"
tier2_stat = "aoe_range", tier2_value = 0.2
tier3_id = "chain_blast", tier3_value = 0.15 (几率), tier3_value_2 = 0.5 (伤害比)
tier5_id = "tactical_bomb", tier5_value = 15.0 (间隔秒), tier5_value_2 = 3.0 (目标数)
```

**`resources/synergies/fortify.tres`:**
```
tag = "fortify", display_name = "坚守"
tier2_stat = "max_hp", tier2_value = 0.2
tier3_id = "emergency_shield", tier3_value = 0.3 (血量阈值), tier3_duration = 3.0 (护盾持续), tier3_value_2 = 10.0 (冷却)
tier5_id = "undying", tier5_value = 5.0 (复活延迟秒), tier5_value_2 = 0.5 (恢复血量比)
```

**`resources/synergies/boost.tres`:**
```
tag = "boost", display_name = "增益"
tier2_stat = "boost_strength", tier2_value = 0.25
tier3_id = "self_boost", tier3_value = 0.0
tier5_id = "global_boost", tier5_value = 0.0
```

- [ ] **Step 3: 在 GameConfig 中注册加载 synergy 配置**

在 `scripts/core/game_config.gd` 中添加：

```gdscript
var synergies: Dictionary = {}  # tag -> SynergyData

func _load_synergies() -> void:
	var dir = DirAccess.open("res://resources/synergies")
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var synergy = load("res://resources/synergies/" + file_name) as SynergyData
			if synergy:
				synergies[synergy.tag] = synergy
		file_name = dir.get_next()
```

在 `_ready()` 中调用 `_load_synergies()`。

- [ ] **Step 4: 更新 global_script_class_cache.cfg**

为 `SynergyData` 添加条目。

- [ ] **Step 5: 提交**

```bash
git add scripts/resources/synergy_data.gd resources/synergies/ scripts/core/game_config.gd .godot/global_script_class_cache.cfg
git commit -m "feat: SynergyData Resource 类和 5 个标签配置"
```

### Task 5: EventBus 新增羁绊信号

**Files:**
- Modify: `scripts/core/event_bus.gd`

- [ ] **Step 1: 添加羁绊和协同相关信号**

在 `scripts/core/event_bus.gd` 中添加：

```gdscript
# 羁绊信号
signal synergy_changed(tag: String, old_tier: int, new_tier: int)  # 羁绊档位变化
signal synergy_effect_triggered(tag: String, effect_id: String)  # 机制型效果触发（用于 UI 反馈）

# 配对协同信号
signal pair_synergy_activated(synergy_id: String)  # 配对协同激活
signal pair_synergy_deactivated(synergy_id: String)  # 配对协同失效
```

- [ ] **Step 2: 提交**

```bash
git add scripts/core/event_bus.gd
git commit -m "feat: EventBus 新增羁绊和配对协同信号"
```

### Task 6: GameData 羁绊状态字段

**Files:**
- Modify: `scripts/core/game_data.gd`

- [ ] **Step 1: 添加羁绊状态字段**

在 `scripts/core/game_data.gd` 中添加变量：

```gdscript
# 羁绊状态
var synergy_tag_counts: Dictionary = {}  # {tag: int} 当前各标签计数
var synergy_active_tiers: Dictionary = {}  # {tag: int} 当前各标签激活的档位 (0/2/3/5)
var active_pair_synergies: Array[String] = []  # 当前激活的配对协同 ID 列表
```

- [ ] **Step 2: 在 reset() 中初始化羁绊状态**

在 `reset()` 方法中添加：

```gdscript
synergy_tag_counts = {}
synergy_active_tiers = {}
active_pair_synergies = []
```

- [ ] **Step 3: 提交**

```bash
git add scripts/core/game_data.gd
git commit -m "feat: GameData 新增羁绊状态字段"
```

### Task 7: SynergyManager 核心逻辑

**Files:**
- Create: `scripts/systems/synergy_manager.gd`
- Test: `tests/unit/test_synergy_manager.gd`

- [ ] **Step 1: 编写 SynergyManager 失败测试**

创建 `tests/unit/test_synergy_manager.gd`：

```gdscript
extends GutTest

var manager: SynergyManager

func before_each():
	GameData.reset()
	manager = SynergyManager.new()

func test_count_tags_empty():
	# 没有部署任何单位，所有标签计数为 0
	var counts = manager.count_tags()
	assert_eq(counts.size(), 0, "空部署应无标签计数")

func test_count_tags_with_character():
	# 角色贡献 1 个标签
	GameData.current_character = "kaze"
	var counts = manager.count_tags()
	assert_eq(counts.get("assault", 0), 1, "Kaze 应贡献 1 个猛攻标签")

func test_count_tags_with_deployed_weapons():
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [
		{id = "rifle", level = 1},
		{id = "minigun", level = 2}
	]
	var counts = manager.count_tags()
	assert_eq(counts.get("assault", 0), 3, "Kaze + rifle + minigun = 3 猛攻")

func test_count_tags_with_deployed_towers():
	GameData.current_character = "merlin"
	GameData.deployed_towers = [
		{id = "sunflower", level = 1, grid_pos = Vector2i(0, 0)},
		{id = "mint", level = 1, grid_pos = Vector2i(1, 0)}
	]
	var counts = manager.count_tags()
	assert_eq(counts.get("boost", 0), 3, "Merlin + sunflower + mint = 3 增益")

func test_count_tags_mixed():
	GameData.current_character = "nemo"
	GameData.deployed_weapons = [{id = "ice_gun", level = 1}]
	GameData.deployed_towers = [
		{id = "ice_flower", level = 1, grid_pos = Vector2i(0, 0)},
		{id = "stump", level = 1, grid_pos = Vector2i(1, 0)}
	]
	var counts = manager.count_tags()
	assert_eq(counts.get("control", 0), 3, "Nemo + ice_gun + ice_flower = 3 控制")
	assert_eq(counts.get("fortify", 0), 1, "stump = 1 坚守")

func test_calculate_tier_none():
	assert_eq(manager._calculate_tier(0), 0, "0 个单位 = 0 档")
	assert_eq(manager._calculate_tier(1), 0, "1 个单位 = 0 档")

func test_calculate_tier_2():
	assert_eq(manager._calculate_tier(2), 2, "2 个单位 = 2 档")

func test_calculate_tier_3():
	assert_eq(manager._calculate_tier(3), 3, "3 个单位 = 3 档")
	assert_eq(manager._calculate_tier(4), 3, "4 个单位 = 3 档")

func test_calculate_tier_5():
	assert_eq(manager._calculate_tier(5), 5, "5 个单位 = 5 档")
	assert_eq(manager._calculate_tier(6), 5, "6 个单位 = 5 档")

func test_recalculate_synergies_emits_signal():
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [{id = "rifle", level = 1}]
	watch_signals(EventBus)
	manager.recalculate()
	assert_signal_emitted(EventBus, "synergy_changed")

func test_recalculate_updates_game_data():
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [
		{id = "rifle", level = 1},
		{id = "minigun", level = 1}
	]
	manager.recalculate()
	assert_eq(GameData.synergy_tag_counts.get("assault", 0), 3)
	assert_eq(GameData.synergy_active_tiers.get("assault", 0), 3)

func test_upgrade_does_not_double_count():
	# Lv3 单位仍只算 1 个标签计数
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [{id = "rifle", level = 3}]
	var counts = manager.count_tags()
	assert_eq(counts.get("assault", 0), 2, "Lv3 rifle 仍只算 1 个猛攻")
```

- [ ] **Step 2: 运行测试确认失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_synergy_manager.gd -gexit
```

预期：FAIL（SynergyManager 类不存在）

- [ ] **Step 3: 实现 SynergyManager**

创建 `scripts/systems/synergy_manager.gd`：

```gdscript
class_name SynergyManager
extends RefCounted

# 标签查找表：unit_id -> tag（启动时由 GameConfig 构建）
var _tag_lookup: Dictionary = {}

func _init() -> void:
	_build_tag_lookup()

func _build_tag_lookup() -> void:
	# 从 GameConfig 的 weapons/towers/characters 构建 id->tag 映射
	for weapon_id in GameConfig.weapons:
		var data: WeaponData = GameConfig.weapons[weapon_id]
		if data.tag != "":
			_tag_lookup[weapon_id] = data.tag
	for tower_id in GameConfig.towers:
		var data: TowerData = GameConfig.towers[tower_id]
		if data.tag != "":
			_tag_lookup[tower_id] = data.tag
	for char_id in GameConfig.characters:
		var data: CharacterData = GameConfig.characters[char_id]
		if data.tag != "":
			_tag_lookup[char_id] = data.tag

# 计算当前部署的标签计数
func count_tags() -> Dictionary:
	var counts: Dictionary = {}

	# 角色贡献
	var char_tag = _tag_lookup.get(GameData.current_character, "")
	if char_tag != "":
		counts[char_tag] = counts.get(char_tag, 0) + 1

	# 已部署武器
	for weapon in GameData.deployed_weapons:
		var tag = _tag_lookup.get(weapon.id, "")
		if tag != "":
			counts[tag] = counts.get(tag, 0) + 1

	# 已部署塔
	for tower in GameData.deployed_towers:
		var tag = _tag_lookup.get(tower.id, "")
		if tag != "":
			counts[tag] = counts.get(tag, 0) + 1

	return counts

# 根据数量计算羁绊档位
func _calculate_tier(count: int) -> int:
	if count >= 5:
		return 5
	elif count >= 3:
		return 3
	elif count >= 2:
		return 2
	return 0

# 重算所有羁绊状态
func recalculate() -> void:
	var counts = count_tags()
	var old_tiers = GameData.synergy_active_tiers.duplicate()

	GameData.synergy_tag_counts = counts
	var new_tiers: Dictionary = {}

	for tag in Enums.Tag.ALL:
		var count = counts.get(tag, 0)
		var tier = _calculate_tier(count)
		if tier > 0:
			new_tiers[tag] = tier

	GameData.synergy_active_tiers = new_tiers

	# 发射变化信号
	for tag in Enums.Tag.ALL:
		var old_tier = old_tiers.get(tag, 0)
		var new_tier = new_tiers.get(tag, 0)
		if old_tier != new_tier:
			EventBus.synergy_changed.emit(tag, old_tier, new_tier)
```

- [ ] **Step 4: 运行测试确认通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_synergy_manager.gd -gexit
```

预期：全部 PASS

- [ ] **Step 5: 更新 global_script_class_cache.cfg 并提交**

```bash
git add scripts/systems/synergy_manager.gd tests/unit/test_synergy_manager.gd .godot/global_script_class_cache.cfg
git commit -m "feat: SynergyManager 标签计数和羁绊档位计算"
```

### Task 8: 在 GameData deploy/undeploy 中触发羁绊重算

**Files:**
- Modify: `scripts/core/game_data.gd`
- Modify: `tests/unit/test_game_data_economy.gd`

- [ ] **Step 1: 编写失败测试**

在 `tests/unit/test_game_data_economy.gd` 中添加：

```gdscript
func test_deploy_weapon_triggers_synergy_recalculate():
	GameData.reset()
	GameData.current_character = "kaze"
	GameData.coins = 100
	# 先将武器放入背包
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData.bag.append({id = "minigun", type = "weapon", level = 1})
	# 部署
	GameData.deploy_weapon(0)
	GameData.deploy_weapon(0)  # minigun 现在是 index 0
	assert_eq(GameData.synergy_active_tiers.get("assault", 0), 3, "Kaze + rifle + minigun = 3 档猛攻")

func test_undeploy_weapon_triggers_synergy_recalculate():
	GameData.reset()
	GameData.current_character = "kaze"
	GameData.coins = 100
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData.bag.append({id = "minigun", type = "weapon", level = 1})
	GameData.deploy_weapon(0)
	GameData.deploy_weapon(0)
	assert_eq(GameData.synergy_active_tiers.get("assault", 0), 3)
	# 卸下一把
	GameData.undeploy_weapon(0)
	assert_eq(GameData.synergy_active_tiers.get("assault", 0), 2, "卸下后降为 2 档")
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 在 GameData 中集成 SynergyManager**

在 `scripts/core/game_data.gd` 中：

```gdscript
var _synergy_manager: SynergyManager

func reset() -> void:
	# ... 现有 reset 代码 ...
	synergy_tag_counts = {}
	synergy_active_tiers = {}
	active_pair_synergies = []
	_synergy_manager = SynergyManager.new()
```

在 `deploy_weapon()`、`undeploy_weapon()`、`deploy_tower()`、`undeploy_tower()`、`sell_from_bag()`、`sell_from_deployed_weapon()`、`sell_from_deployed_tower()`、`_check_merge()` 的末尾添加：

```gdscript
_synergy_manager.recalculate()
```

注意：`init_character()` 中也需要在设置 `current_character` 后初始化 `_synergy_manager`。

- [ ] **Step 4: 运行测试确认通过**

- [ ] **Step 5: 运行全部测试确认无回归**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: 提交**

```bash
git add scripts/core/game_data.gd tests/unit/test_game_data_economy.gd
git commit -m "feat: deploy/undeploy 自动触发羁绊重算"
```

---

## Chunk 3: 羁绊效果实现（2 档数值加成）

### Task 9: 2 档羁绊效果 — 数值加成系统

**Files:**
- Modify: `scripts/systems/synergy_manager.gd`
- Modify: `scripts/entities/towers/tower.gd`
- Modify: `scripts/entities/weapons/weapon.gd`
- Test: `tests/unit/test_synergy_manager.gd`

2 档效果全部是数值加成，实现方式是通过已有的 buff 系统或伤害计算时读取 GameData 中的羁绊状态。

- [ ] **Step 1: 在 SynergyManager 中添加效果应用/移除方法**

扩展 `synergy_manager.gd`，在 `recalculate()` 中检测档位变化后应用/移除效果：

```gdscript
# 存储当前生效的 2 档加成
var _active_tier2_bonuses: Dictionary = {}  # {tag: {stat: value}}

func _apply_tier_effects(tag: String, tier: int) -> void:
	var synergy_data: SynergyData = GameConfig.synergies.get(tag)
	if not synergy_data:
		return

	# 2 档效果
	if tier >= 2:
		_active_tier2_bonuses[tag] = {
			"stat": synergy_data.tier2_stat,
			"value": synergy_data.tier2_value
		}
	else:
		_active_tier2_bonuses.erase(tag)

func _remove_tier_effects(tag: String) -> void:
	_active_tier2_bonuses.erase(tag)

# 查询某个标签的 2 档加成值
func get_tier2_bonus(stat: String) -> float:
	var total: float = 0.0
	for tag in _active_tier2_bonuses:
		var bonus = _active_tier2_bonuses[tag]
		if bonus.stat == stat:
			total += bonus.value
	return total

# 公共查询：获取单位标签
func get_tag(unit_id: String) -> String:
	return _tag_lookup.get(unit_id, "")

# 公共查询：获取指定单位的伤害倍率加成（来自羁绊 2 档）
func get_damage_mult_bonus(unit_id: String) -> float:
	var tag = _tag_lookup.get(unit_id, "")
	if tag == "" or GameData.synergy_active_tiers.get(tag, 0) < 2:
		return 0.0
	var synergy_data: SynergyData = GameConfig.synergies.get(tag)
	if synergy_data and synergy_data.tier2_stat == "damage_mult":
		return synergy_data.tier2_value
	# 增益标签无增益机制的单位获得替代伤害加成
	if tag == Enums.Tag.BOOST and unit_id in ["pea_shooter", "laser"]:
		return GameConfig.synergies.get(tag).tier2_value if GameConfig.synergies.has(tag) else 0.0
	return 0.0
```

- [ ] **Step 2: 编写测试验证 2 档加成查询**

在 `test_synergy_manager.gd` 中添加：

```gdscript
func test_tier2_damage_mult_bonus():
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [
		{id = "rifle", level = 1}
	]
	manager.recalculate()
	# Kaze + rifle = 2 猛攻，应有 0.15 伤害加成
	var bonus = manager.get_damage_mult_bonus("rifle")
	assert_almost_eq(bonus, 0.15, 0.001, "猛攻 2 档应给 rifle +15% 伤害")

func test_tier2_no_bonus_below_threshold():
	GameData.current_character = "kaze"
	# 只有角色，无部署单位 = 1 猛攻
	manager.recalculate()
	var bonus = manager.get_damage_mult_bonus("rifle")
	assert_almost_eq(bonus, 0.0, 0.001, "未达 2 档不应有加成")
```

- [ ] **Step 3: 运行测试**

- [ ] **Step 4: 在武器伤害计算中接入羁绊加成**

在 `scripts/entities/weapons/weapon.gd` 的 `get_damage()` 方法中，添加羁绊伤害加成。注意字段名为 `weapon_data`（无下划线前缀），stat key 使用 `Enums.Stat` 常量：

```gdscript
# 在现有 get_damage() 返回值之前插入羁绊加成
# 羁绊 2 档伤害加成
if GameData._synergy_manager:
	var synergy_bonus = GameData._synergy_manager.get_damage_mult_bonus(weapon_data.id)
	damage *= (1.0 + synergy_bonus)
```

类似地，塔的伤害计算也需要接入。在 `tower.gd` 的攻击伤害逻辑中添加同样的查询（字段名为 `tower_data`）。

类似地，塔的伤害计算也需要接入。在 `tower.gd` 的攻击伤害逻辑中添加同样的查询。

- [ ] **Step 5: 运行全部测试**

- [ ] **Step 6: 提交**

```bash
git add scripts/systems/synergy_manager.gd scripts/entities/weapons/weapon.gd scripts/entities/towers/tower.gd tests/unit/test_synergy_manager.gd
git commit -m "feat: 羁绊 2 档数值加成效果（伤害/控制时间/AOE范围/生命/增益强度）"
```

### Task 10: 其他 2 档效果（控制时间、AOE 范围、生命、增益强度）

**Files:**
- Modify: `scripts/systems/synergy_manager.gd`
- Modify: 各塔脚本（需要读取 AOE、控制时间加成）

- [ ] **Step 1: 在 SynergyManager 中添加各 stat 的查询方法**

```gdscript
# 获取控制时间加成倍率
func get_control_duration_bonus() -> float:
	return get_tier2_bonus("control_duration")

# 获取 AOE 范围加成倍率
func get_aoe_range_bonus() -> float:
	return get_tier2_bonus("aoe_range")

# 获取最大生命值加成倍率
func get_max_hp_bonus(unit_id: String) -> float:
	var tag = _tag_lookup.get(unit_id, "")
	if tag == Enums.Tag.FORTIFY and GameData.synergy_active_tiers.get(tag, 0) >= 2:
		var synergy_data = GameConfig.synergies.get(tag)
		if synergy_data:
			return synergy_data.tier2_value
	return 0.0

# 获取增益强度加成倍率
func get_boost_strength_bonus() -> float:
	return get_tier2_bonus("boost_strength")
```

- [ ] **Step 2: 在相关塔/武器中接入查询**

此步骤需要修改具体塔的脚本（如 ice_flower 的减速持续时间、vine 的定身持续时间等）在初始化或攻击时查询 `GameData._synergy_manager.get_control_duration_bonus()` 并应用倍率。

具体接入点因每个塔/武器的实现不同而异，需要逐个检查并在伤害/控制计算中添加。这里列出需要接入的单位：

- **control_duration**: ice_gun（slow_duration）, ice_flower（slow_duration）, vine（trap_duration）, dandelion（push_interval）
- **aoe_range**: rocket（explosion_radius）, bamboo（explosion_radius）, mushroom（attack_range）
- **max_hp**: stump, oak, heal_flower, blade, flamethrower（这些坚守标签单位的 HP）
- **boost_strength**: mint（buff 倍率）, sunflower（金币产出）, thorn（反伤比例）

- [ ] **Step 3: 编写集成测试验证各 2 档效果**

- [ ] **Step 4: 运行全部测试**

- [ ] **Step 5: 提交**

```bash
git commit -m "feat: 2 档羁绊效果接入所有相关塔和武器"
```

---

## Chunk 4: 羁绊效果实现（3 档和 5 档机制型）

### Task 11: 猛攻 3 档 — 狂热（击杀后攻速翻倍）

**Files:**
- Modify: `scripts/systems/synergy_manager.gd`
- Modify: `scripts/entities/weapons/weapon.gd`
- Modify: `scripts/entities/towers/tower.gd`
- Test: `tests/unit/test_synergy_manager.gd`

- [ ] **Step 1: 编写测试**

```gdscript
func test_assault_tier3_frenzy_activates_on_kill():
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [
		{id = "rifle", level = 1},
		{id = "minigun", level = 1}
	]
	manager.recalculate()
	assert_eq(GameData.synergy_active_tiers.get("assault", 0), 3)
	assert_true(manager.is_tier3_active("assault"), "猛攻 3 档应激活")
```

- [ ] **Step 2: 实现狂热机制**

在 SynergyManager 中：
- 监听 `EventBus.enemy_killed` 信号
- 当猛攻 3 档激活时，设置 `_frenzy_active = true` 和 3 秒计时器
- 提供 `get_attack_speed_mult(unit_id)` 方法，猛攻标签单位在狂热激活时返回 2.0

```gdscript
var _frenzy_active: bool = false
var _frenzy_timer: float = 0.0

func is_tier3_active(tag: String) -> bool:
	return GameData.synergy_active_tiers.get(tag, 0) >= 3

func _on_enemy_killed(_type: String, _pos: Vector2, _is_elite: bool) -> void:
	if is_tier3_active(Enums.Tag.ASSAULT):
		_frenzy_active = true
		_frenzy_timer = 3.0
		EventBus.synergy_effect_triggered.emit(Enums.Tag.ASSAULT, "frenzy")

func get_attack_speed_mult(unit_id: String) -> float:
	var tag = _tag_lookup.get(unit_id, "")
	if tag == Enums.Tag.ASSAULT and _frenzy_active:
		return 2.0
	return 1.0
```

**计时器实现**：狂热效果的 3 秒计时由 `SynergyEffectProcessor`（Node）处理。SynergyEffectProcessor 在 main 战斗场景 `_ready()` 中创建并 `add_child()`，通过 `_process(delta)` 更新所有需要计时的羁绊效果（狂热计时器、战术轰炸间隔、护盾冷却等）。SynergyManager 只负责通知 SynergyEffectProcessor 效果激活/失效，不处理时间逻辑。

```gdscript
# scripts/systems/synergy_effect_processor.gd
class_name SynergyEffectProcessor
extends Node

var _frenzy_timer: float = 0.0
var _frenzy_active: bool = false

func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.synergy_changed.connect(_on_synergy_changed)

func _process(delta: float) -> void:
	if _frenzy_active:
		_frenzy_timer -= delta
		if _frenzy_timer <= 0:
			_frenzy_active = false

func _on_enemy_killed(_type: String, _pos: Vector2, _is_elite: bool) -> void:
	if GameData.synergy_active_tiers.get(Enums.Tag.ASSAULT, 0) >= 3:
		_frenzy_active = true
		_frenzy_timer = 3.0
		EventBus.synergy_effect_triggered.emit(Enums.Tag.ASSAULT, "frenzy")

func is_frenzy_active() -> bool:
	return _frenzy_active
```

- [ ] **Step 3: 运行测试**

- [ ] **Step 4: 提交**

```bash
git commit -m "feat: 猛攻 3 档狂热效果 — 击杀后 3 秒攻速翻倍"
```

### Task 12: 控制 3 档 — 脆弱标记

**Files:**
- Modify: `scripts/systems/synergy_manager.gd`
- Modify: `scripts/entities/enemy.gd`

- [ ] **Step 1: 实现脆弱标记**

当控制 3 档激活时，被控制（减速/定身/冻结）的敌人受到全体伤害 +20%。

在 enemy.gd 中，当敌人被减速/定身时检查控制 3 档：
- 在 `SlowHandler` 或敌人的受伤计算中，如果敌人当前被控制且控制 3 档激活，伤害 ×1.2

```gdscript
# 在 enemy 的受伤计算中
func _get_vulnerability_mult() -> float:
	if GameData._synergy_manager and GameData._synergy_manager.is_tier3_active(Enums.Tag.CONTROL):
		if _is_controlled():  # 检查是否被减速/定身/冻结
			return 1.2
	return 1.0
```

- [ ] **Step 2: 测试**
- [ ] **Step 3: 提交**

### Task 13: 爆破 3 档 — 殉爆

**Files:**
- Modify: 爆炸处理相关代码

- [ ] **Step 1: 实现殉爆**

当爆破 3 档激活时，AOE 伤害有 15% 几率触发二次爆炸（50% 伤害）。

在爆炸伤害处理逻辑中（rocket 的爆炸、bamboo 的爆炸等），检查爆破 3 档：

```gdscript
# 在爆炸处理后
if GameData._synergy_manager and GameData._synergy_manager.is_tier3_active(Enums.Tag.BLAST):
	if randf() < 0.15:  # 15% 几率
		# 再次在同位置创建一个 50% 伤害的爆炸
		_create_chain_explosion(position, damage * 0.5, radius)
```

- [ ] **Step 2: 测试**
- [ ] **Step 3: 提交**

### Task 14: 坚守 3 档 — 应急护盾

**Files:**
- Modify: `scripts/components/health_component.gd`

- [ ] **Step 1: 实现应急护盾**

当坚守 3 档激活时，坚守标签单位生命低于 30% 时获得 3 秒护盾（10 秒冷却）。

需要先在 HealthComponent 中新增 `unit_id: String` 字段，在 tower.gd 和 player.gd 的 `_ready()` 中通过 `health.unit_id = tower_data.id` 或 `health.unit_id = GameData.current_character` 设置。

在 HealthComponent 的 `take_damage()` 中检查：

```gdscript
var unit_id: String = ""  # 由宿主在 _ready() 中设置
var _shield_active: bool = false
var _shield_cooldown: float = 0.0

func _check_emergency_shield() -> void:
	if not GameData._synergy_manager:
		return
	if not GameData._synergy_manager.is_tier3_active(Enums.Tag.FORTIFY):
		return
	if _shield_cooldown > 0 or _shield_active:
		return
	var tag = GameData._synergy_manager.get_tag(unit_id)  # unit_id 通过 HealthComponent 初始化时设置
	if tag != Enums.Tag.FORTIFY:
		return
	if current_hp <= max_hp * 0.3:
		_shield_active = true
		# 3 秒后关闭，10 秒冷却
```

- [ ] **Step 2: 测试**
- [ ] **Step 3: 提交**

### Task 15: 增益 3 档 — 自增益

**Files:**
- Modify: 增益类塔的脚本

- [ ] **Step 1: 实现自增益**

当增益 3 档激活时，增益类单位也能获得自己的增益效果（如薄荷也获得自己的伤害/攻速加成）。

薄荷当前通过 `apply_buff()` 给周围塔加成，但排除自身。增益 3 档时取消这个排除。

- [ ] **Step 2: 测试**
- [ ] **Step 3: 提交**

### Task 16: 5 档效果（猛攻/控制/爆破/坚守/增益）

5 档效果是最复杂的机制型效果，每个需要独立实现：

- [ ] **Step 1: 猛攻 5 档 — 溢杀**

击杀敌人时，溢出伤害的 30% 以爆炸形式伤害周围敌人。需要在 HealthComponent 的 died 信号中传递溢出伤害量，然后在击杀处理中创建爆炸。

- [ ] **Step 2: 控制 5 档 — 连锁控制**

控制效果到期时触发 1 秒冻结。需要在 SlowHandler 的减速到期回调中检查，以及 vine 定身到期时检查。冻结不可叠加。

- [ ] **Step 3: 爆破 5 档 — 战术轰炸**

每 15 秒对屏幕内随机 3 个敌人群落投下轰炸。需要在战斗场景中添加定时器，找到最密集的敌人群落位置，创建轰炸效果。

- [ ] **Step 4: 坚守 5 档 — 不屈**

塔被摧毁后 5 秒原地复活，恢复 50% 生命，每塔一局一次。需要在塔的 died 处理中检查，延迟重生。

- [ ] **Step 5: 增益 5 档 — 全域共享**

增益效果同时作用于玩家角色。需要让薄荷等增益塔的 buff 也应用到 player。

- [ ] **Step 6: 测试所有 5 档效果**

- [ ] **Step 7: 提交**

```bash
git commit -m "feat: 所有 3 档和 5 档羁绊机制效果"
```

---

## Chunk 5: 角色被动重写

### Task 17: 移除旧被动系统

**Files:**
- Modify: `scripts/core/enums.gd`（删除 PassiveType 类）
- Modify: `scripts/core/game_data.gd`（移除旧被动字段和逻辑）
- Modify: `scripts/entities/player.gd`（移除旧被动消费代码）
- Modify: `scripts/entities/towers/tower.gd`（移除 `_apply_character_passive()`）
- Modify: `scripts/entities/weapons/weapon.gd`（移除 DAMAGE_ON_LOW_HP 检查）
- Modify: `scripts/entities/enemy.gd`（移除 `coin_drop_mult` 引用）
- Delete: `tests/unit/test_character_passive.gd`（用新测试替代）

- [ ] **Step 1: 删除 enums.gd 中的 PassiveType 类**

移除整个 `class PassiveType` 定义。

- [ ] **Step 2: 清理 GameData 中的旧被动字段**

移除 `character_passive_type`、`character_passive_value`、`coin_drop_mult` 变量及 `init_character()` 中的旧被动初始化代码。

- [ ] **Step 3: 清理实体脚本中的旧被动消费**

- `player.gd`：移除 `kill_heal` 信号连接和回调
- `tower.gd`：移除 `_apply_character_passive()` 方法及调用
- `weapon.gd`：移除 `DAMAGE_ON_LOW_HP` 检查
- `enemy.gd`：移除 `coin_drop_mult` 在 `_drop_coins()` 中的引用

- [ ] **Step 4: 运行全部测试，修复因移除导致的失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 5: 提交**

```bash
git commit -m "refactor: 移除旧 PassiveType 被动系统"
```

### Task 18: 实现新角色被动

**Files:**
- Modify: `scripts/core/game_data.gd`
- Modify: `scripts/entities/player.gd`
- Modify: `scripts/entities/weapons/weapon.gd`
- Create: `tests/unit/test_new_passives.gd`

5 个新被动的实现：

- [ ] **Step 1: 编写新被动测试**

创建 `tests/unit/test_new_passives.gd`：

```gdscript
extends GutTest

func test_kaze_swift_combo_stacks_damage():
	# Kaze 连续命中同一目标，每次叠加 5% 伤害，最高 30%
	GameData.reset()
	GameData.init_character("kaze")
	# 验证被动配置正确加载
	assert_eq(GameData.new_passive_id, "swift_combo")

func test_nemo_field_master_control_range():
	GameData.reset()
	GameData.init_character("nemo")
	assert_eq(GameData.new_passive_id, "field_master")

func test_gorg_blood_rage_damage_on_hp_loss():
	GameData.reset()
	GameData.init_character("gorg")
	assert_eq(GameData.new_passive_id, "blood_rage")

func test_dora_fortify_regen():
	GameData.reset()
	GameData.init_character("dora")
	assert_eq(GameData.new_passive_id, "fortify_regen")

func test_merlin_amplify_field():
	GameData.reset()
	GameData.init_character("merlin")
	assert_eq(GameData.new_passive_id, "amplify_field")
```

- [ ] **Step 2: 在 GameData.init_character() 中初始化新被动**

在现有 `init_character()` 中保持原有角色属性设置代码不变（`character_max_hp`、`character_speed` 等），只替换被动相关的部分：

```gdscript
# 新增变量（替代旧的 character_passive_type / character_passive_value / coin_drop_mult）
var new_passive_id: String = ""
var new_passive_value: float = 0.0
var new_passive_value_2: float = 0.0

# 在 init_character() 中，删除旧被动初始化代码，替换为：
	new_passive_id = char_data.new_passive_id
	new_passive_value = char_data.new_passive_value
	new_passive_value_2 = char_data.new_passive_value_2
```

注意：不修改角色属性设置逻辑（`character_max_hp = char_data.max_hp` 等），只替换被动部分。

- [ ] **Step 3: 实现各被动的运行时逻辑**

**Kaze — 疾风连击**: 在 player.gd 中跟踪上一个攻击目标，命中同一目标时叠加伤害倍率（通过 weapon 查询）。

**Nemo — 控场大师**: 在 ice_gun/boomerang 的控制效果应用时，检查被动并扩大范围 ×1.3。

**Gorg — 血怒**: 在 player.gd 中根据当前生命百分比计算 AOE 伤害加成，提供给武器/塔查询。

**Dora — 坚壁回馈**: 在 player.gd 的 `_process()` 中每 5 秒回复 2% 最大生命值。检查坚守单位存活数 ≥3 时翻倍。

**Merlin — 增幅领域**: 在增益类塔的效果范围计算中，检查被动并乘以 1.4。

- [ ] **Step 4: 运行测试**

- [ ] **Step 5: 提交**

```bash
git commit -m "feat: 5 个新角色被动实现（疾风连击/控场大师/血怒/坚壁回馈/增幅领域）"
```

---

## Chunk 6: 配对协同系统

### Task 19: PairSynergyManager

**Files:**
- Create: `scripts/systems/pair_synergy_manager.gd`
- Modify: `scripts/core/game_data.gd`
- Test: `tests/unit/test_pair_synergy.gd`

- [ ] **Step 1: 编写测试**

创建 `tests/unit/test_pair_synergy.gd`：

```gdscript
extends GutTest

var manager: PairSynergyManager

func before_each():
	GameData.reset()
	manager = PairSynergyManager.new()

func test_no_pair_synergy_by_default():
	manager.recalculate()
	assert_eq(GameData.active_pair_synergies.size(), 0)

func test_ice_gun_vine_pair():
	GameData.current_character = "nemo"
	GameData.deployed_weapons = [{id = "ice_gun", level = 1}]
	GameData.deployed_towers = [{id = "vine", level = 1, grid_pos = Vector2i(0, 0)}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("frozen_cage"), "冰枪+藤蔓应激活极寒囚笼")

func test_rocket_bamboo_pair():
	GameData.deployed_weapons = [{id = "rocket", level = 1}]
	GameData.deployed_towers = [{id = "bamboo", level = 2, grid_pos = Vector2i(0, 0)}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("chain_detonation"), "火箭炮+爆竹竹应激活连环引爆")

func test_gorg_blade_pair():
	GameData.current_character = "gorg"
	GameData.deployed_weapons = [{id = "blade", level = 1}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("bloodthirst"), "Gorg+刀刃应激活嗜血狂战")

func test_pair_deactivates_on_undeploy():
	GameData.current_character = "gorg"
	GameData.deployed_weapons = [{id = "blade", level = 1}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("bloodthirst"))
	GameData.deployed_weapons = []
	manager.recalculate()
	assert_false(GameData.active_pair_synergies.has("bloodthirst"), "卸下刀刃后嗜血狂战应失效")

func test_merlin_mint_pair():
	GameData.current_character = "merlin"
	GameData.deployed_towers = [{id = "mint", level = 1, grid_pos = Vector2i(0, 0)}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("magic_resonance"), "Merlin+薄荷应激活魔力共鸣")

func test_lightning_ice_flower_pair():
	GameData.deployed_weapons = [{id = "lightning", level = 1}]
	GameData.deployed_towers = [{id = "ice_flower", level = 1, grid_pos = Vector2i(0, 0)}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("superconductor"), "闪电+冰花应激活超导风暴")

func test_kaze_minigun_pair():
	GameData.current_character = "kaze"
	GameData.deployed_weapons = [{id = "minigun", level = 1}]
	manager.recalculate()
	assert_true(GameData.active_pair_synergies.has("bullet_time"), "Kaze+加特林应激活弹幕时刻")
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 实现 PairSynergyManager**

创建 `scripts/systems/pair_synergy_manager.gd`：

```gdscript
class_name PairSynergyManager
extends RefCounted

# 配对协同定义：{synergy_id: {units: [id1, id2], name: "显示名"}}
const PAIR_DEFINITIONS = [
	{id = "frozen_cage", units = ["ice_gun", "vine"], name = "极寒囚笼"},
	{id = "chain_detonation", units = ["rocket", "bamboo"], name = "连环引爆"},
	{id = "bloodthirst", units = ["gorg", "blade"], name = "嗜血狂战"},
	{id = "magic_resonance", units = ["merlin", "mint"], name = "魔力共鸣"},
	{id = "superconductor", units = ["lightning", "ice_flower"], name = "超导风暴"},
	{id = "bullet_time", units = ["kaze", "minigun"], name = "弹幕时刻"},
]

func recalculate() -> void:
	var old_actives = GameData.active_pair_synergies.duplicate()
	var new_actives: Array[String] = []

	# 收集所有当前单位 ID（角色 + 已部署武器 + 已部署塔）
	var active_ids: Array[String] = []
	if GameData.current_character != "":
		active_ids.append(GameData.current_character)
	for weapon in GameData.deployed_weapons:
		active_ids.append(weapon.id)
	for tower in GameData.deployed_towers:
		active_ids.append(tower.id)

	# 检查每个配对
	for pair in PAIR_DEFINITIONS:
		var unit1: String = pair.units[0]
		var unit2: String = pair.units[1]
		if active_ids.has(unit1) and active_ids.has(unit2):
			new_actives.append(pair.id)

	GameData.active_pair_synergies = new_actives

	# 发射信号
	for synergy_id in new_actives:
		if not old_actives.has(synergy_id):
			EventBus.pair_synergy_activated.emit(synergy_id)
	for synergy_id in old_actives:
		if not new_actives.has(synergy_id):
			EventBus.pair_synergy_deactivated.emit(synergy_id)
```

- [ ] **Step 4: 在 GameData 中集成 PairSynergyManager**

在 `reset()` 和 deploy/undeploy 方法中同时调用 `_pair_synergy_manager.recalculate()`。

```gdscript
var _pair_synergy_manager: PairSynergyManager

func reset() -> void:
	# ... 现有代码 ...
	_pair_synergy_manager = PairSynergyManager.new()
```

注意：`_synergy_manager` 和 `_pair_synergy_manager` 都必须在 `reset()` 中初始化（而非 `_ready()`），因为 `reset()` 在每次新游戏开始时调用。同时在 `_ready()` 中也初始化一次，防止 `deploy_weapon()` 等方法在 `reset()` 之前被调用时 null crash：

```gdscript
func _ready() -> void:
	_synergy_manager = SynergyManager.new()
	_pair_synergy_manager = PairSynergyManager.new()
	# ... 现有 _ready 代码 ...
```

在每个触发 `_synergy_manager.recalculate()` 的地方同时调用 `_pair_synergy_manager.recalculate()`。

- [ ] **Step 5: 运行测试确认通过**

- [ ] **Step 6: 提交**

```bash
git add scripts/systems/pair_synergy_manager.gd tests/unit/test_pair_synergy.gd scripts/core/game_data.gd
git commit -m "feat: PairSynergyManager 配对协同检测系统"
```

### Task 20: 实现 6 个配对协同的运行时效果

**Files:**
- 修改各相关实体脚本

每个配对协同的效果需要在运行时生效。由于每个效果的实现位置不同，这里分别说明：

- [ ] **Step 1: 极寒囚笼（ice_gun + vine）**

在 vine 的定身到期回调中，检查 `frozen_cage` 是否激活，如果敌人同时被冰枪减速，则施加 2 秒冻结 + 受伤 +30%。

- [ ] **Step 2: 连环引爆（rocket + bamboo）**

在 bamboo 的爆炸逻辑中，检查 `chain_detonation`，如果激活则搜索爆炸范围内的 rocket 弹头并引爆。

- [ ] **Step 3: 嗜血狂战（gorg + blade）**

在 player.gd 中，当角色为 gorg 且 `bloodthirst` 激活时，击杀敌人回复 5% 最大生命值。

- [ ] **Step 4: 魔力共鸣（merlin + mint）**

在 mint 塔的 buff 应用逻辑中，检查 `magic_resonance`，如果激活则不检查距离，全图应用 buff。

- [ ] **Step 5: 超导风暴（lightning + ice_flower）**

在 lightning 的连锁计算中，检查 `superconductor`，如果目标被 ice_flower 减速，则 chain_count +2 且 chain_decay = 1.0。

- [ ] **Step 6: 弹幕时刻（kaze + minigun）**

在 minigun 的射击计数中，检查 `bullet_time`，每 50 发触发 0.5 秒全屏减速 80%（通过 EffectsManager 或直接修改所有敌人速度）。

- [ ] **Step 7: 运行全部测试**

- [ ] **Step 8: 提交**

```bash
git commit -m "feat: 6 个配对协同运行时效果"
```

---

## Chunk 7: 收尾与集成测试

### Task 21: 波次配置扩展到 15 波

**Files:**
- Modify/Create: `resources/waves/<map_id>/*.tres`

- [ ] **Step 1: 检查当前波次数量**

查看现有波次配置文件，确定当前有多少波，需要新增多少。

- [ ] **Step 2: 为每个地图创建 15 波配置**

按照成长节奏设计（开荒 1-3 → 探索 4-7 → 定型 8-11 → 成型 12-15）设置敌人数量和类型递增。

- [ ] **Step 3: 提交**

```bash
git commit -m "feat: 波次配置扩展到 15 波"
```

### Task 22: 全量测试与回归修复

**Files:**
- All test files

- [ ] **Step 1: 运行全部测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 2: 修复所有失败测试**

重点关注：
- `test_character_passive.gd`：需要完全重写或删除（旧被动已移除）
- `test_game_data_economy.gd`：可能有引用旧被动字段的测试
- `test_merge_system.gd`：确认合成不影响羁绊计数

- [ ] **Step 3: 提交**

```bash
git commit -m "test: 修复全部测试适配构筑协同系统"
```

### Task 23: 更新 CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 更新 CLAUDE.md 中的架构描述**

添加 SynergyManager 和 PairSynergyManager 到 Autoload/系统说明。更新角色被动描述。添加标签羁绊概要。

- [ ] **Step 2: 提交**

```bash
git commit -m "docs: 更新 CLAUDE.md 适配构筑协同系统"
```
