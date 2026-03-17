# 组件化战斗系统重构 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将武器/塔/投射物系统从继承架构重构为组件组合架构，消除所有子类（ShurikenWeapon、TowerShooter、TowerGenerator、ShurikenProjectile），行为通过可插拔子节点组件实现。

**Architecture:** Resource 层拆分（AttackConfigData/GeneratorConfigData 独立）→ 新组件（TargetFinder/RangedAttack/MeleeAttack/Generator + 投射物命中效果组件）→ 投射物基座重写 → 塔统一化 → 武器 Pivot+Offset 重构 → 集成适配 + 旧代码清理。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架

**重要：原子性分支** — Resource 重构（Chunk 1）会使旧代码不可用。整个重构在 feature 分支上进行，期间游戏不可运行是预期的。只有完成 Chunk 6 后整体才恢复可运行状态。每个 Chunk 内的测试仅验证新代码本身。

**Spec:** `docs/superpowers/specs/2026-03-17-component-based-combat-redesign.md`

**测试命令:** `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

**单文件测试:** `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/<file>.gd -gexit`

---

## File Structure

### 新建文件

**Resource 类：**
- `scripts/resources/attack_config_data.gd` — 攻击配置（damage/fire_rate/range per_level）
- `scripts/resources/generator_config_data.gd` — 生成配置（amount/interval per_level）

**核心组件：**
- `scripts/components/target_finder_component.gd` — Area2D 索敌，可插拔策略
- `scripts/components/ranged_attack_component.gd` — 远程攻击（冷却+投射物创建）
- `scripts/components/melee_attack_component.gd` — 近战攻击（冷却+临时 hitbox）
- `scripts/components/generator_component.gd` — 定时生成（金币）

**投射物组件：**
- `scripts/components/linear_movement_component.gd` — 直线移动+生命周期
- `scripts/components/trail_component.gd` — Line2D 拖尾
- `scripts/components/rotation_component.gd` — 旋转动画
- `scripts/components/slow_on_hit_component.gd` — 命中减速
- `scripts/components/knockback_on_hit_component.gd` — 命中击退
- `scripts/components/pierce_component.gd` — 穿透
- `scripts/components/bounce_on_hit_component.gd` — 弹射

**投射物基座：**
- `scripts/entities/projectiles/projectile.gd` — 新投射物基座（替代 projectile_base.gd）

**投射物场景（替代现有 2 个场景为 4 个）：**
- `scenes/entities/projectiles/arrow.tscn`
- `scenes/entities/projectiles/shuriken.tscn`
- `scenes/entities/projectiles/pea_bullet.tscn`
- `scenes/entities/projectiles/ice_bullet.tscn`

**测试文件：**
- `tests/unit/test_target_finder_component.gd`
- `tests/unit/test_ranged_attack_component.gd`
- `tests/unit/test_melee_attack_component.gd`
- `tests/unit/test_generator_component.gd`
- `tests/unit/test_projectile_components.gd`
- `tests/unit/test_projectile_new.gd`

### 修改文件

- `scripts/resources/weapon_data.gd` — 重构：拆出 AttackConfigData，添加 pivot/visual 配置
- `scripts/resources/tower_data.gd` — 重构：拆出 AttackConfigData/GeneratorConfigData
- `scripts/resources/projectile_data.gd` — 精简：移除命中效果字段
- `scripts/entities/towers/tower.gd` — 重写：统一基座，组件自动检测
- `scripts/entities/weapons/weapon_manager.gd` — 重写：Pivot+Offset 架构
- `scripts/core/scene_factory.gd` — 适配：create_projectile 签名变更，池 key 更新
- `scripts/entities/player.gd` — 适配：被动 multiplier 注入方式
- `scripts/ui/main.gd` — 适配：移除 TowerShooter/TowerGenerator 引用
- `resources/weapons/*.tres` — 重建
- `resources/towers/*.tres` — 重建
- `resources/projectiles/*.tres` — 重建
- `scenes/entities/towers/*.tscn` — 重建
- 现有测试文件 — 适配新接口

### 删除文件

- `scripts/components/attacker_component.gd`
- `scripts/entities/weapons/weapon.gd`
- `scripts/entities/weapons/shuriken_weapon.gd`
- `scripts/entities/towers/tower_shooter.gd`
- `scripts/entities/towers/tower_generator.gd`
- `scripts/entities/projectiles/projectile_base.gd`
- `scripts/entities/projectiles/shuriken_projectile.gd`
- `scenes/entities/projectiles/bullet_projectile.tscn`
- `scenes/entities/projectiles/shuriken_projectile.tscn`

---

## Chunk 1: Resource 层重构

### Task 1: 新建 AttackConfigData 和 GeneratorConfigData

**Files:**
- Create: `scripts/resources/attack_config_data.gd`
- Create: `scripts/resources/generator_config_data.gd`

- [ ] **Step 1: 创建 AttackConfigData**

```gdscript
# scripts/resources/attack_config_data.gd
class_name AttackConfigData
extends Resource

@export var damage_per_level: PackedFloat32Array = []
@export var fire_rate_per_level: PackedFloat32Array = []
@export var attack_range_per_level: PackedFloat32Array = []
```

- [ ] **Step 2: 创建 GeneratorConfigData**

```gdscript
# scripts/resources/generator_config_data.gd
class_name GeneratorConfigData
extends Resource

@export var generate_amount_per_level: PackedFloat32Array = []
@export var generate_interval_per_level: PackedFloat32Array = []
```

- [ ] **Step 3: 提交**

```bash
git add scripts/resources/attack_config_data.gd scripts/resources/generator_config_data.gd
git commit -m "feat: 新增 AttackConfigData 和 GeneratorConfigData Resource 类"
```

### Task 2: 重构 WeaponData、TowerData、ProjectileData

**Files:**
- Modify: `scripts/resources/weapon_data.gd`
- Modify: `scripts/resources/tower_data.gd`
- Modify: `scripts/resources/projectile_data.gd`

- [ ] **Step 1: 重构 WeaponData**

将 `weapon_data.gd` 重写为：

```gdscript
class_name WeaponData
extends Resource

@export_group("基础信息")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""
@export var sell_price_per_level: PackedInt32Array = PackedInt32Array([])

@export_group("攻击配置")
@export var attack_config: AttackConfigData = null
@export var projectile_data: ProjectileData = null
@export var melee_config: MeleeConfig = null

@export_group("Pivot 配置")
@export var pivot_offset: float = 15.0

@export_group("视觉配置")
@export var hide_sprite_on_fire: bool = false
@export var sprite_restore_ratio: float = 0.9
```

移除的字段：`attack_mode`、`max_level`、`damage_per_level`、`fire_rate_per_level`、`weapon_range_per_level`（迁移到 AttackConfigData）。

- [ ] **Step 2: 重构 TowerData**

将 `tower_data.gd` 重写为：

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

@export_group("射击塔配置")
@export var attack_config: AttackConfigData = null
@export var projectile_data: ProjectileData = null
@export var slow_ratio_per_level: PackedFloat32Array = []
@export var slow_duration_per_level: PackedFloat32Array = []

@export_group("生成塔配置")
@export var generator_config: GeneratorConfigData = null
```

移除的字段：`max_level`、`damage_per_level`、`fire_rate_per_level`、`attack_range_per_level`、`generate_amount_per_level`、`generate_interval_per_level`（迁移到对应子 Resource）。

- [ ] **Step 3: 精简 ProjectileData**

将 `projectile_data.gd` 重写为：

```gdscript
class_name ProjectileData
extends Resource

@export_group("飞行参数")
@export var speed: float = 300.0
@export var lifetime: float = 5.0

@export_group("视觉")
@export var sprite_path: String = ""
@export var projectile_scene: PackedScene = null
```

移除的字段：`trail_enabled`、`trail_config`、`knockback_force`、`base_pierce_count`、`slow_ratio`、`slow_duration`（迁移到投射物场景子节点组件的 @export）。

- [ ] **Step 4: 提交**

```bash
git add scripts/resources/weapon_data.gd scripts/resources/tower_data.gd scripts/resources/projectile_data.gd
git commit -m "refactor: 重构 WeaponData/TowerData/ProjectileData Resource 类"
```

### Task 3: 迁移 .tres 资源文件

**Files:**
- Modify: `resources/weapons/bow.tres`, `shuriken.tres`, `sword.tres`
- Modify: `resources/towers/pea_shooter.tres`, `ice_flower.tres`, `sunflower.tres`
- Modify: `resources/projectiles/arrow.tres`, `shuriken.tres`, `pea_bullet.tres`, `ice_bullet.tres`

- [ ] **Step 1: 迁移武器 .tres 文件**

每个武器文件需要：将原有 `damage_per_level`/`fire_rate_per_level`/`weapon_range_per_level` 嵌套到 `attack_config` 子资源中，添加 `pivot_offset` 和视觉配置。

`resources/weapons/bow.tres` 示例结构：
```
[sub_resource type="AttackConfigData"]
damage_per_level = PackedFloat32Array(8, 18, 34)
fire_rate_per_level = PackedFloat32Array(0.5, 0.4, 0.3)
attack_range_per_level = PackedFloat32Array(150, 170, 200)

[resource]
id = "bow"
display_name = "弓箭"
attack_config = SubResource(上面的)
projectile_data = ExtResource(arrow.tres)
pivot_offset = 15.0
sell_price_per_level = PackedInt32Array(3, 7, 21)
```

`resources/weapons/shuriken.tres`：同结构，`hide_sprite_on_fire = true`，`sprite_restore_ratio = 0.9`。

`resources/weapons/sword.tres`：同结构，`melee_config = ExtResource(sword_melee.tres)`，无 `projectile_data`，`pivot_offset = 10.0`。

- [ ] **Step 2: 迁移塔 .tres 文件**

`resources/towers/pea_shooter.tres`：
```
[sub_resource type="AttackConfigData"]
damage_per_level = PackedFloat32Array(15, 30, 55)
fire_rate_per_level = PackedFloat32Array(1.0, 0.8, 0.6)
attack_range_per_level = PackedFloat32Array(150, 170, 200)

[resource]
id = "pea_shooter"
display_name = "射手塔"
hp_per_level = PackedFloat32Array(80, 150, 260)
attack_config = SubResource(上面的)
projectile_data = ExtResource(pea_bullet.tres)
sell_price_per_level = PackedInt32Array(3, 7, 21)
```

`resources/towers/ice_flower.tres`：同结构 + `slow_ratio_per_level`/`slow_duration_per_level`。

`resources/towers/sunflower.tres`：
```
[sub_resource type="GeneratorConfigData"]
generate_amount_per_level = PackedFloat32Array(5, 8, 12)
generate_interval_per_level = PackedFloat32Array(10, 8, 6)

[resource]
id = "sunflower"
display_name = "向日葵"
hp_per_level = PackedFloat32Array(70, 115, 170)
generator_config = SubResource(上面的)
sell_price_per_level = PackedInt32Array(3, 7, 21)
```

- [ ] **Step 3: 精简投射物 .tres 文件**

从每个投射物 .tres 移除：`knockback_force`、`base_pierce_count`、`slow_ratio`、`slow_duration`、`trail_enabled`、`trail_config`。
只保留：`speed`、`lifetime`、`sprite_path`、`projectile_scene`。

注意：`projectile_scene` 字段需要在后续任务创建新场景后再更新引用。暂时保留旧引用或清空。

- [ ] **Step 4: 提交**

```bash
git add resources/weapons/ resources/towers/ resources/projectiles/
git commit -m "refactor: 迁移 .tres 资源文件到新 Resource 结构"
```

---

## Chunk 2: 核心组件

### Task 4: TargetFinderComponent

**Files:**
- Create: `scripts/components/target_finder_component.gd`
- Create: `tests/unit/test_target_finder_component.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/unit/test_target_finder_component.gd
extends GutTest

var finder: TargetFinderComponent

func before_each() -> void:
	finder = TargetFinderComponent.new()
	add_child(finder)

func after_each() -> void:
	finder.queue_free()

func test_get_target_returns_null_when_no_enemies() -> void:
	assert_null(finder.get_target())

func test_set_range_updates_detect_area() -> void:
	finder.set_range(200.0)
	assert_eq(finder.detect_range, 200.0)

func test_target_changed_signal_emitted() -> void:
	watch_signals(finder)
	# target_changed 仅在目标身份变化时发出
	finder._update_target(null)
	assert_signal_not_emitted(finder, "target_changed")
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_target_finder_component.gd -gexit`
Expected: FAIL — TargetFinderComponent 类不存在

- [ ] **Step 3: 实现 TargetFinderComponent**

```gdscript
# scripts/components/target_finder_component.gd
class_name TargetFinderComponent
extends Node

enum TargetStrategy { NEAREST, LOWEST_HP, HIGHEST_HP, RANDOM }

signal target_changed(new_target: Node2D)

@export var detect_range: float = 100.0
@export var strategy: TargetStrategy = TargetStrategy.NEAREST

var _current_target: Node2D = null
var _detect_area: Area2D = null
var _collision_shape: CollisionShape2D = null

func _ready() -> void:
	_detect_area = Area2D.new()
	_detect_area.name = "DetectArea"
	_detect_area.collision_layer = 0
	_detect_area.collision_mask = 2  # enemies layer
	_detect_area.monitoring = true
	_detect_area.monitorable = false
	_collision_shape = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = detect_range
	_collision_shape.shape = shape
	_detect_area.add_child(_collision_shape)
	add_child(_detect_area)

func set_range(new_range: float) -> void:
	detect_range = new_range
	if _collision_shape and _collision_shape.shape:
		(_collision_shape.shape as CircleShape2D).radius = new_range

func get_target() -> Node2D:
	if not _detect_area:
		return null
	var bodies: Array[Node2D] = _detect_area.get_overlapping_bodies()
	if bodies.is_empty():
		_update_target(null)
		return null

	var result: Node2D = null
	match strategy:
		TargetStrategy.NEAREST:
			result = _find_nearest(bodies)
		TargetStrategy.LOWEST_HP:
			result = _find_lowest_hp(bodies)
		TargetStrategy.HIGHEST_HP:
			result = _find_highest_hp(bodies)
		TargetStrategy.RANDOM:
			result = bodies.pick_random()

	_update_target(result)
	return result

func _update_target(new_target: Node2D) -> void:
	if new_target != _current_target:
		_current_target = new_target
		target_changed.emit(new_target)

func _find_nearest(bodies: Array[Node2D]) -> Node2D:
	var closest: Node2D = null
	var min_dist: float = INF
	var origin: Vector2 = global_position
	for body in bodies:
		if not is_instance_valid(body):
			continue
		var dist: float = origin.distance_squared_to(body.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = body
	return closest

func _find_lowest_hp(bodies: Array[Node2D]) -> Node2D:
	var result: Node2D = null
	var min_hp: float = INF
	for body in bodies:
		if not is_instance_valid(body):
			continue
		var health = body.get_node_or_null("HealthComponent")
		if health and health.current_hp < min_hp:
			min_hp = health.current_hp
			result = body
	return result

func _find_highest_hp(bodies: Array[Node2D]) -> Node2D:
	var result: Node2D = null
	var max_hp: float = -1.0
	for body in bodies:
		if not is_instance_valid(body):
			continue
		var health = body.get_node_or_null("HealthComponent")
		if health and health.current_hp > max_hp:
			max_hp = health.current_hp
			result = body
	return result
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_target_finder_component.gd -gexit`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/components/target_finder_component.gd tests/unit/test_target_finder_component.gd
git commit -m "feat: TargetFinderComponent — Area2D 索敌组件（支持多种策略）"
```

### Task 5: RangedAttackComponent

**Files:**
- Create: `scripts/components/ranged_attack_component.gd`
- Create: `tests/unit/test_ranged_attack_component.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/unit/test_ranged_attack_component.gd
extends GutTest

var comp: RangedAttackComponent

func before_each() -> void:
	comp = RangedAttackComponent.new()
	add_child(comp)

func after_each() -> void:
	comp.queue_free()

func test_initial_cooldown_zero() -> void:
	assert_eq(comp._cooldown_remaining, 0.0)

func test_get_final_damage_with_multiplier() -> void:
	comp._base_damage = 10.0
	comp.damage_multiplier = 1.5
	assert_almost_eq(comp.get_final_damage(), 15.0, 0.01)

func test_get_final_cooldown_with_multiplier() -> void:
	comp._base_cooldown = 1.0
	comp.speed_multiplier = 2.0
	assert_almost_eq(comp.get_final_cooldown(), 0.5, 0.01)

func test_set_level_reads_attack_config() -> void:
	var config := AttackConfigData.new()
	config.damage_per_level = PackedFloat32Array([10, 20, 30])
	config.fire_rate_per_level = PackedFloat32Array([1.0, 0.8, 0.6])
	config.attack_range_per_level = PackedFloat32Array([100, 150, 200])
	comp.attack_config = config
	comp.set_level(2)
	assert_almost_eq(comp._base_damage, 20.0, 0.01)
	assert_almost_eq(comp._base_cooldown, 0.8, 0.01)

func test_tick_decrements_cooldown() -> void:
	comp._cooldown_remaining = 1.0
	comp.tick(0.5)
	assert_almost_eq(comp._cooldown_remaining, 0.5, 0.01)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ranged_attack_component.gd -gexit`
Expected: FAIL

- [ ] **Step 3: 实现 RangedAttackComponent**

```gdscript
# scripts/components/ranged_attack_component.gd
class_name RangedAttackComponent
extends Node

signal attack_executed(target: Node2D, projectile: Node2D)
signal projectile_spawned(proj: Node2D)

var attack_config: AttackConfigData = null
var projectile_data: ProjectileData = null
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var on_projectile_created: Callable  # 可选回调
var sfx_id: String = "shoot"

var _base_damage: float = 0.0
var _base_cooldown: float = 1.0
var _cooldown_remaining: float = 0.0
var _target_finder: TargetFinderComponent = null
var _fire_point: Marker2D = null

func _ready() -> void:
	# 查找兄弟节点
	_target_finder = get_parent().get_node_or_null("TargetFinderComponent")
	# 查找 FirePoint（在 WeaponOffset 子树中）
	var offset = get_parent().get_node_or_null("WeaponOffset")
	if offset:
		_fire_point = offset.get_node_or_null("FirePoint")

func set_level(level: int) -> void:
	if not attack_config:
		return
	var idx: int = level - 1
	if idx < attack_config.damage_per_level.size():
		_base_damage = attack_config.damage_per_level[idx]
	if idx < attack_config.fire_rate_per_level.size():
		_base_cooldown = attack_config.fire_rate_per_level[idx]
	# 同步 TargetFinder 范围
	if _target_finder and idx < attack_config.attack_range_per_level.size():
		_target_finder.set_range(attack_config.attack_range_per_level[idx])

func tick(delta: float) -> void:
	_cooldown_remaining -= delta
	if _cooldown_remaining > 0.0:
		return
	if not _target_finder:
		return
	var target: Node2D = _target_finder.get_target()
	if not target or not is_instance_valid(target):
		return
	_execute_attack(target)
	_cooldown_remaining = get_final_cooldown()

func get_final_damage() -> float:
	return _base_damage * damage_multiplier

func get_final_cooldown() -> float:
	if speed_multiplier <= 0.0:
		return _base_cooldown
	return _base_cooldown / speed_multiplier

func _execute_attack(target: Node2D) -> void:
	if not projectile_data:
		return
	var fire_pos: Vector2
	if _fire_point:
		fire_pos = _fire_point.global_position
	else:
		fire_pos = get_parent().global_position
	var direction: Vector2 = fire_pos.direction_to(target.global_position)
	var damage: float = get_final_damage()
	var proj: Node2D = SceneFactory.create_projectile(projectile_data, damage, fire_pos, direction)
	# 可选回调（塔覆写命中效果参数）
	if on_projectile_created.is_valid():
		on_projectile_created.call(proj)
	projectile_spawned.emit(proj)
	attack_executed.emit(target, proj)
	AudioManager.play(sfx_id)
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ranged_attack_component.gd -gexit`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/components/ranged_attack_component.gd tests/unit/test_ranged_attack_component.gd
git commit -m "feat: RangedAttackComponent — 远程攻击组件（冷却+索敌+投射物创建）"
```

### Task 6: MeleeAttackComponent

**Files:**
- Create: `scripts/components/melee_attack_component.gd`
- Create: `tests/unit/test_melee_attack_component.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/unit/test_melee_attack_component.gd
extends GutTest

var comp: MeleeAttackComponent

func before_each() -> void:
	comp = MeleeAttackComponent.new()
	add_child(comp)

func after_each() -> void:
	comp.queue_free()

func test_get_final_damage_with_multiplier() -> void:
	comp._base_damage = 20.0
	comp.damage_multiplier = 1.1
	assert_almost_eq(comp.get_final_damage(), 22.0, 0.01)

func test_set_level_reads_attack_config() -> void:
	var config := AttackConfigData.new()
	config.damage_per_level = PackedFloat32Array([20, 38, 65])
	config.fire_rate_per_level = PackedFloat32Array([0.4, 0.32, 0.24])
	config.attack_range_per_level = PackedFloat32Array([50, 60, 70])
	comp.attack_config = config
	comp.set_level(3)
	assert_almost_eq(comp._base_damage, 65.0, 0.01)
	assert_almost_eq(comp._base_cooldown, 0.24, 0.01)

func test_tick_decrements_cooldown() -> void:
	comp._cooldown_remaining = 0.5
	comp.tick(0.3)
	assert_almost_eq(comp._cooldown_remaining, 0.2, 0.01)
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 实现 MeleeAttackComponent**

```gdscript
# scripts/components/melee_attack_component.gd
class_name MeleeAttackComponent
extends Node

signal attack_executed(target: Node2D)

var attack_config: AttackConfigData = null
var melee_config: MeleeConfig = null
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var sfx_id: String = "melee"

var _base_damage: float = 0.0
var _base_cooldown: float = 1.0
var _cooldown_remaining: float = 0.0
var _target_finder: TargetFinderComponent = null
var _is_attacking: bool = false

func _ready() -> void:
	_target_finder = get_parent().get_node_or_null("TargetFinderComponent")

func set_level(level: int) -> void:
	if not attack_config:
		return
	var idx: int = level - 1
	if idx < attack_config.damage_per_level.size():
		_base_damage = attack_config.damage_per_level[idx]
	if idx < attack_config.fire_rate_per_level.size():
		_base_cooldown = attack_config.fire_rate_per_level[idx]
	if _target_finder and idx < attack_config.attack_range_per_level.size():
		_target_finder.set_range(attack_config.attack_range_per_level[idx])

func tick(delta: float) -> void:
	if _is_attacking:
		return
	_cooldown_remaining -= delta
	if _cooldown_remaining > 0.0:
		return
	if not _target_finder:
		return
	var target: Node2D = _target_finder.get_target()
	if not target or not is_instance_valid(target):
		return
	_execute_melee(target)
	_cooldown_remaining = get_final_cooldown()

func get_final_damage() -> float:
	return _base_damage * damage_multiplier

func get_final_cooldown() -> float:
	if speed_multiplier <= 0.0:
		return _base_cooldown
	return _base_cooldown / speed_multiplier

func _execute_melee(target: Node2D) -> void:
	if not melee_config:
		return
	_is_attacking = true
	var direction: Vector2 = get_parent().global_position.direction_to(target.global_position)

	# 创建临时 Hitbox（Hitbox 继承 Area2D，直接配置碰撞层）
	var hitbox := Hitbox.new()
	hitbox.damage = get_final_damage()
	hitbox.knockback_force = melee_config.knockback_force
	hitbox.collision_layer = 4   # CollisionLayers.HITBOX
	hitbox.collision_mask = 128  # CollisionLayers.HURTBOX
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = melee_config.hit_radius
	shape.shape = circle
	hitbox.add_child(shape)
	get_parent().add_child(hitbox)
	hitbox.global_position = get_parent().global_position + direction * melee_config.thrust_distance

	# Tween 前刺动画
	var pivot: Node2D = get_parent()
	var offset_node: Node2D = pivot.get_node_or_null("WeaponOffset")
	if offset_node:
		var tween := create_tween()
		var original_pos: Vector2 = offset_node.position
		var thrust_pos: Vector2 = original_pos + direction * melee_config.thrust_distance
		tween.tween_property(offset_node, "position", thrust_pos, 0.1)
		tween.tween_property(offset_node, "position", original_pos, 0.1)
		tween.tween_callback(func() -> void:
			if is_instance_valid(hitbox):
				hitbox.queue_free()
			_is_attacking = false
		)
	else:
		get_tree().create_timer(0.2).timeout.connect(func() -> void:
			if is_instance_valid(hitbox):
				hitbox.queue_free()
			_is_attacking = false
		)

	attack_executed.emit(target)
	AudioManager.play(sfx_id)
```

- [ ] **Step 4: 运行测试确认通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/components/melee_attack_component.gd tests/unit/test_melee_attack_component.gd
git commit -m "feat: MeleeAttackComponent — 近战攻击组件（临时 hitbox + Tween 前刺）"
```

### Task 7: GeneratorComponent

**Files:**
- Create: `scripts/components/generator_component.gd`
- Create: `tests/unit/test_generator_component.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/unit/test_generator_component.gd
extends GutTest

var comp: GeneratorComponent

func before_each() -> void:
	comp = GeneratorComponent.new()
	add_child(comp)

func after_each() -> void:
	comp.queue_free()

func test_set_level_updates_amount() -> void:
	var config := GeneratorConfigData.new()
	config.generate_amount_per_level = PackedFloat32Array([5, 8, 12])
	config.generate_interval_per_level = PackedFloat32Array([10, 8, 6])
	comp.config = config
	comp.set_level(2)
	assert_eq(comp._amount, 8)
	assert_almost_eq(comp._interval, 8.0, 0.01)

func test_generated_signal_exists() -> void:
	assert_has_signal(comp, "generated")
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 实现 GeneratorComponent**

```gdscript
# scripts/components/generator_component.gd
class_name GeneratorComponent
extends Node

signal generated(amount: int, position: Vector2)

var config: GeneratorConfigData = null
var _amount: int = 0
var _interval: float = 10.0
var _timer: Timer = null

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.autostart = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

func set_level(level: int) -> void:
	if not config:
		return
	var idx: int = level - 1
	if idx < config.generate_amount_per_level.size():
		_amount = int(config.generate_amount_per_level[idx])
	if idx < config.generate_interval_per_level.size():
		_interval = config.generate_interval_per_level[idx]
	_timer.wait_time = _interval
	if is_inside_tree():
		_timer.start()

func _on_timer_timeout() -> void:
	generated.emit(_amount, get_parent().global_position if get_parent() else Vector2.ZERO)
```

- [ ] **Step 4: 运行测试确认通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/components/generator_component.gd tests/unit/test_generator_component.gd
git commit -m "feat: GeneratorComponent — 定时生成组件（替代 TowerGenerator）"
```

---

## Chunk 3: 投射物组件 + 投射物基座

### Task 8: 投射物飞行/视觉组件

**Files:**
- Create: `scripts/components/linear_movement_component.gd`
- Create: `scripts/components/trail_component.gd`
- Create: `scripts/components/rotation_component.gd`

- [ ] **Step 1: 实现 LinearMovementComponent**

```gdscript
# scripts/components/linear_movement_component.gd
class_name LinearMovementComponent
extends Node

signal lifetime_expired

var speed: float = 300.0
var lifetime: float = 5.0
var _elapsed: float = 0.0

func on_projectile_setup(projectile: Node2D) -> void:
	speed = projectile.data.speed
	lifetime = projectile.data.lifetime
	_elapsed = 0.0
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	var proj: Node2D = get_parent()
	if not proj:
		return
	proj.position += proj.direction * speed * delta
	_elapsed += delta
	if _elapsed >= lifetime:
		lifetime_expired.emit()
		proj.request_destroy()

func reset() -> void:
	_elapsed = 0.0
	set_physics_process(false)
```

- [ ] **Step 2: 实现 TrailComponent**

```gdscript
# scripts/components/trail_component.gd
class_name TrailComponent
extends Node

@export var trail_color: Color = Color.WHITE
@export var trail_width: float = 1.0
@export var max_points: int = 4

var _trail: Line2D = null

func on_projectile_setup(_projectile: Node2D) -> void:
	if not _trail:
		_trail = Line2D.new()
		_trail.width = trail_width
		_trail.default_color = trail_color
		add_child(_trail)
	_trail.clear_points()
	_trail.visible = true

func _process(_delta: float) -> void:
	if not _trail or not _trail.visible:
		return
	var proj: Node2D = get_parent()
	if not proj:
		return
	# Trail 是 proj 的子节点的子节点，用局部坐标（相对于 trail 自身）
	# 记录 proj 的全局位置，转换为 trail 的局部坐标
	_trail.add_point(_trail.to_local(proj.global_position))
	while _trail.get_point_count() > max_points:
		_trail.remove_point(0)

func reset() -> void:
	if _trail:
		_trail.clear_points()
		_trail.visible = false
```

- [ ] **Step 3: 实现 RotationComponent**

```gdscript
# scripts/components/rotation_component.gd
class_name RotationComponent
extends Node

@export var rotation_speed: float = 10.0

var _sprite: Node2D = null

func on_projectile_setup(projectile: Node2D) -> void:
	# 查找动态创建的精灵
	_sprite = projectile.get_node_or_null("_PooledSprite")

func _process(delta: float) -> void:
	if _sprite:
		_sprite.rotation += rotation_speed * delta

func reset() -> void:
	_sprite = null
```

- [ ] **Step 4: 提交**

```bash
git add scripts/components/linear_movement_component.gd scripts/components/trail_component.gd scripts/components/rotation_component.gd
git commit -m "feat: 投射物飞行/视觉组件（LinearMovement + Trail + Rotation）"
```

### Task 9: 投射物命中效果组件

**Files:**
- Create: `scripts/components/slow_on_hit_component.gd`
- Create: `scripts/components/knockback_on_hit_component.gd`
- Create: `scripts/components/pierce_component.gd`
- Create: `scripts/components/bounce_on_hit_component.gd`
- Create: `tests/unit/test_projectile_components.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/unit/test_projectile_components.gd
extends GutTest

func test_pierce_component_tracks_hits() -> void:
	var pierce := PierceComponent.new()
	add_child(pierce)
	pierce.max_pierce_count = 2
	# 模拟 3 次命中
	var dummy := Node2D.new()
	add_child(dummy)
	pierce.on_hit(dummy, null)
	assert_eq(pierce._hit_count, 1)
	pierce.on_hit(dummy, null)
	assert_eq(pierce._hit_count, 2)
	# 第 3 次应标记销毁
	pierce.on_hit(dummy, null)
	assert_eq(pierce._hit_count, 3)
	dummy.queue_free()
	pierce.queue_free()

func test_pierce_component_reset() -> void:
	var pierce := PierceComponent.new()
	add_child(pierce)
	pierce._hit_count = 5
	pierce.reset()
	assert_eq(pierce._hit_count, 0)
	pierce.queue_free()

func test_pierce_manages_lifecycle() -> void:
	var pierce := PierceComponent.new()
	assert_true(pierce.manages_lifecycle)
	pierce.free()

func test_bounce_manages_lifecycle() -> void:
	var bounce := BounceOnHitComponent.new()
	assert_true(bounce.manages_lifecycle)
	bounce.free()

func test_bounce_excludes_hit_enemies() -> void:
	var bounce := BounceOnHitComponent.new()
	add_child(bounce)
	var enemy := Node2D.new()
	bounce._hit_enemies.append(enemy)
	# _find_bounce_target should skip already-hit enemies
	# (detailed test requires enemies in group, tested in integration)
	assert_eq(bounce._hit_enemies.size(), 1)
	enemy.free()
	bounce.queue_free()

func test_bounce_reset_clears_state() -> void:
	var bounce := BounceOnHitComponent.new()
	add_child(bounce)
	bounce._bounce_count = 3
	bounce._hit_enemies.append(Node2D.new())
	bounce.reset()
	assert_eq(bounce._bounce_count, 0)
	assert_eq(bounce._hit_enemies.size(), 0)
	bounce.queue_free()

func test_slow_on_hit_graceful_without_handler() -> void:
	# target 没有 SlowHandler 时不应崩溃
	var slow := SlowOnHitComponent.new()
	add_child(slow)
	var target := Node2D.new()
	add_child(target)
	# 不应报错
	slow.on_hit(target, null)
	target.queue_free()
	slow.queue_free()

func test_knockback_on_hit_graceful_without_handler() -> void:
	var kb := KnockbackOnHitComponent.new()
	add_child(kb)
	var target := Node2D.new()
	add_child(target)
	var fake_proj := Node2D.new()
	fake_proj.set("direction", Vector2.RIGHT)
	kb.on_hit(target, fake_proj)
	target.queue_free()
	kb.queue_free()
	fake_proj.free()
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 实现命中效果组件**

```gdscript
# scripts/components/slow_on_hit_component.gd
class_name SlowOnHitComponent
extends Node

@export var slow_ratio: float = 0.3
@export var slow_duration: float = 1.5

func on_hit(target: Node2D, projectile: Node2D) -> void:
	var slow_handler = target.get_node_or_null("SlowHandler")
	if slow_handler:
		var source_id: String = "proj_" + str(projectile.get_instance_id())
		slow_handler.apply_timed_slow(slow_ratio, slow_duration, source_id)

func reset() -> void:
	pass  # 无状态
```

```gdscript
# scripts/components/knockback_on_hit_component.gd
class_name KnockbackOnHitComponent
extends Node

@export var knockback_force: float = 40.0

func on_hit(target: Node2D, projectile: Node2D) -> void:
	var knockback_handler = target.get_node_or_null("KnockbackHandler")
	if knockback_handler and projectile:
		var direction: Vector2 = projectile.direction
		knockback_handler.apply_knockback(direction * knockback_force)

func reset() -> void:
	pass  # 无状态
```

```gdscript
# scripts/components/pierce_component.gd
class_name PierceComponent
extends Node

signal pierce_exhausted

@export var max_pierce_count: int = 0
var manages_lifecycle: bool = true
var _hit_count: int = 0

func on_hit(target: Node2D, projectile: Node2D) -> void:
	_hit_count += 1
	if _hit_count > max_pierce_count:
		if projectile:
			projectile._should_destroy = true
		pierce_exhausted.emit()

func reset() -> void:
	_hit_count = 0
```

```gdscript
# scripts/components/bounce_on_hit_component.gd
class_name BounceOnHitComponent
extends Node

signal bounces_exhausted

@export var bounce_range: float = 150.0
@export var max_bounces: int = 1
var manages_lifecycle: bool = true

var _bounce_count: int = 0
var _hit_enemies: Array[Node2D] = []

func on_hit(target: Node2D, projectile: Node2D) -> void:
	_hit_enemies.append(target)
	_bounce_count += 1
	if _bounce_count > max_bounces:
		if projectile:
			projectile._should_destroy = true
		bounces_exhausted.emit()
		return
	# 寻找弹射目标
	var bounce_target: Node2D = _find_bounce_target(target.global_position)
	if bounce_target and projectile:
		projectile.direction = projectile.global_position.direction_to(bounce_target.global_position)
	else:
		if projectile:
			projectile._should_destroy = true
		bounces_exhausted.emit()

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
```

- [ ] **Step 4: 运行测试确认通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/components/slow_on_hit_component.gd scripts/components/knockback_on_hit_component.gd scripts/components/pierce_component.gd scripts/components/bounce_on_hit_component.gd tests/unit/test_projectile_components.gd
git commit -m "feat: 投射物命中效果组件（Slow/Knockback/Pierce/Bounce）"
```

### Task 10: 投射物基座 + 场景

**Files:**
- Create: `scripts/entities/projectiles/projectile.gd`
- Create: `scenes/entities/projectiles/arrow.tscn`
- Create: `scenes/entities/projectiles/shuriken.tscn`
- Create: `scenes/entities/projectiles/pea_bullet.tscn`
- Create: `scenes/entities/projectiles/ice_bullet.tscn`
- Create: `tests/unit/test_projectile_new.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/unit/test_projectile_new.gd
extends GutTest

func test_projectile_has_direction() -> void:
	var proj := Projectile.new()
	proj.direction = Vector2.RIGHT
	assert_eq(proj.direction, Vector2.RIGHT)
	proj.free()

func test_projectile_should_destroy_default_false() -> void:
	var proj := Projectile.new()
	assert_false(proj._should_destroy)
	proj.free()

func test_has_lifecycle_component_false_when_none() -> void:
	var proj := Projectile.new()
	add_child(proj)
	assert_false(proj._has_lifecycle_component())
	proj.queue_free()

func test_has_lifecycle_component_true_with_pierce() -> void:
	var proj := Projectile.new()
	var pierce := PierceComponent.new()
	proj.add_child(pierce)
	add_child(proj)
	assert_true(proj._has_lifecycle_component())
	proj.queue_free()

func test_reset_for_pool_clears_destroy_flag() -> void:
	var proj := Projectile.new()
	add_child(proj)
	proj._should_destroy = true
	proj.reset_for_pool()
	assert_false(proj._should_destroy)
	proj.queue_free()
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 实现 Projectile 基座**

```gdscript
# scripts/entities/projectiles/projectile.gd
class_name Projectile
extends Node2D

var data: ProjectileData = null
var damage: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var _is_pooled: bool = false
var _should_destroy: bool = false

func setup(p_data: ProjectileData, dmg: float, from: Vector2, dir: Vector2) -> void:
	data = p_data
	damage = dmg
	direction = dir
	global_position = from
	_should_destroy = false
	# Hitbox 伤害值同步 + 碰撞连线
	var hitbox = get_node_or_null("Hitbox") as Hitbox
	if hitbox:
		hitbox.damage = dmg
		# 断开旧连接（池化复用时可能残留）
		if hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.disconnect(_on_hitbox_area_entered)
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	# 设置精灵（动态创建）
	_setup_sprite()
	# 设置旋转
	rotation = dir.angle()
	# 通知子组件初始化
	for child in get_children():
		if child.has_method("on_projectile_setup"):
			child.on_projectile_setup(self)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	# 伤害已由 Hurtbox._on_area_entered() 自动处理（Hitbox.damage → Hurtbox.hit_taken）
	# 这里触发额外命中效果组件
	var target: Node2D = area.get_parent()
	if target:
		on_hit(target)

func on_hit(target: Node2D) -> void:
	# 伤害由 Hitbox/Hurtbox 体系自动处理
	# 这里只处理额外效果组件
	for child in get_children():
		if child.has_method("on_hit"):
			child.on_hit(target, self)
	# 命中特效
	EffectsManager.spawn_hit_sparks(global_position)
	# 销毁判断
	if _should_destroy:
		request_destroy()
	elif not _has_lifecycle_component():
		request_destroy()

func _has_lifecycle_component() -> bool:
	for child in get_children():
		if child.get("manages_lifecycle"):
			return true
	return false

func reset_for_pool() -> void:
	_should_destroy = false
	# 断开 Hitbox 碰撞连接
	var hitbox = get_node_or_null("Hitbox") as Hitbox
	if hitbox and hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.disconnect(_on_hitbox_area_entered)
	for child in get_children():
		if child.has_method("reset"):
			child.reset()
	_cleanup_sprite()

func request_destroy() -> void:
	SceneFactory.call_deferred("release_projectile", self)

func _setup_sprite() -> void:
	_cleanup_sprite()
	if not data or data.sprite_path.is_empty():
		return
	var texture: Texture2D = load(data.sprite_path)
	if not texture:
		return
	var sprite := Sprite2D.new()
	sprite.name = "_PooledSprite"
	sprite.texture = texture
	add_child(sprite)

func _cleanup_sprite() -> void:
	var old_sprite = get_node_or_null("_PooledSprite")
	if old_sprite:
		old_sprite.queue_free()
```

- [ ] **Step 4: 运行测试确认通过**

- [ ] **Step 5: 创建投射物场景**

使用 gdai-mcp 或手动创建 4 个 .tscn 场景文件。每个场景结构如 spec 所述。

**arrow.tscn：**
- Root: Projectile (Node2D, script: `projectile.gd`)
- Children: Hitbox (Area2D, layer=4, mask=128) → CollisionShape2D (CircleShape2D r=2), LinearMovementComponent, TrailComponent (trail_color=WHITE, trail_width=1, max_points=4), KnockbackOnHitComponent (force=40)

**shuriken.tscn：**
- Root: Projectile (Node2D, script: `projectile.gd`)
- Children: Hitbox (Area2D, layer=4, mask=128) → CollisionShape2D (CircleShape2D r=3), LinearMovementComponent, TrailComponent, RotationComponent (rotation_speed=10), BounceOnHitComponent (bounce_range=150, max_bounces=1)

**pea_bullet.tscn：**
- Root: Projectile (Node2D, script: `projectile.gd`)
- Children: Hitbox (Area2D, layer=4, mask=128) → CollisionShape2D (CircleShape2D r=2), LinearMovementComponent

**ice_bullet.tscn：**
- Root: Projectile (Node2D, script: `projectile.gd`)
- Children: Hitbox (Area2D, layer=4, mask=128) → CollisionShape2D (CircleShape2D r=2), LinearMovementComponent, SlowOnHitComponent (slow_ratio=0.3, slow_duration=1.5)

- [ ] **Step 6: 更新 projectile .tres 的 projectile_scene 引用**

每个 .tres 文件更新 `projectile_scene` 指向对应新场景：
- `arrow.tres` → `res://scenes/entities/projectiles/arrow.tscn`
- `shuriken.tres` → `res://scenes/entities/projectiles/shuriken.tscn`
- `pea_bullet.tres` → `res://scenes/entities/projectiles/pea_bullet.tscn`
- `ice_bullet.tres` → `res://scenes/entities/projectiles/ice_bullet.tscn`

- [ ] **Step 7: 提交**

```bash
git add scripts/entities/projectiles/projectile.gd scenes/entities/projectiles/ resources/projectiles/ tests/unit/test_projectile_new.gd
git commit -m "feat: 组件化投射物系统（Projectile 基座 + 4 个场景 + 测试）"
```

---

## Chunk 4: 塔系统重构

### Task 11: 统一 Tower 基座

**Files:**
- Modify: `scripts/entities/towers/tower.gd` — 重写为统一基座
- Modify: `scenes/entities/towers/tower_pea_shooter.tscn`
- Modify: `scenes/entities/towers/tower_ice_flower.tscn`
- Modify: `scenes/entities/towers/tower_sunflower.tscn`

- [ ] **Step 1: 重写 tower.gd**

将 `tower.gd` 重写为统一基座，通过 `get_node_or_null()` 自动检测并初始化组件：

```gdscript
# scripts/entities/towers/tower.gd
class_name Tower
extends StaticBody2D

signal tower_destroyed(tower_type: String, position: Vector2)

var data: TowerData = null
var tower_type: String = ""
var current_level: int = 1
var damage_mult: float = 1.0
var speed_mult: float = 1.0

@onready var visual: AnimatedSprite2D = $Visual
@onready var health: HealthComponent = $HealthComponent

var _attack_component: Node = null  # RangedAttackComponent 或 MeleeAttackComponent
var _buff_sources: Dictionary = {}

func _ready() -> void:
	# 血量初始化
	var idx: int = current_level - 1
	health.initialize(data.hp_per_level[idx])
	health.died.connect(_on_died)

	# 自动检测攻击组件
	_attack_component = get_node_or_null("RangedAttackComponent")
	if not _attack_component:
		_attack_component = get_node_or_null("MeleeAttackComponent")
	if _attack_component and data.attack_config:
		_attack_component.attack_config = data.attack_config
		if _attack_component is RangedAttackComponent:
			_attack_component.projectile_data = data.projectile_data
			_attack_component.attack_executed.connect(_on_attack_executed)
			_attack_component.projectile_spawned.connect(_on_projectile_spawned)
			# ice_flower per_level slow 覆写
			if data.slow_ratio_per_level.size() > 0:
				_attack_component.on_projectile_created = func(proj: Node2D) -> void:
					var slow_comp = proj.get_node_or_null("SlowOnHitComponent")
					if slow_comp:
						slow_comp.slow_ratio = data.slow_ratio_per_level[idx]
						slow_comp.slow_duration = data.slow_duration_per_level[idx]
		_attack_component.set_level(current_level)
		# 塔基础 multiplier
		var tower_mult: float = PlayerState.player_stats.get(Enums.Stat.TOWER_MULT, 1.0)
		_buff_sources["_base_tower_mult"] = {dmg = tower_mult, spd = 1.0}
		_recalc_buffs()

	# 自动检测生成组件
	var generator = get_node_or_null("GeneratorComponent")
	if generator and data.generator_config:
		generator.config = data.generator_config
		generator.set_level(current_level)
		generator.generated.connect(_on_generated)

	_setup_level_glow()
	add_to_group(Enums.Group.TOWERS)

func _process(delta: float) -> void:
	if _attack_component and _attack_component.has_method("tick"):
		_attack_component.tick(delta)

func apply_buff(dmg_mult: float, spd_mult: float, source_id: String) -> void:
	_buff_sources[source_id] = {dmg = dmg_mult, spd = spd_mult}
	_recalc_buffs()

func remove_buff(source_id: String) -> void:
	_buff_sources.erase(source_id)
	_recalc_buffs()

func _recalc_buffs() -> void:
	damage_mult = 1.0
	speed_mult = 1.0
	for entry in _buff_sources.values():
		damage_mult *= entry.dmg
		speed_mult *= entry.spd
	if _attack_component:
		_attack_component.damage_multiplier = damage_mult
		_attack_component.speed_multiplier = speed_mult

func take_damage(amount: float, attacker: Node2D = null) -> void:
	health.take_damage(amount, attacker)

func play_attack_animation() -> void:
	if visual.sprite_frames and visual.sprite_frames.has_animation("attack"):
		visual.play("attack")
		if not visual.animation_finished.is_connected(_on_attack_animation_finished):
			visual.animation_finished.connect(_on_attack_animation_finished, CONNECT_ONE_SHOT)

func _on_attack_executed(_target: Node2D, _proj: Node2D = null) -> void:
	play_attack_animation()

func _on_projectile_spawned(proj: Node2D) -> void:
	get_parent().add_child(proj)

func _on_generated(amount: int, pos: Vector2) -> void:
	EventBus.coins_generated.emit(amount, pos)
	play_attack_animation()

func _on_died() -> void:
	tower_destroyed.emit(tower_type, global_position)
	queue_free()

func _on_attack_animation_finished() -> void:
	visual.play("idle")

func _setup_level_glow() -> void:
	if current_level < 2:
		return
	var glow_path: String = "res://assets/towers/lv%d_glow.png" % current_level
	var glow_texture: Texture2D = load(glow_path)
	if not glow_texture:
		return
	var glow := Sprite2D.new()
	glow.texture = glow_texture
	glow.z_index = -1
	add_child(glow)
```

- [ ] **Step 2: 更新塔场景文件**

使用 gdai-mcp 修改每个塔场景：

**tower_pea_shooter.tscn：**
- 根节点 script → `tower.gd`（原来是 `tower_shooter.gd`）
- 添加子节点：TargetFinderComponent（script: `target_finder_component.gd`）
- 添加子节点：RangedAttackComponent（script: `ranged_attack_component.gd`）
- 移除原有 DetectArea（TargetFinderComponent 自己创建）

**tower_ice_flower.tscn：** 同 pea_shooter 结构

**tower_sunflower.tscn：**
- 根节点 script → `tower.gd`（原来是 `tower_generator.gd`）
- 添加子节点：GeneratorComponent（script: `generator_component.gd`）
- 移除原有 GenerateTimer

- [ ] **Step 3: 运行现有塔相关测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_tower_buff.gd -gexit`
Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_tower_level.gd -gexit`

修改测试以适配新接口（如有必要）。

- [ ] **Step 4: 提交**

```bash
git add scripts/entities/towers/tower.gd scenes/entities/towers/
git commit -m "refactor: 统一 Tower 基座 — 组件自动检测，移除 TowerShooter/TowerGenerator 子类"
```

---

## Chunk 5: 武器系统重构

### Task 12: 重写 WeaponManager（Pivot + Offset）

**Files:**
- Modify: `scripts/entities/weapons/weapon_manager.gd` — 完全重写

- [ ] **Step 1: 重写 weapon_manager.gd**

```gdscript
# scripts/entities/weapons/weapon_manager.gd
class_name WeaponManager
extends Node2D

const ORBIT_SPEED: float = TAU / 8.0
const SPRITE_SCALE: float = 6.0

var _pivots: Array[Node2D] = []
var _weapon_data_list: Array[WeaponData] = []
var _orbit_angle: float = 0.0
var _projectile_container: Node = null
var _weapon_drag_callback: Callable

# 武器精灵颜色映射（后备方案，无 icon 时使用）
const WEAPON_COLORS: Dictionary = {
	"bow": Color.GREEN,
	"shuriken": Color.CORNFLOWER_BLUE,
	"sword": Color.RED,
}

func _ready() -> void:
	# 缓存投射物容器（避免 get_parent() 链）
	_projectile_container = get_parent().get_parent() if get_parent() else null

func initialize(weapon_entries: Array[Dictionary]) -> void:
	_clear_all()
	for entry in weapon_entries:
		add_weapon(entry.id, entry.level)

func add_weapon(weapon_id: String, level: int) -> void:
	if not GameConfig.weapons.has(weapon_id):
		push_error("Unknown weapon: " + weapon_id)
		return
	var weapon_data: WeaponData = GameConfig.weapons[weapon_id]
	_weapon_data_list.append(weapon_data)

	# 创建 Pivot
	var pivot := Node2D.new()
	pivot.name = "WeaponPivot_%d" % _pivots.size()
	add_child(pivot)

	# 创建 TargetFinderComponent
	var finder := TargetFinderComponent.new()
	finder.name = "TargetFinderComponent"
	pivot.add_child(finder)

	# 创建攻击组件
	if weapon_data.projectile_data:
		var ranged := RangedAttackComponent.new()
		ranged.name = "RangedAttackComponent"
		ranged.attack_config = weapon_data.attack_config
		ranged.projectile_data = weapon_data.projectile_data
		ranged.projectile_spawned.connect(_on_projectile_spawned)
		ranged.attack_executed.connect(func(_t: Node2D, _p: Node2D) -> void:
			_on_attack_executed(pivot, weapon_data)
		)
		pivot.add_child(ranged)
		ranged.set_level(level)
	elif weapon_data.melee_config:
		var melee := MeleeAttackComponent.new()
		melee.name = "MeleeAttackComponent"
		melee.attack_config = weapon_data.attack_config
		melee.melee_config = weapon_data.melee_config
		melee.attack_executed.connect(func(_t: Node2D) -> void:
			_on_attack_executed(pivot, weapon_data)
		)
		pivot.add_child(melee)
		melee.set_level(level)

	# 创建 Offset + Sprite + FirePoint
	var offset := Node2D.new()
	offset.name = "WeaponOffset"
	offset.position = Vector2(weapon_data.pivot_offset, 0)
	pivot.add_child(offset)

	var sprite := Sprite2D.new()
	sprite.name = "WeaponSprite"
	_setup_weapon_sprite(sprite, weapon_id)
	offset.add_child(sprite)

	var fire_point := Marker2D.new()
	fire_point.name = "FirePoint"
	offset.add_child(fire_point)

	# 点击拖拽区域（商店阶段）
	_setup_click_area(sprite, _pivots.size())

	_pivots.append(pivot)
	# 注入被动 multiplier
	_apply_passive_to_pivot(pivot)
	_redistribute_angles()

func remove_weapon(index: int) -> void:
	if index < 0 or index >= _pivots.size():
		return
	var pivot: Node2D = _pivots[index]
	_pivots.remove_at(index)
	_weapon_data_list.remove_at(index)
	pivot.queue_free()
	_redistribute_angles()

func refresh_weapons() -> void:
	_clear_all()
	for entry in InventoryManager.deployed_weapons:
		add_weapon(entry.id, entry.level)

func tick(delta: float) -> void:
	_orbit_angle += ORBIT_SPEED * delta
	for i in _pivots.size():
		var pivot: Node2D = _pivots[i]
		# 更新 Pivot 旋转
		var finder = pivot.get_node_or_null("TargetFinderComponent")
		var target: Node2D = finder.get_target() if finder else null
		if target and is_instance_valid(target):
			pivot.look_at(target.global_position)
		else:
			var base_angle: float = _orbit_angle + (TAU / _pivots.size()) * i
			pivot.rotation = base_angle
		# 驱动攻击组件
		var attack = pivot.get_node_or_null("RangedAttackComponent")
		if not attack:
			attack = pivot.get_node_or_null("MeleeAttackComponent")
		if attack:
			attack.tick(delta)

func set_weapon_drag_callback(callback: Callable) -> void:
	_weapon_drag_callback = callback

func set_input_enabled(enabled: bool) -> void:
	# 控制是否响应拖拽
	pass

func _on_projectile_spawned(proj: Node2D) -> void:
	if _projectile_container:
		_projectile_container.add_child(proj)
	elif get_parent():
		get_parent().get_parent().add_child(proj)

func _on_attack_executed(pivot: Node2D, weapon_data: WeaponData) -> void:
	if weapon_data.hide_sprite_on_fire:
		var sprite = pivot.get_node_or_null("WeaponOffset/WeaponSprite")
		if sprite:
			sprite.visible = false
			# 定时恢复
			var attack = pivot.get_node_or_null("RangedAttackComponent")
			if attack:
				var restore_time: float = attack.get_final_cooldown() * weapon_data.sprite_restore_ratio
				get_tree().create_timer(restore_time).timeout.connect(func() -> void:
					if is_instance_valid(sprite):
						sprite.visible = true
				)

func _apply_passive_to_pivot(pivot: Node2D) -> void:
	var dmg_mult: float = PlayerState.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var spd_mult: float = PlayerState.player_stats.get(Enums.Stat.ATTACK_SPEED_MULT, 1.0)
	var attack = pivot.get_node_or_null("RangedAttackComponent")
	if not attack:
		attack = pivot.get_node_or_null("MeleeAttackComponent")
	if attack:
		attack.damage_multiplier = dmg_mult
		attack.speed_multiplier = spd_mult

func _redistribute_angles() -> void:
	# 均匀分布 Pivot 角度
	for i in _pivots.size():
		# 仅设置初始角度偏移，实际旋转由 tick() 控制
		pass

func _clear_all() -> void:
	for pivot in _pivots:
		pivot.queue_free()
	_pivots.clear()
	_weapon_data_list.clear()

func _setup_weapon_sprite(sprite: Sprite2D, weapon_id: String) -> void:
	# 尝试从 WeaponData icon_path 加载纹理
	var weapon_data: WeaponData = GameConfig.weapons.get(weapon_id)
	if weapon_data and not weapon_data.icon_path.is_empty():
		var tex: Texture2D = load(weapon_data.icon_path)
		if tex:
			sprite.texture = tex
			return
	# 后备：彩色圆点
	var img := Image.create(SPRITE_SCALE as int, SPRITE_SCALE as int, false, Image.FORMAT_RGBA8)
	var color: Color = WEAPON_COLORS.get(weapon_id, Color.WHITE)
	img.fill(color)
	sprite.texture = ImageTexture.create_from_image(img)

func _setup_click_area(sprite: Sprite2D, index: int) -> void:
	var click_area := Area2D.new()
	click_area.name = "ClickArea"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 12)
	shape.shape = rect
	click_area.add_child(shape)
	click_area.input_event.connect(func(_vp: Node, event: InputEvent, _idx: int) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _weapon_drag_callback.is_valid():
				_weapon_drag_callback.call(index)
	)
	sprite.add_child(click_area)
```

- [ ] **Step 2: 修改现有武器测试适配新接口**

更新 `tests/unit/test_weapon_manager.gd` 中的测试，移除对旧 Weapon 类和 AttackerComponent 的引用。

- [ ] **Step 3: 运行测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_weapon_manager.gd -gexit`

- [ ] **Step 4: 提交**

```bash
git add scripts/entities/weapons/weapon_manager.gd tests/unit/test_weapon_manager.gd
git commit -m "refactor: WeaponManager Pivot+Offset 重构 — 消除 Weapon/ShurikenWeapon 子类"
```

---

## Chunk 6: 集成适配 + 清理

### Task 13: SceneFactory 适配

**Files:**
- Modify: `scripts/core/scene_factory.gd`

- [ ] **Step 1: 更新 create_projectile 签名**

移除 `extra_pierce` 参数：
```gdscript
# 旧签名
func create_projectile(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2, extra_pierce: int = 0) -> ProjectileBase:

# 新签名
func create_projectile(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2) -> Projectile:
```

更新内部实现：移除 `extra_pierce` 传递给 `setup()`。`setup()` 签名也已变更（4 参数）。

- [ ] **Step 2: 更新池 key 生成**

`_get_projectile_pool_key()` 从 `p_data.projectile_scene.resource_path` 提取场景名作为 key。新场景路径变更：
- 旧：`res://scenes/entities/projectiles/bullet_projectile.tscn` → key `projectile_bullet_projectile`
- 新：`res://scenes/entities/projectiles/arrow.tscn` → key `projectile_arrow`
- 新：`res://scenes/entities/projectiles/pea_bullet.tscn` → key `projectile_pea_bullet`
- 等

由于 key 由场景路径自动生成，只要 .tres 中的 `projectile_scene` 引用指向新场景即可，无需修改 key 生成逻辑。`warmup_initial()` 遍历 `GameConfig.weapons`/`GameConfig.towers` 获取 `projectile_data.projectile_scene` 自动注册新池。

- [ ] **Step 3: 移除旧场景引用**

移除对 `bullet_projectile.tscn` 和 `shuriken_projectile.tscn` 的引用。

- [ ] **Step 4: 更新 warmup 逻辑**

`warmup_initial()` 和 `warmup_for_wave()` 中，遍历所有 WeaponData/TowerData 的 `projectile_data.projectile_scene` 注册池。

- [ ] **Step 5: 提交**

```bash
git add scripts/core/scene_factory.gd
git commit -m "refactor: SceneFactory 适配组件化投射物（移除 extra_pierce，更新池 key）"
```

### Task 14: player.gd 适配

**Files:**
- Modify: `scripts/entities/player.gd`

- [ ] **Step 1: 更新被动 multiplier 注入**

player.gd 中原来通过 `weapon.attacker.damage_multiplier` 注入被动，现在通过 WeaponManager（它内部设置 RangedAttackComponent/MeleeAttackComponent 的 multiplier）。

检查 `_apply_passive_to_weapon()` 相关调用，确认 WeaponManager 已处理被动注入。

- [ ] **Step 2: 更新 combo 被动（swift_combo）**

Kaze 的 `update_combo_target()` 原来由 weapon 调用。新架构中需要通过 RangedAttackComponent 的 `attack_executed` 信号触发。

检查 `get_combo_damage_mult()` 和 `get_blood_rage_mult()` 的调用点，确保与新组件兼容。

- [ ] **Step 3: 运行全量测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

- [ ] **Step 4: 提交**

```bash
git add scripts/entities/player.gd
git commit -m "refactor: player.gd 适配组件化武器系统（被动 multiplier 注入）"
```

### Task 15: main.gd 适配

**Files:**
- Modify: `scripts/ui/main.gd`

- [ ] **Step 1: 移除 TowerShooter/TowerGenerator 类型引用**

搜索 `main.gd` 中对 `TowerShooter`、`TowerGenerator` 类名的引用，替换为 `Tower`（或移除类型检查）。

- [ ] **Step 2: 确认 EventBus 信号连接正确**

`coins_generated` 信号现在由 GeneratorComponent → tower.gd → EventBus 传递，确认 main.gd 监听不受影响。

- [ ] **Step 3: 提交**

```bash
git add scripts/ui/main.gd
git commit -m "refactor: main.gd 适配统一 Tower 类型"
```

### Task 16: 删除旧文件 + 更新测试

**Files:**
- Delete: `scripts/components/attacker_component.gd`
- Delete: `scripts/entities/weapons/weapon.gd`
- Delete: `scripts/entities/weapons/shuriken_weapon.gd`
- Delete: `scripts/entities/towers/tower_shooter.gd`
- Delete: `scripts/entities/towers/tower_generator.gd`
- Delete: `scripts/entities/projectiles/projectile_base.gd`
- Delete: `scripts/entities/projectiles/shuriken_projectile.gd`
- Delete: `scenes/entities/projectiles/bullet_projectile.tscn`
- Delete: `scenes/entities/projectiles/shuriken_projectile.tscn`
- Modify: existing test files

- [ ] **Step 1: 删除旧脚本和场景**

```bash
git rm scripts/components/attacker_component.gd
git rm scripts/entities/weapons/weapon.gd
git rm scripts/entities/weapons/shuriken_weapon.gd
git rm scripts/entities/towers/tower_shooter.gd
git rm scripts/entities/towers/tower_generator.gd
git rm scripts/entities/projectiles/projectile_base.gd
git rm scripts/entities/projectiles/shuriken_projectile.gd
git rm scenes/entities/projectiles/bullet_projectile.tscn
git rm scenes/entities/projectiles/shuriken_projectile.tscn
```

- [ ] **Step 2: 更新/删除旧测试**

- `test_attacker_component.gd` — 删除（被 test_ranged_attack_component.gd 和 test_melee_attack_component.gd 替代）
- `test_projectile.gd` — 重写为基于新 Projectile 类的测试
- `test_shuriken_projectile.gd` — 删除（弹射行为由 test_projectile_components.gd 覆盖）
- `test_weapon.gd` — 重写为基于新 Pivot+Offset 结构的测试
- `test_weapon_config.gd` — 更新 WeaponData 字段引用
- `test_weapon_level.gd` — 更新为 AttackConfigData
- `test_tower_buff.gd` — 更新为新 tower.gd
- `test_tower_level.gd` — 更新为新 tower.gd

- [ ] **Step 3: 更新 global_script_class_cache.cfg**

**推荐方式**：打开 Godot 编辑器一次，它会自动重新生成此文件。仅在无法打开编辑器时才手动编辑。

新增带 `class_name` 的脚本后需更新缓存：
- TargetFinderComponent
- RangedAttackComponent
- MeleeAttackComponent
- GeneratorComponent
- LinearMovementComponent
- TrailComponent
- RotationComponent
- SlowOnHitComponent
- KnockbackOnHitComponent
- PierceComponent
- BounceOnHitComponent
- Projectile
- AttackConfigData
- GeneratorConfigData

移除旧 class_name：
- AttackerComponent
- ShurikenWeapon
- TowerShooter
- TowerGenerator
- ProjectileBase
- ShurikenProjectile

- [ ] **Step 4: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: ALL PASS

- [ ] **Step 5: 提交**

```bash
git add -A
git commit -m "chore: 删除旧继承类（AttackerComponent/ShurikenWeapon/TowerShooter 等）+ 更新测试"
```

### Task 17: 最终验证

- [ ] **Step 1: 在 Godot 编辑器中运行项目**

使用 gdai-mcp 的 `play_scene` 工具或手动运行，验证：
1. 角色选择 → 地图选择 → main 场景正常加载
2. 商店阶段：可购买弓/手里剑/剑，武器精灵环绕玩家
3. 战斗阶段：武器自动索敌开火，投射物飞行正常
4. 弓箭有击退效果，手里剑有弹射效果
5. 购买射手塔/冰花塔/向日葵，放置正常
6. 冰花塔投射物有减速效果
7. 向日葵定时生成金币
8. 合成系统正常（3 同级合成升级）
9. 手里剑开火时精灵隐藏，冷却后恢复

- [ ] **Step 2: 运行全量测试最终确认**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: ALL PASS

- [ ] **Step 3: 最终提交**

```bash
git commit --allow-empty -m "chore: 组件化战斗系统重构完成 — 验证通过"
```
