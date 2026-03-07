# Player / Weapon / Projectile 架构重构设计

**日期**：2026-03-07
**状态**：已确认，待实现

## 背景与目标

现有架构存在以下耦合问题：
- `bullet.gd` / `boomerang.gd` 直接调用 `body.take_damage()` + `apply_knockback()`，耦合敌人接口
- 激光在 `weapon_system.gd` 里直接物理查询造伤，无投射物抽象
- `boomerang.gd` 硬编码 `GameConfig.weapons["boomerang"]`
- 视觉特效（枪口闪、激光闪）内嵌在武器逻辑里
- `WeaponSystem` 只支持单武器，无法扩展多武器

重构目标：
1. **Player**：只负责移动、收集、承受伤害、提供全局属性面板
2. **WeaponManager + Weapon 子类**：统一管理多武器，不可见，负责找目标、算冷却、发射投射物
3. **Projectile 子类**：可见执行者，负责飞行表现和通过 Hitbox 造成伤害
4. **Hitbox / Hurtbox**：统一的碰撞伤害体系

---

## 一、碰撞层设计

| 层号 | 值 | 用途 |
|------|----|------|
| Layer 1 | 1 | Player body（物理移动，不动） |
| Layer 2 | 2 | Enemy body（物理移动，不动） |
| Layer 3 | 4 | **player_hitbox**（玩家投射物 Hitbox，复用原 bullet 层） |
| Layer 4 | 8 | Tower 范围检测（不动） |
| Layer 5 | 16 | Map boundary（不动） |
| Layer 6 | 32 | **enemy_hitbox**（敌人接触 Hitbox，新增） |
| Layer 7 | 64 | **player_hurtbox**（新增） |
| Layer 8 | 128 | **enemy_hurtbox**（新增） |

**mask 配置：**

| 节点 | layer | mask |
|------|-------|------|
| 玩家投射物 Hitbox | 3 (4) | 8 (128) |
| 敌人接触 Hitbox | 6 (32) | 7 (64) |
| Player Hurtbox | 7 (64) | 6 (32) |
| Enemy Hurtbox | 8 (128) | 3 (4) |

---

## 二、Hitbox / Hurtbox 组件

### hitbox.gd
```gdscript
class_name Hitbox
extends Area2D

var damage: float = 0.0
var knockback_force: float = 0.0
# 碰撞层在 .tscn 中配置，脚本不硬编码
```

### hurtbox.gd
```gdscript
class_name Hurtbox
extends Area2D

signal hit_taken(damage: float, knockback_dir: Vector2)

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
    if area is Hitbox:
        var dir: Vector2 = area.global_position.direction_to(global_position)
        hit_taken.emit(area.damage, dir * area.knockback_force)
```

宿主在 `_ready()` 中连接信号：
```gdscript
$Hurtbox.hit_taken.connect(_on_hurtbox_hit)

func _on_hurtbox_hit(damage: float, knockback: Vector2) -> void:
    health.take_damage(damage)
    _knockback.apply_impulse(knockback)  # 仅 enemy
```

无敌帧由 Player 在 `_on_hurtbox_hit()` 中控制。

---

## 三、WeaponManager + Weapon 子类

### weapon.gd（基类）
```gdscript
class_name Weapon
extends Node

var weapon_data: WeaponData = null
var _cooldown: float = 0.0

func initialize(data: WeaponData) -> void:
    weapon_data = data

func tick(delta: float, target: Node2D) -> void:
    _cooldown -= delta
    if _cooldown <= 0.0 and target:
        fire(target)
        _cooldown = weapon_data.fire_rate / GameData.player_stats["attack_speed_mult"]

func fire(_target: Node2D) -> void:
    pass  # 子类实现
```

fire() 内部计算伤害：
```gdscript
var final_damage: float = weapon_data.damage * GameData.player_stats["damage_mult"]
```
每次 fire() 动态读取，实时反映全局加成。

### weapon_manager.gd
```gdscript
class_name WeaponManager
extends Node

var _weapons: Array[Weapon] = []

func initialize(weapon_ids: Array[String]) -> void:
    for id in weapon_ids:
        var data: WeaponData = GameConfig.weapons[id]
        var weapon: Weapon = _create_weapon(data.projectile_type)
        weapon.initialize(data)
        add_child(weapon)
        _weapons.append(weapon)

func tick(delta: float) -> void:
    var target: Node2D = _find_closest_enemy()
    for weapon in _weapons:
        weapon.tick(delta, target)

func _find_closest_enemy() -> Node2D:
    # 统一查找最近敌人，每帧一次，分发给所有武器
    ...

func _create_weapon(projectile_type: String) -> Weapon:
    match projectile_type:
        "bullet":    return BulletWeapon.new()
        "boomerang": return BoomerangWeapon.new()
        "laser":     return LaserWeapon.new()
    return Weapon.new()
```

Player 调用：
```gdscript
# _ready()
$WeaponManager.initialize([GameData.selected_weapon])  # 未来扩展为 Array

# _process()
$WeaponManager.tick(delta)
```

子类文件：
- `bullet_weapon.gd`：fire() → SceneFactory.create_bullet_projectile()，设置 hitbox.damage、方向
- `boomerang_weapon.gd`：fire() → SceneFactory.create_boomerang_projectile()
- `laser_weapon.gd`：fire() → SceneFactory.create_laser_projectile()，按 beam_range 拉伸 Hitbox

---

## 四、Projectile 子类

### projectile.gd（基类）
```gdscript
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

| 子类 | 行为 |
|------|------|
| BulletProjectile | 直线飞行，碰到 enemy_hurtbox → queue_free() |
| BoomerangProjectile | 去程/回程状态机，回程追踪 owner_pos（Vector2，非节点引用） |
| LaserProjectile | setup() 时拉伸 Hitbox 覆盖光束路径，存活 beam_duration 后销毁，无 _physics_process |

---

## 五、Player / Enemy 变更

### Player
| 现有 | 重构后 |
|------|--------|
| `WeaponSystem` 子节点 | `WeaponManager` 子节点 |
| `_weapon.initialize(...)` | `_weapon_manager.initialize([id])` |
| `_weapon.process(delta)` | `_weapon_manager.tick(delta)` |
| `check_enemy_collision()` | **删除**，由 Hurtbox 接管 |
| `take_damage()` 直接调用 | 改为 `_on_hurtbox_hit()` |
| `invincible_timer` 在碰撞检测里判断 | 移到 `_on_hurtbox_hit()` |

新增子节点：`Hurtbox (Area2D)` — layer=7(64), mask=6(32)

### Enemy
| 现有 | 重构后 |
|------|--------|
| `take_damage()` 公开方法 | 保留（塔攻击暂未迁移） |
| `apply_knockback()` 公开方法 | 保留，Hurtbox 信号传入 |
| 无 Hitbox | 新增 Hitbox — layer=6(32), mask=7(64)，damage=EnemyData.damage |
| 无 Hurtbox | 新增 Hurtbox — layer=8(128), mask=3(4) |

> take_damage() 本次不删除，塔的攻击尚未迁移到 Hitbox 体系。Hitbox/Hurtbox 增量引入。

**场景树（gdai-mcp 操作）：**
```
Player
  ├─ HealthComponent
  ├─ Hurtbox (Area2D)   ← 新增
  ├─ WeaponManager      ← 替换 WeaponSystem
  ├─ SpriteAnimator
  └─ Camera

Enemy
  ├─ HealthComponent
  ├─ Hitbox (Area2D)    ← 新增
  ├─ Hurtbox (Area2D)   ← 新增
  ├─ KnockbackHandler
  ├─ SlowHandler
  └─ SpriteAnimator
```

---

## 六、文件结构变更

**新增：**
```
scripts/components/hitbox.gd
scripts/components/hurtbox.gd
scripts/entities/weapons/weapon.gd
scripts/entities/weapons/weapon_manager.gd
scripts/entities/weapons/bullet_weapon.gd
scripts/entities/weapons/boomerang_weapon.gd
scripts/entities/weapons/laser_weapon.gd
scripts/entities/projectiles/projectile.gd
scripts/entities/projectiles/bullet_projectile.gd
scripts/entities/projectiles/boomerang_projectile.gd
scripts/entities/projectiles/laser_projectile.gd
scenes/entities/projectiles/bullet_projectile.tscn
scenes/entities/projectiles/boomerang_projectile.tscn
scenes/entities/projectiles/laser_projectile.tscn
```

**删除：**
```
scripts/components/weapon_system.gd
scripts/entities/bullet.gd
scripts/entities/boomerang.gd
scripts/entities/laser_beam.gd
scenes/entities/bullet.tscn
scenes/entities/boomerang.tscn
scenes/entities/laser_beam.tscn
```

**修改：**
```
scripts/entities/player.gd
scripts/entities/enemy.gd
scripts/core/scene_factory.gd
scenes/entities/player.tscn          # gdai-mcp 操作
scenes/entities/enemies/*.tscn       # gdai-mcp 操作
```

**新增测试：**
```
tests/unit/test_hitbox_hurtbox.gd
tests/unit/test_weapon_manager.gd
tests/unit/test_bullet_projectile.gd
```
