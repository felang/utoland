# 武器与植物塔扩充实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将武器从 3 种扩充至 10 种，植物塔从 3 种扩充至 15 种（全植物主题）。

**Architecture:** 配置驱动架构（.tres Resource），通过 SceneFactory 注入数据。新增 weapon_type 字段解决 Weapon 子类分发冲突。SlowHandler 重构为效果字典模式支持多源减速。HealthComponent 扩展 attacker 追踪支持荆棘反伤。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-13-weapon-tower-expansion-design.md`

---

## Chunk 1: Foundation — ID 改名 + 资源类扩展 + 组件重构

### Task 1: 塔 ID 改名迁移

改名 shooter→pea_shooter, wall→stump, slow→ice_flower。此任务必须在所有新增之前完成。

**Files:**
- Modify: `scripts/core/enums.gd:45-48` — TowerId 常量改名
- Modify: `scripts/entities/towers/tower.gd:6` — 默认值
- Modify: `scripts/entities/towers/tower_shooter.gd:12` — 硬编码 tower_type
- Modify: `scripts/entities/towers/tower_slow.gd:10` — 硬编码 tower_type
- Modify: `scripts/core/scene_factory.gd:4-8` — _tower_scenes 字典 key
- Modify: `scripts/core/game_config.gd` — SPRITES.towers 字典 key
- Rename: `resources/towers/shooter.tres` → `pea_shooter.tres` (内部 id 字段)
- Rename: `resources/towers/slow.tres` → `ice_flower.tres`
- Rename: `resources/towers/wall.tres` → `stump.tres`
- Rename: `scenes/entities/towers/tower_shooter.tscn` → `tower_pea_shooter.tscn`
- Rename: `scenes/entities/towers/tower_slow.tscn` → `tower_ice_flower.tscn`
- Rename: `scenes/entities/towers/tower_wall.tscn` → `tower_stump.tscn`
- Modify: 5 个 character .tres — default_tower 字段
- Modify: 全部涉及旧 ID 的测试文件

- [ ] **Step 1: 更新 Enums.TowerId 常量**

```gdscript
# scripts/core/enums.gd — TowerId class
class TowerId:
	const PEA_SHOOTER = "pea_shooter"
	const STUMP = "stump"
	const ICE_FLOWER = "ice_flower"
```

- [ ] **Step 2: 更新脚本中硬编码的塔类型**

```gdscript
# scripts/entities/towers/tower.gd:6
var tower_type: String = Enums.TowerId.STUMP

# scripts/entities/towers/tower_shooter.gd:12
tower_type = Enums.TowerId.PEA_SHOOTER

# scripts/entities/towers/tower_slow.gd:10
tower_type = Enums.TowerId.ICE_FLOWER
```

- [ ] **Step 3: 更新 SceneFactory _tower_scenes 字典**

```gdscript
# scripts/core/scene_factory.gd:4-8
var _tower_scenes: Dictionary = {
	Enums.TowerId.PEA_SHOOTER: preload("res://scenes/entities/towers/tower_pea_shooter.tscn"),
	Enums.TowerId.STUMP: preload("res://scenes/entities/towers/tower_stump.tscn"),
	Enums.TowerId.ICE_FLOWER: preload("res://scenes/entities/towers/tower_ice_flower.tscn")
}
```

- [ ] **Step 4: 更新 GameConfig SPRITES.towers 字典 key**

搜索 `GameConfig.gd` 中 SPRITES 字典下的 "towers" 部分，将 "shooter" → "pea_shooter", "wall" → "stump", "slow" → "ice_flower"。

- [ ] **Step 5: 重命名 .tres 资源文件并更新内部 id**

```bash
cd /Users/langtao/utoland
git mv resources/towers/shooter.tres resources/towers/pea_shooter.tres
git mv resources/towers/slow.tres resources/towers/ice_flower.tres
git mv resources/towers/wall.tres resources/towers/stump.tres
```

编辑每个 .tres 内部的 `id = "..."` 字段为新 ID。

- [ ] **Step 6: 重命名 .tscn 场景文件**

```bash
git mv scenes/entities/towers/tower_shooter.tscn scenes/entities/towers/tower_pea_shooter.tscn
git mv scenes/entities/towers/tower_slow.tscn scenes/entities/towers/tower_ice_flower.tscn
git mv scenes/entities/towers/tower_wall.tscn scenes/entities/towers/tower_stump.tscn
```

更新 .tscn 内部的脚本路径引用（如有 `[ext_resource]` 变化）。

- [ ] **Step 7: 更新 5 个角色 .tres 的 default_tower**

- `resources/characters/dora.tres` → default_tower = "pea_shooter"
- `resources/characters/gorg.tres` → default_tower = "stump"
- `resources/characters/kaze.tres` → default_tower = "ice_flower"
- `resources/characters/nemo.tres` → default_tower = "pea_shooter"
- `resources/characters/merlin.tres` → default_tower = "pea_shooter"

- [ ] **Step 8: 批量更新所有测试文件中的旧 ID**

用全局替换更新以下测试文件中所有 `Enums.TowerId.SHOOTER` → `Enums.TowerId.PEA_SHOOTER`，`WALL` → `STUMP`，`SLOW` → `ICE_FLOWER`，以及字符串 `"shooter"` → `"pea_shooter"` 等：

- `tests/unit/test_resource_loading.gd`
- `tests/unit/test_scene_factory.gd`
- `tests/unit/test_placement_panel.gd`
- `tests/unit/test_placement_grid_rules.gd`
- `tests/unit/test_entity_scene_dimensions.gd`
- `tests/unit/test_event_bus.gd`
- `tests/unit/test_tower_level.gd`
- `tests/unit/test_upgrade_generator.gd`
- `tests/integration/test_combat_flow.gd`
- `tests/integration/test_tower_placement.gd`

- [ ] **Step 9: 运行全部测试验证改名无回归**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 全部测试通过（314 个）

- [ ] **Step 10: 提交**

```bash
git add -A
git commit -m "refactor: 塔 ID 改名 shooter→pea_shooter, wall→stump, slow→ice_flower"
```

---

### Task 2: Enums 新增武器/塔/投射物常量

**Files:**
- Modify: `scripts/core/enums.gd:30-54`

- [ ] **Step 1: 在 WeaponId 中新增 7 个常量**

```gdscript
class WeaponId:
	const RIFLE = "rifle"
	const BOOMERANG = "boomerang"
	const LASER = "laser"
	const SHOTGUN = "shotgun"
	const MINIGUN = "minigun"
	const ROCKET = "rocket"
	const FLAMETHROWER = "flamethrower"
	const LIGHTNING = "lightning"
	const ICE_GUN = "ice_gun"
	const BLADE = "blade"
```

- [ ] **Step 2: 在 TowerId 中新增 12 个常量**

```gdscript
class TowerId:
	const PEA_SHOOTER = "pea_shooter"
	const STUMP = "stump"
	const ICE_FLOWER = "ice_flower"
	const CACTUS = "cactus"
	const ROSE = "rose"
	const MUSHROOM = "mushroom"
	const VINE = "vine"
	const DANDELION = "dandelion"
	const PITCHER = "pitcher"
	const THORN = "thorn"
	const OAK = "oak"
	const SUNFLOWER = "sunflower"
	const MINT = "mint"
	const HEAL_FLOWER = "heal_flower"
	const BAMBOO = "bamboo"
```

- [ ] **Step 3: 在 ProjectileId 中新增 4 个常量**

```gdscript
class ProjectileId:
	const BULLET = "bullet"
	const BOOMERANG = "boomerang"
	const LASER = "laser"
	const ROCKET = "rocket"
	const FLAME = "flame"
	const CHAIN = "chain"
	const MELEE = "melee"
```

- [ ] **Step 4: 运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 5: 提交**

```bash
git add scripts/core/enums.gd
git commit -m "feat: 新增武器/塔/投射物 Enums 常量"
```

---

### Task 3: WeaponData 扩展 — weapon_type + 新武器字段

**Files:**
- Modify: `scripts/resources/weapon_data.gd`
- Modify: `resources/weapons/rifle.tres` — 添加 weapon_type
- Modify: `resources/weapons/boomerang.tres` — 添加 weapon_type
- Modify: `resources/weapons/laser.tres` — 添加 weapon_type
- Test: `tests/unit/test_resource_loading.gd`

- [ ] **Step 1: 写测试 — weapon_type 字段存在且正确**

在 `tests/unit/test_resource_loading.gd` 中新增：

```gdscript
func test_weapon_has_weapon_type():
	var rifle: WeaponData = GameConfig.weapons[Enums.WeaponId.RIFLE]
	assert_eq(rifle.weapon_type, "bullet", "rifle weapon_type 应为 bullet")
	var boom: WeaponData = GameConfig.weapons[Enums.WeaponId.BOOMERANG]
	assert_eq(boom.weapon_type, "boomerang", "boomerang weapon_type 应为 boomerang")
	var laser: WeaponData = GameConfig.weapons[Enums.WeaponId.LASER]
	assert_eq(laser.weapon_type, "laser", "laser weapon_type 应为 laser")
```

- [ ] **Step 2: 运行测试验证失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
```

Expected: FAIL — weapon_type 属性不存在

- [ ] **Step 3: 在 WeaponData 中新增所有扩展字段**

```gdscript
# scripts/resources/weapon_data.gd — 在现有字段后追加

# 武器类分发
@export var weapon_type: String = ""

# 火箭筒
@export var explosion_radius_per_level: PackedFloat32Array = []

# 火焰喷射
@export var flame_cone_angle: float = 45.0

# 闪电链
@export var chain_count: int = 3
@export var chain_decay: float = 0.7
@export var chain_range: float = 150.0

# 冰冻枪
@export var slow_on_hit: float = 0.0
@export var slow_duration: float = 2.0
```

- [ ] **Step 4: 更新现有 3 个 .tres 添加 weapon_type**

- `resources/weapons/rifle.tres` → 添加 `weapon_type = "bullet"`
- `resources/weapons/boomerang.tres` → 添加 `weapon_type = "boomerang"`
- `resources/weapons/laser.tres` → 添加 `weapon_type = "laser"`

- [ ] **Step 5: 运行测试验证通过**

- [ ] **Step 6: 提交**

```bash
git add scripts/resources/weapon_data.gd resources/weapons/ tests/unit/test_resource_loading.gd
git commit -m "feat: WeaponData 新增 weapon_type 及新武器扩展字段"
```

---

### Task 4: TowerData 扩展 — 新塔配置字段

**Files:**
- Modify: `scripts/resources/tower_data.gd`

- [ ] **Step 1: 新增所有塔扩展字段**

```gdscript
# scripts/resources/tower_data.gd — 在现有字段后追加

# 玫瑰（连发）
@export var burst_count: int = 3
@export var burst_interval: float = 0.15

# 藤蔓（定身）
@export var trap_duration_per_level: PackedFloat32Array = []
@export var trap_cooldown: float = 8.0

# 蒲公英（击退）
@export var knockback_force_per_level: PackedFloat32Array = []
@export var knockback_interval: float = 5.0

# 猪笼草（抓取）
@export var grab_dps_per_level: PackedFloat32Array = []
@export var digest_duration_per_level: PackedFloat32Array = []

# 荆棘（反伤）
@export var reflect_ratio_per_level: PackedFloat32Array = []

# 橡树（减伤光环）
@export var aura_reduction_per_level: PackedFloat32Array = []

# 向日葵（产金）
@export var generate_amount_per_level: PackedFloat32Array = []
@export var generate_interval_per_level: PackedFloat32Array = []

# 薄荷（增益光环）
@export var buff_damage_mult_per_level: PackedFloat32Array = []
@export var buff_speed_mult_per_level: PackedFloat32Array = []

# 治愈花（治疗）
@export var heal_amount_per_level: PackedFloat32Array = []
@export var heal_interval_per_level: PackedFloat32Array = []

# 爆竹竹（自爆）
@export var charge_time: float = 15.0
@export var explosion_damage_per_level: PackedFloat32Array = []
@export var explosion_range_per_level: PackedFloat32Array = []
```

- [ ] **Step 2: 运行测试无回归**

- [ ] **Step 3: 提交**

```bash
git add scripts/resources/tower_data.gd
git commit -m "feat: TowerData 新增所有塔扩展字段"
```

---

### Task 5: EnemyData 新增 is_boss 字段

**Files:**
- Modify: `scripts/resources/enemy_data.gd`
- Modify: `resources/enemies/boss_brute.tres` — 设置 is_boss = true
- Test: `tests/unit/test_resource_loading.gd`

- [ ] **Step 1: 写测试**

```gdscript
func test_boss_brute_is_boss():
	var ed: EnemyData = GameConfig.enemies[Enums.Enemy.BOSS_BRUTE]
	assert_true(ed.is_boss, "boss_brute 应标记为 is_boss")

func test_normal_enemy_not_boss():
	var ed: EnemyData = GameConfig.enemies[Enums.Enemy.NORMAL]
	assert_false(ed.is_boss, "normal 不应标记为 is_boss")
```

- [ ] **Step 2: 运行测试验证失败**

- [ ] **Step 3: 实现**

```gdscript
# scripts/resources/enemy_data.gd — 在现有字段后追加
@export var is_boss: bool = false
```

编辑 `resources/enemies/boss_brute.tres` 添加 `is_boss = true`。同时检查其他 Boss .tres 文件（boss_summoner, boss_guardian）如已存在也设置。

- [ ] **Step 4: 运行测试验证通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/resources/enemy_data.gd resources/enemies/ tests/unit/test_resource_loading.gd
git commit -m "feat: EnemyData 新增 is_boss 字段"
```

---

### Task 6: HealthComponent 扩展 — damage_reduction + attacker 追踪

**Files:**
- Modify: `scripts/components/health_component.gd:6,27-42,44-51`
- Test: `tests/unit/test_health_component.gd` (若存在) 或新建

- [ ] **Step 1: 写测试 — damage_reduction 和 attacker 参数**

```gdscript
# tests/unit/test_health_component.gd

func test_damage_reduction_reduces_damage():
	var hc := HealthComponent.new()
	add_child(hc)
	hc.initialize(100.0)
	hc.damage_reduction = 0.25
	hc.take_damage(40.0)
	# 40 * (1 - 0.25) = 30 实际伤害
	assert_almost_eq(hc.current_hp, 70.0, 0.01, "减伤 25% 后应为 70 HP")

func test_damage_reduction_clamp():
	var hc := HealthComponent.new()
	add_child(hc)
	hc.initialize(100.0)
	hc.damage_reduction = 0.9  # 超过上限
	hc.take_damage(100.0)
	# clamp 到 0.75: 100 * (1 - 0.75) = 25 实际伤害
	assert_almost_eq(hc.current_hp, 75.0, 0.01, "减伤上限应为 75%")

func test_damaged_signal_includes_attacker():
	var hc := HealthComponent.new()
	add_child(hc)
	hc.initialize(100.0)
	var received_attacker: Node2D = null
	hc.damaged.connect(func(amt, hp, atk): received_attacker = atk)
	var mock_attacker := Node2D.new()
	add_child(mock_attacker)
	hc.take_damage(10.0, mock_attacker)
	assert_eq(received_attacker, mock_attacker, "应收到 attacker 引用")
	mock_attacker.queue_free()

func test_damaged_signal_null_attacker():
	var hc := HealthComponent.new()
	add_child(hc)
	hc.initialize(100.0)
	var signal_fired: bool = false
	hc.damaged.connect(func(_amt, _hp, atk): signal_fired = true; assert_null(atk))
	hc.take_damage(10.0)
	assert_true(signal_fired)
```

- [ ] **Step 2: 运行测试验证失败**

- [ ] **Step 3: 实现 HealthComponent 扩展**

```gdscript
# scripts/components/health_component.gd

# 信号扩展（第 6 行）
signal damaged(amount: float, current_hp: float, attacker: Node2D)

# 新增字段（第 11 行后）
var damage_reduction: float = 0.0

# take_damage 扩展（替换第 27-42 行）
func take_damage(amount: float, attacker: Node2D = null) -> void:
	if invincible:
		return
	var reduction: float = clampf(damage_reduction, 0.0, 0.75)
	amount *= (1.0 - reduction)
	current_hp -= amount
	var owner_node: Node2D = get_parent() as Node2D
	if owner_node:
		EffectsManager.flash_white(owner_node)
	var pos: Vector2 = _get_global_position() + damage_number_offset
	EffectsManager.spawn_damage_number(pos, amount)
	EffectsManager.spawn_hit_sparks(_get_global_position())
	damaged.emit(amount, current_hp, attacker)
	if current_hp <= 0:
		die()

# take_damage_no_sparks 也需要扩展签名（第 44-51 行）
func take_damage_no_sparks(amount: float, attacker: Node2D = null) -> void:
	if invincible:
		return
	current_hp -= amount
	damaged.emit(amount, current_hp, attacker)
	if current_hp <= 0:
		died.emit()
```

- [ ] **Step 4: 修复所有 damaged 信号连接处**

搜索整个项目中连接 `damaged` 信号的地方，更新回调签名增加第三个参数 `_attacker: Node2D`。常见模式：

```bash
# 搜索所有 damaged.connect 调用
rg "damaged\.connect" scripts/ tests/
```

- [ ] **Step 5: 更新 Tower.take_damage 传递 attacker**

```gdscript
# scripts/entities/towers/tower.gd:29-30
func take_damage(amount: float, attacker: Node2D = null) -> void:
	health.take_damage(amount, attacker)
```

- [ ] **Step 6: 更新 enemy._attack_tower 传递 self**

```gdscript
# scripts/entities/enemy.gd:84
target_tower.take_damage(tower_attack_damage, self)
```

- [ ] **Step 7: 运行全部测试验证通过**

- [ ] **Step 8: 提交**

```bash
git add scripts/components/health_component.gd scripts/entities/towers/tower.gd scripts/entities/enemy.gd tests/
git commit -m "feat: HealthComponent 新增 damage_reduction 和 attacker 追踪"
```

---

### Task 7: SlowHandler 重构 — 计数器 → 效果字典

**Files:**
- Modify: `scripts/components/slow_handler.gd` — 完全重写
- Modify: `scripts/entities/towers/tower_slow.gd` — 适配新 API
- Modify: `scripts/entities/enemy.gd:132-142` — 适配新 API
- Test: `tests/unit/test_slow_handler.gd` (新建或更新)

- [ ] **Step 1: 写测试**

```gdscript
# tests/unit/test_slow_handler.gd
extends GutTest

func test_single_slow_applies():
	var sh := SlowHandler.new()
	add_child(sh)
	sh.initialize(100.0)
	var received_speed: float = -1.0
	sh.speed_changed.connect(func(s): received_speed = s)
	sh.apply_slow(0.3, "tower_1")
	assert_almost_eq(received_speed, 70.0, 0.01)

func test_remove_slow_restores():
	var sh := SlowHandler.new()
	add_child(sh)
	sh.initialize(100.0)
	var received_speed: float = -1.0
	sh.speed_changed.connect(func(s): received_speed = s)
	sh.apply_slow(0.3, "tower_1")
	sh.remove_slow("tower_1")
	assert_almost_eq(received_speed, 100.0, 0.01)

func test_max_value_stacking():
	var sh := SlowHandler.new()
	add_child(sh)
	sh.initialize(100.0)
	var received_speed: float = -1.0
	sh.speed_changed.connect(func(s): received_speed = s)
	sh.apply_slow(0.3, "tower_1")
	sh.apply_slow(0.5, "tower_2")
	# max(0.3, 0.5) = 0.5 → speed = 50
	assert_almost_eq(received_speed, 50.0, 0.01)

func test_remove_one_of_two_slows():
	var sh := SlowHandler.new()
	add_child(sh)
	sh.initialize(100.0)
	var received_speed: float = -1.0
	sh.speed_changed.connect(func(s): received_speed = s)
	sh.apply_slow(0.3, "tower_1")
	sh.apply_slow(0.5, "tower_2")
	sh.remove_slow("tower_2")
	# 只剩 tower_1 的 0.3 → speed = 70
	assert_almost_eq(received_speed, 70.0, 0.01)

func test_timed_slow_expires():
	var sh := SlowHandler.new()
	add_child(sh)
	sh.initialize(100.0)
	var received_speed: float = -1.0
	sh.speed_changed.connect(func(s): received_speed = s)
	sh.apply_timed_slow(0.3, 0.1, "bullet_1")
	assert_almost_eq(received_speed, 70.0, 0.01)
	# 等待过期
	await get_tree().create_timer(0.2).timeout
	assert_almost_eq(received_speed, 100.0, 0.01, "定时减速应已过期")
```

- [ ] **Step 2: 运行测试验证失败**

- [ ] **Step 3: 重写 SlowHandler**

```gdscript
# scripts/components/slow_handler.gd — 完全替换
class_name SlowHandler
extends Node

# 减速处理组件 — 管理多源减速效果，取最大值

signal speed_changed(new_speed: float)

var base_speed: float = 0.0
var _active_slows: Dictionary = {}  # {source_id: {percent: float}}

func initialize(initial_speed: float) -> void:
	base_speed = initial_speed

func apply_slow(percent: float, source_id: String) -> void:
	_active_slows[source_id] = {"percent": percent}
	_recalc_speed()

func remove_slow(source_id: String) -> void:
	_active_slows.erase(source_id)
	_recalc_speed()

var _timed_slow_timers: Dictionary = {}  # {source_id: SceneTreeTimer}

func apply_timed_slow(percent: float, duration: float, source_id: String) -> void:
	apply_slow(percent, source_id)
	# 若同 source_id 已有定时器，先断开旧回调（防止提前移除）
	if _timed_slow_timers.has(source_id):
		var old_timer = _timed_slow_timers[source_id]
		if old_timer and old_timer.timeout.is_connected(_on_timed_slow_expired.bind(source_id)):
			old_timer.timeout.disconnect(_on_timed_slow_expired.bind(source_id))
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	timer.timeout.connect(_on_timed_slow_expired.bind(source_id))
	_timed_slow_timers[source_id] = timer

func _on_timed_slow_expired(source_id: String) -> void:
	_timed_slow_timers.erase(source_id)
	remove_slow(source_id)

func _recalc_speed() -> void:
	if _active_slows.is_empty():
		speed_changed.emit(base_speed)
		return
	var max_percent: float = 0.0
	for data in _active_slows.values():
		if data["percent"] > max_percent:
			max_percent = data["percent"]
	speed_changed.emit(base_speed * (1.0 - max_percent))
```

- [ ] **Step 4: 更新 TowerSlow 适配新 API**

```gdscript
# scripts/entities/towers/tower_slow.gd — apply_slow/remove_slow 增加 source_id

# _on_body_entered 中:
enemy.apply_slow(_slow_percent, str(get_instance_id()))

# _on_body_exited 中:
enemy.remove_slow(str(get_instance_id()))
```

- [ ] **Step 5: 更新 enemy.gd 的 apply_slow/remove_slow 签名**

```gdscript
# scripts/entities/enemy.gd:132-142

func apply_slow(slow_percent: float, source_id: String = "") -> void:
	slow_handler.apply_slow(slow_percent, source_id)

func remove_slow(source_id: String = "") -> void:
	slow_handler.remove_slow(source_id)
```

- [ ] **Step 6: 运行全部测试验证通过**

- [ ] **Step 7: 提交**

```bash
git add scripts/components/slow_handler.gd scripts/entities/towers/tower_slow.gd scripts/entities/enemy.gd tests/
git commit -m "refactor: SlowHandler 重构为效果字典模式，支持多源减速和定时减速"
```

---

### Task 8: Tower 基类扩展 — buff 支持 + Enemy root 系统

**Files:**
- Modify: `scripts/entities/towers/tower.gd` — 新增 damage_mult, speed_mult, apply_buff/remove_buff
- Modify: `scripts/entities/enemy.gd` — 新增 apply_root/remove_root, is_rooted
- Test: 新增测试

- [ ] **Step 1: 写测试 — Tower buff 和 Enemy root**

```gdscript
# tests/unit/test_tower_buff.gd
extends GutTest

func test_tower_default_mult():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	add_child(tower)
	assert_eq(tower.damage_mult, 1.0)
	assert_eq(tower.speed_mult, 1.0)
	tower.queue_free()

func test_tower_apply_remove_buff():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	add_child(tower)
	tower.apply_buff(1.15, 1.1, "mint_1")
	assert_almost_eq(tower.damage_mult, 1.15, 0.01)
	assert_almost_eq(tower.speed_mult, 1.1, 0.01)
	tower.remove_buff("mint_1")
	assert_almost_eq(tower.damage_mult, 1.0, 0.01)
	assert_almost_eq(tower.speed_mult, 1.0, 0.01)
	tower.queue_free()

func test_tower_multiple_buff_sources():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	add_child(tower)
	tower.apply_buff(1.15, 1.1, "mint_1")
	tower.apply_buff(1.2, 1.05, "mint_2")
	# 乘法叠加: 1.15 * 1.2 = 1.38, 1.1 * 1.05 = 1.155
	assert_almost_eq(tower.damage_mult, 1.38, 0.01)
	assert_almost_eq(tower.speed_mult, 1.155, 0.01)
	tower.remove_buff("mint_1")
	assert_almost_eq(tower.damage_mult, 1.2, 0.01)
	tower.queue_free()
```

```gdscript
# tests/unit/test_enemy_root.gd
extends GutTest

func test_enemy_root_stops_movement():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	add_child(enemy)
	assert_false(enemy.is_rooted)
	enemy.apply_root(1.0)
	assert_true(enemy.is_rooted)
	assert_eq(enemy.speed, 0.0)
	enemy.queue_free()
```

- [ ] **Step 2: 运行测试验证失败**

- [ ] **Step 3: 实现 Tower buff 方法**

```gdscript
# scripts/entities/towers/tower.gd — 在 var 声明区新增
var damage_mult: float = 1.0
var speed_mult: float = 1.0
var _buff_sources: Dictionary = {}  # {source_id: {dmg: float, spd: float}}

# 新增方法 — 支持多源 buff 叠加（乘法）
func apply_buff(dmg_mult: float, spd_mult: float, source_id: String) -> void:
	_buff_sources[source_id] = {"dmg": dmg_mult, "spd": spd_mult}
	_recalc_buffs()

func remove_buff(source_id: String) -> void:
	_buff_sources.erase(source_id)
	_recalc_buffs()

func _recalc_buffs() -> void:
	damage_mult = 1.0
	speed_mult = 1.0
	for data in _buff_sources.values():
		damage_mult *= data["dmg"]
		speed_mult *= data["spd"]
```

- [ ] **Step 4: 实现 Enemy root 系统**

```gdscript
# scripts/entities/enemy.gd — 在变量声明区新增
var is_rooted: bool = false
var _pre_root_speed: float = 0.0

# 新增方法
func apply_root(duration: float) -> void:
	is_rooted = true
	_pre_root_speed = speed
	speed = 0.0
	velocity = Vector2.ZERO
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	timer.timeout.connect(remove_root)

func remove_root() -> void:
	if not is_rooted:
		return
	is_rooted = false
	speed = _pre_root_speed
```

同时在 `_chase_player()` 开头加判断：

```gdscript
func _chase_player() -> void:
	if is_rooted:
		return
	# ... 现有逻辑
```

同时在 `_on_speed_changed()` 中防止 root 期间被 slow 覆盖：

```gdscript
func _on_speed_changed(new_speed: float) -> void:
	if is_rooted:
		_pre_root_speed = new_speed  # 更新保存速度，但不改实际速度
		return
	speed = new_speed
```

- [ ] **Step 5: 运行全部测试验证通过**

- [ ] **Step 6: 提交**

```bash
git add scripts/entities/towers/tower.gd scripts/entities/enemy.gd tests/
git commit -m "feat: Tower 新增 buff 支持，Enemy 新增 root 定身系统"
```

---

### Task 9: WeaponManager 改为 weapon_type 分发

**Files:**
- Modify: `scripts/entities/weapons/weapon_manager.gd:15-16,53-59`
- Test: `tests/unit/test_weapon_config.gd`

- [ ] **Step 1: 写测试**

```gdscript
# tests/unit/test_weapon_config.gd — 新增
func test_all_weapons_have_weapon_type():
	for id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[id]
		assert_ne(w.weapon_type, "", id + " 应有 weapon_type")
```

- [ ] **Step 2: 运行测试验证失败**（新武器 .tres 尚未创建，但现有 3 个应通过）

- [ ] **Step 3: 修改 WeaponManager._create_weapon 和 _add_weapon**

```gdscript
# scripts/entities/weapons/weapon_manager.gd

func _add_weapon(data: WeaponData) -> void:
	var weapon: Weapon = _create_weapon(data.weapon_type)  # 改为 weapon_type
	if not weapon:
		return
	weapon.initialize(data)
	weapon.owner_node = get_parent() as Node2D
	add_child(weapon)
	_weapons.append(weapon)

func _create_weapon(weapon_type: String) -> Weapon:
	match weapon_type:
		"bullet":        return BulletWeapon.new()
		"boomerang":     return BoomerangWeapon.new()
		"laser":         return LaserWeapon.new()
		# 新武器类型将在 Chunk 2/3 中添加
	push_error("WeaponManager: 未知 weapon_type: " + weapon_type)
	return null
```

- [ ] **Step 4: 运行全部测试验证通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/entities/weapons/weapon_manager.gd tests/
git commit -m "refactor: WeaponManager 改为按 weapon_type 分发 Weapon 子类"
```

---

### 注意: headless 测试 class_name 缓存

> **重要**: 每当新增带 `class_name` 的脚本（如 ShotgunWeapon, RocketProjectile 等），若无法打开 Godot 编辑器自动刷新，需手动在 `.godot/global_script_class_cache.cfg` 中补充对应条目，否则 headless 测试无法识别该类名。建议每个 Chunk 实现完毕后在 Godot 编辑器中打开项目一次，让编辑器自动更新缓存。

---

## Chunk 2: 新武器 — 复用 Bullet 投射物 (shotgun, minigun, ice_gun)

### Task 10: Shotgun 武器 — 霰弹枪

**Files:**
- Create: `scripts/entities/weapons/shotgun_weapon.gd`
- Create: `resources/weapons/shotgun.tres`
- Modify: `scripts/entities/weapons/weapon_manager.gd:53+` — 添加 "shotgun" 映射
- Test: `tests/unit/test_weapon_config.gd`

- [ ] **Step 1: 写测试**

```gdscript
func test_shotgun_resource_loaded():
	assert_true(GameConfig.weapons.has(Enums.WeaponId.SHOTGUN), "应包含 shotgun")
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.SHOTGUN]
	assert_eq(w.weapon_type, "shotgun")
	assert_eq(w.projectile_type, "bullet")
	assert_gt(w.bullet_count, 1, "霰弹枪应发射多颗子弹")
```

- [ ] **Step 2: 运行测试验证失败**

- [ ] **Step 3: 创建 ShotgunWeapon 脚本**

```gdscript
# scripts/entities/weapons/shotgun_weapon.gd
class_name ShotgunWeapon
extends Weapon

# 霰弹枪 — 扇形散射多颗子弹

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		return
	var base_dir: Vector2 = owner_node.global_position.direction_to(target.global_position)
	var count: int = weapon_data.bullet_count
	var spread: float = deg_to_rad(25.0)  # ±25° 扇形
	for i in count:
		var angle_offset: float = lerp(-spread, spread, float(i) / max(count - 1, 1))
		var dir: Vector2 = base_dir.rotated(angle_offset)
		var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
		bullet.speed = weapon_data.bullet_speed
		bullet.lifetime = 2.0  # 短寿命，近距离武器
		scene_parent.add_child(bullet)
		bullet.setup(base_damage, weapon_data.knockback_force, owner_node.global_position, dir)
	AudioManager.play("shoot")
```

- [ ] **Step 4: 创建 shotgun.tres 资源文件**

在 `resources/weapons/` 下创建 `shotgun.tres`：
- id = "shotgun", display_name = "霰弹枪"
- weapon_type = "shotgun", projectile_type = "bullet"
- bullet_count = 4, bullet_speed = 250.0
- damage_per_level = [6, 9, 13, 18, 24]
- fire_rate_per_level = [0.6, 0.55, 0.5, 0.45, 0.4]
- weapon_range_per_level = [180, 195, 210, 230, 250]
- knockback_force = 60.0

- [ ] **Step 5: 在 WeaponManager._create_weapon 添加映射**

```gdscript
"shotgun":       return ShotgunWeapon.new()
```

- [ ] **Step 6: 运行测试验证通过**

- [ ] **Step 7: 提交**

```bash
git add scripts/entities/weapons/shotgun_weapon.gd resources/weapons/shotgun.tres scripts/entities/weapons/weapon_manager.gd tests/
git commit -m "feat: 新增霰弹枪武器（扇形散射子弹）"
```

---

### Task 11: Minigun 武器 — 加特林

**Files:**
- Create: `resources/weapons/minigun.tres`
- Modify: `scripts/entities/weapons/weapon_manager.gd` — 添加 "minigun" → BulletWeapon 映射
- Test: `tests/unit/test_weapon_config.gd`

- [ ] **Step 1: 写测试**

```gdscript
func test_minigun_resource_loaded():
	assert_true(GameConfig.weapons.has(Enums.WeaponId.MINIGUN))
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.MINIGUN]
	assert_eq(w.weapon_type, "minigun")
	assert_lt(w.fire_rate_per_level[0], 0.1, "加特林射速应极快")
```

- [ ] **Step 2: 创建 minigun.tres**

- id = "minigun", display_name = "加特林", weapon_type = "minigun", projectile_type = "bullet"
- damage_per_level = [4, 6, 8, 11, 15]
- fire_rate_per_level = [0.05, 0.045, 0.04, 0.035, 0.03]
- weapon_range_per_level = [250, 265, 280, 300, 320]
- bullet_speed = 350.0, knockback_force = 20.0

- [ ] **Step 3: 在 WeaponManager 添加 "minigun" → BulletWeapon 映射**

```gdscript
"minigun":       return BulletWeapon.new()
```

- [ ] **Step 4: 运行测试验证通过**

- [ ] **Step 5: 提交**

```bash
git add resources/weapons/minigun.tres scripts/entities/weapons/weapon_manager.gd tests/
git commit -m "feat: 新增加特林武器（极速射击复用 BulletWeapon）"
```

---

### Task 12: IceGun 武器 — 冰冻枪 + BulletProjectile 减速扩展

**Files:**
- Create: `scripts/entities/weapons/ice_gun_weapon.gd`
- Create: `resources/weapons/ice_gun.tres`
- Modify: `scripts/entities/projectiles/bullet_projectile.gd:71-80` — 新增 slow 逻辑
- Modify: `scripts/entities/weapons/weapon_manager.gd` — 添加映射
- Test: `tests/unit/test_weapon_config.gd`

- [ ] **Step 1: 写测试**

```gdscript
func test_ice_gun_resource_loaded():
	assert_true(GameConfig.weapons.has(Enums.WeaponId.ICE_GUN))
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.ICE_GUN]
	assert_eq(w.weapon_type, "ice_gun")
	assert_gt(w.slow_on_hit, 0.0, "冰冻枪应有 slow_on_hit")
```

- [ ] **Step 2: 在 BulletProjectile 新增 slow 属性和命中逻辑**

```gdscript
# scripts/entities/projectiles/bullet_projectile.gd — 新增变量
var slow_on_hit: float = 0.0
var slow_duration: float = 0.0

# 在 _on_hitbox_area_entered 中，命中 Hurtbox 后添加：
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		EffectsManager.spawn_hit_sparks(global_position)
		# 冰冻减速
		if slow_on_hit > 0.0:
			var enemy: Node2D = area.get_parent()
			if enemy and enemy.has_method("apply_slow"):
				var source_id: String = "ice_bullet_" + str(get_instance_id())
				enemy.slow_handler.apply_timed_slow(slow_on_hit, slow_duration, source_id)
		# 分裂弹（保持原有逻辑）
		if GameData.split_count > 0 and not get_meta("is_split", false):
			_spawn_split_bullets()
		_hit_count += 1
		if _hit_count > GameData.pierce_count:
			_cleanup_and_free()
```

- [ ] **Step 3: 创建 IceGunWeapon 脚本**

```gdscript
# scripts/entities/weapons/ice_gun_weapon.gd
class_name IceGunWeapon
extends BulletWeapon

# 冰冻枪 — 子弹命中后附加减速效果

func _spawn_bullet(scene_parent: Node, direction: Vector2, damage: float) -> void:
	var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
	bullet.speed = weapon_data.bullet_speed
	bullet.slow_on_hit = weapon_data.slow_on_hit
	bullet.slow_duration = weapon_data.slow_duration
	scene_parent.add_child(bullet)
	bullet.setup(damage, weapon_data.knockback_force, owner_node.global_position, direction)
```

- [ ] **Step 4: 创建 ice_gun.tres**

- id = "ice_gun", display_name = "冰冻枪", weapon_type = "ice_gun", projectile_type = "bullet"
- damage_per_level = [8, 12, 16, 21, 28]
- fire_rate_per_level = [0.2, 0.18, 0.16, 0.14, 0.12]
- weapon_range_per_level = [280, 300, 320, 340, 370]
- slow_on_hit = 0.3, slow_duration = 2.0
- bullet_speed = 280.0, knockback_force = 30.0

- [ ] **Step 5: WeaponManager 添加 "ice_gun" 映射**

```gdscript
"ice_gun":       return IceGunWeapon.new()
```

- [ ] **Step 6: 运行测试验证通过**

- [ ] **Step 7: 提交**

```bash
git add scripts/entities/weapons/ice_gun_weapon.gd scripts/entities/projectiles/bullet_projectile.gd resources/weapons/ice_gun.tres scripts/entities/weapons/weapon_manager.gd tests/
git commit -m "feat: 新增冰冻枪武器（子弹命中附加减速）"
```

---

## Chunk 3: 新武器 — 新投射物类型 (rocket, flame, chain, melee)

### Task 13: Rocket 武器 + RocketProjectile

**Files:**
- Create: `scripts/entities/projectiles/rocket_projectile.gd`
- Create: `scenes/entities/projectiles/rocket_projectile.tscn`
- Create: `scripts/entities/weapons/rocket_weapon.gd`
- Create: `resources/weapons/rocket.tres`
- Modify: `scripts/core/scene_factory.gd` — 新增 create_rocket_projectile
- Modify: `scripts/entities/weapons/weapon_manager.gd` — 添加映射

- [ ] **Step 1: 写测试**

```gdscript
# tests/unit/test_weapon_config.gd
func test_rocket_resource_loaded():
	assert_true(GameConfig.weapons.has(Enums.WeaponId.ROCKET))
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.ROCKET]
	assert_eq(w.weapon_type, "rocket")
	assert_gt(w.explosion_radius_per_level.size(), 0, "应有爆炸半径配置")
```

- [ ] **Step 2: 创建 RocketProjectile**

```gdscript
# scripts/entities/projectiles/rocket_projectile.gd
class_name RocketProjectile
extends Projectile

# 火箭投射物 — 直线飞行，碰撞后范围爆炸

var speed: float = 300.0
var lifetime: float = 3.0
var explosion_radius: float = 80.0
var _direction: Vector2 = Vector2.RIGHT
var _elapsed: float = 0.0

func _on_setup(direction: Vector2) -> void:
	_direction = direction
	hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	_elapsed += delta
	if _elapsed >= lifetime:
		_explode()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		_explode()

func _explode() -> void:
	# 对爆炸范围内所有敌人造成伤害
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	for enemy in enemies:
		if enemy is Node2D:
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist <= explosion_radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(hitbox.damage)
	# 爆炸视觉效果
	EffectsManager.spawn_death_effect(global_position, Color.ORANGE)
	queue_free()
```

- [ ] **Step 3: 创建 rocket_projectile.tscn 场景**

使用 MCP 或手动创建。结构与 bullet_projectile.tscn 相同：
- Root: Node2D "RocketProjectile", script = rocket_projectile.gd
- Hitbox (Area2D): layer=4, mask=128, CircleShape2D radius=4.0

- [ ] **Step 4: SceneFactory 注册**

```gdscript
# scripts/core/scene_factory.gd
var _rocket_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/rocket_projectile.tscn")

func create_rocket_projectile() -> RocketProjectile:
	return _rocket_projectile_scene.instantiate()
```

- [ ] **Step 5: 创建 RocketWeapon**

```gdscript
# scripts/entities/weapons/rocket_weapon.gd
class_name RocketWeapon
extends Weapon

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		return
	var direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
	var rocket: RocketProjectile = SceneFactory.create_rocket_projectile()
	rocket.speed = weapon_data.bullet_speed
	var level: int = get_current_level()
	if weapon_data.explosion_radius_per_level.size() >= level:
		rocket.explosion_radius = weapon_data.explosion_radius_per_level[level - 1]
	scene_parent.add_child(rocket)
	rocket.setup(base_damage, weapon_data.knockback_force, owner_node.global_position, direction)
	AudioManager.play("shoot")
```

- [ ] **Step 6: 创建 rocket.tres**

- id = "rocket", display_name = "火箭筒", weapon_type = "rocket", projectile_type = "rocket"
- damage_per_level = [40, 55, 72, 95, 125]
- fire_rate_per_level = [1.5, 1.35, 1.2, 1.05, 0.9]
- weapon_range_per_level = [350, 370, 390, 420, 450]
- explosion_radius_per_level = [80, 90, 100, 115, 130]
- bullet_speed = 300.0, knockback_force = 100.0

- [ ] **Step 7: WeaponManager 添加映射**

```gdscript
"rocket":        return RocketWeapon.new()
```

- [ ] **Step 8: 运行测试验证通过**

- [ ] **Step 9: 提交**

```bash
git add scripts/entities/projectiles/rocket_projectile.gd scenes/entities/projectiles/rocket_projectile.tscn scripts/entities/weapons/rocket_weapon.gd resources/weapons/rocket.tres scripts/core/scene_factory.gd scripts/entities/weapons/weapon_manager.gd tests/
git commit -m "feat: 新增火箭筒武器（AOE 爆炸投射物）"
```

---

### Task 14: Lightning 武器 + ChainProjectile

**Files:**
- Create: `scripts/entities/projectiles/chain_projectile.gd`
- Create: `scenes/entities/projectiles/chain_projectile.tscn`
- Create: `scripts/entities/weapons/lightning_weapon.gd`
- Create: `resources/weapons/lightning.tres`
- Modify: `scripts/core/scene_factory.gd`
- Modify: `scripts/entities/weapons/weapon_manager.gd`

- [ ] **Step 1: 写测试**

```gdscript
func test_lightning_resource_loaded():
	assert_true(GameConfig.weapons.has(Enums.WeaponId.LIGHTNING))
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.LIGHTNING]
	assert_eq(w.weapon_type, "lightning")
	assert_gt(w.chain_count, 0)
```

- [ ] **Step 2: 创建 ChainProjectile**

```gdscript
# scripts/entities/projectiles/chain_projectile.gd
class_name ChainProjectile
extends Projectile

# 闪电链投射物 — 瞬时命中 + 链式跳跃

var chain_count: int = 3
var chain_decay: float = 0.7
var chain_range: float = 150.0
var _visual_duration: float = 0.15

func _on_setup(direction: Vector2) -> void:
	# 瞬时命中，不需要 direction 移动
	pass

func execute_chain(first_target: Node2D, damage: float) -> void:
	var targets: Array[Node2D] = [first_target]
	var current_damage: float = damage
	var current_target: Node2D = first_target
	# 第一次命中
	if current_target.has_method("take_damage"):
		current_target.take_damage(current_damage)
	# 链式跳跃
	for _i in chain_count:
		current_damage *= chain_decay
		var next_target: Node2D = _find_next_target(current_target, targets)
		if not next_target:
			break
		targets.append(next_target)
		current_target = next_target
		if current_target.has_method("take_damage"):
			current_target.take_damage(current_damage)
	# 视觉效果：Line2D 连接所有目标
	_draw_chain(targets)
	# 定时清理
	var timer: SceneTreeTimer = get_tree().create_timer(_visual_duration)
	timer.timeout.connect(queue_free)

func _find_next_target(from: Node2D, exclude: Array[Node2D]) -> Node2D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var closest: Node2D = null
	var min_dist: float = chain_range
	for enemy in enemies:
		if enemy is Node2D and enemy not in exclude:
			var dist: float = from.global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest

func _draw_chain(targets: Array[Node2D]) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(0.5, 0.8, 1.0, 0.9)
	line.top_level = true
	for t in targets:
		if is_instance_valid(t):
			line.add_point(t.global_position)
	add_child(line)
```

- [ ] **Step 3: 创建 chain_projectile.tscn**

- Root: Node2D "ChainProjectile", script = chain_projectile.gd
- Hitbox (Area2D): layer=4, mask=128, 空 CollisionShape2D（链式不需要物理碰撞）

- [ ] **Step 4: SceneFactory + LightningWeapon + .tres + WeaponManager 映射**

```gdscript
# scripts/entities/weapons/lightning_weapon.gd
class_name LightningWeapon
extends Weapon

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		return
	var chain: ChainProjectile = SceneFactory.create_chain_projectile()
	chain.chain_count = weapon_data.chain_count
	chain.chain_decay = weapon_data.chain_decay
	chain.chain_range = weapon_data.chain_range
	scene_parent.add_child(chain)
	chain.global_position = target.global_position
	chain.execute_chain(target, base_damage)
	AudioManager.play("shoot")
```

lightning.tres:
- id = "lightning", display_name = "闪电链", weapon_type = "lightning", projectile_type = "chain"
- damage_per_level = [12, 17, 23, 30, 40]
- fire_rate_per_level = [0.8, 0.72, 0.65, 0.58, 0.5]
- weapon_range_per_level = [300, 320, 340, 370, 400]
- chain_count = 3, chain_decay = 0.7, chain_range = 150.0
- knockback_force = 0.0

WeaponManager: `"lightning": return LightningWeapon.new()`

- [ ] **Step 5: 运行测试验证通过**

- [ ] **Step 6: 提交**

```bash
git commit -m "feat: 新增闪电链武器（瞬时链式跳跃伤害）"
```

---

### Task 15: Blade 武器 + MeleeProjectile

**Files:**
- Create: `scripts/entities/projectiles/melee_projectile.gd`
- Create: `scenes/entities/projectiles/melee_projectile.tscn`
- Create: `scripts/entities/weapons/blade_weapon.gd`
- Create: `resources/weapons/blade.tres`
- Modify: `scripts/core/scene_factory.gd`
- Modify: `scripts/entities/weapons/weapon_manager.gd`

- [ ] **Step 1: 创建 MeleeProjectile**

```gdscript
# scripts/entities/projectiles/melee_projectile.gd
class_name MeleeProjectile
extends Projectile

# 近战投射物 — 玩家中心圆形瞬时 hitbox

var melee_radius: float = 60.0
var _duration: float = 0.1

func _on_setup(_direction: Vector2) -> void:
	# 动态创建圆形碰撞形状
	var shape := CircleShape2D.new()
	shape.radius = melee_radius
	var col: CollisionShape2D = hitbox.get_node("CollisionShape2D")
	col.shape = shape
	# 定时清理
	var timer: SceneTreeTimer = get_tree().create_timer(_duration)
	timer.timeout.connect(queue_free)
```

- [ ] **Step 2: 创建 BladeWeapon**

```gdscript
# scripts/entities/weapons/blade_weapon.gd
class_name BladeWeapon
extends Weapon

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		return
	var melee: MeleeProjectile = SceneFactory.create_melee_projectile()
	melee.melee_radius = get_weapon_range()
	scene_parent.add_child(melee)
	melee.setup(base_damage, weapon_data.knockback_force, owner_node.global_position, Vector2.ZERO)
	AudioManager.play("shoot")
```

- [ ] **Step 3: 场景 + SceneFactory + .tres + WeaponManager 映射**

blade.tres:
- id = "blade", display_name = "旋刃", weapon_type = "blade", projectile_type = "melee"
- damage_per_level = [20, 28, 38, 50, 65]
- fire_rate_per_level = [0.4, 0.36, 0.32, 0.28, 0.24]
- weapon_range_per_level = [60, 65, 72, 80, 90]
- knockback_force = 80.0

WeaponManager: `"blade": return BladeWeapon.new()`

- [ ] **Step 4: 运行测试验证通过**

- [ ] **Step 5: 提交**

```bash
git commit -m "feat: 新增旋刃武器（近战圆形瞬时伤害）"
```

---

### Task 16: Flamethrower 武器 + FlameProjectile

**Files:**
- Create: `scripts/entities/projectiles/flame_projectile.gd`
- Create: `scenes/entities/projectiles/flame_projectile.tscn`
- Create: `scripts/entities/weapons/flamethrower_weapon.gd`
- Create: `resources/weapons/flamethrower.tres`
- Modify: `scripts/core/scene_factory.gd`
- Modify: `scripts/entities/weapons/weapon_manager.gd`

- [ ] **Step 1: 创建 FlameProjectile — 持续型锥形伤害**

```gdscript
# scripts/entities/projectiles/flame_projectile.gd
class_name FlameProjectile
extends Node2D

# 火焰投射物 — 持续型锥形 hitbox，由 FlamethrowerWeapon 维持

var flame_damage: float = 3.0
var flame_range: float = 100.0
var cone_angle: float = 45.0
var _tick_interval: float = 0.1
var _tick_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if not visible:
		return
	_tick_timer -= delta
	if _tick_timer <= 0:
		_tick_timer = _tick_interval
		_deal_damage()

func _deal_damage() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var half_angle: float = deg_to_rad(cone_angle / 2.0)
	var forward: Vector2 = Vector2.RIGHT.rotated(rotation)
	for enemy in enemies:
		if enemy is Node2D:
			var to_enemy: Vector2 = enemy.global_position - global_position
			var dist: float = to_enemy.length()
			if dist <= flame_range and dist > 0:
				var angle: float = forward.angle_to(to_enemy.normalized())
				if absf(angle) <= half_angle:
					if enemy.has_method("take_damage"):
						enemy.take_damage(flame_damage)

func update_direction(target_pos: Vector2) -> void:
	var dir: Vector2 = target_pos - global_position
	if dir.length() > 0:
		rotation = dir.angle()
```

注意：FlameProjectile 不继承 Projectile 基类（无 Hitbox 子节点），它自行管理伤害。

- [ ] **Step 2: 创建 FlamethrowerWeapon — 持续型武器**

```gdscript
# scripts/entities/weapons/flamethrower_weapon.gd
class_name FlamethrowerWeapon
extends Weapon

# 火焰喷射 — 维持单个 FlameProjectile 持续伤害

var _flame: FlameProjectile = null

func fire(target: Node2D) -> void:
	# 持续型，不使用 cooldown fire 模式
	pass

func tick(delta: float, target: Node2D) -> void:
	if not _flame or not is_instance_valid(_flame):
		_create_flame()
	if target:
		_flame.visible = true
		_flame.global_position = owner_node.global_position
		_flame.update_direction(target.global_position)
		_flame.flame_damage = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	else:
		_flame.visible = false

func _create_flame() -> void:
	_flame = SceneFactory.create_flame_projectile()
	_flame.flame_range = get_weapon_range()
	_flame.cone_angle = weapon_data.flame_cone_angle
	var scene_parent: Node = owner_node.get_parent()
	if scene_parent:
		scene_parent.add_child(_flame)
```

- [ ] **Step 3: 场景 + SceneFactory + .tres + WeaponManager 映射**

flamethrower.tres:
- id = "flamethrower", display_name = "火焰喷射", weapon_type = "flamethrower", projectile_type = "flame"
- damage_per_level = [3, 4.5, 6, 8, 11] (每 0.1s tick 伤害)
- fire_rate_per_level = [0, 0, 0, 0, 0] (持续型不用)
- weapon_range_per_level = [100, 110, 120, 135, 150]
- flame_cone_angle = 45.0, knockback_force = 0.0

WeaponManager: `"flamethrower": return FlamethrowerWeapon.new()`

- [ ] **Step 4: 运行测试验证通过**

- [ ] **Step 5: 提交**

```bash
git commit -m "feat: 新增火焰喷射武器（持续型锥形伤害）"
```

---

## Chunk 4: 新塔 — 攻击型 + 控制型 (cactus, rose, mushroom, vine, dandelion, pitcher)

### Task 17: Cactus 塔 — 仙人掌（狙击）

**Files:**
- Create: `scripts/entities/towers/tower_sniper.gd`
- Create: `scenes/entities/towers/tower_cactus.tscn`
- Create: `resources/towers/cactus.tres`
- Modify: `scripts/core/scene_factory.gd` — _tower_scenes 注册

- [ ] **Step 1: 写测试**

```gdscript
# tests/unit/test_scene_factory.gd — 新增
func test_create_tower_cactus():
	var tower = SceneFactory.create_tower(Enums.TowerId.CACTUS)
	assert_not_null(tower, "应能创建仙人掌塔")
	assert_eq(tower.tower_type, Enums.TowerId.CACTUS)
	add_child(tower)
	assert_not_null(tower.data, "应注入 TowerData")
	tower.queue_free()
```

- [ ] **Step 2: 创建 TowerSniper 脚本**

```gdscript
# scripts/entities/towers/tower_sniper.gd
extends Tower

# 仙人掌 — 远程狙击，优先攻击血量最高敌人

var attack_damage: float = 35.0
var attack_rate: float = 2.5
var attack_range: float = 450.0

@onready var _detect_area: Area2D = $DetectArea
@onready var _shoot_timer: Timer = $ShootTimer

func _ready() -> void:
	tower_type = Enums.TowerId.CACTUS
	super._ready()
	_shoot_timer.timeout.connect(_shoot_highest_hp)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var idx: int = get_current_level() - 1
	attack_damage = data.damage_per_level[idx] * GameData.player_stats.get(Enums.Stat.TOWER_MULT, 1.0) * damage_mult
	attack_rate = data.fire_rate_per_level[idx] / maxf(speed_mult, 0.1)  # speed_mult > 1 = 更快（间隔更短）
	attack_range = data.attack_range_per_level[idx]
	_detect_area.get_node("CollisionShape2D").shape.radius = attack_range
	_shoot_timer.wait_time = attack_rate
	if not _shoot_timer.is_stopped():
		_shoot_timer.start()

func _shoot_highest_hp() -> void:
	var target: Node2D = _find_highest_hp_target()
	if not target:
		return
	var dir: Vector2 = global_position.direction_to(target.global_position)
	var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
	bullet.speed = 400.0
	get_parent().add_child(bullet)
	bullet.setup(attack_damage, 60.0, global_position, dir)

func _find_highest_hp_target() -> Node2D:
	var bodies: Array[Node2D] = _detect_area.get_overlapping_bodies()
	var best: Node2D = null
	var max_hp: float = 0.0
	for body in bodies:
		if body.is_in_group(Enums.Group.ENEMIES) and body.has_node("HealthComponent"):
			var hp: float = body.health.current_hp
			if hp > max_hp:
				max_hp = hp
				best = body
	return best

func _on_body_entered(_body: Node2D) -> void:
	if _shoot_timer.is_stopped():
		_shoot_timer.start()

func _on_body_exited(_body: Node2D) -> void:
	if _detect_area.get_overlapping_bodies().is_empty():
		_shoot_timer.stop()
```

- [ ] **Step 3: 创建 tower_cactus.tscn**

结构参考 tower_pea_shooter.tscn：
- Root: StaticBody2D "TowerCactus", script = tower_sniper.gd, collision_layer=8, collision_mask=2
- Sprite2D (占位)
- CollisionShape2D: RectangleShape2D 16x16
- DetectArea (Area2D): collision_layer=0, collision_mask=2, CircleShape2D radius=450
- ShootTimer (Timer): wait_time=2.5, one_shot=false
- HealthComponent (Node)

连接信号：DetectArea.body_entered → _on_body_entered, body_exited → _on_body_exited

- [ ] **Step 4: 创建 cactus.tres**

- id = "cactus", display_name = "仙人掌", max_level = 5
- hp_per_level = [60, 80, 105, 135, 170]
- damage_per_level = [35, 48, 63, 82, 110]
- fire_rate_per_level = [2.5, 2.3, 2.1, 1.9, 1.7]
- attack_range_per_level = [450, 475, 500, 530, 570]
- place_cost_per_level = [20, 26, 34, 44, 56]
- shop_price_per_level = [0, 30, 50, 75, 105]

- [ ] **Step 5: SceneFactory 注册**

在 `_tower_scenes` 字典中添加 `Enums.TowerId.CACTUS: preload("res://scenes/entities/towers/tower_cactus.tscn")`

- [ ] **Step 6: 运行测试验证通过**

- [ ] **Step 7: 提交**

```bash
git commit -m "feat: 新增仙人掌塔（远程狙击优先高HP）"
```

---

### Task 18-22: 其余攻击型 + 控制型塔

> 以下各塔遵循 Task 17 相同模式：写测试 → 创建脚本 → 创建场景 → 创建 .tres → SceneFactory 注册 → 测试 → 提交。每个塔一个独立提交。

**Task 18: Rose (玫瑰) — TowerBurst**
- 脚本: `scripts/entities/towers/tower_burst.gd` — 状态机 IDLE→BURST(3连发)→COOLDOWN
- 场景: `scenes/entities/towers/tower_rose.tscn`
- 资源: `resources/towers/rose.tres`
- 数值: HP 70-170, damage 10×3, burst_count=3, burst_interval=0.15, cooldown=3.0s, range 150-250

**Task 19: Mushroom (毒蘑菇) — TowerAoe**
- 脚本: `scripts/entities/towers/tower_aoe.gd` — SporeArea 持续 tick 伤害
- 场景: `scenes/entities/towers/tower_mushroom.tscn`
- 资源: `resources/towers/mushroom.tres`
- 数值: HP 90-200, damage 5-12/tick, range 180-280

**Task 20: Vine (藤蔓) — TowerTrap**
- 脚本: `scripts/entities/towers/tower_trap.gd` — TrapArea 检测 + 定身冷却
- 场景: `scenes/entities/towers/tower_vine.tscn`
- 资源: `resources/towers/vine.tres`
- 数值: HP 100-220, trap_duration 2.5-4.0s, trap_cooldown=8s, range 120-200
- 依赖: Enemy.apply_root() (Task 8)

**Task 21: Dandelion (蒲公英) — TowerKnockback**
- 脚本: `scripts/entities/towers/tower_knockback.gd` — PushArea + 周期击退
- 场景: `scenes/entities/towers/tower_dandelion.tscn`
- 资源: `resources/towers/dandelion.tres`
- 数值: HP 80-180, knockback_force 100-180, knockback_interval=5s, range 200-300
- 依赖: KnockbackHandler (已有)

**Task 22: Pitcher (猪笼草) — TowerGrab**
- 脚本: `scripts/entities/towers/tower_grab.gd` — 状态机 IDLE→GRAB→DIGEST→IDLE
- 场景: `scenes/entities/towers/tower_pitcher.tscn`
- 资源: `resources/towers/pitcher.tres`
- 数值: HP 120-260, grab_dps 8-18, digest_duration 3-5s, range 100-160
- 注意: Boss 免疫 (检查 enemy.data.is_boss)，抓取敌人隔离处理

---

## Chunk 5: 新塔 — 防御型 + 辅助型 + 特殊 (thorn, oak, sunflower, mint, heal_flower, bamboo)

### Task 23: Thorn (荆棘) — TowerThorn

**Files:**
- Create: `scripts/entities/towers/tower_thorn.gd`
- Create: `scenes/entities/towers/tower_thorn.tscn`
- Create: `resources/towers/thorn.tres`

- [ ] **Step 1: 写测试**

```gdscript
func test_create_tower_thorn():
	var tower = SceneFactory.create_tower(Enums.TowerId.THORN)
	assert_not_null(tower)
	add_child(tower)
	assert_not_null(tower.data)
	tower.queue_free()
```

- [ ] **Step 2: 创建 TowerThorn**

```gdscript
# scripts/entities/towers/tower_thorn.gd
extends Tower

# 荆棘 — 敌人攻击自身时反弹伤害

var reflect_ratio: float = 0.25

func _ready() -> void:
	tower_type = Enums.TowerId.THORN
	super._ready()
	health.damaged.connect(_on_damaged)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var idx: int = get_current_level() - 1
	if data.reflect_ratio_per_level.size() > idx:
		reflect_ratio = data.reflect_ratio_per_level[idx]

func _on_damaged(amount: float, _current_hp: float, attacker: Node2D) -> void:
	if attacker and is_instance_valid(attacker) and attacker.has_method("take_damage"):
		var reflect_damage: float = amount * reflect_ratio
		attacker.health.take_damage(reflect_damage)
```

- [ ] **Step 3: 场景 + .tres + SceneFactory 注册**

thorn.tres: HP 150-340, reflect_ratio 0.25-0.45

- [ ] **Step 4: 测试 + 提交**

---

### Task 24: Oak (橡树) — TowerAura

```gdscript
# scripts/entities/towers/tower_aura.gd
extends Tower

# 橡树 — 超肉 + 范围内友方塔减伤光环

var aura_reduction: float = 0.15
var _buffed_towers: Array[Tower] = []

@onready var _aura_area: Area2D = $AuraArea

func _ready() -> void:
	tower_type = Enums.TowerId.OAK
	super._ready()
	_aura_area.body_entered.connect(_on_tower_entered)
	_aura_area.body_exited.connect(_on_tower_exited)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var idx: int = get_current_level() - 1
	if data.aura_reduction_per_level.size() > idx:
		var old_reduction: float = aura_reduction
		aura_reduction = data.aura_reduction_per_level[idx]
		_update_buffed_towers(old_reduction, aura_reduction)

func _on_tower_entered(body: Node2D) -> void:
	if body is Tower and body != self:
		body.health.damage_reduction = clampf(body.health.damage_reduction + aura_reduction, 0.0, 0.75)
		_buffed_towers.append(body)

func _on_tower_exited(body: Node2D) -> void:
	if body is Tower and body in _buffed_towers:
		body.health.damage_reduction = maxf(body.health.damage_reduction - aura_reduction, 0.0)
		_buffed_towers.erase(body)

func _update_buffed_towers(old_val: float, new_val: float) -> void:
	for t in _buffed_towers:
		if is_instance_valid(t):
			t.health.damage_reduction = clampf(t.health.damage_reduction - old_val + new_val, 0.0, 0.75)

func _on_died() -> void:
	for t in _buffed_towers:
		if is_instance_valid(t):
			t.health.damage_reduction = maxf(t.health.damage_reduction - aura_reduction, 0.0)
	super._on_died()
```

AuraArea: collision_layer=0, collision_mask=8 (检测 Tower body)

oak.tres: HP 400-820, aura_reduction 0.15-0.25, range 150-250

---

### Task 25-28: 辅助型 + 特殊型塔

> 同样遵循标准模式。

**Task 25: Sunflower (向日葵) — TowerGenerator**
- 脚本: `scripts/entities/towers/tower_generator.gd` — 定时器生成 Coin
- 场景: `scenes/entities/towers/tower_sunflower.tscn`
- 数值: HP 50-120, generate_amount 5-12, generate_interval 10-6s

**Task 26: Mint (薄荷) — TowerBuff**
- 脚本: `scripts/entities/towers/tower_buff.gd` — BuffArea 增益友方塔
- 场景: `scenes/entities/towers/tower_mint.tscn`
- 数值: HP 60-140, buff_damage_mult 1.15-1.35, buff_speed_mult 1.1-1.25, range 180-280
- 使用 Tower.apply_buff/remove_buff (Task 8)

**Task 27: HealFlower (治愈花) — TowerHeal**
- 脚本: `scripts/entities/towers/tower_heal.gd` — HealArea 治疗最低HP塔
- 场景: `scenes/entities/towers/tower_heal_flower.tscn`
- 数值: HP 60-140, heal_amount 20-45, heal_interval 3-2s, range 200-300
- 使用 HealthComponent.heal() (已有)

**Task 28: Bamboo (爆竹竹) — TowerBomb**
- 脚本: `scripts/entities/towers/tower_bomb.gd` — 状态机 CHARGING→EXPLODE→queue_free()
- 场景: `scenes/entities/towers/tower_bamboo.tscn`
- 数值: HP 100-220, explosion_damage 150-350, explosion_range 250-400, charge_time=15s
- owned_towers 中不移除，可重复放置

---

### Task 29: SceneFactory 完整注册 + 全部 .tres 验证

**Files:**
- Modify: `scripts/core/scene_factory.gd` — 确保全部 15 塔 + 7 投射物已注册

- [ ] **Step 1: 写覆盖性测试**

```gdscript
# tests/unit/test_scene_factory.gd — 确保所有塔都能创建
func test_all_towers_can_be_created():
	var all_ids: Array[String] = [
		Enums.TowerId.PEA_SHOOTER, Enums.TowerId.STUMP, Enums.TowerId.ICE_FLOWER,
		Enums.TowerId.CACTUS, Enums.TowerId.ROSE, Enums.TowerId.MUSHROOM,
		Enums.TowerId.VINE, Enums.TowerId.DANDELION, Enums.TowerId.PITCHER,
		Enums.TowerId.THORN, Enums.TowerId.OAK, Enums.TowerId.SUNFLOWER,
		Enums.TowerId.MINT, Enums.TowerId.HEAL_FLOWER, Enums.TowerId.BAMBOO,
	]
	for id in all_ids:
		var tower = SceneFactory.create_tower(id)
		assert_not_null(tower, "应能创建塔: " + id)
		add_child(tower)
		assert_eq(tower.tower_type, id)
		assert_not_null(tower.data, id + " 应注入 TowerData")
		tower.queue_free()
```

```gdscript
# tests/unit/test_weapon_config.gd — 确保所有武器资源正确加载
func test_all_weapons_loaded():
	var all_ids: Array[String] = [
		Enums.WeaponId.RIFLE, Enums.WeaponId.BOOMERANG, Enums.WeaponId.LASER,
		Enums.WeaponId.SHOTGUN, Enums.WeaponId.MINIGUN, Enums.WeaponId.ROCKET,
		Enums.WeaponId.FLAMETHROWER, Enums.WeaponId.LIGHTNING,
		Enums.WeaponId.ICE_GUN, Enums.WeaponId.BLADE,
	]
	for id in all_ids:
		assert_true(GameConfig.weapons.has(id), "应包含武器: " + id)
		var w: WeaponData = GameConfig.weapons[id]
		assert_ne(w.weapon_type, "", id + " 应有 weapon_type")
		assert_eq(w.damage_per_level.size(), w.max_level, id + " damage_per_level 数量应匹配 max_level")
```

- [ ] **Step 2: 运行全部测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 3: 修复任何失败**

- [ ] **Step 4: 提交**

```bash
git commit -m "test: 全量武器/塔创建验证测试"
```

---

### Task 30: 更新 GameConfig SPRITES + 升级弹窗 display_name

**Files:**
- Modify: `scripts/core/game_config.gd` — SPRITES.towers 添加新塔精灵配置
- 验证: `scripts/systems/upgrade_generator.gd` — 无需修改（自动从 GameConfig 构建池）
- 验证: `scripts/ui/upgrade_popup.gd` — 使用 display_name 显示（来自 Resource）

- [ ] **Step 1: 更新 SPRITES.towers 添加 12 个新塔占位精灵配置**

每个新塔在 SPRITES.towers 中添加条目，暂用占位 sprite region。

- [ ] **Step 2: 运行全部测试验证通过**

- [ ] **Step 3: 提交**

```bash
git commit -m "feat: 更新 GameConfig SPRITES 配置支持 15 塔"
```

---

### Task 31: 最终集成测试 + 清理

- [ ] **Step 1: 运行全部测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 2: 在 Godot 编辑器中打开项目，验证场景加载无错误**

- [ ] **Step 3: 手动运行游戏验证**

- 角色选择后进入布置阶段，侧栏应显示已拥有塔
- 进入战斗，武器应正常自动开火
- 波次结束后升级弹窗应显示新武器/塔选项
- 选择新武器后下一波应生效
- 选择新塔后布置阶段应可放置

- [ ] **Step 4: 最终提交**

```bash
git commit -m "feat: 武器与植物塔扩充完成 — 10武器 + 15塔"
```
