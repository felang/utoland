# 波次系统重设计 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将波次系统从"时间+敌人数量"双重结束条件改为纯时间制+分段生成，总波次缩减为 15 波（每 5 波一个 Boss）。

**Architecture:** 新建 `SpawnPhaseData` Resource 类定义分段生成参数。改造 `WaveData` 移除 `total_enemies`/`spawn_interval`/`boss_escort_count`，新增 `max_alive_enemies`/`spawn_phases`。`EnemySpawner` 改为分段式生成逻辑（阶段切换 + max_alive 上限）。`WaveManager` 简化为纯时间结束。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-17-wave-system-redesign.md`

---

## Chunk 1: Resource 层改造 + 基础测试

### Task 1: 新建 SpawnPhaseData Resource

**Files:**
- Create: `scripts/resources/spawn_phase_data.gd`

- [ ] **Step 1: 创建 SpawnPhaseData Resource 类**

```gdscript
class_name SpawnPhaseData
extends Resource

## 该阶段占波次总时长的比例（所有阶段之和 = 1.0）
@export var duration_ratio: float = 0.5
## 该阶段的生成间隔（秒）
@export var spawn_interval: float = 1.0
## 该阶段的敌人权重（留空则继承波次级别的 enemy_weights）
@export var enemy_weights: Dictionary = {}
```

- [ ] **Step 2: 在 global_script_class_cache.cfg 中注册 SpawnPhaseData**

在 `.godot/global_script_class_cache.cfg` 的 `list` 数组中追加：

```
{
"base": &"Resource",
"class": &"SpawnPhaseData",
"icon": "",
"is_abstract": false,
"is_tool": false,
"language": &"GDScript",
"path": "res://scripts/resources/spawn_phase_data.gd"
}
```

- [ ] **Step 3: Commit**

```bash
git add scripts/resources/spawn_phase_data.gd .godot/global_script_class_cache.cfg
git commit -m "feat: 新建 SpawnPhaseData Resource 类"
```

### Task 2: 改造 WaveData Resource

**Files:**
- Modify: `scripts/resources/wave_data.gd`

- [ ] **Step 1: 移除旧字段，新增新字段**

在 `wave_data.gd` 中：
- 移除 `total_enemies: int`
- 移除 `spawn_interval: float`
- 移除 `boss_escort_count: int`
- 新增 `max_alive_enemies: int = 30`
- 新增 `spawn_phases: Array[SpawnPhaseData] = []`

最终文件：

```gdscript
class_name WaveData
extends Resource

# 基础配置
@export var wave_number: int = 1
@export var time_limit: float = 60.0

# 分段生成
@export var max_alive_enemies: int = 30
@export var spawn_phases: Array[SpawnPhaseData] = []

# 敌人权重（默认，段内可覆盖）
@export var enemy_weights: Dictionary = {"normal": 100}

# 精英怪
@export var elite_chance: float = 0.0
@export var elite_hp_mult: float = 1.5
@export var elite_damage_mult: float = 1.3
@export var elite_coin_mult: float = 2.0
@export var elite_scale: float = 1.2
@export var elite_exp_mult: float = 2.0

# Boss 波
@export var is_boss_wave: bool = false
@export var boss_id: String = ""
```

- [ ] **Step 2: Commit**

```bash
git add scripts/resources/wave_data.gd
git commit -m "refactor: WaveData 移除 total_enemies/spawn_interval/boss_escort_count，新增分段生成字段"
```

### Task 3: EventBus 新增 boss_escaped 信号

**Files:**
- Modify: `scripts/core/event_bus.gd`

- [ ] **Step 1: 在波次系统信号区域添加 boss_escaped 信号**

在 `event_bus.gd` 的 `# 波次系统` 区域，`game_lost` 下方添加：

```gdscript
signal boss_escaped(boss_id: String)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/core/event_bus.gd
git commit -m "feat: EventBus 新增 boss_escaped 信号"
```

---

## Chunk 2: WaveManager 改造

### Task 4: WaveManager 测试先行

**Files:**
- Modify: `tests/unit/test_wave_manager.gd`

- [ ] **Step 1: 重写测试文件，覆盖纯时间制逻辑**

完全重写 `tests/unit/test_wave_manager.gd`：

```gdscript
extends GutTest

## WaveManager 纯时间制单元测试

var wave_manager: Node

func before_each():
	wave_manager = load("res://scripts/systems/wave_manager.gd").new()

func _make_wave_data(time_limit: float = 60.0, is_boss: bool = false, boss_id: String = "") -> WaveData:
	var wd := WaveData.new()
	wd.time_limit = time_limit
	wd.is_boss_wave = is_boss
	wd.boss_id = boss_id
	return wd

func test_wave_completes_on_time_limit():
	var wd := _make_wave_data(1.0)
	wave_manager._start_wave_with_data(1, wd)
	wave_manager._process(1.1)
	assert_false(wave_manager.is_wave_active, "波次应在时间到后结束")

func test_wave_stays_active_before_time_limit():
	var wd := _make_wave_data(10.0)
	wave_manager._start_wave_with_data(1, wd)
	wave_manager._process(5.0)
	assert_true(wave_manager.is_wave_active, "时间未到波次应保持活跃")

func test_enemy_kills_do_not_end_wave():
	var wd := _make_wave_data(999.0)
	wave_manager._start_wave_with_data(1, wd)
	# 击杀大量敌人不应结束波次
	for i in range(100):
		wave_manager._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_true(wave_manager.is_wave_active, "击杀敌人不应结束波次")

func test_boss_kill_does_not_end_wave():
	var wd := _make_wave_data(999.0, true, "boss_brute")
	wave_manager._start_wave_with_data(1, wd)
	wave_manager._on_boss_killed("boss_brute")
	assert_true(wave_manager.is_wave_active, "Boss 被杀不应立即结束波次")
	assert_true(wave_manager._boss_killed_this_wave, "应标记 Boss 已击杀")

func test_boss_wave_time_up_without_kill_marks_escaped():
	var wd := _make_wave_data(1.0, true, "boss_brute")
	wave_manager._start_wave_with_data(1, wd)
	# 不击杀 Boss，时间到
	wave_manager._process(1.1)
	assert_false(wave_manager.is_wave_active, "时间到波次应结束")
	# boss_escaped 信号由 complete_wave() 触发（需要 EventBus 连接验证）

func test_boss_wave_time_up_after_kill_no_escape():
	var wd := _make_wave_data(1.0, true, "boss_brute")
	wave_manager._start_wave_with_data(1, wd)
	wave_manager._on_boss_killed("boss_brute")
	wave_manager._process(1.1)
	assert_false(wave_manager.is_wave_active)
	assert_true(wave_manager._boss_killed_this_wave)

func test_boss_killed_flag_resets_each_wave():
	var wd1 := _make_wave_data(999.0, true, "boss_brute")
	wave_manager._start_wave_with_data(1, wd1)
	wave_manager._on_boss_killed("boss_brute")
	assert_true(wave_manager._boss_killed_this_wave)
	var wd2 := _make_wave_data(999.0)
	wave_manager._start_wave_with_data(2, wd2)
	assert_false(wave_manager._boss_killed_this_wave, "新波次应重置 Boss 击杀标记")

```

- [ ] **Step 2: 运行测试，确认失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_wave_manager.gd -gexit
```

预期：多个测试失败（`_boss_killed_this_wave` 不存在，击杀仍会结束波次等）

- [ ] **Step 3: Commit 失败测试**

```bash
git add tests/unit/test_wave_manager.gd
git commit -m "test: 重写 WaveManager 测试为纯时间制"
```

### Task 5: 改造 WaveManager 实现

**Files:**
- Modify: `scripts/systems/wave_manager.gd`

- [ ] **Step 1: 改造 WaveManager**

完整替换 `wave_manager.gd`：

```gdscript
extends Node

const VICTORY_DELAY: float = 1.0
const WAVE_CLEANUP_DELAY: float = 2.0
const SHOP_TRANSITION_DELAY: float = 1.0

var total_waves: int = 0
var current_wave: int = 0
var wave_time_left: float = 0.0
var is_wave_active: bool = false
var _current_wave_data: WaveData = null
var _boss_killed_this_wave: bool = false

func _ready() -> void:
	add_to_group(Enums.Group.WAVE_MANAGER)
	EventBus.player_died.connect(_on_player_died)
	EventBus.boss_killed.connect(_on_boss_killed)
	var map_waves: Array = GameConfig.get_waves_for_map(GameData.selected_map)
	if map_waves.size() > 0:
		GameConfig.waves = map_waves
	total_waves = GameConfig.waves.size()
	if GameData.current_wave > 0:
		current_wave = GameData.current_wave

func _process(delta: float) -> void:
	if not is_wave_active:
		return
	wave_time_left -= delta
	if wave_time_left <= 0:
		complete_wave()

func start_next_wave() -> void:
	current_wave += 1
	GameData.current_wave = current_wave
	if current_wave > total_waves:
		EventBus.game_won.emit()
		await get_tree().create_timer(VICTORY_DELAY).timeout
		SceneManager.go_to(Enums.Scene.RESULT)
		return
	var wave_data: WaveData = GameConfig.waves[current_wave - 1]
	_start_wave_with_data(current_wave, wave_data)

func complete_wave() -> void:
	if not is_wave_active:
		return
	is_wave_active = false
	EventBus.wave_completed.emit(current_wave)
	AudioManager.play("wave_complete")
	# Boss 波次：时间到但 Boss 未被击杀 → 发送逃跑信号
	if _current_wave_data and _current_wave_data.is_boss_wave and not _boss_killed_this_wave:
		EventBus.boss_escaped.emit(_current_wave_data.boss_id)
	if not is_inside_tree():
		return
	attract_all_coins()
	attract_all_exp_orbs()
	await get_tree().create_timer(WAVE_CLEANUP_DELAY).timeout
	clear_all_enemies()
	await get_tree().create_timer(SHOP_TRANSITION_DELAY).timeout
	EventBus.wave_transition_ready.emit()

func attract_all_coins() -> void:
	var coins: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.COINS)
	for coin in coins:
		if coin.has_method("force_attract"):
			coin.force_attract()

func attract_all_exp_orbs() -> void:
	var orbs: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.EXP_ORBS)
	for orb in orbs:
		if orb.has_method("force_attract"):
			orb.force_attract()

func clear_all_enemies() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	for enemy in enemies:
		if enemy.has_method("set_physics_process"):
			enemy.set_physics_process(false)
			enemy.set_process(false)
		enemy.queue_free()

func _start_wave_with_data(wave_num: int, wave_data: WaveData) -> void:
	_current_wave_data = wave_data
	_boss_killed_this_wave = false
	wave_time_left = wave_data.time_limit
	is_wave_active = true
	EventBus.wave_started.emit(wave_num, wave_data)
	AudioManager.play("wave_start")
	var fx: EffectConfigData = GameConfig.effects
	if fx:
		EventBus.camera_shake_requested.emit(fx.camera_shake_wave_start_intensity, fx.camera_shake_wave_start_duration)

func _on_enemy_killed(_enemy_type: String, _position: Vector2, _is_elite: bool) -> void:
	# 纯时间制：击杀不影响波次结束
	pass

func _on_boss_killed(_boss_id: String) -> void:
	if not is_wave_active:
		return
	_boss_killed_this_wave = true

func _on_player_died() -> void:
	EventBus.game_lost.emit()
```

关键变化：
- 移除 `enemies_killed` 变量
- 新增 `_boss_killed_this_wave: bool` 标记
- `_on_enemy_killed` 改为空实现（保留连接以防其他系统依赖）
- `_on_boss_killed` 不再调用 `complete_wave()`，只标记
- `complete_wave()` 中在 `wave_completed` 信号后、清场前检查 boss_escaped
- `_ready()` 中移除 `EventBus.enemy_killed.connect`（不再需要）

- [ ] **Step 2: 运行测试验证通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_wave_manager.gd -gexit
```

预期：所有测试 PASS

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/wave_manager.gd
git commit -m "refactor: WaveManager 改为纯时间制结束条件"
```

---

## Chunk 3: EnemySpawner 改造

### Task 6: EnemySpawner 测试先行

**Files:**
- Modify: `tests/unit/test_boss_wave_spawner.gd`

- [ ] **Step 1: 重写 Boss 波次 + 分段生成测试**

完全重写 `tests/unit/test_boss_wave_spawner.gd`：

```gdscript
extends GutTest

## EnemySpawner 分段生成 + Boss 波次测试

var spawner: Node

func before_each():
	spawner = load("res://scripts/systems/enemy_spawner.gd").new()
	add_child_autofree(spawner)

func _make_phase(ratio: float, interval: float, weights: Dictionary = {}) -> SpawnPhaseData:
	var phase := SpawnPhaseData.new()
	phase.duration_ratio = ratio
	phase.spawn_interval = interval
	phase.enemy_weights = weights
	return phase

func _make_wave_data(time_limit: float = 60.0, phases: Array[SpawnPhaseData] = [], max_alive: int = 30) -> WaveData:
	var wd := WaveData.new()
	wd.time_limit = time_limit
	wd.max_alive_enemies = max_alive
	wd.spawn_phases = phases
	wd.enemy_weights = {"normal": 100}
	return wd

func test_enters_first_phase_on_wave_start():
	var phases: Array[SpawnPhaseData] = [
		_make_phase(0.5, 2.0),
		_make_phase(0.5, 1.0),
	]
	var wd := _make_wave_data(60.0, phases)
	spawner._on_wave_started(1, wd)
	assert_eq(spawner._current_phase_index, 0)
	assert_almost_eq(spawner._phase_duration, 30.0, 0.01, "第一阶段应为 60 * 0.5 = 30 秒")
	assert_almost_eq(spawner._current_spawn_interval, 2.0, 0.01)

func test_phase_transition():
	var phases: Array[SpawnPhaseData] = [
		_make_phase(0.3, 2.0),
		_make_phase(0.7, 0.5),
	]
	var wd := _make_wave_data(100.0, phases)
	spawner._on_wave_started(1, wd)
	# 模拟经过 30 秒（phase 0 的 duration = 100 * 0.3 = 30）
	spawner._phase_time_elapsed = 31.0
	spawner._check_phase_transition()
	assert_eq(spawner._current_phase_index, 1)
	assert_almost_eq(spawner._current_spawn_interval, 0.5, 0.01)

func test_last_phase_does_not_overflow():
	var phases: Array[SpawnPhaseData] = [
		_make_phase(0.5, 2.0),
		_make_phase(0.5, 1.0),
	]
	var wd := _make_wave_data(60.0, phases)
	spawner._on_wave_started(1, wd)
	# 跳到最后阶段
	spawner._current_phase_index = 1
	spawner._phase_time_elapsed = 999.0
	spawner._check_phase_transition()
	# 应保持在最后阶段，不越界
	assert_eq(spawner._current_phase_index, 1)

func test_phase_inherits_wave_enemy_weights():
	var phases: Array[SpawnPhaseData] = [
		_make_phase(1.0, 1.0),  # enemy_weights 为空
	]
	var wd := _make_wave_data(60.0, phases)
	wd.enemy_weights = {"normal": 70, "fast": 30}
	spawner._on_wave_started(1, wd)
	assert_eq(spawner._current_enemy_weights, {"normal": 70, "fast": 30})

func test_phase_overrides_enemy_weights():
	var custom_weights := {"tank": 100}
	var phases: Array[SpawnPhaseData] = [
		_make_phase(1.0, 1.0, custom_weights),
	]
	var wd := _make_wave_data(60.0, phases)
	wd.enemy_weights = {"normal": 100}
	spawner._on_wave_started(1, wd)
	assert_eq(spawner._current_enemy_weights, {"tank": 100})

func test_boss_should_spawn_on_last_phase():
	var phases: Array[SpawnPhaseData] = [
		_make_phase(0.6, 1.0),
		_make_phase(0.4, 0.5),
	]
	var wd := _make_wave_data(60.0, phases)
	wd.is_boss_wave = true
	wd.boss_id = "boss_brute"
	spawner._on_wave_started(1, wd)
	assert_false(spawner._boss_spawned)
	assert_false(spawner._should_spawn_boss(), "第一阶段不应生成 Boss")
	# 模拟切到最后阶段（不调用 _enter_phase 避免触发实际生成）
	spawner._current_phase_index = 1
	assert_true(spawner._should_spawn_boss(), "最后阶段应触发 Boss 生成")

func test_boss_spawned_flag_resets():
	var phases: Array[SpawnPhaseData] = [_make_phase(1.0, 1.0)]
	var wd := WaveData.new()
	wd.is_boss_wave = true
	wd.boss_id = "boss_brute"
	wd.spawn_phases = phases
	wd.time_limit = 60.0
	wd.max_alive_enemies = 30
	wd.enemy_weights = {"normal": 100}
	spawner._on_wave_started(1, wd)
	assert_false(spawner._boss_spawned)

func test_wave_completed_stops_spawning():
	var phases: Array[SpawnPhaseData] = [_make_phase(1.0, 1.0)]
	var wd := _make_wave_data(60.0, phases)
	spawner._on_wave_started(1, wd)
	assert_true(spawner._is_wave_active)
	spawner._on_wave_completed(1)
	assert_false(spawner._is_wave_active)
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_boss_wave_spawner.gd -gexit
```

预期：大量失败（`_current_phase_index`、`_check_phase_transition` 等不存在）

- [ ] **Step 3: Commit 失败测试**

```bash
git add tests/unit/test_boss_wave_spawner.gd
git commit -m "test: 重写 EnemySpawner 测试为分段生成模式"
```

### Task 7: 改造 EnemySpawner 实现

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd`

- [ ] **Step 1: 完整重写 EnemySpawner**

```gdscript
extends Node
class_name EnemySpawner

const SCALING_START_WAVE := 11
const HP_SCALING_PER_WAVE := 1.06
const DAMAGE_SCALING_PER_WAVE := 1.04

var spawn_timer: float = 0.0
var player: Node2D
var _current_wave_data: WaveData = null
var _is_wave_active: bool = false
var _boss_spawned: bool = false

# 分段生成状态
var _current_phase_index: int = 0
var _phase_time_elapsed: float = 0.0
var _phase_duration: float = 0.0
var _current_spawn_interval: float = 1.0
var _current_enemy_weights: Dictionary = {}

# 地图边界
var map_min_x: float = 0.0
var map_max_x: float = 0.0
var map_min_y: float = 0.0
var map_max_y: float = 0.0
var min_distance_from_player: float = 100.0

func _ready() -> void:
	map_min_x = -GameConfig.MAP_HALF_WIDTH
	map_max_x = GameConfig.MAP_HALF_WIDTH
	map_min_y = -GameConfig.MAP_HALF_HEIGHT
	map_max_y = GameConfig.MAP_HALF_HEIGHT
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
	_phase_time_elapsed += delta
	_check_phase_transition()
	# max_alive 检查
	var alive_count: int = get_tree().get_nodes_in_group(Enums.Group.ENEMIES).size()
	if alive_count >= _current_wave_data.max_alive_enemies:
		return
	# 生成计时
	spawn_timer -= delta
	if spawn_timer <= 0:
		_spawn_normal_enemy()
		spawn_timer = _current_spawn_interval

func _check_phase_transition() -> void:
	if not _current_wave_data or _current_wave_data.spawn_phases.is_empty():
		return
	# 最后阶段不切换
	if _current_phase_index >= _current_wave_data.spawn_phases.size() - 1:
		return
	if _phase_time_elapsed >= _phase_duration:
		_enter_phase(_current_phase_index + 1)

func _enter_phase(index: int) -> void:
	_current_phase_index = index
	var phase: SpawnPhaseData = _current_wave_data.spawn_phases[index]
	_phase_duration = _current_wave_data.time_limit * phase.duration_ratio
	_phase_time_elapsed = 0.0
	_current_spawn_interval = phase.spawn_interval
	_current_enemy_weights = phase.enemy_weights if not phase.enemy_weights.is_empty() else _current_wave_data.enemy_weights
	# Boss 波次：进入最后阶段时生成 Boss
	if _current_wave_data.is_boss_wave and index == _current_wave_data.spawn_phases.size() - 1:
		if not _boss_spawned:
			_spawn_boss()

func _should_spawn_boss() -> bool:
	if not _current_wave_data or not _current_wave_data.is_boss_wave:
		return false
	return _current_phase_index == _current_wave_data.spawn_phases.size() - 1 and not _boss_spawned

static func get_wave_scaling(wave_number: int) -> Dictionary:
	if wave_number < SCALING_START_WAVE:
		return {"hp_mult": 1.0, "damage_mult": 1.0}
	var waves_past: int = wave_number - SCALING_START_WAVE + 1
	return {
		"hp_mult": pow(HP_SCALING_PER_WAVE, waves_past),
		"damage_mult": pow(DAMAGE_SCALING_PER_WAVE, waves_past)
	}

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
	return weights.keys()[0]

func _spawn_normal_enemy() -> void:
	var enemy_type: String = pick_weighted_enemy(_current_enemy_weights)
	var enemy: Node = SceneFactory.create_enemy(enemy_type)
	if not enemy:
		return
	var spawn_pos: Vector2 = get_random_spawn_position()
	enemy.global_position = spawn_pos
	get_parent().add_child(enemy)
	# 精英怪检查
	if _current_wave_data.elite_chance > 0.0 and randf() < _current_wave_data.elite_chance:
		enemy.apply_elite(
			_current_wave_data.elite_hp_mult,
			_current_wave_data.elite_damage_mult,
			_current_wave_data.elite_coin_mult,
			_current_wave_data.elite_scale,
			_current_wave_data.elite_exp_mult
		)
	# 波次缩放
	if not enemy.data.is_boss:
		var scaling = get_wave_scaling(_current_wave_data.wave_number)
		if scaling.hp_mult > 1.0:
			enemy.health.max_hp *= scaling.hp_mult
			enemy.health.current_hp = enemy.health.max_hp
			enemy._hitbox.damage *= scaling.damage_mult
			enemy.tower_attack_damage *= scaling.damage_mult

func _spawn_boss() -> void:
	var boss: Node = SceneFactory.create_enemy(_current_wave_data.boss_id)
	if not boss:
		push_error("无法创建 Boss: " + _current_wave_data.boss_id)
		return
	var spawn_pos: Vector2 = get_random_spawn_position()
	boss.global_position = spawn_pos
	_boss_spawned = true
	get_parent().add_child(boss)
	AudioManager.play("boss_appear")

func get_random_spawn_position() -> Vector2:
	var spawn_pos = Vector2.ZERO
	var attempts = 0
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
	spawn_timer = 0.0
	_boss_spawned = false
	if wave_data.spawn_phases.size() > 0:
		_enter_phase(0)
	else:
		# 无分段配置时的默认行为
		_current_spawn_interval = 1.0
		_current_enemy_weights = wave_data.enemy_weights

func _on_wave_completed(_wave_number: int) -> void:
	_is_wave_active = false

func _on_game_ended() -> void:
	_is_wave_active = false
```

关键变化：
- 移除 `enemies_spawned`、`BossPhase` 枚举、`_boss_phase`
- 新增分段状态变量和 `_check_phase_transition()`、`_enter_phase()` 方法
- `_process()` 中加入 `max_alive_enemies` 检查
- `spawn_enemy()` 改名为 `_spawn_normal_enemy()`，使用 `_current_enemy_weights`（段内权重）
- Boss 在 `_enter_phase()` 进入最后阶段时自动生成

- [ ] **Step 2: 运行测试验证通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_boss_wave_spawner.gd -gexit
```

预期：所有测试 PASS

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/enemy_spawner.gd
git commit -m "refactor: EnemySpawner 改为分段生成 + max_alive 上限模式"
```

---

## Chunk 4: 波次配置文件

### Task 8: 重写 15 波 forest 配置 + 删除多余波次

**Files:**
- Modify: `resources/waves/forest/wave_01.tres` ~ `wave_15.tres`（重写）
- Delete: `resources/waves/forest/wave_16.tres` ~ `wave_20.tres`

由于 `.tres` 文件中无法内联 `SpawnPhaseData` 子资源数组（Godot Resource 序列化限制），改为**在 GDScript 中用代码生成 `.tres` 文件**。

- [ ] **Step 1: 编写波次配置生成脚本**

创建临时工具脚本 `tools/generate_wave_configs.gd`（用完即删），用 `ResourceSaver` 批量生成 15 波 `.tres` 文件。

每波的具体参数参照 spec 中的表格（`docs/superpowers/specs/2026-03-17-wave-system-redesign.md` 第 150-168 行）。

示例结构（wave_01）：
```gdscript
var wd := WaveData.new()
wd.wave_number = 1
wd.time_limit = 40.0
wd.max_alive_enemies = 15
wd.enemy_weights = {"normal": 100}
wd.elite_chance = 0.0

var p0 := SpawnPhaseData.new()
p0.duration_ratio = 0.3
p0.spawn_interval = 2.5

var p1 := SpawnPhaseData.new()
p1.duration_ratio = 0.5
p1.spawn_interval = 1.5

var p2 := SpawnPhaseData.new()
p2.duration_ratio = 0.2
p2.spawn_interval = 1.0

wd.spawn_phases = [p0, p1, p2]
ResourceSaver.save(wd, "res://resources/waves/forest/wave_01.tres")
```

- [ ] **Step 2: 通过 Godot 编辑器脚本运行生成**

使用 gdai-mcp 的 `execute_editor_script` 工具运行生成脚本，或手动在编辑器中运行。

- [ ] **Step 3: 删除多余波次文件**

```bash
rm resources/waves/forest/wave_16.tres
rm resources/waves/forest/wave_17.tres
rm resources/waves/forest/wave_18.tres
rm resources/waves/forest/wave_19.tres
rm resources/waves/forest/wave_20.tres
```

- [ ] **Step 4: 验证生成的文件**

检查 `resources/waves/forest/` 目录应只有 `wave_01.tres` ~ `wave_15.tres`，共 15 个文件。每个文件应包含 `spawn_phases` 子资源数组。

- [ ] **Step 5: 删除临时生成脚本**

```bash
rm tools/generate_wave_configs.gd
```

- [ ] **Step 6: Commit**

```bash
git add resources/waves/forest/
git commit -m "feat: 重写 forest 地图 15 波配置（纯时间制+分段生成）"
```

---

## Chunk 5: 更新测试

### Task 9: 更新 test_enemy_spawner.gd

**Files:**
- Modify: `tests/unit/test_enemy_spawner.gd`

- [ ] **Step 1: 移除引用已删除字段的测试，保留 pick_weighted_enemy 测试**

移除以下 3 个测试（引用已删除的 `total_enemies`、`enemies_spawned`、`_should_spawn()`）：
- `test_should_spawn_respects_limit`
- `test_enemies_spawned_resets_each_wave`
- `test_should_spawn_false_without_wave_data`

保留以下 3 个测试（不依赖已删除字段）：
- `test_pick_weighted_enemy_single_type`
- `test_pick_weighted_enemy_returns_valid_type`
- `test_pick_weighted_enemy_respects_weights`

- [ ] **Step 2: 运行测试验证通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_enemy_spawner.gd -gexit
```

- [ ] **Step 3: Commit**

```bash
git add tests/unit/test_enemy_spawner.gd
git commit -m "test: 移除 EnemySpawner 中引用已删除字段的测试"
```

### Task 10: 更新 test_resource_loading.gd

**Files:**
- Modify: `tests/unit/test_resource_loading.gd`

- [ ] **Step 1: 更新波次资源加载测试**

修改以下测试：
- `test_waves_loaded_count`: 从 `20` 改为 `15`
- `test_wave_1_defaults`: 移除 `spawn_interval` 断言，改为检查 `max_alive_enemies` 和 `spawn_phases.size() > 0`
- `test_wave_6_values`: 移除 `spawn_interval` 断言，改为检查 `max_alive_enemies` 和 `spawn_phases.size() > 0`

```gdscript
func test_waves_loaded_count() -> void:
	assert_eq(GameConfig.waves.size(), 15, "应加载 15 个波次")

func test_wave_1_defaults() -> void:
	var w: WaveData = GameConfig.waves[0]
	assert_eq(w.time_limit, 40.0, "波次1的time_limit应为40.0")
	assert_gt(w.spawn_phases.size(), 0, "波次1应有分段配置")
	assert_gt(w.max_alive_enemies, 0, "波次1应有max_alive_enemies")
	assert_true(w.enemy_weights.has("normal"), "波次1应包含normal敌人权重")

func test_wave_6_values() -> void:
	var w: WaveData = GameConfig.waves[5]
	assert_gt(w.spawn_phases.size(), 0, "波次6应有分段配置")
	assert_true(w.enemy_weights.has("fast"), "波次6应包含fast敌人权重")
```

- [ ] **Step 2: 运行测试验证通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_resource_loading.gd -gexit
```

- [ ] **Step 3: Commit**

```bash
git add tests/unit/test_resource_loading.gd
git commit -m "test: 更新波次资源加载测试适配新 WaveData 字段"
```

### Task 11: 更新 test_wave_scaling.gd

**Files:**
- Modify: `tests/unit/test_wave_scaling.gd`

- [ ] **Step 1: 移除 wave 20 测试（只有 15 波了）**

移除 `test_scaling_wave_20` 测试。其余测试不变（wave 1/10/11/15 仍有效）。

- [ ] **Step 2: 运行测试验证通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_wave_scaling.gd -gexit
```

- [ ] **Step 3: Commit**

```bash
git add tests/unit/test_wave_scaling.gd
git commit -m "test: 移除 wave 20 缩放测试（总波次改为 15）"
```

### Task 12: 重写 test_wave_balance.gd

**Files:**
- Modify: `tests/unit/test_wave_balance.gd`

- [ ] **Step 1: 重写波次平衡测试**

```gdscript
extends GutTest

func test_forest_has_15_waves():
	var waves = GameConfig.get_waves_for_map("forest")
	assert_eq(waves.size(), 15, "Forest 应有 15 波")

func test_wave_numbers_sequential():
	var waves = GameConfig.get_waves_for_map("forest")
	for i in range(waves.size()):
		assert_eq(waves[i].wave_number, i + 1)

func test_boss_waves_at_5_10_15():
	var waves = GameConfig.get_waves_for_map("forest")
	var boss_wave_numbers := []
	for w: WaveData in waves:
		if w.is_boss_wave:
			boss_wave_numbers.append(w.wave_number)
	assert_eq(boss_wave_numbers.size(), 3, "应有 3 个 Boss 波")
	assert_has(boss_wave_numbers, 5, "第 5 波应为 Boss 波")
	assert_has(boss_wave_numbers, 10, "第 10 波应为 Boss 波")
	assert_has(boss_wave_numbers, 15, "第 15 波应为 Boss 波")

func test_boss_ids():
	var waves = GameConfig.get_waves_for_map("forest")
	assert_eq(waves[4].boss_id, "boss_brute")
	assert_eq(waves[9].boss_id, "boss_summoner")
	assert_eq(waves[14].boss_id, "boss_guardian")

func test_all_waves_have_spawn_phases():
	var waves = GameConfig.get_waves_for_map("forest")
	for w: WaveData in waves:
		assert_gt(w.spawn_phases.size(), 0, "波次 %d 应有分段配置" % w.wave_number)

func test_spawn_phases_duration_ratio_sum():
	var waves = GameConfig.get_waves_for_map("forest")
	for w: WaveData in waves:
		var total_ratio: float = 0.0
		for phase: SpawnPhaseData in w.spawn_phases:
			total_ratio += phase.duration_ratio
		assert_almost_eq(total_ratio, 1.0, 0.01, "波次 %d 的 duration_ratio 之和应为 1.0" % w.wave_number)

func test_time_limit_increasing():
	var waves = GameConfig.get_waves_for_map("forest")
	# 非 Boss 波次的时间应整体递增
	assert_lt(waves[0].time_limit, waves[13].time_limit, "后期波次时间应更长")

func test_elite_chance_progression():
	var waves = GameConfig.get_waves_for_map("forest")
	assert_eq(waves[0].elite_chance, 0.0, "第 1 波不应有精英怪")
	var has_elite := false
	for w: WaveData in waves:
		if w.elite_chance > 0.0:
			has_elite = true
			break
	assert_true(has_elite, "后期波次应有精英怪")

func test_max_alive_enemies_increasing():
	var waves = GameConfig.get_waves_for_map("forest")
	assert_lt(waves[0].max_alive_enemies, waves[14].max_alive_enemies, "后期波次 max_alive 应更大")
```

- [ ] **Step 2: 运行测试验证通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_wave_balance.gd -gexit
```

- [ ] **Step 3: Commit**

```bash
git add tests/unit/test_wave_balance.gd
git commit -m "test: 重写波次平衡测试适配 15 波纯时间制"
```

### Task 13: 重写 test_wave_system.gd（集成测试）

**Files:**
- Modify: `tests/integration/test_wave_system.gd`

- [ ] **Step 1: 重写集成测试**

```gdscript
extends GutTest

func test_forest_wave_count():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	assert_eq(waves.size(), 15, "Forest 地图应有 15 波")

func test_waves_sorted_by_number():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	for i in range(waves.size() - 1):
		assert_lt(waves[i].wave_number, waves[i + 1].wave_number, "波次应按 wave_number 排序")

func test_boss_waves_count():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	var boss_waves := []
	for w: WaveData in waves:
		if w.is_boss_wave:
			boss_waves.append(w.wave_number)
	assert_eq(boss_waves.size(), 3, "应有 3 个 Boss 波")

func test_boss_waves_are_5_10_15():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	var boss_wave_numbers := []
	for w: WaveData in waves:
		if w.is_boss_wave:
			boss_wave_numbers.append(w.wave_number)
	assert_has(boss_wave_numbers, 5, "第 5 波应为 Boss 波")
	assert_has(boss_wave_numbers, 10, "第 10 波应为 Boss 波")
	assert_has(boss_wave_numbers, 15, "第 15 波应为 Boss 波")

func test_all_enemy_weights_reference_valid_types():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	for w: WaveData in waves:
		for enemy_id: String in w.enemy_weights:
			assert_true(GameConfig.enemies.has(enemy_id), "敌人类型 '%s' 应在 GameConfig 中注册 (wave %d)" % [enemy_id, w.wave_number])

func test_boss_ids_reference_valid_enemies():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	for w: WaveData in waves:
		if w.is_boss_wave:
			assert_ne(w.boss_id, "", "Boss 波 %d 应有 boss_id" % w.wave_number)
			assert_true(GameConfig.enemies.has(w.boss_id), "Boss '%s' 应在 GameConfig 中注册 (wave %d)" % [w.boss_id, w.wave_number])

func test_spawn_phases_valid():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	for w: WaveData in waves:
		assert_gt(w.spawn_phases.size(), 0, "波次 %d 应有分段" % w.wave_number)
		var total_ratio: float = 0.0
		for phase: SpawnPhaseData in w.spawn_phases:
			assert_gt(phase.duration_ratio, 0.0, "波次 %d 阶段 ratio 应 > 0" % w.wave_number)
			assert_gt(phase.spawn_interval, 0.0, "波次 %d 阶段 interval 应 > 0" % w.wave_number)
			total_ratio += phase.duration_ratio
		assert_almost_eq(total_ratio, 1.0, 0.01, "波次 %d ratio 之和应为 1.0" % w.wave_number)

func test_wave_manager_time_based_completion():
	var wm = load("res://scripts/systems/wave_manager.gd").new()
	var waves: Array = GameConfig.get_waves_for_map("forest")
	var wave_1: WaveData = waves[0]
	wm._start_wave_with_data(1, wave_1)
	assert_true(wm.is_wave_active)
	# 模拟时间到期
	wm._process(wave_1.time_limit + 0.1)
	assert_false(wm.is_wave_active, "时间到后波次应结束")

func test_elite_chance_increases_over_waves():
	var waves: Array = GameConfig.get_waves_for_map("forest")
	assert_eq(waves[0].elite_chance, 0.0, "第 1 波不应有精英怪")
	var has_elite := false
	for w: WaveData in waves:
		if w.elite_chance > 0.0:
			has_elite = true
			break
	assert_true(has_elite, "后期波次应有精英怪")
```

- [ ] **Step 2: 运行测试验证通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/integration -ginclude_subdirs -gtest=test_wave_system.gd -gexit
```

- [ ] **Step 3: Commit**

```bash
git add tests/integration/test_wave_system.gd
git commit -m "test: 重写波次系统集成测试适配 15 波纯时间制"
```

---

## Chunk 6: 全量测试 + 清理

### Task 14: 运行全量测试

- [ ] **Step 1: 运行所有测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

预期：所有测试 PASS。如果有其他测试引用了 `total_enemies`、`spawn_interval` 或 `boss_escort_count` 字段，需要修复。

- [ ] **Step 2: 搜索残留引用**

在代码中搜索 `total_enemies`、`spawn_interval`（WaveData 上的）、`boss_escort_count`，确保没有其他文件仍在引用这些已删除字段。排除：`enemy_spawner.gd` 中 `_current_spawn_interval`（这是内部变量，不是 WaveData 字段）。

- [ ] **Step 3: 修复任何残留引用并 commit**

若有残留引用，修复后 commit。

### Task 15: HUD 倒计时验证

- [ ] **Step 1: 检查 HUD 是否依赖已删除字段**

检查 `scripts/ui/hud.gd` 中是否有引用 `total_enemies` 或 `enemies_killed` 的逻辑。如果有，移除或替换。

- [ ] **Step 2: 如有修改则 commit**

```bash
git add scripts/ui/hud.gd
git commit -m "fix: HUD 移除已删除的 total_enemies/enemies_killed 引用"
```
