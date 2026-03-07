# Player / Weapon / Projectile 架构重构实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 Player/Weapon/Projectile 解耦，引入 Hitbox/Hurtbox 伤害体系，WeaponManager 支持多武器。

**Architecture:** Hitbox(Area2D) 携带伤害数据，Hurtbox(Area2D) 接收并触发 HealthComponent。Weapon 基类 + 三个子类通过 WeaponManager 统一管理，每帧查找一次目标分发给所有武器。Projectile 基类 + 三个子类负责飞行表现和 Hitbox 碰撞。

**Tech Stack:** Godot 4.6，GDScript，GUT 测试框架，gdai-mcp 操作场景树

**设计文档：** `docs/plans/2026-03-07-player-weapon-projectile-refactor-design.md`

**测试运行命令：**
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
单文件测试（加 `-gtest=res://tests/unit/test_xxx.gd`）

---

## Task 1: Hitbox 组件

**Files:**
- Create: `scripts/components/hitbox.gd`
- Test: `tests/unit/test_hitbox.gd`

**Step 1: 写失败测试**

```gdscript
# tests/unit/test_hitbox.gd
extends GutTest

func test_hitbox_has_default_values():
    var hitbox = Hitbox.new()
    add_child_autofree(hitbox)
    assert_eq(hitbox.damage, 0.0)
    assert_eq(hitbox.knockback_force, 0.0)

func test_hitbox_values_can_be_set():
    var hitbox = Hitbox.new()
    add_child_autofree(hitbox)
    hitbox.damage = 25.0
    hitbox.knockback_force = 150.0
    assert_eq(hitbox.damage, 25.0)
    assert_eq(hitbox.knockback_force, 150.0)
```

**Step 2: 运行测试，确认失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit -gtest=res://tests/unit/test_hitbox.gd
```
预期：FAIL — "Hitbox not found"

**Step 3: 实现**

```gdscript
# scripts/components/hitbox.gd
class_name Hitbox
extends Area2D

var damage: float = 0.0
var knockback_force: float = 0.0
# 碰撞层在 .tscn 中配置，不在脚本里硬编码
```

**Step 4: 运行测试，确认通过**

**Step 5: Commit**

```bash
git add scripts/components/hitbox.gd tests/unit/test_hitbox.gd
git commit -m "feat: 添加 Hitbox 组件"
```

---

## Task 2: Hurtbox 组件

**Files:**
- Create: `scripts/components/hurtbox.gd`
- Test: `tests/unit/test_hurtbox.gd`

**Step 1: 写失败测试**

```gdscript
# tests/unit/test_hurtbox.gd
extends GutTest

func test_hurtbox_emits_hit_taken_when_hitbox_enters():
    var hurtbox = Hurtbox.new()
    add_child_autofree(hurtbox)

    var hitbox = Hitbox.new()
    hitbox.damage = 25.0
    hitbox.knockback_force = 100.0
    hitbox.global_position = Vector2(10, 0)  # 非零以产生方向

    var received_damage: float = -1.0
    var received_knockback: Vector2 = Vector2.ZERO
    hurtbox.hit_taken.connect(func(dmg, kb): received_damage = dmg; received_knockback = kb)

    # 直接调用，绕过物理引擎
    hurtbox._on_area_entered(hitbox)

    assert_eq(received_damage, 25.0)
    assert_true(received_knockback.length() > 0.0, "knockback should have direction")

func test_hurtbox_ignores_non_hitbox_areas():
    var hurtbox = Hurtbox.new()
    add_child_autofree(hurtbox)

    var signal_received: bool = false
    hurtbox.hit_taken.connect(func(_d, _k): signal_received = true)

    var other_area = Area2D.new()
    add_child_autofree(other_area)
    hurtbox._on_area_entered(other_area)

    assert_false(signal_received)
```

**Step 2: 运行测试，确认失败**

**Step 3: 实现**

```gdscript
# scripts/components/hurtbox.gd
class_name Hurtbox
extends Area2D

signal hit_taken(damage: float, knockback_dir: Vector2)

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
    if not area is Hitbox:
        return
    var dir: Vector2 = area.global_position.direction_to(global_position)
    hit_taken.emit(area.damage, dir * area.knockback_force)
```

**Step 4: 运行测试，确认通过**

**Step 5: Commit**

```bash
git add scripts/components/hurtbox.gd tests/unit/test_hurtbox.gd
git commit -m "feat: 添加 Hurtbox 组件"
```

---

## Task 3: Projectile 基类

**Files:**
- Create: `scripts/entities/projectiles/projectile.gd`
- Test: `tests/unit/test_projectile.gd`

**Step 1: 写失败测试**

```gdscript
# tests/unit/test_projectile.gd
extends GutTest

func test_projectile_setup_sets_position_and_hitbox():
    var proj = Projectile.new()
    var hitbox = Hitbox.new()
    hitbox.name = "Hitbox"
    proj.add_child(hitbox)
    add_child_autofree(proj)

    proj.setup(30.0, 80.0, Vector2(100, 200), Vector2.RIGHT)

    assert_eq(proj.global_position, Vector2(100, 200))
    assert_eq(proj.hitbox.damage, 30.0)
    assert_eq(proj.hitbox.knockback_force, 80.0)
```

**Step 2: 运行测试，确认失败**

**Step 3: 实现**

```gdscript
# scripts/entities/projectiles/projectile.gd
class_name Projectile
extends Node2D

@onready var hitbox: Hitbox = $Hitbox

func setup(damage: float, knockback_force: float, from: Vector2, direction: Vector2) -> void:
    global_position = from
    hitbox.damage = damage
    hitbox.knockback_force = knockback_force
    _on_setup(direction)

func _on_setup(_direction: Vector2) -> void:
    pass  # 子类实现
```

**Step 4: 运行测试，确认通过**

**Step 5: Commit**

```bash
git add scripts/entities/projectiles/projectile.gd tests/unit/test_projectile.gd
git commit -m "feat: 添加 Projectile 基类"
```

---

## Task 4: BulletProjectile 脚本 + 场景

**Files:**
- Create: `scripts/entities/projectiles/bullet_projectile.gd`
- Create: `scenes/entities/projectiles/bullet_projectile.tscn` (gdai-mcp)
- Test: `tests/unit/test_bullet_projectile.gd`

**Step 1: 写失败测试**

```gdscript
# tests/unit/test_bullet_projectile.gd
extends GutTest

func test_bullet_moves_in_direction():
    var bullet = BulletProjectile.new()
    var hitbox = Hitbox.new()
    hitbox.name = "Hitbox"
    bullet.add_child(hitbox)
    add_child_autofree(bullet)

    bullet.setup(10.0, 50.0, Vector2.ZERO, Vector2.RIGHT)
    var start_x: float = bullet.global_position.x
    bullet._physics_process(0.1)

    assert_true(bullet.global_position.x > start_x, "bullet should move right")

func test_bullet_queue_frees_after_lifetime():
    var bullet = BulletProjectile.new()
    var hitbox = Hitbox.new()
    hitbox.name = "Hitbox"
    bullet.add_child(hitbox)
    add_child_autofree(bullet)

    bullet.setup(10.0, 50.0, Vector2.ZERO, Vector2.RIGHT)
    bullet._physics_process(bullet.lifetime + 0.1)

    assert_true(bullet.is_queued_for_deletion())
```

**Step 2: 运行测试，确认失败**

**Step 3: 实现脚本**

```gdscript
# scripts/entities/projectiles/bullet_projectile.gd
class_name BulletProjectile
extends Projectile

var speed: float = 600.0
var lifetime: float = 5.0
var _elapsed: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _trail: Line2D = null
var _trail_positions: Array[Vector2] = []

func _on_setup(direction: Vector2) -> void:
    _direction = direction
    _elapsed = 0.0
    var fx: EffectConfigData = GameConfig.effects
    _trail = Line2D.new()
    _trail.width = fx.bullet_trail_width
    _trail.default_color = fx.bullet_trail_color
    _trail.z_index = -1
    _trail.top_level = true
    add_child(_trail)
    hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(delta: float) -> void:
    global_position += _direction * speed * delta
    _elapsed += delta
    _update_trail()
    if _elapsed >= lifetime:
        queue_free()

func _update_trail() -> void:
    _trail_positions.insert(0, global_position)
    var max_pts: int = GameConfig.effects.bullet_trail_max_points
    if _trail_positions.size() > max_pts:
        _trail_positions.resize(max_pts)
    _trail.clear_points()
    for pos in _trail_positions:
        _trail.add_point(pos)

func _on_hitbox_area_entered(area: Area2D) -> void:
    if area is Hurtbox:
        EffectsManager.spawn_hit_sparks(global_position)
        queue_free()
```

**Step 4: 用 gdai-mcp 创建场景**

使用 gdai-mcp 创建 `scenes/entities/projectiles/bullet_projectile.tscn`：
- 根节点：Node2D，脚本挂 `bullet_projectile.gd`，命名 `BulletProjectile`
- 子节点：`Hitbox (Area2D)` — collision_layer=4, collision_mask=128，添加 CircleShape2D(radius=4)

**Step 5: 更新 SceneFactory 预加载（仅加，不删旧）**

```gdscript
# scripts/core/scene_factory.gd 新增
var _bullet_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/bullet_projectile.tscn")

func create_bullet_projectile() -> BulletProjectile:
    return _bullet_projectile_scene.instantiate()
```

**Step 6: 运行测试，确认通过**

**Step 7: Commit**

```bash
git add scripts/entities/projectiles/bullet_projectile.gd \
        scenes/entities/projectiles/bullet_projectile.tscn \
        scripts/core/scene_factory.gd \
        tests/unit/test_bullet_projectile.gd
git commit -m "feat: 添加 BulletProjectile 及场景"
```

---

## Task 5: BoomerangProjectile 脚本 + 场景

**Files:**
- Create: `scripts/entities/projectiles/boomerang_projectile.gd`
- Create: `scenes/entities/projectiles/boomerang_projectile.tscn` (gdai-mcp)
- Test: `tests/unit/test_boomerang_projectile.gd`

**Step 1: 写失败测试**

```gdscript
# tests/unit/test_boomerang_projectile.gd
extends GutTest

func _make_boomerang() -> BoomerangProjectile:
    var b = BoomerangProjectile.new()
    var hitbox = Hitbox.new()
    hitbox.name = "Hitbox"
    b.add_child(hitbox)
    add_child_autofree(b)
    return b

func test_boomerang_moves_outbound():
    var b = _make_boomerang()
    b.setup(10.0, 50.0, Vector2.ZERO, Vector2.RIGHT)
    b._physics_process(0.1)
    assert_true(b.global_position.x > 0.0)

func test_boomerang_switches_to_returning_after_distance():
    var b = _make_boomerang()
    b.setup(10.0, 50.0, Vector2.ZERO, Vector2.RIGHT)
    # 强制走完出程距离
    b._traveled = b.outbound_distance + 1.0
    b._physics_process(0.016)
    assert_eq(b._state, "RETURNING")

func test_boomerang_returns_toward_player():
    var b = _make_boomerang()
    var player_node = Node2D.new()
    player_node.global_position = Vector2(-100, 0)
    add_child_autofree(player_node)
    b.setup(10.0, 50.0, Vector2(100, 0), Vector2.RIGHT)
    b._state = "RETURNING"
    b._player = player_node
    var start_x: float = b.global_position.x
    b._physics_process(0.1)
    assert_true(b.global_position.x < start_x, "should move toward player")
```

**Step 2: 运行测试，确认失败**

**Step 3: 实现脚本**

```gdscript
# scripts/entities/projectiles/boomerang_projectile.gd
class_name BoomerangProjectile
extends Projectile

var speed: float = 350.0
var outbound_distance: float = 200.0
var return_speed_mult: float = 1.3
var max_lifetime: float = 5.0

var _state: String = "OUTBOUND"
var _traveled: float = 0.0
var _elapsed: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _hit_outbound: Array = []
var _hit_returning: Array = []
var _player: Node2D = null
var _trail: Line2D = null
var _trail_positions: Array[Vector2] = []

func _on_setup(direction: Vector2) -> void:
    _direction = direction
    var w: WeaponData = GameConfig.weapons["boomerang"]
    speed = w.boomerang_speed
    outbound_distance = w.outbound_distance
    return_speed_mult = w.return_speed_mult
    var fx: EffectConfigData = GameConfig.effects
    _trail = Line2D.new()
    _trail.width = fx.boomerang_trail_width
    _trail.default_color = fx.boomerang_trail_color
    _trail.top_level = true
    _trail.z_index = -1
    add_child(_trail)
    hitbox.area_entered.connect(_on_hitbox_area_entered)

func set_player(player_node: Node2D) -> void:
    _player = player_node

func _physics_process(delta: float) -> void:
    _elapsed += delta
    if _elapsed >= max_lifetime:
        queue_free()
        return
    var fx: EffectConfigData = GameConfig.effects
    rotation += deg_to_rad(fx.boomerang_rotation_speed) * delta
    _update_trail()
    match _state:
        "OUTBOUND":  _process_outbound(delta)
        "RETURNING": _process_returning(delta)

func _process_outbound(delta: float) -> void:
    var dist: float = speed * delta
    global_position += _direction * dist
    _traveled += dist
    if _traveled >= outbound_distance:
        _state = "RETURNING"

func _process_returning(delta: float) -> void:
    if not is_instance_valid(_player):
        queue_free()
        return
    var to_player: Vector2 = _player.global_position - global_position
    if to_player.length() < GameConfig.effects.boomerang_return_distance:
        queue_free()
        return
    global_position += to_player.normalized() * speed * return_speed_mult * delta

func _update_trail() -> void:
    var fx: EffectConfigData = GameConfig.effects
    _trail_positions.insert(0, global_position)
    if _trail_positions.size() > fx.boomerang_trail_points:
        _trail_positions.resize(fx.boomerang_trail_points)
    _trail.clear_points()
    for pos in _trail_positions:
        _trail.add_point(pos)

func _on_hitbox_area_entered(area: Area2D) -> void:
    if not area is Hurtbox:
        return
    var owner_node: Node = area.get_parent()
    match _state:
        "OUTBOUND":
            if owner_node not in _hit_outbound:
                _hit_outbound.append(owner_node)
        "RETURNING":
            if owner_node not in _hit_returning:
                _hit_returning.append(owner_node)
    # 伤害已由 Hurtbox 信号处理，此处只做穿透去重
```

> 注意：BoomerangProjectile 的伤害由 Hurtbox 的 `hit_taken` 信号触发，`_on_hitbox_area_entered` 只负责穿透去重（同一敌人单程只受一次伤）。

**Step 4: 用 gdai-mcp 创建场景**

`scenes/entities/projectiles/boomerang_projectile.tscn`：
- 根节点：Node2D，脚本挂 `boomerang_projectile.gd`
- 子节点：`Hitbox (Area2D)` — collision_layer=4, collision_mask=128，添加 CircleShape2D(radius=6)

**Step 5: 更新 SceneFactory**

```gdscript
var _boomerang_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/boomerang_projectile.tscn")

func create_boomerang_projectile() -> BoomerangProjectile:
    return _boomerang_projectile_scene.instantiate()
```

**Step 6: 运行测试，确认通过**

**Step 7: Commit**

```bash
git add scripts/entities/projectiles/boomerang_projectile.gd \
        scenes/entities/projectiles/boomerang_projectile.tscn \
        scripts/core/scene_factory.gd \
        tests/unit/test_boomerang_projectile.gd
git commit -m "feat: 添加 BoomerangProjectile 及场景"
```

---

## Task 6: LaserProjectile 脚本 + 场景

**Files:**
- Create: `scripts/entities/projectiles/laser_projectile.gd`
- Create: `scenes/entities/projectiles/laser_projectile.tscn` (gdai-mcp)
- Test: `tests/unit/test_laser_projectile.gd`

**Step 1: 写失败测试**

```gdscript
# tests/unit/test_laser_projectile.gd
extends GutTest

func test_laser_frees_after_duration():
    var laser = LaserProjectile.new()
    var hitbox = Hitbox.new()
    hitbox.name = "Hitbox"
    var shape = CollisionShape2D.new()
    shape.name = "HitboxShape"
    hitbox.add_child(shape)
    laser.add_child(hitbox)
    add_child_autofree(laser)

    laser.setup(20.0, 0.0, Vector2.ZERO, Vector2.RIGHT)
    laser._process(laser.beam_duration + 0.01)

    assert_true(laser.is_queued_for_deletion())

func test_laser_has_correct_damage():
    var laser = LaserProjectile.new()
    var hitbox = Hitbox.new()
    hitbox.name = "Hitbox"
    var shape = CollisionShape2D.new()
    shape.name = "HitboxShape"
    hitbox.add_child(shape)
    laser.add_child(hitbox)
    add_child_autofree(laser)

    laser.setup(42.0, 0.0, Vector2.ZERO, Vector2.RIGHT)

    assert_eq(laser.hitbox.damage, 42.0)
```

**Step 2: 运行测试，确认失败**

**Step 3: 实现脚本**

```gdscript
# scripts/entities/projectiles/laser_projectile.gd
class_name LaserProjectile
extends Projectile

var beam_duration: float = 0.08
var beam_range: float = 400.0
var _elapsed: float = 0.0
var _line: Line2D = null

@onready var _hitbox_shape: CollisionShape2D = $Hitbox/HitboxShape

func _on_setup(direction: Vector2) -> void:
    _elapsed = 0.0
    # 拉伸 Hitbox 覆盖激光路径
    var rect = RectangleShape2D.new()
    rect.size = Vector2(beam_range, 8.0)
    _hitbox_shape.shape = rect
    _hitbox_shape.position = direction * beam_range * 0.5
    _hitbox_shape.rotation = direction.angle()
    # 视觉 Line2D
    _line = Line2D.new()
    _line.width = 3.0
    _line.default_color = Color(1, 0.2, 0.2, 0.9)
    _line.add_point(Vector2.ZERO)
    _line.add_point(direction * beam_range)
    add_child(_line)

func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed >= beam_duration:
        queue_free()
```

**Step 4: 用 gdai-mcp 创建场景**

`scenes/entities/projectiles/laser_projectile.tscn`：
- 根节点：Node2D，脚本挂 `laser_projectile.gd`
- 子节点：`Hitbox (Area2D)` — collision_layer=4, collision_mask=128
  - 子节点：`HitboxShape (CollisionShape2D)` — 暂无 shape（由脚本在 `_on_setup` 里动态设置）

**Step 5: 更新 SceneFactory**

```gdscript
var _laser_projectile_scene: PackedScene = preload("res://scenes/entities/projectiles/laser_projectile.tscn")

func create_laser_projectile() -> LaserProjectile:
    return _laser_projectile_scene.instantiate()
```

**Step 6: 运行测试，确认通过**

**Step 7: Commit**

```bash
git add scripts/entities/projectiles/laser_projectile.gd \
        scenes/entities/projectiles/laser_projectile.tscn \
        scripts/core/scene_factory.gd \
        tests/unit/test_laser_projectile.gd
git commit -m "feat: 添加 LaserProjectile 及场景"
```

---

## Task 7: Weapon 基类 + 三个子类

**Files:**
- Create: `scripts/entities/weapons/weapon.gd`
- Create: `scripts/entities/weapons/bullet_weapon.gd`
- Create: `scripts/entities/weapons/boomerang_weapon.gd`
- Create: `scripts/entities/weapons/laser_weapon.gd`
- Test: `tests/unit/test_weapon.gd`

**Step 1: 写失败测试**

```gdscript
# tests/unit/test_weapon.gd
extends GutTest

func test_weapon_does_not_fire_before_cooldown():
    var w = Weapon.new()
    add_child_autofree(w)
    w.weapon_data = WeaponData.new()
    w.weapon_data.fire_rate = 1.0
    w.weapon_data.damage = 10.0

    var fired: bool = false
    w.set("_fire_called", false)  # 仅验证 tick 不会在冷却内调用 fire

    # 注入 mock fire，通过信号验证
    w._cooldown = 0.5  # 还有 0.5s 冷却
    var target = Node2D.new()
    add_child_autofree(target)
    w.tick(0.1, target)

    # 冷却应还剩 0.4s，fire 不应被调用
    assert_almost_eq(w._cooldown, 0.4, 0.001)

func test_weapon_fires_when_cooldown_reaches_zero():
    var w = Weapon.new()
    add_child_autofree(w)
    w.weapon_data = WeaponData.new()
    w.weapon_data.fire_rate = 0.5
    w.weapon_data.damage = 10.0
    w._cooldown = 0.0

    var target = Node2D.new()
    add_child_autofree(target)
    # fire() 在基类是 pass，所以调用不会崩溃，冷却应被重置
    w.tick(0.016, target)
    assert_almost_eq(w._cooldown, 0.5, 0.01)
```

**Step 2: 运行测试，确认失败**

**Step 3: 实现基类**

```gdscript
# scripts/entities/weapons/weapon.gd
class_name Weapon
extends Node

var weapon_data: WeaponData = null
var _cooldown: float = 0.0

func initialize(data: WeaponData) -> void:
    weapon_data = data
    _cooldown = 0.0

func tick(delta: float, target: Node2D) -> void:
    _cooldown -= delta
    if _cooldown <= 0.0 and target:
        fire(target)
        var speed_mult: float = GameData.player_stats.get("attack_speed_mult", 1.0)
        _cooldown = weapon_data.fire_rate / speed_mult

func fire(_target: Node2D) -> void:
    pass  # 子类实现
```

**Step 4: 实现三个子类**

```gdscript
# scripts/entities/weapons/bullet_weapon.gd
class_name BulletWeapon
extends Weapon

func fire(target: Node2D) -> void:
    var owner_node: Node2D = get_parent() as Node2D
    if not owner_node:
        return
    var final_damage: float = weapon_data.damage * GameData.player_stats.get("damage_mult", 1.0)
    var direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
    var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
    bullet.speed = weapon_data.bullet_speed
    var scene_parent: Node = owner_node.get_parent()
    if not scene_parent:
        return
    scene_parent.add_child(bullet)
    bullet.setup(final_damage, 80.0, owner_node.global_position, direction)
    _spawn_muzzle_flash(owner_node)

func _spawn_muzzle_flash(owner_node: Node2D) -> void:
    var fx: EffectConfigData = GameConfig.effects
    var flash: ColorRect = ColorRect.new()
    flash.size = fx.muzzle_flash_size
    flash.position = owner_node.global_position - fx.muzzle_flash_size / 2
    flash.color = fx.muzzle_flash_color
    flash.z_index = fx.muzzle_flash_z_index
    var parent: Node = owner_node.get_parent()
    if parent:
        parent.add_child(flash)
        var tween: Tween = owner_node.create_tween()
        tween.tween_property(flash, "scale", Vector2(0.1, 0.1), fx.muzzle_flash_duration).set_ease(Tween.EASE_OUT)
        tween.tween_callback(flash.queue_free)
```

```gdscript
# scripts/entities/weapons/boomerang_weapon.gd
class_name BoomerangWeapon
extends Weapon

func fire(target: Node2D) -> void:
    var owner_node: Node2D = get_parent() as Node2D
    if not owner_node:
        return
    var final_damage: float = weapon_data.damage * GameData.player_stats.get("damage_mult", 1.0)
    var direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
    var boomerang: BoomerangProjectile = SceneFactory.create_boomerang_projectile()
    var scene_parent: Node = owner_node.get_parent()
    if not scene_parent:
        return
    scene_parent.add_child(boomerang)
    boomerang.set_player(owner_node)
    boomerang.setup(final_damage, 60.0, owner_node.global_position, direction)
```

```gdscript
# scripts/entities/weapons/laser_weapon.gd
class_name LaserWeapon
extends Weapon

func fire(target: Node2D) -> void:
    var owner_node: Node2D = get_parent() as Node2D
    if not owner_node:
        return
    var final_damage: float = weapon_data.damage * GameData.player_stats.get("damage_mult", 1.0)
    var direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
    var laser: LaserProjectile = SceneFactory.create_laser_projectile()
    laser.beam_range = weapon_data.beam_range
    laser.beam_duration = weapon_data.beam_duration
    var scene_parent: Node = owner_node.get_parent()
    if not scene_parent:
        return
    scene_parent.add_child(laser)
    laser.setup(final_damage, 0.0, owner_node.global_position, direction)
    _spawn_laser_flash(owner_node, scene_parent)

func _spawn_laser_flash(owner_node: Node2D, scene_parent: Node) -> void:
    var fx: EffectConfigData = GameConfig.effects
    var flash: ColorRect = ColorRect.new()
    flash.color = Color(1, 0, 0, fx.laser_flash_alpha)
    flash.size = fx.laser_flash_size
    flash.position = owner_node.global_position - fx.laser_flash_size / 2
    flash.z_index = fx.laser_flash_z_index
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    scene_parent.add_child(flash)
    var tween: Tween = owner_node.create_tween()
    tween.tween_property(flash, "modulate:a", 0.0, fx.laser_flash_duration)
    tween.tween_callback(flash.queue_free)
```

**Step 5: 运行测试，确认通过**

**Step 6: Commit**

```bash
git add scripts/entities/weapons/
git commit -m "feat: 添加 Weapon 基类及 Bullet/Boomerang/Laser 子类"
```

---

## Task 8: WeaponManager

**Files:**
- Create: `scripts/entities/weapons/weapon_manager.gd`
- Test: `tests/unit/test_weapon_manager.gd`

**Step 1: 写失败测试**

```gdscript
# tests/unit/test_weapon_manager.gd
extends GutTest

func test_weapon_manager_initializes_weapons():
    var mgr = WeaponManager.new()
    add_child_autofree(mgr)

    # 注入 mock GameConfig 武器（需要 rifle WeaponData 存在）
    var wm = mgr
    wm.initialize(["rifle"])
    assert_eq(wm._weapons.size(), 1)

func test_weapon_manager_add_weapon():
    var mgr = WeaponManager.new()
    add_child_autofree(mgr)

    var data = WeaponData.new()
    data.projectile_type = "bullet"
    data.fire_rate = 0.5
    data.damage = 10.0
    mgr._add_weapon(data)

    assert_eq(mgr._weapons.size(), 1)
    assert_true(mgr._weapons[0] is BulletWeapon)
```

**Step 2: 运行测试，确认失败**

**Step 3: 实现**

```gdscript
# scripts/entities/weapons/weapon_manager.gd
class_name WeaponManager
extends Node

var _weapons: Array[Weapon] = []

func initialize(weapon_ids: Array[String]) -> void:
    for id in weapon_ids:
        if not GameConfig.weapons.has(id):
            push_error("WeaponManager: unknown weapon id: " + id)
            continue
        _add_weapon(GameConfig.weapons[id])

func _add_weapon(data: WeaponData) -> void:
    var weapon: Weapon = _create_weapon(data.projectile_type)
    weapon.initialize(data)
    add_child(weapon)
    _weapons.append(weapon)

func tick(delta: float) -> void:
    var target: Node2D = _find_closest_enemy()
    for weapon in _weapons:
        weapon.tick(delta, target)

func _find_closest_enemy() -> Node2D:
    var owner_node: Node2D = get_parent() as Node2D
    if not owner_node:
        return null
    var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
    var closest: Node2D = null
    var min_dist: float = INF
    for enemy in enemies:
        if enemy is Node2D:
            var dist: float = owner_node.global_position.distance_to(enemy.global_position)
            if dist < min_dist:
                min_dist = dist
                closest = enemy
    return closest

func _create_weapon(projectile_type: String) -> Weapon:
    match projectile_type:
        "bullet":    return BulletWeapon.new()
        "boomerang": return BoomerangWeapon.new()
        "laser":     return LaserWeapon.new()
    push_error("WeaponManager: unknown projectile_type: " + projectile_type)
    return Weapon.new()
```

**Step 4: 运行测试，确认通过**

**Step 5: Commit**

```bash
git add scripts/entities/weapons/weapon_manager.gd tests/unit/test_weapon_manager.gd
git commit -m "feat: 添加 WeaponManager"
```

---

## Task 9: Player 场景更新（gdai-mcp）

**Files:**
- Modify: `scenes/entities/player.tscn` (gdai-mcp)

**Step 1: 用 gdai-mcp 打开 player.tscn**

**Step 2: 删除 WeaponSystem 节点**

用 gdai-mcp 删除 `WeaponSystem` 子节点。

**Step 3: 添加 WeaponManager 节点**

用 gdai-mcp 添加 Node 节点，命名 `WeaponManager`，挂载脚本 `scripts/entities/weapons/weapon_manager.gd`。

**Step 4: 添加 Hurtbox 节点**

用 gdai-mcp 添加 Area2D 节点，命名 `Hurtbox`，挂载脚本 `scripts/components/hurtbox.gd`。
- collision_layer = 64（Layer 7）
- collision_mask = 32（Layer 6）
- 添加 CollisionShape2D 子节点，形状 CircleShape2D(radius=12)

**Step 5: 保存并验证场景树结构**

```
Player (CharacterBody2D)
  ├─ HealthComponent
  ├─ Hurtbox (Area2D)      ← 新增
  ├─ WeaponManager (Node)  ← 替换 WeaponSystem
  ├─ SpriteAnimator
  └─ Camera
```

**Step 6: Commit**

```bash
git add scenes/entities/player.tscn
git commit -m "feat: 更新 player 场景，添加 Hurtbox 替换 WeaponSystem"
```

---

## Task 10: Player 脚本更新

**Files:**
- Modify: `scripts/entities/player.gd`
- Test: `tests/unit/test_player.gd`（如已存在则更新）

**Step 1: 写失败测试（验证新信号流）**

```gdscript
# tests/unit/test_player.gd（新增用例）
func test_player_takes_damage_from_hurtbox_signal():
    # 通过 _on_hurtbox_hit 直接测试伤害逻辑
    var player = preload("res://scenes/entities/player.tscn").instantiate()
    add_child_autofree(player)
    await get_tree().process_frame

    var initial_hp: float = player.health.current_hp
    player._on_hurtbox_hit(10.0, Vector2.ZERO)

    assert_lt(player.health.current_hp, initial_hp)

func test_player_invincible_after_hit():
    var player = preload("res://scenes/entities/player.tscn").instantiate()
    add_child_autofree(player)
    await get_tree().process_frame

    player._on_hurtbox_hit(10.0, Vector2.ZERO)
    assert_true(player.invincible_timer > 0.0)

func test_player_ignores_damage_when_invincible():
    var player = preload("res://scenes/entities/player.tscn").instantiate()
    add_child_autofree(player)
    await get_tree().process_frame

    player.invincible_timer = 1.0
    var hp_before: float = player.health.current_hp
    player._on_hurtbox_hit(10.0, Vector2.ZERO)

    assert_eq(player.health.current_hp, hp_before)
```

**Step 2: 修改 player.gd**

```gdscript
# 删除的内容：
# - @onready var _weapon: WeaponSystem
# - _weapon.initialize(...) 和 _weapon.process(delta)
# - check_enemy_collision() 整个方法
# - collision_mask 里的敌人 body 检测（改由 Hurtbox 负责）

# 新增/修改的内容：

@onready var _weapon_manager: WeaponManager = $WeaponManager

func _ready() -> void:
    # ... 原有代码 ...
    # 替换武器初始化：
    _weapon_manager.initialize([GameData.selected_weapon])
    # 连接 Hurtbox 信号：
    $Hurtbox.hit_taken.connect(_on_hurtbox_hit)
    # 删除 health.died 之外无关内容

func _process(delta: float) -> void:
    # 替换 _weapon.process(delta)：
    _weapon_manager.tick(delta)
    # 删除 invincible_timer 手动递减（移到 _physics_process 或保留）
    if invincible_timer > 0:
        invincible_timer -= delta
    # hp_regen 保留不变

func _physics_process(_delta: float) -> void:
    # 删除末尾的 check_enemy_collision()
    # 保留移动逻辑不变

func _on_hurtbox_hit(damage: float, _knockback_dir: Vector2) -> void:
    if invincible_timer > 0:
        return
    health.take_damage_no_sparks(damage)
    _flash_white()
    invincible_timer = invincible_duration
    var fx: EffectConfigData = GameConfig.effects
    EventBus.camera_shake_requested.emit(
        fx.camera_shake_player_hit_intensity,
        fx.camera_shake_player_hit_duration
    )
    print("Player HP: ", health.current_hp)

# 删除原有的 take_damage() 方法（或保留为内部调用 _on_hurtbox_hit 的包装）
```

**Step 3: 运行测试，确认通过**

**Step 4: Commit**

```bash
git add scripts/entities/player.gd tests/unit/test_player.gd
git commit -m "refactor: player 使用 WeaponManager 和 Hurtbox，移除 check_enemy_collision"
```

---

## Task 11: Enemy 场景更新（gdai-mcp）

**Files:**
- Modify: `scenes/entities/enemies/enemy_normal.tscn` (gdai-mcp)
- Modify: `scenes/entities/enemies/enemy_fast.tscn` (gdai-mcp)
- Modify: `scenes/entities/enemies/enemy_tank.tscn` (gdai-mcp)

对三个敌人场景重复以下步骤：

**Step 1: 用 gdai-mcp 打开场景**

**Step 2: 添加 Hitbox 节点（接触伤害玩家）**

添加 Area2D，命名 `Hitbox`，挂载 `scripts/components/hitbox.gd`：
- collision_layer = 32（Layer 6，enemy_hitbox）
- collision_mask = 64（Layer 7，player_hurtbox）
- 添加 CollisionShape2D，形状与敌人 body 相同大小

> `hitbox.damage` 不在场景设置，由 enemy.gd 的 `_ready()` 里赋值：`$Hitbox.damage = data.damage`

**Step 3: 添加 Hurtbox 节点（承受玩家投射物伤害）**

添加 Area2D，命名 `Hurtbox`，挂载 `scripts/components/hurtbox.gd`：
- collision_layer = 128（Layer 8，enemy_hurtbox）
- collision_mask = 4（Layer 3，player_hitbox）
- 添加 CollisionShape2D，形状与敌人 body 相同大小

**Step 4: Commit**

```bash
git add scenes/entities/enemies/
git commit -m "feat: 为所有敌人场景添加 Hitbox 和 Hurtbox"
```

---

## Task 12: Enemy 脚本更新

**Files:**
- Modify: `scripts/entities/enemy.gd`

**Step 1: 修改 enemy.gd**

```gdscript
@onready var _hitbox: Hitbox = $Hitbox

func _ready():
    # ... 原有代码 ...
    # 新增：设置接触伤害值
    _hitbox.damage = data.damage
    # 新增：连接 Hurtbox 信号
    $Hurtbox.hit_taken.connect(_on_hurtbox_hit)

func _on_hurtbox_hit(damage: float, knockback_dir: Vector2) -> void:
    health.take_damage(damage)
    if knockback_dir.length() > 0:
        _knockback.apply_knockback(knockback_dir.normalized())

# take_damage() 保留不动（塔攻击仍使用）
# apply_knockback() 保留不动
```

**Step 2: 运行全量测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
预期：全部通过（现有 145 个 + 新增）

**Step 3: Commit**

```bash
git add scripts/entities/enemy.gd
git commit -m "refactor: enemy 连接 Hurtbox 信号处理投射物伤害"
```

---

## Task 13: 清理旧文件

**Files（删除）:**
- `scripts/components/weapon_system.gd`
- `scripts/entities/bullet.gd`
- `scripts/entities/boomerang.gd`
- `scripts/entities/laser_beam.gd`
- `scenes/entities/bullet.tscn`
- `scenes/entities/boomerang.tscn`
- `scenes/entities/laser_beam.tscn`

**Files（修改）:**
- `scripts/core/scene_factory.gd`：删除 `create_bullet()`, `create_boomerang()`, `create_laser_beam()` 及对应 preload

**Step 1: 确认无引用**

```bash
grep -r "weapon_system\|create_bullet()\|create_boomerang()\|create_laser_beam\|bullet\.tscn\|boomerang\.tscn\|laser_beam\.tscn" /Users/langtao/utoland/scripts /Users/langtao/utoland/scenes --include="*.gd" --include="*.tscn" -l
```
预期：无输出（或仅在已删除文件中）

**Step 2: 删除文件**

```bash
rm scripts/components/weapon_system.gd
rm scripts/entities/bullet.gd scripts/entities/boomerang.gd scripts/entities/laser_beam.gd
rm scenes/entities/bullet.tscn scenes/entities/boomerang.tscn scenes/entities/laser_beam.tscn
```

**Step 3: 清理 scene_factory.gd 中旧方法**

删除：
```gdscript
var _bullet_scene: PackedScene = preload(...)
var _boomerang_scene: PackedScene = preload(...)
var _laser_beam_scene: PackedScene = preload(...)
func create_bullet() -> Area2D: ...
func create_boomerang() -> Area2D: ...
func create_laser_beam() -> Node2D: ...
```

**Step 4: 运行全量测试，确认通过**

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: 删除旧 WeaponSystem/Bullet/Boomerang/LaserBeam，完成架构重构"
```

---

## Task 14: 运行游戏验证

**Step 1: 用 gdai-mcp run_project 运行游戏**

验证：
- 玩家可以正常移动
- 子弹/回旋镖/激光正常发射并命中敌人
- 敌人接触玩家时玩家掉血
- 无敌帧正常生效（受伤后短暂闪白不继续掉血）
- 击杀敌人正常掉金币

**Step 2: 运行全量测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
预期：全部通过

**Step 3: 最终 Commit**

```bash
git add -A
git commit -m "test: 验证重构后全量测试通过"
```
