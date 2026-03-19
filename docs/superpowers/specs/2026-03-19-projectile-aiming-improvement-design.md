# 投射物瞄准改进设计

## 问题

当前所有投射物发射时瞄准敌人**当前位置**，沿直线飞行。敌人移动时投射物容易打空，塔的攻击尤为明显（塔固定不动，与敌人有距离）。

## 方案概述

采用混合策略：
- **塔**：投射物发射后**追踪目标**（直线追踪，每帧微调方向），保证命中
- **武器**（bow/shuriken）：发射时计算**预判提前量**（lead shot），投射物仍走直线
- **近战**（sword）：不改动，范围即时判定无命中问题
- **shuriken 弹射**：弹射后切换为追踪模式（短距离，高灵敏度）

## 详细设计

### 1. 预判瞄准（武器侧）

**改动文件**：`scripts/components/ranged_attack_component.gd`

**新增属性**：
```gdscript
@export var use_lead_shot: bool = false
```

**改动方法**：`_execute_attack(target)` 中方向计算逻辑：

```gdscript
# 原始逻辑
var direction: Vector2 = fire_pos.direction_to(target.global_position)

# 预判逻辑（use_lead_shot == true 时）
var distance: float = fire_pos.distance_to(target.global_position)
var flight_time: float = distance / projectile_data.speed
var predicted_pos: Vector2 = target.global_position + target.velocity * flight_time
direction = fire_pos.direction_to(predicted_pos)
```

**细节**：
- `CharacterBody2D.velocity` 是 Godot 内置属性，敌人移动时自然有值
- 单次迭代预判，精度足够，性能好
- 若 `target.velocity` 为零或目标无 velocity 属性，fallback 到当前位置
- 武器的 `RangedAttackComponent` 设 `use_lead_shot = true`，塔的不设

### 2. 追踪移动组件（塔侧）

**新增文件**：`scripts/components/tracking_movement_component.gd`

**功能**：投射物飞行中每帧朝目标位置调整方向，保证命中。

```gdscript
class_name TrackingMovementComponent
extends Node

signal lifetime_expired

var speed: float = 300.0
var lifetime: float = 5.0
@export var turn_speed: float = 8.0  # 转向速度（弧度/秒）

var _elapsed: float = 0.0
var _target: Node2D = null

func on_projectile_setup(projectile: Node2D) -> void:
    speed = projectile.data.speed
    lifetime = projectile.data.lifetime
    _target = projectile.target  # 从 Projectile.target 读取
    _elapsed = 0.0
    set_physics_process(true)

func _physics_process(delta: float) -> void:
    var proj: Node2D = get_parent()
    if not proj:
        return
    # 追踪：目标有效时持续调整方向
    if _target and is_instance_valid(_target):
        var desired: Vector2 = proj.global_position.direction_to(_target.global_position)
        proj.direction = proj.direction.slerp(desired, turn_speed * delta).normalized()
        proj.rotation = proj.direction.angle()
    # 移动
    proj.position += proj.direction * speed * delta
    # 生命周期
    _elapsed += delta
    if _elapsed >= lifetime:
        lifetime_expired.emit()
        proj.request_destroy()

func reset() -> void:
    _elapsed = 0.0
    _target = null
    set_physics_process(false)
```

**与 LinearMovementComponent 互斥**：同一投射物场景只挂其中一个。

**使用场景**：
- `pea_bullet.tscn` — 替换 LinearMovement 为 TrackingMovement
- `ice_bullet.tscn` — 替换 LinearMovement 为 TrackingMovement

### 3. Projectile 基座改动

**改动文件**：`scripts/entities/projectiles/projectile.gd`

**新增属性**：
```gdscript
var target: Node2D = null  # 追踪目标（可选）
```

**改动 `setup()` 签名**：
```gdscript
func setup(p_data: ProjectileData, dmg: float, from: Vector2, dir: Vector2, p_target: Node2D = null) -> void:
    target = p_target
    # ... 其余不变
```

**改动 `reset_for_pool()`**：
```gdscript
func reset_for_pool() -> void:
    target = null  # 清除追踪引用
    # ... 其余不变
```

### 4. SceneFactory 改动

**改动文件**：`scripts/core/scene_factory.gd`

**改动 `create_projectile()` 签名**：
```gdscript
func create_projectile(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2, target: Node2D = null) -> Node2D:
    # ... 池化获取 ...
    proj.setup(p_data, damage, from, direction, target)
    return proj
```

可选参数，不影响现有调用方。

### 5. RangedAttackComponent 传递 target

**改动文件**：`scripts/components/ranged_attack_component.gd`

`_execute_attack()` 中，塔的投射物需要传 target：
```gdscript
func _execute_attack(target: Node2D) -> void:
    # ... fire_pos 计算 ...
    var direction: Vector2
    if use_lead_shot:
        # 预判瞄准
        var distance: float = fire_pos.distance_to(target.global_position)
        var flight_time: float = distance / projectile_data.speed
        var target_velocity: Vector2 = target.velocity if "velocity" in target else Vector2.ZERO
        var predicted_pos: Vector2 = target.global_position + target_velocity * flight_time
        direction = fire_pos.direction_to(predicted_pos)
    else:
        direction = fire_pos.direction_to(target.global_position)
    var damage: float = get_final_damage()
    # 追踪型投射物传 target，预判型不传（直线飞行）
    var proj_target: Node2D = null if use_lead_shot else target
    var proj: Node2D = SceneFactory.create_projectile(projectile_data, damage, fire_pos, direction, proj_target)
    # ... 后续不变
```

**逻辑**：
- `use_lead_shot = true`（武器）：计算预判方向，不传 target（投射物直线飞行）
- `use_lead_shot = false`（塔）：普通方向，传 target（投射物自行追踪）

### 6. Shuriken 弹射追踪

**改动文件**：`scripts/components/bounce_on_hit_component.gd`

**新增属性**：
```gdscript
@export var bounce_tracking: bool = false
@export var bounce_turn_speed: float = 10.0  # 短距离追踪更灵敏
var _is_bouncing: bool = false
var _projectile_ref: Node2D = null
```

**改动 `on_hit()`**：弹射时设置追踪
```gdscript
func on_hit(target: Node2D, projectile: Node2D) -> void:
    # ... 原有逻辑 ...
    var bounce_target: Node2D = _find_bounce_target(target.global_position)
    if bounce_target and projectile:
        projectile.direction = projectile.global_position.direction_to(bounce_target.global_position)
        # 启用弹射追踪
        if bounce_tracking:
            projectile.target = bounce_target
            _projectile_ref = projectile
            _is_bouncing = true
            set_physics_process(true)
        # ... hitbox 暂停/恢复不变
```

**新增 `_physics_process()`**：弹射飞行中持续修正方向
```gdscript
func _physics_process(delta: float) -> void:
    if not _is_bouncing or not bounce_tracking:
        set_physics_process(false)
        return
    if not _projectile_ref or not is_instance_valid(_projectile_ref):
        _stop_tracking()
        return
    var target: Node2D = _projectile_ref.target
    if not target or not is_instance_valid(target):
        _stop_tracking()
        return
    var desired: Vector2 = _projectile_ref.global_position.direction_to(target.global_position)
    _projectile_ref.direction = _projectile_ref.direction.slerp(desired, bounce_turn_speed * delta).normalized()

func _stop_tracking() -> void:
    _is_bouncing = false
    _projectile_ref = null
    set_physics_process(false)
```

**改动 `reset()`**：
```gdscript
func reset() -> void:
    _bounce_count = 0
    _hit_enemies.clear()
    _is_bouncing = false
    _projectile_ref = null
    set_physics_process(false)
```

### 7. 场景改动

**`scenes/entities/projectiles/pea_bullet.tscn`**：
- 移除 `LinearMovementComponent` 子节点
- 添加 `TrackingMovementComponent` 子节点（turn_speed = 8.0）

**`scenes/entities/projectiles/ice_bullet.tscn`**：
- 移除 `LinearMovementComponent` 子节点
- 添加 `TrackingMovementComponent` 子节点（turn_speed = 8.0）

**`scenes/entities/projectiles/shuriken.tscn`**：
- `BounceOnHitComponent` 设 `bounce_tracking = true`

**其他场景不变**。

## 改动清单

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `scripts/components/tracking_movement_component.gd` | **新增** | 追踪移动组件 |
| `scripts/components/ranged_attack_component.gd` | 修改 | 加 `use_lead_shot` + 预判计算 + 传 target |
| `scripts/entities/projectiles/projectile.gd` | 修改 | 加 `target` 属性，`setup()` 加参数 |
| `scripts/core/scene_factory.gd` | 修改 | `create_projectile()` 加 `target` 参数 |
| `scripts/components/bounce_on_hit_component.gd` | 修改 | 弹射后追踪逻辑 |
| `scenes/entities/projectiles/pea_bullet.tscn` | 修改 | LinearMovement → TrackingMovement |
| `scenes/entities/projectiles/ice_bullet.tscn` | 修改 | LinearMovement → TrackingMovement |
| `scenes/entities/projectiles/shuriken.tscn` | 修改 | BounceOnHit 设 bounce_tracking=true |

## 对象池兼容

- `TrackingMovementComponent.reset()` — 清除 `_target` 引用 + `_elapsed`，关闭 `_physics_process`
- `BounceOnHitComponent.reset()` — 清除 `_is_bouncing` + `_projectile_ref`，关闭 `_physics_process`
- `Projectile.reset_for_pool()` — 清除 `target` 引用

## 不需要改动的部分

- `LinearMovementComponent` — 不动
- `ProjectileData` — 不新增字段（speed/lifetime 够用，turn_speed 在组件 @export）
- 武器/塔的 `.tres` 资源文件 — 不动
- `MeleeAttackComponent` — 不动
- `arrow.tscn` — 不动（继续用 LinearMovement + 预判）
- `TargetFinderComponent` — 不动
