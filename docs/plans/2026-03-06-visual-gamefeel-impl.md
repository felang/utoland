# 视觉与打击感优化 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为游戏添加完整的视觉反馈系统（屏幕震动、击退、闪白、伤害数字、粒子特效）和武器视觉增强，达到土豆兄弟级别的打击感。

**Architecture:** 新增 `scripts/systems/effects_manager.gd` 作为 Autoload 单例，统一管理特效创建（伤害数字、击中火花、死亡爆炸）。屏幕震动挂在玩家 Camera2D 上通过脚本驱动。击退、闪白等效果直接在实体脚本中实现。所有特效参数集中到 `GameConfig` 中配置。

**Tech Stack:** Godot 4.6 GDScript, Tween 动画, GPUParticles2D, Line2D

---

### Task 1: GameConfig 添加特效配置

**Files:**
- Modify: `game_config.gd:7` (添加新的 const 块)

**Step 1: 在 GameConfig 中添加特效配置常量**

在 `game_config.gd` 的 `MAPS` 常量之后添加：

```gdscript
# 特效配置
const EFFECTS = {
	"camera_shake": {
		"player_hit": {"intensity": 3.0, "duration": 0.1},
		"enemy_kill": {"intensity": 2.0, "duration": 0.08},
		"wave_start": {"intensity": 5.0, "duration": 0.2}
	},
	"knockback": {
		"distance": 15.0,
		"duration": 0.1
	},
	"hit_flash": {
		"duration": 0.05,
		"color": Color.WHITE
	},
	"invincible_blink": {
		"interval": 0.08,
		"alpha_low": 0.3,
		"alpha_high": 1.0
	},
	"damage_number": {
		"float_distance": 30.0,
		"random_offset_x": 10.0,
		"duration": 0.6,
		"big_damage_threshold": 30.0,
		"big_damage_scale": 1.3,
		"normal_color": Color.WHITE,
		"big_color": Color.YELLOW
	},
	"death_particles": {
		"count": 10,
		"spread": 20.0,
		"lifetime": 0.3,
		"gravity": 200.0
	},
	"hit_sparks": {
		"count": 5,
		"lifetime": 0.15,
		"spread_speed": 100.0
	},
	"coin_pickup": {
		"shrink_duration": 0.15
	},
	"bullet_trail": {
		"length": 15.0,
		"width": 2.0,
		"color": Color(1, 1, 0, 0.6)
	},
	"boomerang": {
		"rotation_speed": 720.0,
		"trail_points": 6,
		"trail_width": 3.0,
		"trail_color": Color(0.2, 0.8, 1.0, 0.6),
		"return_rotation_mult": 1.5
	},
	"laser": {
		"beam_width": 4.0,
		"core_color": Color(1, 1, 1, 0.9),
		"edge_color": Color(1, 0.2, 0.2, 0.7),
		"flash_alpha": 0.03,
		"flash_duration": 0.05
	}
}
```

**Step 2: 运行测试确认没有破坏现有功能**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: 所有现有测试通过

**Step 3: Commit**

```bash
git add game_config.gd
git commit -m "feat: GameConfig 添加特效配置常量"
```

---

### Task 2: 屏幕震动系统 (CameraShake)

**Files:**
- Create: `scripts/systems/camera_shake.gd`
- Modify: `scripts/entities/player.gd` (在 Camera 节点上附加震动逻辑)
- Test: `tests/unit/test_camera_shake.gd`

**Step 1: 编写 camera_shake.gd 测试**

```gdscript
extends GutTest

# 屏幕震动系统单元测试

var shake_script = preload("res://scripts/systems/camera_shake.gd")

func test_shake_sets_trauma():
	var camera = Camera2D.new()
	camera.set_script(shake_script)
	add_child_autoqfree(camera)
	camera.shake(3.0, 0.1)
	assert_gt(camera._trauma, 0.0, "调用 shake 后 trauma 应大于 0")

func test_shake_takes_max_trauma():
	var camera = Camera2D.new()
	camera.set_script(shake_script)
	add_child_autoqfree(camera)
	camera.shake(2.0, 0.1)
	var first_trauma = camera._trauma
	camera.shake(5.0, 0.2)
	assert_gte(camera._trauma, first_trauma, "多次 shake 应取更大值")

func test_trauma_decays_over_time():
	var camera = Camera2D.new()
	camera.set_script(shake_script)
	add_child_autoqfree(camera)
	camera.shake(5.0, 0.5)
	var initial = camera._trauma
	# 模拟时间流逝
	camera._process(0.1)
	assert_lt(camera._trauma, initial, "trauma 应随时间衰减")
```

**Step 2: 运行测试确认失败**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_camera_shake.gd -gexit`
Expected: FAIL — 脚本不存在

**Step 3: 实现 camera_shake.gd**

```gdscript
extends Camera2D

# 屏幕震动 — 附加到玩家的 Camera2D 节点
# trauma 模型：震动强度随时间衰减，多次震动取最大值

var _trauma: float = 0.0
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_elapsed: float = 0.0

func shake(intensity: float, duration: float) -> void:
	if intensity > _shake_intensity:
		_shake_intensity = intensity
		_shake_duration = duration
		_shake_elapsed = 0.0
	_trauma = maxf(_trauma, intensity)

func _process(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return

	_shake_elapsed += delta
	if _shake_elapsed >= _shake_duration:
		_trauma = 0.0
		_shake_intensity = 0.0
		offset = Vector2.ZERO
		return

	# trauma 线性衰减
	var progress: float = _shake_elapsed / _shake_duration
	var current_intensity: float = _shake_intensity * (1.0 - progress)
	_trauma = current_intensity

	# 随机偏移
	offset = Vector2(
		randf_range(-current_intensity, current_intensity),
		randf_range(-current_intensity, current_intensity)
	)
```

**Step 4: 运行测试确认通过**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_camera_shake.gd -gexit`
Expected: PASS

**Step 5: 将 camera_shake.gd 附加到 player.tscn 的 Camera 节点**

修改 `scenes/player.tscn`，将 Camera 节点的 script 设置为 `camera_shake.gd`：

在 `[node name="Camera" ...]` 行添加 script 引用：
```
[ext_resource type="Script" path="res://scripts/systems/camera_shake.gd" id="2_shake"]

[node name="Camera" type="Camera2D" parent="." unique_id=1630942064]
script = ExtResource("2_shake")
```

**Step 6: 在 player.gd 中触发震动**

在 `player.gd` 的 `take_damage()` 方法中添加震动调用：

```gdscript
func take_damage(amount: float) -> void:
	current_hp -= amount
	# 屏幕震动
	var camera: Camera2D = $Camera
	if camera and camera.has_method("shake"):
		var shake_config: Dictionary = GameConfig.EFFECTS["camera_shake"]["player_hit"]
		camera.shake(shake_config["intensity"], shake_config["duration"])
	print("Player HP: ", current_hp)
	if current_hp <= 0:
		die()
```

**Step 7: Commit**

```bash
git add scripts/systems/camera_shake.gd tests/unit/test_camera_shake.gd scenes/player.tscn scripts/entities/player.gd
git commit -m "feat: 屏幕震动系统 — 玩家受击时触发相机抖动"
```

---

### Task 3: 击退系统 (Knockback)

**Files:**
- Modify: `scripts/entities/enemy.gd` (添加 `apply_knockback()` 方法)
- Modify: `scripts/entities/bullet.gd` (击中时触发击退)
- Modify: `scripts/entities/boomerang.gd` (击中时触发击退)
- Modify: `scripts/entities/player.gd` (激光击中时触发击退)
- Test: `tests/unit/test_knockback.gd`

**Step 1: 编写击退测试**

```gdscript
extends GutTest

# 击退系统单元测试

func test_enemy_has_knockback_method():
	var enemy = SceneFactory.create_enemy("normal")
	add_child_autoqfree(enemy)
	assert_true(enemy.has_method("apply_knockback"), "敌人应有 apply_knockback 方法")

func test_knockback_changes_position():
	var enemy = SceneFactory.create_enemy("normal")
	add_child_autoqfree(enemy)
	await get_tree().process_frame
	var original_pos: Vector2 = enemy.global_position
	var knockback_dir: Vector2 = Vector2.RIGHT
	enemy.apply_knockback(knockback_dir)
	# 击退通过 Tween 异步执行，等一帧后检查
	await get_tree().create_timer(0.15).timeout
	assert_ne(enemy.global_position, original_pos, "击退后位置应改变")

func test_enemy_still_takes_damage_during_knockback():
	var enemy = SceneFactory.create_enemy("normal")
	add_child_autoqfree(enemy)
	await get_tree().process_frame
	enemy.apply_knockback(Vector2.RIGHT)
	var hp_before: float = enemy.current_hp
	enemy.take_damage(10.0)
	assert_lt(enemy.current_hp, hp_before, "击退期间仍应可以受伤")
```

**Step 2: 运行测试确认失败**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_knockback.gd -gexit`
Expected: FAIL

**Step 3: 在 enemy.gd 中实现击退**

在 `enemy.gd` 的 `drop_coins()` 函数之后添加：

```gdscript
func apply_knockback(direction: Vector2) -> void:
	var config: Dictionary = GameConfig.EFFECTS["knockback"]
	var tween: Tween = create_tween()
	var target_pos: Vector2 = global_position + direction * config["distance"]
	tween.tween_property(self, "global_position", target_pos, config["duration"]).set_ease(Tween.EASE_OUT)
```

**Step 4: 运行测试确认通过**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_knockback.gd -gexit`
Expected: PASS

**Step 5: 在 bullet.gd 中触发击退**

修改 `bullet.gd` 的 `_on_body_entered`：

```gdscript
func _on_body_entered(body):
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(direction)
		queue_free()
```

**Step 6: 在 boomerang.gd 中触发击退**

修改 `boomerang.gd` 的 `_on_body_entered`：

```gdscript
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	if not body.has_method("take_damage"):
		return
	var knockback_dir: Vector2 = global_position.direction_to(body.global_position)
	match _state:
		"OUTBOUND":
			if body not in _hit_outbound:
				_hit_outbound.append(body)
				body.take_damage(damage)
				if body.has_method("apply_knockback"):
					body.apply_knockback(knockback_dir)
		"RETURNING":
			if body not in _hit_returning:
				_hit_returning.append(body)
				body.take_damage(damage)
				if body.has_method("apply_knockback"):
					body.apply_knockback(knockback_dir)
```

**Step 7: 在 player.gd 激光命中处触发击退**

修改 `player.gd` 的 `_shoot_laser` 方法，在 `collider.take_damage(weapon_damage)` 后添加：

```gdscript
		if collider.is_in_group("enemies") and collider not in hit_enemies:
			hit_enemies.append(collider)
			if collider.has_method("take_damage"):
				collider.take_damage(weapon_damage)
			if collider.has_method("apply_knockback"):
				collider.apply_knockback(direction)
```

**Step 8: Commit**

```bash
git add scripts/entities/enemy.gd scripts/entities/bullet.gd scripts/entities/boomerang.gd scripts/entities/player.gd tests/unit/test_knockback.gd
git commit -m "feat: 击退系统 — 敌人受击时产生方向性击退效果"
```

---

### Task 4: 受击闪白 + 无敌帧闪烁

**Files:**
- Modify: `scripts/entities/enemy.gd` (受击闪白)
- Modify: `scripts/entities/player.gd` (受击闪白 + 无敌帧闪烁)
- Test: `tests/unit/test_hit_flash.gd`

**Step 1: 编写测试**

```gdscript
extends GutTest

# 受击闪白和无敌帧闪烁测试

func test_enemy_flash_on_damage():
	var enemy = SceneFactory.create_enemy("normal")
	add_child_autoqfree(enemy)
	await get_tree().process_frame
	enemy.take_damage(5.0)
	# 闪白后 modulate 应瞬间变白
	assert_eq(enemy.modulate, Color.WHITE, "受击瞬间 modulate 应为白色（闪白后会恢复）")
	# 注意：由于闪白极短(0.05s)，这里测试的是调用后的状态

func test_player_blink_during_invincibility():
	# 只测试无敌状态标志，闪烁视觉效果难以在单元测试中验证
	var player_scene = preload("res://scenes/player.tscn")
	var player = player_scene.instantiate()
	add_child_autoqfree(player)
	await get_tree().process_frame
	player.take_damage(10.0)
	assert_gt(player.invincible_timer, 0.0, "受击后应进入无敌状态")
```

**Step 2: 运行测试确认失败**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_hit_flash.gd -gexit`
Expected: FAIL

**Step 3: 在 enemy.gd 的 take_damage 中添加闪白**

```gdscript
func take_damage(amount: float):
	current_hp -= amount
	_flash_white()
	if current_hp <= 0:
		die()

func _flash_white() -> void:
	var config: Dictionary = GameConfig.EFFECTS["hit_flash"]
	modulate = config["color"]
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, config["duration"])
```

注意：enemy 的默认 modulate 就是 Color.WHITE（不影响 ColorRect 颜色），闪白时先设置为纯白（覆盖子节点颜色），再恢复。实际上对于 ColorRect，需要先将 modulate 设置为一个更亮的值。改为：

```gdscript
func _flash_white() -> void:
	var config: Dictionary = GameConfig.EFFECTS["hit_flash"]
	var original_modulate: Color = modulate
	modulate = Color(2, 2, 2, 1)  # 超亮白色让 ColorRect 变白
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", original_modulate, config["duration"])
```

**Step 4: 在 player.gd 中添加无敌帧闪烁**

修改 `player.gd` 的 `take_damage()` 和 `_process()`：

在 `take_damage()` 中添加闪白和开始闪烁：
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
	# 开始无敌帧闪烁
	_start_invincible_blink()
	print("Player HP: ", current_hp)
	if current_hp <= 0:
		die()

func _flash_white() -> void:
	var original_modulate: Color = modulate
	modulate = Color(2, 2, 2, 1)
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", original_modulate, GameConfig.EFFECTS["hit_flash"]["duration"])

var _blink_tween: Tween = null

func _start_invincible_blink() -> void:
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	var config: Dictionary = GameConfig.EFFECTS["invincible_blink"]
	var blink_count: int = int(invincible_duration / (config["interval"] * 2))
	_blink_tween = create_tween()
	for i in blink_count:
		_blink_tween.tween_property(self, "modulate:a", config["alpha_low"], config["interval"])
		_blink_tween.tween_property(self, "modulate:a", config["alpha_high"], config["interval"])
	_blink_tween.tween_property(self, "modulate:a", 1.0, 0.01)  # 确保恢复
```

**Step 5: 运行测试确认通过**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_hit_flash.gd -gexit`
Expected: PASS

**Step 6: 运行全部测试确认无回归**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: 所有测试通过

**Step 7: Commit**

```bash
git add scripts/entities/enemy.gd scripts/entities/player.gd tests/unit/test_hit_flash.gd
git commit -m "feat: 受击闪白和无敌帧闪烁视觉反馈"
```

---

### Task 5: EffectsManager 单例 + 伤害数字

**Files:**
- Create: `scripts/systems/effects_manager.gd`
- Modify: `project.godot` (注册 autoload)
- Modify: `scripts/entities/enemy.gd` (受击时调用 EffectsManager)
- Test: `tests/unit/test_effects_manager.gd`

**Step 1: 编写测试**

```gdscript
extends GutTest

# EffectsManager 单元测试

func test_effects_manager_exists():
	assert_not_null(EffectsManager, "EffectsManager autoload 应存在")

func test_spawn_damage_number():
	EffectsManager.spawn_damage_number(Vector2(100, 100), 25.0)
	await get_tree().process_frame
	# 伤害数字是 Label 节点，检查是否创建成功
	var labels = get_tree().get_nodes_in_group("damage_numbers")
	assert_gt(labels.size(), 0, "应至少有一个伤害数字")

func test_big_damage_number_is_yellow():
	EffectsManager.spawn_damage_number(Vector2(100, 100), 50.0)  # 大于阈值 30
	await get_tree().process_frame
	var labels = get_tree().get_nodes_in_group("damage_numbers")
	if labels.size() > 0:
		var label: Label = labels[-1]
		var big_color: Color = GameConfig.EFFECTS["damage_number"]["big_color"]
		assert_eq(label.modulate, big_color, "大伤害数字应为黄色")
```

**Step 2: 运行测试确认失败**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_effects_manager.gd -gexit`
Expected: FAIL

**Step 3: 实现 effects_manager.gd**

```gdscript
extends Node

# 特效管理器 — 统一管理伤害数字、击中火花、死亡爆炸等视觉特效
# 作为 Autoload 单例全局可用

func spawn_damage_number(pos: Vector2, damage: float) -> void:
	var config: Dictionary = GameConfig.EFFECTS["damage_number"]
	var label: Label = Label.new()
	label.text = str(int(damage))
	label.add_to_group("damage_numbers")
	label.global_position = pos
	label.z_index = 100  # 确保在最上层
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 大伤害特殊样式
	var is_big: bool = damage >= config["big_damage_threshold"]
	if is_big:
		label.modulate = config["big_color"]
		label.scale = Vector2(config["big_damage_scale"], config["big_damage_scale"])
	else:
		label.modulate = config["normal_color"]

	# 添加到场景树
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(label)
	else:
		add_child(label)

	# 动画：上浮 + 随机横向偏移 + 淡出
	var offset_x: float = randf_range(-config["random_offset_x"], config["random_offset_x"])
	var target_pos: Vector2 = pos + Vector2(offset_x, -config["float_distance"])
	var duration: float = config["duration"]

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", target_pos, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func spawn_hit_sparks(pos: Vector2, color: Color = Color.YELLOW) -> void:
	var config: Dictionary = GameConfig.EFFECTS["hit_sparks"]
	for i in config["count"]:
		var spark: ColorRect = ColorRect.new()
		spark.size = Vector2(2, 2)
		spark.position = pos - Vector2(1, 1)
		spark.color = color
		spark.z_index = 50

		var tree: SceneTree = get_tree()
		if tree and tree.current_scene:
			tree.current_scene.add_child(spark)
		else:
			add_child(spark)

		# 随机方向扩散
		var angle: float = randf() * TAU
		var spread_dir: Vector2 = Vector2.from_angle(angle)
		var target: Vector2 = pos + spread_dir * config["spread_speed"] * config["lifetime"]

		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", target - Vector2(1, 1), config["lifetime"])
		tween.tween_property(spark, "modulate:a", 0.0, config["lifetime"])
		tween.set_parallel(false)
		tween.tween_callback(spark.queue_free)

func spawn_death_effect(pos: Vector2, entity_color: Color) -> void:
	var config: Dictionary = GameConfig.EFFECTS["death_particles"]
	for i in config["count"]:
		var particle: ColorRect = ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.position = pos - Vector2(1.5, 1.5)
		particle.color = entity_color
		particle.z_index = 50

		var tree: SceneTree = get_tree()
		if tree and tree.current_scene:
			tree.current_scene.add_child(particle)
		else:
			add_child(particle)

		# 随机方向 + 重力效果
		var angle: float = randf() * TAU
		var speed: float = randf_range(50.0, config["spread_speed"] if config.has("spread_speed") else 120.0)
		var spread_dir: Vector2 = Vector2.from_angle(angle)
		var target: Vector2 = pos + spread_dir * speed * config["lifetime"]
		target.y += config["gravity"] * config["lifetime"] * config["lifetime"] * 0.5  # 重力

		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target - Vector2(1.5, 1.5), config["lifetime"]).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, config["lifetime"] * 0.5).set_delay(config["lifetime"] * 0.5)
		tween.set_parallel(false)
		tween.tween_callback(particle.queue_free)
```

**Step 4: 注册 EffectsManager 为 Autoload**

在 `project.godot` 的 `[autoload]` 段添加：
```
EffectsManager="*res://scripts/systems/effects_manager.gd"
```

**Step 5: 在 enemy.gd 中触发伤害数字和死亡特效**

修改 `enemy.gd` 的 `take_damage()` 和 `die()`：

```gdscript
func take_damage(amount: float):
	current_hp -= amount
	_flash_white()
	# 伤害数字
	EffectsManager.spawn_damage_number(global_position + Vector2(0, -20), amount)
	# 击中火花
	EffectsManager.spawn_hit_sparks(global_position)
	if current_hp <= 0:
		die()

func die():
	# 死亡爆炸特效
	var visual: ColorRect = $Visual
	var death_color: Color = visual.color if visual else Color.RED
	EffectsManager.spawn_death_effect(global_position, death_color)
	# 屏幕震动（通过玩家的 Camera）
	var player_node: Node2D = get_tree().get_first_node_in_group("player")
	if player_node:
		var camera: Camera2D = player_node.get_node_or_null("Camera")
		if camera and camera.has_method("shake"):
			var shake_config: Dictionary = GameConfig.EFFECTS["camera_shake"]["enemy_kill"]
			camera.shake(shake_config["intensity"], shake_config["duration"])
	drop_coins()
	queue_free()
```

**Step 6: 运行测试确认通过**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_effects_manager.gd -gexit`
Expected: PASS

**Step 7: 运行全部测试**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: 所有通过

**Step 8: Commit**

```bash
git add scripts/systems/effects_manager.gd tests/unit/test_effects_manager.gd project.godot scripts/entities/enemy.gd
git commit -m "feat: EffectsManager 单例 — 伤害数字、击中火花、死亡爆炸特效"
```

---

### Task 6: 金币拾取特效

**Files:**
- Modify: `scripts/entities/coin.gd` (拾取时缩小淡出)

**Step 1: 修改 coin.gd 的 _on_body_entered**

```gdscript
func _on_body_entered(body):
	if body.is_in_group("player"):
		body.add_coins(value)
		_play_pickup_effect()

func _play_pickup_effect() -> void:
	# 禁用碰撞，防止重复拾取
	set_deferred("monitoring", false)
	var config: Dictionary = GameConfig.EFFECTS["coin_pickup"]
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), config["shrink_duration"])
	tween.tween_property(self, "modulate:a", 0.0, config["shrink_duration"])
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
```

**Step 2: 运行全部测试确认无回归**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 所有通过

**Step 3: Commit**

```bash
git add scripts/entities/coin.gd
git commit -m "feat: 金币拾取缩小淡出特效"
```

---

### Task 7: 波次开始震动

**Files:**
- Modify: `scripts/systems/wave_manager.gd` (波次开始时触发震动)

**Step 1: 修改 wave_manager.gd 的 start_next_wave**

在 `wave_started.emit(current_wave)` 之后添加：

```gdscript
	# 波次开始屏幕震动
	var player_node: Node2D = get_tree().get_first_node_in_group("player")
	if player_node:
		var camera: Camera2D = player_node.get_node_or_null("Camera")
		if camera and camera.has_method("shake"):
			var shake_config: Dictionary = GameConfig.EFFECTS["camera_shake"]["wave_start"]
			camera.shake(shake_config["intensity"], shake_config["duration"])
```

**Step 2: 运行全部测试**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 所有通过

**Step 3: Commit**

```bash
git add scripts/systems/wave_manager.gd
git commit -m "feat: 波次开始屏幕震动反馈"
```

---

### Task 8: 子弹拖尾效果

**Files:**
- Modify: `scripts/entities/bullet.gd` (添加 Line2D 拖尾)

**Step 1: 在 bullet.gd 中添加拖尾**

```gdscript
extends Area2D

var speed: float = 400.0
var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var lifetime: float = 5.0
var elapsed: float = 0.0

var _trail: Line2D = null
var _trail_positions: Array[Vector2] = []
const TRAIL_MAX_POINTS: int = 4

func _ready():
	body_entered.connect(_on_body_entered)
	# 创建拖尾 Line2D
	var config: Dictionary = GameConfig.EFFECTS["bullet_trail"]
	_trail = Line2D.new()
	_trail.width = config["width"]
	_trail.default_color = config["color"]
	_trail.z_index = -1
	# 拖尾需要在世界坐标系中，不随子弹旋转
	_trail.top_level = true
	add_child(_trail)

func _physics_process(delta):
	global_position += direction * speed * delta
	elapsed += delta
	# 更新拖尾
	_update_trail()
	if elapsed >= lifetime:
		queue_free()

func _update_trail() -> void:
	_trail_positions.insert(0, global_position)
	if _trail_positions.size() > TRAIL_MAX_POINTS:
		_trail_positions.resize(TRAIL_MAX_POINTS)
	_trail.clear_points()
	for pos in _trail_positions:
		_trail.add_point(pos)

func _on_body_entered(body):
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(direction)
		queue_free()
```

**Step 2: 运行全部测试**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 所有通过

**Step 3: Commit**

```bash
git add scripts/entities/bullet.gd
git commit -m "feat: 子弹拖尾效果 — Line2D 黄色渐变拖尾"
```

---

### Task 9: 回旋镖旋转 + 拖尾

**Files:**
- Modify: `scripts/entities/boomerang.gd` (添加旋转动画和 Line2D 拖尾)

**Step 1: 修改 boomerang.gd**

在 `_ready()` 中添加拖尾初始化，在 `_physics_process()` 中添加旋转和拖尾更新：

```gdscript
extends Area2D

# ... 现有变量保持不变 ...

var _trail: Line2D = null
var _trail_positions: Array[Vector2] = []

func _ready() -> void:
	var config: Dictionary = GameConfig.WEAPONS["boomerang"]
	speed = config["speed"]
	outbound_distance = config["outbound_distance"]
	return_speed_mult = config["return_speed_mult"]
	body_entered.connect(_on_body_entered)
	# 创建拖尾
	var fx_config: Dictionary = GameConfig.EFFECTS["boomerang"]
	_trail = Line2D.new()
	_trail.width = fx_config["trail_width"]
	_trail.default_color = fx_config["trail_color"]
	_trail.top_level = true
	_trail.z_index = -1
	add_child(_trail)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= max_lifetime:
		queue_free()
		return
	# 旋转
	var fx_config: Dictionary = GameConfig.EFFECTS["boomerang"]
	var rot_speed: float = deg_to_rad(fx_config["rotation_speed"])
	if _state == "RETURNING":
		rot_speed *= fx_config["return_rotation_mult"]
	rotation += rot_speed * delta
	# 拖尾
	_update_trail(fx_config["trail_points"])

	match _state:
		"OUTBOUND":
			_process_outbound(delta)
		"RETURNING":
			_process_returning(delta)

func _update_trail(max_points: int) -> void:
	_trail_positions.insert(0, global_position)
	if _trail_positions.size() > max_points:
		_trail_positions.resize(max_points)
	_trail.clear_points()
	for pos in _trail_positions:
		_trail.add_point(pos)

# ... _process_outbound, _process_returning, _on_body_entered 保持不变 ...
```

**Step 2: 运行测试**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 所有通过

**Step 3: Commit**

```bash
git add scripts/entities/boomerang.gd
git commit -m "feat: 回旋镖旋转动画 + 拖尾效果"
```

---

### Task 10: 激光视觉增强

**Files:**
- Modify: `scripts/entities/laser_beam.gd` (加粗、渐变、击中闪光)
- Modify: `scripts/entities/player.gd` (激光发射频闪)

**Step 1: 修改 laser_beam.gd**

```gdscript
extends Node2D

# 激光视觉效果 — Line2D 加粗 + 边缘渐变 + 淡出

var beam_duration: float = 0.08

@onready var line: Line2D = $Line2D

func _ready() -> void:
	beam_duration = GameConfig.WEAPONS["laser"]["beam_duration"]
	# 应用特效配置
	var fx_config: Dictionary = GameConfig.EFFECTS["laser"]
	line.width = fx_config["beam_width"]
	# 渐变：边缘红 → 中心白 → 边缘红
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, fx_config["edge_color"])
	gradient.add_point(0.5, fx_config["core_color"])
	gradient.set_color(gradient.get_point_count() - 1, fx_config["edge_color"])
	line.gradient = gradient

func fire(from: Vector2, to: Vector2) -> void:
	global_position = Vector2.ZERO
	line.clear_points()
	line.add_point(from)
	line.add_point(to)

	# 击中点闪光
	EffectsManager.spawn_hit_sparks(to, Color(1, 0.3, 0.3))

	var tween: Tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, beam_duration)
	tween.tween_callback(queue_free)
```

**Step 2: 在 player.gd 的 _shoot_laser 末尾添加全屏频闪**

在 `beam.fire(global_position, end_pos)` 之后添加：

```gdscript
		# 全屏红色频闪
		var flash_config: Dictionary = GameConfig.EFFECTS["laser"]
		var flash: ColorRect = ColorRect.new()
		flash.color = Color(1, 0, 0, flash_config["flash_alpha"])
		flash.size = Vector2(2000, 2000)
		flash.position = Vector2(-1000, -1000)
		flash.z_index = 90
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(flash)
		var flash_tween: Tween = create_tween()
		flash_tween.tween_property(flash, "modulate:a", 0.0, flash_config["flash_duration"])
		flash_tween.tween_callback(flash.queue_free)
```

**Step 3: 运行测试**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 所有通过

**Step 4: Commit**

```bash
git add scripts/entities/laser_beam.gd scripts/entities/player.gd
git commit -m "feat: 激光视觉增强 — 加粗渐变光束 + 击中闪光 + 频闪效果"
```

---

### Task 11: 枪口闪光效果

**Files:**
- Modify: `scripts/entities/player.gd` (_shoot_bullet 添加枪口闪光)

**Step 1: 在 player.gd 中添加枪口闪光辅助方法**

```gdscript
func _spawn_muzzle_flash(pos: Vector2) -> void:
	var flash: ColorRect = ColorRect.new()
	flash.size = Vector2(6, 6)
	flash.position = pos - Vector2(3, 3)
	flash.color = Color(1, 1, 0.8, 0.9)
	flash.z_index = 10
	var parent: Node = get_parent()
	if parent:
		parent.add_child(flash)
		var tween: Tween = create_tween()
		tween.tween_property(flash, "scale", Vector2(0.1, 0.1), 0.05).set_ease(Tween.EASE_OUT)
		tween.tween_callback(flash.queue_free)
```

**Step 2: 在 _shoot_bullet 中调用**

在 `parent.add_child(bullet)` 之后添加：
```gdscript
		_spawn_muzzle_flash(global_position)
```

**Step 3: 运行测试**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 所有通过

**Step 4: Commit**

```bash
git add scripts/entities/player.gd
git commit -m "feat: 步枪枪口闪光效果"
```

---

### Task 12: 塔受击和死亡反馈

**Files:**
- Modify: `scripts/entities/towers/tower.gd` (受击闪白 + 死亡特效)

**Step 1: 修改 tower.gd 的 take_damage**

```gdscript
func take_damage(amount: float):
	current_hp -= amount
	# 受击闪白
	var original_modulate: Color = modulate
	modulate = Color(2, 2, 2, 1)
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", original_modulate, GameConfig.EFFECTS["hit_flash"]["duration"])
	# 伤害数字
	EffectsManager.spawn_damage_number(global_position + Vector2(0, -20), amount)
	if current_hp <= 0:
		# 死亡特效
		EffectsManager.spawn_death_effect(global_position, Color.GREEN)
		queue_free()
```

**Step 2: 运行测试**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 所有通过

**Step 3: Commit**

```bash
git add scripts/entities/towers/tower.gd
git commit -m "feat: 塔受击闪白和死亡爆炸特效"
```

---

### Task 13: 子弹击中时触发击中火花

**Files:**
- Modify: `scripts/entities/bullet.gd` (击中时生成火花)

**Step 1: 修改 bullet.gd 的 _on_body_entered**

```gdscript
func _on_body_entered(body):
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(direction)
		# 击中火花
		EffectsManager.spawn_hit_sparks(global_position)
		queue_free()
```

**Step 2: 运行测试**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 所有通过

**Step 3: Commit**

```bash
git add scripts/entities/bullet.gd
git commit -m "feat: 子弹击中时生成击中火花特效"
```

---

### Task 14: 最终集成测试 + 手动验收

**Files:**
- Test: `tests/integration/test_visual_effects.gd`

**Step 1: 编写集成测试**

```gdscript
extends GutTest

# 视觉效果集成测试

func test_enemy_death_triggers_effects():
	var enemy = SceneFactory.create_enemy("normal")
	add_child_autoqfree(enemy)
	await get_tree().process_frame
	# 对敌人造成致命伤害
	enemy.take_damage(999.0)
	await get_tree().process_frame
	# 检查伤害数字已生成
	var labels = get_tree().get_nodes_in_group("damage_numbers")
	assert_gt(labels.size(), 0, "敌人受击后应生成伤害数字")

func test_bullet_creates_trail():
	var bullet = SceneFactory.create_bullet()
	bullet.direction = Vector2.RIGHT
	add_child_autoqfree(bullet)
	await get_tree().process_frame
	# 检查子弹有 Line2D 子节点（拖尾）
	var has_trail: bool = false
	for child in bullet.get_children():
		if child is Line2D:
			has_trail = true
			break
	assert_true(has_trail, "子弹应有 Line2D 拖尾子节点")

func test_boomerang_rotates():
	var boomerang = SceneFactory.create_boomerang()
	boomerang.direction = Vector2.RIGHT
	add_child_autoqfree(boomerang)
	var initial_rotation: float = boomerang.rotation
	await get_tree().create_timer(0.1).timeout
	assert_ne(boomerang.rotation, initial_rotation, "回旋镖应持续旋转")
```

**Step 2: 运行集成测试**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_visual_effects.gd -gexit`
Expected: PASS

**Step 3: 运行全部测试确认无回归**

Run: `cd /Users/langtao/utoland && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 所有测试通过

**Step 4: 手动运行游戏验收**

Run: 通过 Godot 编辑器运行，检查以下效果：
- [ ] 玩家受击：屏幕震动 + 闪白 + 无敌帧闪烁
- [ ] 敌人受击：闪白 + 击退 + 伤害数字 + 击中火花
- [ ] 敌人死亡：爆炸粒子 + 屏幕轻震
- [ ] 金币拾取：缩小淡出
- [ ] 子弹：拖尾效果
- [ ] 回旋镖：旋转 + 拖尾
- [ ] 激光：加粗渐变 + 击中闪光 + 频闪
- [ ] 步枪：枪口闪光
- [ ] 塔受击：闪白 + 伤害数字
- [ ] 波次开始：大屏幕震动

**Step 5: Commit**

```bash
git add tests/integration/test_visual_effects.gd
git commit -m "test: 视觉效果集成测试"
```

---

### Task 15: 像素风精灵图替换准备（代码框架）

> 注意：此任务搭建替换精灵图的代码框架。实际精灵图素材需要用户手动下载放入 `assets/sprites/` 目录后，再执行替换。

**Files:**
- Create: `assets/sprites/` 目录结构
- Modify: `game_config.gd` (添加精灵图路径配置)

**Step 1: 创建精灵图目录结构**

```bash
mkdir -p assets/sprites/player
mkdir -p assets/sprites/enemies
mkdir -p assets/sprites/towers
mkdir -p assets/sprites/projectiles
mkdir -p assets/sprites/items
```

**Step 2: 在 GameConfig 添加精灵图路径配置**

在 `game_config.gd` 的 `EFFECTS` 之后添加：

```gdscript
# 精灵图配置 — 待素材到位后取消注释并替换场景中的 ColorRect
const SPRITES = {
	"player": {
		"warrior": "res://assets/sprites/player/warrior.png",
		"ranger": "res://assets/sprites/player/ranger.png",
		"tank": "res://assets/sprites/player/tank.png"
	},
	"enemies": {
		"normal": "res://assets/sprites/enemies/normal.png",
		"fast": "res://assets/sprites/enemies/fast.png",
		"tank": "res://assets/sprites/enemies/tank.png"
	},
	"towers": {
		"shooter": "res://assets/sprites/towers/shooter.png",
		"wall": "res://assets/sprites/towers/wall.png",
		"slow": "res://assets/sprites/towers/slow.png"
	},
	"projectiles": {
		"bullet": "res://assets/sprites/projectiles/bullet.png",
		"boomerang": "res://assets/sprites/projectiles/boomerang.png"
	},
	"items": {
		"coin": "res://assets/sprites/items/coin.png"
	}
}
```

**Step 3: 在 assets/sprites/ 下创建 README 说明素材规格**

创建 `assets/sprites/README.md`：
```
# 精灵图规格

- 标准实体 (玩家/敌人/塔): 16x16 像素
- 大型实体 (坦克敌人): 24x24 像素
- 小型实体 (子弹/金币): 8x8 像素
- 导入设置: Filter = OFF (保持像素锐利)
- 推荐调色板: PICO-8 16色

## 素材来源推荐
- itch.io 搜索 "pixel art roguelike characters"
- itch.io 搜索 "pixel art top-down enemies"
```

**Step 4: Commit**

```bash
git add assets/sprites/ game_config.gd
git commit -m "chore: 像素风精灵图目录结构和路径配置框架"
```

---

## 阶段总结

| 阶段 | Tasks | 核心产出 |
|------|-------|----------|
| 一：游戏手感基础 | 1-4, 7 | 屏幕震动、击退、闪白、无敌帧闪烁 |
| 二：视觉反馈层 | 5-6, 12-13 | 伤害数字、死亡爆炸、金币拾取、击中火花 |
| 三：武器视觉增强 | 8-11 | 子弹拖尾、回旋镖旋转拖尾、激光增强、枪口闪光 |
| 四：像素风准备 | 15 | 目录结构和配置框架，等待素材 |
| 验收 | 14 | 集成测试 + 手动验收 |
