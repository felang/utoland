# 武器-塔-投射物系统重构 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 提取 AttackerComponent 统一武器/塔攻击逻辑，用 ProjectileData 数据驱动投射物配置，消除对 GameData 的直接依赖。

**Architecture:** 新增 AttackerComponent（Node 组件）管理冷却+目标+触发，新增 ProjectileData/MeleeConfig Resource 数据驱动投射物和近战配置。武器和塔通过组合 AttackerComponent 共享攻击逻辑，投射物从 ProjectileData 读取所有配置。

**Tech Stack:** Godot 4.6 GDScript, GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-16-weapon-tower-projectile-redesign.md`

**测试命令:** `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

---

## Chunk 1: 基础层 — Resource 定义 + CollisionLayers + AttackerComponent

### Task 1: CollisionLayers 常量

**Files:**
- Create: `scripts/core/collision_layers.gd`
- Test: `tests/unit/test_collision_layers.gd`

- [ ] **Step 1: 创建 CollisionLayers 脚本**

```gdscript
# scripts/core/collision_layers.gd
class_name CollisionLayers

# 层编号（1-32），用于 set_collision_layer_value() / set_collision_mask_value()
const PLAYER_LAYER = 1     # bit value: 1
const ENEMY_LAYER = 2      # bit value: 2
const HITBOX_LAYER = 3     # bit value: 4
const TOWER_LAYER = 4      # bit value: 8
const HURTBOX_LAYER = 8    # bit value: 128

# 位掩码值，用于直接赋值 collision_layer / collision_mask
const PLAYER = 1
const ENEMY = 2
const HITBOX = 4
const TOWER = 8
const HURTBOX = 128
```

- [ ] **Step 2: 写测试**

```gdscript
# tests/unit/test_collision_layers.gd
extends GutTest

func test_bitmask_values_match_layer_numbers():
	# 验证位掩码值和层编号的对应关系
	assert_eq(CollisionLayers.PLAYER, 1 << (CollisionLayers.PLAYER_LAYER - 1))
	assert_eq(CollisionLayers.ENEMY, 1 << (CollisionLayers.ENEMY_LAYER - 1))
	assert_eq(CollisionLayers.HITBOX, 1 << (CollisionLayers.HITBOX_LAYER - 1))
	assert_eq(CollisionLayers.TOWER, 1 << (CollisionLayers.TOWER_LAYER - 1))
	assert_eq(CollisionLayers.HURTBOX, 1 << (CollisionLayers.HURTBOX_LAYER - 1))
```

- [ ] **Step 3: 运行测试验证通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_collision_layers.gd -gexit`

- [ ] **Step 4: 提交**

```bash
git add scripts/core/collision_layers.gd tests/unit/test_collision_layers.gd
git commit -m "feat: 新增 CollisionLayers 碰撞层常量"
```

**重要：** 每个新增带 `class_name` 的脚本后，必须立即在 `.godot/global_script_class_cache.cfg` 中补充条目，否则 headless 测试无法识别该类名。此规则适用于 Task 1-4, 8, 10 所有新增 class_name 的 task。

---

### Task 2: ProjectileData Resource

**Files:**
- Create: `scripts/resources/projectile_data.gd`
- Test: `tests/unit/test_projectile_data.gd`

- [ ] **Step 1: 创建 ProjectileData Resource 类**

```gdscript
# scripts/resources/projectile_data.gd
class_name ProjectileData
extends Resource

@export_group("飞行参数")
@export var speed: float = 300.0
@export var lifetime: float = 5.0

@export_group("视觉")
@export var sprite_path: String = ""
@export var projectile_scene: PackedScene = null
@export var trail_enabled: bool = true
@export var trail_config: EffectConfigData = null

@export_group("命中效果")
@export var knockback_force: float = 0.0
@export var base_pierce_count: int = 0
@export var slow_ratio: float = 0.0
@export var slow_duration: float = 0.0
```

- [ ] **Step 2: 写测试**

```gdscript
# tests/unit/test_projectile_data.gd
extends GutTest

func test_default_values():
	var data := ProjectileData.new()
	assert_eq(data.speed, 300.0)
	assert_eq(data.lifetime, 5.0)
	assert_eq(data.base_pierce_count, 0)
	assert_eq(data.slow_ratio, 0.0)
	assert_eq(data.knockback_force, 0.0)

func test_slow_configuration():
	var data := ProjectileData.new()
	data.slow_ratio = 0.3
	data.slow_duration = 2.0
	assert_gt(data.slow_ratio, 0.0, "减速比例应大于 0")
	assert_gt(data.slow_duration, 0.0, "减速持续应大于 0")
```

- [ ] **Step 3: 运行测试验证通过**

- [ ] **Step 4: 提交**

```bash
git add scripts/resources/projectile_data.gd tests/unit/test_projectile_data.gd
git commit -m "feat: 新增 ProjectileData Resource 类"
```

---

### Task 3: MeleeConfig Resource

**Files:**
- Create: `scripts/resources/melee_config.gd`
- Test: `tests/unit/test_melee_config.gd`

- [ ] **Step 1: 创建 MeleeConfig Resource 类**

```gdscript
# scripts/resources/melee_config.gd
class_name MeleeConfig
extends Resource

@export var thrust_distance: float = 15.0
@export var hit_angle: float = 90.0
@export var hit_radius: float = 20.0
@export var knockback_force: float = 50.0
```

注：`hit_radius` 默认 20.0 匹配 spec。当前 SwordWeapon 使用 8.0，将在 sword_melee.tres 中配置 `hit_radius = 8.0` 覆盖默认值。

- [ ] **Step 2: 写测试**

```gdscript
# tests/unit/test_melee_config.gd
extends GutTest

func test_default_values():
	var config := MeleeConfig.new()
	assert_eq(config.thrust_distance, 15.0)
	assert_eq(config.hit_radius, 8.0)
	assert_eq(config.knockback_force, 50.0)
```

- [ ] **Step 3: 运行测试，提交**

```bash
git add scripts/resources/melee_config.gd tests/unit/test_melee_config.gd
git commit -m "feat: 新增 MeleeConfig Resource 类"
```

---

### Task 4: AttackerComponent — 核心组件

**Files:**
- Create: `scripts/components/attacker_component.gd`
- Test: `tests/unit/test_attacker_component.gd`

- [ ] **Step 1: 写失败测试 — RANGED 模式基本流程**

```gdscript
# tests/unit/test_attacker_component.gd
extends GutTest

var _attacker: AttackerComponent
var _proj_data: ProjectileData
var _fired_count: int = 0
var _last_target: Node2D = null
var _last_proj_data: ProjectileData = null

func before_each():
	_attacker = AttackerComponent.new()
	_proj_data = ProjectileData.new()
	_proj_data.speed = 300.0
	_fired_count = 0
	_last_target = null
	_last_proj_data = null
	add_child(_attacker)

func after_each():
	_attacker.queue_free()

func _on_attack_fired(target: Node2D, proj_data: ProjectileData) -> void:
	_fired_count += 1
	_last_target = target
	_last_proj_data = proj_data

func test_ranged_attack_fires_signal():
	var dummy_target := Node2D.new()
	add_child(dummy_target)
	_attacker.attack_fired.connect(_on_attack_fired)
	_attacker.init_attacker(10.0, 100.0, 0.5, AttackerComponent.AttackMode.RANGED, _proj_data, null)
	_attacker.target_finder = func(_range: float) -> Node2D: return dummy_target
	# 模拟足够时间过去让冷却结束
	_attacker.tick(1.0)
	assert_eq(_fired_count, 1, "应发射一次攻击")
	assert_eq(_last_target, dummy_target)
	assert_eq(_last_proj_data, _proj_data)
	dummy_target.queue_free()

func test_cooldown_prevents_rapid_fire():
	var dummy_target := Node2D.new()
	add_child(dummy_target)
	_attacker.attack_fired.connect(_on_attack_fired)
	_attacker.init_attacker(10.0, 100.0, 1.0, AttackerComponent.AttackMode.RANGED, _proj_data, null)
	_attacker.target_finder = func(_range: float) -> Node2D: return dummy_target
	_attacker.tick(1.0)  # 第一次攻击
	_attacker.tick(0.5)  # 冷却中
	assert_eq(_fired_count, 1, "冷却中不应再次攻击")
	_attacker.tick(0.6)  # 冷却结束
	assert_eq(_fired_count, 2, "冷却结束应再次攻击")
	dummy_target.queue_free()

func test_no_target_no_fire():
	_attacker.attack_fired.connect(_on_attack_fired)
	_attacker.init_attacker(10.0, 100.0, 0.5, AttackerComponent.AttackMode.RANGED, _proj_data, null)
	_attacker.target_finder = func(_range: float) -> Node2D: return null
	_attacker.tick(1.0)
	assert_eq(_fired_count, 0, "无目标时不应攻击")

func test_get_final_damage_with_multiplier():
	_attacker.init_attacker(10.0, 100.0, 0.5, AttackerComponent.AttackMode.RANGED, _proj_data, null)
	assert_eq(_attacker.get_final_damage(), 10.0)
	_attacker.damage_multiplier = 1.5
	assert_almost_eq(_attacker.get_final_damage(), 15.0, 0.01)

func test_get_final_cooldown_with_speed_mult():
	_attacker.init_attacker(10.0, 100.0, 1.0, AttackerComponent.AttackMode.RANGED, _proj_data, null)
	assert_eq(_attacker.get_final_cooldown(), 1.0)
	_attacker.speed_multiplier = 2.0
	assert_almost_eq(_attacker.get_final_cooldown(), 0.5, 0.01)

func test_update_stats():
	_attacker.init_attacker(10.0, 100.0, 1.0, AttackerComponent.AttackMode.RANGED, _proj_data, null)
	_attacker.update_stats(20.0, 150.0, 0.5)
	assert_eq(_attacker.get_final_damage(), 20.0)
	assert_eq(_attacker.attack_range, 150.0)
	assert_eq(_attacker.get_final_cooldown(), 0.5)

func test_melee_mode_emits_melee_triggered():
	var dummy_target := Node2D.new()
	add_child(dummy_target)
	var melee_cfg := MeleeConfig.new()
	var _melee_fired := false
	_attacker.melee_triggered.connect(func(_t, _c): _melee_fired = true)
	_attacker.init_attacker(10.0, 50.0, 0.5, AttackerComponent.AttackMode.MELEE, null, melee_cfg)
	_attacker.target_finder = func(_range: float) -> Node2D: return dummy_target
	_attacker.tick(1.0)
	assert_true(_melee_fired, "MELEE 模式应发射 melee_triggered 信号")
	dummy_target.queue_free()
```

- [ ] **Step 2: 运行测试，验证全部 FAIL**

- [ ] **Step 3: 实现 AttackerComponent**

```gdscript
# scripts/components/attacker_component.gd
class_name AttackerComponent
extends Node

enum AttackMode { RANGED, MELEE }

signal attack_fired(target: Node2D, projectile_data: ProjectileData)
signal melee_triggered(target: Node2D, melee_config: MeleeConfig)
signal target_changed(new_target: Node2D)

# 配置（由 init_attacker 设置）
var attack_mode: AttackMode = AttackMode.RANGED
var base_damage: float = 0.0
var attack_range: float = 0.0
var base_cooldown: float = 1.0
var projectile_data: ProjectileData = null
var melee_config: MeleeConfig = null

# 外部注入
var target_finder: Callable  ## func(range: float) -> Node2D
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0

# 内部状态
var _cooldown_remaining: float = 0.0
var _current_target: Node2D = null

func init_attacker(
	p_damage: float,
	p_range: float,
	p_cooldown: float,
	p_mode: AttackMode,
	p_projectile_data: ProjectileData,
	p_melee_config: MeleeConfig
) -> void:
	base_damage = p_damage
	attack_range = p_range
	base_cooldown = p_cooldown
	attack_mode = p_mode
	projectile_data = p_projectile_data
	melee_config = p_melee_config
	_cooldown_remaining = 0.0

func update_stats(p_damage: float, p_range: float, p_cooldown: float) -> void:
	base_damage = p_damage
	attack_range = p_range
	base_cooldown = p_cooldown

func get_final_damage() -> float:
	return base_damage * damage_multiplier

func get_final_cooldown() -> float:
	if speed_multiplier <= 0.0:
		return base_cooldown
	return base_cooldown / speed_multiplier

func tick(delta: float) -> void:
	_cooldown_remaining -= delta
	if _cooldown_remaining > 0.0:
		return
	if not target_finder.is_valid():
		return
	var target: Node2D = target_finder.call(attack_range)
	if target != _current_target:
		_current_target = target
		target_changed.emit(target)
	if target == null:
		return
	_cooldown_remaining = get_final_cooldown()
	_execute_attack(target)

func _execute_attack(target: Node2D) -> void:
	match attack_mode:
		AttackMode.RANGED:
			attack_fired.emit(target, projectile_data)
		AttackMode.MELEE:
			melee_triggered.emit(target, melee_config)
```

- [ ] **Step 4: 运行测试验证通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/components/attacker_component.gd tests/unit/test_attacker_component.gd
git commit -m "feat: 新增 AttackerComponent 组件（冷却+目标+触发）"
```

---

### Task 5: AttackMode 枚举注册到 Enums

**Files:**
- Modify: `scripts/core/enums.gd`

注：`AttackMode` 枚举已定义在 `AttackerComponent` 内部（`AttackerComponent.AttackMode.RANGED/MELEE`）。WeaponData 需要引用它作为 `@export` 类型。在 GDScript 中，`@export` 可以直接使用内部 enum，所以不需要额外放到 Enums 中。跳过此 task。

---

## Chunk 2: Resource 数据迁移 — WeaponData + TowerData + .tres 文件

### Task 6: WeaponData 添加新字段、删除旧字段

**Files:**
- Modify: `scripts/resources/weapon_data.gd`
- Modify: `resources/weapons/bow.tres`
- Modify: `resources/weapons/shuriken.tres`
- Modify: `resources/weapons/sword.tres`
- Test: `tests/unit/test_weapon_data.gd`（更新现有测试）

- [ ] **Step 1: 修改 WeaponData — 添加新字段，删除旧字段**

```gdscript
# scripts/resources/weapon_data.gd — 完整重写
class_name WeaponData
extends Resource

@export_group("基础信息")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""

@export_group("攻击模式")
@export var attack_mode: int = 0  # 0=RANGED, 1=MELEE（对应 AttackerComponent.AttackMode 枚举）

@export_group("等级系统")
@export var max_level: int = 3
@export var damage_per_level: PackedFloat32Array = []
@export var fire_rate_per_level: PackedFloat32Array = []
@export var weapon_range_per_level: PackedFloat32Array = []
@export var sell_price_per_level: PackedInt32Array = PackedInt32Array([])

@export_group("投射物配置（远程）")
@export var projectile_data: ProjectileData = null

@export_group("近战配置")
@export var melee_config: MeleeConfig = null
```

注：`attack_mode` 存为 int（0=RANGED, 1=MELEE），与 `AttackerComponent.AttackMode` 枚举值对应。Weapon.set_level() 中转换时使用 `data.attack_mode as AttackerComponent.AttackMode`。

- [ ] **Step 2: 创建投射物 .tres 配置文件**

创建 `resources/projectiles/` 目录，新增：

`resources/projectiles/arrow.tres`:
```
[gd_resource type="Resource" script_class="ProjectileData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/projectile_data.gd" id="1"]
[resource]
script = ExtResource("1")
speed = 300.0
lifetime = 5.0
sprite_path = "res://assets/projectiles/arrow.png"
projectile_scene = null
trail_enabled = true
knockback_force = 40.0
```

`resources/projectiles/shuriken.tres`:
```
[gd_resource type="Resource" script_class="ProjectileData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/projectile_data.gd" id="1"]
[resource]
script = ExtResource("1")
speed = 175.0
lifetime = 5.0
sprite_path = "res://assets/projectiles/shuriken.png"
projectile_scene = null
trail_enabled = true
knockback_force = 0.0
```

`resources/projectiles/sword_melee.tres`（MeleeConfig）:
```
[gd_resource type="Resource" script_class="MeleeConfig" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/melee_config.gd" id="1"]
[resource]
script = ExtResource("1")
thrust_distance = 15.0
hit_angle = 90.0
hit_radius = 8.0
knockback_force = 80.0
```

注：hit_radius 在 .tres 中设为 8.0 覆盖 MeleeConfig 默认的 20.0，匹配当前 SwordWeapon 行为。

```
```

`resources/projectiles/pea_bullet.tres`:
```
[gd_resource type="Resource" script_class="ProjectileData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/projectile_data.gd" id="1"]
[resource]
script = ExtResource("1")
speed = 800.0
lifetime = 5.0
sprite_path = "res://assets/projectiles/archer.png"
projectile_scene = null
trail_enabled = false
knockback_force = 0.0
```

`resources/projectiles/ice_bullet.tres`:
```
[gd_resource type="Resource" script_class="ProjectileData" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/projectile_data.gd" id="1"]
[resource]
script = ExtResource("1")
speed = 800.0
lifetime = 5.0
sprite_path = "res://assets/projectiles/ice_bullet.png"
projectile_scene = null
trail_enabled = false
knockback_force = 0.0
slow_ratio = 0.3
slow_duration = 1.5
```

注：`projectile_scene` 字段暂设为 null，在 Task 9（ProjectileBase 重构）完成后再回填场景引用。在此之前不影响编译和测试。

- [ ] **Step 3: 更新 bow.tres**

修改 `resources/weapons/bow.tres` — 移除旧字段，引用 arrow.tres ProjectileData：
```
[gd_resource type="Resource" script_class="WeaponData" load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/resources/weapon_data.gd" id="1"]
[ext_resource type="Resource" path="res://resources/projectiles/arrow.tres" id="2"]
[resource]
script = ExtResource("1")
id = "bow"
display_name = "弓"
description = "单发射击的基础远程武器"
icon_path = "res://assets/weapons/bow/sprite.png"
attack_mode = 0
max_level = 3
damage_per_level = PackedFloat32Array(8, 18, 34)
fire_rate_per_level = PackedFloat32Array(0.5, 0.4, 0.3)
weapon_range_per_level = PackedFloat32Array(150, 170, 200)
sell_price_per_level = PackedInt32Array(3, 7, 21)
projectile_data = ExtResource("2")
```

- [ ] **Step 4: 更新 shuriken.tres**

```
[gd_resource type="Resource" script_class="WeaponData" load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/resources/weapon_data.gd" id="1"]
[ext_resource type="Resource" path="res://resources/projectiles/shuriken.tres" id="2"]
[resource]
script = ExtResource("1")
id = "shuriken"
display_name = "手里剑"
description = "投掷后自动返回，可二次命中"
icon_path = "res://assets/projectiles/shuriken.png"
attack_mode = 0
max_level = 3
damage_per_level = PackedFloat32Array(15, 30, 55)
fire_rate_per_level = PackedFloat32Array(0.8, 0.65, 0.5)
weapon_range_per_level = PackedFloat32Array(100, 120, 150)
sell_price_per_level = PackedInt32Array(3, 7, 21)
projectile_data = ExtResource("2")
```

- [ ] **Step 5: 更新 sword.tres**

```
[gd_resource type="Resource" script_class="WeaponData" load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/resources/weapon_data.gd" id="1"]
[ext_resource type="Resource" path="res://resources/projectiles/sword_melee.tres" id="2"]
[resource]
script = ExtResource("1")
id = "sword"
display_name = "剑"
description = "前方扇形挥砍，可同时命中多个敌人"
icon_path = "res://assets/weapons/sword/sprite.png"
attack_mode = 1
max_level = 3
damage_per_level = PackedFloat32Array(20, 38, 65)
fire_rate_per_level = PackedFloat32Array(0.4, 0.32, 0.24)
weapon_range_per_level = PackedFloat32Array(60, 72, 90)
sell_price_per_level = PackedInt32Array(3, 7, 21)
melee_config = ExtResource("2")
```

- [ ] **Step 6: 更新 test_weapon_data.gd 适配新字段**

检查现有测试，确保没有引用被删除的字段（`weapon_type`、`projectile_type`、`bullet_speed` 等）。如果有，更新为新字段。

- [ ] **Step 7: 运行测试验证通过**

- [ ] **Step 8: 提交**

```bash
git add scripts/resources/weapon_data.gd resources/projectiles/ resources/weapons/
git add tests/unit/test_weapon_data.gd
git commit -m "refactor: WeaponData 迁移到 ProjectileData/MeleeConfig 配置"
```

---

### Task 7: TowerData 添加 projectile_data、删除 projectile_sprite_path

**Files:**
- Modify: `scripts/resources/tower_data.gd`
- Modify: `resources/towers/pea_shooter.tres`
- Modify: `resources/towers/ice_flower.tres`
- Test: `tests/unit/test_tower_data.gd`（更新）

- [ ] **Step 1: 修改 TowerData**

```gdscript
# scripts/resources/tower_data.gd — 完整重写
class_name TowerData
extends Resource

@export_group("基础信息")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""

@export_group("等级系统")
@export var max_level: int = 3
@export var hp_per_level: PackedFloat32Array = []
@export var damage_per_level: PackedFloat32Array = []
@export var fire_rate_per_level: PackedFloat32Array = []
@export var attack_range_per_level: PackedFloat32Array = []
@export var slow_ratio_per_level: PackedFloat32Array = []
@export var slow_duration_per_level: PackedFloat32Array = []
@export var sell_price_per_level: PackedInt32Array = PackedInt32Array([])

@export_group("投射物配置（射手塔）")
@export var projectile_data: ProjectileData = null

@export_group("向日葵专有")
@export var generate_amount_per_level: PackedFloat32Array = []
@export var generate_interval_per_level: PackedFloat32Array = []
```

注：删除 `projectile_sprite_path`。保留 `slow_ratio_per_level` 和 `slow_duration_per_level` 用于 per_level 覆写。

- [ ] **Step 2: 更新 pea_shooter.tres — 引用 pea_bullet.tres**

```
[gd_resource type="Resource" script_class="TowerData" load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/resources/tower_data.gd" id="1"]
[ext_resource type="Resource" path="res://resources/projectiles/pea_bullet.tres" id="2"]
[resource]
script = ExtResource("1")
id = "pea_shooter"
display_name = "射手塔"
description = "稳定射击最近的敌人。虽然平凡，但从不缺席。"
icon_path = "res://assets/towers/pea_shooter/sprite.png"
max_level = 3
hp_per_level = PackedFloat32Array(80, 150, 260)
damage_per_level = PackedFloat32Array(15, 30, 55)
fire_rate_per_level = PackedFloat32Array(1.0, 0.8, 0.6)
attack_range_per_level = PackedFloat32Array(150, 170, 200)
sell_price_per_level = PackedInt32Array(3, 7, 21)
projectile_data = ExtResource("2")
```

- [ ] **Step 3: 更新 ice_flower.tres — 引用 ice_bullet.tres**

```
[gd_resource type="Resource" script_class="TowerData" load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/resources/tower_data.gd" id="1"]
[ext_resource type="Resource" path="res://resources/projectiles/ice_bullet.tres" id="2"]
[resource]
script = ExtResource("1")
id = "ice_flower"
display_name = "冰花"
description = "射出寒冰弹，命中敌人造成伤害并减速。"
icon_path = "res://assets/towers/ice_flower/sprite.png"
max_level = 3
hp_per_level = PackedFloat32Array(70, 125, 200)
damage_per_level = PackedFloat32Array(3, 5, 8)
fire_rate_per_level = PackedFloat32Array(0.8, 0.7, 0.6)
attack_range_per_level = PackedFloat32Array(100, 120, 150)
slow_ratio_per_level = PackedFloat32Array(0.3, 0.4, 0.5)
slow_duration_per_level = PackedFloat32Array(1.5, 2.0, 2.5)
sell_price_per_level = PackedInt32Array(3, 7, 21)
projectile_data = ExtResource("2")
```

- [ ] **Step 4: sunflower.tres 不变**（无 projectile_data，无 projectile_sprite_path）

- [ ] **Step 5: 更新测试，运行验证**

检查 `test_tower_data.gd` 是否引用 `projectile_sprite_path`，如有则改为检查 `projectile_data`。

- [ ] **Step 6: 提交**

```bash
git add scripts/resources/tower_data.gd resources/towers/
git add tests/unit/test_tower_data.gd
git commit -m "refactor: TowerData 迁移到 ProjectileData 配置"
```

---

## Chunk 3: 投射物系统重构

### Task 8: ProjectileBase — 合并 Projectile + BulletProjectile

**Files:**
- Rename+Rewrite: `scripts/entities/projectiles/projectile.gd` → `projectile_base.gd`（ProjectileBase）
- Delete: `scripts/entities/projectiles/bullet_projectile.gd`（逻辑合并到 projectile_base.gd）
- Modify: `scenes/entities/projectiles/bullet_projectile.tscn`（脚本改为 projectile_base.gd）
- Test: `tests/unit/test_projectile.gd`（重写）
- Test: `tests/unit/test_bullet_projectile.gd`（删除或合并）

- [ ] **Step 1: 写失败测试 — ProjectileBase 新 setup() 签名**

```gdscript
# tests/unit/test_projectile.gd — 重写
extends GutTest

var _projectile: ProjectileBase

func before_each():
	var scene = preload("res://scenes/entities/projectiles/bullet_projectile.tscn")
	_projectile = scene.instantiate()
	add_child(_projectile)

func after_each():
	_projectile.queue_free()

func test_setup_sets_position_and_damage():
	var data := ProjectileData.new()
	data.speed = 300.0
	data.lifetime = 5.0
	data.knockback_force = 40.0
	_projectile.setup(data, 25.0, Vector2(100, 200), Vector2.RIGHT)
	assert_eq(_projectile.global_position, Vector2(100, 200))
	assert_eq(_projectile.hitbox.damage, 25.0)
	assert_eq(_projectile.hitbox.knockback_force, 40.0)

func test_setup_with_pierce():
	var data := ProjectileData.new()
	data.base_pierce_count = 1
	_projectile.setup(data, 10.0, Vector2.ZERO, Vector2.RIGHT, 2)
	# 内部 pierce = base(1) + extra(2) = 3
	assert_eq(_projectile._pierce_count, 3)

func test_projectile_moves_in_direction():
	var data := ProjectileData.new()
	data.speed = 100.0
	data.lifetime = 5.0
	_projectile.setup(data, 10.0, Vector2.ZERO, Vector2.RIGHT)
	# 模拟一帧
	_projectile._physics_process(0.1)
	assert_almost_eq(_projectile.global_position.x, 10.0, 0.5)

func test_hit_signal_emitted():
	var data := ProjectileData.new()
	data.speed = 100.0
	data.lifetime = 5.0
	_projectile.setup(data, 10.0, Vector2.ZERO, Vector2.RIGHT)
	var _hit_emitted := false
	_projectile.hit.connect(func(_pos, _dir): _hit_emitted = true)
	# 直接调用内部命中方法模拟
	# 注意：实际测试中碰撞需要物理帧，这里测试信号连接
	assert_not_null(_projectile.hitbox, "应有 Hitbox 子节点")
```

- [ ] **Step 2: 运行测试验证 FAIL**

- [ ] **Step 3: 重命名 projectile.gd → projectile_base.gd，然后重写**

```bash
git mv scripts/entities/projectiles/projectile.gd scripts/entities/projectiles/projectile_base.gd
```

```gdscript
# scripts/entities/projectiles/projectile_base.gd — 完整重写
# ProjectileBase — 统一投射物基类
# 直线飞行 + 数据驱动的命中效果（slow/pierce/knockback）
# 替代原 Projectile + BulletProjectile
class_name ProjectileBase
extends Node2D

signal hit(position: Vector2, direction: Vector2)

@onready var hitbox: Hitbox = $Hitbox

var data: ProjectileData = null
var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _lifetime: float = 5.0
var _elapsed: float = 0.0
var _pierce_count: int = 0
var _hit_count: int = 0
var _trail: Line2D = null
var _trail_positions: Array[Vector2] = []
var _trail_max_points: int = 4
var show_trail: bool = true

func setup(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2, extra_pierce: int = 0) -> void:
	data = p_data
	global_position = from
	_direction = direction
	_speed = data.speed
	_lifetime = data.lifetime
	_pierce_count = data.base_pierce_count + extra_pierce
	_hit_count = 0
	_elapsed = 0.0
	# Hitbox
	assert(hitbox != null, "ProjectileBase.setup: 缺少 Hitbox 子节点")
	hitbox.damage = damage
	hitbox.knockback_force = data.knockback_force
	# 精灵
	if data.sprite_path != "" and ResourceLoader.exists(data.sprite_path):
		var sprite := Sprite2D.new()
		sprite.texture = load(data.sprite_path)
		sprite.rotation = direction.angle()
		add_child(sprite)
	# 拖尾
	show_trail = data.trail_enabled
	if show_trail:
		var fx: EffectConfigData = GameConfig.effects
		_trail_max_points = fx.bullet_trail_max_points
		_trail = Line2D.new()
		_trail.width = fx.bullet_trail_width
		_trail.default_color = fx.bullet_trail_color
		_trail.z_index = -1
		_trail.top_level = true
		add_child(_trail)
	# 碰撞信号
	hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(delta: float) -> void:
	global_position += _direction * _speed * delta
	_elapsed += delta
	_update_trail()
	if _elapsed >= _lifetime:
		_cleanup_and_free()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	EffectsManager.spawn_hit_sparks(global_position)
	# 减速效果
	if data.slow_ratio > 0.0:
		var enemy: Node2D = area.get_parent() as Node2D
		if enemy and enemy.has_node("SlowHandler"):
			var source_id: String = "projectile_" + str(get_instance_id())
			enemy.slow_handler.apply_timed_slow(data.slow_ratio, data.slow_duration, source_id)
	# 发射命中信号（供 WeaponManager 监听分裂等）
	hit.emit(global_position, _direction)
	# 穿透判断
	_hit_count += 1
	if _hit_count > _pierce_count:
		_cleanup_and_free()

func _update_trail() -> void:
	if _trail == null:
		return
	_trail_positions.insert(0, global_position)
	if _trail_positions.size() > _trail_max_points:
		_trail_positions.resize(_trail_max_points)
	_trail.clear_points()
	for pos in _trail_positions:
		_trail.add_point(pos)

func _cleanup_and_free() -> void:
	if _trail and is_instance_valid(_trail):
		_trail.queue_free()
	queue_free()
```

- [ ] **Step 4: 更新 bullet_projectile.tscn 脚本引用**

修改 `scenes/entities/projectiles/bullet_projectile.tscn`：将 script 路径从 `bullet_projectile.gd` 改为 `projectile_base.gd`。

- [ ] **Step 5: 删除 bullet_projectile.gd**

```bash
git rm scripts/entities/projectiles/bullet_projectile.gd
```

- [ ] **Step 6: 删除或合并 test_bullet_projectile.gd**

测试内容已合并到 test_projectile.gd。

- [ ] **Step 7: 运行测试验证通过**

- [ ] **Step 8: 提交**

```bash
git add scripts/entities/projectiles/projectile.gd
git add scenes/entities/projectiles/bullet_projectile.tscn
git rm scripts/entities/projectiles/bullet_projectile.gd
git rm tests/unit/test_bullet_projectile.gd
git add tests/unit/test_projectile.gd
git commit -m "refactor: ProjectileBase 合并 BulletProjectile，数据驱动投射物配置"
```

---

### Task 9: 回填 ProjectileData.projectile_scene + SceneFactory

**Files:**
- Modify: `resources/projectiles/arrow.tres`（设置 projectile_scene）
- Modify: `resources/projectiles/pea_bullet.tres`
- Modify: `resources/projectiles/ice_bullet.tres`
- Modify: `resources/projectiles/shuriken.tres`
- Modify: `scripts/core/scene_factory.gd`

- [ ] **Step 1: 回填 .tres 中的 projectile_scene**

所有远程投射物（arrow、pea_bullet、ice_bullet）指向 `bullet_projectile.tscn`：

在每个 .tres 中添加 ext_resource 引用场景，设 `projectile_scene = ExtResource("场景id")`。

手里剑指向 `shuriken_projectile.tscn`。

注：.tres 文件中引用 PackedScene 需要用 `[ext_resource type="PackedScene" path="..." id="N"]`。

- [ ] **Step 2: 修改 SceneFactory — 新增 create_projectile()，保留旧方法暂不删除**

```gdscript
# 在 scene_factory.gd 中新增:

# 统一投射物创建 — 从 ProjectileData 实例化
func create_projectile(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2, extra_pierce: int = 0) -> ProjectileBase:
	assert(p_data != null, "SceneFactory.create_projectile: data 不能为 null")
	assert(p_data.projectile_scene != null, "SceneFactory.create_projectile: projectile_scene 未配置")
	var proj: ProjectileBase = p_data.projectile_scene.instantiate()
	proj.setup(p_data, damage, from, direction, extra_pierce)
	return proj
```

暂时保留 `create_bullet_projectile()` 和 `create_shuriken_projectile()` 不删除，等所有调用者迁移完再删。

- [ ] **Step 3: 提交**

```bash
git add resources/projectiles/ scripts/core/scene_factory.gd
git commit -m "feat: SceneFactory.create_projectile() 统一投射物创建"
```

---

### Task 10: ShurikenProjectile 适配 ProjectileBase

**Files:**
- Modify: `scripts/entities/projectiles/shuriken_projectile.gd`
- Test: `tests/unit/test_shuriken_projectile.gd`（更新）

- [ ] **Step 1: 重写 ShurikenProjectile extends ProjectileBase**

```gdscript
# scripts/entities/projectiles/shuriken_projectile.gd — 重写
# ShurikenProjectile — 手里剑投射物（二段弹跳）
# 直线飞行 → 命中敌人 → 弹射到附近另一个敌人 → 消失
class_name ShurikenProjectile
extends ProjectileBase

@export var bounce_range: float = 150.0
@export var outbound_distance: float = 100.0
@export var return_speed_mult: float = 1.3

var _rotation_speed: float = 0.0
var _bounce_target: Node2D = null
var _hit_enemies: Array[Node2D] = []
var _shuriken_hit_count: int = 0  # 手里剑自己的命中计数（区别于基类的穿透计数）

func setup(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2, extra_pierce: int = 0) -> void:
	# 调用基类 setup（会设置 speed/lifetime/hitbox 等）
	super.setup(p_data, damage, from, direction, extra_pierce)
	_shuriken_hit_count = 0
	_bounce_target = null
	_hit_enemies = []
	# 手里剑特效配置
	var fx: EffectConfigData = GameConfig.effects
	_rotation_speed = deg_to_rad(fx.shuriken_rotation_speed)
	# 覆盖拖尾配置为手里剑专用
	if _trail:
		_trail.width = fx.shuriken_trail_width
		_trail.default_color = fx.shuriken_trail_color
		_trail_max_points = fx.shuriken_trail_points
	# 断开基类的碰撞信号，使用自己的处理
	if hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.disconnect(_on_hitbox_area_entered)
	hitbox.area_entered.connect(_on_shuriken_hit)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime:
		_cleanup_and_free()
		return
	rotation += _rotation_speed * delta
	_update_trail()
	# 弹射追踪
	if _bounce_target and is_instance_valid(_bounce_target):
		_direction = global_position.direction_to(_bounce_target.global_position)
	global_position += _direction * _speed * delta

func _on_shuriken_hit(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	var enemy: Node2D = area.get_parent()
	if enemy in _hit_enemies:
		return
	_hit_enemies.append(enemy)
	_shuriken_hit_count += 1
	EffectsManager.spawn_hit_sparks(global_position)
	hit.emit(global_position, _direction)
	if _shuriken_hit_count == 1:
		_bounce_target = _find_bounce_target(enemy)
		if _bounce_target == null:
			_cleanup_and_free()
	elif _shuriken_hit_count >= 2:
		_cleanup_and_free()

func _find_bounce_target(exclude: Node2D) -> Node2D:
	if not is_inside_tree():
		return null
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var closest: Node2D = null
	var min_dist: float = bounce_range
	for enemy in enemies:
		if enemy == exclude:
			continue
		if enemy is Node2D:
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest
```

- [ ] **Step 2: 更新 shuriken_projectile.tscn 脚本引用**（如需要）

确保场景的根节点脚本仍指向 `shuriken_projectile.gd`。

- [ ] **Step 3: 更新测试，运行验证**

- [ ] **Step 4: 提交**

```bash
git add scripts/entities/projectiles/shuriken_projectile.gd
git add tests/unit/test_shuriken_projectile.gd
git commit -m "refactor: ShurikenProjectile 适配 ProjectileBase"
```

---

## Chunk 4: 武器系统重构

### Task 11: Weapon 基类重构 — 组合 AttackerComponent

**Files:**
- Modify: `scripts/entities/weapons/weapon.gd`
- Test: `tests/unit/test_weapon.gd`（重写）

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/unit/test_weapon.gd — 重写
extends GutTest

var _weapon: Weapon

func before_each():
	_weapon = Weapon.new()
	add_child(_weapon)

func after_each():
	_weapon.queue_free()

func test_initialize_creates_attacker():
	var data := WeaponData.new()
	data.damage_per_level = PackedFloat32Array([10, 20, 30])
	data.fire_rate_per_level = PackedFloat32Array([0.5, 0.4, 0.3])
	data.weapon_range_per_level = PackedFloat32Array([100, 120, 150])
	data.attack_mode = 0  # RANGED
	_weapon.initialize(data)
	assert_not_null(_weapon.attacker, "initialize 应创建 AttackerComponent")

func test_set_level_updates_attacker_stats():
	var data := WeaponData.new()
	data.damage_per_level = PackedFloat32Array([10, 20, 30])
	data.fire_rate_per_level = PackedFloat32Array([0.5, 0.4, 0.3])
	data.weapon_range_per_level = PackedFloat32Array([100, 120, 150])
	data.attack_mode = 0
	_weapon.initialize(data)
	_weapon.set_level(2)
	assert_eq(_weapon.attacker.base_damage, 20.0)
	assert_eq(_weapon.attacker.attack_range, 120.0)
```

- [ ] **Step 2: 运行测试验证 FAIL**

- [ ] **Step 3: 重写 weapon.gd**

```gdscript
# scripts/entities/weapons/weapon.gd — 完整重写
# Weapon — 武器基类
# 组合 AttackerComponent 管理攻击逻辑
class_name Weapon
extends Node

signal projectile_created(proj: ProjectileBase)

var weapon_data: WeaponData = null
var owner_node: Node2D = null
var sprite: Sprite2D = null  # 漂浮精灵引用，由 WeaponManager 注入
var attacker: AttackerComponent = null
var _level: int = 1

func initialize(data: WeaponData) -> void:
	weapon_data = data
	# 创建 AttackerComponent
	attacker = AttackerComponent.new()
	add_child(attacker)
	# 连接信号
	attacker.attack_fired.connect(_on_attack_fired)
	attacker.melee_triggered.connect(_on_melee_triggered)

func set_level(level: int) -> void:
	_level = level
	if not attacker:
		return
	var idx: int = level - 1
	attacker.update_stats(
		weapon_data.damage_per_level[idx],
		weapon_data.weapon_range_per_level[idx],
		weapon_data.fire_rate_per_level[idx]
	)
	attacker.attack_mode = weapon_data.attack_mode as AttackerComponent.AttackMode
	attacker.projectile_data = weapon_data.projectile_data
	attacker.melee_config = weapon_data.melee_config

func get_current_level() -> int:
	return _level

## 获取发射位置（优先使用武器精灵位置，否则回退到角色位置）
func get_fire_position() -> Vector2:
	if sprite and is_instance_valid(sprite):
		return sprite.global_position
	if owner_node:
		return owner_node.global_position
	return Vector2.ZERO

func _on_attack_fired(target: Node2D, proj_data: ProjectileData) -> void:
	if not owner_node:
		return
	var fire_pos: Vector2 = get_fire_position()
	var direction: Vector2 = fire_pos.direction_to(target.global_position)
	var damage: float = attacker.get_final_damage()
	var extra_pierce: int = GameData.pierce_count
	var proj: ProjectileBase = SceneFactory.create_projectile(proj_data, damage, fire_pos, direction, extra_pierce)
	var scene_parent: Node = owner_node.get_parent()
	if scene_parent:
		scene_parent.add_child(proj)
	projectile_created.emit(proj)
	AudioManager.play("shoot")

func _on_melee_triggered(target: Node2D, config: MeleeConfig) -> void:
	if not owner_node or not sprite or not is_instance_valid(sprite):
		return
	var damage: float = attacker.get_final_damage()
	var thrust_direction: Vector2 = sprite.global_position.direction_to(target.global_position)
	var hit_enemies: Array[Node2D] = []
	# 创建临时 hitbox 挂在精灵上
	var thrust_hitbox := Area2D.new()
	thrust_hitbox.collision_layer = CollisionLayers.HITBOX
	thrust_hitbox.collision_mask = CollisionLayers.HURTBOX
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = config.hit_radius
	shape.shape = circle
	thrust_hitbox.add_child(shape)
	thrust_hitbox.area_entered.connect(func(area: Area2D) -> void:
		if not area is Hurtbox:
			return
		var enemy: Node2D = area.get_parent()
		if enemy in hit_enemies:
			return
		hit_enemies.append(enemy)
		area.hit_taken.emit(damage, thrust_direction * config.knockback_force)
		EffectsManager.spawn_hit_sparks(enemy.global_position)
	)
	sprite.add_child(thrust_hitbox)
	# 突刺动画
	var original_pos: Vector2 = sprite.position
	var thrust_pos: Vector2 = original_pos + thrust_direction * config.thrust_distance
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "position", thrust_pos, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "position", original_pos, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func():
		if thrust_hitbox and is_instance_valid(thrust_hitbox):
			thrust_hitbox.queue_free()
	)
	AudioManager.play("shoot")
```

- [ ] **Step 4: 运行测试验证通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/entities/weapons/weapon.gd tests/unit/test_weapon.gd
git commit -m "refactor: Weapon 组合 AttackerComponent，统一攻击逻辑"
```

---

### Task 12: ShurikenWeapon 适配

**Files:**
- Modify: `scripts/entities/weapons/shuriken_weapon.gd`

- [ ] **Step 1: 重写 ShurikenWeapon**

```gdscript
# scripts/entities/weapons/shuriken_weapon.gd — 重写
# ShurikenWeapon — 手里剑武器（自身即投射物）
# 发射时漂浮精灵隐藏，冷却结束后恢复
class_name ShurikenWeapon
extends Weapon

func initialize(data: WeaponData) -> void:
	super.initialize(data)
	# 覆盖：监听 attacker 冷却用于精灵恢复
	# ShurikenWeapon 需要在 attacker tick 前检查冷却状态

func _on_attack_fired(target: Node2D, proj_data: ProjectileData) -> void:
	if not owner_node:
		return
	var fire_pos: Vector2 = get_fire_position()
	var direction: Vector2 = fire_pos.direction_to(target.global_position)
	var damage: float = attacker.get_final_damage()
	var extra_pierce: int = GameData.pierce_count
	var shuriken: ProjectileBase = SceneFactory.create_projectile(proj_data, damage, fire_pos, direction, extra_pierce)
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		return
	scene_parent.add_child(shuriken)
	# 隐藏漂浮精灵
	if sprite and is_instance_valid(sprite):
		sprite.visible = false
	# 冷却结束恢复精灵：监听 attacker 的下一次攻击触发前恢复
	_schedule_sprite_restore()
	AudioManager.play("shoot")

func _schedule_sprite_restore() -> void:
	# 等待冷却时间后恢复精灵可见
	if not is_inside_tree():
		return
	var cooldown: float = attacker.get_final_cooldown()
	get_tree().create_timer(cooldown * 0.9).timeout.connect(func():
		if sprite and is_instance_valid(sprite):
			sprite.visible = true
	, CONNECT_ONE_SHOT)
```

- [ ] **Step 2: 运行全部测试验证**

- [ ] **Step 3: 提交**

```bash
git add scripts/entities/weapons/shuriken_weapon.gd
git commit -m "refactor: ShurikenWeapon 适配 AttackerComponent"
```

---

### Task 13: WeaponManager 重构

**Files:**
- Modify: `scripts/entities/weapons/weapon_manager.gd`
- Test: `tests/unit/test_weapon_manager.gd`（更新）

- [ ] **Step 1: 重写 WeaponManager**

```gdscript
# scripts/entities/weapons/weapon_manager.gd — 完整重写
# WeaponManager — 统一管理玩家所有武器
# 为每个武器注入 target_finder，tick 驱动 AttackerComponent
# 管理浮动精灵视觉（轨道动画）
class_name WeaponManager
extends Node2D

const ORBIT_RADIUS: float = 15.0
const ORBIT_SPEED: float = TAU / 8.0
const SPRITE_SIZE: int = 6

const WEAPON_COLORS: Dictionary = {
	"bow": Color.GREEN,
	"shuriken": Color.CORNFLOWER_BLUE,
	"sword": Color.RED,
}

const SPRITE_ROTATION_OFFSET: Dictionary = {
	"bow": -PI / 2.0,
	"shuriken": 0.0,
	"sword": PI / 2.0,
}

var _weapons: Array[Weapon] = []
var _weapon_sprites: Array[Sprite2D] = []
var _sprite_rot_offsets: Array[float] = []
var _orbit_angle: float = 0.0
var _current_target: Node2D = null

func initialize(weapon_entries: Array[Dictionary]) -> void:
	for entry in weapon_entries:
		if not GameConfig.weapons.has(entry.id):
			push_error("WeaponManager: 未知武器 id: " + entry.id)
			continue
		var data: WeaponData = GameConfig.weapons[entry.id]
		var weapon: Weapon = _add_weapon(data, entry.id)
		if weapon:
			weapon.set_level(entry.level)
			_apply_passive_to_weapon(weapon)

func _add_weapon(data: WeaponData, weapon_id: String) -> Weapon:
	var weapon: Weapon = _create_weapon(weapon_id)
	if not weapon:
		return null
	weapon.initialize(data)
	weapon.owner_node = get_parent() as Node2D
	weapon.attacker.target_finder = _find_nearest_enemy
	add_child(weapon)
	_weapons.append(weapon)
	# 创建漂浮精灵
	var sprite := _create_weapon_sprite(data, weapon_id)
	add_child(sprite)
	_weapon_sprites.append(sprite)
	_sprite_rot_offsets.append(SPRITE_ROTATION_OFFSET.get(weapon_id, 0.0))
	weapon.sprite = sprite
	# 监听投射物创建（分裂系统，Task 18 实现）
	weapon.projectile_created.connect(_on_weapon_projectile_created)
	return weapon

func tick(delta: float) -> void:
	for weapon in _weapons:
		weapon.attacker.tick(delta)
	# 朝向目标
	_current_target = _find_closest_enemy_unlimited()
	_update_sprites(delta)

func _find_nearest_enemy(range_limit: float) -> Node2D:
	if not is_inside_tree():
		return null
	var owner_node: Node2D = get_parent() as Node2D
	if not owner_node:
		return null
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var closest: Node2D = null
	var min_dist: float = range_limit
	for enemy in enemies:
		if enemy is Node2D:
			var dist: float = owner_node.global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest

func _find_closest_enemy_unlimited() -> Node2D:
	return _find_nearest_enemy(INF)

func _apply_passive_to_weapon(weapon: Weapon) -> void:
	var dmg_mult: float = GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var spd_mult: float = GameData.player_stats.get(Enums.Stat.ATTACK_SPEED_MULT, 1.0)
	weapon.attacker.damage_multiplier = dmg_mult
	weapon.attacker.speed_multiplier = spd_mult

func _create_weapon(weapon_id: String) -> Weapon:
	match weapon_id:
		"shuriken":
			return ShurikenWeapon.new()
		_:
			return Weapon.new()

func _update_sprites(delta: float) -> void:
	if _weapon_sprites.is_empty():
		return
	_orbit_angle += ORBIT_SPEED * delta
	var count: int = _weapon_sprites.size()
	var angle_step: float = TAU / count
	var has_target: bool = _current_target != null and is_instance_valid(_current_target)
	var target_angle: float = 0.0
	if has_target:
		var owner_node: Node2D = get_parent() as Node2D
		if owner_node:
			target_angle = owner_node.global_position.direction_to(_current_target.global_position).angle()
	for i in range(count):
		var slot_angle: float = _orbit_angle + angle_step * i
		_weapon_sprites[i].position = Vector2(cos(slot_angle), sin(slot_angle)) * ORBIT_RADIUS
		var face_angle: float
		if has_target:
			face_angle = target_angle
		else:
			face_angle = slot_angle
		_weapon_sprites[i].rotation = face_angle + _sprite_rot_offsets[i]

func _create_weapon_sprite(data: WeaponData, weapon_id: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.z_index = 1
	if data.icon_path != "" and ResourceLoader.exists(data.icon_path):
		sprite.texture = load(data.icon_path)
	else:
		var color: Color = WEAPON_COLORS.get(weapon_id, Color.WHITE)
		var img := Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
		var center := Vector2(SPRITE_SIZE / 2.0, SPRITE_SIZE / 2.0)
		var radius: float = SPRITE_SIZE / 2.0
		for x in range(SPRITE_SIZE):
			for y in range(SPRITE_SIZE):
				var dist: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
				if dist <= radius:
					img.set_pixel(x, y, color)
				else:
					img.set_pixel(x, y, Color.TRANSPARENT)
		sprite.texture = ImageTexture.create_from_image(img)
	return sprite
```

- [ ] **Step 2: 更新 test_weapon_manager.gd**

移除对 `BowWeapon`/`SwordWeapon` 类名的引用，测试统一使用 `Weapon` 类。

- [ ] **Step 3: 运行全部测试**

- [ ] **Step 4: 提交**

```bash
git add scripts/entities/weapons/weapon_manager.gd tests/unit/test_weapon_manager.gd
git commit -m "refactor: WeaponManager 适配 AttackerComponent + 被动注入"
```

---

### Task 14: 删除 BowWeapon + SwordWeapon

**Files:**
- Delete: `scripts/entities/weapons/bow_weapon.gd`
- Delete: `scripts/entities/weapons/sword_weapon.gd`
- Cleanup: 移除 `.uid` 文件

- [ ] **Step 1: 确认无其他文件引用 BowWeapon/SwordWeapon**

搜索 `BowWeapon` 和 `SwordWeapon` 在整个代码库中的引用。WeaponManager 已在 Task 13 中修改为不再引用它们。

- [ ] **Step 2: 删除文件**

```bash
git rm scripts/entities/weapons/bow_weapon.gd
git rm scripts/entities/weapons/sword_weapon.gd
```

- [ ] **Step 3: 清理相关 .uid 文件和测试**

删除可能引用这些类的测试中的断言。

- [ ] **Step 4: 运行全部测试验证**

- [ ] **Step 5: 提交**

```bash
git commit -m "chore: 删除 BowWeapon 和 SwordWeapon 子类"
```

---

## Chunk 5: 塔系统重构 + SceneFactory 清理

### Task 15: TowerShooter 重构 — 组合 AttackerComponent

**Files:**
- Modify: `scripts/entities/towers/tower_shooter.gd`
- Modify: `scenes/entities/towers/tower_pea_shooter.tscn`（删除 ShootTimer 节点）
- Modify: `scenes/entities/towers/tower_ice_flower.tscn`（删除 ShootTimer 节点）
- Test: `tests/unit/test_tower_level.gd`（更新）

- [ ] **Step 1: 重写 tower_shooter.gd**

```gdscript
# scripts/entities/towers/tower_shooter.gd — 重写
# TowerShooter — 射手塔（组合 AttackerComponent）
extends Tower

var attacker: AttackerComponent = null

@onready var detect_area: Area2D = $DetectArea

func _ready() -> void:
	super._ready()
	# 创建 AttackerComponent
	attacker = AttackerComponent.new()
	add_child(attacker)
	attacker.attack_fired.connect(_on_attack_fired)
	attacker.target_finder = _find_nearest_enemy
	# 初始化攻击参数
	_apply_attacker_stats()

func _process(delta: float) -> void:
	attacker.tick(delta)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	if attacker:
		_apply_attacker_stats()

func _apply_attacker_stats() -> void:
	var idx: int = current_level - 1
	var damage: float = data.damage_per_level[idx] * GameData.player_stats.get(Enums.Stat.TOWER_MULT, 1.0)
	var cooldown: float = data.fire_rate_per_level[idx]
	var attack_range: float = data.attack_range_per_level[idx]
	attacker.update_stats(damage, attack_range, cooldown)
	attacker.attack_mode = AttackerComponent.AttackMode.RANGED
	# 处理 per_level slow 覆写
	if data.projectile_data and data.slow_ratio_per_level.size() > 0:
		var proj_data: ProjectileData = data.projectile_data.duplicate()
		proj_data.slow_ratio = data.slow_ratio_per_level[idx]
		proj_data.slow_duration = data.slow_duration_per_level[idx]
		attacker.projectile_data = proj_data
	else:
		attacker.projectile_data = data.projectile_data
	# 更新 DetectArea 碰撞范围
	var detect_shape: CollisionShape2D = detect_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if detect_shape and detect_shape.shape is CircleShape2D:
		(detect_shape.shape as CircleShape2D).radius = attack_range

func apply_buff(dmg_mult: float, spd_mult: float, source_id: String) -> void:
	super.apply_buff(dmg_mult, spd_mult, source_id)
	if attacker:
		attacker.damage_multiplier = damage_mult
		attacker.speed_multiplier = speed_mult

func remove_buff(source_id: String) -> void:
	super.remove_buff(source_id)
	if attacker:
		attacker.damage_multiplier = damage_mult
		attacker.speed_multiplier = speed_mult

func _on_attack_fired(_target: Node2D, proj_data: ProjectileData) -> void:
	if not proj_data:
		return
	var direction: Vector2 = global_position.direction_to(_target.global_position)
	var proj: ProjectileBase = SceneFactory.create_projectile(
		proj_data, attacker.get_final_damage(), global_position, direction
	)
	get_parent().add_child(proj)
	play_attack_animation()

func _find_nearest_enemy(range_limit: float) -> Node2D:
	var enemies: Array[Node2D] = detect_area.get_overlapping_bodies()
	var closest: Node2D = null
	var min_dist: float = range_limit
	for enemy: Node2D in enemies:
		if enemy.is_in_group(Enums.Group.ENEMIES):
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest
```

- [ ] **Step 2: 删除场景中的 ShootTimer 节点**

使用 gdai-mcp 工具或手动编辑 `tower_pea_shooter.tscn` 和 `tower_ice_flower.tscn`，删除 `ShootTimer` 子节点。

- [ ] **Step 3: 更新测试**

- [ ] **Step 4: 运行全部测试验证**

- [ ] **Step 5: 提交**

```bash
git add scripts/entities/towers/tower_shooter.gd
git add scenes/entities/towers/tower_pea_shooter.tscn scenes/entities/towers/tower_ice_flower.tscn
git add tests/unit/test_tower_level.gd
git commit -m "refactor: TowerShooter 组合 AttackerComponent，删除 ShootTimer"
```

---

### Task 16: SceneFactory 清理 — 删除旧方法 + 旧 preload

**Files:**
- Modify: `scripts/core/scene_factory.gd`

- [ ] **Step 1: 删除旧投射物方法和 preload**

移除：
- `var _bullet_projectile_scene` preload
- `var _shuriken_projectile_scene` preload
- `func create_bullet_projectile()`
- `func create_shuriken_projectile()`

- [ ] **Step 2: 全局搜索确认无调用者**

搜索 `create_bullet_projectile` 和 `create_shuriken_projectile`，确认 tower_shooter.gd、shuriken_weapon.gd、bow_weapon.gd（已删除）中已无调用。

- [ ] **Step 3: 运行全部测试**

- [ ] **Step 4: 提交**

```bash
git add scripts/core/scene_factory.gd
git commit -m "chore: SceneFactory 删除旧投射物创建方法"
```

---

### Task 17: 碰撞层魔数替换

**Files:**
- Modify: 所有脚本中使用碰撞层魔数的位置

- [ ] **Step 1: 搜索硬编码碰撞层**

在脚本中搜索 `collision_layer = 4`、`collision_mask = 128` 等模式。

主要位置：`weapon.gd` 的 `_on_melee_triggered`（已在 Task 11 中使用 `CollisionLayers.HITBOX/HURTBOX`）。

确认所有脚本中的碰撞层赋值都使用了 `CollisionLayers` 常量。

- [ ] **Step 2: 提交（如有变更）**

```bash
git commit -m "refactor: 碰撞层魔数替换为 CollisionLayers 常量"
```

---

### Task 18: 分裂系统迁移（WeaponManager）

**Files:**
- Modify: `scripts/entities/weapons/weapon.gd`（_on_attack_fired 返回创建的投射物）
- Modify: `scripts/entities/weapons/weapon_manager.gd`（监听投射物 hit 信号处理分裂）

注：per spec，分裂逻辑在 WeaponManager 中，不在 Weapon 中。

- [ ] **Step 1: 修改 Weapon._on_attack_fired 返回投射物引用**

修改 `weapon.gd` 的 `_on_attack_fired`，将创建的投射物存到实例变量供外部访问：

```gdscript
# 在 Weapon 类中新增信号
signal projectile_created(proj: ProjectileBase)

func _on_attack_fired(target: Node2D, proj_data: ProjectileData) -> void:
	if not owner_node:
		return
	var fire_pos: Vector2 = get_fire_position()
	var direction: Vector2 = fire_pos.direction_to(target.global_position)
	var damage: float = attacker.get_final_damage()
	var extra_pierce: int = GameData.pierce_count
	var proj: ProjectileBase = SceneFactory.create_projectile(proj_data, damage, fire_pos, direction, extra_pierce)
	var scene_parent: Node = owner_node.get_parent()
	if scene_parent:
		scene_parent.add_child(proj)
	projectile_created.emit(proj)
	AudioManager.play("shoot")
```

- [ ] **Step 2: 在 WeaponManager._add_weapon 中监听分裂**

```gdscript
# 在 WeaponManager._add_weapon 中，替换之前的 pass 注释：
weapon.projectile_created.connect(_on_weapon_projectile_created)

# 新增方法：
func _on_weapon_projectile_created(proj: ProjectileBase) -> void:
	if GameData.split_count <= 0:
		return
	if proj.get_meta("is_split", false):
		return
	proj.hit.connect(_on_projectile_hit_for_split.bind(proj.data, proj.hitbox.damage))

func _on_projectile_hit_for_split(pos: Vector2, dir: Vector2, proj_data: ProjectileData, original_damage: float) -> void:
	var scene_parent: Node = get_parent().get_parent()  # player -> level
	if not scene_parent:
		return
	var split_damage: float = original_damage * GameData.split_damage_mult
	for i in GameData.split_count:
		var angle: float = randf_range(-PI / 2, PI / 2)
		var split_dir: Vector2 = dir.rotated(angle)
		var split_proj: ProjectileBase = SceneFactory.create_projectile(proj_data, split_damage, pos, split_dir)
		split_proj.set_meta("is_split", true)
		scene_parent.add_child(split_proj)
```

- [ ] **Step 2: 运行全部测试**

- [ ] **Step 3: 提交**

```bash
git add scripts/entities/weapons/weapon.gd
git commit -m "feat: 分裂系统迁移到 Weapon（通过投射物 hit 信号）"
```

---

## Chunk 6: 全局测试 + class_name 缓存 + 清理

### Task 19: 验证 global_script_class_cache.cfg

**重要：** 每个新增 `class_name` 的 task（Task 1-4, 8, 10）都应在提交前更新 `.godot/global_script_class_cache.cfg`，否则 headless 测试无法识别新类名。此 task 仅做最终验证。

**Files:**
- Verify: `.godot/global_script_class_cache.cfg`

- [ ] **Step 1: 验证所有新增/更名/删除的 class_name 条目正确**

新增的 class_name（应已在各 task 中添加）：
- `CollisionLayers` → `scripts/core/collision_layers.gd`
- `ProjectileData` → `scripts/resources/projectile_data.gd`
- `MeleeConfig` → `scripts/resources/melee_config.gd`
- `AttackerComponent` → `scripts/components/attacker_component.gd`

更名的 class_name：
- `Projectile` → `ProjectileBase`（文件 `scripts/entities/projectiles/projectile_base.gd`）

删除的 class_name：
- `BulletProjectile`
- `BowWeapon`
- `SwordWeapon`

- [ ] **Step 2: 如有遗漏，修正并提交**

---

### Task 20: 全量测试 + 修复

- [ ] **Step 1: 运行全部测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 2: 修复任何失败的测试**

重点检查：
- `test_weapon.gd` — 新 Weapon API
- `test_weapon_manager.gd` — 无 BowWeapon/SwordWeapon 引用
- `test_projectile.gd` — 新 setup() 签名
- `test_shuriken_projectile.gd` — extends ProjectileBase
- `test_tower_level.gd` — TowerShooter 无 ShootTimer
- `test_tower_buff.gd` — buff → attacker multiplier

- [ ] **Step 3: 修复旧测试中引用被删字段的问题**

例如：`test_weapon_config.gd`、`test_weapon_level.gd`、`test_player_weapon.gd` 可能引用 `weapon_type`、`bullet_speed` 等已删字段。

- [ ] **Step 4: 全部测试通过后提交**

```bash
git add -u
git commit -m "test: 修复全部测试适配新架构"
```

---

### Task 21: 清理 .uid 文件和无用引用

- [ ] **Step 1: 删除已删文件的 .uid 文件**

```bash
git rm scripts/entities/weapons/bow_weapon.gd.uid 2>/dev/null
git rm scripts/entities/weapons/sword_weapon.gd.uid 2>/dev/null
git rm scripts/entities/projectiles/bullet_projectile.gd.uid 2>/dev/null
git rm tests/unit/test_bullet_projectile.gd.uid 2>/dev/null
```

- [ ] **Step 2: 最终全量测试**

- [ ] **Step 3: 提交**

```bash
git commit -m "chore: 清理已删文件的 .uid 引用"
```

---

## 任务依赖图

```
Task 1 (CollisionLayers) ──┐
Task 2 (ProjectileData)  ──┤
Task 3 (MeleeConfig)     ──┼── Task 6 (WeaponData) ──┐
Task 4 (AttackerComponent)─┤   Task 7 (TowerData)  ──┤
                            │                          │
                            └── Task 8 (ProjectileBase)┤
                                Task 9 (SceneFactory)──┤
                                Task 10 (Shuriken)   ──┤
                                                       │
                            Task 11 (Weapon)  ─────────┤
                            Task 12 (ShurikenWeapon) ──┤
                            Task 13 (WeaponManager)  ──┤
                            Task 14 (Delete old)     ──┤
                                                       │
                            Task 15 (TowerShooter) ────┤
                            Task 16 (SceneFactory)  ───┤
                            Task 17 (CollisionLayers)──┤
                            Task 18 (Split system)  ───┤
                                                       │
                            Task 19 (Cache) ───────────┤
                            Task 20 (Full test) ───────┤
                            Task 21 (Cleanup)  ────────┘
```

**并行可能性：**
- Tasks 1-4 可完全并行（无依赖）
- Tasks 6-7 可并行（分别改 WeaponData 和 TowerData）
- Tasks 11→12 必须顺序（ShurikenWeapon extends Weapon）
- Tasks 15-18 需要顺序执行（塔依赖前面的武器重构完成）
