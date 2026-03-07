# 架构重构实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 重构 utoland 项目架构，引入全局事件总线解耦系统间依赖，将 GameConfig 字典转为自定义资源体系，整理文件夹结构。

**Architecture:** 分三阶段：Phase 1 创建 EventBus Autoload 并迁移所有跨系统直接调用为信号通信；Phase 2 定义 Resource 类并将 GameConfig 字典拆为 .tres 资源文件；Phase 3 整理场景和脚本目录结构。每阶段在独立 feature 分支上进行。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架

---

## Phase 1: 事件总线 + 解耦

### Task 1: 创建 feature 分支

**Step 1: 创建分支**

```bash
git checkout -b feature/event-bus develop
```

**Step 2: 确认分支**

Run: `git branch --show-current`
Expected: `feature/event-bus`

---

### Task 2: 创建 EventBus 脚本

**Files:**
- Create: `scripts/core/event_bus.gd`

**Step 1: 创建 EventBus Autoload 脚本**

```gdscript
extends Node

# 波次系统
signal wave_started(wave_number: int, wave_config: Dictionary)
signal wave_completed(wave_number: int)
signal game_won()
signal game_lost()

# 战斗事件
signal enemy_killed(enemy_type: String, position: Vector2)
signal player_damaged(damage: float, current_hp: float)
signal player_died()

# 经济事件
signal coins_changed(amount: int, total: int)
signal coin_collected(value: int, position: Vector2)

# 视觉反馈
signal camera_shake_requested(intensity: float, duration: float)

# 塔防事件
signal tower_placed(tower_type: String, position: Vector2)
signal tower_destroyed(tower_type: String, position: Vector2)
```

**Step 2: 注册为 Autoload**

修改 `project.godot` 的 `[autoload]` 段，在 EffectsManager 之后添加：

```ini
EventBus="*res://scripts/core/event_bus.gd"
```

**Step 3: 提交**

```bash
git add scripts/core/event_bus.gd project.godot
git commit -m "feat: 创建 EventBus 全局事件总线 Autoload"
```

---

### Task 3: 为 EventBus 编写测试

**Files:**
- Create: `tests/unit/test_event_bus.gd`

**Step 1: 编写 EventBus 信号测试**

```gdscript
extends GutTest

# EventBus 信号存在性与触发测试

func test_event_bus_exists():
	assert_not_null(EventBus, "EventBus Autoload 应存在")

func test_wave_started_signal():
	watch_signals(EventBus)
	EventBus.wave_started.emit(1, {"duration": 45})
	assert_signal_emitted(EventBus, "wave_started")

func test_wave_completed_signal():
	watch_signals(EventBus)
	EventBus.wave_completed.emit(1)
	assert_signal_emitted(EventBus, "wave_completed")

func test_game_won_signal():
	watch_signals(EventBus)
	EventBus.game_won.emit()
	assert_signal_emitted(EventBus, "game_won")

func test_game_lost_signal():
	watch_signals(EventBus)
	EventBus.game_lost.emit()
	assert_signal_emitted(EventBus, "game_lost")

func test_player_died_signal():
	watch_signals(EventBus)
	EventBus.player_died.emit()
	assert_signal_emitted(EventBus, "player_died")

func test_camera_shake_requested_signal():
	watch_signals(EventBus)
	EventBus.camera_shake_requested.emit(3.0, 0.1)
	assert_signal_emitted(EventBus, "camera_shake_requested")

func test_enemy_killed_signal():
	watch_signals(EventBus)
	EventBus.enemy_killed.emit("normal", Vector2(100, 200))
	assert_signal_emitted(EventBus, "enemy_killed")
```

**Step 2: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_event_bus -gexit`
Expected: 7 tests PASS

**Step 3: 提交**

```bash
git add tests/unit/test_event_bus.gd
git commit -m "test: EventBus 信号存在性与触发测试"
```

---

### Task 4: 迁移 WaveManager 信号到 EventBus

**Files:**
- Modify: `scripts/systems/wave_manager.gd`

**Step 1: 重构 wave_manager.gd**

移除 WaveManager 自身的 4 个信号声明，改为 emit EventBus 信号。同时用 `EventBus.camera_shake_requested` 替代直接访问 player camera 节点。

将 `scripts/systems/wave_manager.gd` 完整替换为：

```gdscript
extends Node

var total_waves: int = GameConfig.WAVES["total_waves"]
var current_wave: int = 0
var wave_time_left: float = 0.0
var is_wave_active: bool = false

func _ready():
	add_to_group("wave_manager")
	# 连接 player_died 信号
	EventBus.player_died.connect(_on_player_died)
	# 从 GameData 恢复波次
	if GameData.current_wave > 0:
		current_wave = GameData.current_wave
	start_next_wave()

func _process(delta):
	if is_wave_active:
		wave_time_left -= delta
		if wave_time_left <= 0:
			complete_wave()

func start_next_wave():
	current_wave += 1
	GameData.current_wave = current_wave  # 同步到 GameData

	if current_wave > total_waves:
		EventBus.game_won.emit()
		print("Victory! You completed all waves!")
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/ui/result.tscn")
		return

	var config = GameConfig.WAVES["wave_configs"][current_wave - 1]
	wave_time_left = config["duration"]
	is_wave_active = true
	EventBus.wave_started.emit(current_wave, config)
	# 波次开始屏幕震动 — 通过 EventBus 而非直接访问 camera
	var shake_config: Dictionary = GameConfig.EFFECTS["camera_shake"]["wave_start"]
	EventBus.camera_shake_requested.emit(shake_config["intensity"], shake_config["duration"])
	print("Wave ", current_wave, " started!")

func complete_wave():
	is_wave_active = false
	attract_all_coins()
	await get_tree().create_timer(2.0).timeout
	clear_all_enemies()
	EventBus.wave_completed.emit(current_wave)
	print("Wave ", current_wave, " completed!")

	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/shop.tscn")

func attract_all_coins():
	var coins = get_tree().get_nodes_in_group("coins")
	for coin in coins:
		if coin.has_method("force_attract"):
			coin.force_attract()

func clear_all_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("set_physics_process"):
			enemy.set_physics_process(false)
			enemy.set_process(false)
		enemy.queue_free()

func get_current_wave_config():
	if current_wave > 0 and current_wave <= total_waves:
		return GameConfig.WAVES["wave_configs"][current_wave - 1]
	return {}

func _on_player_died() -> void:
	EventBus.game_lost.emit()
```

**Step 2: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 所有测试通过（可能有些测试需要在后续步骤更新）

**Step 3: 提交**

```bash
git add scripts/systems/wave_manager.gd
git commit -m "refactor: WaveManager 信号迁移到 EventBus，解耦 camera 直接访问"
```

---

### Task 5: 重构 player.gd — 解耦 wave_manager 直接调用

**Files:**
- Modify: `scripts/entities/player.gd`

**Step 1: 修改 player.die() 方法**

将 `player.gd` 中 `die()` 方法的 wave_manager 直接调用改为 EventBus 信号：

旧代码（第 109-116 行）：
```gdscript
func die() -> void:
	print("Player died!")
	var wave_manager: Node = get_tree().get_first_node_in_group("wave_manager")
	if wave_manager:
		GameData.current_wave = wave_manager.current_wave
		wave_manager.game_lost.emit()
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/result.tscn")
```

新代码：
```gdscript
func die() -> void:
	print("Player died!")
	EventBus.player_died.emit()
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/result.tscn")
```

**Step 2: 修改 take_damage() 中的 camera shake**

旧代码（第 96-107 行）：
```gdscript
func take_damage(amount: float) -> void:
	current_hp -= amount
	# 受击闪白
	_flash_white()
	# 屏幕震动
	var camera: Camera2D = $Camera
	if camera and camera.has_method("shake"):
		var shake_config: Dictionary = GameConfig.EFFECTS["camera_shake"]["player_hit"]
		camera.shake(shake_config["intensity"], shake_config["duration"])
	print("Player HP: ", current_hp)
	if current_hp <= 0:
		die()
```

新代码：
```gdscript
func take_damage(amount: float) -> void:
	current_hp -= amount
	# 受击闪白
	_flash_white()
	# 屏幕震动 — 通过 EventBus
	var shake_config: Dictionary = GameConfig.EFFECTS["camera_shake"]["player_hit"]
	EventBus.camera_shake_requested.emit(shake_config["intensity"], shake_config["duration"])
	print("Player HP: ", current_hp)
	if current_hp <= 0:
		die()
```

**Step 3: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

**Step 4: 提交**

```bash
git add scripts/entities/player.gd
git commit -m "refactor: player 解耦 wave_manager 直接引用，camera shake 走 EventBus"
```

---

### Task 6: 重构 enemy.gd — camera shake 走 EventBus

**Files:**
- Modify: `scripts/entities/enemy.gd`

**Step 1: 修改 enemy.die() 中的 camera shake**

旧代码（第 82-96 行）：
```gdscript
func die():
	# 清理活跃的 tween
	if _knockback_tween and _knockback_tween.is_valid():
		_knockback_tween.kill()
	# 死亡爆炸特效
	EffectsManager.spawn_death_effect(global_position, _death_color)
	# 屏幕震动
	var player_node: Node2D = get_tree().get_first_node_in_group("player")
	if player_node:
		var camera: Camera2D = player_node.get_node_or_null("Camera")
		if camera and camera.has_method("shake"):
			var shake_config: Dictionary = GameConfig.EFFECTS["camera_shake"]["enemy_kill"]
			camera.shake(shake_config["intensity"], shake_config["duration"])
	drop_coins()
	queue_free()
```

新代码：
```gdscript
func die():
	# 清理活跃的 tween
	if _knockback_tween and _knockback_tween.is_valid():
		_knockback_tween.kill()
	# 死亡爆炸特效
	EffectsManager.spawn_death_effect(global_position, _death_color)
	# 屏幕震动 — 通过 EventBus
	var shake_config: Dictionary = GameConfig.EFFECTS["camera_shake"]["enemy_kill"]
	EventBus.camera_shake_requested.emit(shake_config["intensity"], shake_config["duration"])
	# 通知敌人被击杀
	EventBus.enemy_killed.emit(enemy_type, global_position)
	drop_coins()
	queue_free()
```

**Step 2: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

**Step 3: 提交**

```bash
git add scripts/entities/enemy.gd
git commit -m "refactor: enemy camera shake 和 kill 事件走 EventBus"
```

---

### Task 7: 重构 camera_shake.gd — 连接 EventBus

**Files:**
- Modify: `scripts/systems/camera_shake.gd`

**Step 1: 在 _ready() 中连接 EventBus 信号**

在 `camera_shake.gd` 的 `_ready()` 末尾添加 EventBus 连接：

```gdscript
func _ready() -> void:
	var config: Dictionary = GameConfig.EFFECTS["camera"]
	# 缩放
	zoom = config["zoom"]
	# 平滑跟随
	position_smoothing_enabled = true
	position_smoothing_speed = config["smoothing_speed"]
	# 地图边界限制
	limit_left = -int(GameConfig.MAP_HALF_WIDTH)
	limit_right = int(GameConfig.MAP_HALF_WIDTH)
	limit_top = -int(GameConfig.MAP_HALF_HEIGHT)
	limit_bottom = int(GameConfig.MAP_HALF_HEIGHT)
	# 连接全局 camera shake 请求
	EventBus.camera_shake_requested.connect(shake)
```

**Step 2: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

**Step 3: 提交**

```bash
git add scripts/systems/camera_shake.gd
git commit -m "refactor: camera_shake 连接 EventBus.camera_shake_requested 信号"
```

---

### Task 8: 重构 enemy_spawner.gd — 解耦 wave_manager 直接引用

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd`

**Step 1: 重构 enemy_spawner.gd**

将直接引用 wave_manager 改为通过 EventBus 接收波次信息，使用 GameData 获取波次状态：

```gdscript
extends Node

var spawn_timer: float = 0.0
var player: Node2D
var _current_wave_config: Dictionary = {}
var _is_wave_active: bool = false

# Map boundaries
var map_min_x: float = -GameConfig.MAP_HALF_WIDTH
var map_max_x: float = GameConfig.MAP_HALF_WIDTH
var map_min_y: float = -GameConfig.MAP_HALF_HEIGHT
var map_max_y: float = GameConfig.MAP_HALF_HEIGHT
var min_distance_from_player = 200.0

func _ready():
	player = get_tree().get_first_node_in_group("player")
	# 连接 EventBus 信号
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.game_won.connect(_on_game_ended)
	EventBus.game_lost.connect(_on_game_ended)

func _process(delta):
	if not _is_wave_active:
		return

	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_enemy()
		spawn_timer = _current_wave_config.get("spawn_interval", 3.0)

func spawn_enemy():
	var enemy_types = _current_wave_config.get("enemy_types", ["normal"])
	var random_type = enemy_types[randi() % enemy_types.size()]
	var enemy = SceneFactory.create_enemy(random_type)

	var spawn_pos = get_random_spawn_position()
	enemy.global_position = spawn_pos
	get_parent().add_child(enemy)

func get_random_spawn_position() -> Vector2:
	var spawn_pos = Vector2.ZERO
	var attempts = 0
	var max_attempts = 10

	while attempts < max_attempts:
		spawn_pos.x = randf_range(map_min_x, map_max_x)
		spawn_pos.y = randf_range(map_min_y, map_max_y)

		if player and player.global_position.distance_to(spawn_pos) >= min_distance_from_player:
			break
		attempts += 1

	return spawn_pos

func _on_wave_started(wave_number: int, wave_config: Dictionary) -> void:
	_current_wave_config = wave_config
	_is_wave_active = true
	spawn_timer = 0.0

func _on_wave_completed(_wave_number: int) -> void:
	_is_wave_active = false

func _on_game_ended() -> void:
	_is_wave_active = false
```

**Step 2: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

**Step 3: 提交**

```bash
git add scripts/systems/enemy_spawner.gd
git commit -m "refactor: enemy_spawner 解耦 wave_manager 直接引用，改用 EventBus"
```

---

### Task 9: 重构 hud.gd — 解耦 wave_manager 直接引用

**Files:**
- Modify: `scripts/ui/hud.gd`

**Step 1: 重构 hud.gd**

HUD 不再直接引用 wave_manager 节点，改为通过 EventBus 监听波次事件，使用 GameData 获取当前波次号：

```gdscript
extends CanvasLayer

@onready var hp_label = $HPLabel
@onready var timer_label = $TimerLabel

var player: Node2D = null
var _wave_time_left: float = 0.0
var _is_wave_active: bool = false

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("HUD: Player node not found in 'player' group")
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)

func _process(delta):
	if player and is_instance_valid(player):
		hp_label.text = "HP: %.0f | Coins: %d" % [player.current_hp, player.coins]

	if _is_wave_active:
		_wave_time_left -= delta
		if _wave_time_left < 0:
			_wave_time_left = 0.0
	timer_label.text = "Wave: %d/10 | Time: %.0f" % [GameData.current_wave, _wave_time_left]

func _on_wave_started(wave_number: int, wave_config: Dictionary) -> void:
	_is_wave_active = true
	_wave_time_left = wave_config.get("duration", 0.0)

func _on_wave_completed(_wave_number: int) -> void:
	_is_wave_active = false
```

**Step 2: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

**Step 3: 提交**

```bash
git add scripts/ui/hud.gd
git commit -m "refactor: HUD 解耦 wave_manager 直接引用，改用 EventBus + GameData"
```

---

### Task 10: 更新受影响的测试

**Files:**
- Modify: `tests/unit/test_camera_shake.gd` (可能需要更新)
- Modify: `tests/integration/test_enemy_spawning.gd` (可能需要更新)
- Review: 所有其他测试文件确认不受影响

**Step 1: 检查并更新受影响的测试**

检查所有测试文件中对 wave_manager 信号的直接引用，改为通过 EventBus。

`test_camera_shake.gd` — camera_shake._ready() 现在连接 EventBus，测试中创建独立 Camera2D 不走场景树，EventBus.camera_shake_requested.connect(shake) 可能因为没有 EventBus 导致问题。需要检查测试是否需要更新。

如果 camera_shake 测试中 _ready() 会调用 EventBus，而测试是通过 `set_script` 手动创建的，则 EventBus 作为 Autoload 在测试运行时应该可用（GUT 在 Godot 引擎中运行），所以应该没问题。

**Step 2: 运行全量测试确认所有 115+ 个测试通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 所有测试通过

**Step 3: 修复任何失败的测试**

根据测试输出修复。

**Step 4: 提交**

```bash
git add tests/
git commit -m "test: 更新测试适配 EventBus 重构"
```

---

### Task 11: Phase 1 合并

**Step 1: 运行最终全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部通过

**Step 2: 合并到 develop**

```bash
git checkout develop
git merge feature/event-bus --no-ff -m "feat: Phase 1 完成 — EventBus 事件总线 + 系统解耦"
```

---

## Phase 2: 自定义资源体系

### Task 12: 创建 feature 分支

**Step 1: 创建分支**

```bash
git checkout -b feature/custom-resources develop
```

---

### Task 13: 定义 WeaponData Resource 类

**Files:**
- Create: `scripts/resources/weapon_data.gd`

**Step 1: 创建 WeaponData Resource**

```gdscript
class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var projectile_type: String = "bullet"  # bullet, boomerang, laser
@export var fire_rate: float = 0.1
@export var damage: float = 10.0
@export var weapon_range: float = 300.0  # "range" 是 GDScript 内置，用 weapon_range

# 子弹特有
@export var bullet_count: int = 1
@export var bullet_speed: float = 600.0

# 回旋镖特有
@export var boomerang_speed: float = 350.0
@export var outbound_distance: float = 200.0
@export var return_speed_mult: float = 1.3

# 激光特有
@export var beam_range: float = 400.0
@export var beam_width: float = 2.0
@export var beam_duration: float = 0.08
```

**Step 2: 提交**

```bash
git add scripts/resources/weapon_data.gd
git commit -m "feat: 定义 WeaponData Resource 类"
```

---

### Task 14: 定义 EnemyData Resource 类

**Files:**
- Create: `scripts/resources/enemy_data.gd`

**Step 1: 创建 EnemyData Resource**

```gdscript
class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var hp: float = 50.0
@export var speed: float = 100.0
@export var damage: float = 10.0
@export var coin_drop_min: int = 1
@export var coin_drop_max: int = 3
```

**Step 2: 提交**

```bash
git add scripts/resources/enemy_data.gd
git commit -m "feat: 定义 EnemyData Resource 类"
```

---

### Task 15: 定义 TowerData Resource 类

**Files:**
- Create: `scripts/resources/tower_data.gd`

**Step 1: 创建 TowerData Resource**

```gdscript
class_name TowerData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var hp: float = 100.0
@export var damage: float = 0.0
@export var fire_rate: float = 0.0
@export var attack_range: float = 0.0  # "range" 是内置
@export var shop_price_min: int = 35
@export var shop_price_max: int = 45

# 减速塔特有
@export var slow_percent: float = 0.0
```

**Step 2: 提交**

```bash
git add scripts/resources/tower_data.gd
git commit -m "feat: 定义 TowerData Resource 类"
```

---

### Task 16: 定义 WaveData Resource 类

**Files:**
- Create: `scripts/resources/wave_data.gd`

**Step 1: 创建 WaveData Resource**

```gdscript
class_name WaveData
extends Resource

@export var wave_number: int = 1
@export var duration: float = 45.0
@export var spawn_interval: float = 1.5
@export var enemy_types: PackedStringArray = ["normal"]
```

**Step 2: 提交**

```bash
git add scripts/resources/wave_data.gd
git commit -m "feat: 定义 WaveData Resource 类"
```

---

### Task 17: 定义 CharacterData Resource 类

**Files:**
- Create: `scripts/resources/character_data.gd`

**Step 1: 创建 CharacterData Resource**

```gdscript
class_name CharacterData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var max_hp: float = 100.0
@export var speed: float = 200.0
@export var damage_mult: float = 1.0
@export var attack_speed_mult: float = 1.0
@export var move_speed_mult: float = 1.0
@export var hp_regen: float = 0.0
```

**Step 2: 提交**

```bash
git add scripts/resources/character_data.gd
git commit -m "feat: 定义 CharacterData Resource 类"
```

---

### Task 18: 定义 MapData Resource 类

**Files:**
- Create: `scripts/resources/map_data.gd`

**Step 1: 创建 MapData Resource**

```gdscript
class_name MapData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var preview_image: String = ""
@export var background: String = ""
@export var fallback_color: String = "#2d5016"
```

**Step 2: 提交**

```bash
git add scripts/resources/map_data.gd
git commit -m "feat: 定义 MapData Resource 类"
```

---

### Task 19: 定义 EffectConfigData Resource 类

**Files:**
- Create: `scripts/resources/effect_config_data.gd`

**Step 1: 创建 EffectConfigData Resource**

该资源整合所有特效参数（包括目前硬编码在 effects_manager 中的值）：

```gdscript
class_name EffectConfigData
extends Resource

# 摄像机震动
@export var camera_shake_player_hit_intensity: float = 3.0
@export var camera_shake_player_hit_duration: float = 0.1
@export var camera_shake_enemy_kill_intensity: float = 2.0
@export var camera_shake_enemy_kill_duration: float = 0.08
@export var camera_shake_wave_start_intensity: float = 5.0
@export var camera_shake_wave_start_duration: float = 0.2

# 击退
@export var knockback_distance: float = 15.0
@export var knockback_duration: float = 0.1

# 受击闪白
@export var hit_flash_duration: float = 0.05
@export var hit_flash_color: Color = Color.WHITE

# 无敌帧闪烁
@export var invincible_blink_interval: float = 0.08
@export var invincible_blink_alpha_low: float = 0.3
@export var invincible_blink_alpha_high: float = 1.0

# 伤害数字
@export var damage_number_float_distance: float = 30.0
@export var damage_number_random_offset_x: float = 10.0
@export var damage_number_duration: float = 0.6
@export var damage_number_big_threshold: float = 30.0
@export var damage_number_big_scale: float = 1.3
@export var damage_number_normal_color: Color = Color.WHITE
@export var damage_number_big_color: Color = Color.YELLOW
@export var damage_number_z_index: int = 100

# 死亡粒子
@export var death_particle_count: int = 10
@export var death_particle_spread: float = 20.0
@export var death_particle_lifetime: float = 0.3
@export var death_particle_gravity: float = 200.0
@export var death_particle_speed_min: float = 50.0
@export var death_particle_speed_max: float = 120.0
@export var death_particle_z_index: int = 50

# 击中火花
@export var hit_spark_count: int = 5
@export var hit_spark_lifetime: float = 0.15
@export var hit_spark_spread_speed: float = 100.0
@export var hit_spark_z_index: int = 50

# 金币拾取
@export var coin_pickup_shrink_duration: float = 0.15

# 子弹拖尾
@export var bullet_trail_length: float = 15.0
@export var bullet_trail_width: float = 2.0
@export var bullet_trail_color: Color = Color(1, 1, 0, 0.6)
@export var bullet_trail_max_points: int = 4

# 回旋镖特效
@export var boomerang_rotation_speed: float = 720.0
@export var boomerang_trail_points: int = 6
@export var boomerang_trail_width: float = 3.0
@export var boomerang_trail_color: Color = Color(0.2, 0.8, 1.0, 0.6)
@export var boomerang_return_rotation_mult: float = 1.5
@export var boomerang_return_distance: float = 15.0

# 激光特效
@export var laser_beam_width: float = 4.0
@export var laser_core_color: Color = Color(1, 1, 1, 0.9)
@export var laser_edge_color: Color = Color(1, 0.2, 0.2, 0.7)
@export var laser_flash_alpha: float = 0.03
@export var laser_flash_duration: float = 0.05
@export var laser_flash_size: Vector2 = Vector2(2000, 2000)
@export var laser_flash_z_index: int = 90
@export var laser_ray_query_limit: int = 20
@export var laser_collision_mask: int = 2

# 摄像机
@export var camera_zoom: Vector2 = Vector2(0.75, 0.75)
@export var camera_smoothing_speed: float = 8.0
@export var camera_look_ahead_distance: float = 40.0
@export var camera_look_ahead_smoothing: float = 3.0

# 枪口闪光
@export var muzzle_flash_size: Vector2 = Vector2(6, 6)
@export var muzzle_flash_color: Color = Color(1, 1, 0.8, 0.9)
@export var muzzle_flash_z_index: int = 10
@export var muzzle_flash_duration: float = 0.05
```

**Step 2: 提交**

```bash
git add scripts/resources/effect_config_data.gd
git commit -m "feat: 定义 EffectConfigData Resource 类（含所有硬编码特效值）"
```

---

### Task 20: 定义 SpriteConfigData Resource 类

**Files:**
- Create: `scripts/resources/sprite_config_data.gd`

**Step 1: 创建 SpriteConfigData Resource**

```gdscript
class_name SpriteConfigData
extends Resource

# 玩家精灵配置
@export var idle_texture_path: String = ""
@export var walk_texture_path: String = ""
@export var spritesheet_path: String = ""  # 敌人用单个 spritesheet
@export var frame_size: Vector2 = Vector2(16, 16)
@export var idle_frames: int = 4
@export var walk_frames: int = 4
@export var walk_directions: int = 4
@export var fps: float = 8.0

# 方向判定滞后阈值
@export var direction_hysteresis_keep: float = 0.7
@export var direction_hysteresis_switch: float = 1.4
```

**Step 2: 提交**

```bash
git add scripts/resources/sprite_config_data.gd
git commit -m "feat: 定义 SpriteConfigData Resource 类"
```

---

### Task 21: 定义 ShopItemData 和 SpawnConfigData

**Files:**
- Create: `scripts/resources/shop_config_data.gd`
- Create: `scripts/resources/spawn_config_data.gd`

**Step 1: 创建 ShopConfigData Resource**

```gdscript
class_name ShopConfigData
extends Resource

@export var refresh_cost: int = 10
@export var item_count: int = 4
@export var passive_price_min: int = 20
@export var passive_price_max: int = 40
@export var heal_price: int = 12
@export var heal_amount: int = 50
@export var passive_chance: float = 0.6
@export var tower_chance: float = 0.3
# 剩余为消耗品概率 (1 - passive - tower)
```

**Step 2: 创建 SpawnConfigData Resource**

```gdscript
class_name SpawnConfigData
extends Resource

@export var min_distance_from_player: float = 200.0
@export var max_spawn_attempts: int = 10
```

**Step 3: 提交**

```bash
git add scripts/resources/shop_config_data.gd scripts/resources/spawn_config_data.gd
git commit -m "feat: 定义 ShopConfigData 和 SpawnConfigData Resource 类"
```

---

### Task 22: 创建 .tres 资源文件 — 武器

**Files:**
- Create: `resources/weapons/rifle.tres`
- Create: `resources/weapons/boomerang.tres`
- Create: `resources/weapons/laser.tres`

**Step 1: 创建目录和资源文件**

```bash
mkdir -p resources/weapons
```

`resources/weapons/rifle.tres`:
```
[gd_resource type="Resource" script_class="WeaponData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/weapon_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "rifle"
display_name = "步枪"
projectile_type = "bullet"
fire_rate = 0.1
damage = 10.0
weapon_range = 300.0
bullet_count = 1
bullet_speed = 600.0
boomerang_speed = 350.0
outbound_distance = 200.0
return_speed_mult = 1.3
beam_range = 400.0
beam_width = 2.0
beam_duration = 0.08
```

`resources/weapons/boomerang.tres`:
```
[gd_resource type="Resource" script_class="WeaponData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/weapon_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "boomerang"
display_name = "回旋镖"
projectile_type = "boomerang"
fire_rate = 0.8
damage = 15.0
weapon_range = 200.0
bullet_count = 1
bullet_speed = 600.0
boomerang_speed = 350.0
outbound_distance = 200.0
return_speed_mult = 1.3
beam_range = 400.0
beam_width = 2.0
beam_duration = 0.08
```

`resources/weapons/laser.tres`:
```
[gd_resource type="Resource" script_class="WeaponData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/weapon_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "laser"
display_name = "激光枪"
projectile_type = "laser"
fire_rate = 0.15
damage = 8.0
weapon_range = 400.0
bullet_count = 1
bullet_speed = 600.0
boomerang_speed = 350.0
outbound_distance = 200.0
return_speed_mult = 1.3
beam_range = 400.0
beam_width = 2.0
beam_duration = 0.08
```

**Step 2: 提交**

```bash
git add resources/weapons/
git commit -m "feat: 创建武器 .tres 资源文件"
```

---

### Task 23: 创建 .tres 资源文件 — 敌人

**Files:**
- Create: `resources/enemies/normal.tres`
- Create: `resources/enemies/fast.tres`
- Create: `resources/enemies/tank.tres`

**Step 1: 创建目录和资源文件**

```bash
mkdir -p resources/enemies
```

`resources/enemies/normal.tres`:
```
[gd_resource type="Resource" script_class="EnemyData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/enemy_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "normal"
display_name = "普通敌人"
hp = 50.0
speed = 100.0
damage = 10.0
coin_drop_min = 1
coin_drop_max = 3
```

`resources/enemies/fast.tres`:
```
[gd_resource type="Resource" script_class="EnemyData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/enemy_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "fast"
display_name = "快速敌人"
hp = 35.0
speed = 180.0
damage = 8.0
coin_drop_min = 2
coin_drop_max = 4
```

`resources/enemies/tank.tres`:
```
[gd_resource type="Resource" script_class="EnemyData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/enemy_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "tank"
display_name = "坦克敌人"
hp = 200.0
speed = 50.0
damage = 25.0
coin_drop_min = 5
coin_drop_max = 10
```

**Step 2: 提交**

```bash
git add resources/enemies/
git commit -m "feat: 创建敌人 .tres 资源文件"
```

---

### Task 24: 创建 .tres 资源文件 — 塔

**Files:**
- Create: `resources/towers/shooter.tres`
- Create: `resources/towers/wall.tres`
- Create: `resources/towers/slow.tres`

**Step 1: 创建目录和资源文件**

```bash
mkdir -p resources/towers
```

`resources/towers/shooter.tres`:
```
[gd_resource type="Resource" script_class="TowerData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/tower_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "shooter"
display_name = "射手塔"
hp = 80.0
damage = 15.0
fire_rate = 1.0
attack_range = 300.0
shop_price_min = 35
shop_price_max = 45
slow_percent = 0.0
```

`resources/towers/wall.tres`:
```
[gd_resource type="Resource" script_class="TowerData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/tower_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "wall"
display_name = "墙塔"
hp = 300.0
damage = 0.0
fire_rate = 0.0
attack_range = 0.0
shop_price_min = 35
shop_price_max = 45
slow_percent = 0.0
```

`resources/towers/slow.tres`:
```
[gd_resource type="Resource" script_class="TowerData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/tower_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "slow"
display_name = "减速塔"
hp = 70.0
damage = 0.0
fire_rate = 0.0
attack_range = 200.0
shop_price_min = 35
shop_price_max = 45
slow_percent = 0.3
```

**Step 2: 提交**

```bash
git add resources/towers/
git commit -m "feat: 创建塔 .tres 资源文件"
```

---

### Task 25: 创建 .tres 资源文件 — 波次、角色、地图

**Files:**
- Create: `resources/waves/wave_01.tres` ... `wave_10.tres`
- Create: `resources/characters/warrior.tres`, `ranger.tres`, `tank.tres`
- Create: `resources/maps/forest.tres`, `desert.tres`

**Step 1: 创建目录**

```bash
mkdir -p resources/waves resources/characters resources/maps
```

**Step 2: 创建波次资源（10个文件）**

为每波创建 .tres 文件。示例 `resources/waves/wave_01.tres`:
```
[gd_resource type="Resource" script_class="WaveData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/wave_data.gd" id="1"]

[resource]
script = ExtResource("1")
wave_number = 1
duration = 45.0
spawn_interval = 1.5
enemy_types = PackedStringArray("normal")
```

其余 wave_02~wave_10 按 GameConfig.WAVES 中的数据创建。

**Step 3: 创建角色资源**

`resources/characters/warrior.tres`:
```
[gd_resource type="Resource" script_class="CharacterData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/character_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "warrior"
display_name = "战士"
description = "高生命值，低速度"
max_hp = 150.0
speed = 180.0
damage_mult = 1.2
attack_speed_mult = 1.0
move_speed_mult = 0.9
hp_regen = 0.0
```

`resources/characters/ranger.tres` 和 `resources/characters/tank.tres` 同理。

**Step 4: 创建地图资源**

`resources/maps/forest.tres`:
```
[gd_resource type="Resource" script_class="MapData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/map_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "forest"
display_name = "森林"
description = "茂密的森林环境"
preview_image = "res://assets/maps/forest_preview.png"
background = "res://assets/maps/forest_bg.png"
fallback_color = "#2d5016"
```

`resources/maps/desert.tres` 同理。

**Step 5: 提交**

```bash
git add resources/waves/ resources/characters/ resources/maps/
git commit -m "feat: 创建波次、角色、地图 .tres 资源文件"
```

---

### Task 26: 创建 .tres 资源文件 — 特效、商店、生成

**Files:**
- Create: `resources/effects/default_effects.tres`
- Create: `resources/shop/default_shop.tres`
- Create: `resources/spawn/default_spawn.tres`

**Step 1: 创建目录和资源文件**

```bash
mkdir -p resources/effects resources/shop resources/spawn
```

创建 `resources/effects/default_effects.tres`，用 EffectConfigData 所有默认值。

创建 `resources/shop/default_shop.tres`，用 ShopConfigData 默认值。

创建 `resources/spawn/default_spawn.tres`，用 SpawnConfigData 默认值（min_distance=200）。

**Step 2: 提交**

```bash
git add resources/effects/ resources/shop/ resources/spawn/
git commit -m "feat: 创建特效、商店、生成配置 .tres 资源文件"
```

---

### Task 27: 重构 GameConfig 为资源注册表

**Files:**
- Modify: `game_config.gd`

**Step 1: 重构 GameConfig**

GameConfig 从 const 字典变为运行时加载 .tres 的注册表。保留 const 值作为向后兼容（全局尺寸常量等），新增 Resource 字典。

```gdscript
extends Node

# 配置驱动优化 - 游戏配置中心
# 资源注册表 + 全局常量

# 开发模式开关
const DEBUG_MODE = true

# 全局尺寸标准（这些保留为 const，不需要资源化）
const BASE_VIEWPORT_WIDTH = 640
const BASE_VIEWPORT_HEIGHT = 360
const PPU = 30
const GRID_SIZE = 30

const MAP_COLS = 40
const MAP_ROWS = 30
const MAP_PIXEL_WIDTH = MAP_COLS * GRID_SIZE
const MAP_PIXEL_HEIGHT = MAP_ROWS * GRID_SIZE
const MAP_HALF_WIDTH = MAP_PIXEL_WIDTH / 2.0
const MAP_HALF_HEIGHT = MAP_PIXEL_HEIGHT / 2.0

const ENTITY_SIZE_STANDARD = GRID_SIZE
const ENTITY_SIZE_TANK = int(GRID_SIZE * 1.5)
const BULLET_SIZE = int(GRID_SIZE * 0.2)
const COIN_RADIUS = int(GRID_SIZE * 0.2)

const UI_BUTTON_SIZE = Vector2(160, 36)
const UI_BUTTON_SMALL_SIZE = Vector2(120, 32)
const UI_MAP_CARD_SIZE = Vector2(240, 140)
const UI_RESULT_PANEL_SIZE = Vector2(320, 220)
const UI_SHOP_PANEL_SIZE = Vector2(560, 300)
const UI_CARD_GAP = 20

# --- 资源注册表 ---
var weapons: Dictionary = {}       # {id: WeaponData}
var enemies: Dictionary = {}       # {type: EnemyData}
var towers: Dictionary = {}        # {type: TowerData}
var waves: Array[WaveData] = []    # 按波次号排序
var characters: Dictionary = {}    # {id: CharacterData}
var maps: Dictionary = {}          # {id: MapData}
var effects: EffectConfigData = null
var shop: ShopConfigData = null
var spawn: SpawnConfigData = null

# --- 向后兼容（保留旧 API，逐步迁移后移除） ---
var WEAPONS: Dictionary = {}
var ENEMIES: Dictionary = {}
var TOWERS: Dictionary = {}
var WAVES: Dictionary = {}
var PLAYER: Dictionary = {}
var CHARACTERS: Dictionary = {}
var SHOP: Dictionary = {}
var MAPS: Dictionary = {}
var EFFECTS: Dictionary = {}
var SPRITES: Dictionary = {}

func _ready() -> void:
	_load_resources_from_dir("res://resources/weapons/", weapons)
	_load_resources_from_dir("res://resources/enemies/", enemies)
	_load_resources_from_dir("res://resources/towers/", towers)
	_load_waves("res://resources/waves/")
	_load_resources_from_dir("res://resources/characters/", characters)
	_load_resources_from_dir("res://resources/maps/", maps)
	effects = load("res://resources/effects/default_effects.tres")
	shop = load("res://resources/shop/default_shop.tres")
	spawn = load("res://resources/spawn/default_spawn.tres")
	# 构建向后兼容字典
	_build_compat_dicts()

func _load_resources_from_dir(path: String, target: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		push_error("无法打开资源目录: " + path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res: Resource = load(path + file_name)
			if res and "id" in res:
				target[res.id] = res
		file_name = dir.get_next()

func _load_waves(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		push_error("无法打开波次目录: " + path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res: Resource = load(path + file_name)
			if res is WaveData:
				waves.append(res)
		file_name = dir.get_next()
	waves.sort_custom(func(a, b): return a.wave_number < b.wave_number)

func _build_compat_dicts() -> void:
	# 武器
	for id in weapons:
		var w: WeaponData = weapons[id]
		var d: Dictionary = {
			"name": w.display_name,
			"projectile_type": w.projectile_type,
			"fire_rate": w.fire_rate,
			"damage": w.damage,
			"range": w.weapon_range,
		}
		if w.projectile_type == "bullet":
			d["bullet_count"] = w.bullet_count
			d["bullet_speed"] = w.bullet_speed
		elif w.projectile_type == "boomerang":
			d["speed"] = w.boomerang_speed
			d["outbound_distance"] = w.outbound_distance
			d["return_speed_mult"] = w.return_speed_mult
		elif w.projectile_type == "laser":
			d["beam_range"] = w.beam_range
			d["beam_width"] = w.beam_width
			d["beam_duration"] = w.beam_duration
		WEAPONS[id] = d

	# 敌人
	for id in enemies:
		var e: EnemyData = enemies[id]
		ENEMIES[id] = {
			"name": e.display_name,
			"hp": e.hp,
			"speed": e.speed,
			"damage": e.damage,
			"coin_drop_min": e.coin_drop_min,
			"coin_drop_max": e.coin_drop_max
		}

	# 塔
	for id in towers:
		var t: TowerData = towers[id]
		var d: Dictionary = {
			"name": t.display_name,
			"hp": t.hp,
			"damage": t.damage,
			"fire_rate": t.fire_rate,
			"range": t.attack_range,
			"shop_price_min": t.shop_price_min,
			"shop_price_max": t.shop_price_max
		}
		if t.slow_percent > 0:
			d["slow_percent"] = t.slow_percent
		TOWERS[id] = d

	# 波次
	var wave_configs: Array = []
	for w in waves:
		wave_configs.append({
			"duration": w.duration,
			"spawn_interval": w.spawn_interval,
			"enemy_types": Array(w.enemy_types)
		})
	WAVES = {
		"total_waves": waves.size(),
		"wave_configs": wave_configs
	}

	# 角色
	for id in characters:
		var c: CharacterData = characters[id]
		CHARACTERS[id] = {
			"name": c.display_name,
			"description": c.description,
			"max_hp": c.max_hp,
			"speed": c.speed,
			"damage_mult": c.damage_mult,
			"attack_speed_mult": c.attack_speed_mult,
			"move_speed_mult": c.move_speed_mult,
			"hp_regen": c.hp_regen
		}

	# 地图
	for id in maps:
		var m: MapData = maps[id]
		MAPS[id] = {
			"name": m.display_name,
			"description": m.description,
			"preview_image": m.preview_image,
			"background": m.background,
			"fallback_color": m.fallback_color
		}

	# 玩家 — 保留不变
	PLAYER = {
		"initial_hp": 100.0,
		"initial_speed": 200.0,
		"initial_coins": 100,
		"hp_regen_interval": 5.0,
		"default_enemy_touch_damage": 10.0
	}

	# 商店
	SHOP = {
		"refresh_cost": shop.refresh_cost,
		"item_count": shop.item_count,
		"passive_price_min": shop.passive_price_min,
		"passive_price_max": shop.passive_price_max,
		"heal_price": shop.heal_price,
		"heal_amount": shop.heal_amount
	}

	# 特效 — 保留旧嵌套字典格式
	if effects:
		EFFECTS = {
			"camera_shake": {
				"player_hit": {"intensity": effects.camera_shake_player_hit_intensity, "duration": effects.camera_shake_player_hit_duration},
				"enemy_kill": {"intensity": effects.camera_shake_enemy_kill_intensity, "duration": effects.camera_shake_enemy_kill_duration},
				"wave_start": {"intensity": effects.camera_shake_wave_start_intensity, "duration": effects.camera_shake_wave_start_duration}
			},
			"knockback": {"distance": effects.knockback_distance, "duration": effects.knockback_duration},
			"hit_flash": {"duration": effects.hit_flash_duration, "color": effects.hit_flash_color},
			"invincible_blink": {"interval": effects.invincible_blink_interval, "alpha_low": effects.invincible_blink_alpha_low, "alpha_high": effects.invincible_blink_alpha_high},
			"damage_number": {
				"float_distance": effects.damage_number_float_distance,
				"random_offset_x": effects.damage_number_random_offset_x,
				"duration": effects.damage_number_duration,
				"big_damage_threshold": effects.damage_number_big_threshold,
				"big_damage_scale": effects.damage_number_big_scale,
				"normal_color": effects.damage_number_normal_color,
				"big_color": effects.damage_number_big_color
			},
			"death_particles": {"count": effects.death_particle_count, "spread": effects.death_particle_spread, "lifetime": effects.death_particle_lifetime, "gravity": effects.death_particle_gravity},
			"hit_sparks": {"count": effects.hit_spark_count, "lifetime": effects.hit_spark_lifetime, "spread_speed": effects.hit_spark_spread_speed},
			"coin_pickup": {"shrink_duration": effects.coin_pickup_shrink_duration},
			"bullet_trail": {"length": effects.bullet_trail_length, "width": effects.bullet_trail_width, "color": effects.bullet_trail_color},
			"boomerang": {"rotation_speed": effects.boomerang_rotation_speed, "trail_points": effects.boomerang_trail_points, "trail_width": effects.boomerang_trail_width, "trail_color": effects.boomerang_trail_color, "return_rotation_mult": effects.boomerang_return_rotation_mult},
			"laser": {"beam_width": effects.laser_beam_width, "core_color": effects.laser_core_color, "edge_color": effects.laser_edge_color, "flash_alpha": effects.laser_flash_alpha, "flash_duration": effects.laser_flash_duration},
			"camera": {"zoom": effects.camera_zoom, "smoothing_speed": effects.camera_smoothing_speed, "look_ahead_distance": effects.camera_look_ahead_distance, "look_ahead_smoothing": effects.camera_look_ahead_smoothing}
		}

	# 精灵图配置 — Phase 2 后续步骤中会资源化，暂保留
	SPRITES = {
		"player": {
			"warrior": {
				"idle": "res://assets/sprites/player/knight_idle.png",
				"walk": "res://assets/sprites/player/knight_walk.png",
				"frame_size": Vector2(16, 16),
				"idle_frames": 4, "walk_frames": 4, "walk_directions": 4, "fps": 8.0
			},
			"ranger": {
				"idle": "res://assets/sprites/player/hunter_idle.png",
				"walk": "res://assets/sprites/player/hunter_walk.png",
				"frame_size": Vector2(16, 16),
				"idle_frames": 4, "walk_frames": 4, "walk_directions": 4, "fps": 8.0
			},
			"tank": {
				"idle": "res://assets/sprites/player/monk_idle.png",
				"walk": "res://assets/sprites/player/monk_walk.png",
				"frame_size": Vector2(16, 16),
				"idle_frames": 4, "walk_frames": 4, "walk_directions": 4, "fps": 8.0
			}
		},
		"enemies": {
			"normal": {"spritesheet": "res://assets/sprites/enemies/slime.png", "frame_size": Vector2(16, 16), "walk_frames": 4, "walk_directions": 4, "fps": 8.0},
			"fast": {"spritesheet": "res://assets/sprites/enemies/bluebat.png", "frame_size": Vector2(16, 16), "walk_frames": 4, "walk_directions": 4, "fps": 10.0},
			"tank": {"spritesheet": "res://assets/sprites/enemies/trex.png", "frame_size": Vector2(16, 16), "walk_frames": 4, "walk_directions": 4, "fps": 6.0}
		},
		"towers": {
			"tileset": "res://assets/sprites/towers/tileset_towers.png",
			"shooter": {"region": Rect2(32, 0, 16, 16)},
			"wall": {"region": Rect2(64, 32, 16, 16)},
			"slow": {"region": Rect2(320, 0, 16, 16)}
		},
		"projectiles": {
			"bullet": "res://assets/sprites/projectiles/kunai.png",
			"boomerang": "res://assets/sprites/projectiles/shuriken.png"
		},
		"items": {
			"coin": "res://assets/sprites/items/gold_coin.png"
		}
	}
```

注意：GameConfig 原来是 `const` 字典，现在需要改为 `var` 并在 `_ready()` 中填充。原有的 SPRITES 字典暂时保持硬编码（SpriteFrames 资源化在后续子任务中处理）。

**Step 2: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 所有测试通过（向后兼容字典保证现有代码不中断）

**Step 3: 提交**

```bash
git add game_config.gd
git commit -m "refactor: GameConfig 改为资源注册表 + 向后兼容字典"
```

---

### Task 28: 编写 Resource 加载测试

**Files:**
- Create: `tests/unit/test_resource_loading.gd`

**Step 1: 编写测试验证资源加载正确**

```gdscript
extends GutTest

# 验证 .tres 资源加载到 GameConfig 注册表

func test_weapons_loaded():
	assert_true(GameConfig.weapons.has("rifle"), "应加载 rifle 武器资源")
	assert_true(GameConfig.weapons.has("boomerang"), "应加载 boomerang 武器资源")
	assert_true(GameConfig.weapons.has("laser"), "应加载 laser 武器资源")

func test_weapon_data_type():
	assert_is(GameConfig.weapons["rifle"], WeaponData, "rifle 应为 WeaponData 类型")

func test_weapon_data_values():
	var rifle: WeaponData = GameConfig.weapons["rifle"]
	assert_eq(rifle.damage, 10.0, "rifle 伤害应为 10.0")
	assert_eq(rifle.fire_rate, 0.1, "rifle 射速应为 0.1")
	assert_eq(rifle.projectile_type, "bullet", "rifle 弹道类型应为 bullet")

func test_enemies_loaded():
	assert_true(GameConfig.enemies.has("normal"), "应加载 normal 敌人资源")
	assert_true(GameConfig.enemies.has("fast"), "应加载 fast 敌人资源")
	assert_true(GameConfig.enemies.has("tank"), "应加载 tank 敌人资源")

func test_enemy_data_values():
	var normal: EnemyData = GameConfig.enemies["normal"]
	assert_eq(normal.hp, 50.0, "普通敌人 HP 应为 50.0")
	assert_eq(normal.speed, 100.0, "普通敌人速度应为 100.0")

func test_towers_loaded():
	assert_true(GameConfig.towers.has("shooter"), "应加载 shooter 塔资源")
	assert_true(GameConfig.towers.has("wall"), "应加载 wall 塔资源")
	assert_true(GameConfig.towers.has("slow"), "应加载 slow 塔资源")

func test_waves_loaded():
	assert_eq(GameConfig.waves.size(), 10, "应加载 10 个波次资源")

func test_waves_sorted():
	for i in range(GameConfig.waves.size() - 1):
		assert_lt(GameConfig.waves[i].wave_number, GameConfig.waves[i + 1].wave_number, "波次应按编号排序")

func test_characters_loaded():
	assert_true(GameConfig.characters.has("warrior"), "应加载 warrior 角色")
	assert_true(GameConfig.characters.has("ranger"), "应加载 ranger 角色")
	assert_true(GameConfig.characters.has("tank"), "应加载 tank 角色")

func test_maps_loaded():
	assert_true(GameConfig.maps.has("forest"), "应加载 forest 地图")
	assert_true(GameConfig.maps.has("desert"), "应加载 desert 地图")

func test_effects_loaded():
	assert_not_null(GameConfig.effects, "应加载特效配置资源")
	assert_is(GameConfig.effects, EffectConfigData, "应为 EffectConfigData 类型")

func test_shop_loaded():
	assert_not_null(GameConfig.shop, "应加载商店配置资源")

func test_spawn_loaded():
	assert_not_null(GameConfig.spawn, "应加载生成配置资源")

func test_compat_weapons_dict():
	assert_eq(GameConfig.WEAPONS.size(), 3, "向后兼容 WEAPONS 应有 3 项")
	assert_eq(GameConfig.WEAPONS["rifle"]["damage"], 10.0, "向后兼容 rifle damage")

func test_compat_enemies_dict():
	assert_eq(GameConfig.ENEMIES.size(), 3, "向后兼容 ENEMIES 应有 3 项")

func test_compat_waves_dict():
	assert_eq(GameConfig.WAVES["total_waves"], 10, "向后兼容 total_waves")
	assert_eq(GameConfig.WAVES["wave_configs"].size(), 10, "向后兼容 wave_configs 应有 10 项")
```

**Step 2: 运行测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_resource_loading -gexit`
Expected: 全部通过

**Step 3: 提交**

```bash
git add tests/unit/test_resource_loading.gd
git commit -m "test: 资源加载和向后兼容测试"
```

---

### Task 29: 消除硬编码值 — bullet.gd 和 coin.gd

**Files:**
- Modify: `scripts/entities/bullet.gd`
- Modify: `scripts/entities/coin.gd`

**Step 1: 修改 bullet.gd**

将 `speed = 400.0` 和 `TRAIL_MAX_POINTS = 4` 改为从外部设置或从 GameConfig.effects 读取：

```gdscript
extends Area2D

var speed: float = 600.0  # 由创建者设置（SceneFactory 或 player）
var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var lifetime: float = 5.0
var elapsed: float = 0.0

var _trail: Line2D = null
var _trail_positions: Array[Vector2] = []
var _trail_max_points: int = 4

func _ready():
	body_entered.connect(_on_body_entered)
	# 创建拖尾 Line2D
	var config: Dictionary = GameConfig.EFFECTS["bullet_trail"]
	_trail_max_points = GameConfig.effects.bullet_trail_max_points if GameConfig.effects else 4
	_trail = Line2D.new()
	_trail.width = config["width"]
	_trail.default_color = config["color"]
	_trail.z_index = -1
	_trail.top_level = true
	add_child(_trail)

func _physics_process(delta):
	global_position += direction * speed * delta
	elapsed += delta
	_update_trail()
	if elapsed >= lifetime:
		queue_free()

func _update_trail() -> void:
	_trail_positions.insert(0, global_position)
	if _trail_positions.size() > _trail_max_points:
		_trail_positions.resize(_trail_max_points)
	_trail.clear_points()
	for pos in _trail_positions:
		_trail.add_point(pos)

func _on_body_entered(body):
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(direction)
		EffectsManager.spawn_hit_sparks(global_position)
		queue_free()
```

**Step 2: 修改 coin.gd**

将 `force_attract()` 中的硬编码 `800.0` 改为 `attract_speed * 1.6`（保持相对比例）：

将 `coin.gd` 的 `force_attract()` 方法修改为：
```gdscript
func force_attract():
	is_attracted = true
	attract_speed = attract_speed * 1.6  # 加速吸引
```

**Step 3: 修改 boomerang.gd 的 return distance**

将 `boomerang.gd` 第75行的 `if distance < 15.0` 改为从 effects 配置读取：

```gdscript
func _process_returning(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	var return_speed: float = speed * return_speed_mult
	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	var return_dist: float = GameConfig.effects.boomerang_return_distance if GameConfig.effects else 15.0
	if distance < return_dist:
		queue_free()
		return
	var move_dir: Vector2 = to_player.normalized()
	global_position += move_dir * return_speed * delta
```

**Step 4: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

**Step 5: 提交**

```bash
git add scripts/entities/bullet.gd scripts/entities/coin.gd scripts/entities/boomerang.gd
git commit -m "refactor: 消除 bullet/coin/boomerang 中的硬编码值"
```

---

### Task 30: 消除硬编码值 — effects_manager.gd 和 player.gd

**Files:**
- Modify: `scripts/systems/effects_manager.gd`
- Modify: `scripts/entities/player.gd`

**Step 1: 修改 effects_manager.gd**

将死亡粒子速度 `randf_range(50.0, 120.0)` 和 z_index 硬编码改为从 effects 配置读取：

在 `spawn_damage_number` 中：`label.z_index = 100` → `label.z_index = GameConfig.effects.damage_number_z_index if GameConfig.effects else 100`

在 `spawn_hit_sparks` 中：`spark.z_index = 50` → `spark.z_index = GameConfig.effects.hit_spark_z_index if GameConfig.effects else 50`

在 `spawn_death_effect` 中：
- `particle.z_index = 50` → `particle.z_index = GameConfig.effects.death_particle_z_index if GameConfig.effects else 50`
- `randf_range(50.0, 120.0)` → `randf_range(GameConfig.effects.death_particle_speed_min, GameConfig.effects.death_particle_speed_max) if GameConfig.effects else randf_range(50.0, 120.0)`

**Step 2: 修改 player.gd 中的激光硬编码**

在 `_shoot_laser` 中：
- `range(20)` → 使用 `GameConfig.effects.laser_ray_query_limit`
- `collision_mask = 2` → 使用 `GameConfig.effects.laser_collision_mask`
- `Vector2(2000, 2000)` → 使用 `GameConfig.effects.laser_flash_size`
- `flash.z_index = 90` → 使用 `GameConfig.effects.laser_flash_z_index`

在 `_spawn_muzzle_flash` 中：
- `Vector2(6, 6)` → 使用 `GameConfig.effects.muzzle_flash_size`
- `Color(1, 1, 0.8, 0.9)` → 使用 `GameConfig.effects.muzzle_flash_color`
- `flash.z_index = 10` → 使用 `GameConfig.effects.muzzle_flash_z_index`

**Step 3: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

**Step 4: 提交**

```bash
git add scripts/systems/effects_manager.gd scripts/entities/player.gd
git commit -m "refactor: 消除 effects_manager 和 player 中的硬编码特效值"
```

---

### Task 31: 消除硬编码值 — enemy_spawner.gd 和 sprite_loader.gd

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd`
- Modify: `scripts/core/sprite_loader.gd`

**Step 1: 修改 enemy_spawner.gd**

将 `min_distance_from_player = 200.0` 改为从 spawn 配置读取：

```gdscript
var min_distance_from_player: float = 200.0  # 默认值

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if GameConfig.spawn:
		min_distance_from_player = GameConfig.spawn.min_distance_from_player
	# 连接 EventBus 信号
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.game_won.connect(_on_game_ended)
	EventBus.game_lost.connect(_on_game_ended)
```

**Step 2: 修改 sprite_loader.gd 的方向滞后阈值**

将 `0.7` 和 `1.4` 改为参数或从配置读取。由于 `get_walk_animation` 是静态方法，添加可选参数：

```gdscript
static func get_walk_animation(velocity: Vector2, current_anim: String = "", hysteresis_keep: float = 0.7, hysteresis_switch: float = 1.4) -> String:
	if velocity.length_squared() < 1.0:
		return "idle"

	var abs_x: float = abs(velocity.x)
	var abs_y: float = abs(velocity.y)

	var is_current_horizontal: bool = current_anim in ["walk_left", "walk_right"]
	var is_current_vertical: bool = current_anim in ["walk_up", "walk_down"]

	var use_horizontal: bool
	if is_current_horizontal:
		use_horizontal = abs_x >= abs_y * hysteresis_keep
	elif is_current_vertical:
		use_horizontal = abs_x > abs_y * hysteresis_switch
	else:
		use_horizontal = abs_x > abs_y

	if use_horizontal:
		return "walk_right" if velocity.x > 0 else "walk_left"
	else:
		return "walk_down" if velocity.y > 0 else "walk_up"
```

**Step 3: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

**Step 4: 提交**

```bash
git add scripts/systems/enemy_spawner.gd scripts/core/sprite_loader.gd
git commit -m "refactor: 消除 enemy_spawner 和 sprite_loader 中的硬编码值"
```

---

### Task 32: 运行全量测试 + Phase 2 合并

**Step 1: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部通过

**Step 2: 修复任何失败的测试**

根据输出修复。

**Step 3: 合并到 develop**

```bash
git checkout develop
git merge feature/custom-resources --no-ff -m "feat: Phase 2 完成 — 自定义资源体系 + 消除硬编码"
```

---

## Phase 3: 文件夹结构整理

### Task 33: 创建 feature 分支

```bash
git checkout -b feature/folder-restructure develop
```

---

### Task 34: 移动 game_config.gd 到 scripts/core/

**Files:**
- Move: `game_config.gd` → `scripts/core/game_config.gd`
- Modify: `project.godot`

**Step 1: 移动文件**

```bash
git mv game_config.gd scripts/core/game_config.gd
```

**Step 2: 更新 project.godot**

将 `GameConfig="*res://game_config.gd"` 改为 `GameConfig="*res://scripts/core/game_config.gd"`

**Step 3: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

**Step 4: 提交**

```bash
git add -A
git commit -m "refactor: 移动 game_config.gd 到 scripts/core/"
```

---

### Task 35: 创建 scenes/entities/ 并移动实体场景

**Files:**
- Move: `scenes/player.tscn` → `scenes/entities/player.tscn`
- Move: `scenes/bullet.tscn` → `scenes/entities/bullet.tscn`
- Move: `scenes/boomerang.tscn` → `scenes/entities/boomerang.tscn`
- Move: `scenes/laser_beam.tscn` → `scenes/entities/laser_beam.tscn`
- Move: `scenes/coin.tscn` → `scenes/entities/coin.tscn`
- Move: `scenes/enemies/` → `scenes/entities/enemies/`
- Move: `scenes/towers/` → `scenes/entities/towers/`

**Step 1: 创建目录并移动文件**

```bash
mkdir -p scenes/entities
git mv scenes/player.tscn scenes/entities/player.tscn
git mv scenes/bullet.tscn scenes/entities/bullet.tscn
git mv scenes/boomerang.tscn scenes/entities/boomerang.tscn
git mv scenes/laser_beam.tscn scenes/entities/laser_beam.tscn
git mv scenes/coin.tscn scenes/entities/coin.tscn
git mv scenes/enemies scenes/entities/enemies
git mv scenes/towers scenes/entities/towers
```

**Step 2: 更新 SceneFactory 中的 preload 路径**

在 `scripts/core/scene_factory.gd` 中更新所有 preload 路径：
- `"res://scenes/towers/tower_shooter.tscn"` → `"res://scenes/entities/towers/tower_shooter.tscn"`
- `"res://scenes/towers/tower_wall.tscn"` → `"res://scenes/entities/towers/tower_wall.tscn"`
- `"res://scenes/towers/tower_slow.tscn"` → `"res://scenes/entities/towers/tower_slow.tscn"`
- `"res://scenes/enemies/enemy_normal.tscn"` → `"res://scenes/entities/enemies/enemy_normal.tscn"`
- `"res://scenes/enemies/enemy_fast.tscn"` → `"res://scenes/entities/enemies/enemy_fast.tscn"`
- `"res://scenes/enemies/enemy_tank.tscn"` → `"res://scenes/entities/enemies/enemy_tank.tscn"`
- `"res://scenes/bullet.tscn"` → `"res://scenes/entities/bullet.tscn"`
- `"res://scenes/coin.tscn"` → `"res://scenes/entities/coin.tscn"`
- `"res://scenes/boomerang.tscn"` → `"res://scenes/entities/boomerang.tscn"`
- `"res://scenes/laser_beam.tscn"` → `"res://scenes/entities/laser_beam.tscn"`

**Step 3: 更新 .tscn 文件内的 [ext_resource] 路径**

搜索所有 .tscn 文件中引用被移动文件的路径并更新。

**Step 4: 更新测试中的 preload 路径**

搜索 `tests/` 目录中所有 preload/load 引用被移动场景的测试文件并更新路径。

**Step 5: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

**Step 6: 提交**

```bash
git add -A
git commit -m "refactor: 移动实体场景到 scenes/entities/"
```

---

### Task 36: 创建 scenes/levels/ 并移动关卡场景

**Files:**
- Move: `scenes/main.tscn` → `scenes/levels/main.tscn`
- Move: `scenes/placement.tscn` → `scenes/levels/placement.tscn`

**Step 1: 创建目录并移动**

```bash
mkdir -p scenes/levels
git mv scenes/main.tscn scenes/levels/main.tscn
git mv scenes/placement.tscn scenes/levels/placement.tscn
```

**Step 2: 更新所有引用路径**

搜索并更新以下文件中的场景引用：
- `scripts/systems/wave_manager.gd`: `change_scene_to_file("res://scenes/ui/shop.tscn")` 和 `change_scene_to_file("res://scenes/ui/result.tscn")` — 这些不需要改
- `scripts/ui/placement.gd`: `change_scene_to_file("res://scenes/main.tscn")` → `"res://scenes/levels/main.tscn"`
- `scripts/systems/shop_manager.gd`: `change_scene_to_file("res://scenes/placement.tscn")` → `"res://scenes/levels/placement.tscn"`，`change_scene_to_file("res://scenes/main.tscn")` → `"res://scenes/levels/main.tscn"`

搜索所有 .gd 和 .tscn 文件中包含 `scenes/main.tscn` 或 `scenes/placement.tscn` 的引用。

**Step 3: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

**Step 4: 提交**

```bash
git add -A
git commit -m "refactor: 移动关卡场景到 scenes/levels/"
```

---

### Task 37: 移动选择界面到 scenes/ui/，创建 scenes/shared/

**Files:**
- Move: `scenes/character_selection.tscn` → `scenes/ui/character_selection.tscn`
- Move: `scenes/map_boundary.tscn` → `scenes/shared/map_boundary.tscn`

**Step 1: 移动文件**

```bash
mkdir -p scenes/shared
git mv scenes/character_selection.tscn scenes/ui/character_selection.tscn
git mv scenes/map_boundary.tscn scenes/shared/map_boundary.tscn
```

注：`weapon_select.tscn` 和 `map_select.tscn` 如果已在 `scenes/` 根目录，也需要移动到 `scenes/ui/`。

**Step 2: 更新所有引用路径**

搜索所有 .gd 和 .tscn 文件中的引用。

**Step 3: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

**Step 4: 提交**

```bash
git add -A
git commit -m "refactor: 移动 character_selection 和 map_boundary 场景到正确目录"
```

---

### Task 38: 更新 CLAUDE.md 反映新结构

**Files:**
- Modify: `CLAUDE.md`

**Step 1: 更新 CLAUDE.md 中的架构文档**

更新代码组织、游戏流程中的场景路径、Autoload 路径等，反映重构后的文件结构。

**Step 2: 提交**

```bash
git add CLAUDE.md
git commit -m "docs: 更新 CLAUDE.md 反映重构后的目录结构"
```

---

### Task 39: Phase 3 最终测试与合并

**Step 1: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部通过

**Step 2: 合并到 develop**

```bash
git checkout develop
git merge feature/folder-restructure --no-ff -m "feat: Phase 3 完成 — 文件夹结构整理"
```

---

### Task 40: 清理向后兼容代码（可选后续）

Phase 2 的向后兼容字典（WEAPONS, ENEMIES 等大写变量）可以在后续逐步清理：

1. 找到所有使用 `GameConfig.WEAPONS[...]` 的代码
2. 替换为 `GameConfig.weapons[...].property` 直接访问 Resource 属性
3. 移除 `_build_compat_dicts()` 和相关大写变量

这一步留在后续迭代中完成，确保当前重构稳定。

---

## 测试命令快速参考

```bash
# 全量测试
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# 单个测试文件
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude=test_event_bus -gexit

# 单元测试目录
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
