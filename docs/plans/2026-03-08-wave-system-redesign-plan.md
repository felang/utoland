# 波次系统重新设计 - 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将波次系统从纯时间驱动改为击杀制+时间兜底，支持权重随机生成、精英怪、Boss 波和可配置波次数。

**Architecture:** 扩展现有 WaveData Resource 字段，改造 WaveManager 和 EnemySpawner 逻辑。新增 `enemy_killed` 信号的 `is_elite` 参数和 `boss_killed` 信号。Boss 作为独立实体（extends enemy.gd）。波次 .tres 文件按地图分目录存放。

**Tech Stack:** GDScript (Godot 4.6), GUT 测试框架

---

## Task 1: 扩展 EventBus 信号

**Files:**
- Modify: `scripts/core/event_bus.gd:13`

**Step 1: 修改 enemy_killed 信号签名，新增 boss_killed**

当前 `enemy_killed` 签名是 `(enemy_type: String, position: Vector2)`。新增 `is_elite: bool` 参数，并添加 `boss_killed` 信号。

```gdscript
# 战斗事件（修改后）
signal enemy_killed(enemy_type: String, position: Vector2, is_elite: bool)
signal boss_killed(boss_id: String)
```

**Step 2: 更新所有 enemy_killed 的 emit 调用**

- Modify: `scripts/entities/enemy.gd:96`

```gdscript
# 原来：EventBus.enemy_killed.emit(enemy_type, global_position)
# 改为：
EventBus.enemy_killed.emit(enemy_type, global_position, is_elite)
```

需要在 enemy.gd 新增 `var is_elite: bool = false` 变量。

**Step 3: 更新所有 enemy_killed 的 connect 回调签名**

- Modify: `scripts/entities/weapons/weapon.gd` — `_on_enemy_killed` 方法新增 `is_elite: bool` 参数

**Step 4: 运行测试确认不破坏现有功能**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部通过

**Step 5: Commit**

```bash
git add scripts/core/event_bus.gd scripts/entities/enemy.gd scripts/entities/weapons/weapon.gd
git commit -m "refactor: 扩展 enemy_killed 信号支持精英怪标识，新增 boss_killed 信号"
```

---

## Task 2: 扩展 WaveData Resource

**Files:**
- Modify: `scripts/resources/wave_data.gd`

**Step 1: 写失败测试**

- Create: `tests/unit/test_wave_data.gd`

```gdscript
extends GutTest

func test_wave_data_default_values():
	var wd := WaveData.new()
	assert_eq(wd.wave_number, 1)
	assert_eq(wd.total_enemies, 15)
	assert_eq(wd.time_limit, 60.0)
	assert_eq(wd.spawn_interval, 1.5)
	assert_eq(wd.enemy_weights, {"normal": 100})
	assert_eq(wd.elite_chance, 0.0)
	assert_eq(wd.elite_hp_mult, 1.5)
	assert_eq(wd.elite_damage_mult, 1.3)
	assert_eq(wd.elite_coin_mult, 2.0)
	assert_eq(wd.elite_scale, 1.2)
	assert_eq(wd.is_boss_wave, false)
	assert_eq(wd.boss_id, "")
	assert_eq(wd.boss_escort_count, 0)

func test_wave_data_has_no_legacy_fields():
	var wd := WaveData.new()
	# 确认旧字段已移除
	assert_false("duration" in wd, "duration 字段应已被 time_limit 替代")
	assert_false("enemy_types" in wd, "enemy_types 字段应已被 enemy_weights 替代")
```

**Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_wave_data.gd -gexit`
Expected: FAIL（旧字段仍存在，新字段不存在）

**Step 3: 实现 WaveData 扩展**

```gdscript
class_name WaveData
extends Resource

# 基础配置
@export var wave_number: int = 1
@export var total_enemies: int = 15
@export var time_limit: float = 60.0
@export var spawn_interval: float = 1.5

# 敌人权重
@export var enemy_weights: Dictionary = {"normal": 100}

# 精英怪
@export var elite_chance: float = 0.0
@export var elite_hp_mult: float = 1.5
@export var elite_damage_mult: float = 1.3
@export var elite_coin_mult: float = 2.0
@export var elite_scale: float = 1.2

# Boss 波
@export var is_boss_wave: bool = false
@export var boss_id: String = ""
@export var boss_escort_count: int = 0
```

**Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_wave_data.gd -gexit`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/resources/wave_data.gd tests/unit/test_wave_data.gd
git commit -m "feat: 扩展 WaveData Resource，支持击杀制、权重随机、精英怪和 Boss 波"
```

---

## Task 3: 改造 WaveManager — 击杀制结束条件

**Files:**
- Modify: `scripts/systems/wave_manager.gd`
- Create: `tests/unit/test_wave_manager.gd`

**Step 1: 写失败测试**

```gdscript
extends GutTest

var wave_manager: Node

func before_each():
	# 创建独立的 WaveManager 实例（不走 _ready 自动开始）
	wave_manager = load("res://scripts/systems/wave_manager.gd").new()
	add_child_autofree(wave_manager)

func test_wave_manager_tracks_kill_count():
	# 模拟波次开始
	var wd := WaveData.new()
	wd.total_enemies = 5
	wd.time_limit = 60.0
	wave_manager._start_wave_with_data(1, wd)

	assert_eq(wave_manager.enemies_killed, 0)
	# 模拟击杀
	wave_manager._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_eq(wave_manager.enemies_killed, 1)

func test_wave_completes_on_all_killed():
	var wd := WaveData.new()
	wd.total_enemies = 2
	wd.time_limit = 999.0
	wave_manager._start_wave_with_data(1, wd)

	wave_manager._on_enemy_killed("normal", Vector2.ZERO, false)
	wave_manager._on_enemy_killed("fast", Vector2.ZERO, false)
	# 击杀数达到 total_enemies，波次应标记为非活跃
	assert_false(wave_manager.is_wave_active)

func test_wave_completes_on_time_limit():
	var wd := WaveData.new()
	wd.total_enemies = 100
	wd.time_limit = 1.0
	wave_manager._start_wave_with_data(1, wd)

	# 模拟时间流逝
	wave_manager._process(1.1)
	assert_false(wave_manager.is_wave_active)

func test_boss_wave_completes_on_boss_killed():
	var wd := WaveData.new()
	wd.is_boss_wave = true
	wd.boss_id = "boss_brute"
	wd.total_enemies = 100
	wd.time_limit = 999.0
	wave_manager._start_wave_with_data(1, wd)

	wave_manager._on_boss_killed("boss_brute")
	assert_false(wave_manager.is_wave_active)
```

**Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_wave_manager.gd -gexit`
Expected: FAIL

**Step 3: 实现 WaveManager 改造**

关键改动：
- 新增 `enemies_killed: int`、`_current_wave_data: WaveData` 变量
- `_ready()` 中连接 `EventBus.enemy_killed` 和 `EventBus.boss_killed`
- 提取 `_start_wave_with_data(wave_num, wave_data)` 供测试调用
- `_process()` 中检查 `wave_time_left <= 0` 时触发 `complete_wave()`
- `_on_enemy_killed()` 中累加 `enemies_killed`，达到 `total_enemies` 时触发 `complete_wave()`
- `_on_boss_killed()` 中直接触发 `complete_wave()`
- `start_next_wave()` 中读取 `wave_data.time_limit` 替代原 `wave_data.duration`
- 每波开始重置 `enemies_killed = 0`

完整实现：

```gdscript
extends Node

const VICTORY_DELAY: float = 1.0
const WAVE_CLEANUP_DELAY: float = 2.0
const SHOP_TRANSITION_DELAY: float = 1.0

var total_waves: int = GameConfig.waves.size()
var current_wave: int = 0
var wave_time_left: float = 0.0
var is_wave_active: bool = false
var enemies_killed: int = 0
var _current_wave_data: WaveData = null

func _ready() -> void:
	add_to_group(Enums.Group.WAVE_MANAGER)
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.boss_killed.connect(_on_boss_killed)
	if GameData.current_wave > 0:
		current_wave = GameData.current_wave
	start_next_wave()

func _process(delta: float) -> void:
	if is_wave_active:
		wave_time_left -= delta
		if wave_time_left <= 0:
			complete_wave()

func start_next_wave() -> void:
	current_wave += 1
	GameData.current_wave = current_wave

	if current_wave > total_waves:
		EventBus.game_won.emit()
		print("Victory! You completed all waves!")
		await get_tree().create_timer(VICTORY_DELAY).timeout
		SceneManager.go_to(Enums.Scene.RESULT)
		return

	var wave_data: WaveData = GameConfig.waves[current_wave - 1]
	_start_wave_with_data(current_wave, wave_data)

func _start_wave_with_data(wave_num: int, wave_data: WaveData) -> void:
	_current_wave_data = wave_data
	enemies_killed = 0
	wave_time_left = wave_data.time_limit
	is_wave_active = true
	EventBus.wave_started.emit(wave_num, wave_data)
	var fx: EffectConfigData = GameConfig.effects
	if fx:
		EventBus.camera_shake_requested.emit(fx.camera_shake_wave_start_intensity, fx.camera_shake_wave_start_duration)
	print("Wave ", wave_num, " started!")

func complete_wave() -> void:
	if not is_wave_active:
		return
	is_wave_active = false
	attract_all_coins()
	await get_tree().create_timer(WAVE_CLEANUP_DELAY).timeout
	clear_all_enemies()
	EventBus.wave_completed.emit(current_wave)
	print("Wave ", current_wave, " completed!")

	await get_tree().create_timer(SHOP_TRANSITION_DELAY).timeout
	SceneManager.go_to(Enums.Scene.SHOP)

func _on_enemy_killed(_enemy_type: String, _position: Vector2, _is_elite: bool) -> void:
	if not is_wave_active:
		return
	enemies_killed += 1
	if _current_wave_data and not _current_wave_data.is_boss_wave:
		if enemies_killed >= _current_wave_data.total_enemies:
			complete_wave()

func _on_boss_killed(_boss_id: String) -> void:
	if not is_wave_active:
		return
	complete_wave()

func attract_all_coins() -> void:
	var coins: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.COINS)
	for coin in coins:
		if coin.has_method("force_attract"):
			coin.force_attract()

func clear_all_enemies() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	for enemy in enemies:
		if enemy.has_method("set_physics_process"):
			enemy.set_physics_process(false)
			enemy.set_process(false)
		enemy.queue_free()

func _on_player_died() -> void:
	EventBus.game_lost.emit()
```

**Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_wave_manager.gd -gexit`
Expected: PASS

**Step 5: 运行全部测试确认没有回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部通过

**Step 6: Commit**

```bash
git add scripts/systems/wave_manager.gd tests/unit/test_wave_manager.gd
git commit -m "feat: WaveManager 改为击杀制+时间兜底，支持 Boss 波结束条件"
```

---

## Task 4: 改造 EnemySpawner — 权重随机 + 生成上限

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd`
- Create: `tests/unit/test_enemy_spawner.gd`

**Step 1: 写失败测试**

```gdscript
extends GutTest

var spawner: Node

func before_each():
	spawner = load("res://scripts/systems/enemy_spawner.gd").new()
	add_child_autofree(spawner)

func test_pick_weighted_enemy_single_type():
	var weights := {"normal": 100}
	var result: String = spawner.pick_weighted_enemy(weights)
	assert_eq(result, "normal")

func test_pick_weighted_enemy_returns_valid_type():
	var weights := {"normal": 70, "fast": 30}
	for i in range(50):
		var result: String = spawner.pick_weighted_enemy(weights)
		assert_true(result in ["normal", "fast"], "应返回有效敌人类型: %s" % result)

func test_enemies_spawned_counter():
	var wd := WaveData.new()
	wd.total_enemies = 3
	wd.spawn_interval = 1.0
	wd.enemy_weights = {"normal": 100}
	spawner._on_wave_started(1, wd)
	assert_eq(spawner.enemies_spawned, 0)

func test_spawner_stops_at_total_enemies():
	var wd := WaveData.new()
	wd.total_enemies = 2
	wd.enemy_weights = {"normal": 100}
	spawner._on_wave_started(1, wd)
	assert_true(spawner._should_spawn())
	spawner.enemies_spawned = 2
	assert_false(spawner._should_spawn())
```

**Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_enemy_spawner.gd -gexit`
Expected: FAIL

**Step 3: 实现改造**

关键改动：
- 新增 `enemies_spawned: int` 计数器
- 新增 `pick_weighted_enemy(weights: Dictionary) -> String` 方法
- 新增 `_should_spawn() -> bool` 方法检查 `enemies_spawned < total_enemies`
- `spawn_enemy()` 使用 `pick_weighted_enemy` 替代原随机选取
- `_on_wave_started()` 重置 `enemies_spawned = 0`
- `_process()` 中调用 `_should_spawn()` 判断是否继续生成

完整实现：

```gdscript
extends Node

var spawn_timer: float = 0.0
var player: Node2D
var _current_wave_data: WaveData = null
var _is_wave_active: bool = false
var enemies_spawned: int = 0

# Map boundaries
var map_min_x: float = -GameConfig.MAP_HALF_WIDTH
var map_max_x: float = GameConfig.MAP_HALF_WIDTH
var map_min_y: float = -GameConfig.MAP_HALF_HEIGHT
var map_max_y: float = GameConfig.MAP_HALF_HEIGHT
var min_distance_from_player: float = 200.0

func _ready() -> void:
	player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if GameConfig.spawn:
		min_distance_from_player = GameConfig.spawn.min_distance_from_player
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.game_won.connect(_on_game_ended)
	EventBus.game_lost.connect(_on_game_ended)

func _process(delta: float) -> void:
	if not _is_wave_active:
		return

	spawn_timer -= delta
	if spawn_timer <= 0 and _should_spawn():
		spawn_enemy()
		spawn_timer = _current_wave_data.spawn_interval

func _should_spawn() -> bool:
	if not _current_wave_data:
		return false
	return enemies_spawned < _current_wave_data.total_enemies

func spawn_enemy() -> void:
	var enemy_type: String = pick_weighted_enemy(_current_wave_data.enemy_weights)
	var enemy: Node = SceneFactory.create_enemy(enemy_type)
	if not enemy:
		return

	var spawn_pos: Vector2 = get_random_spawn_position()
	enemy.global_position = spawn_pos
	enemies_spawned += 1
	get_parent().add_child(enemy)

func pick_weighted_enemy(weights: Dictionary) -> String:
	var total_weight: int = 0
	for w: int in weights.values():
		total_weight += w

	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for enemy_id: String in weights:
		cumulative += weights[enemy_id]
		if roll < cumulative:
			return enemy_id

	# 兜底（不应到达）
	return weights.keys()[0]

func get_random_spawn_position() -> Vector2:
	var spawn_pos := Vector2.ZERO
	var attempts := 0
	var max_attempts: int = GameConfig.spawn.max_spawn_attempts if GameConfig.spawn else 10

	while attempts < max_attempts:
		spawn_pos.x = randf_range(map_min_x, map_max_x)
		spawn_pos.y = randf_range(map_min_y, map_max_y)

		if player and player.global_position.distance_to(spawn_pos) >= min_distance_from_player:
			break
		attempts += 1

	return spawn_pos

func _on_wave_started(_wave_number: int, wave_data: WaveData) -> void:
	_current_wave_data = wave_data
	_is_wave_active = true
	enemies_spawned = 0
	spawn_timer = 0.0

func _on_wave_completed(_wave_number: int) -> void:
	_is_wave_active = false

func _on_game_ended() -> void:
	_is_wave_active = false
```

**Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_enemy_spawner.gd -gexit`
Expected: PASS

**Step 5: 运行全部测试确认没有回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部通过

**Step 6: Commit**

```bash
git add scripts/systems/enemy_spawner.gd tests/unit/test_enemy_spawner.gd
git commit -m "feat: EnemySpawner 支持权重随机选敌和生成上限控制"
```

---

## Task 5: 精英怪生成

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd`
- Modify: `scripts/entities/enemy.gd`
- Create: `tests/unit/test_elite_enemy.gd`

**Step 1: 写失败测试**

```gdscript
extends GutTest

var test_scene: Node2D

func before_each():
	test_scene = Node2D.new()
	add_child_autofree(test_scene)

func test_enemy_has_is_elite_flag():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	assert_eq(enemy.is_elite, false, "默认不是精英怪")

func test_elite_enemy_has_boosted_hp():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	var base_hp: float = enemy.health.max_hp

	enemy.apply_elite(1.5, 1.3, 2.0, 1.2)
	assert_almost_eq(enemy.health.max_hp, base_hp * 1.5, 0.01)
	assert_almost_eq(enemy.health.current_hp, base_hp * 1.5, 0.01)
	assert_true(enemy.is_elite)
	assert_true(enemy.is_in_group("elites"))

func test_elite_enemy_has_boosted_damage():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	var base_damage: float = enemy.tower_attack_damage

	enemy.apply_elite(1.5, 1.3, 2.0, 1.2)
	assert_almost_eq(enemy.tower_attack_damage, base_damage * 1.3, 0.01)

func test_elite_enemy_emits_is_elite_true():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	enemy.apply_elite(1.5, 1.3, 2.0, 1.2)

	# 监听信号
	var signal_received := false
	var received_is_elite := false
	EventBus.enemy_killed.connect(func(_t, _p, ie): received_is_elite = ie; signal_received = true)

	enemy._on_died()
	assert_true(signal_received)
	assert_true(received_is_elite)
```

**Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_elite_enemy.gd -gexit`
Expected: FAIL

**Step 3: 实现 enemy.gd 的精英化方法**

在 `enemy.gd` 新增：

```gdscript
# 在变量区域新增
var is_elite: bool = false
var _elite_coin_mult: float = 1.0

# 新增方法
func apply_elite(hp_mult: float, damage_mult: float, coin_mult: float, scale_mult: float) -> void:
	is_elite = true
	_elite_coin_mult = coin_mult
	health.max_hp *= hp_mult
	health.current_hp = health.max_hp
	tower_attack_damage *= damage_mult
	_hitbox.damage *= damage_mult
	scale *= scale_mult
	add_to_group("elites")
```

修改 `_on_died()` 中的 emit：

```gdscript
EventBus.enemy_killed.emit(enemy_type, global_position, is_elite)
```

修改 `_drop_coins()` 中应用精英金币倍率：

```gdscript
var coin_count: int = randi_range(data.coin_drop_min, data.coin_drop_max)
coin_count = int(coin_count * _elite_coin_mult)
```

**Step 4: 在 EnemySpawner 中集成精英生成**

在 `enemy_spawner.gd` 的 `spawn_enemy()` 方法中，创建敌人后检查精英概率：

```gdscript
func spawn_enemy() -> void:
	var enemy_type: String = pick_weighted_enemy(_current_wave_data.enemy_weights)
	var enemy: Node = SceneFactory.create_enemy(enemy_type)
	if not enemy:
		return

	# 精英怪检查
	if _current_wave_data.elite_chance > 0.0 and randf() < _current_wave_data.elite_chance:
		enemy.apply_elite(
			_current_wave_data.elite_hp_mult,
			_current_wave_data.elite_damage_mult,
			_current_wave_data.elite_coin_mult,
			_current_wave_data.elite_scale
		)

	var spawn_pos: Vector2 = get_random_spawn_position()
	enemy.global_position = spawn_pos
	enemies_spawned += 1
	get_parent().add_child(enemy)
```

**Step 5: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部通过

**Step 6: Commit**

```bash
git add scripts/entities/enemy.gd scripts/systems/enemy_spawner.gd tests/unit/test_elite_enemy.gd
git commit -m "feat: 精英怪系统 — 运行时属性加成、金币倍率和视觉放大"
```

---

## Task 6: Boss 波生成逻辑

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd`
- Create: `tests/unit/test_boss_wave_spawner.gd`

**Step 1: 写失败测试**

```gdscript
extends GutTest

var spawner: Node

func before_each():
	spawner = load("res://scripts/systems/enemy_spawner.gd").new()
	add_child_autofree(spawner)

func test_boss_wave_has_escort_phase():
	var wd := WaveData.new()
	wd.is_boss_wave = true
	wd.boss_id = "boss_brute"
	wd.boss_escort_count = 5
	wd.total_enemies = 5
	wd.enemy_weights = {"normal": 100}
	spawner._on_wave_started(1, wd)
	assert_eq(spawner._boss_phase, spawner.BossPhase.ESCORT)

func test_boss_phase_transitions_after_escorts():
	var wd := WaveData.new()
	wd.is_boss_wave = true
	wd.boss_id = "boss_brute"
	wd.boss_escort_count = 2
	wd.total_enemies = 2
	wd.enemy_weights = {"normal": 100}
	spawner._on_wave_started(1, wd)

	# 模拟生成了 2 个护卫
	spawner.enemies_spawned = 2
	assert_false(spawner._should_spawn_escort())
	assert_eq(spawner._get_next_boss_phase(), spawner.BossPhase.BOSS)

func test_normal_wave_has_no_boss_phase():
	var wd := WaveData.new()
	wd.is_boss_wave = false
	spawner._on_wave_started(1, wd)
	assert_eq(spawner._boss_phase, spawner.BossPhase.NONE)
```

**Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_boss_wave_spawner.gd -gexit`
Expected: FAIL

**Step 3: 实现 Boss 波分阶段**

在 `enemy_spawner.gd` 新增：

```gdscript
enum BossPhase { NONE, ESCORT, BOSS, DONE }

var _boss_phase: int = BossPhase.NONE
var _boss_spawned: bool = false
```

修改 `_on_wave_started()`：

```gdscript
func _on_wave_started(_wave_number: int, wave_data: WaveData) -> void:
	_current_wave_data = wave_data
	_is_wave_active = true
	enemies_spawned = 0
	spawn_timer = 0.0
	_boss_spawned = false
	if wave_data.is_boss_wave:
		_boss_phase = BossPhase.ESCORT
	else:
		_boss_phase = BossPhase.NONE
```

修改 `_process()` 中 Boss 波逻辑：

```gdscript
func _process(delta: float) -> void:
	if not _is_wave_active:
		return

	# Boss 波状态机
	if _current_wave_data.is_boss_wave:
		_process_boss_wave(delta)
		return

	# 普通波
	spawn_timer -= delta
	if spawn_timer <= 0 and _should_spawn():
		spawn_enemy()
		spawn_timer = _current_wave_data.spawn_interval

func _process_boss_wave(delta: float) -> void:
	match _boss_phase:
		BossPhase.ESCORT:
			spawn_timer -= delta
			if spawn_timer <= 0 and _should_spawn_escort():
				spawn_enemy()
				spawn_timer = _current_wave_data.spawn_interval
			elif not _should_spawn_escort():
				_boss_phase = BossPhase.BOSS
		BossPhase.BOSS:
			if not _boss_spawned:
				_spawn_boss()
				_boss_phase = BossPhase.DONE
		BossPhase.DONE:
			pass

func _should_spawn_escort() -> bool:
	return enemies_spawned < _current_wave_data.boss_escort_count

func _get_next_boss_phase() -> int:
	if not _should_spawn_escort():
		return BossPhase.BOSS
	return BossPhase.ESCORT

func _spawn_boss() -> void:
	var boss: Node = SceneFactory.create_enemy(_current_wave_data.boss_id)
	if not boss:
		push_error("无法创建 Boss: " + _current_wave_data.boss_id)
		return
	var spawn_pos: Vector2 = get_random_spawn_position()
	boss.global_position = spawn_pos
	_boss_spawned = true
	get_parent().add_child(boss)
```

**注意**：Boss 的 EnemyData 和场景在 Task 8 中创建。此处 `_spawn_boss()` 暂时复用 `SceneFactory.create_enemy()`，Boss 的 enemy_type 需要在 SceneFactory 中注册。

**Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部通过

**Step 5: Commit**

```bash
git add scripts/systems/enemy_spawner.gd tests/unit/test_boss_wave_spawner.gd
git commit -m "feat: EnemySpawner Boss 波分阶段生成（护卫→Boss→完成）"
```

---

## Task 7: MapData 扩展 + GameConfig 按地图加载波次

**Files:**
- Modify: `scripts/resources/map_data.gd`
- Modify: `scripts/core/game_config.gd`
- Create: `tests/unit/test_map_waves.gd`

**Step 1: 写失败测试**

```gdscript
extends GutTest

func test_map_data_has_wave_count():
	var md := MapData.new()
	assert_true("wave_count" in md, "MapData 应有 wave_count 字段")

func test_game_config_loads_waves_for_map():
	# 测试 GameConfig 能按地图 id 加载对应波次
	var waves: Array = GameConfig.get_waves_for_map("forest")
	assert_gt(waves.size(), 0, "森林地图应有波次配置")
	for w in waves:
		assert_true(w is WaveData, "每项应为 WaveData")
```

**Step 2: 运行测试确认失败**

Expected: FAIL

**Step 3: 实现**

`map_data.gd` 新增：

```gdscript
@export var wave_count: int = 10
```

`game_config.gd` 改造：
- `waves` 改为 `Dictionary`：`var waves_by_map: Dictionary = {}` — `{map_id: Array[WaveData]}`
- 保留 `var waves: Array = []` 作为当前地图的波次引用（向后兼容）
- 新增 `_load_waves_by_map()` 遍历 `resources/waves/` 下的子目录
- 新增 `get_waves_for_map(map_id: String) -> Array` 方法
- `_ready()` 中调用新加载方法，并设置默认 `waves = waves_by_map["forest"]`

```gdscript
var waves: Array = []  # 当前地图的波次（向后兼容）
var waves_by_map: Dictionary = {}  # {map_id: Array[WaveData]}

func _ready() -> void:
	# ...existing loads...
	_load_waves_by_map("res://resources/waves/")
	# 默认加载 forest（向后兼容）
	if waves_by_map.has("forest"):
		waves = waves_by_map["forest"]

func _load_waves_by_map(base_path: String) -> void:
	var dir := DirAccess.open(base_path)
	if not dir:
		push_error("无法打开波次目录: " + base_path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry != "." and entry != "..":
			var map_waves: Array = []
			_load_wave_files(base_path + entry + "/", map_waves)
			if map_waves.size() > 0:
				waves_by_map[entry] = map_waves
		entry = dir.get_next()

	# 向后兼容：如果没有子目录，直接从根目录加载
	if waves_by_map.is_empty():
		_load_wave_files(base_path, waves)

func _load_wave_files(path: String, target: Array) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res: Resource = load(path + file_name)
			if res is WaveData:
				target.append(res)
		file_name = dir.get_next()
	target.sort_custom(func(a: WaveData, b: WaveData) -> bool: return a.wave_number < b.wave_number)

func get_waves_for_map(map_id: String) -> Array:
	if waves_by_map.has(map_id):
		return waves_by_map[map_id]
	return waves
```

**Step 4: 创建 forest 子目录并迁移波次文件**

```bash
mkdir -p resources/waves/forest
mv resources/waves/wave_*.tres resources/waves/forest/
```

**Step 5: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部通过

**Step 6: 修改 WaveManager 使用当前选择的地图**

在 `wave_manager.gd` 的 `_ready()` 中：

```gdscript
# 原来：total_waves = GameConfig.waves.size()
# 改为：
var map_waves: Array = GameConfig.get_waves_for_map(GameData.selected_map)
if map_waves.size() > 0:
	GameConfig.waves = map_waves
total_waves = GameConfig.waves.size()
```

**Step 7: Commit**

```bash
git add scripts/resources/map_data.gd scripts/core/game_config.gd scripts/systems/wave_manager.gd tests/unit/test_map_waves.gd resources/waves/
git commit -m "feat: 按地图分目录加载波次配置，MapData 新增 wave_count"
```

---

## Task 8: 重写波次 .tres 配置文件（forest 地图 18 波）

**Files:**
- Rewrite: `resources/waves/forest/wave_01.tres` ~ `wave_18.tres`

**Step 1: 删除旧的 10 个 .tres 文件，按设计文档创建 18 个新文件**

每个 .tres 文件格式如下（以 wave_01 为例）：

```ini
[gd_resource type="Resource" script_class="WaveData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/wave_data.gd" id="1"]

[resource]
script = ExtResource("1")
wave_number = 1
total_enemies = 10
time_limit = 45.0
spawn_interval = 2.0
enemy_weights = {"normal": 100}
elite_chance = 0.0
is_boss_wave = false
```

按设计文档中的 18 波难度曲线表逐一创建。Boss 波（wave_08, wave_15, wave_18）需设置 `is_boss_wave = true`、`boss_id` 和 `boss_escort_count`。

**注意**：Boss 的 EnemyData 尚未创建（Task 9），boss_id 先填写但暂时不能在游戏中测试 Boss 波。

**Step 2: 运行测试确认加载正常**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部通过

**Step 3: Commit**

```bash
git add resources/waves/forest/
git commit -m "feat: 重写 forest 地图 18 波次配置（击杀制 + 权重 + 精英 + Boss）"
```

---

## Task 9: Boss 实体框架（boss_brute 为例）

**Files:**
- Create: `resources/enemies/boss_brute.tres`
- Create: `scripts/entities/boss_base.gd`
- Create: `scripts/entities/boss_brute.gd`
- Create: `scenes/entities/enemies/boss_brute.tscn`
- Modify: `scripts/core/scene_factory.gd` — 注册 Boss 场景
- Modify: `scripts/core/enums.gd` — 新增 Boss 常量
- Create: `tests/integration/test_boss_entity.gd`

**Step 1: 写失败测试**

```gdscript
extends GutTest

var test_scene: Node2D

func before_each():
	test_scene = Node2D.new()
	add_child_autofree(test_scene)

func test_boss_brute_creation():
	var boss = SceneFactory.create_enemy("boss_brute")
	assert_not_null(boss, "应能创建 boss_brute")
	test_scene.add_child(boss)
	assert_eq(boss.enemy_type, "boss_brute")
	assert_true(boss.is_in_group(Enums.Group.ENEMIES))

func test_boss_brute_has_high_hp():
	var boss = SceneFactory.create_enemy("boss_brute")
	test_scene.add_child(boss)
	var normal_data: EnemyData = GameConfig.enemies["normal"]
	assert_gt(boss.health.max_hp, normal_data.hp * 5, "Boss 应有远高于普通怪的 HP")

func test_boss_emits_boss_killed_on_death():
	var boss = SceneFactory.create_enemy("boss_brute")
	test_scene.add_child(boss)

	var signal_received := false
	EventBus.boss_killed.connect(func(_id): signal_received = true)
	boss._on_died()
	assert_true(signal_received, "Boss 死亡应发出 boss_killed 信号")
```

**Step 2: 运行测试确认失败**

Expected: FAIL

**Step 3: 实现**

`scripts/core/enums.gd` — Enemy 类新增：
```gdscript
const BOSS_BRUTE = "boss_brute"
const BOSS_SUMMONER = "boss_summoner"
const BOSS_GUARDIAN = "boss_guardian"
```

`resources/enemies/boss_brute.tres`：
```ini
[gd_resource type="Resource" script_class="EnemyData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/enemy_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "boss_brute"
display_name = "蛮兽"
hp = 500.0
speed = 60.0
damage = 30.0
coin_drop_min = 15
coin_drop_max = 25
```

`scripts/entities/boss_base.gd`（Boss 基类，extends enemy.gd 的核心逻辑）：
```gdscript
extends "res://scripts/entities/enemy.gd"

# Boss 基类 — 死亡时额外发出 boss_killed 信号

func _on_died() -> void:
	EventBus.boss_killed.emit(enemy_type)
	super._on_died()
```

`scripts/entities/boss_brute.gd`：
```gdscript
extends "res://scripts/entities/boss_base.gd"

# Boss: 蛮兽 — 重型近战 Boss
# 专属行为（冲锋、践踏）在后续迭代中实现
```

`scenes/entities/enemies/boss_brute.tscn`：
- 复制 `enemy_normal.tscn` 结构
- 替换脚本为 `boss_brute.gd`
- 保留所有组件（HealthComponent, SpriteAnimator, Hitbox, Hurtbox, KnockbackHandler, SlowHandler）

`scripts/core/scene_factory.gd` — 注册 Boss 场景：
```gdscript
var _enemy_scenes: Dictionary = {
	Enums.Enemy.NORMAL: preload("res://scenes/entities/enemies/enemy_normal.tscn"),
	Enums.Enemy.FAST: preload("res://scenes/entities/enemies/enemy_fast.tscn"),
	Enums.Enemy.TANK: preload("res://scenes/entities/enemies/enemy_tank.tscn"),
	Enums.Enemy.BOSS_BRUTE: preload("res://scenes/entities/enemies/boss_brute.tscn"),
}
```

**Step 4: 配置 Boss 精灵（暂时复用 tank 精灵，放大）**

在 `GameConfig.SPRITES["enemies"]` 新增：
```gdscript
"boss_brute": {
	"spritesheet": "res://assets/sprites/enemies/trex.png",
	"frame_size": Vector2(16, 16),
	"walk_frames": 4,
	"walk_directions": 4,
	"fps": 5.0
}
```

Boss 场景 scale 设为 Vector2(2.0, 2.0) 以区分普通怪。

**Step 5: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部通过

**Step 6: Commit**

```bash
git add scripts/core/enums.gd scripts/core/scene_factory.gd scripts/core/game_config.gd \
  scripts/entities/boss_base.gd scripts/entities/boss_brute.gd \
  scenes/entities/enemies/boss_brute.tscn resources/enemies/boss_brute.tres \
  tests/integration/test_boss_entity.gd
git commit -m "feat: Boss 实体框架 — boss_brute 蛮兽（独立场景+EnemyData+SceneFactory注册）"
```

---

## Task 10: 端到端集成测试 + 全量回归

**Files:**
- Create: `tests/integration/test_wave_system.gd`

**Step 1: 写集成测试**

```gdscript
extends GutTest

func test_wave_data_loads_from_config():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	assert_eq(waves.size(), 18, "Forest 地图应有 18 波")
	# 验证排序
	for i in range(waves.size() - 1):
		assert_lt(waves[i].wave_number, waves[i + 1].wave_number)

func test_boss_waves_exist():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	var boss_waves := []
	for w: WaveData in waves:
		if w.is_boss_wave:
			boss_waves.append(w.wave_number)
	assert_eq(boss_waves.size(), 3, "应有 3 个 Boss 波")

func test_all_enemy_weights_reference_valid_types():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	for w: WaveData in waves:
		for enemy_id: String in w.enemy_weights:
			assert_true(GameConfig.enemies.has(enemy_id), "敌人类型 '%s' 应在 GameConfig 中注册" % enemy_id)

func test_boss_ids_reference_valid_enemies():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	for w: WaveData in waves:
		if w.is_boss_wave:
			assert_true(GameConfig.enemies.has(w.boss_id), "Boss '%s' 应在 GameConfig 中注册" % w.boss_id)
```

**Step 2: 运行全部测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部通过

**Step 3: Commit**

```bash
git add tests/integration/test_wave_system.gd
git commit -m "test: 波次系统端到端集成测试"
```

---

## Task 11: 手动游戏内验证

**Step 1: 在 Godot 编辑器中运行游戏**

验证清单：
- [ ] 第 1 波：10 个 normal 敌人，全部击杀后波次结束
- [ ] 第 3 波：有精英怪出现（体型更大），精英怪掉落更多金币
- [ ] 波次间商店正常打开
- [ ] 时间上限兜底生效（可临时将某波 time_limit 设为 5 秒测试）
- [ ] 第 8 波（Boss 波）：先刷护卫小怪，然后出 Boss，Boss 死亡结束波次

**Step 2: 修复发现的问题（如有）**

**Step 3: 最终 Commit**

```bash
git commit -m "fix: 波次系统手动验证修复"  # 如有修复
```
