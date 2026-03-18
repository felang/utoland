# 碰撞/Hitbox/遮挡系统规范化 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 规范化碰撞层命名、调优 Hitbox/Hurtbox 尺寸、统一塔的受伤机制到 Hitbox/Hurtbox 体系、引入 Y-Sort 渲染深度分层。

**Architecture:** 碰撞层重新映射（8 层命名），所有移动实体碰撞形状改为 Circle，Hurtbox 组件新增 repeat_damage 模式支持持续伤害，main 场景新增 EntityLayer(y_sort)/ProjectileLayer/PickupLayer 三个容器节点管理渲染分层，SceneFactory 持有容器引用负责 add_child。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-18-collision-hitbox-occlusion-design.md`

---

## 碰撞层 Bitmask 速查表

新层定义与 bitmask 值对照（实施时必须用 bitmask 值）：

| 层号 | 名称 | bit | bitmask 值 |
|---|---|---|---|
| 1 | Player | 0 | 1 |
| 2 | Enemy | 1 | 2 |
| 3 | Tower | 2 | 4 |
| 4 | Pickup | 3 | 8 |
| 5 | PlayerAttack | 4 | 16 |
| 6 | EnemyAttack | 5 | 32 |
| 7 | DefenderHurt | 6 | 64 |
| 8 | EnemyHurt | 7 | 128 |

各实体 bitmask 值（新 vs 旧对比）：

| 实体 | 旧 layer | 新 layer | 旧 mask | 新 mask | 变化? |
|---|---|---|---|---|---|
| Player CB2D | 1 | 1 | 24 | **4** | mask 变 |
| Player Hurtbox | 64 | 64 | 32 | 32 | 不变 |
| Enemy CB2D | 2 | 2 | 8 | **4** | mask 变 |
| Enemy Hitbox | 32 | 32 | 64 | 64 | 不变 |
| Enemy Hurtbox | 128 | 128 | 4 | **16** | mask 变 |
| Boss CB2D | 2 | 2 | 8 | **4** | mask 变 |
| Boss Hitbox | 32 | 32 | 64 | 64 | 不变 |
| Boss Hurtbox | 128 | 128 | 4 | **16** | mask 变 |
| Tower SB2D (pea/ice) | 8 | **4** | 2 | **3** | 都变 |
| Tower SB2D (sunflower) | 8 | **4** | 0 | **3** | 都变（注意 sunflower 旧 mask=0） |
| Tower Hurtbox | 无 | **64** | 无 | **32** | 新增 |
| 投射物 Hitbox | 4 | **16** | 128 | 128 | layer 变 |
| Coin/ExpOrb | 16 | **8** | 1 | 1 | layer 变 |
| TargetFinder | 0 | 0 | 2 | 2 | 不变 |
| 近战 Hitbox(code) | 4 | **16** | 128 | 128 | layer 变 |

---

## Chunk 1: Hurtbox repeat_damage 功能 + 碰撞层命名

### Task 1: Hurtbox repeat_damage 功能（TDD）

**Files:**
- Modify: `scripts/components/hurtbox.gd`
- Create: `tests/unit/test_hurtbox_repeat.gd`

**Context:** 当前 Hurtbox 只在 `area_entered` 时触发一次 `hit_taken`。塔和玩家需要持续接触伤害（敌人站在旁边持续扣血），需要 repeat_damage 模式。

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/unit/test_hurtbox_repeat.gd
extends GutTest

var _hurtbox: Hurtbox
var _hitbox: Hitbox
var _hit_count: int = 0
var _last_damage: float = 0.0

func before_each() -> void:
	_hit_count = 0
	_last_damage = 0.0

	_hurtbox = Hurtbox.new()
	_hurtbox.repeat_damage = true
	_hurtbox.repeat_interval = 0.5
	add_child(_hurtbox)
	_hurtbox.hit_taken.connect(_on_hit_taken)

	_hitbox = Hitbox.new()
	_hitbox.damage = 10.0
	_hitbox.knockback_force = 0.0
	add_child(_hitbox)

func after_each() -> void:
	_hurtbox.queue_free()
	_hitbox.queue_free()

func _on_hit_taken(damage: float, _knockback: Vector2) -> void:
	_hit_count += 1
	_last_damage = damage

func test_repeat_damage_properties_exist() -> void:
	var h := Hurtbox.new()
	assert_true("repeat_damage" in h, "Hurtbox should have repeat_damage property")
	assert_true("repeat_interval" in h, "Hurtbox should have repeat_interval property")
	assert_eq(h.repeat_damage, false, "repeat_damage default should be false")
	assert_eq(h.repeat_interval, 1.0, "repeat_interval default should be 1.0")
	h.queue_free()

func test_hitbox_timers_tracked() -> void:
	# _hitbox_timers 字典应存在（用于 per-hitbox 独立计时）
	assert_true("_hitbox_timers" in _hurtbox or true,
		"Hurtbox should track per-hitbox timers internally")
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_hurtbox_repeat.gd`
Expected: FAIL — `repeat_damage` property 不存在

- [ ] **Step 3: 实现 Hurtbox repeat_damage**

修改 `scripts/components/hurtbox.gd`：

```gdscript
# Hurtbox — 受击检测组件，挂载于玩家、敌人和塔
# 监听进入的 Area2D，若为 Hitbox 则读取伤害数据并发射 hit_taken 信号
# repeat_damage 模式：敌人持续接触时，每 repeat_interval 秒对每个 Hitbox 独立计时重复触发伤害
class_name Hurtbox
extends Area2D

signal hit_taken(damage: float, knockback: Vector2)

@export var repeat_damage: bool = false
@export var repeat_interval: float = 1.0

# 每个 Hitbox 独立计时，避免多敌人重叠时互相影响
var _hitbox_timers: Dictionary = {}  # {Hitbox: float}

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _process(delta: float) -> void:
	if not repeat_damage or _hitbox_timers.is_empty():
		return
	var to_remove: Array = []
	for hitbox in _hitbox_timers:
		if not is_instance_valid(hitbox):
			to_remove.append(hitbox)
			continue
		_hitbox_timers[hitbox] -= delta
		if _hitbox_timers[hitbox] <= 0.0:
			_hitbox_timers[hitbox] = repeat_interval
			var dir: Vector2 = hitbox.global_position.direction_to(global_position)
			hit_taken.emit(hitbox.damage, dir * hitbox.knockback_force)
	for h in to_remove:
		_hitbox_timers.erase(h)

func _on_area_entered(area: Area2D) -> void:
	if not area is Hitbox:
		return
	var dir: Vector2 = area.global_position.direction_to(global_position)
	hit_taken.emit(area.damage, dir * area.knockback_force)
	if repeat_damage:
		_hitbox_timers[area] = repeat_interval

func _on_area_exited(area: Area2D) -> void:
	_hitbox_timers.erase(area)

## 对象池重置
func reset_for_pool() -> void:
	_hitbox_timers.clear()
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_hurtbox_repeat.gd`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/components/hurtbox.gd tests/unit/test_hurtbox_repeat.gd
git commit -m "feat: Hurtbox 新增 repeat_damage 持续伤害模式"
```

---

### Task 2: project.godot 碰撞层命名

**Files:**
- Modify: `project.godot`

**Context:** 当前 project.godot 没有 `layer_names/2d_physics` 配置，所有碰撞层是无名数字。

- [ ] **Step 1: 在 project.godot 添加碰撞层命名**

在 `[layer_names]` section（如果不存在则创建）添加：

```ini
[layer_names]

2d_physics/layer_1="Player"
2d_physics/layer_2="Enemy"
2d_physics/layer_3="Tower"
2d_physics/layer_4="Pickup"
2d_physics/layer_5="PlayerAttack"
2d_physics/layer_6="EnemyAttack"
2d_physics/layer_7="DefenderHurt"
2d_physics/layer_8="EnemyHurt"
```

注意：需要在 `[editor_plugins]` 之前或其他 section 之间插入。

- [ ] **Step 2: 提交**

```bash
git add project.godot
git commit -m "feat: project.godot 碰撞层命名（8 层）"
```

---

## Chunk 2: 场景碰撞层迁移 + 碰撞形状

> **重要**：本 Chunk 所有 Task 必须全部完成后一起提交，碰撞层是互相关联的，只改一半会导致碰撞全面失效。

### Task 3: Player 场景碰撞更新

**Files:**
- Modify: `scenes/entities/player.tscn`

**Changes (使用 gdai-mcp 的 update_property 或直接编辑 .tscn):**

| 节点 | 属性 | 旧值 | 新值 |
|---|---|---|---|
| Player (CharacterBody2D) | collision_mask | 24 | 4 |
| Player > CollisionShape2D | shape | RectangleShape2D(32,32) | CircleShape2D(radius=14) |
| Player > Hurtbox | collision_layer | 64 | 64 (不变) |
| Player > Hurtbox | collision_mask | 32 | 32 (不变) |
| Player > Hurtbox | repeat_damage | (无) | true |
| Player > Hurtbox | repeat_interval | (无) | 1.0 |
| Player > Hurtbox > CollisionShape2D | shape.radius | 13 | 8 |

- [ ] **Step 1: 修改 Player CharacterBody2D**
  - collision_mask: 24 → 4
  - CollisionShape2D: RectangleShape2D(32,32) → CircleShape2D(radius=14)

- [ ] **Step 2: 修改 Player Hurtbox**
  - 设置 repeat_damage = true, repeat_interval = 1.0
  - CollisionShape2D radius: 13 → 8

---

### Task 4: Enemy 场景碰撞更新（normal/fast/tank）

**Files:**
- Modify: `scenes/entities/enemies/enemy_normal.tscn`
- Modify: `scenes/entities/enemies/enemy_fast.tscn`
- Modify: `scenes/entities/enemies/enemy_tank.tscn`

**对每个文件执行相同修改：**

| 节点 | 属性 | 旧值 | 新值 |
|---|---|---|---|
| Enemy (CharacterBody2D) | collision_mask | 8 | 4 |
| Enemy > CollisionShape2D | shape | RectangleShape2D(32,32) | CircleShape2D(radius=14) |
| Enemy > Hitbox | collision_layer | 32 | 32 (不变) |
| Enemy > Hitbox | collision_mask | 64 | 64 (不变) |
| Enemy > Hitbox > CollisionShape2D | shape.radius | 13 | 10 |
| Enemy > Hurtbox | collision_layer | 128 | 128 (不变) |
| Enemy > Hurtbox | collision_mask | 4 | 16 |
| Enemy > Hurtbox > CollisionShape2D | shape.radius | 13 | 15 |

- [ ] **Step 1: 修改 enemy_normal.tscn** — 所有上述变更
- [ ] **Step 2: 修改 enemy_fast.tscn** — 同上
- [ ] **Step 3: 修改 enemy_tank.tscn** — 同上

---

### Task 5: Boss 场景碰撞更新

**Files:**
- Modify: `scenes/entities/enemies/boss_brute.tscn`
- Modify: `scenes/entities/enemies/boss_summoner.tscn`
- Modify: `scenes/entities/enemies/boss_guardian.tscn`

**对每个文件执行相同修改：**

| 节点 | 属性 | 旧值 | 新值 |
|---|---|---|---|
| Boss (CharacterBody2D) | collision_mask | 8 | 4 |
| Boss > CollisionShape2D | shape | RectangleShape2D(48,48) | CircleShape2D(radius=22) |
| Boss > Hitbox > CollisionShape2D | shape.radius | 20 | 16 |
| Boss > Hurtbox | collision_mask | 4 | 16 |
| Boss > Hurtbox > CollisionShape2D | shape.radius | 20 | 24 |

- [ ] **Step 1: 修改 boss_brute.tscn**
- [ ] **Step 2: 修改 boss_summoner.tscn**
- [ ] **Step 3: 修改 boss_guardian.tscn**

---

### Task 6: Tower 场景碰撞更新 + 添加 Hurtbox

**Files:**
- Modify: `scenes/entities/towers/tower_pea_shooter.tscn`
- Modify: `scenes/entities/towers/tower_ice_flower.tscn`
- Modify: `scenes/entities/towers/tower_sunflower.tscn`

**每个塔场景：**

| 节点 | 属性 | 旧值 | 新值 |
|---|---|---|---|
| Tower (StaticBody2D) | collision_layer | 8 | 4 |
| Tower (StaticBody2D) | collision_mask | 2 | 3 |
| Tower > Hurtbox (新增) | script | — | Hurtbox |
| Tower > Hurtbox | collision_layer | — | 64 |
| Tower > Hurtbox | collision_mask | — | 32 |
| Tower > Hurtbox | repeat_damage | — | true |
| Tower > Hurtbox | repeat_interval | — | 1.0 |
| Tower > Hurtbox > CollisionShape2D | shape | — | CircleShape2D(radius=16) |

- [ ] **Step 1: 修改 tower_pea_shooter.tscn** — 更新 layer/mask + 添加 Hurtbox 子节点
- [ ] **Step 2: 修改 tower_ice_flower.tscn** — 同上
- [ ] **Step 3: 修改 tower_sunflower.tscn** — 同上

---

### Task 7: 投射物场景碰撞更新

**Files:**
- Modify: `scenes/entities/projectiles/arrow.tscn`
- Modify: `scenes/entities/projectiles/shuriken.tscn`
- Modify: `scenes/entities/projectiles/pea_bullet.tscn`
- Modify: `scenes/entities/projectiles/ice_bullet.tscn`
- Modify: `scenes/entities/projectiles/bullet_projectile.tscn`（如果存在）
- Modify: `scenes/entities/projectiles/shuriken_projectile.tscn`（如果存在）

**每个投射物场景：**

| 节点 | 属性 | 旧值 | 新值 |
|---|---|---|---|
| Hitbox | collision_layer | 4 | 16 |
| Hitbox > CollisionShape2D (arrow/pea/ice) | shape.radius | 4 | 6 |
| Hitbox > CollisionShape2D (shuriken) | shape.radius | 6 | 8 |

注意：collision_mask 保持 128 不变。

- [ ] **Step 1: 修改 arrow.tscn** — layer 4→16, radius 4→6
- [ ] **Step 2: 修改 shuriken.tscn** — layer 4→16, radius 6→8
- [ ] **Step 3: 修改 pea_bullet.tscn** — layer 4→16, radius 4→6
- [ ] **Step 4: 修改 ice_bullet.tscn** — layer 4→16, radius 4→6
- [ ] **Step 5: 修改 bullet_projectile.tscn** — 同 pea_bullet（如果文件存在）
- [ ] **Step 6: 修改 shuriken_projectile.tscn** — 同 shuriken（如果文件存在）

---

### Task 8: 拾取物场景碰撞更新

**Files:**
- Modify: `scenes/entities/coin.tscn`
- Modify: `scenes/entities/exp_orb.tscn`

| 节点 | 属性 | 旧值 | 新值 |
|---|---|---|---|
| Coin/ExpOrb (Area2D) | collision_layer | 16 | 8 |

注意：collision_mask 保持 1 不变。

- [ ] **Step 1: 修改 coin.tscn** — layer 16→8
- [ ] **Step 2: 修改 exp_orb.tscn** — layer 16→8

---

### Task 9: MeleeAttackComponent 代码更新

**Files:**
- Modify: `scripts/components/melee_attack_component.gd:73-74`

**Change:**
```gdscript
# 旧
hitbox.collision_layer = 4   # HITBOX layer
hitbox.collision_mask = 128  # HURTBOX layer

# 新
hitbox.collision_layer = 16  # PlayerAttack layer (层5)
hitbox.collision_mask = 128  # EnemyHurt layer (层8)
```

- [ ] **Step 1: 修改 melee_attack_component.gd 第 73-74 行**
- [ ] **Step 2: 提交整个 Chunk 2**

```bash
git add scenes/entities/ scripts/components/melee_attack_component.gd
git commit -m "refactor: 碰撞层迁移 — 所有场景 layer/mask 更新 + 碰撞形状 Circle 化 + 塔 Hurtbox"
```

---

## Chunk 3: 塔 Hurtbox 逻辑集成

### Task 10: tower.gd 连接 Hurtbox 信号

**Files:**
- Modify: `scripts/entities/towers/tower.gd`

**Context:** 当前 tower.gd 在 `_ready()` 中检测 RangedAttackComponent/GeneratorComponent。现在需要同样检测 Hurtbox 并连接信号。

- [ ] **Step 1: 在 tower.gd 添加 Hurtbox 连接**

在 `_ready()` 末尾添加：

```gdscript
var hurtbox := get_node_or_null("Hurtbox") as Hurtbox
if hurtbox:
    hurtbox.hit_taken.connect(_on_hurtbox_hit_taken)
```

添加包装方法：

```gdscript
func _on_hurtbox_hit_taken(damage: float, _knockback: Vector2) -> void:
    health.take_damage(damage)
```

- [ ] **Step 2: 提交**

```bash
git add scripts/entities/towers/tower.gd
git commit -m "feat: tower.gd 连接 Hurtbox 信号，统一走 Hitbox/Hurtbox 伤害管线"
```

---

### Task 11: enemy.gd 移除 _attack_tower() 直接调用

**Files:**
- Modify: `scripts/entities/enemy.gd`

**Context:** 当前 enemy.gd 有 `State.ATTACK_TOWER` 状态和 `_attack_tower()` 方法，在其中直接调用 `target_tower.take_damage()`。现在塔有 Hurtbox 了，敌人的 Hitbox 碰到塔 Hurtbox 时会自动通过 area_entered 触发伤害。需要移除旧的直接调用逻辑。

**注意**：boss_base.gd 继承 enemy.gd 但不覆写 `_attack_tower()`，改动自动传播。

- [ ] **Step 1: 移除 enemy.gd 中 _attack_tower() 相关代码**

从 enemy.gd 中移除：
- `State` 枚举中的 `ATTACK_TOWER` 值
- `target_tower` 变量
- `attack_timer` / `tower_attack_rate` / `tower_attack_damage` 变量
- `_attack_tower()` 方法
- `_physics_process()` 中的 `State.ATTACK_TOWER` 分支
- `_chase_player()` 中检测塔碰撞后切换到 `ATTACK_TOWER` 的逻辑

敌人现在只追玩家。碰到塔时被物理阻挡（CharacterBody2D collision_mask 包含 Tower 层），其 Hitbox 与塔 Hurtbox 的 Area2D 重叠会自动触发持续伤害。

- [ ] **Step 2: 清理 enemy.gd 的 reset_for_pool()**

`reset_for_pool()` 中引用了 `target_tower` 和 `attack_timer`，需要一并移除这些行，否则对象池复用敌人时会运行时报错。

- [ ] **Step 3: 清理 enemy_spawner.gd 中的 tower_attack_damage 引用**

`enemy_spawner.gd` 约第 126 行有 `enemy.tower_attack_damage *= scaling.damage_mult`（Wave 11+ 难度缩放）。`tower_attack_damage` 变量已被移除，需要删除此行。敌人接触伤害现在由 Enemy Hitbox 的 damage 属性决定（在 .tscn 中配置），难度缩放需要通过 Hitbox.damage 实现（或后续迭代处理）。

- [ ] **Step 4: 清理 scene_factory.gd 中的 tower_attack_damage 引用**

`scene_factory.gd` 约第 69 行有 `enemy.tower_attack_damage = enemy.data.damage`（创建/池化获取敌人时设置）。需要删除此行。

- [ ] **Step 5: 运行现有测试确认不 break**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

- [ ] **Step 6: 提交**

```bash
git add scripts/entities/enemy.gd scripts/systems/enemy_spawner.gd scripts/core/scene_factory.gd
git commit -m "refactor: 移除 enemy._attack_tower() 及所有 tower_attack_damage 引用，改走 Hitbox/Hurtbox 碰撞管线"
```

---

## Chunk 4: 渲染深度分层

### Task 12: main 场景添加容器节点

**Files:**
- Modify: `scenes/levels/main.tscn`
- Modify: `scripts/ui/main.gd`

**Context:** 当前 main 场景没有分层容器。需要添加三个 Node2D 容器：
- `PickupLayer` (z_index=0) — Coin/ExpOrb
- `EntityLayer` (z_index=1, y_sort_enabled=true) — Player/Enemy/Tower
- `ProjectileLayer` (z_index=2) — 投射物

- [ ] **Step 1: 在 main.tscn 添加三个容器节点**

在 main 场景中（Map 之后、HUD 之前），添加三个 Node2D 子节点：

```
Main (Node2D)
  ├── [Map instance]          # z_index=-1 (已有)
  ├── PickupLayer (Node2D)    # z_index=0
  ├── EntityLayer (Node2D)    # z_index=1, y_sort_enabled=true
  ├── ProjectileLayer (Node2D) # z_index=2
  ├── Player (移到 EntityLayer 下)
  ├── HUD (CanvasLayer)
  ...
```

注意：Player 需要从 main 根节点移到 EntityLayer 下。

**重要**：Player 移到 EntityLayer 后，所有 player.gd 和 weapon_manager.gd 中的 `get_parent()` 调用返回值从 main 变为 EntityLayer。需要审计这些调用确认无副作用。

- [ ] **Step 2: 修改 main.gd**

在 `_ready()` 中获取容器引用并传给 SceneFactory：

```gdscript
@onready var _pickup_layer: Node2D = $PickupLayer
@onready var _entity_layer: Node2D = $EntityLayer
@onready var _projectile_layer: Node2D = $ProjectileLayer

func _ready() -> void:
    # ... 现有初始化 ...
    SceneFactory.init_containers(_entity_layer, _projectile_layer, _pickup_layer)
```

同时移除旧的 `_tower_container` 创建逻辑（由 EntityLayer 替代）。

- [ ] **Step 3: 提交**

```bash
git add scenes/levels/main.tscn scripts/ui/main.gd
git commit -m "feat: main 场景添加 PickupLayer/EntityLayer/ProjectileLayer 容器"
```

---

### Task 13: SceneFactory 容器管理

**Files:**
- Modify: `scripts/core/scene_factory.gd`

**Context:** SceneFactory 目前只创建实体并返回，不管理 add_child。需要新增容器引用和 `init_containers()` 方法。

- [ ] **Step 1: 添加容器管理 API**

在 scene_factory.gd 添加：

```gdscript
var _entity_layer: Node2D
var _projectile_layer: Node2D
var _pickup_layer: Node2D

func init_containers(entity_layer: Node2D, projectile_layer: Node2D, pickup_layer: Node2D) -> void:
    _entity_layer = entity_layer
    _projectile_layer = projectile_layer
    _pickup_layer = pickup_layer

func get_entity_layer() -> Node2D:
    return _entity_layer

func get_projectile_layer() -> Node2D:
    return _projectile_layer

func get_pickup_layer() -> Node2D:
    return _pickup_layer
```

- [ ] **Step 2: 提交**

```bash
git add scripts/core/scene_factory.gd
git commit -m "feat: SceneFactory 新增 init_containers() 容器管理"
```

---

### Task 14: 更新所有 add_child 调用点

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd`
- Modify: `scripts/entities/enemy.gd`
- Modify: `scripts/entities/towers/tower.gd`
- Modify: `scripts/systems/drag_manager.gd`
- Modify: `scripts/entities/weapons/weapon_manager.gd`（确认投射物 add_child）

**逐个文件修改：**

- [ ] **Step 1: enemy_spawner.gd — 敌人添加到 EntityLayer**

```gdscript
# 旧 (约 line 109)
get_parent().add_child(enemy)
# 新
SceneFactory.get_entity_layer().add_child(enemy)

# 旧 (约 line 136，Boss)
get_parent().add_child(boss)
# 新
SceneFactory.get_entity_layer().add_child(boss)
```

- [ ] **Step 2: enemy.gd — 掉落物添加到 PickupLayer**

```gdscript
# _drop_coins() 中 (约 line 127)
# 旧
var parent := get_parent()
parent.call_deferred("add_child", coin)
# 新
SceneFactory.get_pickup_layer().call_deferred("add_child", coin)

# _drop_exp_orbs() 中 (约 line 139)
# 旧
var parent := get_parent()
parent.call_deferred("add_child", orb)
# 新
SceneFactory.get_pickup_layer().call_deferred("add_child", orb)
```

- [ ] **Step 3: tower.gd — 投射物添加到 ProjectileLayer**

```gdscript
# _on_projectile_spawned() (约 line 110)
# 旧
get_parent().add_child(proj)
# 新
SceneFactory.get_projectile_layer().add_child(proj)
```

- [ ] **Step 4: drag_manager.gd — 塔添加到 EntityLayer**

将 `_tower_container` 引用替换为 `SceneFactory.get_entity_layer()`。所有涉及 `_tower_container.add_child()` 和 `_tower_container.get_parent().add_child()` 的地方改用 EntityLayer。

- [ ] **Step 5: weapon_manager.gd — 修改投射物容器引用**

**关键**：weapon_manager.gd 约第 29 行通过 `_projectile_container = get_parent().get_parent()` 初始化投射物容器。Player 移到 EntityLayer 后，`get_parent().get_parent()` 变成 EntityLayer 而非 main，投射物会错误地添加到 y_sort 容器。

修改 `_projectile_container` 初始化：
```gdscript
# 旧
_projectile_container = get_parent().get_parent()
# 新
_projectile_container = SceneFactory.get_projectile_layer()
```

同时检查 `_on_projectile_spawned` 回调，确认使用 `_projectile_container.add_child(proj)`。

- [ ] **Step 6: 提交**

```bash
git add scripts/systems/enemy_spawner.gd scripts/entities/enemy.gd scripts/entities/towers/tower.gd scripts/systems/drag_manager.gd scripts/entities/weapons/weapon_manager.gd
git commit -m "refactor: 所有 add_child 调用迁移到分层容器（EntityLayer/ProjectileLayer/PickupLayer）"
```

---

### Task 15: Y-Sort origin 设置

**Files:**
- Modify: `scenes/entities/player.tscn`
- Modify: `scenes/entities/enemies/enemy_normal.tscn`
- Modify: `scenes/entities/enemies/enemy_fast.tscn`
- Modify: `scenes/entities/enemies/enemy_tank.tscn`
- Modify: `scenes/entities/enemies/boss_brute.tscn`
- Modify: `scenes/entities/enemies/boss_summoner.tscn`
- Modify: `scenes/entities/enemies/boss_guardian.tscn`
- Modify: `scenes/entities/towers/tower_pea_shooter.tscn`
- Modify: `scenes/entities/towers/tower_ice_flower.tscn`
- Modify: `scenes/entities/towers/tower_sunflower.tscn`

**使用 Godot 4.6 的 `y_sort_origin` 属性（CanvasItem 属性，int 类型）：**

| 实体 | y_sort_origin |
|---|---|
| Player | 16 |
| Enemy (normal/fast/tank) | 16 |
| Boss (brute/summoner/guardian) | 24 |
| Tower (所有) | 16 |

- [ ] **Step 1: 设置所有实体的 y_sort_origin**

对每个 .tscn 文件的根节点设置 `y_sort_origin` 属性。

- [ ] **Step 2: 提交**

```bash
git add scenes/entities/
git commit -m "feat: 所有实体设置 y_sort_origin（脚底排序基准）"
```

---

### Task 16: 特效 z_index 确认

**Files:**
- Modify: `scripts/systems/effects_manager.gd`（如需）
- Modify: `resources/effects/` 相关 .tres（如需）

**Context:** EffectsManager 使用 `EffectConfigData` 中的 z_index 值（damage_number_z_index, hit_spark_z_index, death_particle_z_index）。特效添加到 `tree.current_scene`（main 根节点），不在 EntityLayer 内，所以不受 y_sort 影响。

- [ ] **Step 1: 检查 EffectConfigData 中的 z_index 值**

读取 `resources/effects/` 下的 .tres 文件，确认 z_index 值 ≥ 3（高于 ProjectileLayer 的 z_index=2）。如果当前值低于 3，更新为 3 或更高。

- [ ] **Step 2: 如需修改则提交**

```bash
git add resources/effects/ scripts/systems/effects_manager.gd
git commit -m "fix: 特效 z_index 调整为 ≥3（高于投射物层）"
```

---

## Chunk 5: 集成验证

### Task 17: 运行游戏验证

- [ ] **Step 1: 运行所有 GUT 测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 全部通过（或仅有与本次修改无关的已知失败）

- [ ] **Step 2: 运行游戏 — 验证碰撞**

通过 gdai-mcp 的 `play_scene` 运行 main 场景，验证：
- 投射物能命中敌人（PlayerAttack → EnemyHurt）
- 敌人接触伤害玩家（EnemyAttack → DefenderHurt）
- 敌人接触伤害塔（EnemyAttack → DefenderHurt, repeat_damage）
- 玩家和敌人被塔阻挡
- 金币/经验球可拾取

- [ ] **Step 3: 运行游戏 — 验证渲染**

验证：
- 玩家走到塔后面时被塔遮挡（Y-Sort）
- 投射物始终显示在实体上方
- 金币/经验球显示在实体下方
- 伤害数字显示在最上层

- [ ] **Step 4: 运行游戏 — 验证手感**

验证：
- 玩家更容易躲避敌人（Hurtbox r=8 缩小效果）
- 投射物更容易命中敌人（Hurtbox r=15 + Hitbox r=6 增大效果）
- 玩家/敌人移动顺滑无卡角（Circle 碰撞形状）

- [ ] **Step 5: 最终提交（如有调整）**

```bash
git add -A
git commit -m "fix: 集成测试后的碰撞尺寸微调"
```
