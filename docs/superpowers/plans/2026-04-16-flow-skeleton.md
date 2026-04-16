# 流程骨架重构 (#1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 utoland 从"射击 + 自走棋商店"流程,重构为"战斗中 Roll 塔 + 升级 3 选 1 perk"的类幸存者+塔防骨架,保留现有武器系统和 3 座塔不动。

**Architecture:** 移除 SHOP/BATTLE 二阶段,常态战斗。新增 `PerkManager`(Autoload)+ `TowerRollManager`(RefCounted,替代 `ShopManager`)+ 新 UI 三件套(Perk 弹窗 / Roll 弹窗 / 待建造栏)。perk 效果通过 `PlayerState.player_stats` 字典作为 source of truth,各消费方读取。塔池分 Tier 1-4 + 动态权重(已部署同款塔提升权重),#1 阶段 3 座塔均 Tier 1,框架先就位。

**Tech Stack:** Godot 4.6 (GDScript),GUT 测试框架。

**Spec:** `docs/superpowers/specs/2026-04-16-flow-skeleton-design.md`

---

## File Structure

### 新增

| 文件 | 职责 |
|---|---|
| `scripts/resources/perk_data.gd` | Perk Resource 类(id / 显示名 / 描述 / icon / 效果类型 / 数值) |
| `scripts/resources/tier_weight_table.gd` | Tier 概率表 Resource(按英雄等级分段配置 4 个 Tier 的权重) |
| `scripts/core/perk_manager.gd` | Autoload。监听 `player_level_changed` → 抽 3 个 perk → 弹窗 → 应用效果 |
| `scripts/systems/tower_roll_manager.gd` | RefCounted。Tier 抽卡 + 动态权重(替代 `ShopManager`) |
| `scripts/ui/perk_selection_overlay.gd` + `.tscn` | 升级 3 选 1 暂停弹窗 |
| `scripts/ui/tower_roll_overlay.gd` + `.tscn` | Roll 时 3 选 1 塔卡片(取消退款) |
| `scripts/ui/pending_queue_panel.gd` + `.tscn` | 待建造栏(3 槽,拖拽源) |
| `scripts/ui/battle_hud.gd` + `.tscn` | 战斗 HUD 主组件,替代 `shop_overlay`(整合武器装备栏 + 信息栏 + Roll 按钮 + 待建造栏) |
| `resources/perks/*.tres` × 8 | 通用 perk 配置 |
| `resources/shop/tier_weight_table.tres` | 默认 Tier 概率表 |
| `tests/unit/test_perk_manager.gd` | PerkManager 单元测试 |
| `tests/unit/test_tower_roll_manager.gd` | TowerRollManager 单元测试 |
| `tests/unit/test_perk_data.gd` | PerkData 资源加载校验 |
| `tests/integration/test_flow_skeleton.gd` | 集成测试:升级 → perk / Roll → 放置 / 卖出 / 波次间 |

### 修改

| 文件 | 改动摘要 |
|---|---|
| `scripts/core/enums.gd` | `Stat` 类新增 8 个 perk bonus key |
| `scripts/resources/shop_config.gd` | 重构字段(精简旧的、新增 roll/perk 相关) |
| `scripts/resources/tower_data.gd` | 新增 `tier: int = 1` |
| `resources/towers/*.tres` | 填 `tier = 1` |
| `scripts/core/event_bus.gd` | 新增 roll / perk 信号 |
| `scripts/core/player_state.gd` | `player_stats` 字典初始化 perk bonus 字段;reset 同步 |
| `scripts/core/player_progression.gd` | `add_exp` 乘 `exp_gain_bonus`;`get_population_cap()` 加 `population_bonus` |
| `scripts/core/inventory_manager.gd` | 新增 `pending_towers` + roll/consume/cancel API;sell 改 70% |
| `scripts/entities/player.gd` | 应用 hp / move_speed / pickup_radius bonus |
| `scripts/entities/enemy.gd` | 掉金币应用 `coin_drop_bonus` |
| `scripts/components/ranged_attack_component.gd` | `get_final_damage` / `get_final_cooldown` 应用 perk bonus |
| `scripts/components/melee_attack_component.gd` | 同上 |
| `scripts/systems/drag_manager.gd` | `start_tower_placement` 接受"pending 索引"形态 |
| `scripts/ui/main.gd` | 删 `Phase` 状态机,常态 BATTLE,集成新 UI |
| `project.godot` | 注册 `PerkManager` Autoload |

### 删除

| 文件 | 原因 |
|---|---|
| `scripts/systems/shop_manager.gd` | 由 `TowerRollManager` 替代 |
| `scripts/ui/shop_overlay.gd` + `.tscn` | 由 `BattleHUD` 替代 |
| `tests/unit/test_shop_manager.gd` | 同上 |
| `tests/unit/test_shop_overlay.gd` | 同上 |
| `tests/unit/test_wave_reward.gd` | wave_reward 机制已移除 |

---

## 通用工具

### 运行所有测试

```bash
cd /Users/langtao/utoland
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

### 运行单个测试文件

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_perk_manager.gd -gexit
```

### 头脑刷新 class_name 缓存

新增带 `class_name` 的脚本后,如果 headless 测试找不到类,在 `.godot/global_script_class_cache.cfg` 中手动追加条目;或者用 Godot 编辑器打开一次让其自动刷新。

---

## Phase A — 数据模型与资源(独立基础)

### Task 1: 扩展 Enums.Stat 加入 perk bonus 字段

**Files:**
- Modify: `scripts/core/enums.gd:60-69`

- [ ] **Step 1: 修改 Enums.Stat 类**

在 `Stat` 类末尾追加 8 个新 key:

```gdscript
# 玩家属性 key
class Stat:
	const MAX_HP = "max_hp"
	const HP_MULT = "hp_mult"
	const DAMAGE_MULT = "damage_mult"
	const ATTACK_SPEED_MULT = "attack_speed_mult"
	const TOWER_MULT = "tower_mult"
	const MELEE_DAMAGE_MULT = "MELEE_DAMAGE_MULT"
	const MELEE_ATTACK_SPEED_MULT = "MELEE_ATTACK_SPEED_MULT"
	# Perk bonus(战斗中 3 选 1 累加)
	const HP_BONUS_PERCENT = "hp_bonus_percent"
	const MOVE_SPEED_BONUS_PERCENT = "move_speed_bonus_percent"
	const DAMAGE_BONUS_PERCENT = "damage_bonus_percent"
	const ATTACK_SPEED_BONUS_PERCENT = "attack_speed_bonus_percent"
	const PICKUP_RADIUS_BONUS_PERCENT = "pickup_radius_bonus_percent"
	const COIN_DROP_BONUS_PERCENT = "coin_drop_bonus_percent"
	const EXP_GAIN_BONUS_PERCENT = "exp_gain_bonus_percent"
	const POPULATION_BONUS = "population_bonus"
```

- [ ] **Step 2: 提交**

```bash
git add scripts/core/enums.gd
git commit -m "feat: Enums.Stat 新增 8 个 perk bonus key"
```

---

### Task 2: 重构 ShopConfig 字段

**Files:**
- Modify: `scripts/resources/shop_config.gd`

- [ ] **Step 1: 重写 shop_config.gd**

替换整个文件内容:

```gdscript
class_name ShopConfig
extends Resource

# 商店全局配置(#1 流程骨架重构后,主要服务于 Roll 塔机制)

# Roll 塔配置
@export var roll_cost: int = 3
@export var pending_queue_size: int = 3
@export var dynamic_weight_multiplier: float = 1.5  # 已部署同款塔的 roll 权重倍率

# 卖出配置
@export var sell_return_ratio: float = 0.7  # 卖出返还比例(总投入 × 0.7)

# 兼容字段(暂留 = 0,后续子项目用):波次奖励、Boss 赏金已废弃,金币全靠敌人掉 + 塔生成
```

- [ ] **Step 2: 检查现有 .tres 文件并更新**

读取 `resources/shop_config.tres` 内容(用 Read tool)。如果存在旧字段(`slot_count` / `refresh_cost` / `item_cost` / `wave_reward_per_tier` / `wave_reward_tier_thresholds` / `boss_bounty`),用编辑器或文本编辑器更新为新字段(roll_cost=3,pending_queue_size=3,dynamic_weight_multiplier=1.5,sell_return_ratio=0.7)。

- [ ] **Step 3: 全局搜索旧字段引用**

```bash
cd /Users/langtao/utoland
```

用 Grep 搜以下符号在脚本中的引用,确认下面任务里都会更新:

- `shop_config.slot_count`
- `shop_config.refresh_cost`
- `shop_config.item_cost`
- `shop_config.wave_reward_per_tier`
- `shop_config.wave_reward_tier_thresholds`
- `shop_config.boss_bounty`
- `get_wave_reward(`

每个文件如果命中,在后续任务里改掉。**注意:本任务不立即修复引用**,因为旧 ShopManager / ShopOverlay 会在 Phase D 删除,先记录在心里。

- [ ] **Step 4: 提交**

```bash
git add scripts/resources/shop_config.gd resources/shop_config.tres
git commit -m "refactor: ShopConfig 字段重构为 Roll/Perk 模型"
```

---

### Task 3: TowerData 新增 tier 字段 + 各 .tres 设置 tier=1

**Files:**
- Modify: `scripts/resources/tower_data.gd`
- Modify: `resources/towers/pea_shooter.tres`
- Modify: `resources/towers/ice_flower.tres`
- Modify: `resources/towers/sunflower.tres`

- [ ] **Step 1: tower_data.gd 加字段**

在 `TowerData` 顶部添加 `tier`:

```gdscript
class_name TowerData
extends Resource

@export_group("基础信息")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""
@export var sell_price_per_level: PackedInt32Array = PackedInt32Array([])
@export var hp_per_level: PackedFloat32Array = []
@export var tier: int = 1  # Tier 1-4,#6 扩塔池后真正起作用

@export_group("射击塔配置")
@export var attack_config: AttackConfigData = null
@export var projectile_data: ProjectileData = null
@export var slow_ratio_per_level: PackedFloat32Array = []
@export var slow_duration_per_level: PackedFloat32Array = []

@export_group("生成塔配置")
@export var generator_config: GeneratorConfigData = null
```

- [ ] **Step 2: 各塔 .tres 文件填 tier=1**

用 Godot 编辑器打开 `resources/towers/pea_shooter.tres`,在 Inspector 中将 `tier` 设为 1。对 `ice_flower.tres` 和 `sunflower.tres` 重复操作。

或者直接编辑文本(Read 找到对应资源,在 `[resource]` block 末尾添加 `tier = 1` 一行,对每个 .tres 重复)。

- [ ] **Step 3: 写测试验证 tier 字段被加载**

Create `tests/unit/test_tower_data_tier.gd`:

```gdscript
extends GutTest

func test_pea_shooter_tier_loaded() -> void:
	var data: TowerData = GameConfig.towers["pea_shooter"]
	assert_eq(data.tier, 1)

func test_ice_flower_tier_loaded() -> void:
	var data: TowerData = GameConfig.towers["ice_flower"]
	assert_eq(data.tier, 1)

func test_sunflower_tier_loaded() -> void:
	var data: TowerData = GameConfig.towers["sunflower"]
	assert_eq(data.tier, 1)
```

- [ ] **Step 4: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_tower_data_tier.gd -gexit
```

期望: 3 passing。

- [ ] **Step 5: 提交**

```bash
git add scripts/resources/tower_data.gd resources/towers/ tests/unit/test_tower_data_tier.gd
git commit -m "feat: TowerData 新增 tier 字段,3 座塔填 tier=1"
```

---

### Task 4: 新建 PerkData Resource 类 + 8 个通用 perk .tres

**Files:**
- Create: `scripts/resources/perk_data.gd`
- Create: `resources/perks/vitality.tres`
- Create: `resources/perks/swift.tres`
- Create: `resources/perks/power.tres`
- Create: `resources/perks/rapid.tres`
- Create: `resources/perks/reach.tres`
- Create: `resources/perks/greed.tres`
- Create: `resources/perks/study.tres`
- Create: `resources/perks/expansion.tres`

- [ ] **Step 1: 创建 PerkData 类**

Create `scripts/resources/perk_data.gd`:

```gdscript
class_name PerkData
extends Resource

# Perk 效果类型 — 每个 perk 修改 PlayerState.player_stats 中的一个字段
enum EffectType {
	HP_PERCENT,
	MOVE_SPEED_PERCENT,
	DAMAGE_PERCENT,
	ATTACK_SPEED_PERCENT,
	PICKUP_RADIUS_PERCENT,
	COIN_DROP_PERCENT,
	EXP_GAIN_PERCENT,
	POPULATION_FLAT,
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export_file("*.png") var icon_path: String = ""
@export var effect_type: EffectType = EffectType.HP_PERCENT
@export var effect_value: float = 0.0
```

- [ ] **Step 2: 创建 8 个 perk .tres**

先创建 `resources/perks/` 目录(如不存在)。

每个 .tres 文件按以下模板创建(脚本路径用 `res://scripts/resources/perk_data.gd`)。先用 Godot 编辑器创建第 1 个 `vitality.tres`(Resource → New Resource → 选 PerkData),手动填字段,保存。其余 7 个用文本复制后修改字段。

`resources/perks/vitality.tres`:

```ini
[gd_resource type="Resource" script_class="PerkData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/perk_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "vitality"
display_name = "强健"
description = "最大生命 +10%"
icon_path = ""
effect_type = 0
effect_value = 0.1
```

`resources/perks/swift.tres`(`effect_type = 1`,描述"移速 +10%",effect_value = 0.1)

`resources/perks/power.tres`(`effect_type = 2`,描述"武器伤害 +10%",effect_value = 0.1)

`resources/perks/rapid.tres`(`effect_type = 3`,描述"武器攻速 +10%",effect_value = 0.1)

`resources/perks/reach.tres`(`effect_type = 4`,描述"拾取范围 +30%",effect_value = 0.3)

`resources/perks/greed.tres`(`effect_type = 5`,描述"金币掉落 +10%",effect_value = 0.1)

`resources/perks/study.tres`(`effect_type = 6`,描述"经验获取 +10%",effect_value = 0.1)

`resources/perks/expansion.tres`(`effect_type = 7`,描述"人口上限 +1",effect_value = 1.0)

每个文件的 `id` 字段对应文件名(无 .tres 后缀)。`display_name` 同 spec 表。

- [ ] **Step 3: 写测试验证每个 perk 加载**

Create `tests/unit/test_perk_data.gd`:

```gdscript
extends GutTest

const PERK_IDS: Array[String] = [
	"vitality", "swift", "power", "rapid",
	"reach", "greed", "study", "expansion",
]

func test_all_perk_files_load() -> void:
	for id in PERK_IDS:
		var path: String = "res://resources/perks/%s.tres" % id
		assert_true(ResourceLoader.exists(path), "perk 文件不存在: " + path)
		var perk: PerkData = load(path)
		assert_not_null(perk, "perk 加载失败: " + path)
		assert_eq(perk.id, id, "perk id 不匹配: " + path)

func test_vitality_effect() -> void:
	var perk: PerkData = load("res://resources/perks/vitality.tres")
	assert_eq(perk.effect_type, PerkData.EffectType.HP_PERCENT)
	assert_almost_eq(perk.effect_value, 0.1, 0.001)

func test_expansion_effect() -> void:
	var perk: PerkData = load("res://resources/perks/expansion.tres")
	assert_eq(perk.effect_type, PerkData.EffectType.POPULATION_FLAT)
	assert_almost_eq(perk.effect_value, 1.0, 0.001)
```

- [ ] **Step 4: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_perk_data.gd -gexit
```

期望: 3 passing。如果 `class_name PerkData` 找不到,用 Godot 编辑器打开一次让缓存刷新,或在 `.godot/global_script_class_cache.cfg` 手动追加条目。

- [ ] **Step 5: 提交**

```bash
git add scripts/resources/perk_data.gd resources/perks/ tests/unit/test_perk_data.gd
git commit -m "feat: 新增 PerkData Resource + 8 个通用占位 perk"
```

---

### Task 5: 新建 TierWeightTable Resource + 默认 .tres

**Files:**
- Create: `scripts/resources/tier_weight_table.gd`
- Create: `resources/shop/tier_weight_table.tres`

- [ ] **Step 1: 创建 TierWeightTable 类**

Create `scripts/resources/tier_weight_table.gd`:

```gdscript
class_name TierWeightTable
extends Resource

# Tier 权重表 — 按英雄等级分段配置 4 个 Tier 的抽中权重
#
# entries 是按 level_min 升序排列的数组,每项:
#   {
#     "level_min": int,        # 该段起始等级(含)
#     "weights": Array[float], # 长度 4,对应 Tier 1-4 的权重(归一化用)
#   }
#
# 查找规则:取 level_min <= player_level 的最大段。

@export var entries: Array = []

func get_tier_weights(player_level: int) -> Array:
	var matched: Array = [1.0, 0.0, 0.0, 0.0]  # 兜底
	for entry in entries:
		if entry.get("level_min", 99999) <= player_level:
			matched = entry.get("weights", matched)
	return matched
```

- [ ] **Step 2: 创建默认表 .tres**

先确保 `resources/shop/` 目录存在。

Create `resources/shop/tier_weight_table.tres`:

```ini
[gd_resource type="Resource" script_class="TierWeightTable" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/tier_weight_table.gd" id="1"]

[resource]
script = ExtResource("1")
entries = [{
"level_min": 1,
"weights": [1.0, 0.0, 0.0, 0.0]
}, {
"level_min": 3,
"weights": [0.75, 0.25, 0.0, 0.0]
}, {
"level_min": 6,
"weights": [0.5, 0.35, 0.15, 0.0]
}, {
"level_min": 10,
"weights": [0.3, 0.4, 0.2, 0.1]
}]
```

- [ ] **Step 3: 写测试**

Create `tests/unit/test_tier_weight_table.gd`:

```gdscript
extends GutTest

var _table: TierWeightTable = null

func before_each() -> void:
	_table = load("res://resources/shop/tier_weight_table.tres")

func test_level_1_returns_only_tier_1() -> void:
	var w: Array = _table.get_tier_weights(1)
	assert_eq(w[0], 1.0)
	assert_eq(w[1], 0.0)
	assert_eq(w[2], 0.0)
	assert_eq(w[3], 0.0)

func test_level_3_returns_t1_t2_mix() -> void:
	var w: Array = _table.get_tier_weights(3)
	assert_almost_eq(w[0], 0.75, 0.001)
	assert_almost_eq(w[1], 0.25, 0.001)

func test_level_10_returns_full_spread() -> void:
	var w: Array = _table.get_tier_weights(10)
	assert_almost_eq(w[3], 0.1, 0.001)

func test_level_above_max_uses_top_segment() -> void:
	var w: Array = _table.get_tier_weights(99)
	assert_almost_eq(w[3], 0.1, 0.001)
```

- [ ] **Step 4: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_tier_weight_table.gd -gexit
```

期望: 4 passing。

- [ ] **Step 5: 提交**

```bash
git add scripts/resources/tier_weight_table.gd resources/shop/tier_weight_table.tres tests/unit/test_tier_weight_table.gd
git commit -m "feat: 新增 TierWeightTable + 默认权重表"
```

---

### Task 6: EventBus 新增 roll / perk 信号

**Files:**
- Modify: `scripts/core/event_bus.gd:36-42`

- [ ] **Step 1: 在文件末尾追加新信号块**

在 `tower_moved` 信号下方追加:

```gdscript
# Perk 系统(战斗中 3 选 1 升级)
signal perk_offered(perks: Array)            # Array[PerkData]
signal perk_selected(perk_id: String)
signal perk_applied(perk_id: String)         # 应用完毕广播,UI 可刷新

# Roll 塔系统
signal tower_rolled(candidates: Array)       # Array[String](3 个 tower_id)
signal tower_added_to_queue(tower_id: String)
signal tower_consumed_from_queue(index: int)
signal tower_roll_canceled()
```

注意: **不新增** `player_level_up` 信号,复用现有 `player_level_changed`。

- [ ] **Step 2: 写测试**

Create `tests/unit/test_event_bus_perk_roll.gd`:

```gdscript
extends GutTest

func test_perk_offered_signal_exists() -> void:
	assert_true(EventBus.has_signal("perk_offered"))

func test_perk_selected_signal_exists() -> void:
	assert_true(EventBus.has_signal("perk_selected"))

func test_perk_applied_signal_exists() -> void:
	assert_true(EventBus.has_signal("perk_applied"))

func test_tower_rolled_signal_exists() -> void:
	assert_true(EventBus.has_signal("tower_rolled"))

func test_tower_added_to_queue_signal_exists() -> void:
	assert_true(EventBus.has_signal("tower_added_to_queue"))

func test_tower_consumed_from_queue_signal_exists() -> void:
	assert_true(EventBus.has_signal("tower_consumed_from_queue"))

func test_tower_roll_canceled_signal_exists() -> void:
	assert_true(EventBus.has_signal("tower_roll_canceled"))
```

- [ ] **Step 3: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_event_bus_perk_roll.gd -gexit
```

期望: 7 passing。

- [ ] **Step 4: 提交**

```bash
git add scripts/core/event_bus.gd tests/unit/test_event_bus_perk_roll.gd
git commit -m "feat: EventBus 新增 perk 与 roll 系统信号"
```

---

## Phase B — 核心系统

### Task 7: PlayerState.player_stats 加 perk bonus 字段 + reset 同步

**Files:**
- Modify: `scripts/core/player_state.gd:23-29` 及 `:48-59`
- Test: `tests/unit/test_player_state.gd`(扩展)

- [ ] **Step 1: 修改 player_stats 初始化**

将 player_state.gd 顶部 `player_stats` 字典扩展为:

```gdscript
# 运行时属性集
var player_stats: Dictionary = {
	Enums.Stat.MAX_HP: 100.0,
	Enums.Stat.HP_MULT: 1.0,
	Enums.Stat.DAMAGE_MULT: 1.0,
	Enums.Stat.ATTACK_SPEED_MULT: 1.0,
	Enums.Stat.TOWER_MULT: 1.0,
	# Perk bonus(战斗中累加,reset 重置)
	Enums.Stat.HP_BONUS_PERCENT: 0.0,
	Enums.Stat.MOVE_SPEED_BONUS_PERCENT: 0.0,
	Enums.Stat.DAMAGE_BONUS_PERCENT: 0.0,
	Enums.Stat.ATTACK_SPEED_BONUS_PERCENT: 0.0,
	Enums.Stat.PICKUP_RADIUS_BONUS_PERCENT: 0.0,
	Enums.Stat.COIN_DROP_BONUS_PERCENT: 0.0,
	Enums.Stat.EXP_GAIN_BONUS_PERCENT: 0.0,
	Enums.Stat.POPULATION_BONUS: 0,
}
```

- [ ] **Step 2: 修改 reset() 同步 perk bonus**

在 `reset()` 函数中 `player_stats = {...}` 段落里也加上 perk bonus 字段(全部归 0):

```gdscript
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
		Enums.Stat.TOWER_MULT: 1.0,
		Enums.Stat.HP_BONUS_PERCENT: 0.0,
		Enums.Stat.MOVE_SPEED_BONUS_PERCENT: 0.0,
		Enums.Stat.DAMAGE_BONUS_PERCENT: 0.0,
		Enums.Stat.ATTACK_SPEED_BONUS_PERCENT: 0.0,
		Enums.Stat.PICKUP_RADIUS_BONUS_PERCENT: 0.0,
		Enums.Stat.COIN_DROP_BONUS_PERCENT: 0.0,
		Enums.Stat.EXP_GAIN_BONUS_PERCENT: 0.0,
		Enums.Stat.POPULATION_BONUS: 0,
	}
```

- [ ] **Step 3: 写测试**

Append to `tests/unit/test_player_state.gd`(如果文件存在,在末尾追加;不存在则创建头部 `extends GutTest`):

```gdscript
# ===== Perk bonus 字段 =====

func test_player_stats_has_perk_bonus_keys() -> void:
	PlayerState.reset()
	assert_true(PlayerState.player_stats.has(Enums.Stat.HP_BONUS_PERCENT))
	assert_true(PlayerState.player_stats.has(Enums.Stat.MOVE_SPEED_BONUS_PERCENT))
	assert_true(PlayerState.player_stats.has(Enums.Stat.DAMAGE_BONUS_PERCENT))
	assert_true(PlayerState.player_stats.has(Enums.Stat.ATTACK_SPEED_BONUS_PERCENT))
	assert_true(PlayerState.player_stats.has(Enums.Stat.PICKUP_RADIUS_BONUS_PERCENT))
	assert_true(PlayerState.player_stats.has(Enums.Stat.COIN_DROP_BONUS_PERCENT))
	assert_true(PlayerState.player_stats.has(Enums.Stat.EXP_GAIN_BONUS_PERCENT))
	assert_true(PlayerState.player_stats.has(Enums.Stat.POPULATION_BONUS))

func test_perk_bonus_initialized_to_zero() -> void:
	PlayerState.reset()
	assert_eq(PlayerState.player_stats[Enums.Stat.HP_BONUS_PERCENT], 0.0)
	assert_eq(PlayerState.player_stats[Enums.Stat.POPULATION_BONUS], 0)

func test_perk_bonus_reset_clears_accumulated() -> void:
	PlayerState.reset()
	PlayerState.player_stats[Enums.Stat.HP_BONUS_PERCENT] = 0.5
	PlayerState.player_stats[Enums.Stat.POPULATION_BONUS] = 3
	PlayerState.reset()
	assert_eq(PlayerState.player_stats[Enums.Stat.HP_BONUS_PERCENT], 0.0)
	assert_eq(PlayerState.player_stats[Enums.Stat.POPULATION_BONUS], 0)
```

- [ ] **Step 4: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_player_state.gd -gexit
```

期望: 新增 3 个测试 passing,旧测试不破。

- [ ] **Step 5: 提交**

```bash
git add scripts/core/player_state.gd tests/unit/test_player_state.gd
git commit -m "feat: PlayerState.player_stats 新增 perk bonus 字段"
```

---

### Task 8: PlayerProgression 经验/人口应用 perk bonus

**Files:**
- Modify: `scripts/core/player_progression.gd:13-24`
- Test: `tests/unit/test_player_progression.gd`(扩展)

- [ ] **Step 1: 修改 add_exp 应用 exp_gain_bonus_percent**

```gdscript
func add_exp(amount: int) -> void:
	var bonus: float = PlayerState.player_stats.get(Enums.Stat.EXP_GAIN_BONUS_PERCENT, 0.0)
	var actual: int = int(round(amount * (1.0 + bonus)))
	current_exp += actual
	total_exp_earned += actual
	while current_exp >= exp_for_level(player_level + 1):
		player_level += 1
		EventBus.player_level_changed.emit(player_level)
	var next_threshold: int = exp_for_level(player_level + 1)
	EventBus.exp_changed.emit(current_exp, next_threshold)
```

- [ ] **Step 2: 修改 get_population_cap 应用 population_bonus**

```gdscript
func get_population_cap() -> int:
	var config: ExpConfig = GameConfig.exp_config
	var base: int = config.initial_population + (player_level - 1) * config.population_per_level
	var bonus: int = PlayerState.player_stats.get(Enums.Stat.POPULATION_BONUS, 0)
	return base + bonus
```

- [ ] **Step 3: 写测试 — 经验加成**

Append to `tests/unit/test_player_progression.gd`:

```gdscript
# ===== Perk bonus 应用 =====

func test_exp_gain_bonus_multiplies_added_exp() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	PlayerState.player_stats[Enums.Stat.EXP_GAIN_BONUS_PERCENT] = 0.5  # +50%
	PlayerProgression.add_exp(10)
	assert_eq(PlayerProgression.current_exp, 15)

func test_population_bonus_added_to_cap() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	var base_cap: int = PlayerProgression.get_population_cap()
	PlayerState.player_stats[Enums.Stat.POPULATION_BONUS] = 3
	assert_eq(PlayerProgression.get_population_cap(), base_cap + 3)
```

- [ ] **Step 4: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_player_progression.gd -gexit
```

期望: 新增 2 个测试 passing。

- [ ] **Step 5: 提交**

```bash
git add scripts/core/player_progression.gd tests/unit/test_player_progression.gd
git commit -m "feat: PlayerProgression 应用 exp_gain / population perk bonus"
```

---

### Task 9: PerkManager Autoload + 注册 + 单元测试

**Files:**
- Create: `scripts/core/perk_manager.gd`
- Modify: `project.godot:18-29`(autoload 段)
- Create: `tests/unit/test_perk_manager.gd`

- [ ] **Step 1: 创建 PerkManager**

Create `scripts/core/perk_manager.gd`:

```gdscript
extends Node
## Perk 管理器 — 监听升级 → 抽 3 个 perk → 等待 UI 选择 → 应用效果
##
## 使用流程:
##   1. PlayerProgression.add_exp() 触发 player_level_changed
##   2. PerkManager 抽 3 个 perk → emit perk_offered
##   3. UI 弹窗,玩家点选一个 → 调 select_perk(perk_id)
##   4. PerkManager 应用效果 → emit perk_applied
##
## 多次升级排队:_pending_levelups 计数,UI 关闭后立即触发下一轮。

const PERK_FILES: Array[String] = [
	"res://resources/perks/vitality.tres",
	"res://resources/perks/swift.tres",
	"res://resources/perks/power.tres",
	"res://resources/perks/rapid.tres",
	"res://resources/perks/reach.tres",
	"res://resources/perks/greed.tres",
	"res://resources/perks/study.tres",
	"res://resources/perks/expansion.tres",
]

var _all_perks: Array = []           # Array[PerkData]
var _current_offer: Array = []       # Array[PerkData],当前等待玩家选择
var _pending_levelups: int = 0       # 排队中的升级次数

func _ready() -> void:
	_load_all_perks()
	EventBus.player_level_changed.connect(_on_player_level_changed)

func _load_all_perks() -> void:
	_all_perks.clear()
	for path in PERK_FILES:
		var perk: PerkData = load(path)
		if perk:
			_all_perks.append(perk)

func _on_player_level_changed(_new_level: int) -> void:
	_pending_levelups += 1
	if _current_offer.is_empty():
		_offer_next()

func _offer_next() -> void:
	if _pending_levelups <= 0:
		return
	_pending_levelups -= 1
	_current_offer = _draw_three()
	EventBus.perk_offered.emit(_current_offer)

func _draw_three() -> Array:
	# 抽 3 个不重复
	var pool: Array = _all_perks.duplicate()
	pool.shuffle()
	return pool.slice(0, mini(3, pool.size()))

func select_perk(perk_id: String) -> bool:
	# UI 调用,提交玩家选择
	var picked: PerkData = null
	for p in _current_offer:
		if p.id == perk_id:
			picked = p
			break
	if picked == null:
		return false
	_apply_effect(picked)
	EventBus.perk_selected.emit(perk_id)
	EventBus.perk_applied.emit(perk_id)
	_current_offer = []
	# 队列里还有等待中的升级,立刻再抽一组
	if _pending_levelups > 0:
		_offer_next()
	return true

func _apply_effect(perk: PerkData) -> void:
	match perk.effect_type:
		PerkData.EffectType.HP_PERCENT:
			_add(Enums.Stat.HP_BONUS_PERCENT, perk.effect_value)
		PerkData.EffectType.MOVE_SPEED_PERCENT:
			_add(Enums.Stat.MOVE_SPEED_BONUS_PERCENT, perk.effect_value)
		PerkData.EffectType.DAMAGE_PERCENT:
			_add(Enums.Stat.DAMAGE_BONUS_PERCENT, perk.effect_value)
		PerkData.EffectType.ATTACK_SPEED_PERCENT:
			_add(Enums.Stat.ATTACK_SPEED_BONUS_PERCENT, perk.effect_value)
		PerkData.EffectType.PICKUP_RADIUS_PERCENT:
			_add(Enums.Stat.PICKUP_RADIUS_BONUS_PERCENT, perk.effect_value)
		PerkData.EffectType.COIN_DROP_PERCENT:
			_add(Enums.Stat.COIN_DROP_BONUS_PERCENT, perk.effect_value)
		PerkData.EffectType.EXP_GAIN_PERCENT:
			_add(Enums.Stat.EXP_GAIN_BONUS_PERCENT, perk.effect_value)
		PerkData.EffectType.POPULATION_FLAT:
			var cur: int = PlayerState.player_stats.get(Enums.Stat.POPULATION_BONUS, 0)
			PlayerState.player_stats[Enums.Stat.POPULATION_BONUS] = cur + int(perk.effect_value)
		_:
			push_warning("未知 perk effect_type: " + str(perk.effect_type))

func _add(stat_key: String, delta: float) -> void:
	var cur: float = PlayerState.player_stats.get(stat_key, 0.0)
	PlayerState.player_stats[stat_key] = cur + delta

func reset() -> void:
	# 一局结束清理状态
	_current_offer = []
	_pending_levelups = 0

func has_pending() -> bool:
	return not _current_offer.is_empty() or _pending_levelups > 0

func get_current_offer() -> Array:
	return _current_offer.duplicate()
```

- [ ] **Step 2: 注册 Autoload**

修改 `project.godot` 的 `[autoload]` 段,在 `AudioManager` 之后追加:

```ini
[autoload]

GameConfig="*res://scripts/core/game_config.gd"
PlayerState="*res://scripts/core/player_state.gd"
PlayerProgression="*res://scripts/core/player_progression.gd"
InventoryManager="*res://scripts/core/inventory_manager.gd"
StatsTracker="*res://scripts/core/stats_tracker.gd"
SceneFactory="*res://scripts/core/scene_factory.gd"
EffectsManager="*res://scripts/systems/effects_manager.gd"
EventBus="*res://scripts/core/event_bus.gd"
SceneManager="*res://scripts/core/scene_manager.gd"
AudioManager="*res://scripts/systems/audio_manager.gd"
PerkManager="*res://scripts/core/perk_manager.gd"
```

- [ ] **Step 3: 写测试**

Create `tests/unit/test_perk_manager.gd`:

```gdscript
extends GutTest

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	PerkManager.reset()

func test_perk_manager_loads_all_perks() -> void:
	# _all_perks 私有,通过抽 3 个验证池子可用
	var offer: Array = PerkManager._draw_three()
	assert_eq(offer.size(), 3)

func test_player_level_changed_offers_perks() -> void:
	var emitted: Array = []
	var conn := func(perks: Array) -> void:
		emitted = perks
	EventBus.perk_offered.connect(conn)
	EventBus.player_level_changed.emit(2)
	assert_eq(emitted.size(), 3)
	EventBus.perk_offered.disconnect(conn)

func test_select_perk_applies_hp_bonus() -> void:
	EventBus.player_level_changed.emit(2)
	var offer: Array = PerkManager.get_current_offer()
	# 强制选 vitality(把 vitality 放进 offer)
	for p in PerkManager._all_perks:
		if p.id == "vitality":
			PerkManager._current_offer = [p]
			break
	var ok: bool = PerkManager.select_perk("vitality")
	assert_true(ok)
	assert_almost_eq(PlayerState.player_stats[Enums.Stat.HP_BONUS_PERCENT], 0.1, 0.001)

func test_select_unknown_perk_returns_false() -> void:
	EventBus.player_level_changed.emit(2)
	var ok: bool = PerkManager.select_perk("nonexistent_perk_id")
	assert_false(ok)

func test_multiple_levelups_queue() -> void:
	EventBus.player_level_changed.emit(2)
	EventBus.player_level_changed.emit(3)
	# 第一次 offer 已发出,第二次进队列
	assert_eq(PerkManager._pending_levelups, 1)

func test_select_triggers_next_offer() -> void:
	# 模拟两次升级排队 → 选完第一个后第二个自动弹出
	EventBus.player_level_changed.emit(2)
	EventBus.player_level_changed.emit(3)
	var first_offer: Array = PerkManager.get_current_offer()
	var first_perk_id: String = first_offer[0].id
	PerkManager.select_perk(first_perk_id)
	# 选完后 _current_offer 应该重新被填(因为 _pending_levelups 还有)
	var next_offer: Array = PerkManager.get_current_offer()
	assert_eq(next_offer.size(), 3)

func test_reset_clears_state() -> void:
	EventBus.player_level_changed.emit(2)
	EventBus.player_level_changed.emit(3)
	PerkManager.reset()
	assert_eq(PerkManager.get_current_offer().size(), 0)
	assert_false(PerkManager.has_pending())
```

- [ ] **Step 4: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_perk_manager.gd -gexit
```

期望: 7 passing。如果出现 PerkManager 未注册错误,确认 project.godot 的 [autoload] 段是否正确。

- [ ] **Step 5: 提交**

```bash
git add scripts/core/perk_manager.gd project.godot tests/unit/test_perk_manager.gd
git commit -m "feat: PerkManager Autoload — 升级 3 选 1 perk 抽取与应用"
```

---

### Task 10: TowerRollManager — Tier 抽卡 + 动态权重

**Files:**
- Create: `scripts/systems/tower_roll_manager.gd`
- Create: `tests/unit/test_tower_roll_manager.gd`

- [ ] **Step 1: 创建 TowerRollManager**

Create `scripts/systems/tower_roll_manager.gd`:

```gdscript
class_name TowerRollManager
extends RefCounted

## Roll 塔管理器 — 替代旧 ShopManager
##
## 职责:
##   - 加载 TierWeightTable
##   - 按英雄等级 + 动态权重抽 3 个 tower_id

const TIER_WEIGHT_TABLE_PATH: String = "res://resources/shop/tier_weight_table.tres"

var _tier_table: TierWeightTable = null

func _init() -> void:
	_tier_table = load(TIER_WEIGHT_TABLE_PATH)

## 抽 3 个候选(可重复),按英雄等级 + 动态权重
func roll_three(player_level: int) -> Array:
	var result: Array = []
	for i in 3:
		var picked: String = _roll_one(player_level)
		if picked != "":
			result.append(picked)
	return result

func _roll_one(player_level: int) -> String:
	var tier_weights: Array = _tier_table.get_tier_weights(player_level) if _tier_table else [1.0, 0.0, 0.0, 0.0]
	# 第一步:按 Tier 权重选 Tier
	var picked_tier: int = _weighted_pick(tier_weights) + 1
	# 第二步:在该 Tier 内按基础权重 × 动态权重选塔
	var candidates: Array = _towers_of_tier(picked_tier)
	if candidates.is_empty():
		# 若该 Tier 无塔,降到 Tier 1 兜底
		candidates = _towers_of_tier(1)
		if candidates.is_empty():
			return ""
	var weights: Array = []
	var dynamic_mult: float = GameConfig.shop_config.dynamic_weight_multiplier
	for tower_id in candidates:
		var w: float = 1.0
		if _has_unleveled_deployed(tower_id):
			w *= dynamic_mult
		weights.append(w)
	var pick_idx: int = _weighted_pick(weights)
	return candidates[pick_idx]

func _towers_of_tier(tier: int) -> Array:
	var result: Array = []
	for tower_id: String in GameConfig.towers:
		var data: TowerData = GameConfig.towers[tower_id]
		if data and data.tier == tier:
			result.append(tower_id)
	return result

func _has_unleveled_deployed(tower_id: String) -> bool:
	# 已部署中存在 < Lv3 的同 id 同 lvl 塔时,加权
	for entry in InventoryManager.deployed_towers:
		if entry.id == tower_id and entry.level < 3:
			return true
	return false

func _weighted_pick(weights: Array) -> int:
	var total: float = 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return 0
	var r: float = randf() * total
	var acc: float = 0.0
	for i in weights.size():
		acc += weights[i]
		if r <= acc:
			return i
	return weights.size() - 1
```

- [ ] **Step 2: 写测试**

Create `tests/unit/test_tower_roll_manager.gd`:

```gdscript
extends GutTest

var _mgr: TowerRollManager = null

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	_mgr = TowerRollManager.new()

func test_roll_three_returns_three_ids() -> void:
	var result: Array = _mgr.roll_three(1)
	assert_eq(result.size(), 3)
	for tower_id in result:
		assert_true(GameConfig.towers.has(tower_id), "未知 tower_id: " + str(tower_id))

func test_roll_can_repeat_same_tower() -> void:
	# 大量 roll,期望出现至少一次重复(3 座塔随机抽 3 张)
	var seen_dup: bool = false
	for i in 30:
		var r: Array = _mgr.roll_three(1)
		var unique: Dictionary = {}
		for tid in r:
			unique[tid] = true
		if unique.size() < r.size():
			seen_dup = true
			break
	assert_true(seen_dup, "30 轮 roll 应至少出现 1 次重复")

func test_dynamic_weight_favors_deployed() -> void:
	# 部署 5 座 pea_shooter,期望 pea_shooter 的 roll 比例显著上升
	for i in 5:
		InventoryManager.deployed_towers.append({
			id = "pea_shooter", level = 1,
			grid_pos = Vector2i(i, 0), deploy_id = i + 1,
		})
	var pea_count: int = 0
	var total: int = 0
	for i in 100:
		var r: Array = _mgr.roll_three(1)
		for tid in r:
			total += 1
			if tid == "pea_shooter":
				pea_count += 1
	# 3 座塔均匀概率 1/3 ≈ 33%,加权后应 > 40%
	var ratio: float = float(pea_count) / float(total)
	assert_gt(ratio, 0.4, "pea_shooter 应该被显著加权,实际比例: " + str(ratio))

func test_lv3_deployed_does_not_boost_weight() -> void:
	# 部署 Lv3 满级 pea_shooter — 不应加权
	InventoryManager.deployed_towers.append({
		id = "pea_shooter", level = 3,
		grid_pos = Vector2i(0, 0), deploy_id = 1,
	})
	# 此处只验证函数返回正确(不再加权)
	assert_false(_mgr._has_unleveled_deployed("pea_shooter"))
```

- [ ] **Step 3: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_tower_roll_manager.gd -gexit
```

期望: 4 passing。

- [ ] **Step 4: 提交**

```bash
git add scripts/systems/tower_roll_manager.gd tests/unit/test_tower_roll_manager.gd
git commit -m "feat: TowerRollManager — Tier 抽卡 + 动态权重"
```

---

### Task 11: InventoryManager 加 pending_towers + Roll API

**Files:**
- Modify: `scripts/core/inventory_manager.gd`
- Test: `tests/unit/test_inventory_pending.gd`(新建)

- [ ] **Step 1: 在 InventoryManager 顶部加 pending 状态**

在 `var _next_deploy_id: int = 1` 后追加:

```gdscript
# 待建造栏(roll 出来选的塔卡片,等待拖到地图上放置)
var pending_towers: Array[String] = []  # 元素是 tower_id

# Roll 管理器(惰性初始化)
var _roll_manager: TowerRollManager = null

# 当前 Roll 出来的 3 个候选(等待玩家从中选 1)
var _current_roll_offer: Array[String] = []
```

- [ ] **Step 2: 在文件末尾追加 Roll API**

```gdscript
# ===== Roll / Pending 管理 =====

func _get_roll_manager() -> TowerRollManager:
	if _roll_manager == null:
		_roll_manager = TowerRollManager.new()
	return _roll_manager

## 触发一次 Roll:扣金币 + 抽 3 个候选 + 发信号
## 调用前应先用 can_roll() 检查
func roll_tower() -> bool:
	var cost: int = GameConfig.shop_config.roll_cost
	if coins < cost:
		return false
	if pending_towers.size() >= GameConfig.shop_config.pending_queue_size:
		return false
	if not _current_roll_offer.is_empty():
		return false  # 已有未决 offer
	coins -= cost
	EventBus.coins_changed.emit(-cost, coins)
	_current_roll_offer = []
	for tid in _get_roll_manager().roll_three(PlayerProgression.player_level):
		_current_roll_offer.append(tid)
	EventBus.tower_rolled.emit(_current_roll_offer.duplicate())
	return true

## 玩家从 3 选 1 中确认选择,加入 pending_towers
func confirm_roll_pick(candidate_index: int) -> bool:
	if candidate_index < 0 or candidate_index >= _current_roll_offer.size():
		return false
	var tower_id: String = _current_roll_offer[candidate_index]
	pending_towers.append(tower_id)
	_current_roll_offer = []
	EventBus.tower_added_to_queue.emit(tower_id)
	return true

## 玩家点取消 → 退还 roll 费用,清空 offer
func cancel_roll() -> void:
	if _current_roll_offer.is_empty():
		return
	var refund: int = GameConfig.shop_config.roll_cost
	coins += refund
	EventBus.coins_changed.emit(refund, coins)
	_current_roll_offer = []
	EventBus.tower_roll_canceled.emit()

## 从待建造栏取出 1 个 tower_id 用于放置(放置成功调)
func consume_pending(index: int) -> String:
	if index < 0 or index >= pending_towers.size():
		return ""
	var tid: String = pending_towers[index]
	pending_towers.remove_at(index)
	EventBus.tower_consumed_from_queue.emit(index)
	return tid

func can_roll() -> bool:
	return (coins >= GameConfig.shop_config.roll_cost
		and pending_towers.size() < GameConfig.shop_config.pending_queue_size
		and _current_roll_offer.is_empty())

func get_current_roll_offer() -> Array[String]:
	return _current_roll_offer.duplicate()
```

- [ ] **Step 3: 修改 reset() 清理 pending 状态**

修改 `reset()`,在 `_next_deploy_id = 1` 之后追加:

```gdscript
	pending_towers = []
	_current_roll_offer = []
	# _roll_manager 复用,不清
```

- [ ] **Step 4: 修改 sell 返还为 70%**

修改 `_apply_sell` 函数:

```gdscript
func _apply_sell(item: Dictionary) -> int:
	var data: Resource
	if item.type == "weapon":
		data = GameConfig.weapons[item.id]
	else:
		data = GameConfig.towers[item.id]
	var base_value: int = data.sell_price_per_level[item.level - 1]
	var ratio: float = GameConfig.shop_config.sell_return_ratio
	var refund: int = int(round(base_value * ratio))
	coins += refund
	EventBus.item_sold.emit(item, refund)
	EventBus.coins_changed.emit(refund, coins)
	return refund
```

- [ ] **Step 5: 写测试**

Create `tests/unit/test_inventory_pending.gd`:

```gdscript
extends GutTest

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	InventoryManager.coins = 100
	InventoryManager.pending_towers = []
	InventoryManager._current_roll_offer = []

func test_roll_deducts_cost_and_offers_three() -> void:
	var ok: bool = InventoryManager.roll_tower()
	assert_true(ok)
	assert_eq(InventoryManager.coins, 100 - GameConfig.shop_config.roll_cost)
	assert_eq(InventoryManager.get_current_roll_offer().size(), 3)

func test_roll_blocked_when_no_coins() -> void:
	InventoryManager.coins = 0
	var ok: bool = InventoryManager.roll_tower()
	assert_false(ok)

func test_roll_blocked_when_pending_full() -> void:
	for i in GameConfig.shop_config.pending_queue_size:
		InventoryManager.pending_towers.append("pea_shooter")
	var ok: bool = InventoryManager.roll_tower()
	assert_false(ok)

func test_confirm_pick_adds_to_pending() -> void:
	InventoryManager.roll_tower()
	var picked_id: String = InventoryManager.get_current_roll_offer()[0]
	InventoryManager.confirm_roll_pick(0)
	assert_eq(InventoryManager.pending_towers.size(), 1)
	assert_eq(InventoryManager.pending_towers[0], picked_id)
	assert_eq(InventoryManager.get_current_roll_offer().size(), 0)

func test_cancel_refunds_cost() -> void:
	var pre: int = InventoryManager.coins
	InventoryManager.roll_tower()
	InventoryManager.cancel_roll()
	assert_eq(InventoryManager.coins, pre)
	assert_eq(InventoryManager.get_current_roll_offer().size(), 0)

func test_consume_pending_removes_and_returns_id() -> void:
	InventoryManager.pending_towers = ["pea_shooter", "ice_flower"]
	var tid: String = InventoryManager.consume_pending(0)
	assert_eq(tid, "pea_shooter")
	assert_eq(InventoryManager.pending_towers.size(), 1)
	assert_eq(InventoryManager.pending_towers[0], "ice_flower")

func test_consume_pending_invalid_index() -> void:
	var tid: String = InventoryManager.consume_pending(5)
	assert_eq(tid, "")

func test_sell_returns_70_percent() -> void:
	# 部署一座 lv1 pea_shooter
	InventoryManager.deployed_towers.append({
		id = "pea_shooter", level = 1,
		grid_pos = Vector2i(0, 0), deploy_id = 1,
	})
	var pre: int = InventoryManager.coins
	var data: TowerData = GameConfig.towers["pea_shooter"]
	var base_value: int = data.sell_price_per_level[0]
	var refund: int = InventoryManager.sell_from_deployed_tower(1)
	assert_eq(refund, int(round(base_value * 0.7)))
	assert_eq(InventoryManager.coins, pre + refund)

func test_reset_clears_pending() -> void:
	InventoryManager.pending_towers = ["pea_shooter"]
	InventoryManager._current_roll_offer = ["ice_flower", "sunflower", "pea_shooter"]
	InventoryManager.reset()
	assert_eq(InventoryManager.pending_towers.size(), 0)
	assert_eq(InventoryManager.get_current_roll_offer().size(), 0)
```

- [ ] **Step 6: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_pending.gd -gexit
```

期望: 9 passing。

- [ ] **Step 7: 提交**

```bash
git add scripts/core/inventory_manager.gd tests/unit/test_inventory_pending.gd
git commit -m "feat: InventoryManager 新增 pending_towers + Roll API + 70% 卖出"
```

---

## Phase C — 各组件读取 perk bonus

### Task 12: Player 应用 hp / move_speed / pickup_radius perk bonus

**Files:**
- Modify: `scripts/entities/player.gd:25-65`、`:140-156`

- [ ] **Step 1: 修改 _ready 初始化最大生命应用 hp_bonus**

修改 player.gd `_ready` 中初始化最大生命部分,把 perk bonus 也乘进去。

找到:
```gdscript
var max_hp: float = PlayerState.player_stats[Enums.Stat.MAX_HP] * PlayerState.player_stats[Enums.Stat.HP_MULT]
health.initialize(max_hp)
```

替换为:
```gdscript
var hp_perk: float = PlayerState.player_stats.get(Enums.Stat.HP_BONUS_PERCENT, 0.0)
var max_hp: float = PlayerState.player_stats[Enums.Stat.MAX_HP] * PlayerState.player_stats[Enums.Stat.HP_MULT] * (1.0 + hp_perk)
health.initialize(max_hp)
```

- [ ] **Step 2: 修改 _apply_level_growth 应用 move_speed / pickup bonus**

找到 `_apply_level_growth` 的最后两行(speed 和 pickup_range_mult):

```gdscript
var speed_mult: float = pow(1.0 + LEVEL_SPEED_GROWTH, levels_gained)
speed = _base_speed * speed_mult
# 拾取范围成长(复利)
pickup_range_mult = pow(1.0 + LEVEL_PICKUP_GROWTH, levels_gained)
```

替换为:
```gdscript
var speed_mult: float = pow(1.0 + LEVEL_SPEED_GROWTH, levels_gained)
var move_perk: float = PlayerState.player_stats.get(Enums.Stat.MOVE_SPEED_BONUS_PERCENT, 0.0)
speed = _base_speed * speed_mult * (1.0 + move_perk)
# 拾取范围成长(复利)
var pickup_perk: float = PlayerState.player_stats.get(Enums.Stat.PICKUP_RADIUS_BONUS_PERCENT, 0.0)
pickup_range_mult = pow(1.0 + LEVEL_PICKUP_GROWTH, levels_gained) * (1.0 + pickup_perk)
```

- [ ] **Step 3: 监听 perk_applied 即时刷新**

在 `_ready()` 末尾(`_apply_level_growth(PlayerProgression.player_level)` 那行后)追加:

```gdscript
EventBus.perk_applied.connect(_on_perk_applied)
```

在文件末尾追加方法:

```gdscript
func _on_perk_applied(_perk_id: String) -> void:
	# 即时应用 perk 加成(避免等到下次升级才生效)
	# 重新跑等级成长公式即可,会读取最新 perk bonus
	_apply_level_growth(PlayerProgression.player_level)
	# HP 上限也同步
	var hp_perk: float = PlayerState.player_stats.get(Enums.Stat.HP_BONUS_PERCENT, 0.0)
	var new_max: float = _base_max_hp * (1.0 + hp_perk)
	# Lv1 时 _apply_level_growth 不跑,这里兜底处理
	if PlayerProgression.player_level == 1:
		var hp_diff: float = new_max - health.max_hp
		health.max_hp = new_max
		if hp_diff > 0:
			health.heal(hp_diff)
```

- [ ] **Step 4: 提交**

```bash
git add scripts/entities/player.gd
git commit -m "feat: Player 应用 hp / move_speed / pickup_radius perk bonus"
```

---

### Task 13: Enemy 掉金币应用 coin_drop_bonus_percent

**Files:**
- Modify: `scripts/entities/enemy.gd`(找到 `_drop_exp_orbs` 附近,补 coin 掉落入口)

- [ ] **Step 1: 检查 enemy.gd 当前金币掉落实现**

读 `scripts/entities/enemy.gd`(完整文件),搜 `coin` 字样,确认掉金币的逻辑在哪里。当前 enemy 自身不直接掉金币,金币掉落由其他模块处理。

如果 enemy.gd 中找不到 coin 相关方法:用 Grep 搜整个项目:

`grep -rn "create_coin\|EnemyData.*coin" scripts/`

定位到掉金币的实际入口(可能在 SceneFactory.create_coin 调用方,或 wave_manager 中的处理)。

- [ ] **Step 2: 在掉金币入口应用 coin_drop_bonus**

在掉金币的实际位置(假设在 enemy.gd 的某 `_drop_coins` 方法,或 wave_manager 等),金币数量计算改为:

```gdscript
var base_count: int = data.coin_drop_count  # 假设 EnemyData 有此字段
var bonus: float = PlayerState.player_stats.get(Enums.Stat.COIN_DROP_BONUS_PERCENT, 0.0)
var actual: int = int(round(base_count * (1.0 + bonus)))
```

如果当前金币只有"数量"维度,处理 actual。
如果当前金币是"价值",则把价值乘 (1 + bonus)。

具体实现以现有代码为准。

> **如果实施时发现 enemy.gd 自己不掉金币**(全靠塔生成或波次奖励):
> - #1 阶段去掉了波次奖励,coin_drop_bonus 在 #1 阶段实际没作用对象 — 但仍然要保留字段为后续敌人掉金币机制做准备
> - 在 enemy.gd 中加 TODO 注释("coin_drop_bonus 应用入口待 #5 敌人调整时接入"),不要硬塞逻辑

- [ ] **Step 3: 写测试(若实际有掉落入口)**

如果实际找到掉金币代码,Create `tests/unit/test_enemy_coin_drop_bonus.gd`:

```gdscript
extends GutTest

func before_each() -> void:
	PlayerState.reset()

func test_coin_drop_bonus_multiplies_count() -> void:
	# 此测试需根据 Step 2 实际入口写,无入口则跳过
	pending("待 enemy 实际掉金币入口确认后补测")
```

如无掉落入口,提交时不要包含此 test 文件。

- [ ] **Step 4: 提交**

```bash
git add scripts/entities/enemy.gd  # 若改了
# 若有 test: git add tests/unit/test_enemy_coin_drop_bonus.gd
git commit -m "feat: enemy 掉金币应用 coin_drop_bonus(若有入口)"
```

如果 Step 1 发现项目中确实没有"敌人掉金币"路径,跳过这个 task,在执行报告中注明。

---

### Task 14: 攻击组件应用 damage / attack_speed perk bonus

**Files:**
- Modify: `scripts/components/ranged_attack_component.gd:58-65`
- Modify: `scripts/components/melee_attack_component.gd:56-63`

- [ ] **Step 1: 修改 RangedAttackComponent.get_final_damage / get_final_cooldown**

替换 `get_final_damage` 和 `get_final_cooldown`:

```gdscript
func get_final_damage() -> float:
	var perk_bonus: float = PlayerState.player_stats.get(Enums.Stat.DAMAGE_BONUS_PERCENT, 0.0)
	return _base_damage * damage_multiplier * (1.0 + perk_bonus)

func get_final_cooldown() -> float:
	var perk_bonus: float = PlayerState.player_stats.get(Enums.Stat.ATTACK_SPEED_BONUS_PERCENT, 0.0)
	var spd: float = speed_multiplier * (1.0 + perk_bonus)
	if spd <= 0.0:
		return _base_cooldown
	return _base_cooldown / spd
```

注意:塔的攻击组件不应受玩家 perk 影响(perk 是英雄成长)。但当前代码塔和武器复用同一个 RangedAttackComponent,需要区分。

**简化决策**: #1 阶段塔也享受 perk(数值小),后续 #2 时再分离武器/塔的 attack 组件读取来源。

- [ ] **Step 2: 修改 MeleeAttackComponent 同样**

替换 `get_final_damage` 和 `get_final_cooldown` 同上(MeleeAttackComponent 只有武器用,所以 perk 应用是正确的)。

- [ ] **Step 3: 扩展现有测试**

Append to `tests/unit/test_ranged_attack_component.gd`(若存在;若不存在则创建):

```gdscript
# ===== Perk bonus 应用 =====

func test_damage_bonus_applied() -> void:
	PlayerState.reset()
	var comp := RangedAttackComponent.new()
	comp._base_damage = 10.0
	comp.damage_multiplier = 1.0
	PlayerState.player_stats[Enums.Stat.DAMAGE_BONUS_PERCENT] = 0.5
	assert_almost_eq(comp.get_final_damage(), 15.0, 0.01)

func test_attack_speed_bonus_reduces_cooldown() -> void:
	PlayerState.reset()
	var comp := RangedAttackComponent.new()
	comp._base_cooldown = 1.0
	comp.speed_multiplier = 1.0
	PlayerState.player_stats[Enums.Stat.ATTACK_SPEED_BONUS_PERCENT] = 1.0  # +100%
	assert_almost_eq(comp.get_final_cooldown(), 0.5, 0.01)
```

Append to `tests/unit/test_melee_attack_component.gd` 类似两个测试(对应 MeleeAttackComponent)。

- [ ] **Step 4: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ranged_attack_component.gd -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_melee_attack_component.gd -gexit
```

期望: 各 +2 passing。

- [ ] **Step 5: 提交**

```bash
git add scripts/components/ranged_attack_component.gd scripts/components/melee_attack_component.gd tests/unit/test_ranged_attack_component.gd tests/unit/test_melee_attack_component.gd
git commit -m "feat: 攻击组件应用 damage / attack_speed perk bonus"
```

---

## Phase D — UI

### Task 15: PerkSelectionOverlay — 升级 3 选 1 暂停弹窗

**Files:**
- Create: `scripts/ui/perk_selection_overlay.gd`
- Create: `scenes/ui/perk_selection_overlay.tscn`

- [ ] **Step 1: 创建 perk_selection_overlay.gd**

Create `scripts/ui/perk_selection_overlay.gd`:

```gdscript
extends CanvasLayer
## 升级 3 选 1 暂停弹窗
##
## - 监听 EventBus.perk_offered → 弹出 + 设置 paused
## - 玩家点选一张卡 → PerkManager.select_perk(id) → 关闭面板 + paused=false
## - process_mode = ALWAYS,不被暂停影响

const CARD_SIZE := Vector2(180, 240)

var _root: Control
var _card_buttons: Array[Button] = []
var _card_titles: Array[Label] = []
var _card_descs: Array[Label] = []
var _current_offer: Array = []

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	EventBus.perk_offered.connect(_on_perk_offered)

func _build_ui() -> void:
	# 半透明遮罩
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_root = bg

	# 标题
	var title := Label.new()
	title.text = "升级!选一个加成"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position.y = 80
	bg.add_child(title)

	# 3 张卡片
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.position = Vector2(-CARD_SIZE.x * 1.5 - 16, -CARD_SIZE.y * 0.5)
	bg.add_child(hbox)

	for i in 3:
		var card := _create_card(i)
		hbox.add_child(card)

func _create_card(idx: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_SIZE
	btn.flat = false
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_card_titles.append(title)

	var desc := Label.new()
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(CARD_SIZE.x - 20, 0)
	vbox.add_child(desc)
	_card_descs.append(desc)

	btn.pressed.connect(_on_card_pressed.bind(idx))
	_card_buttons.append(btn)
	return btn

func _on_perk_offered(perks: Array) -> void:
	_current_offer = perks
	for i in 3:
		if i < perks.size():
			var p: PerkData = perks[i]
			_card_titles[i].text = p.display_name
			_card_descs[i].text = p.description
			_card_buttons[i].visible = true
			_card_buttons[i].disabled = false
		else:
			_card_buttons[i].visible = false
	visible = true
	get_tree().paused = true

func _on_card_pressed(idx: int) -> void:
	if idx < 0 or idx >= _current_offer.size():
		return
	var perk: PerkData = _current_offer[idx]
	PerkManager.select_perk(perk.id)
	# 检查是否还有排队的升级 — 若有,PerkManager 会自动 emit 下一个 perk_offered
	if PerkManager.has_pending():
		# 等待下一个 offer 弹窗(_on_perk_offered 会立即被再次调用)
		return
	# 否则关闭面板并恢复
	visible = false
	get_tree().paused = false
```

- [ ] **Step 2: 创建场景**

`scenes/ui/perk_selection_overlay.tscn`(全代码生成,场景文件最小):

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/perk_selection_overlay.gd" id="1"]

[node name="PerkSelectionOverlay" type="CanvasLayer"]
layer = 50
script = ExtResource("1")
```

- [ ] **Step 3: 简单连通性验证(不写 UI 自动化测试,人工跑游戏验证)**

执行测试套件确保不破现有:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

期望: 全绿(若有 ShopManager / ShopOverlay 旧测试因为还没删可能仍然过)。

- [ ] **Step 4: 提交**

```bash
git add scripts/ui/perk_selection_overlay.gd scenes/ui/perk_selection_overlay.tscn
git commit -m "feat: PerkSelectionOverlay — 升级 3 选 1 暂停弹窗"
```

---

### Task 16: TowerRollOverlay — Roll 时 3 选 1 塔卡片(取消退款)

**Files:**
- Create: `scripts/ui/tower_roll_overlay.gd`
- Create: `scenes/ui/tower_roll_overlay.tscn`

- [ ] **Step 1: 创建 tower_roll_overlay.gd**

Create `scripts/ui/tower_roll_overlay.gd`:

```gdscript
extends CanvasLayer
## Roll 时弹出的 3 选 1 塔卡片面板
##
## 不暂停游戏,玩家可以选 1 张或取消(取消退款)。
## 监听 EventBus.tower_rolled → 弹出 → 玩家点卡 → 调 InventoryManager.confirm_roll_pick

const CARD_SIZE := Vector2(120, 160)

var _root: Control
var _card_buttons: Array[Button] = []
var _card_icons: Array[TextureRect] = []
var _card_names: Array[Label] = []
var _cancel_btn: Button
var _current_offer: Array[String] = []

func _ready() -> void:
	layer = 40
	_build_ui()
	visible = false
	EventBus.tower_rolled.connect(_on_tower_rolled)

func _build_ui() -> void:
	# 半透明背景(可点空白处不取消,需点取消按钮)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.4)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_root = bg

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Roll 出 3 张,选一张"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)
	for i in 3:
		hbox.add_child(_create_card(i))

	_cancel_btn = Button.new()
	_cancel_btn.text = "取消(退款)"
	_cancel_btn.custom_minimum_size = Vector2(140, 32)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	vbox.add_child(_cancel_btn)

func _create_card(idx: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_SIZE
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)
	_card_icons.append(icon)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	_card_names.append(name_label)

	btn.pressed.connect(_on_card_pressed.bind(idx))
	_card_buttons.append(btn)
	return btn

func _on_tower_rolled(candidates: Array) -> void:
	_current_offer.clear()
	for c in candidates:
		_current_offer.append(c)
	for i in 3:
		if i < _current_offer.size():
			var tid: String = _current_offer[i]
			var data: TowerData = GameConfig.towers.get(tid)
			_card_names[i].text = data.display_name if data else tid
			if data and data.icon_path != "" and ResourceLoader.exists(data.icon_path):
				_card_icons[i].texture = load(data.icon_path)
			else:
				_card_icons[i].texture = null
			_card_buttons[i].visible = true
		else:
			_card_buttons[i].visible = false
	visible = true

func _on_card_pressed(idx: int) -> void:
	InventoryManager.confirm_roll_pick(idx)
	visible = false

func _on_cancel_pressed() -> void:
	InventoryManager.cancel_roll()
	visible = false
```

- [ ] **Step 2: 创建场景**

`scenes/ui/tower_roll_overlay.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/tower_roll_overlay.gd" id="1"]

[node name="TowerRollOverlay" type="CanvasLayer"]
layer = 40
script = ExtResource("1")
```

- [ ] **Step 3: 提交**

```bash
git add scripts/ui/tower_roll_overlay.gd scenes/ui/tower_roll_overlay.tscn
git commit -m "feat: TowerRollOverlay — Roll 时 3 选 1 塔卡片"
```

---

### Task 17: PendingQueuePanel — 待建造栏(3 槽,拖拽源)

**Files:**
- Create: `scripts/ui/pending_queue_panel.gd`
- Create: `scenes/ui/pending_queue_panel.tscn`

- [ ] **Step 1: 创建 pending_queue_panel.gd**

Create `scripts/ui/pending_queue_panel.gd`:

```gdscript
extends Control
## 待建造栏 — 3 槽水平排列
##
## - 监听 tower_added_to_queue / tower_consumed_from_queue 刷新
## - 点击槽位 → 调 drag_manager.start_tower_placement(tower_id, on_placed, on_cancelled)
##   on_placed 回调时,从 InventoryManager 消费该槽位
##
## drag_manager 由父组件(BattleHUD)注入

const SLOT_SIZE := Vector2(56, 72)

var drag_manager: Node = null  # 外部注入

var _slot_buttons: Array[Button] = []
var _slot_icons: Array[TextureRect] = []
var _slot_names: Array[Label] = []
var _placing_index: int = -1

func _ready() -> void:
	_build_ui()
	EventBus.tower_added_to_queue.connect(_refresh)
	EventBus.tower_consumed_from_queue.connect(func(_idx: int) -> void: _refresh())
	_refresh()

func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.add_theme_constant_override("separation", 6)
	add_child(hbox)
	for i in GameConfig.shop_config.pending_queue_size:
		hbox.add_child(_create_slot(i))

func _create_slot(idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = SLOT_SIZE
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)
	_slot_icons.append(icon)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	_slot_names.append(name_label)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_slot_pressed.bind(idx))
	panel.add_child(btn)
	_slot_buttons.append(btn)
	return panel

func _refresh() -> void:
	for i in _slot_buttons.size():
		if i < InventoryManager.pending_towers.size():
			var tid: String = InventoryManager.pending_towers[i]
			var data: TowerData = GameConfig.towers.get(tid)
			_slot_names[i].text = data.display_name if data else tid
			if data and data.icon_path != "" and ResourceLoader.exists(data.icon_path):
				_slot_icons[i].texture = load(data.icon_path)
			else:
				_slot_icons[i].texture = null
			_slot_buttons[i].disabled = false
			_slot_buttons[i].modulate = Color.WHITE
		else:
			_slot_icons[i].texture = null
			_slot_names[i].text = "空"
			_slot_buttons[i].disabled = true
			_slot_buttons[i].modulate = Color(0.4, 0.4, 0.4)

func _on_slot_pressed(idx: int) -> void:
	if drag_manager == null:
		push_warning("PendingQueuePanel: drag_manager 未注入")
		return
	if idx >= InventoryManager.pending_towers.size():
		return
	if _placing_index >= 0:
		return  # 正在放置另一张
	_placing_index = idx
	var tower_id: String = InventoryManager.pending_towers[idx]
	drag_manager.start_tower_placement(
		tower_id,
		_on_placed,
		_on_cancelled,
	)

func _on_placed(grid_pos: Vector2i) -> void:
	if _placing_index < 0:
		return
	var tower_id: String = InventoryManager.consume_pending(_placing_index)
	if tower_id != "":
		# 实际部署:调 InventoryManager.buy_and_place_tower 但 cost=0(已经在 roll 时扣过)
		# 走一个简化分支:直接 deployed_towers.append + 生成节点
		var deploy_id: int = InventoryManager._next_deploy_id
		InventoryManager._next_deploy_id += 1
		InventoryManager.deployed_towers.append({
			id = tower_id, level = 1,
			grid_pos = grid_pos, deploy_id = deploy_id,
		})
		drag_manager.spawn_tower_node(deploy_id, tower_id, 1, grid_pos)
		EventBus.tower_placed.emit(tower_id, Vector2(grid_pos))
		EventBus.item_purchased.emit({id = tower_id, type = "tower", level = 1})
	_placing_index = -1
	_refresh()

func _on_cancelled() -> void:
	# 玩家取消放置 → pending 不消费,卡片回到栏内
	_placing_index = -1
	_refresh()
```

- [ ] **Step 2: 创建场景**

`scenes/ui/pending_queue_panel.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/pending_queue_panel.gd" id="1"]

[node name="PendingQueuePanel" type="Control"]
custom_minimum_size = Vector2(200, 80)
script = ExtResource("1")
```

- [ ] **Step 3: 提交**

```bash
git add scripts/ui/pending_queue_panel.gd scenes/ui/pending_queue_panel.tscn
git commit -m "feat: PendingQueuePanel — 待建造栏 3 槽 + 点击放置"
```

---

### Task 18: 修改塔点击浮窗:去掉合成入口(改为自动)+ 保留卖出 / 移动

**Files:**
- Modify: `scripts/systems/drag_manager.gd:93-141`

> 文档说"合成自动触发,不设手动升级按钮"。当前代码的塔菜单有"合成 / 卖出 / 移动"三项,需移除"合成"项,并在自动判定满足合成条件时直接调 `_check_merge`。

- [ ] **Step 1: 修改 _show_tower_menu — 移除合成项**

替换 `_show_tower_menu` 函数(去掉合成选项部分):

```gdscript
func _show_tower_menu(deploy_id: int) -> void:
	_menu_deploy_id = deploy_id
	if _tower_menu == null:
		_tower_menu = PopupMenu.new()
		_tower_menu.name = "TowerMenu"
		_tower_menu.id_pressed.connect(_on_tower_menu_pressed)
		add_child(_tower_menu)
	_tower_menu.clear()
	var entry: Dictionary = {}
	for t in InventoryManager.deployed_towers:
		if t.deploy_id == deploy_id:
			entry = t
			break
	if entry.is_empty():
		return
	# 卖出选项(70% 返还,InventoryManager._apply_sell 已实现)
	var tower_data: TowerData = GameConfig.towers.get(entry.id)
	var base_value: int = tower_data.sell_price_per_level[entry.level - 1] if tower_data else 0
	var refund_preview: int = int(round(base_value * GameConfig.shop_config.sell_return_ratio))
	_tower_menu.add_item("卖出 $%d" % refund_preview, 1)
	# 移动选项
	_tower_menu.add_item("移动", 2)
	var tower_node: Node2D = _tower_nodes[deploy_id]
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * tower_node.global_position
	_tower_menu.position = Vector2i(int(screen_pos.x), int(screen_pos.y) - 60)
	_tower_menu.popup()
```

- [ ] **Step 2: 修改 _on_tower_menu_pressed — 移除合成分支**

```gdscript
func _on_tower_menu_pressed(id: int) -> void:
	var deploy_id: int = _menu_deploy_id
	match id:
		1:  # 卖出
			var refund: int = InventoryManager.sell_from_deployed_tower(deploy_id)
			if refund > 0:
				_remove_tower_node(deploy_id)
		2:  # 移动
			start_move_tower(deploy_id)
	_menu_deploy_id = -1
```

可以删除整个 `_handle_tower_merge_visual` 方法(不再被调用)。

- [ ] **Step 3: 重写 PendingQueuePanel._on_placed 加自动合成视觉处理**

放置后立刻调 `_check_merge` 检查 2 合 1。比对前后 deployed_towers 差异,让 drag_manager 同步移除 / 升级节点。

> 注意: `InventoryManager.buy_and_place_tower` 在新流程下不再被调用(Roll 路径走 PendingQueuePanel),不需要给它加 `_check_merge`。所有合成处理集中在 PendingQueuePanel。

替换 `scripts/ui/pending_queue_panel.gd` 的 `_on_placed` 函数为:

```gdscript
func _on_placed(grid_pos: Vector2i) -> void:
	if _placing_index < 0:
		return
	var tower_id: String = InventoryManager.consume_pending(_placing_index)
	if tower_id != "":
		# 备份合成前状态
		var old_towers: Array = InventoryManager.deployed_towers.duplicate(true)
		# 部署新塔(走数据 + 视觉)
		var deploy_id: int = InventoryManager._next_deploy_id
		InventoryManager._next_deploy_id += 1
		InventoryManager.deployed_towers.append({
			id = tower_id, level = 1,
			grid_pos = grid_pos, deploy_id = deploy_id,
		})
		drag_manager.spawn_tower_node(deploy_id, tower_id, 1, grid_pos)
		EventBus.tower_placed.emit(tower_id, Vector2(grid_pos))
		EventBus.item_purchased.emit({id = tower_id, type = "tower", level = 1})
		# 自动 2 合 1 检查
		InventoryManager._check_merge(tower_id, 1)
		_sync_merge_visuals(old_towers, deploy_id, grid_pos)
	_placing_index = -1
	_refresh()

func _sync_merge_visuals(old_towers: Array, just_placed_deploy_id: int, just_placed_grid_pos: Vector2i) -> void:
	# 1. 找出被合成掉的 deploy_id(old 里有但 new 里没有)→ 移除节点
	var current_ids: Array[int] = []
	for entry in InventoryManager.deployed_towers:
		current_ids.append(entry.deploy_id)
	for entry in old_towers:
		if entry.deploy_id not in current_ids:
			drag_manager._remove_tower_node(entry.deploy_id)
	# 还要处理刚 spawn 的那个(它在 old_towers 里也没有,但被 _check_merge 删掉了)
	if just_placed_deploy_id not in current_ids:
		drag_manager._remove_tower_node(just_placed_deploy_id)
	# 2. 找出升级了 level 的塔 → 替换节点
	for entry in InventoryManager.deployed_towers:
		for old in old_towers:
			if old.deploy_id == entry.deploy_id and old.level != entry.level:
				drag_manager.upgrade_tower_node(entry.deploy_id, entry.id, entry.level, entry.grid_pos)
				break
	# 3. 找出 _check_merge 留下的"新升级品"(deploy_id 不在 old 里,但在 new 里)
	#    该 deploy_id 复用了 just_placed_deploy_id,需要 spawn 升级后的节点
	for entry in InventoryManager.deployed_towers:
		var in_old: bool = false
		for old in old_towers:
			if old.deploy_id == entry.deploy_id:
				in_old = true
				break
		if not in_old and entry.deploy_id == just_placed_deploy_id and entry.level > 1:
			# 刚 spawn 的 Lv1 节点已被 _remove_tower_node 删掉,这里 spawn 升级后的节点
			drag_manager.spawn_tower_node(entry.deploy_id, entry.id, entry.level, entry.grid_pos)
```

> 实现说明:`InventoryManager._check_merge` 当前实现(`inventory_manager.gd:122-136`)是从 deployed_towers 尾部往前找,kept_tower_deploy_id 取**第一个找到的(尾部)**,即新放置的;然后 append 一个 Lv2 塔复用该 deploy_id。所以新放置的 deploy_id 在合并后**仍然存在**(只是 level 升级了),但**位置可能也变了**(看 _check_merge 用的 kept_tower_pos)。视觉处理上述 3 条覆盖。

- [ ] **Step 4: 提交**

```bash
git add scripts/systems/drag_manager.gd scripts/core/inventory_manager.gd scripts/ui/pending_queue_panel.gd
git commit -m "feat: 塔浮窗去掉手动合成,放置后自动 2 合 1"
```

---

### Task 19: BattleHUD — 整合战斗 HUD 主组件

**Files:**
- Create: `scripts/ui/battle_hud.gd`
- Create: `scenes/ui/battle_hud.tscn`

> BattleHUD 替代 ShopOverlay,整合:武器装备栏(从 ShopOverlay 迁入)+ Roll 按钮 + 待建造栏 + 信息栏(金币/等级/人口/波数 — 部分本来 HUD 也展示,这里增加 人口/波数)

- [ ] **Step 1: 创建 battle_hud.gd**

Create `scripts/ui/battle_hud.gd`:

```gdscript
extends CanvasLayer
## 战斗 HUD 主组件 — 替代旧 ShopOverlay
##
## 包含:
##   - 左侧: 武器装备栏(3x3,合成 / 卖出 菜单)
##   - 底部中央: Roll 按钮 + 待建造栏(实例化 PendingQueuePanel.tscn)
##   - 顶部右侧: 人口 / 波次 简要信息(金币 / 等级 / 经验 由现有 HUD 显示)
##
## 外部依赖:drag_manager / weapon_manager,由 main.gd 注入。
## 自身实例化 PendingQueuePanel,内部把 drag_manager 透传给它。

const WEAPON_ICON_SIZE := Vector2(28, 28)
const ROLL_BTN_SIZE := Vector2(120, 36)
const PENDING_PANEL_SCENE := preload("res://scenes/ui/pending_queue_panel.tscn")

var drag_manager: Node = null
var weapon_manager: WeaponManager = null

var _weapon_grid: GridContainer
var _weapon_menu: PopupMenu
var _menu_weapon_index: int = -1

var _roll_button: Button
var _pop_label: Label
var _pending_panel: Control

func _ready() -> void:
	layer = 10
	_build_ui()
	_refresh()
	EventBus.coins_changed.connect(func(_d: int, _t: int) -> void: _refresh_roll_button())
	EventBus.item_purchased.connect(func(_i: Dictionary) -> void: _refresh())
	EventBus.item_sold.connect(func(_i: Dictionary, _r: int) -> void: _refresh())
	EventBus.item_merged.connect(func(_id: String, _lvl: int) -> void: _refresh())
	EventBus.tower_added_to_queue.connect(func(_t: String) -> void: _refresh_roll_button())
	EventBus.tower_consumed_from_queue.connect(func(_i: int) -> void: _refresh_roll_button())
	EventBus.tower_roll_canceled.connect(func() -> void: _refresh_roll_button())

func _build_ui() -> void:
	# 左侧武器栏
	var left := PanelContainer.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.position = Vector2(8, 80)
	left.custom_minimum_size = Vector2(110, 0)
	add_child(left)

	var weapon_vbox := VBoxContainer.new()
	left.add_child(weapon_vbox)

	var weapon_label := Label.new()
	weapon_label.text = "武器"
	weapon_label.add_theme_font_size_override("font_size", 14)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_vbox.add_child(weapon_label)

	_weapon_grid = GridContainer.new()
	_weapon_grid.columns = 3
	_weapon_grid.add_theme_constant_override("h_separation", 3)
	_weapon_grid.add_theme_constant_override("v_separation", 3)
	weapon_vbox.add_child(_weapon_grid)

	# 武器菜单
	_weapon_menu = PopupMenu.new()
	_weapon_menu.id_pressed.connect(_on_weapon_menu_pressed)
	add_child(_weapon_menu)

	# 底部:Roll 按钮 + 待建造栏
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	bottom.position.y = -100
	add_child(bottom)

	_roll_button = Button.new()
	_roll_button.custom_minimum_size = ROLL_BTN_SIZE
	_roll_button.pressed.connect(_on_roll_pressed)
	bottom.add_child(_roll_button)

	_pending_panel = PENDING_PANEL_SCENE.instantiate()
	bottom.add_child(_pending_panel)

	# 右上:人口 / 波次(精简,golden HUD 已显示金币/等级/经验)
	var top_right := VBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.position = Vector2(-150, 8)
	add_child(top_right)

	_pop_label = Label.new()
	_pop_label.add_theme_font_size_override("font_size", 14)
	_pop_label.add_theme_color_override("font_color", Color.WHITE)
	top_right.add_child(_pop_label)

func _refresh() -> void:
	_refresh_weapon_grid()
	_refresh_roll_button()
	_refresh_pop_label()

func _refresh_weapon_grid() -> void:
	for child in _weapon_grid.get_children():
		child.queue_free()
	for i in InventoryManager.deployed_weapons.size():
		var entry: Dictionary = InventoryManager.deployed_weapons[i]
		var btn := Button.new()
		btn.custom_minimum_size = WEAPON_ICON_SIZE
		btn.flat = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var weapon_data: WeaponData = GameConfig.weapons.get(entry.id)
		if weapon_data and not weapon_data.icon_path.is_empty() and ResourceLoader.exists(weapon_data.icon_path):
			var icon := TextureRect.new()
			icon.texture = load(weapon_data.icon_path)
			icon.custom_minimum_size = WEAPON_ICON_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(icon)
		btn.pressed.connect(_show_weapon_menu.bind(i))
		_weapon_grid.add_child(btn)
	# 填充空槽至 9
	var total: int = max(9, InventoryManager.deployed_weapons.size())
	if total % 3 != 0:
		total = (total / 3 + 1) * 3
	for i in (total - InventoryManager.deployed_weapons.size()):
		var empty := Panel.new()
		empty.custom_minimum_size = WEAPON_ICON_SIZE
		empty.modulate = Color(0.3, 0.3, 0.3)
		_weapon_grid.add_child(empty)

func _show_weapon_menu(weapon_index: int) -> void:
	_menu_weapon_index = weapon_index
	_weapon_menu.clear()
	var entry: Dictionary = InventoryManager.deployed_weapons[weapon_index]
	var has_pair: bool = false
	for i in InventoryManager.deployed_weapons.size():
		if i != weapon_index and InventoryManager.deployed_weapons[i].id == entry.id and InventoryManager.deployed_weapons[i].level == entry.level and entry.level < 3:
			has_pair = true
			break
	if has_pair:
		_weapon_menu.add_item("合成", 0)
	var weapon_data: WeaponData = GameConfig.weapons.get(entry.id)
	var base_value: int = weapon_data.sell_price_per_level[entry.level - 1] if weapon_data else 0
	var refund: int = int(round(base_value * GameConfig.shop_config.sell_return_ratio))
	_weapon_menu.add_item("卖出 $%d" % refund, 1)
	var btn: Button = _weapon_grid.get_child(weapon_index)
	var global_pos: Vector2 = btn.global_position
	_weapon_menu.position = Vector2i(int(global_pos.x), int(global_pos.y) - 50)
	_weapon_menu.popup()

func _on_weapon_menu_pressed(id: int) -> void:
	match id:
		0:  # 合成
			if InventoryManager.merge_weapon(_menu_weapon_index):
				if weapon_manager:
					weapon_manager.refresh_weapons()
				_refresh()
		1:  # 卖出
			var refund: int = InventoryManager.sell_from_deployed_weapon(_menu_weapon_index)
			if refund > 0 and weapon_manager:
				weapon_manager.remove_weapon(_menu_weapon_index)
			_refresh()
	_menu_weapon_index = -1

func _refresh_roll_button() -> void:
	var cost: int = GameConfig.shop_config.roll_cost
	_roll_button.text = "Roll $%d" % cost
	_roll_button.disabled = not InventoryManager.can_roll()

func _refresh_pop_label() -> void:
	var cur: int = InventoryManager.get_population_used()
	var maxv: int = PlayerProgression.get_population_cap()
	_pop_label.text = "人口 %d/%d" % [cur, maxv]

func _on_roll_pressed() -> void:
	InventoryManager.roll_tower()
	_refresh_roll_button()

func set_drag_manager(dm: Node) -> void:
	drag_manager = dm
	if _pending_panel:
		_pending_panel.drag_manager = dm
```

- [ ] **Step 2: 创建场景**

`scenes/ui/battle_hud.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/battle_hud.gd" id="1"]

[node name="BattleHUD" type="CanvasLayer"]
layer = 10
script = ExtResource("1")
```

- [ ] **Step 3: 提交**

```bash
git add scripts/ui/battle_hud.gd scenes/ui/battle_hud.tscn
git commit -m "feat: BattleHUD — 整合武器栏 + Roll 按钮 + 待建造栏 + 信息"
```

---

## Phase E — 流程整合

### Task 20: main.gd — 删除 Phase 状态机,整合新 UI

**Files:**
- Modify: `scripts/ui/main.gd`(整体重写)
- Modify: `scenes/levels/main.tscn`(把 ShopOverlay 替换为 BattleHUD,新增 PerkSelectionOverlay / TowerRollOverlay)

- [ ] **Step 1: 重写 main.gd**

将 main.gd 改为(整体替换):

```gdscript
extends Node2D

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const BATTLE_HUD_SCENE := preload("res://scenes/ui/battle_hud.tscn")
const PERK_OVERLAY_SCENE := preload("res://scenes/ui/perk_selection_overlay.tscn")
const TOWER_ROLL_SCENE := preload("res://scenes/ui/tower_roll_overlay.tscn")

var _battle_hud: CanvasLayer = null
var _perk_overlay: CanvasLayer = null
var _tower_roll_overlay: CanvasLayer = null
var _drag_manager: Node = null
var _player: Node2D = null
var _entity_layer: Node2D = null
var _projectile_layer: Node2D = null
var _pickup_layer: Node2D = null
var _player_spawn_pos: Vector2 = Vector2.ZERO
var _map_layout: MapLayout = null

func _ready() -> void:
	_load_map()

	_player = PLAYER_SCENE.instantiate()
	_player.position = _player_spawn_pos
	_entity_layer.add_child(_player)
	SceneFactory.init_containers(_entity_layer, _projectile_layer, _pickup_layer)

	# DragManager(预先在 main.tscn 中)
	_drag_manager = $DragManager
	_drag_manager.initialize(_entity_layer, _player)
	if _map_layout:
		_drag_manager.placeable_cells = _map_layout.get_placeable_dict()
	# Battle 阶段:塔点击菜单始终启用
	_drag_manager.set_shop_mode(true)

	# 战斗 HUD(替代 ShopOverlay)
	_battle_hud = BATTLE_HUD_SCENE.instantiate()
	add_child(_battle_hud)
	_battle_hud.set_drag_manager(_drag_manager)
	if _player.has_node("WeaponManager"):
		_battle_hud.weapon_manager = _player.get_node("WeaponManager")

	# Perk 选择弹窗(常驻,视实时升级而显示)
	_perk_overlay = PERK_OVERLAY_SCENE.instantiate()
	add_child(_perk_overlay)

	# Roll 时 3 选 1 弹窗
	_tower_roll_overlay = TOWER_ROLL_SCENE.instantiate()
	add_child(_tower_roll_overlay)

	# 暂停覆盖层 / 调试面板
	var pause_overlay = load("res://scripts/ui/pause_overlay.gd").new()
	add_child(pause_overlay)
	var debug_panel = load("res://scripts/ui/debug_panel.gd").new()
	add_child(debug_panel)

	# 信号连接
	EventBus.wave_transition_ready.connect(_on_wave_transition_ready)
	EventBus.coins_generated.connect(_on_coins_generated)
	EventBus.wave_started.connect(_on_wave_started_warmup)

	# HUD(顶部信息栏 — 现有的 HUD)
	$HUD.set_battle_phase(true)

	# 立刻进入战斗
	AudioManager.play_bgm("battle")
	SceneFactory.warmup_initial()
	$WaveManager.start_next_wave()

func _on_wave_transition_ready() -> void:
	# 旧版进入 SHOP 阶段;新版直接进入下一波
	# 短暂呼吸期由 wave_manager 自带的 SHOP_TRANSITION_DELAY 提供
	$WaveManager.start_next_wave()

func _load_map() -> void:
	var map_data: MapData = GameConfig.maps.get(PlayerState.selected_map)
	if map_data == null or map_data.map_scene.is_empty():
		push_warning("地图场景未配置: " + PlayerState.selected_map)
		return
	if not ResourceLoader.exists(map_data.map_scene):
		push_warning("地图场景文件不存在: " + map_data.map_scene)
		return
	var map_instance = load(map_data.map_scene).instantiate()
	add_child(map_instance)
	move_child(map_instance, 0)

	if map_data.generator_config != null:
		var generator := MapGenerator.new()
		var layout := generator.generate(map_data.generator_config)
		generator.apply_to_tilemap(map_instance, layout, map_data.generator_config)
		_map_layout = layout
		_player_spawn_pos = layout.get_player_spawn_world()
	else:
		_player_spawn_pos = Vector2.ZERO

	_entity_layer = map_instance.get_node("EntityLayer")
	_projectile_layer = map_instance.get_node("ProjectileLayer")
	_pickup_layer = map_instance.get_node("PickupLayer")
	assert(_entity_layer != null, "地图缺少 EntityLayer 节点")
	assert(_projectile_layer != null, "地图缺少 ProjectileLayer 节点")
	assert(_pickup_layer != null, "地图缺少 PickupLayer 节点")

func _add_coins(amount: int) -> void:
	InventoryManager.coins += amount
	StatsTracker.record_coins_earned(amount)
	EventBus.coins_changed.emit(amount, InventoryManager.coins)
	if _player:
		_player.coins = InventoryManager.coins

func _on_coins_generated(amount: int, _pos: Vector2) -> void:
	_add_coins(amount)

func _on_wave_started_warmup(_wave_num: int, wave_data: WaveData) -> void:
	SceneFactory.warmup_for_wave(wave_data)

func _exit_tree() -> void:
	SceneFactory.clear_all_pools()
```

注意删除了:
- `enum Phase` 与 `current_phase`
- `_enter_shop_phase` / `_enter_battle_phase` / `_on_start_battle`
- `_on_boss_killed` 中的 `boss_bounty` 加金币(现在 boss 不给固定金币)
- `_shop_overlay` 引用

- [ ] **Step 2: 修改 main.tscn — 移除 ShopOverlay,不显式实例化新 UI**

打开 `scenes/levels/main.tscn`(在 Godot 编辑器中,或文本读改):
- 删除 `ShopOverlay` 子节点(包括其 ext_resource)
- BattleHUD / PerkSelectionOverlay / TowerRollOverlay 由 main.gd 在 `_ready()` 中实例化,不需要在 .tscn 中预放
- 保留 `HUD` / `DragManager` / `WaveManager` 等子节点

> 用文本编辑:在 main.tscn 文件中删除 `[node name="ShopOverlay" ...]` 节点段及对应 `[ext_resource ... shop_overlay.tscn ...]`。

- [ ] **Step 3: 运行编辑器或测试套件验证不破**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

期望: 全绿(部分 ShopManager / ShopOverlay / wave_reward 旧测试可能 fail,留到 Task 22 删除)。

- [ ] **Step 4: 提交**

```bash
git add scripts/ui/main.gd scenes/levels/main.tscn
git commit -m "refactor: main.gd 删除 Phase 状态机,常态战斗 + 集成新 UI"
```

---

### Task 21: WaveManager 清理 — 删除 SHOP_TRANSITION_DELAY 引用 + 不再发奖励

**Files:**
- Modify: `scripts/systems/wave_manager.gd:1-6`(常量定义)、其他相关位置

- [ ] **Step 1: 调整 wave_manager 常量**

将顶部常量改为:

```gdscript
const VICTORY_DELAY: float = 1.0
const WAVE_CLEANUP_DELAY: float = 2.0
const WAVE_BREATHER_DELAY: float = 3.0  # 波次间呼吸期(原 SHOP_TRANSITION_DELAY)
```

将 `complete_wave()` 中的 `SHOP_TRANSITION_DELAY` 替换为 `WAVE_BREATHER_DELAY`。

- [ ] **Step 2: 检查 main.gd 中 _on_wave_transition_ready 是否合理**

main.gd 在 Task 20 中已改为收到 `wave_transition_ready` 后直接 `start_next_wave()`,呼吸期由 wave_manager 自带的 `WAVE_BREATHER_DELAY` 提供,在 emit `wave_transition_ready` 之前已 sleep 完。✓ 无需改动。

- [ ] **Step 3: 测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_wave_manager.gd -gexit
```

期望: 通过。如有 wave_reward 相关 test failing 是预期(下一 task 删除)。

- [ ] **Step 4: 提交**

```bash
git add scripts/systems/wave_manager.gd
git commit -m "refactor: WaveManager SHOP_TRANSITION_DELAY 重命名为 WAVE_BREATHER_DELAY"
```

---

### Task 22: 删除 ShopManager / ShopOverlay / 旧测试

**Files:**
- Delete: `scripts/systems/shop_manager.gd`
- Delete: `scripts/ui/shop_overlay.gd`
- Delete: `scenes/ui/shop_overlay.tscn`
- Delete: `tests/unit/test_shop_manager.gd`
- Delete: `tests/unit/test_shop_overlay.gd`
- Delete: `tests/unit/test_wave_reward.gd`

- [ ] **Step 1: 检查无引用**

用 Grep 确认这些类/文件没被其他代码引用(除上面 Task 已改的位置):

`grep -rn "ShopManager\|shop_overlay\|ShopOverlay\|wave_reward_per_tier\|boss_bounty\|get_wave_reward" scripts/ scenes/`

预期: 全部命中已被前面任务清掉。如有残留,补 patch。

- [ ] **Step 2: 删除文件**

```bash
git rm scripts/systems/shop_manager.gd
git rm scripts/ui/shop_overlay.gd
git rm scenes/ui/shop_overlay.tscn
git rm tests/unit/test_shop_manager.gd
git rm tests/unit/test_shop_overlay.gd
git rm tests/unit/test_wave_reward.gd
```

- [ ] **Step 3: 删除 .uid 残留**

用 `ls scripts/systems/shop_manager.gd.uid scripts/ui/shop_overlay.gd.uid scenes/ui/shop_overlay.tscn.uid 2>/dev/null` 检查;如有,`git rm` 之。

- [ ] **Step 4: 运行所有测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

期望: 全绿。

- [ ] **Step 5: 提交**

```bash
git commit -m "chore: 删除 ShopManager / ShopOverlay 及对应测试(已被 BattleHUD/TowerRollManager 替代)"
```

---

### Task 23: PlayerState.player_stats 关联 reset 顺序对齐 InventoryManager

**Files:**
- 测试 `tests/unit/test_inventory_manager.gd`(若存在)

- [ ] **Step 1: 复查 InventoryManager.reset() 是否正确清理 pending**

读 `scripts/core/inventory_manager.gd:205-219`,确认 Task 11 的 reset 改动已经包含 pending_towers 清理。如果遗漏补:

```gdscript
	pending_towers = []
	_current_roll_offer = []
```

- [ ] **Step 2: 提交(若有改动)**

```bash
git add scripts/core/inventory_manager.gd
git commit -m "fix: InventoryManager.reset 清理 pending 状态"
```

如无改动可跳过。

---

## Phase F — 集成测试与手工验证

### Task 24: 集成测试 — 升级 → perk → 效果生效

**Files:**
- Create: `tests/integration/test_perk_levelup_flow.gd`

- [ ] **Step 1: 写集成测试**

Create `tests/integration/test_perk_levelup_flow.gd`:

```gdscript
extends GutTest

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	PerkManager.reset()

func test_levelup_emits_perk_offered() -> void:
	var emitted_perks: Array = []
	var conn := func(perks: Array) -> void:
		emitted_perks = perks
	EventBus.perk_offered.connect(conn)
	# 给足以升级到 Lv2 的经验
	var threshold: int = PlayerProgression.exp_for_level(2)
	PlayerProgression.add_exp(threshold)
	assert_eq(PlayerProgression.player_level, 2)
	assert_eq(emitted_perks.size(), 3)
	EventBus.perk_offered.disconnect(conn)

func test_select_vitality_increases_hp_bonus() -> void:
	# 强制 offer 包含 vitality(模拟玩家选了)
	for p in PerkManager._all_perks:
		if p.id == "vitality":
			PerkManager._current_offer = [p]
			break
	PerkManager.select_perk("vitality")
	assert_almost_eq(PlayerState.player_stats[Enums.Stat.HP_BONUS_PERCENT], 0.1, 0.001)

func test_select_expansion_increases_population_cap() -> void:
	var pre_cap: int = PlayerProgression.get_population_cap()
	for p in PerkManager._all_perks:
		if p.id == "expansion":
			PerkManager._current_offer = [p]
			break
	PerkManager.select_perk("expansion")
	assert_eq(PlayerProgression.get_population_cap(), pre_cap + 1)

func test_select_study_increases_exp_gain() -> void:
	for p in PerkManager._all_perks:
		if p.id == "study":
			PerkManager._current_offer = [p]
			break
	PerkManager.select_perk("study")
	# 应用后再 add_exp 验证倍率
	var pre_exp: int = PlayerProgression.current_exp
	PlayerProgression.add_exp(10)
	# +10% bonus → 实际 +11
	assert_eq(PlayerProgression.current_exp - pre_exp, 11)
```

- [ ] **Step 2: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_perk_levelup_flow.gd -gexit
```

期望: 4 passing。

- [ ] **Step 3: 提交**

```bash
git add tests/integration/test_perk_levelup_flow.gd
git commit -m "test: 集成测试 — 升级 → perk → 效果生效"
```

---

### Task 25: 集成测试 — Roll 流程

**Files:**
- Create: `tests/integration/test_roll_flow.gd`

- [ ] **Step 1: 写集成测试**

Create `tests/integration/test_roll_flow.gd`:

```gdscript
extends GutTest

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	InventoryManager.coins = 100

func test_roll_pick_three_times_fills_queue() -> void:
	for i in 3:
		assert_true(InventoryManager.roll_tower())
		# 确认 offer 有 3 个候选
		assert_eq(InventoryManager.get_current_roll_offer().size(), 3)
		InventoryManager.confirm_roll_pick(0)
	assert_eq(InventoryManager.pending_towers.size(), 3)

func test_roll_blocked_when_queue_full() -> void:
	for i in 3:
		InventoryManager.roll_tower()
		InventoryManager.confirm_roll_pick(0)
	# 第 4 次应被阻止
	assert_false(InventoryManager.roll_tower())
	assert_false(InventoryManager.can_roll())

func test_consume_pending_after_full_allows_more_roll() -> void:
	for i in 3:
		InventoryManager.roll_tower()
		InventoryManager.confirm_roll_pick(0)
	InventoryManager.consume_pending(0)
	# 现在可以再 roll
	assert_true(InventoryManager.can_roll())

func test_cancel_refunds_full_cost() -> void:
	var pre: int = InventoryManager.coins
	InventoryManager.roll_tower()
	InventoryManager.cancel_roll()
	assert_eq(InventoryManager.coins, pre)
```

- [ ] **Step 2: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_roll_flow.gd -gexit
```

期望: 4 passing。

- [ ] **Step 3: 提交**

```bash
git add tests/integration/test_roll_flow.gd
git commit -m "test: 集成测试 — Roll → 待建造栏 → 满栏阻止 → 消费后可再 roll"
```

---

### Task 26: 集成测试 — 卖出 70%

**Files:**
- Create: `tests/integration/test_sell_returns.gd`

- [ ] **Step 1: 写集成测试**

Create `tests/integration/test_sell_returns.gd`:

```gdscript
extends GutTest

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	InventoryManager.coins = 0

func test_sell_lv1_tower_70_percent() -> void:
	var data: TowerData = GameConfig.towers["pea_shooter"]
	var base: int = data.sell_price_per_level[0]
	InventoryManager.deployed_towers.append({
		id = "pea_shooter", level = 1,
		grid_pos = Vector2i(0, 0), deploy_id = 1,
	})
	var refund: int = InventoryManager.sell_from_deployed_tower(1)
	assert_eq(refund, int(round(base * 0.7)))
	assert_eq(InventoryManager.coins, refund)
	assert_eq(InventoryManager.deployed_towers.size(), 0)

func test_sell_lv2_tower_70_percent_of_lv2_price() -> void:
	var data: TowerData = GameConfig.towers["pea_shooter"]
	if data.sell_price_per_level.size() < 2:
		pending("塔配置无 lv2 售价")
		return
	var base: int = data.sell_price_per_level[1]
	InventoryManager.deployed_towers.append({
		id = "pea_shooter", level = 2,
		grid_pos = Vector2i(0, 0), deploy_id = 1,
	})
	var refund: int = InventoryManager.sell_from_deployed_tower(1)
	assert_eq(refund, int(round(base * 0.7)))

func test_sell_weapon_70_percent() -> void:
	var data: WeaponData = GameConfig.weapons["bow"]
	var base: int = data.sell_price_per_level[0]
	InventoryManager.deployed_weapons.append({id = "bow", level = 1})
	var refund: int = InventoryManager.sell_from_deployed_weapon(0)
	assert_eq(refund, int(round(base * 0.7)))
```

- [ ] **Step 2: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_sell_returns.gd -gexit
```

期望: 3 passing。

- [ ] **Step 3: 提交**

```bash
git add tests/integration/test_sell_returns.gd
git commit -m "test: 集成测试 — 卖出按 70% 返还"
```

---

### Task 27: 全套单元 + 集成测试套件回归

**Files:** 无变更,纯运行

- [ ] **Step 1: 运行完整测试套件**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

期望: 全绿(failing 0,errored 0)。

- [ ] **Step 2: 若有 failing,逐个修复**

- 失败用例分析:对于每个 failing,检查是否是新代码 bug(优先修)或旧测试已过时(评估是否仍有意义,有则改测试,无则删)。
- 不允许跳过任何 failing 进入下一步。

- [ ] **Step 3: 提交修复(如有)**

```bash
git add ...
git commit -m "fix: <具体的 fail 修复说明>"
```

---

### Task 28: 手工验证 — 跑通 15 波

**Files:** 无代码,运行游戏

- [ ] **Step 1: 启动 Godot 编辑器并 Run main scene**

```bash
open /Applications/Godot.app && # 然后在编辑器中按 F5 运行
```

或用 gdai-mcp 的 `play_scene` 功能跑 `res://scenes/levels/main.tscn`。

- [ ] **Step 2: 流程检查表**

逐项验证:

- [ ] 进入 main 场景立即开始战斗(无 SHOP 阶段切换)
- [ ] BGM 是 battle 主题
- [ ] 顶部 HUD 显示金币 / Lv / 经验条 / 第 X 波 / 倒计时
- [ ] 右上信息栏显示"人口 X/Y"
- [ ] 左侧武器装备栏显示初始武器(角色起始武器)
- [ ] 底部 Roll 按钮显示"Roll $3"
- [ ] 拾取经验球到升级阈值 → 游戏暂停 → 弹出 3 选 1 perk 面板
- [ ] 选一个 perk → 面板关闭,游戏继续 → 验证效果(例如 vitality 选完后 HP 上限增加)
- [ ] 点击 Roll(金币足够时)→ 弹 3 选 1 塔卡片 → 选一张 → 进入待建造栏
- [ ] 点击待建造栏卡片 → 进入放置模式 → 拖到地图合法位置 → 塔出现
- [ ] 待建造栏满 3 张时 Roll 按钮置灰
- [ ] 点击已部署塔 → 弹"卖出 / 移动"菜单(无"合成"选项)
- [ ] 卖出 → 金币按 70% 返还
- [ ] 移动 → 进入 MOVE 模式 → 拖到新位置 → 塔搬过去
- [ ] 放置同 id 同 lvl 第 2 个 → 自动合成为 Lv2(2 个塔节点合并为 1 个)
- [ ] 波次结束:不刷新 UI、不弹商店、3 秒后自动开始下一波
- [ ] 第 5 / 10 / 15 波 Boss 击杀:**不再**发"Boss 赏金"金币(去掉的逻辑)
- [ ] 跑完 15 波或英雄阵亡 → 进入 result 场景

- [ ] **Step 3: 记录手工验证结果**

如果有 bug,创建 fix 任务并修复;如果全过,记录"手工 OK"在 commit message。

- [ ] **Step 4: 终止 commit(可选,标记里程碑)**

```bash
git commit --allow-empty -m "milestone: #1 流程骨架重构完成,手工验证 15 波通过"
```

---

## Self-Review Notes

实施完成后,运行此 checklist:

1. **Spec 覆盖**: 对照 `docs/superpowers/specs/2026-04-16-flow-skeleton-design.md` 各章节:
   - §3 核心玩法流程 → Task 20-21
   - §4 Roll 塔机制 → Task 5, 10, 11, 16, 17
   - §5 升级 3 选 1 perk → Task 4, 9, 15, 24
   - §6 UI 改造 → Task 17, 18, 19
   - §7 经济调整 → Task 11(70% 卖出)、Task 22(删 wave_reward)
   - §8 模块改动清单 → 全 28 task 覆盖
   - §9 数据模型变更 → Task 1, 3, 4, 5, 7
   - §10 错误与边界处理 → Task 11(Roll 阻塞)、Task 9(perk 队列)、Task 16(取消退款)
   - §11 测试策略 → Task 24-28

2. **Placeholder 扫描**: 无 TBD / TODO 在 spec 与 plan 中,代码注释中允许"# 待 #X 接入"形式标记后续工作

3. **类型一致**: 
   - `PerkManager.select_perk(perk_id: String) -> bool`(Task 9 定义,Task 15 / 24 调用)
   - `InventoryManager.roll_tower() -> bool`(Task 11 定义,Task 19 / 25 调用)
   - `InventoryManager.confirm_roll_pick(idx: int) -> bool`(Task 11 定义,Task 16 调用)
   - `InventoryManager.consume_pending(idx: int) -> String`(Task 11 定义,Task 17 调用)
   - `InventoryManager.cancel_roll() -> void`(Task 11 定义,Task 16 调用)
   - `InventoryManager.can_roll() -> bool`(Task 11 定义,Task 19 调用)
   - `TowerRollManager.roll_three(player_level: int) -> Array`(Task 10 定义,Task 11 调用)
   - `BattleHUD.set_drag_manager(dm: Node)`(Task 19 定义,Task 20 调用)
   - `PendingQueuePanel.drag_manager`(Task 17 公开字段,Task 19 设置)
