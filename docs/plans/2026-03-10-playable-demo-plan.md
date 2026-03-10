# Playable Demo Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add audio system, pause functionality, boss charge ability, and debug panel to reach a playable demo for self-testing.

**Architecture:** Four independent modules, each following existing patterns (Autoload singletons, EventBus signals, component-based entities). Audio and Pause are new Autoloads. Boss charge extends existing enemy state machine. Debug panel is a scene-local CanvasLayer.

**Tech Stack:** Godot 4.6, GDScript, GUT test framework

---

### Task 1: AudioManager Autoload - Core

**Files:**
- Create: `scripts/systems/audio_manager.gd`
- Modify: `project.godot` (add Autoload entry after EffectsManager line)

**Step 1: Create AudioManager script**

```gdscript
# scripts/systems/audio_manager.gd
extends Node

## 音效管理器 — 统一管理 SFX 播放
## 作为 Autoload 单例全局可用

const POOL_SIZE: int = 8

var _sounds: Dictionary = {}  # sound_id -> AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0

func _ready() -> void:
	_create_pool()
	_register_sounds()

func _create_pool() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)

func _register_sounds() -> void:
	var sfx_dir := "res://assets/sfx/"
	var sound_map: Dictionary = {
		"shoot": "shoot.wav",
		"hit": "hit.wav",
		"enemy_die": "enemy_die.wav",
		"coin_pickup": "coin_pickup.wav",
		"player_hit": "player_hit.wav",
		"wave_start": "wave_start.wav",
		"wave_complete": "wave_complete.wav",
		"shop_buy": "shop_buy.wav",
		"boss_appear": "boss_appear.wav",
	}
	for id: String in sound_map:
		var path: String = sfx_dir + sound_map[id]
		if ResourceLoader.exists(path):
			_sounds[id] = load(path)

func play(sound_id: String, volume_db: float = 0.0) -> void:
	if not _sounds.has(sound_id):
		return
	var player: AudioStreamPlayer = _pool[_pool_index]
	player.stream = _sounds[sound_id]
	player.volume_db = volume_db
	player.play()
	_pool_index = (_pool_index + 1) % POOL_SIZE
```

**Step 2: Register as Autoload in project.godot**

In `project.godot`, in the `[autoload]` section, add after the `EffectsManager` line:

```
AudioManager="*res://scripts/systems/audio_manager.gd"
```

**Step 3: Create placeholder sound files**

Create directory `assets/sfx/` and add 9 placeholder `.wav` files. These can be generated with jsfxr or be silent 0.1s WAV files initially. The files needed are:
`shoot.wav`, `hit.wav`, `enemy_die.wav`, `coin_pickup.wav`, `player_hit.wav`, `wave_start.wav`, `wave_complete.wav`, `shop_buy.wav`, `boss_appear.wav`

**Step 4: Write unit test**

```gdscript
# tests/unit/test_audio_manager.gd
extends GutTest

## AudioManager 单元测试

var audio_manager: Node

func before_each():
	audio_manager = load("res://scripts/systems/audio_manager.gd").new()
	add_child(audio_manager)

func after_each():
	audio_manager.queue_free()

func test_pool_created():
	assert_eq(audio_manager._pool.size(), 8, "应创建 8 个 AudioStreamPlayer")

func test_play_unknown_sound_no_crash():
	audio_manager.play("nonexistent")
	assert_true(true, "播放不存在的音效不应崩溃")

func test_pool_index_wraps():
	# 模拟播放超过池大小的次数
	for i in 10:
		audio_manager.play("nonexistent")
	assert_eq(audio_manager._pool_index, 10 % 8, "池索引应正确环绕")

func test_register_sounds_populates_dictionary():
	# 若 assets/sfx/ 目录中有文件则 _sounds 非空
	# 无文件时 _sounds 应为空但不崩溃
	assert_typeof(audio_manager._sounds, TYPE_DICTIONARY)
```

**Step 5: Run test to verify**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_audio_manager.gd -gexit`

**Step 6: Commit**

```bash
git add scripts/systems/audio_manager.gd assets/sfx/ tests/unit/test_audio_manager.gd project.godot
git commit -m "feat: AudioManager 基础框架（Autoload + 音效池 + 占位音效）"
```

---

### Task 2: AudioManager - Hook into game events

**Files:**
- Modify: `scripts/entities/weapons/bullet_weapon.gd:45` (after `_spawn_muzzle_flash`)
- Modify: `scripts/entities/enemy.gd:99-101` (in `_on_died`)
- Modify: `scripts/entities/coin.gd:34` (in `_play_pickup_effect`)
- Modify: `scripts/components/health_component.gd` (in `take_damage`, for player_hit)
- Modify: `scripts/systems/wave_manager.gd:81,52` (wave_started, wave_completed)
- Modify: `scripts/systems/enemy_spawner.gd:122` (after boss spawn)
- Modify: `scripts/systems/shop_manager.gd:76` (after apply_effect)

**Step 1: Add shoot sound in BulletWeapon**

In `scripts/entities/weapons/bullet_weapon.gd`, after line 45 (`_spawn_muzzle_flash(owner_node)`), add:

```gdscript
	AudioManager.play("shoot")
```

**Step 2: Add enemy death + hit sounds in enemy.gd**

In `scripts/entities/enemy.gd`, in `_on_died()` (after line 99, `EventBus.enemy_killed.emit(...)`), add:

```gdscript
	AudioManager.play("enemy_die")
```

In `_on_hurtbox_hit()` (line 134), add at the start of the function:

```gdscript
	AudioManager.play("hit", -6.0)
```

**Step 3: Add coin pickup sound**

In `scripts/entities/coin.gd`, in `_on_body_entered()` (after line 33, `GameData.record_coins_earned`), add:

```gdscript
		AudioManager.play("coin_pickup")
```

**Step 4: Add player hit sound**

In `scripts/entities/enemy.gd` `_on_hurtbox_hit` is enemy getting hit. For player hit, check `scripts/entities/player.gd`. Find the player's hurtbox hit handler and add:

```gdscript
	AudioManager.play("player_hit")
```

**Step 5: Add wave start/complete sounds**

In `scripts/systems/wave_manager.gd`:
- After line 81 (`EventBus.wave_started.emit(wave_num, wave_data)`), add:
```gdscript
	AudioManager.play("wave_start")
```
- After line 52 (`EventBus.wave_completed.emit(current_wave)`), add:
```gdscript
	AudioManager.play("wave_complete")
```

**Step 6: Add boss appear sound**

In `scripts/systems/enemy_spawner.gd`, after line 122 (`get_parent().add_child(boss)`), add:

```gdscript
	AudioManager.play("boss_appear")
```

**Step 7: Add shop buy sound**

In `scripts/systems/shop_manager.gd`, after line 76 (`_effect_applier.apply_effect(item)`), add:

```gdscript
	AudioManager.play("shop_buy")
```

**Step 8: Run all tests to verify no regressions**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

Expected: All 253+ tests pass (AudioManager.play with missing sounds is a no-op)

**Step 9: Commit**

```bash
git add scripts/entities/weapons/bullet_weapon.gd scripts/entities/enemy.gd scripts/entities/coin.gd scripts/systems/wave_manager.gd scripts/systems/enemy_spawner.gd scripts/systems/shop_manager.gd
git commit -m "feat: 游戏事件接入 AudioManager（射击/击杀/拾取/波次/Boss/商店）"
```

---

### Task 3: Pause System

**Files:**
- Create: `scripts/ui/pause_overlay.gd`
- Modify: `scripts/ui/main.gd` (add pause input handling + PauseOverlay creation)
- Modify: `project.godot` (add `pause` input action)

**Step 1: Add pause input action to project.godot**

In `project.godot`, in the `[input]` section, add:

```
pause={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194305,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

Note: `physical_keycode 4194305` = KEY_ESCAPE

**Step 2: Create PauseOverlay script**

```gdscript
# scripts/ui/pause_overlay.gd
extends CanvasLayer

## 暂停覆盖层 — ESC 切换暂停，显示暂停菜单

var _panel: PanelContainer
var _is_paused: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	_is_paused = not _is_paused
	get_tree().paused = _is_paused
	visible = _is_paused

func _build_ui() -> void:
	# 半透明背景
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 居中容器
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "已暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	# 继续按钮
	var resume_btn := Button.new()
	resume_btn.text = "继续"
	resume_btn.pressed.connect(_toggle_pause)
	resume_btn.custom_minimum_size = Vector2(120, 36)
	vbox.add_child(resume_btn)

	# 返回主菜单按钮
	var menu_btn := Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.pressed.connect(_on_return_to_menu)
	menu_btn.custom_minimum_size = Vector2(120, 36)
	vbox.add_child(menu_btn)

func _on_return_to_menu() -> void:
	get_tree().paused = false
	_is_paused = false
	SceneManager.go_to(Enums.Scene.START_MENU)
```

**Step 3: Add PauseOverlay to main.gd**

Replace the entire `scripts/ui/main.gd` with:

```gdscript
extends Node2D

var _pause_overlay: CanvasLayer

func _ready() -> void:
	# 暂停覆盖层
	_pause_overlay = load("res://scripts/ui/pause_overlay.gd").new()
	add_child(_pause_overlay)
```

**Step 4: Write unit test**

```gdscript
# tests/unit/test_pause_overlay.gd
extends GutTest

## PauseOverlay 单元测试

var overlay: CanvasLayer

func before_each():
	overlay = load("res://scripts/ui/pause_overlay.gd").new()
	add_child(overlay)

func after_each():
	overlay.queue_free()
	get_tree().paused = false

func test_starts_hidden():
	assert_false(overlay.visible, "暂停覆盖层初始应隐藏")

func test_toggle_pause_shows_overlay():
	overlay._toggle_pause()
	assert_true(overlay.visible, "暂停后应显示")
	assert_true(get_tree().paused, "暂停后 tree.paused 应为 true")

func test_toggle_pause_twice_resumes():
	overlay._toggle_pause()
	overlay._toggle_pause()
	assert_false(overlay.visible, "恢复后应隐藏")
	assert_false(get_tree().paused, "恢复后 tree.paused 应为 false")

func test_process_mode_always():
	assert_eq(overlay.process_mode, Node.PROCESS_MODE_ALWAYS, "暂停时仍需处理输入")
```

**Step 5: Run test**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_pause_overlay.gd -gexit`

**Step 6: Commit**

```bash
git add scripts/ui/pause_overlay.gd scripts/ui/main.gd tests/unit/test_pause_overlay.gd project.godot
git commit -m "feat: 暂停系统（ESC 暂停/继续，返回主菜单）"
```

---

### Task 4: EnemyData charge fields

**Files:**
- Modify: `scripts/resources/enemy_data.gd` (add 4 optional charge fields)
- Modify: `resources/enemies/boss_brute.tres` (fill charge values)

**Step 1: Add charge fields to EnemyData**

In `scripts/resources/enemy_data.gd`, after line 10 (`@export var coin_drop_max`), add:

```gdscript

# Boss 冲锋参数（可选，普通敌人留默认值 0）
@export var charge_cooldown: float = 0.0
@export var charge_speed_mult: float = 0.0
@export var charge_damage_mult: float = 0.0
@export var charge_windup_time: float = 0.0
```

**Step 2: Update boss_brute.tres**

In `resources/enemies/boss_brute.tres`, after `coin_drop_max = 25`, add:

```
charge_cooldown = 8.0
charge_speed_mult = 4.0
charge_damage_mult = 2.0
charge_windup_time = 0.8
```

**Step 3: Write test**

```gdscript
# tests/unit/test_enemy_data_charge.gd
extends GutTest

## EnemyData 冲锋字段测试

func test_default_charge_fields_are_zero():
	var data := EnemyData.new()
	assert_eq(data.charge_cooldown, 0.0, "默认冲锋冷却应为 0")
	assert_eq(data.charge_speed_mult, 0.0, "默认冲锋速度倍率应为 0")
	assert_eq(data.charge_damage_mult, 0.0, "默认冲锋伤害倍率应为 0")
	assert_eq(data.charge_windup_time, 0.0, "默认冲锋预备时间应为 0")

func test_boss_brute_has_charge_data():
	var data: EnemyData = GameConfig.enemies["boss_brute"]
	assert_gt(data.charge_cooldown, 0.0, "蛮兽应有冲锋冷却")
	assert_gt(data.charge_speed_mult, 1.0, "蛮兽冲锋速度应大于正常")
	assert_gt(data.charge_damage_mult, 1.0, "蛮兽冲锋伤害应大于正常")
	assert_gt(data.charge_windup_time, 0.0, "蛮兽应有冲锋预备时间")

func test_normal_enemy_no_charge():
	var data: EnemyData = GameConfig.enemies["normal"]
	assert_eq(data.charge_cooldown, 0.0, "普通敌人不应有冲锋")
```

**Step 4: Run test**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_enemy_data_charge.gd -gexit`

**Step 5: Commit**

```bash
git add scripts/resources/enemy_data.gd resources/enemies/boss_brute.tres tests/unit/test_enemy_data_charge.gd
git commit -m "feat: EnemyData 新增冲锋字段，boss_brute 填充冲锋数值"
```

---

### Task 5: Boss Brute Charge State Machine

**Files:**
- Modify: `scripts/entities/boss_brute.gd` (implement charge state machine)

**Step 1: Implement boss_brute charge behavior**

Replace `scripts/entities/boss_brute.gd` entirely:

```gdscript
extends "res://scripts/entities/boss_base.gd"

# Boss: 蛮兽 — 重型近战 Boss，周期性冲锋攻击

enum ChargeState { CHASE, WINDUP, CHARGING, STUNNED }

var _charge_state: int = ChargeState.CHASE
var _charge_timer: float = 0.0
var _charge_elapsed: float = 0.0
var _charge_direction: Vector2 = Vector2.ZERO
var _charge_duration: float = 0.6  # 冲锋持续时间
var _stun_duration: float = 0.5    # 眩晕持续时间
var _stun_timer: float = 0.0
var _original_damage: float = 0.0
var _min_charge_distance: float = 80.0  # 最小冲锋距离

func _ready() -> void:
	super._ready()
	_charge_timer = data.charge_cooldown
	_original_damage = data.damage

func _physics_process(delta: float) -> void:
	if data.charge_cooldown <= 0.0:
		# 没有冲锋数据则走普通 enemy 逻辑
		super._physics_process(delta)
		return

	match _charge_state:
		ChargeState.CHASE:
			_process_chase(delta)
		ChargeState.WINDUP:
			_process_windup(delta)
		ChargeState.CHARGING:
			_process_charging(delta)
		ChargeState.STUNNED:
			_process_stunned(delta)

func _process_chase(delta: float) -> void:
	# 正常追击（复用 enemy 逻辑）
	attack_timer -= delta
	_chase_player()

	# 冲锋冷却计时
	_charge_timer -= delta
	if _charge_timer <= 0.0 and _can_charge():
		_start_windup()

func _can_charge() -> bool:
	if not player or not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) > _min_charge_distance

func _start_windup() -> void:
	_charge_state = ChargeState.WINDUP
	_charge_elapsed = 0.0
	velocity = Vector2.ZERO
	# 闪红预警
	modulate = Color(1.5, 0.3, 0.3, 1.0)

func _process_windup(delta: float) -> void:
	_charge_elapsed += delta
	if _charge_elapsed >= data.charge_windup_time:
		_start_charge()

func _start_charge() -> void:
	_charge_state = ChargeState.CHARGING
	_charge_elapsed = 0.0
	# 锁定冲锋方向
	if player and is_instance_valid(player):
		_charge_direction = global_position.direction_to(player.global_position)
	else:
		_charge_direction = Vector2.RIGHT
	# 提高伤害
	_hitbox.damage = _original_damage * data.charge_damage_mult
	modulate = Color(1.8, 0.2, 0.2, 1.0)

func _process_charging(delta: float) -> void:
	_charge_elapsed += delta
	velocity = _charge_direction * speed * data.charge_speed_mult
	move_and_slide()
	_sprite_animator.update_animation_no_idle(velocity)

	if _charge_elapsed >= _charge_duration:
		_start_stun()

func _start_stun() -> void:
	_charge_state = ChargeState.STUNNED
	_stun_timer = _stun_duration
	velocity = Vector2.ZERO
	# 恢复正常伤害
	_hitbox.damage = _original_damage
	modulate = Color(0.7, 0.7, 0.7, 1.0)

func _process_stunned(delta: float) -> void:
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_charge_state = ChargeState.CHASE
		_charge_timer = data.charge_cooldown
		modulate = Color.WHITE
```

**Step 2: Write test**

```gdscript
# tests/unit/test_boss_brute_charge.gd
extends GutTest

## Boss 蛮兽冲锋行为测试

var boss: CharacterBody2D

func before_each():
	# 创建 boss 实例
	boss = SceneFactory.create_enemy("boss_brute")
	# 创建一个假 player 供 boss 追击
	var player := CharacterBody2D.new()
	player.add_to_group(Enums.Group.PLAYER)
	player.global_position = Vector2(300, 0)
	add_child(player)
	add_child(boss)
	boss.global_position = Vector2(0, 0)

func after_each():
	for child in get_children():
		child.queue_free()

func test_boss_starts_in_chase():
	assert_eq(boss._charge_state, boss.ChargeState.CHASE, "Boss 初始应为追击状态")

func test_windup_starts_after_cooldown():
	# 快速推进冷却
	boss._charge_timer = 0.0
	boss._process_chase(0.1)
	assert_eq(boss._charge_state, boss.ChargeState.WINDUP, "冷却结束后应进入预备状态")

func test_windup_changes_modulate():
	boss._start_windup()
	assert_ne(boss.modulate, Color.WHITE, "预备阶段应改变颜色")

func test_charge_increases_damage():
	var normal_damage: float = boss._hitbox.damage
	boss._start_charge()
	assert_gt(boss._hitbox.damage, normal_damage, "冲锋时伤害应增加")

func test_stun_restores_damage():
	boss._start_charge()
	boss._start_stun()
	assert_eq(boss._hitbox.damage, boss._original_damage, "眩晕后伤害应恢复")

func test_stun_ends_returns_to_chase():
	boss._start_stun()
	boss._process_stunned(1.0)  # 超过眩晕时间
	assert_eq(boss._charge_state, boss.ChargeState.CHASE, "眩晕结束后应回到追击")
	assert_eq(boss.modulate, Color.WHITE, "恢复后颜色应回到白色")

func test_no_charge_when_too_close():
	# 把 player 移到很近的位置
	boss.player.global_position = Vector2(10, 0)
	boss._charge_timer = 0.0
	boss._process_chase(0.1)
	assert_eq(boss._charge_state, boss.ChargeState.CHASE, "距离太近不应触发冲锋")

func test_full_charge_cycle():
	# CHASE → WINDUP → CHARGING → STUNNED → CHASE
	boss._charge_timer = 0.0
	boss._process_chase(0.1)
	assert_eq(boss._charge_state, boss.ChargeState.WINDUP)
	boss._process_windup(1.0)  # 超过 windup time
	assert_eq(boss._charge_state, boss.ChargeState.CHARGING)
	boss._process_charging(1.0)  # 超过 charge duration
	assert_eq(boss._charge_state, boss.ChargeState.STUNNED)
	boss._process_stunned(1.0)  # 超过 stun duration
	assert_eq(boss._charge_state, boss.ChargeState.CHASE)
```

**Step 3: Run test**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_boss_brute_charge.gd -gexit`

**Step 4: Add charge sound effect hooks**

In `boss_brute.gd`, in `_start_windup()`, add:
```gdscript
	AudioManager.play("boss_appear", -3.0)
```

**Step 5: Commit**

```bash
git add scripts/entities/boss_brute.gd tests/unit/test_boss_brute_charge.gd
git commit -m "feat: Boss 蛮兽冲锋状态机（预备→冲刺→眩晕循环）"
```

---

### Task 6: Debug Panel

**Files:**
- Create: `scripts/ui/debug_panel.gd`
- Modify: `scripts/ui/main.gd` (add debug panel)
- Modify: `project.godot` (add debug input actions)

**Step 1: Add debug input actions to project.godot**

In `project.godot` `[input]` section, add actions for F1-F4:

```
debug_toggle={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194332,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
debug_skip_wave={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194333,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
debug_add_coins={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194334,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
debug_godmode={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194335,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

Note: F1=4194332, F2=4194333, F3=4194334, F4=4194335

**Step 2: Create DebugPanel script**

```gdscript
# scripts/ui/debug_panel.gd
extends CanvasLayer

## 调试面板 — F1 显隐，F2 跳波，F3 加钱，F4 无敌

var _label: Label
var _godmode: bool = false

func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_skip_wave"):
		_skip_wave()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_add_coins"):
		GameData.coins += 100
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_godmode"):
		_toggle_godmode()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_info()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(4, 4)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color.GREEN)
	panel.add_child(_label)
	add_child(panel)

func _update_info() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var wave_managers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.WAVE_MANAGER)
	var wave_info: String = "N/A"
	var total_info: String = "N/A"
	if wave_managers.size() > 0:
		var wm: Node = wave_managers[0]
		wave_info = str(wm.current_wave)
		total_info = str(wm.total_waves)

	var player: Node = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	var hp_text: String = "N/A"
	var dmg_text: String = "N/A"
	if player and player.has_node("HealthComponent"):
		hp_text = "%d/%d" % [int(player.health.current_hp), int(player.health.max_hp)]
	dmg_text = "x%.1f" % GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)

	var godmode_text: String = " [GOD]" if _godmode else ""
	_label.text = "Wave: %s/%s | Enemies: %d\nHP: %s | DMG: %s\nCoins: %d | FPS: %d%s" % [
		wave_info, total_info, enemies.size(),
		hp_text, dmg_text,
		GameData.coins, Engine.get_frames_per_second(),
		godmode_text
	]

func _skip_wave() -> void:
	var wave_managers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.WAVE_MANAGER)
	if wave_managers.size() > 0:
		wave_managers[0].complete_wave()

func _toggle_godmode() -> void:
	_godmode = not _godmode
	var player: Node = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if player and player.has_node("HealthComponent"):
		player.health.invincible = _godmode
```

**Step 3: Add invincible flag to HealthComponent**

In `scripts/components/health_component.gd`, add a property:

```gdscript
var invincible: bool = false
```

And in the `take_damage` method, add at the beginning:

```gdscript
	if invincible:
		return
```

**Step 4: Update main.gd to include debug panel**

In `scripts/ui/main.gd`, in `_ready()`, add after the pause overlay:

```gdscript
	# 调试面板
	var debug_panel := load("res://scripts/ui/debug_panel.gd").new()
	add_child(debug_panel)
```

**Step 5: Write test**

```gdscript
# tests/unit/test_debug_panel.gd
extends GutTest

## DebugPanel 单元测试

var panel: CanvasLayer

func before_each():
	panel = load("res://scripts/ui/debug_panel.gd").new()
	add_child(panel)

func after_each():
	panel.queue_free()

func test_starts_hidden():
	assert_false(panel.visible, "调试面板初始应隐藏")

func test_process_mode_always():
	assert_eq(panel.process_mode, Node.PROCESS_MODE_ALWAYS)

func test_add_coins():
	var before: int = GameData.coins
	GameData.coins += 100
	assert_eq(GameData.coins, before + 100)

func test_godmode_toggle():
	assert_false(panel._godmode)
	panel._toggle_godmode()
	assert_true(panel._godmode)
	panel._toggle_godmode()
	assert_false(panel._godmode)
```

**Step 6: Run test**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_debug_panel.gd -gexit`

**Step 7: Commit**

```bash
git add scripts/ui/debug_panel.gd scripts/ui/main.gd scripts/components/health_component.gd tests/unit/test_debug_panel.gd project.godot
git commit -m "feat: 调试面板（F1显隐/F2跳波/F3加钱/F4无敌）"
```

---

### Task 7: Generate real SFX files with jsfxr

**Files:**
- Modify: `assets/sfx/*.wav` (replace placeholders with real generated sounds)

**Step 1: Generate sound effects**

Use jsfxr (https://sfxr.me/) to generate 9 `.wav` files with these characteristics:

| Sound | jsfxr preset suggestion |
|-------|------------------------|
| shoot.wav | Laser/Shoot — short, punchy |
| hit.wav | Hit/Hurt — brief impact |
| enemy_die.wav | Explosion — small pop |
| coin_pickup.wav | Pickup/Coin — bright ding |
| player_hit.wav | Hit/Hurt — heavier thud |
| wave_start.wav | Powerup — ascending tone |
| wave_complete.wav | Powerup — triumphant chord |
| shop_buy.wav | Pickup/Coin — cash register |
| boss_appear.wav | Explosion — deep, ominous |

Each file should be 0.2-0.8 seconds long, 44100 Hz, mono WAV.

Note: This step requires manual action or a jsfxr CLI tool. If generating programmatically is not feasible, use Godot's built-in AudioStreamGenerator to create simple synthetic sounds, or keep the placeholders and add real sounds later.

**Step 2: Verify sounds load**

Run the game and test each sound trigger point.

**Step 3: Commit**

```bash
git add assets/sfx/
git commit -m "feat: 添加 9 个游戏音效（jsfxr 生成）"
```

---

### Task 8: Integration test & full run verification

**Files:**
- No new files; run all existing tests + manual play test

**Step 1: Run full test suite**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

Expected: All tests pass (253+ existing + ~20 new)

**Step 2: Manual play test checklist**

Play through the game and verify:
- [ ] Start menu → Character select → Map select → Battle works
- [ ] Sounds play on shoot, hit, kill, coin pickup
- [ ] Wave start/complete sounds play
- [ ] ESC pauses game (enemies freeze, timer stops)
- [ ] ESC again resumes
- [ ] "返回主菜单" from pause works
- [ ] Boss wave: brute appears with sound
- [ ] Boss does charge attack (flashes red → dashes → stuns)
- [ ] F1 shows debug panel
- [ ] F2 skips wave
- [ ] F3 adds 100 coins
- [ ] F4 toggles godmode (no damage taken)
- [ ] Shop purchase plays sound
- [ ] Result screen accessible after win/loss

**Step 3: Fix any issues found, commit**

```bash
git commit -m "fix: 集成测试修复"
```

**Step 4: Final commit**

```bash
git commit -m "milestone: 可试玩 demo v0.2.0 — 音效/暂停/Boss冲锋/调试面板"
```
