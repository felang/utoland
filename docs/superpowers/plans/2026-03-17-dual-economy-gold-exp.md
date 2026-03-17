# 金币经验双轨制 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将单一金币经济改为金币 + 经验双轨制：怪物掉经验球升人口，金币改为每波固定奖励 + 向日葵生成。

**Architecture:** 新建 ExpConfig Resource 和 ExpOrb 实体，改写 GameData 的升级/人口逻辑为经验公式驱动（无上限），移除 buy_level_up 及相关 UI。金币来源从怪物掉落改为波次固定奖励。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-17-dual-economy-gold-exp-design.md`

---

## Chunk 1: Core Infrastructure & Data Layer

### Task 1: EventBus 新增经验信号

**Files:**
- Modify: `scripts/core/event_bus.gd:19-22`

- [ ] **Step 1: 新增经验信号**

在 `event_bus.gd` 的经济事件区块（line 19-22 之后）添加：

```gdscript
# 经验事件
signal exp_collected(value: int, position: Vector2)
signal exp_changed(current_exp: int, exp_to_next: int)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/core/event_bus.gd
git commit -m "feat: EventBus 新增 exp_collected/exp_changed 信号"
```

---

### Task 2: Enums 新增 EXP_ORBS 分组

**Files:**
- Modify: `scripts/core/enums.gd:3-10`

- [ ] **Step 1: 新增分组常量**

在 `enums.gd` 的 `Group` 类中（line 10 之后）添加：

```gdscript
const EXP_ORBS = "exp_orbs"
```

- [ ] **Step 2: Commit**

```bash
git add scripts/core/enums.gd
git commit -m "feat: Enums.Group 新增 EXP_ORBS 分组常量"
```

---

### Task 3: ExpConfig Resource

**Files:**
- Create: `scripts/resources/exp_config.gd`
- Create: `resources/exp_config.tres`
- Modify: `scripts/core/game_config.gd:121,134`

- [ ] **Step 1: 创建 ExpConfig 类**

创建 `scripts/resources/exp_config.gd`：

```gdscript
class_name ExpConfig
extends Resource

## 经验升级公式参数：exp_for_level(n) = floor(base_exp * n ^ exp_exponent)
@export var base_exp: float = 5.0
@export var exp_exponent: float = 2.0

## 人口系统
@export var initial_population: int = 2
@export var population_per_level: int = 1
```

- [ ] **Step 2: 创建 .tres 数据文件**

创建 `resources/exp_config.tres`：

```
[gd_resource type="Resource" script_class="ExpConfig" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/exp_config.gd" id="1"]

[resource]
script = ExtResource("1")
base_exp = 5.0
exp_exponent = 2.0
initial_population = 2
population_per_level = 1
```

- [ ] **Step 3: 更新 global_script_class_cache.cfg**

新增 `class_name ExpConfig` 的脚本后，headless 测试需要手动在 `.godot/global_script_class_cache.cfg` 中补充条目。在文件的 `list=` 数组中添加：

```
{
"base": &"Resource",
"class": &"ExpConfig",
"icon": "",
"language": &"GDScript",
"path": "res://scripts/resources/exp_config.gd"
}
```

- [ ] **Step 4: GameConfig 注册 exp_config**

在 `game_config.gd` line 122（`spawn` 之后）添加变量：

```gdscript
var exp_config: ExpConfig = null
```

在 `_ready()` 中 line 135（`spawn = load(...)` 之后）添加加载：

```gdscript
exp_config = load("res://resources/exp_config.tres")
```

- [ ] **Step 5: Commit**

```bash
git add scripts/resources/exp_config.gd resources/exp_config.tres scripts/core/game_config.gd .godot/global_script_class_cache.cfg
git commit -m "feat: 新建 ExpConfig Resource 并注册到 GameConfig"
```

---

### Task 4: ShopConfig 移除升级字段、新增 wave_reward

**Files:**
- Modify: `scripts/resources/shop_config.gd`
- Modify: `resources/shop/shop_config.tres`

- [ ] **Step 1: 修改 ShopConfig 类**

将 `shop_config.gd` 改为：

```gdscript
class_name ShopConfig
extends Resource

# 商店全局配置：槽位、刷新费用、物品费用、波次奖励

@export var slot_count: int = 4
@export var refresh_cost: int = 2
@export var item_cost: int = 3
@export var wave_reward: int = 10
```

- [ ] **Step 2: 确认 .tres 文件**

`resources/shop/shop_config.tres` 当前只引用脚本，无显式字段覆盖（使用脚本默认值）。类变更后默认值自动生效，无需修改 .tres 文件。

- [ ] **Step 3: Commit**

```bash
git add scripts/resources/shop_config.gd resources/shop/shop_config.tres
git commit -m "refactor: ShopConfig 移除 level_up_costs/population_per_level，新增 wave_reward"
```

---

### Task 5: EnemyData 新增 exp_drop 字段

**Files:**
- Modify: `scripts/resources/enemy_data.gd:9-10`

- [ ] **Step 1: 新增字段**

在 `enemy_data.gd` line 10（`coin_drop_max` 之后）添加：

```gdscript
@export var exp_drop_min: int = 1
@export var exp_drop_max: int = 1
```

- [ ] **Step 2: Commit**

```bash
git add scripts/resources/enemy_data.gd
git commit -m "feat: EnemyData 新增 exp_drop_min/exp_drop_max 字段"
```

---

### Task 6: WaveData 新增 elite_exp_mult

**Files:**
- Modify: `scripts/resources/wave_data.gd:17`

- [ ] **Step 1: 新增字段**

在 `wave_data.gd` line 18（`elite_scale` 之后）添加：

```gdscript
@export var elite_exp_mult: float = 2.0
```

- [ ] **Step 2: Commit**

```bash
git add scripts/resources/wave_data.gd
git commit -m "feat: WaveData 新增 elite_exp_mult 字段"
```

---

### Task 7: GameData 经验系统核心逻辑

**Files:**
- Modify: `scripts/core/game_data.gd`
- Test: `tests/unit/test_game_data_economy.gd`

- [ ] **Step 1: 写失败测试 — add_exp 和自动升级**

在 `tests/unit/test_game_data_economy.gd` 中，替换原有的 `test_buy_level_up_*` 测试（lines 150-187）为以下经验系统测试：

```gdscript
# ===== 经验系统 =====

func test_add_exp_accumulates() -> void:
	GameData.current_exp = 0
	GameData.add_exp(10)
	assert_eq(GameData.current_exp, 10)
	GameData.add_exp(5)
	assert_eq(GameData.current_exp, 15)

func test_add_exp_records_total() -> void:
	GameData.total_exp_earned = 0
	GameData.current_exp = 0
	GameData.add_exp(10)
	assert_eq(GameData.total_exp_earned, 10)

func test_add_exp_auto_level_up() -> void:
	GameData.player_level = 1
	GameData.current_exp = 0
	# exp_for_level(2) = floor(5 * 2^2) = 20
	GameData.add_exp(20)
	assert_eq(GameData.player_level, 2)

func test_add_exp_no_level_up_below_threshold() -> void:
	GameData.player_level = 1
	GameData.current_exp = 0
	GameData.add_exp(19)
	assert_eq(GameData.player_level, 1)

func test_add_exp_multi_level_up() -> void:
	GameData.player_level = 1
	GameData.current_exp = 0
	# exp_for_level(2) = 20, exp_for_level(3) = 45
	GameData.add_exp(45)
	assert_eq(GameData.player_level, 3)

func test_add_exp_emits_level_changed() -> void:
	GameData.player_level = 1
	GameData.current_exp = 0
	var level_changes: Array[int] = []
	EventBus.player_level_changed.connect(func(lvl: int): level_changes.append(lvl))
	GameData.add_exp(20)
	assert_eq(level_changes, [2])
	for conn in EventBus.player_level_changed.get_connections():
		EventBus.player_level_changed.disconnect(conn["callable"])

func test_add_exp_emits_exp_changed() -> void:
	GameData.player_level = 1
	GameData.current_exp = 0
	var exp_events: Array[Array] = []
	EventBus.exp_changed.connect(func(cur: int, to_next: int): exp_events.append([cur, to_next]))
	GameData.add_exp(10)
	assert_eq(exp_events.size(), 1)
	assert_eq(exp_events[0][0], 10)  # current_exp
	for conn in EventBus.exp_changed.get_connections():
		EventBus.exp_changed.disconnect(conn["callable"])
```

- [ ] **Step 2: 写失败测试 — get_population_cap 新公式**

替换原有 `test_get_population_cap_*` 测试（lines 24-40）为：

```gdscript
func test_get_population_cap_level1() -> void:
	GameData.player_level = 1
	# initial_population + (1-1) * 1 = 2
	assert_eq(GameData.get_population_cap(), 2)

func test_get_population_cap_level5() -> void:
	GameData.player_level = 5
	# initial_population + (5-1) * 1 = 6
	assert_eq(GameData.get_population_cap(), 6)

func test_get_population_cap_level10() -> void:
	GameData.player_level = 10
	# initial_population + (10-1) * 1 = 11
	assert_eq(GameData.get_population_cap(), 11)
```

- [ ] **Step 3: 写失败测试 — reset 包含新字段**

在测试文件中新增：

```gdscript
func test_reset_clears_exp_fields() -> void:
	GameData.current_exp = 999
	GameData.total_exp_earned = 888
	GameData.player_level = 5
	GameData.reset()
	assert_eq(GameData.current_exp, 0)
	assert_eq(GameData.total_exp_earned, 0)
	assert_eq(GameData.player_level, 1)
```

- [ ] **Step 4: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_game_data_economy.gd`

Expected: FAIL（方法/字段不存在）

- [ ] **Step 5: 实现 GameData 经验系统**

修改 `scripts/core/game_data.gd`：

**5a. 新增字段**（line 27 之后，`player_level` 下方）：

```gdscript
var current_exp: int = 0
var total_exp_earned: int = 0
```

**5b. 更新 `_DEFAULTS`**（在 line 69 `"player_level": 1,` 之后添加）：

```gdscript
"current_exp": 0,
"total_exp_earned": 0,
```

**5c. 改写 `get_population_cap()`**（替换 lines 142-144）：

```gdscript
func get_population_cap() -> int:
	var config: ExpConfig = GameConfig.exp_config
	return config.initial_population + (player_level - 1) * config.population_per_level
```

**5d. 替换 `buy_level_up()` 为 `add_exp()` 和 `exp_for_level()`**（替换 lines 166-179）：

```gdscript
# ===== 经验系统 =====

func exp_for_level(level: int) -> int:
	var config: ExpConfig = GameConfig.exp_config
	return int(floor(config.base_exp * pow(level, config.exp_exponent)))

func add_exp(amount: int) -> void:
	current_exp += amount
	total_exp_earned += amount
	# 循环检查升级
	while current_exp >= exp_for_level(player_level + 1):
		player_level += 1
		EventBus.player_level_changed.emit(player_level)
	# 通知经验变化
	var next_threshold: int = exp_for_level(player_level + 1)
	EventBus.exp_changed.emit(current_exp, next_threshold)
```

- [ ] **Step 6: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_game_data_economy.gd`

Expected: ALL PASS

- [ ] **Step 7: Commit**

```bash
git add scripts/core/game_data.gd tests/unit/test_game_data_economy.gd
git commit -m "feat: GameData 经验系统 — add_exp 自动升级、公式化人口上限，移除 buy_level_up"
```

---

## Chunk 2: Exp Orb Entity & Enemy Integration

### Task 8: 经验球实体

**Files:**
- Create: `scripts/entities/exp_orb.gd`
- Create: `scenes/entities/exp_orb.tscn`
- Modify: `scripts/core/scene_factory.gd:19,48-50`

- [ ] **Step 1: 创建经验球占位精灵**

创建一个简单的占位图片。用绿色圆形代替，可复用 `gold_coin.png` 临时替代。暂时使用 `assets/items/gold_coin.png` 作为占位（后续替换）。

- [ ] **Step 2: 创建 exp_orb.gd**

创建 `scripts/entities/exp_orb.gd`：

```gdscript
extends Area2D

const FORCE_ATTRACT_SPEED_MULT: float = 1.6

@export var value: int = 1
@export var attract_speed: float = 200.0
@export var attract_range: float = 30.0

var player: Node2D = null
var is_attracted: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	add_to_group(Enums.Group.EXP_ORBS)

func _process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
		if not player:
			return

	if global_position.distance_to(player.global_position) < attract_range:
		is_attracted = true

	if is_attracted:
		var direction: Vector2 = global_position.direction_to(player.global_position)
		global_position += direction * attract_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(Enums.Group.PLAYER):
		body.add_exp(value)
		AudioManager.play("coin_pickup")  # 占位音效，后续替换
		_play_pickup_effect()

func _play_pickup_effect() -> void:
	set_deferred("monitoring", false)
	var shrink_dur: float = GameConfig.effects.coin_pickup_shrink_duration
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), shrink_dur)
	tween.tween_property(self, "modulate:a", 0.0, shrink_dur)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func force_attract() -> void:
	is_attracted = true
	attract_speed = attract_speed * FORCE_ATTRACT_SPEED_MULT
```

- [ ] **Step 3: 创建 exp_orb.tscn**

创建 `scenes/entities/exp_orb.tscn`（参照 coin.tscn 结构）：

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/entities/exp_orb.gd" id="1_exp"]
[ext_resource type="Texture2D" path="res://assets/items/gold_coin.png" id="2_exp"]

[sub_resource type="CircleShape2D" id="CircleShape2D_exp"]
radius = 3.0

[node name="ExpOrb" type="Area2D"]
collision_layer = 16
collision_mask = 1
script = ExtResource("1_exp")

[node name="Visual" type="Sprite2D" parent="."]
texture = ExtResource("2_exp")
modulate = Color(0.3, 1.0, 0.5, 1.0)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_exp")
```

注意：`modulate = Color(0.3, 1.0, 0.5, 1.0)` 将金币精灵染为绿色作为占位区分。

- [ ] **Step 4: SceneFactory 注册经验球**

在 `scene_factory.gd` line 19（`_coin_scene` 之后）添加：

```gdscript
var _exp_orb_scene: PackedScene = preload("res://scenes/entities/exp_orb.tscn")
```

在 line 50（`create_coin()` 之后）添加：

```gdscript
func create_exp_orb() -> Area2D:
	return _exp_orb_scene.instantiate()
```

- [ ] **Step 5: Commit**

```bash
git add scripts/entities/exp_orb.gd scenes/entities/exp_orb.tscn scripts/core/scene_factory.gd
git commit -m "feat: 新建经验球实体 ExpOrb + SceneFactory.create_exp_orb()"
```

---

### Task 9: Player 新增 add_exp 方法

**Files:**
- Modify: `scripts/entities/player.gd:111-113`

- [ ] **Step 1: 新增 add_exp 方法**

在 `player.gd` line 113（`add_coins()` 之后）添加：

```gdscript
func add_exp(amount: int) -> void:
	GameData.add_exp(amount)
	EventBus.exp_collected.emit(amount, global_position)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/entities/player.gd
git commit -m "feat: Player.add_exp() 经验收集方法"
```

---

### Task 10: Enemy 改为掉落经验球

**Files:**
- Modify: `scripts/entities/enemy.gd:5,14,100-132`
- Test: `tests/unit/test_elite_enemy.gd`

- [ ] **Step 1: 写失败测试 — apply_elite 新增 exp_mult 参数**

更新 `tests/unit/test_elite_enemy.gd`，所有 `apply_elite` 调用从 4 参数改为 5 参数，并新增 exp_mult 测试：

将所有 `enemy.apply_elite(1.5, 1.3, 2.0, 1.2)` 改为 `enemy.apply_elite(1.5, 1.3, 2.0, 1.2, 3.0)`。

新增测试：

```gdscript
func test_apply_elite_sets_exp_mult():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	enemy.apply_elite(1.5, 1.3, 2.0, 1.2, 3.0)
	assert_eq(enemy._elite_exp_mult, 3.0)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_elite_enemy.gd`

Expected: FAIL（参数数量不匹配，`_elite_exp_mult` 不存在）

- [ ] **Step 3: 实现 enemy.gd 改动**

**3a. 新增常量和变量**（line 5 旁，`COIN_SCATTER_RANGE` 之后）：

```gdscript
const EXP_SCATTER_RANGE: float = 20.0
```

在 line 14（`_elite_coin_mult` 之后）添加：

```gdscript
var _elite_exp_mult: float = 1.0
```

**3b. 新增 `_drop_exp_orbs()` 方法**（在 `_drop_coins()` 方法之后，line 123 之后）：

```gdscript
func _drop_exp_orbs() -> void:
	var parent: Node = get_parent()
	if not parent:
		return

	var orb_count: int = randi_range(data.exp_drop_min, data.exp_drop_max)
	orb_count = int(orb_count * _elite_exp_mult)
	for i in orb_count:
		var orb = SceneFactory.create_exp_orb()
		orb.global_position = global_position + Vector2(randf_range(-EXP_SCATTER_RANGE, EXP_SCATTER_RANGE), randf_range(-EXP_SCATTER_RANGE, EXP_SCATTER_RANGE))
		parent.call_deferred("add_child", orb)
```

**3c. `_on_died()` 调用 `_drop_exp_orbs()` 替代 `_drop_coins()`**（line 108）：

将 `_drop_coins()` 改为 `_drop_exp_orbs()`。

**3d. `apply_elite()` 新增 `exp_mult` 参数**（替换 line 124）：

```gdscript
func apply_elite(hp_mult: float, damage_mult: float, coin_mult: float, scale_mult: float, exp_mult: float = 1.0) -> void:
	is_elite = true
	_elite_coin_mult = coin_mult
	_elite_exp_mult = exp_mult
	health.max_hp *= hp_mult
	health.current_hp = health.max_hp
	tower_attack_damage *= damage_mult
	_hitbox.damage *= damage_mult
	scale *= scale_mult
	add_to_group("elites")
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_elite_enemy.gd`

Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/entities/enemy.gd tests/unit/test_elite_enemy.gd
git commit -m "feat: Enemy 掉落经验球替代金币，apply_elite 新增 exp_mult"
```

---

### Task 11: EnemySpawner 传入 exp_mult

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd:91-97`

- [ ] **Step 1: 更新 apply_elite 调用**

在 `enemy_spawner.gd` lines 91-97，修改 `apply_elite` 调用添加第 5 个参数：

```gdscript
if _current_wave_data.elite_chance > 0.0 and randf() < _current_wave_data.elite_chance:
	enemy.apply_elite(
		_current_wave_data.elite_hp_mult,
		_current_wave_data.elite_damage_mult,
		_current_wave_data.elite_coin_mult,
		_current_wave_data.elite_scale,
		_current_wave_data.elite_exp_mult
	)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/systems/enemy_spawner.gd
git commit -m "feat: EnemySpawner 传入 elite_exp_mult 到 apply_elite"
```

---

## Chunk 3: Wave System, UI & Data Files

### Task 12: WaveManager 吸引经验球

**Files:**
- Modify: `scripts/systems/wave_manager.gd:54,60-64`

- [ ] **Step 1: 新增 attract_all_exp_orbs 方法**

在 `wave_manager.gd` line 64（`attract_all_coins()` 方法之后）添加：

```gdscript
func attract_all_exp_orbs() -> void:
	var orbs: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.EXP_ORBS)
	for orb in orbs:
		if orb.has_method("force_attract"):
			orb.force_attract()
```

- [ ] **Step 2: 在 complete_wave() 中调用**

在 line 54（`attract_all_coins()` 之后）添加：

```gdscript
attract_all_exp_orbs()
```

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/wave_manager.gd
git commit -m "feat: WaveManager 波次结束强制吸引经验球"
```

---

### Task 13: main.gd 波次奖励金币

**Files:**
- Modify: `scripts/ui/main.gd:61-92,147-148`

- [ ] **Step 1: _enter_shop_phase 发放波次奖励**

在 `main.gd` 的 `_enter_shop_phase()` 方法中，line 90（`_shop_overlay.refresh_shop(is_first)` 之前）添加波次奖励逻辑：

```gdscript
# 波次结束奖励金币（首次商店不发，首次用初始金币）
if not is_first:
	var reward: int = GameConfig.shop_config.wave_reward
	GameData.coins += reward
	GameData.record_coins_earned(reward)
	EventBus.coins_changed.emit(reward, GameData.coins)
	# 同步 Player 金币
	var player_node: Node2D = $Player
	if player_node:
		player_node.coins = GameData.coins
```

- [ ] **Step 2: Commit**

```bash
git add scripts/ui/main.gd
git commit -m "feat: 波次结束固定奖励金币（ShopConfig.wave_reward）"
```

---

### Task 14: ShopOverlay 移除升级按钮

**Files:**
- Modify: `scripts/ui/shop_overlay.gd:20,107-111,175-178,225-233,279-281`

- [ ] **Step 1: 移除 _level_up_button 变量声明**

删除 line 20：`var _level_up_button: Button`

- [ ] **Step 2: 移除 _setup_ui 中的升级按钮创建**

删除 lines 107-111（`# --- 升级按钮 ---` 区块的 4 行代码）。

- [ ] **Step 3: 移除 _update_ui 中的 _update_level_up_button 调用**

删除 line 178：`_update_level_up_button()`

- [ ] **Step 4: 移除 _update_level_up_button 方法**

删除 lines 225-233 整个方法。

- [ ] **Step 5: 移除 _on_level_up_pressed 方法**

删除 lines 279-281 整个方法。

- [ ] **Step 6: 修复 _update_info_bar 人口显示**

将 line 184：

```gdscript
var pop_max: int = GameConfig.shop_config.population_per_level[GameData.player_level - 1]
```

改为：

```gdscript
var pop_max: int = GameData.get_population_cap()
```

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/shop_overlay.gd
git commit -m "refactor: ShopOverlay 移除升级按钮，人口显示改用 GameData.get_population_cap()"
```

---

### Task 15: 结算页面新增经验统计

**Files:**
- Modify: `scripts/ui/result.gd:28-33`

- [ ] **Step 1: 新增经验统计行**

在 `result.gd` line 29（`"获取金币"` 之后）添加一行：

```gdscript
_add_stat_row(stats_grid, "获取经验", str(GameData.total_exp_earned))
```

- [ ] **Step 2: Commit**

```bash
git add scripts/ui/result.gd
git commit -m "feat: 结算页面新增经验统计"
```

---

### Task 16: 敌人 .tres 配置 exp_drop

**Files:**
- Modify: `resources/enemies/normal.tres`
- Modify: `resources/enemies/fast.tres`
- Modify: `resources/enemies/tank.tres`
- Modify: `resources/enemies/boss_brute.tres`
- Modify: `resources/enemies/boss_summoner.tres`
- Modify: `resources/enemies/boss_guardian.tres`

- [ ] **Step 1: 为每种敌人配置经验掉落**

在每个 `.tres` 文件的 `[resource]` 区块末尾添加 `exp_drop_min` 和 `exp_drop_max`：

| 敌人 | exp_drop_min | exp_drop_max |
|------|-------------|-------------|
| normal | 1 | 1 |
| fast | 1 | 2 |
| tank | 2 | 3 |
| boss_brute | 10 | 15 |
| boss_summoner | 10 | 15 |
| boss_guardian | 10 | 15 |

示例（normal.tres 追加）：

```
exp_drop_min = 1
exp_drop_max = 1
```

示例（boss_brute.tres 追加）：

```
exp_drop_min = 10
exp_drop_max = 15
```

- [ ] **Step 2: Commit**

```bash
git add resources/enemies/
git commit -m "feat: 配置所有敌人 exp_drop_min/exp_drop_max"
```

---

### Task 17: 波次 .tres 配置 elite_exp_mult

**Files:**
- Modify: `resources/waves/forest/wave_*.tres`（含 elite_chance > 0 的波次）

- [ ] **Step 1: 配置有精英怪的波次**

对 `resources/waves/forest/` 中 `elite_chance > 0` 的波次文件，追加 `elite_exp_mult = 2.0`。由于 WaveData 默认值已设为 2.0，只有需要不同值的波次才需要显式配置。检查各波次文件，确认默认值合适即可（无需改动即可用默认值）。

- [ ] **Step 2: Commit（如有改动）**

```bash
git add resources/waves/
git commit -m "feat: 波次 .tres 配置 elite_exp_mult（如需覆盖默认值）"
```

---

### Task 18: 全量测试验证

**Files:**
- Test: `tests/unit/test_game_data_economy.gd`
- Test: `tests/unit/test_elite_enemy.gd`

- [ ] **Step 1: 运行全部单元测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

Expected: ALL PASS

- [ ] **Step 2: 修复任何失败的测试**

如果有其他测试因依赖 `buy_level_up()` 或 `ShopConfig.population_per_level` / `level_up_costs` 而失败，逐一修复。

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "test: 全量测试通过，经验双轨制实装完成"
```
