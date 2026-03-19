# 资源系统重设计 实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 三资源分离（金币/经验/人口），升级增强（通用属性+Dora被动进化），经济数值调整

**Architecture:** 删除敌人金币掉落和金币买升级，使经验→人口、金币→装备两条线完全独立。升级新增通用属性成长(HP/移速/拾取范围)和角色被动进化系统(PassiveEvolutionData Resource)。金币来源精简为波次奖励(分段)+向日葵+Boss赏金。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架

**设计文档:** `docs/superpowers/specs/2026-03-19-resource-system-redesign.md`

---

## Chunk 1: 金币系统清理与数值调整

### Task 1: 删除敌人金币相关死代码

**Files:**
- Modify: `scripts/resources/enemy_data.gd:9-10` (删除 coin_drop 字段)
- Modify: `scripts/entities/enemy.gd:3,13,90-100,114,164,173` (删除 coin 相关代码)
- Modify: `scripts/systems/enemy_spawner.gd:111-117` (apply_elite 调用去掉 coin_mult)
- Modify: `scripts/resources/wave_data.gd:19` (删除 elite_coin_mult)
- Modify: `resources/enemies/fast.tres` (删除 coin_drop 行)
- Modify: `resources/enemies/tank.tres` (删除 coin_drop 行)
- Modify: `resources/enemies/boss_brute.tres` (删除 coin_drop 行)
- Modify: `resources/enemies/boss_summoner.tres` (删除 coin_drop 行)
- Modify: `resources/enemies/boss_guardian.tres` (删除 coin_drop 行)

- [ ] **Step 1: 删除 `enemy_data.gd` 中的 coin_drop 字段**

从 `scripts/resources/enemy_data.gd` 删除这两行：
```gdscript
@export var coin_drop_min: int = 1
@export var coin_drop_max: int = 3
```

- [ ] **Step 2: 清理 `enemy.gd` 中所有金币相关代码**

从 `scripts/entities/enemy.gd` 删除：
- 行 3: `const COIN_SCATTER_RANGE: float = 40.0`
- 行 13: `var _elite_coin_mult: float = 1.0`
- 行 90-100: 整个 `_drop_coins()` 方法
- 行 114 `apply_elite()` 方法：删除 `coin_mult` 参数和 `_elite_coin_mult = coin_mult` 赋值

修改后的 `apply_elite` 签名：
```gdscript
func apply_elite(hp_mult: float, damage_mult: float, scale_mult: float, exp_mult: float = 1.0) -> void:
	is_elite = true
	_elite_exp_mult = exp_mult
	health.max_hp *= hp_mult
	health.current_hp = health.max_hp
	_hitbox.damage *= damage_mult
	scale *= scale_mult
	add_to_group("elites")
```

从 `reset_for_pool()` 删除 `_elite_coin_mult = 1.0`。

- [ ] **Step 3: 更新 `enemy_spawner.gd` 的 apply_elite 调用**

`scripts/systems/enemy_spawner.gd` 行 111-117，修改 `apply_elite()` 调用，去掉 `coin_mult` 参数：
```gdscript
if _current_wave_data.elite_chance > 0.0 and randf() < _current_wave_data.elite_chance:
	enemy.apply_elite(
		_current_wave_data.elite_hp_mult,
		_current_wave_data.elite_damage_mult,
		_current_wave_data.elite_scale,
		_current_wave_data.elite_exp_mult
	)
```

- [ ] **Step 4: 删除 `wave_data.gd` 的 elite_coin_mult**

从 `scripts/resources/wave_data.gd` 行 19 删除：
```gdscript
@export var elite_coin_mult: float = 2.0
```

- [ ] **Step 5: 清理所有敌人 .tres 文件的 coin_drop 行**

以下文件删除 `coin_drop_min` 和 `coin_drop_max` 行：
- `resources/enemies/fast.tres`
- `resources/enemies/tank.tres`
- `resources/enemies/boss_brute.tres`
- `resources/enemies/boss_summoner.tres`
- `resources/enemies/boss_guardian.tres`

注意：`normal.tres` 没有显式设置这些字段（使用默认值），无需改动。但 `enemy_data.gd` 的字段已删除所以不影响。

- [ ] **Step 6: 提交**

```bash
git add scripts/resources/enemy_data.gd scripts/entities/enemy.gd scripts/systems/enemy_spawner.gd scripts/resources/wave_data.gd resources/enemies/
git commit -m "refactor: 删除敌人金币掉落相关死代码（coin_drop/elite_coin_mult）"
```

---

### Task 2: 删除金币买升级功能

**Files:**
- Modify: `scripts/core/player_progression.gd:26-28` (删除 buy_level_up)
- Modify: `scripts/systems/shop_manager.gd:52-60` (删除 buy_level_up)
- Modify: `scripts/resources/shop_config.gd:10-14` (删除 level_up 相关字段和方法)
- Modify: `scripts/ui/shop_overlay.gd` (删除升级按钮 UI)

- [ ] **Step 1: 删除 `player_progression.gd` 的 `buy_level_up()`**

从 `scripts/core/player_progression.gd` 行 26-28 删除：
```gdscript
func buy_level_up() -> void:
	player_level += 1
	EventBus.player_level_changed.emit(player_level)
```

- [ ] **Step 2: 删除 `shop_manager.gd` 的 `buy_level_up()`**

从 `scripts/systems/shop_manager.gd` 删除整个 `buy_level_up()` 方法（行 52-60）。

- [ ] **Step 3: 清理 `shop_config.gd` 的 level_up 相关代码**

从 `scripts/resources/shop_config.gd` 删除：
- 行 10: `@export var level_up_base_cost: int = 4`
- 行 11: `@export var level_up_cost_increment: int = 2`
- 行 13-14: 整个 `get_level_up_cost()` 方法

- [ ] **Step 4: 从 `shop_overlay.gd` 删除升级按钮**

在 `scripts/ui/shop_overlay.gd` 中：
- 删除 `_level_up_button` 变量声明
- 删除行 124-128（按钮创建和信号连接）
- 删除 `_on_level_up_pressed()` 方法（行 379-381）
- 从 `_update_action_buttons()` 删除行 292-294（升级按钮更新逻辑）
- 调整布局：原升级按钮位置空出，刷新按钮可适当扩大

- [ ] **Step 5: 提交**

```bash
git add scripts/core/player_progression.gd scripts/systems/shop_manager.gd scripts/resources/shop_config.gd scripts/ui/shop_overlay.gd
git commit -m "refactor: 删除金币买升级功能（buy_level_up），人口只来自经验升级"
```

---

### Task 3: 调整金币经济数值

**Files:**
- Modify: `scripts/core/game_config.gd:53` (initial_coins 100→40)
- Modify: `resources/characters/dora.tres` (starting_gold 30→10)
- Modify: `scripts/resources/shop_config.gd` (新增分段波次奖励和 Boss 赏金)
- Modify: `resources/shop/shop_config.tres` (新增分段奖励数据)
- Modify: `scripts/ui/main.gd:63` (波次奖励改用分段配置)
- Modify: `scripts/ui/main.gd` (新增 Boss 赏金逻辑)

- [ ] **Step 1: 修改初始金币**

`scripts/core/game_config.gd` 行 53，将 `"initial_coins": 100` 改为 `"initial_coins": 40`。

- [ ] **Step 2: 修改 Dora 初始金币 bonus**

`resources/characters/dora.tres`，将 `starting_gold = 30` 改为 `starting_gold = 10`。

- [ ] **Step 3: `shop_config.gd` 新增波次奖励分段和 Boss 赏金**

在 `scripts/resources/shop_config.gd` 中，删除旧的 `wave_reward` 字段，新增：

```gdscript
@export var wave_reward_per_tier: PackedInt32Array = [5, 8, 10]
@export var wave_reward_tier_thresholds: PackedInt32Array = [1, 6, 11]
@export var boss_bounty: Dictionary = {
	"boss_brute": 15,
	"boss_summoner": 20,
	"boss_guardian": 30,
}

func get_wave_reward(wave_number: int) -> int:
	for i in range(wave_reward_tier_thresholds.size() - 1, -1, -1):
		if wave_number >= wave_reward_tier_thresholds[i]:
			return wave_reward_per_tier[i]
	return wave_reward_per_tier[0]
```

完整文件应为：
```gdscript
class_name ShopConfig
extends Resource

# 商店全局配置：槽位、刷新费用、物品费用、波次奖励

@export var slot_count: int = 4
@export var refresh_cost: int = 2
@export var item_cost: int = 3
@export var wave_reward_per_tier: PackedInt32Array = [5, 8, 10]
@export var wave_reward_tier_thresholds: PackedInt32Array = [1, 6, 11]
@export var boss_bounty: Dictionary = {
	"boss_brute": 15,
	"boss_summoner": 20,
	"boss_guardian": 30,
}

func get_wave_reward(wave_number: int) -> int:
	for i in range(wave_reward_tier_thresholds.size() - 1, -1, -1):
		if wave_number >= wave_reward_tier_thresholds[i]:
			return wave_reward_per_tier[i]
	return wave_reward_per_tier[0]
```

- [ ] **Step 4: 更新 `shop_config.tres`**

`resources/shop/shop_config.tres` 需要删除旧的 `wave_reward = 10` 行（如有显式设置）。新增字段使用 `shop_config.gd` 中的默认值即可，不需要在 .tres 中显式覆盖。

- [ ] **Step 5: 修改 `main.gd` 波次奖励逻辑**

在 `scripts/ui/main.gd` 的 `_enter_shop_phase()` 中，行 63 将：
```gdscript
var reward: int = GameConfig.shop_config.wave_reward
```
改为：
```gdscript
var reward: int = GameConfig.shop_config.get_wave_reward(PlayerState.current_wave)
```

- [ ] **Step 6: `main.gd` 新增 Boss 赏金和统一加金方法**

在 `scripts/ui/main.gd` 中：

1. 在 `_ready()` 的信号连接区域（行 46-49 之后）新增：
```gdscript
EventBus.boss_killed.connect(_on_boss_killed)
```

2. 新增 `_add_coins()` 统一方法和 `_on_boss_killed()` 处理：
```gdscript
func _add_coins(amount: int) -> void:
	InventoryManager.coins += amount
	StatsTracker.record_coins_earned(amount)
	EventBus.coins_changed.emit(amount, InventoryManager.coins)
	if _player:
		_player.coins = InventoryManager.coins

func _on_boss_killed(boss_id: String) -> void:
	var bounty: int = GameConfig.shop_config.boss_bounty.get(boss_id, 0)
	if bounty > 0:
		_add_coins(bounty)
```

3. 将 `_enter_shop_phase()` 中行 64-69 的加金逻辑也改用 `_add_coins()`：
```gdscript
if not is_first:
	_shop_overlay.slide_in()
	var reward: int = GameConfig.shop_config.get_wave_reward(PlayerState.current_wave)
	_add_coins(reward)
```

4. 将 `_on_coins_generated()` 也重构为使用 `_add_coins()`：
```gdscript
func _on_coins_generated(amount: int, _pos: Vector2) -> void:
	_add_coins(amount)
```

- [ ] **Step 7: 提交**

```bash
git add scripts/core/game_config.gd resources/characters/dora.tres scripts/resources/shop_config.gd resources/shop/shop_config.tres scripts/ui/main.gd
git commit -m "feat: 金币经济调整（初始40金、分段波次奖励、Boss赏金）"
```

---

### Task 4: 调整向日葵和经验曲线数值

**Files:**
- Modify: `resources/towers/sunflower.tres` (产出数值调整)
- Modify: `resources/exp_config.tres` (exp_exponent 2.0→1.6)
- Modify: `resources/enemies/normal.tres` (exp_drop 确认)
- Modify: `resources/enemies/fast.tres` (exp_drop 调整)
- Modify: `resources/enemies/tank.tres` (exp_drop 调整)
- Modify: `resources/enemies/boss_brute.tres` (exp_drop 调整)
- Modify: `resources/enemies/boss_summoner.tres` (exp_drop 调整)
- Modify: `resources/enemies/boss_guardian.tres` (exp_drop 调整)

- [ ] **Step 1: 修改向日葵产出**

`resources/towers/sunflower.tres` 中 GeneratorConfigData 子资源：
- `generate_amount_per_level` 从 `(5, 8, 12)` 改为 `(3, 5, 8)`
- `generate_interval_per_level` 从 `(10.0, 8.0, 6.0)` 改为 `(12.0, 10.0, 8.0)`

- [ ] **Step 2: 修改经验曲线**

`resources/exp_config.tres`，将 `exp_exponent = 2.0` 改为 `exp_exponent = 1.6`。

- [ ] **Step 3: 调整敌人经验掉落值**

按设计文档调整各敌人 .tres 文件的 exp_drop 值：

- `normal.tres`: 保持 `exp_drop_min=1, exp_drop_max=1`（不变）
- `fast.tres`: `exp_drop_min=1, exp_drop_max=1`（原 1-2 改为 1）
- `tank.tres`: 保持 `exp_drop_min=2, exp_drop_max=3`（改为 1-2）→ 设为 `exp_drop_min=1, exp_drop_max=2`
- `boss_brute.tres`: `exp_drop_min=8, exp_drop_max=10`（原 10-15）
- `boss_summoner.tres`: `exp_drop_min=10, exp_drop_max=12`（原 10-15）
- `boss_guardian.tres`: `exp_drop_min=12, exp_drop_max=15`（不变）

- [ ] **Step 4: 提交**

```bash
git add resources/towers/sunflower.tres resources/exp_config.tres resources/enemies/
git commit -m "chore: 调整向日葵产出和经验曲线数值（exp_exponent 2.0→1.6）"
```

---

### Task 5: 更新受影响的测试

**Files:**
- Modify: `tests/unit/test_resource_loading.gd:209` (initial_coins 断言)
- Modify: `tests/unit/test_game_data_economy.gd:14` (before_each 初始金币)
- Modify: `tests/unit/test_new_passives.gd` (Dora starting_gold 和 passive 断言)

- [ ] **Step 1: 修复 `test_resource_loading.gd`**

行 209，将 `assert_eq(GameConfig.PLAYER["initial_coins"], 100)` 改为 `assert_eq(GameConfig.PLAYER["initial_coins"], 40)`。

- [ ] **Step 2: 修复 `test_game_data_economy.gd`**

检查行 14 的 `InventoryManager.coins = GameConfig.PLAYER["initial_coins"]`。这行只是设置初始状态，值会自动跟随 GameConfig 变化，不需要改。但需检查文件中所有硬编码 100 的断言并更新。

同时检查是否有任何 `buy_level_up` 相关的测试用例需要删除。

- [ ] **Step 3: 修复 `test_new_passives.gd`**

- 行 28-32: `test_dora_passive_loaded()` 断言 `new_passive_id == "fortify_regen"` — 暂时保留，因为我们在 Task 7 (被动进化) 中才会清空 Dora 的 `new_passive_id`。当前步骤只更新经济值。
- 行 59-67: `test_reset_applies_starting_gold()` 中期望金币 = `initial_coins + starting_gold`。现在 40 + 10 = 50。确认断言值是否硬编码，如果硬编码了需要修改。

- [ ] **Step 4: 运行测试验证**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 5: 提交**

```bash
git add tests/
git commit -m "test: 更新测试用例适配新经济数值（初始金币40、starting_gold调整）"
```

---

## Chunk 2: 升级奖励增强与被动进化系统

### Task 6: 通用属性成长（每级 +3%HP / +2%移速 / +5%拾取范围）

**Files:**
- Modify: `scripts/entities/player.gd` (新增属性成长逻辑)
- Modify: `scripts/entities/exp_orb.gd:24` (拾取范围乘数)
- Modify: `scripts/entities/coin.gd:24` (拾取范围乘数)

- [ ] **Step 1: `player.gd` 新增通用成长变量和升级监听**

在 `scripts/entities/player.gd` 顶部变量区新增：
```gdscript
# 通用属性成长（每级复利）
const LEVEL_HP_GROWTH: float = 0.03       # +3% HP/级
const LEVEL_SPEED_GROWTH: float = 0.02    # +2% 移速/级
const LEVEL_PICKUP_GROWTH: float = 0.05   # +5% 拾取范围/级
var pickup_range_mult: float = 1.0
var _base_max_hp: float = 0.0
var _base_speed: float = 0.0
```

在 `_ready()` 中，`health.initialize(max_hp)` 之后保存基础值：
```gdscript
_base_max_hp = max_hp
_base_speed = speed
```

在 `_ready()` 最后（`_init_passives()` 之后）连接升级信号并应用当前等级的成长：
```gdscript
EventBus.player_level_changed.connect(_on_level_up)
_apply_level_growth(PlayerProgression.player_level)
```

- [ ] **Step 2: 实现 `_on_level_up()` 和 `_apply_level_growth()`**

```gdscript
func _on_level_up(new_level: int) -> void:
	_apply_level_growth(new_level)

func _apply_level_growth(level: int) -> void:
	var levels_gained: int = level - 1  # Lv1 = 0 次成长
	if levels_gained <= 0:
		return
	# HP 成长（复利）
	var hp_mult: float = pow(1.0 + LEVEL_HP_GROWTH, levels_gained)
	var new_max_hp: float = _base_max_hp * hp_mult
	var hp_diff: float = new_max_hp - health.max_hp
	health.max_hp = new_max_hp
	if hp_diff > 0:
		health.heal(hp_diff)  # 升级时恢复增加的 HP 部分
	# 移速成长（复利）
	var speed_mult: float = pow(1.0 + LEVEL_SPEED_GROWTH, levels_gained)
	speed = _base_speed * speed_mult
	# 拾取范围成长（复利）
	pickup_range_mult = pow(1.0 + LEVEL_PICKUP_GROWTH, levels_gained)
```

- [ ] **Step 3: `exp_orb.gd` 使用拾取范围乘数**

`scripts/entities/exp_orb.gd` 行 24，将：
```gdscript
if global_position.distance_to(player.global_position) < attract_range:
```
改为：
```gdscript
var effective_range: float = attract_range
if player.get("pickup_range_mult") != null:
	effective_range *= player.pickup_range_mult
if global_position.distance_to(player.global_position) < effective_range:
```

- [ ] **Step 4: `coin.gd` 同样使用拾取范围乘数**

`scripts/entities/coin.gd` 行 24，同上修改：
```gdscript
var effective_range: float = attract_range
if player.get("pickup_range_mult") != null:
	effective_range *= player.pickup_range_mult
if global_position.distance_to(player.global_position) < effective_range:
```

- [ ] **Step 5: 提交**

```bash
git add scripts/entities/player.gd scripts/entities/exp_orb.gd scripts/entities/coin.gd
git commit -m "feat: 升级通用属性成长（+3%HP/+2%移速/+5%拾取范围每级）"
```

---

### Task 7: PassiveEvolutionData Resource 和 Dora 被动进化

**Files:**
- Create: `scripts/resources/passive_evolution_data.gd`
- Create: `resources/passives/dora_sword_saint.tres`
- Modify: `scripts/resources/character_data.gd` (新增 passive_evolution 字段)
- Modify: `resources/characters/dora.tres` (引用 passive_evolution, 清空 new_passive_id)
- Modify: `scripts/entities/player.gd` (被动进化系统替换)

- [ ] **Step 1: 创建 `PassiveEvolutionData` Resource**

创建 `scripts/resources/passive_evolution_data.gd`：
```gdscript
class_name PassiveEvolutionData
extends Resource

## 被动进化数据：三阶进化，每阶一个属性字典
## 有效键: melee_damage_mult, melee_attack_speed_mult, kill_heal,
##         move_speed_mult, max_hp_mult, damage_reduction, dodge_chance,
##         pickup_range_mult, exp_mult

@export var passive_id: String = ""
@export var passive_name: String = ""

@export var tier_1: Dictionary = {}
@export var tier_2: Dictionary = {}
@export var tier_3: Dictionary = {}

@export var tier_2_level: int = 4
@export var tier_3_level: int = 7

func get_tier_for_level(level: int) -> Dictionary:
	if level >= tier_3_level:
		return tier_3
	elif level >= tier_2_level:
		return tier_2
	else:
		return tier_1
```

- [ ] **Step 2: 在 `.godot/global_script_class_cache.cfg` 中注册 class_name**

headless 测试需要手动注册新的 `class_name`。检查文件格式并添加 `PassiveEvolutionData` 条目。

运行命令查看格式：
```bash
grep "PassiveEvolutionData" .godot/global_script_class_cache.cfg || echo "需要手动添加"
```

如需手动添加，在 cfg 文件的 list 数组中追加：
```
{
"base": &"Resource",
"class": &"PassiveEvolutionData",
"icon": "",
"language": &"GDScript",
"path": "res://scripts/resources/passive_evolution_data.gd"
}
```

- [ ] **Step 3: `character_data.gd` 新增 `passive_evolution` 字段**

在 `scripts/resources/character_data.gd` 的 @export 区域（`new_passive_value_2` 之后）新增：
```gdscript
@export var passive_evolution: PassiveEvolutionData = null
```

- [ ] **Step 4: 创建 Dora 被动进化 .tres 文件**

创建 `resources/passives/dora_sword_saint.tres`：
```
[gd_resource type="Resource" script_class="PassiveEvolutionData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/passive_evolution_data.gd" id="1"]

[resource]
script = ExtResource("1")
passive_id = "sword_saint"
passive_name = "剑圣"
tier_1 = { "melee_damage_mult": 1.1 }
tier_2 = { "melee_damage_mult": 1.2, "melee_attack_speed_mult": 1.1 }
tier_3 = { "melee_damage_mult": 1.3, "melee_attack_speed_mult": 1.2, "kill_heal": 1.0 }
tier_2_level = 4
tier_3_level = 7
```

- [ ] **Step 5: 修改 `dora.tres` 引用新被动系统**

`resources/characters/dora.tres` 中：
- 将 `new_passive_id = "fortify_regen"` 改为 `new_passive_id = ""`
- 将 `new_passive_value = 0.02` 改为 `new_passive_value = 0.0`
- 将 `new_passive_value_2 = 3.0` 改为 `new_passive_value_2 = 0.0`
- 新增 `passive_evolution` 字段引用 `dora_sword_saint.tres`（作为外部资源）

注意：.tres 的具体引用格式需要通过 Godot 编辑器保存或手工编写 ext_resource。手工格式：
```
[ext_resource type="Resource" uid="..." path="res://resources/passives/dora_sword_saint.tres" id="passive_evo"]

passive_evolution = ExtResource("passive_evo")
```

如果 headless 环境下无法自动生成 uid，可先在 .tres 中设置路径，后续通过编辑器保存时自动补全 uid。

- [ ] **Step 6: 提交**

```bash
git add scripts/resources/passive_evolution_data.gd resources/passives/ scripts/resources/character_data.gd resources/characters/dora.tres
git commit -m "feat: 新增 PassiveEvolutionData Resource 和 Dora 剑圣被动数据"
```

---

### Task 8: player.gd 被动进化系统集成

**Files:**
- Modify: `scripts/entities/player.gd` (被动系统改造)
- Modify: `scripts/entities/weapons/weapon_manager.gd:138-153,188-196` (近战乘数)

- [ ] **Step 1: player.gd 新增被动进化状态变量**

在 `scripts/entities/player.gd` 变量区新增：
```gdscript
# 被动进化系统
var _passive_evolution: PassiveEvolutionData = null
var _current_passive_tier: Dictionary = {}
var _kill_heal_amount: float = 0.0
```

- [ ] **Step 2: 改造 `_init_passives()` 支持新旧系统共存**

将当前 `_init_passives()` (行 152-158) 替换为：

```gdscript
func _init_passives() -> void:
	var char_data: CharacterData = GameConfig.characters[PlayerState.current_character]
	if char_data.passive_evolution:
		_passive_evolution = char_data.passive_evolution
		_apply_passive_tier(PlayerProgression.player_level)
	else:
		# 旧系统回退（Kaze/Nemo/Gorg/Merlin 暂用）
		match PlayerState.new_passive_id:
			"swift_combo":
				_combo_target = null
				_combo_stacks = 0
			"fortify_regen":
				_fortify_regen_timer = 0.0
```

- [ ] **Step 3: 实现 `_apply_passive_tier()`**

```gdscript
func _apply_passive_tier(level: int) -> void:
	if not _passive_evolution:
		return
	_current_passive_tier = _passive_evolution.get_tier_for_level(level)
	# 写入 player_stats 供 WeaponManager 读取
	PlayerState.player_stats[Enums.Stat.MELEE_DAMAGE_MULT] = _current_passive_tier.get("melee_damage_mult", 1.0)
	PlayerState.player_stats[Enums.Stat.MELEE_ATTACK_SPEED_MULT] = _current_passive_tier.get("melee_attack_speed_mult", 1.0)
	# 击杀回血
	_kill_heal_amount = _current_passive_tier.get("kill_heal", 0.0)
	if _kill_heal_amount > 0.0 and not EventBus.enemy_killed.is_connected(_on_enemy_killed_heal):
		EventBus.enemy_killed.connect(_on_enemy_killed_heal)
	elif _kill_heal_amount <= 0.0 and EventBus.enemy_killed.is_connected(_on_enemy_killed_heal):
		EventBus.enemy_killed.disconnect(_on_enemy_killed_heal)
```

- [ ] **Step 4: 新增击杀回血回调**

```gdscript
func _on_enemy_killed_heal(_enemy_type: String, _pos: Vector2, _is_elite: bool) -> void:
	if _kill_heal_amount > 0.0:
		health.heal(_kill_heal_amount)
```

- [ ] **Step 5: 修改 `_on_level_up()` 也触发被动进化更新**

在已有的 `_on_level_up()` 中添加被动进化检查：
```gdscript
func _on_level_up(new_level: int) -> void:
	_apply_level_growth(new_level)
	_apply_passive_tier(new_level)
	# 刷新武器乘数
	_weapon_manager.refresh_passive_multipliers()
```

- [ ] **Step 6: 在 `Enums` 中新增近战 Stat 常量**

检查 `scripts/core/enums.gd` 中 `Stat` 常量定义，新增：
```gdscript
const MELEE_DAMAGE_MULT = "MELEE_DAMAGE_MULT"
const MELEE_ATTACK_SPEED_MULT = "MELEE_ATTACK_SPEED_MULT"
```

如果 `Enums.Stat` 是 Dictionary/class 结构，需按现有格式添加。

- [ ] **Step 7: `weapon_manager.gd` 支持近战专属乘数**

在 `scripts/entities/weapons/weapon_manager.gd` 中：

修改 `tick_combat()` (行 138-153)，在 attack.damage_multiplier 赋值时区分近战：
```gdscript
func tick_combat(delta: float) -> void:
	var dynamic_dmg_mult: float = 1.0
	if _dynamic_damage_mult_getter.is_valid():
		dynamic_dmg_mult = _dynamic_damage_mult_getter.call()
	var base_dmg_mult: float = PlayerState.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var melee_dmg_mult: float = PlayerState.player_stats.get(Enums.Stat.MELEE_DAMAGE_MULT, 1.0)
	var melee_spd_mult: float = PlayerState.player_stats.get(Enums.Stat.MELEE_ATTACK_SPEED_MULT, 1.0)
	var count: int = _pivots.size()
	for i in count:
		var pivot: Node2D = _pivots[i]
		var attack = pivot.get_node_or_null("RangedAttackComponent")
		if not attack:
			attack = pivot.get_node_or_null("MeleeAttackComponent")
		if attack:
			var final_dmg: float = base_dmg_mult * dynamic_dmg_mult
			var final_spd: float = 1.0
			if attack is MeleeAttackComponent:
				final_dmg *= melee_dmg_mult
				final_spd = melee_spd_mult
			attack.damage_multiplier = final_dmg
			attack.speed_multiplier = final_spd
			attack.tick(delta)
```

同时修改 `_apply_passive_to_pivot()` (行 188-196)：
```gdscript
func _apply_passive_to_pivot(pivot: Node2D) -> void:
	var dmg_mult: float = PlayerState.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var spd_mult: float = PlayerState.player_stats.get(Enums.Stat.ATTACK_SPEED_MULT, 1.0)
	var melee_dmg: float = PlayerState.player_stats.get(Enums.Stat.MELEE_DAMAGE_MULT, 1.0)
	var melee_spd: float = PlayerState.player_stats.get(Enums.Stat.MELEE_ATTACK_SPEED_MULT, 1.0)
	var attack = pivot.get_node_or_null("RangedAttackComponent")
	if not attack:
		attack = pivot.get_node_or_null("MeleeAttackComponent")
	if attack:
		var final_dmg: float = dmg_mult
		var final_spd: float = spd_mult
		if attack is MeleeAttackComponent:
			final_dmg *= melee_dmg
			final_spd *= melee_spd
		attack.damage_multiplier = final_dmg
		attack.speed_multiplier = final_spd
```

新增 `refresh_passive_multipliers()` 方法（供升级时刷新）：
```gdscript
func refresh_passive_multipliers() -> void:
	for pivot in _pivots:
		_apply_passive_to_pivot(pivot)
```

- [ ] **Step 8: 提交**

```bash
git add scripts/entities/player.gd scripts/entities/weapons/weapon_manager.gd scripts/core/enums.gd
git commit -m "feat: 被动进化系统集成（Dora 剑圣三阶进化 + 近战乘数传递）"
```

---

### Task 9: 更新被动相关测试

**Files:**
- Modify: `tests/unit/test_new_passives.gd`
- Create: `tests/unit/test_passive_evolution.gd` (新测试)
- Create: `tests/unit/test_wave_reward.gd` (新测试)

- [ ] **Step 1: 修改 `test_new_passives.gd`**

- `test_dora_passive_loaded()`: Dora 的 `new_passive_id` 现在是空字符串。修改断言：
```gdscript
func test_dora_passive_loaded() -> void:
	var dora: CharacterData = GameConfig.characters["dora"]
	assert_eq(dora.new_passive_id, "", "Dora 应该使用新被动进化系统")
	assert_not_null(dora.passive_evolution, "Dora 应有 passive_evolution 数据")
	assert_eq(dora.passive_evolution.passive_id, "sword_saint")
```

- `test_reset_applies_starting_gold()`: 更新期望金币 = 40 + 10 = 50（如果硬编码了旧值 130）。

- [ ] **Step 2: 创建 `test_passive_evolution.gd`**

创建 `tests/unit/test_passive_evolution.gd`：
```gdscript
extends GutTest

func test_passive_evolution_data_tier_selection() -> void:
	var evo := PassiveEvolutionData.new()
	evo.tier_1 = { "melee_damage_mult": 1.1 }
	evo.tier_2 = { "melee_damage_mult": 1.2, "melee_attack_speed_mult": 1.1 }
	evo.tier_3 = { "melee_damage_mult": 1.3, "melee_attack_speed_mult": 1.2, "kill_heal": 1.0 }
	evo.tier_2_level = 4
	evo.tier_3_level = 7

	var t1: Dictionary = evo.get_tier_for_level(1)
	assert_eq(t1.get("melee_damage_mult"), 1.1, "Lv1 应返回 tier_1")
	assert_false(t1.has("melee_attack_speed_mult"), "tier_1 不应有攻速")

	var t1_3: Dictionary = evo.get_tier_for_level(3)
	assert_eq(t1_3.get("melee_damage_mult"), 1.1, "Lv3 仍为 tier_1")

	var t2: Dictionary = evo.get_tier_for_level(4)
	assert_eq(t2.get("melee_damage_mult"), 1.2, "Lv4 应返回 tier_2")
	assert_eq(t2.get("melee_attack_speed_mult"), 1.1, "tier_2 应有攻速")

	var t3: Dictionary = evo.get_tier_for_level(7)
	assert_eq(t3.get("melee_damage_mult"), 1.3, "Lv7 应返回 tier_3")
	assert_eq(t3.get("kill_heal"), 1.0, "tier_3 应有击杀回血")

	var t3_9: Dictionary = evo.get_tier_for_level(9)
	assert_eq(t3_9.get("kill_heal"), 1.0, "Lv9 仍为 tier_3")

func test_dora_passive_evolution_loaded() -> void:
	var dora: CharacterData = GameConfig.characters["dora"]
	assert_not_null(dora.passive_evolution)
	var evo: PassiveEvolutionData = dora.passive_evolution
	assert_eq(evo.passive_id, "sword_saint")
	assert_eq(evo.tier_2_level, 4)
	assert_eq(evo.tier_3_level, 7)
	assert_almost_eq(evo.tier_1.get("melee_damage_mult", 0.0), 1.1, 0.01)
	assert_almost_eq(evo.tier_3.get("kill_heal", 0.0), 1.0, 0.01)
```

- [ ] **Step 3: 创建 `test_wave_reward.gd`**

创建 `tests/unit/test_wave_reward.gd`：
```gdscript
extends GutTest

func test_wave_reward_tiers() -> void:
	var config: ShopConfig = GameConfig.shop_config
	assert_eq(config.get_wave_reward(1), 5, "Wave 1 奖励应为 5")
	assert_eq(config.get_wave_reward(5), 5, "Wave 5 奖励应为 5")
	assert_eq(config.get_wave_reward(6), 8, "Wave 6 奖励应为 8")
	assert_eq(config.get_wave_reward(10), 8, "Wave 10 奖励应为 8")
	assert_eq(config.get_wave_reward(11), 10, "Wave 11 奖励应为 10")
	assert_eq(config.get_wave_reward(15), 10, "Wave 15 奖励应为 10")

func test_boss_bounty_config() -> void:
	var config: ShopConfig = GameConfig.shop_config
	assert_eq(config.boss_bounty.get("boss_brute", 0), 15)
	assert_eq(config.boss_bounty.get("boss_summoner", 0), 20)
	assert_eq(config.boss_bounty.get("boss_guardian", 0), 30)
	assert_eq(config.boss_bounty.get("nonexistent", 0), 0)
```

- [ ] **Step 4: 运行所有测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 5: 提交**

```bash
git add tests/unit/test_new_passives.gd tests/unit/test_passive_evolution.gd tests/unit/test_wave_reward.gd
git commit -m "test: 被动进化系统和波次奖励测试"
```

---

### Task 10: 最终验证与清理

- [ ] **Step 1: 运行完整测试套件**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

修复所有失败的测试。

- [ ] **Step 2: 在 Godot 编辑器中验证**

通过 gdai-mcp 的 `play_scene` 工具或 Godot 编辑器运行游戏，验证：
1. 初始金币为 50（Dora: 40+10）
2. 波次结束后奖励正确（Wave 1 = 5金）
3. 商店中没有升级按钮
4. 向日葵产出为 3金/12s
5. Dora 开局有剑且近战伤害正确（+10%）
6. 升级后 HP/移速/拾取范围增长可感知
7. 到达 Lv4/Lv7 时被动进化是否正确切换

- [ ] **Step 3: 提交最终修复**

```bash
git add -A
git commit -m "fix: 资源系统重设计最终修复和验证"
```
