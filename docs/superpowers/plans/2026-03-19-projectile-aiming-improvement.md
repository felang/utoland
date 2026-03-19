# 投射物瞄准改进 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 塔投射物改为追踪目标保证命中，武器投射物改为预判提前量提高命中率，shuriken 弹射改为追踪。

**Architecture:** 新增 `TrackingMovementComponent` 组件替代塔投射物的 `LinearMovementComponent`。在 `RangedAttackComponent` 中加预判瞄准逻辑。`BounceOnHitComponent` 内置弹射追踪。`Projectile` 基座加可选 `target` 引用，通过 `SceneFactory` 传递。

**Tech Stack:** Godot 4.6 GDScript, GUT 测试框架

---

## Chunk 1: 基础设施（Projectile + SceneFactory 接口扩展）

### Task 1: Projectile 基座加 target 属性

**Files:**
- Modify: `scripts/entities/projectiles/projectile.gd:4-8` (新增 target 变量)
- Modify: `scripts/entities/projectiles/projectile.gd:10` (setup 签名)
- Modify: `scripts/entities/projectiles/projectile.gd:61-69` (reset_for_pool)
- Test: `tests/unit/test_projectile_new.gd`

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_projectile_new.gd` 末尾追加：

```gdscript
func test_setup_stores_target() -> void:
	var proj := Projectile.new()
	add_child(proj)
	var target := Node2D.new()
	add_child(target)
	proj.data = ProjectileData.new()
	proj.setup(proj.data, 10.0, Vector2.ZERO, Vector2.RIGHT, target)
	assert_eq(proj.target, target)
	target.queue_free()
	proj.queue_free()

func test_setup_without_target_defaults_null() -> void:
	var proj := Projectile.new()
	add_child(proj)
	proj.data = ProjectileData.new()
	proj.setup(proj.data, 10.0, Vector2.ZERO, Vector2.RIGHT)
	assert_null(proj.target)
	proj.queue_free()

func test_reset_for_pool_clears_target() -> void:
	var proj := Projectile.new()
	add_child(proj)
	var t := Node2D.new()
	proj.target = t
	proj.reset_for_pool()
	assert_null(proj.target)
	t.free()
	proj.queue_free()
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_projectile_new.gd -gexit`
Expected: FAIL（setup 签名不匹配）

- [ ] **Step 3: 修改 projectile.gd**

在 `scripts/entities/projectiles/projectile.gd` 中：

1. 第 7 行后新增：
```gdscript
var target: Node2D = null
```

2. 修改 `setup()` 签名（第 10 行）：
```gdscript
func setup(p_data: ProjectileData, dmg: float, from: Vector2, dir: Vector2, p_target: Node2D = null) -> void:
	target = p_target
	data = p_data
	# ... 其余不变
```

3. 在 `reset_for_pool()` 首行加：
```gdscript
func reset_for_pool() -> void:
	target = null
	_should_destroy = false
	# ... 其余不变
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_projectile_new.gd -gexit`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/entities/projectiles/projectile.gd tests/unit/test_projectile_new.gd
git commit -m "feat: Projectile 基座新增 target 属性支持追踪"
```

### Task 2: SceneFactory.create_projectile 加 target 参数

**Files:**
- Modify: `scripts/core/scene_factory.gd:138-146`

- [ ] **Step 1: 修改 create_projectile 签名**

在 `scripts/core/scene_factory.gd` 第 138 行：

```gdscript
func create_projectile(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2, target: Node2D = null) -> Node2D:
	assert(p_data != null, "SceneFactory.create_projectile: data 不能为 null")
	assert(p_data.projectile_scene != null, "SceneFactory.create_projectile: projectile_scene 未配置")
	var key: String = _get_projectile_pool_key(p_data)
	if not _pools.has(key):
		_register_pool(key, p_data.projectile_scene)
	var proj: Node2D = _pool_acquire(key) as Node2D
	proj.setup(p_data, damage, from, direction, target)
	return proj
```

- [ ] **Step 2: 运行全量测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部 PASS（可选参数向后兼容）

- [ ] **Step 3: 提交**

```bash
git add scripts/core/scene_factory.gd
git commit -m "feat: SceneFactory.create_projectile 新增可选 target 参数"
```

## Chunk 2: TrackingMovementComponent（追踪移动组件）

### Task 3: 创建 TrackingMovementComponent

**Files:**
- Create: `scripts/components/tracking_movement_component.gd`
- Test: `tests/unit/test_tracking_movement_component.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/unit/test_tracking_movement_component.gd`：

```gdscript
extends GutTest

func test_on_projectile_setup_reads_data() -> void:
	var comp := TrackingMovementComponent.new()
	add_child(comp)
	var proj := Node2D.new()
	proj.set_script(load("res://scripts/entities/projectiles/projectile.gd"))
	add_child(proj)
	var data := ProjectileData.new()
	data.speed = 500.0
	data.lifetime = 3.0
	proj.data = data
	var target := Node2D.new()
	add_child(target)
	proj.target = target
	comp.on_projectile_setup(proj)
	assert_eq(comp.speed, 500.0)
	assert_eq(comp.lifetime, 3.0)
	assert_eq(comp._target, target)
	target.queue_free()
	proj.queue_free()
	comp.queue_free()

func test_tracking_adjusts_direction() -> void:
	var comp := TrackingMovementComponent.new()
	comp.turn_speed = 20.0  # 高转向速度，确保一帧内能明显转向
	var proj := Node2D.new()
	proj.set_script(load("res://scripts/entities/projectiles/projectile.gd"))
	add_child(proj)
	proj.global_position = Vector2.ZERO
	proj.direction = Vector2.RIGHT
	var data := ProjectileData.new()
	data.speed = 100.0
	data.lifetime = 5.0
	proj.data = data
	var target := Node2D.new()
	add_child(target)
	target.global_position = Vector2(0, 100)  # 目标在正下方
	proj.target = target
	proj.add_child(comp)
	comp.on_projectile_setup(proj)
	# 模拟一帧物理
	comp._physics_process(0.1)
	# direction 应该从 RIGHT 朝 DOWN 偏转
	assert_gt(proj.direction.y, 0.0, "方向应该朝目标偏转")
	target.queue_free()
	proj.queue_free()

func test_invalid_target_keeps_direction() -> void:
	var comp := TrackingMovementComponent.new()
	var proj := Node2D.new()
	proj.set_script(load("res://scripts/entities/projectiles/projectile.gd"))
	add_child(proj)
	proj.direction = Vector2.RIGHT
	var data := ProjectileData.new()
	data.speed = 100.0
	data.lifetime = 5.0
	proj.data = data
	proj.target = null
	proj.add_child(comp)
	comp.on_projectile_setup(proj)
	comp._physics_process(0.1)
	# 无目标时方向不变，仍直线飞行
	assert_almost_eq(proj.direction.x, 1.0, 0.01)
	proj.queue_free()

func test_reset_clears_state() -> void:
	var comp := TrackingMovementComponent.new()
	add_child(comp)
	comp._elapsed = 3.0
	var t := Node2D.new()
	comp._target = t
	comp.reset()
	assert_eq(comp._elapsed, 0.0)
	assert_null(comp._target)
	t.free()
	comp.queue_free()

func test_pooled_target_not_in_tree_ignored() -> void:
	var comp := TrackingMovementComponent.new()
	var proj := Node2D.new()
	proj.set_script(load("res://scripts/entities/projectiles/projectile.gd"))
	add_child(proj)
	proj.direction = Vector2.RIGHT
	proj.global_position = Vector2.ZERO
	var data := ProjectileData.new()
	data.speed = 100.0
	data.lifetime = 5.0
	proj.data = data
	# 创建一个不在场景树中的目标（模拟池化回收）
	var target := Node2D.new()  # 不 add_child，不在场景树中
	proj.target = target
	proj.add_child(comp)
	comp.on_projectile_setup(proj)
	comp._physics_process(0.1)
	# 目标不在树中，方向不应改变
	assert_almost_eq(proj.direction.x, 1.0, 0.01)
	target.free()
	proj.queue_free()
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tracking_movement_component.gd -gexit`
Expected: FAIL（TrackingMovementComponent 类不存在）

- [ ] **Step 3: 创建 tracking_movement_component.gd**

创建 `scripts/components/tracking_movement_component.gd`：

```gdscript
class_name TrackingMovementComponent
extends Node

## 追踪移动组件 — 投射物飞行中每帧朝目标调整方向，保证命中
## 与 LinearMovementComponent 互斥，同一投射物场景只挂其中一个

signal lifetime_expired

var speed: float = 300.0
var lifetime: float = 5.0
@export var turn_speed: float = 8.0

var _elapsed: float = 0.0
var _target: Node2D = null

func on_projectile_setup(projectile: Node2D) -> void:
	speed = projectile.data.speed
	lifetime = projectile.data.lifetime
	_target = projectile.target
	_elapsed = 0.0
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	var proj: Node2D = get_parent()
	if not proj:
		return
	# 目标有效且在场景树中时持续调整方向（池化回收的敌人不在树中）
	if _target and is_instance_valid(_target) and _target.is_inside_tree():
		var desired: Vector2 = proj.global_position.direction_to(_target.global_position)
		proj.direction = proj.direction.lerp(desired, turn_speed * delta).normalized()
		proj.rotation = proj.direction.angle()
	# 目标失效时保持最后方向直线飞行
	proj.position += proj.direction * speed * delta
	_elapsed += delta
	if _elapsed >= lifetime:
		lifetime_expired.emit()
		proj.request_destroy()

func reset() -> void:
	_elapsed = 0.0
	_target = null
	set_physics_process(false)
```

- [ ] **Step 4: 在 global_script_class_cache.cfg 中注册 class_name**

在 `.godot/global_script_class_cache.cfg` 的 list 数组中追加（参照 LinearMovementComponent 条目格式）：

```
, {
"base": &"Node",
"class": &"TrackingMovementComponent",
"icon": "",
"is_abstract": false,
"is_tool": false,
"language": &"GDScript",
"path": "res://scripts/components/tracking_movement_component.gd"
}
```

- [ ] **Step 5: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_tracking_movement_component.gd -gexit`
Expected: 全部 PASS

- [ ] **Step 6: 提交**

```bash
git add scripts/components/tracking_movement_component.gd tests/unit/test_tracking_movement_component.gd .godot/global_script_class_cache.cfg
git commit -m "feat: 新增 TrackingMovementComponent 追踪移动组件"
```

## Chunk 3: 预判瞄准 + target 传递（RangedAttackComponent + WeaponManager）

### Task 4: RangedAttackComponent 预判瞄准 + target 传递

**Files:**
- Modify: `scripts/components/ranged_attack_component.gd:1-12` (新增 use_lead_shot 属性)
- Modify: `scripts/components/ranged_attack_component.gd:65-80` (_execute_attack 逻辑)
- Test: `tests/unit/test_ranged_attack_component.gd`

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_ranged_attack_component.gd` 末尾追加：

```gdscript
func test_use_lead_shot_defaults_false() -> void:
	assert_false(comp.use_lead_shot)

func test_calculate_lead_direction_static_target() -> void:
	# 静止目标时预判方向 = 直射方向
	comp.use_lead_shot = true
	var fire_pos := Vector2.ZERO
	var target_pos := Vector2(100, 0)
	var target_velocity := Vector2.ZERO
	var speed := 500.0
	var result: Vector2 = comp._calculate_direction(fire_pos, target_pos, target_velocity, speed)
	assert_almost_eq(result.x, 1.0, 0.01)
	assert_almost_eq(result.y, 0.0, 0.01)

func test_calculate_lead_direction_moving_target() -> void:
	# 目标向上移动时，预判方向应有 y 偏移
	comp.use_lead_shot = true
	var fire_pos := Vector2.ZERO
	var target_pos := Vector2(100, 0)
	var target_velocity := Vector2(0, -200)  # 目标向上移动
	var speed := 500.0
	var result: Vector2 = comp._calculate_direction(fire_pos, target_pos, target_velocity, speed)
	assert_lt(result.y, 0.0, "预判方向应向上偏移")

func test_calculate_direction_no_lead_shot() -> void:
	# 不使用预判时直射
	comp.use_lead_shot = false
	var fire_pos := Vector2.ZERO
	var target_pos := Vector2(100, 0)
	var target_velocity := Vector2(0, -200)
	var speed := 500.0
	var result: Vector2 = comp._calculate_direction(fire_pos, target_pos, target_velocity, speed)
	assert_almost_eq(result.x, 1.0, 0.01)
	assert_almost_eq(result.y, 0.0, 0.01)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_ranged_attack_component.gd -gexit`
Expected: FAIL（use_lead_shot 和 _calculate_direction 不存在）

- [ ] **Step 3: 修改 ranged_attack_component.gd**

1. 在属性区（第 11 行 `sfx_id` 后）新增：
```gdscript
var use_lead_shot: bool = false
```

2. 新增辅助方法（在 `_execute_attack` 之前）：
```gdscript
func _calculate_direction(fire_pos: Vector2, target_pos: Vector2, target_velocity: Vector2, proj_speed: float) -> Vector2:
	if use_lead_shot and target_velocity.length_squared() > 0.0:
		var distance: float = fire_pos.distance_to(target_pos)
		var flight_time: float = distance / proj_speed
		var predicted_pos: Vector2 = target_pos + target_velocity * flight_time
		return fire_pos.direction_to(predicted_pos)
	return fire_pos.direction_to(target_pos)
```

3. 修改 `_execute_attack`（第 65-80 行）：
```gdscript
func _execute_attack(target: Node2D) -> void:
	if not projectile_data:
		return
	var fire_pos: Vector2
	if _fire_point:
		fire_pos = _fire_point.global_position
	else:
		fire_pos = get_parent().global_position
	var target_velocity: Vector2 = target.velocity if "velocity" in target else Vector2.ZERO
	var direction: Vector2 = _calculate_direction(fire_pos, target.global_position, target_velocity, projectile_data.speed)
	var damage: float = get_final_damage()
	var proj_target: Node2D = null if use_lead_shot else target
	var proj: Node2D = SceneFactory.create_projectile(projectile_data, damage, fire_pos, direction, proj_target)
	if on_projectile_created.is_valid():
		on_projectile_created.call(proj)
	projectile_spawned.emit(proj)
	attack_executed.emit(target, proj)
	AudioManager.play(sfx_id)
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_ranged_attack_component.gd -gexit`
Expected: 全部 PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/components/ranged_attack_component.gd tests/unit/test_ranged_attack_component.gd
git commit -m "feat: RangedAttackComponent 新增预判瞄准和 target 传递"
```

### Task 5: WeaponManager 启用 use_lead_shot

**Files:**
- Modify: `scripts/entities/weapons/weapon_manager.gd:71-80`

- [ ] **Step 1: 修改 weapon_manager.gd**

在第 75 行（`ranged.projectile_data = weapon_data.projectile_data` 之后）新增一行：

```gdscript
		ranged.use_lead_shot = true
```

完整上下文：
```gdscript
	if weapon_data.projectile_data:
		var ranged := RangedAttackComponent.new()
		ranged.name = "RangedAttackComponent"
		ranged.attack_config = weapon_data.attack_config
		ranged.projectile_data = weapon_data.projectile_data
		ranged.use_lead_shot = true
		ranged.projectile_spawned.connect(_on_projectile_spawned)
```

- [ ] **Step 2: 运行全量测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部 PASS

- [ ] **Step 3: 提交**

```bash
git add scripts/entities/weapons/weapon_manager.gd
git commit -m "feat: WeaponManager 启用 use_lead_shot 预判瞄准"
```

## Chunk 4: 弹射追踪（BounceOnHitComponent）

### Task 6: BounceOnHitComponent 弹射追踪

**Files:**
- Modify: `scripts/components/bounce_on_hit_component.gd`
- Test: `tests/unit/test_projectile_components.gd`

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_projectile_components.gd` 末尾追加：

```gdscript
func test_bounce_tracking_defaults_false() -> void:
	var bounce := BounceOnHitComponent.new()
	assert_false(bounce.bounce_tracking)
	bounce.free()

func test_bounce_reset_clears_tracking_state() -> void:
	var bounce := BounceOnHitComponent.new()
	add_child(bounce)
	bounce._is_bouncing = true
	bounce._projectile_ref = Node2D.new()
	bounce.reset()
	assert_false(bounce._is_bouncing)
	assert_null(bounce._projectile_ref)
	bounce.queue_free()

func test_bounce_stop_tracking_clears_state() -> void:
	var bounce := BounceOnHitComponent.new()
	add_child(bounce)
	bounce._is_bouncing = true
	bounce._projectile_ref = Node2D.new()
	bounce._stop_tracking()
	assert_false(bounce._is_bouncing)
	assert_null(bounce._projectile_ref)
	bounce.queue_free()
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_projectile_components.gd -gexit`
Expected: FAIL（bounce_tracking/_is_bouncing/_stop_tracking 不存在）

- [ ] **Step 3: 修改 bounce_on_hit_component.gd**

完整替换文件内容：

```gdscript
class_name BounceOnHitComponent
extends Node

signal bounces_exhausted

@export var bounce_range: float = 150.0
@export var max_bounces: int = 1
@export var bounce_tracking: bool = false
@export var bounce_turn_speed: float = 10.0
var manages_lifecycle: bool = true

var _bounce_count: int = 0
var _hit_enemies: Array[Node2D] = []
var _is_bouncing: bool = false
var _projectile_ref: Node2D = null

func on_hit(target: Node2D, projectile: Node2D) -> void:
	# 防止同帧重叠敌人触发多次命中
	if target in _hit_enemies:
		return
	_hit_enemies.append(target)
	_bounce_count += 1
	# 命中后暂停碰撞检测，弹射重定向后再启用
	var hitbox = projectile.get_node_or_null("Hitbox") if projectile else null
	if _bounce_count > max_bounces:
		if projectile:
			projectile._should_destroy = true
		bounces_exhausted.emit()
		return
	var bounce_target: Node2D = _find_bounce_target(target.global_position)
	if bounce_target and projectile:
		projectile.direction = projectile.global_position.direction_to(bounce_target.global_position)
		# 启用弹射追踪
		if bounce_tracking:
			projectile.target = bounce_target
			_projectile_ref = projectile
			_is_bouncing = true
			set_physics_process(true)
		# 短暂禁用再启用，避免弹射瞬间碰到相邻敌人
		if hitbox:
			hitbox.set_deferred("monitoring", false)
			projectile.get_tree().create_timer(0.05).timeout.connect(func() -> void:
				if is_instance_valid(hitbox):
					hitbox.monitoring = true
			)
	else:
		if projectile:
			projectile._should_destroy = true
		bounces_exhausted.emit()

func _physics_process(delta: float) -> void:
	if not _is_bouncing or not bounce_tracking:
		set_physics_process(false)
		return
	if not _projectile_ref or not is_instance_valid(_projectile_ref):
		_stop_tracking()
		return
	var target: Node2D = _projectile_ref.target
	if not target or not is_instance_valid(target) or not target.is_inside_tree():
		_stop_tracking()
		return
	var desired: Vector2 = _projectile_ref.global_position.direction_to(target.global_position)
	_projectile_ref.direction = _projectile_ref.direction.lerp(desired, bounce_turn_speed * delta).normalized()

func _stop_tracking() -> void:
	_is_bouncing = false
	_projectile_ref = null
	set_physics_process(false)

func _find_bounce_target(from_pos: Vector2) -> Node2D:
	if not is_inside_tree():
		return null
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var closest: Node2D = null
	var min_dist: float = bounce_range * bounce_range
	for enemy in enemies:
		if enemy in _hit_enemies:
			continue
		if not is_instance_valid(enemy):
			continue
		var dist: float = from_pos.distance_squared_to((enemy as Node2D).global_position)
		if dist < min_dist:
			min_dist = dist
			closest = enemy as Node2D
	return closest

func reset() -> void:
	_bounce_count = 0
	_hit_enemies.clear()
	_is_bouncing = false
	_projectile_ref = null
	set_physics_process(false)
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_projectile_components.gd -gexit`
Expected: 全部 PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/components/bounce_on_hit_component.gd tests/unit/test_projectile_components.gd
git commit -m "feat: BounceOnHitComponent 新增弹射追踪"
```

## Chunk 5: 场景文件更新 + 全量验证

### Task 7: 塔投射物场景替换为 TrackingMovement

**Files:**
- Modify: `scenes/entities/projectiles/pea_bullet.tscn`
- Modify: `scenes/entities/projectiles/ice_bullet.tscn`

- [ ] **Step 1: 修改 pea_bullet.tscn**

替换 `scenes/entities/projectiles/pea_bullet.tscn` 完整内容：

```
[gd_scene load_steps=4 format=3 uid="uid://pea_bullet_projectile"]

[ext_resource type="Script" uid="uid://c8projectile01" path="res://scripts/entities/projectiles/projectile.gd" id="1_proj"]
[ext_resource type="Script" uid="uid://bx7m3k2vpqn4r" path="res://scripts/components/hitbox.gd" id="2_hitbox"]
[ext_resource type="Script" path="res://scripts/components/tracking_movement_component.gd" id="3_tracking"]

[sub_resource type="CircleShape2D" id="CircleShape2D_pea"]
radius = 6.0

[node name="PeaBullet" type="Node2D"]
script = ExtResource("1_proj")

[node name="Hitbox" type="Area2D" parent="." groups=["hitboxes"]]
collision_layer = 16
collision_mask = 128
script = ExtResource("2_hitbox")

[node name="CollisionShape2D" type="CollisionShape2D" parent="Hitbox"]
shape = SubResource("CircleShape2D_pea")

[node name="TrackingMovementComponent" type="Node" parent="."]
script = ExtResource("3_tracking")
turn_speed = 8.0
```

- [ ] **Step 2: 修改 ice_bullet.tscn**

替换 `scenes/entities/projectiles/ice_bullet.tscn` 完整内容：

```
[gd_scene load_steps=5 format=3 uid="uid://ice_bullet_projectile"]

[ext_resource type="Script" uid="uid://c8projectile01" path="res://scripts/entities/projectiles/projectile.gd" id="1_proj"]
[ext_resource type="Script" uid="uid://bx7m3k2vpqn4r" path="res://scripts/components/hitbox.gd" id="2_hitbox"]
[ext_resource type="Script" path="res://scripts/components/tracking_movement_component.gd" id="3_tracking"]
[ext_resource type="Script" path="res://scripts/components/slow_on_hit_component.gd" id="4_slow"]

[sub_resource type="CircleShape2D" id="CircleShape2D_ice"]
radius = 6.0

[node name="IceBullet" type="Node2D"]
script = ExtResource("1_proj")

[node name="Hitbox" type="Area2D" parent="." groups=["hitboxes"]]
collision_layer = 16
collision_mask = 128
script = ExtResource("2_hitbox")

[node name="CollisionShape2D" type="CollisionShape2D" parent="Hitbox"]
shape = SubResource("CircleShape2D_ice")

[node name="TrackingMovementComponent" type="Node" parent="."]
script = ExtResource("3_tracking")
turn_speed = 8.0

[node name="SlowOnHitComponent" type="Node" parent="."]
script = ExtResource("4_slow")
slow_ratio = 0.3
slow_duration = 1.5
```

- [ ] **Step 3: 在 Godot 编辑器中重新保存两个场景**

TrackingMovementComponent 的 ext_resource 没有 UID，需在编辑器中打开并保存让 Godot 自动分配 UID 和刷新缓存。

- [ ] **Step 4: 提交**

```bash
git add scenes/entities/projectiles/pea_bullet.tscn scenes/entities/projectiles/ice_bullet.tscn
git commit -m "feat: 塔投射物场景替换 LinearMovement 为 TrackingMovement"
```

### Task 8: Shuriken 场景启用弹射追踪

**Files:**
- Modify: `scenes/entities/projectiles/shuriken.tscn`

- [ ] **Step 1: 修改 shuriken.tscn**

在 `scenes/entities/projectiles/shuriken.tscn` 的 BounceOnHitComponent 节点添加属性：

将第 34-37 行：
```
[node name="BounceOnHitComponent" type="Node" parent="."]
script = ExtResource("6_bounce")
bounce_range = 150.0
max_bounces = 1
```

改为：
```
[node name="BounceOnHitComponent" type="Node" parent="."]
script = ExtResource("6_bounce")
bounce_range = 150.0
max_bounces = 1
bounce_tracking = true
```

- [ ] **Step 2: 提交**

```bash
git add scenes/entities/projectiles/shuriken.tscn
git commit -m "feat: shuriken 弹射启用追踪模式"
```

### Task 9: 全量测试 + 运行验证

- [ ] **Step 1: 运行全量单元测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部 PASS

- [ ] **Step 2: 在编辑器中运行游戏验证**

通过 gdai-mcp 的 `play_scene` 工具运行 main 场景，验证：
1. 购买塔（pea_shooter/ice_flower）→ 塔投射物追踪敌人命中
2. 弓箭/手里剑攻击 → 投射物有预判提前量，移动敌人命中率提升
3. 手里剑弹射 → 弹射后追踪下一个目标
4. 敌人死亡时投射物不报错

- [ ] **Step 3: 最终提交（如有修复）**

```bash
git add -A
git commit -m "fix: 投射物瞄准改进最终修复"
```
