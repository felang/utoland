# 组件化战斗系统重构设计

## 背景

当前武器/塔/投射物系统采用继承+部分组合的混合架构，存在以下问题：

1. **方法重复** — `ShurikenWeapon._on_attack_fired()` 与 `Weapon._on_attack_fired()` 90% 重复；`TowerShooter._on_attack_fired()` 与 Weapon 几乎一致
2. **继承层级不合理** — `TowerGenerator` 继承 Tower 的攻击动画/buff 系统但完全不用
3. **投射物行为靠子类覆写** — 弹射/旋转/拖尾硬编码在 `ShurikenProjectile` 子类，新行为组合需要新子类
4. **TowerData 万能 Resource** — 射击塔和生成塔共用一个 Resource 类，互不使用的字段
5. **工厂硬编码** — `WeaponManager._create_weapon()` 用 match 语句决定子类
6. **近战逻辑内嵌** — `Weapon._on_melee_triggered()` 手动创建临时 Area2D + Tween，无法复用
7. **索敌不统一** — 武器遍历全局 enemies 组（低效），塔用 Area2D（合理），两套实现

## 设计目标

- **组合优于继承**：行为通过子节点组件组合，消除 ShurikenWeapon/TowerShooter/TowerGenerator/ShurikenProjectile 等子类
- **组件与 Resource 一一对应**：每个组件读自己的配置 Resource
- **武器和塔保持分离，共享组件池**：不做统一基类，但使用相同的组件
- **Pivot + Offset 武器管理**：分离环绕运动和瞄准/开火方向
- **可插拔索敌策略**：统一用 Area2D 范围检测，支持多种策略（最近/最低血量等）
- **投射物命中效果组件化**：减速/击退/弹射等作为子节点组件，可自由叠加
- **移除 AttackerComponent**：冷却和乘数内聚到各攻击组件

## 组件清单

### 索敌组件

#### TargetFinderComponent (Node)
- **职责**：在范围内查找目标，提供可插拔策略
- **子节点**：DetectArea (Area2D + CircleShape2D)
- **配置**：
  - `detect_range: float` — 检测半径
  - `strategy: TargetStrategy` — 枚举：NEAREST / LOWEST_HP / HIGHEST_HP / RANDOM
- **API**：
  - `get_target() -> Node2D` — 根据策略返回目标（内部缓存 `_current_target`，仅目标身份变化时发信号）
  - `set_range(range: float)` — 更新 DetectArea 半径
- **共用**：武器和塔都挂载此组件，统一用 Area2D 物理检测
- **信号**：`target_changed(new_target: Node2D)` — 仅在目标身份变化时发出（非每帧）

### 攻击组件（互斥，挂其一）

#### RangedAttackComponent (Node)
- **职责**：冷却管理 + 索敌 + 创建投射物
- **依赖**：兄弟节点 TargetFinderComponent（@onready 引用或注入）
- **配置 Resource**：`AttackConfigData`
- **属性**：
  - `damage_multiplier: float = 1.0` — 被动/buff 伤害乘数
  - `speed_multiplier: float = 1.0` — 被动/buff 攻速乘数
  - `projectile_data: ProjectileData` — 投射物配置
  - `on_projectile_created: Callable` — 可选回调，投射物创建后、添加到场景树前调用（塔覆写命中效果参数用）
- **API**：
  - `tick(delta: float)` — 每帧调用，管理冷却+触发攻击
  - `get_final_damage() -> float` — base_damage * damage_multiplier
  - `get_final_cooldown() -> float` — base_cooldown / speed_multiplier
  - `set_level(level: int)` — 从 AttackConfigData 的 per_level 数组更新参数
- **信号**：
  - `attack_executed(target: Node2D, projectile: Node2D)` — 攻击执行后
- **重要约定**：攻击组件不使用 `_process()`/`_physics_process()` 自驱动，由宿主（WeaponManager/Tower）显式调用 `tick(delta)` 驱动，避免双重 tick
- **投射物添加到场景树**：通过 `projectile_spawned` 信号通知宿主添加，不直接操作场景树
- **信号**：
  - `attack_executed(target: Node2D, projectile: Node2D)` — 攻击执行后
  - `projectile_spawned(proj: Node2D)` — 投射物已创建，需添加到场景树
- **音效**：`sfx_id: String = "shoot"` — 可配置的攻击音效 ID
- **内部流程**：
  1. `tick()` 递减冷却
  2. 冷却到期 → `target_finder.get_target()`
  3. 有目标 → `SceneFactory.create_projectile()` → emit `projectile_spawned`
  4. 宿主收到信号 → 添加到场景树
  5. 发出 `attack_executed` 信号
  6. `AudioManager.play(sfx_id)`

#### MeleeAttackComponent (Node)
- **职责**：冷却管理 + 索敌 + hitbox 挥砍
- **依赖**：兄弟节点 TargetFinderComponent
- **配置 Resource**：`AttackConfigData` + `MeleeConfig`
- **属性**：
  - `damage_multiplier: float = 1.0`
  - `speed_multiplier: float = 1.0`
- **API**：
  - `tick(delta: float)` — 冷却+触发
  - `get_final_damage() -> float`
  - `set_level(level: int)`
- **信号**：
  - `attack_executed(target: Node2D)`
- **内部流程**：
  1. 冷却到期 → 有目标
  2. 创建临时 Area2D (hit_radius) 在目标方向
  3. Tween 前刺动画（通过 Pivot 旋转）
  4. 检测 area_entered → 对命中目标施加伤害+击退
  5. 动画结束销毁临时 hitbox

#### GeneratorComponent (Node)
- **职责**：定时生成资源（金币）
- **配置 Resource**：`GeneratorConfigData`
- **属性**：
  - `_timer: Timer` — 内部定时器，`_ready()` 中创建并添加为子节点
- **API**：
  - `set_level(level: int)` — 更新 amount/interval，若 timer 已在树中则重启
- **信号**：
  - `generated(amount: int, position: Vector2)` — 生成时发出，接入 EventBus.coins_generated
- **Timer 生命周期**：`_ready()` 创建 Timer 子节点（autostart=false）。`set_level()` 设置 wait_time 并调用 `start()`。宿主（Tower）在 `_ready()` 中调用 `set_level()` 时，若组件尚未进入树则延迟到 `_ready()` 后启动

### 投射物命中效果组件（可叠加，挂载在投射物场景中）

**伤害处理**：基础伤害仍由 Hitbox/Hurtbox 碰撞体系自动处理（Hitbox.damage → Hurtbox.hit_taken 信号 → Enemy 扣血）。命中效果组件只处理额外效果（减速/击退/弹射等），不负责伤害本身。

所有命中效果组件遵循统一接口（duck typing，无需继承基类）：

```gdscript
# 方法签名约定：
func on_hit(target: Node2D, projectile: Projectile) -> void  # projectile 提供 damage/direction 等上下文
func reset() -> void  # 对象池重置
```

投射物基座在 Hitbox 碰撞时：先由 Hitbox/Hurtbox 体系处理伤害，然后遍历所有实现了 `on_hit` 的子节点组件处理额外效果。

#### SlowOnHitComponent (Node)
- **配置**：`slow_ratio: float`, `slow_duration: float`（@export，或从 Resource）
- **on_hit**：`target.slow_handler.apply_timed_slow(ratio, duration, source_id)`

#### KnockbackOnHitComponent (Node)
- **配置**：`knockback_force: float`
- **on_hit**：`target.knockback_handler.apply_knockback(direction * force)`

#### PierceComponent (Node)
- **配置**：`max_pierce_count: int`
- **状态**：`_hit_count: int`
- **on_hit**：`_hit_count += 1`，当 `_hit_count > max_pierce_count` 时通知投射物销毁
- **信号**：`pierce_exhausted` — 穿透用尽

#### BounceOnHitComponent (Node)
- **配置**：`bounce_range: float`, `max_bounces: int`
- **状态**：`_bounce_count: int`, `_hit_enemies: Array[Node2D]`
- **on_hit**：
  1. `_bounce_count += 1`
  2. 若 `_bounce_count >= max_bounces` → 通知销毁
  3. 否则 `_find_bounce_target()` → 改变投射物方向
- **索敌方式**：使用 `get_tree().get_nodes_in_group(Enums.Group.ENEMIES)` 扫描组内目标（投射物无 TargetFinderComponent，且弹射目标查找是一次性操作，不需要 Area2D 持续检测）
- **信号**：`bounces_exhausted` — 弹射用尽

### 投射物飞行/视觉组件

#### LinearMovementComponent (Node)
- **职责**：直线移动 + 生命周期管理
- **配置**：`speed: float`, `lifetime: float`（从 ProjectileData 注入）
- **_physics_process**：`owner.position += direction * speed * delta`
- **生命周期**：`_elapsed >= lifetime` → 通知投射物销毁
- **信号**：`lifetime_expired`

#### RotationComponent (Node)
- **职责**：持续旋转精灵
- **配置**：`rotation_speed: float`
- **_process**：`sprite.rotation += rotation_speed * delta`

#### TrailComponent (Node)
- **职责**：Line2D 拖尾效果
- **配置**：`trail_color: Color`, `trail_width: float`, `max_points: int`
- **_process**：维护位置点数组，更新 Line2D
- **注意**：Line2D 不使用 `top_level = true`，跟随投射物移动。`reset()` 时清空 `points` 数组

## Resource 结构

### AttackConfigData (Resource)
```gdscript
class_name AttackConfigData extends Resource

@export var damage_per_level: PackedFloat32Array      # [Lv1, Lv2, Lv3]
@export var fire_rate_per_level: PackedFloat32Array    # 冷却时间(秒)
@export var attack_range_per_level: PackedFloat32Array # 检测范围
```
武器和塔共用此 Resource。`RangedAttackComponent`/`MeleeAttackComponent` 在 `set_level()` 时从对应 index 读取参数，**同时自动更新兄弟节点 TargetFinderComponent 的检测范围**（`target_finder.set_range(attack_range_per_level[idx])`）。这确保攻击范围和索敌范围始终同步，调用方无需手动协调。

### GeneratorConfigData (Resource)
```gdscript
class_name GeneratorConfigData extends Resource

@export var generate_amount_per_level: PackedFloat32Array  # [5, 8, 12]
@export var generate_interval_per_level: PackedFloat32Array # [10, 8, 6]
```

### WeaponData (Resource, 重构)
```gdscript
class_name WeaponData extends Resource

# 基础信息
@export var id: String
@export var display_name: String
@export var description: String
@export var icon_path: String
@export var sell_price_per_level: PackedInt32Array

# 攻击配置
@export var attack_config: AttackConfigData
@export var projectile_data: ProjectileData  # 远程武器用
@export var melee_config: MeleeConfig        # 近战武器用

# Pivot 配置
@export var pivot_offset: float = 15.0       # 距玩家中心的偏移距离

# 视觉配置
@export var hide_sprite_on_fire: bool = false # 开火时隐藏精灵（手里剑等投掷武器）
@export var sprite_restore_ratio: float = 0.9 # 冷却恢复到此比例时显示精灵
```
不再需要 `attack_mode` 枚举，由挂载的攻击组件决定。
`hide_sprite_on_fire` 替代原 ShurikenWeapon 子类的精灵隐藏行为——WeaponManager 监听 `attack_executed` 信号，若此标志为 true 则隐藏精灵并在冷却恢复后显示。

### TowerData (Resource, 重构)
```gdscript
class_name TowerData extends Resource

# 基础信息
@export var id: String
@export var display_name: String
@export var description: String
@export var icon_path: String
@export var sell_price_per_level: PackedInt32Array
@export var hp_per_level: PackedFloat32Array

# 行为配置（按塔类型二选一）
@export var attack_config: AttackConfigData       # 射击塔
@export var projectile_data: ProjectileData       # 射击塔的投射物
@export var generator_config: GeneratorConfigData  # 生成塔
```

### ProjectileData (Resource, 精简)
```gdscript
class_name ProjectileData extends Resource

@export var speed: float = 300.0
@export var lifetime: float = 5.0
@export var sprite_path: String
@export var projectile_scene: PackedScene
```
移除 `knockback_force`、`slow_ratio`、`slow_duration`、`base_pierce_count`、`trail_enabled` 等字段。这些行为由投射物场景中的子节点组件各自配置。

### MeleeConfig (Resource, 保持不变)
```gdscript
class_name MeleeConfig extends Resource

@export var thrust_distance: float = 60.0
@export var hit_angle: float = 90.0
@export var hit_radius: float = 20.0
@export var knockback_force: float = 50.0
```
MeleeAttackComponent 创建临时 hitbox 时使用 `collision_layer = CollisionLayers.HITBOX`, `collision_mask = CollisionLayers.HURTBOX`（与投射物一致）。

## 武器结构 (Pivot + Offset)

### 场景树
```
Player
└── WeaponManager (Node2D)
    └── WeaponPivot_0 (Node2D)              # 枢轴：旋转朝向目标
        ├── TargetFinderComponent            # 索敌
        │   └── DetectArea (Area2D)
        ├── RangedAttackComponent            # 或 MeleeAttackComponent
        └── WeaponOffset (Node2D)            # 偏移：固定距离
            ├── Sprite2D                     # 武器视觉
            └── FirePoint (Marker2D)         # 投射物生成点
```

### WeaponPivot 行为
- 无目标时：匀速环绕（`_orbit_angle += orbit_speed * delta`）
- 有目标时：旋转朝向目标（`look_at(target.global_position)`）
- 多把武器时：Pivot 均匀分布在环绕圆上

### WeaponOffset 行为
- 纯静态偏移，`position = Vector2(pivot_offset, 0)`
- 不同武器不同 offset（弓远、剑近）

### WeaponManager 职责收窄
重构后 WeaponManager 只负责：
1. 管理 WeaponPivot 子树的创建/销毁
2. 环绕动画驱动（均分角度）
3. add_weapon() / remove_weapon() / refresh_weapons()
4. 注入被动 multiplier 到攻击组件
5. 武器拖拽回调（商店阶段）

不再负责：
- ~~target_finder 回调注入~~（组件自带）
- ~~_find_nearest_enemy_from()~~（组件自带 DetectArea）
- ~~精灵位置手动计算~~（Pivot + Offset 自动处理）
- ~~精灵旋转朝向手动计算~~（Pivot rotation 自动处理）

### 创建流程
```
WeaponManager.add_weapon(weapon_id, level):
  1. weapon_data = GameConfig.weapons[weapon_id]
  2. 创建 WeaponPivot (Node2D)
  3. 创建 TargetFinderComponent，设置 range
  4. 根据 weapon_data 有 projectile_data → 创建 RangedAttackComponent
     根据 weapon_data 有 melee_config → 创建 MeleeAttackComponent
  5. 注入 AttackConfigData，调用 set_level(level)
  6. 创建 WeaponOffset + Sprite2D + FirePoint
  7. 注入被动 multiplier
  8. 添加到 Pivot 子树
```
不再需要 match 语句区分子类。

## 塔结构

### 射击塔场景 (tower_pea_shooter.tscn)
```
Tower (StaticBody2D, script: tower.gd)
├── Visual (AnimatedSprite2D)
├── CollisionShape2D
├── HealthComponent
├── TargetFinderComponent
│   └── DetectArea (Area2D + CircleShape2D)
└── RangedAttackComponent
```

### 冰花塔场景 (tower_ice_flower.tscn)
```
Tower (StaticBody2D, script: tower.gd)
├── Visual (AnimatedSprite2D)
├── CollisionShape2D
├── HealthComponent
├── TargetFinderComponent
│   └── DetectArea (Area2D + CircleShape2D)
└── RangedAttackComponent
```
与 pea_shooter 结构完全一致，差异在于 TowerData 引用不同的 ProjectileData（ice_bullet 场景带 SlowOnHitComponent）。

### 向日葵场景 (tower_sunflower.tscn)
```
Tower (StaticBody2D, script: tower.gd)
├── Visual (AnimatedSprite2D)
├── CollisionShape2D
├── HealthComponent
└── GeneratorComponent
```
无 TargetFinder，无攻击组件。

### Tower 基座 (tower.gd) 职责
- 通用属性：`data: TowerData`, `current_level`, `tower_type`
- HealthComponent 管理
- Buff 系统：`apply_buff()` / `remove_buff()` → 查找 RangedAttackComponent/MeleeAttackComponent 并设置其 `damage_multiplier`/`speed_multiplier`
- 塔 multiplier：`_ready()` 中从 `PlayerState.player_stats[Enums.Stat.TOWER_MULT]` 读取并注入攻击组件的 `damage_multiplier`
- 等级视觉（glow）
- 死亡处理：`_on_died()` emit `EventBus.tower_destroyed(tower_type, global_position)` → `queue_free()`
- `_ready()` 中通过 `get_node_or_null()` 检测挂载了哪些组件，自动初始化
- `_process()` 中对 RangedAttackComponent/MeleeAttackComponent 调用 `tick(delta)`

### Tower._ready() 自动初始化
```gdscript
func _ready() -> void:
    # 基础初始化
    health = $HealthComponent
    health.initialize(data.hp_per_level[current_level - 1])
    health.died.connect(_on_died)

    # 自动检测并初始化攻击组件
    _attack_component = get_node_or_null("RangedAttackComponent")
    if _attack_component and data.attack_config:
        _attack_component.projectile_data = data.projectile_data
        _attack_component.set_level(current_level)  # 内部同步 TargetFinder 范围
        _attack_component.attack_executed.connect(_on_attack_executed)
        _attack_component.projectile_spawned.connect(_on_projectile_spawned)
        # 注入塔 multiplier（作为 buff source，与外部 buff 统一管理）
        var tower_mult: float = PlayerState.player_stats.get(Enums.Stat.TOWER_MULT, 1.0)
        _buff_sources["_base_tower_mult"] = {dmg = tower_mult, spd = 1.0}
        _recalc_buffs()

    # 自动检测并初始化生成组件
    var generator = get_node_or_null("GeneratorComponent")
    if generator and data.generator_config:
        generator.set_level(current_level)
        generator.generated.connect(_on_generated)

    _setup_level_glow()
    add_to_group(Enums.Group.TOWERS)

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
    # 传递到攻击组件
    if _attack_component:
        _attack_component.damage_multiplier = damage_mult
        _attack_component.speed_multiplier = speed_mult

func _on_projectile_spawned(proj: Node2D) -> void:
    get_parent().add_child(proj)

func _process(delta: float) -> void:
    if _attack_component:
        _attack_component.tick(delta)
```
不再需要 TowerShooter / TowerGenerator 子类。

## 投射物结构

### 投射物基座 (projectile.gd)

精灵由 `setup()` 动态创建（从 `data.sprite_path` 加载），池化重置时清理。不在 .tscn 场景中预置 Sprite2D 节点。

```gdscript
class_name Projectile extends Node2D

var data: ProjectileData
var damage: float
var direction: Vector2
var _is_pooled: bool = false
var _should_destroy: bool = false  # 组件可设置此标志请求销毁

func setup(p_data: ProjectileData, dmg: float, from: Vector2, dir: Vector2) -> void:
    data = p_data
    damage = dmg
    direction = dir
    global_position = from
    _should_destroy = false
    # Hitbox 伤害值同步
    $Hitbox.damage = dmg
    # 设置精灵（动态创建）
    _setup_sprite()
    # 通知子组件初始化
    for child in get_children():
        if child.has_method("on_projectile_setup"):
            child.on_projectile_setup(self)

func on_hit(target: Node2D) -> void:
    # 伤害由 Hitbox/Hurtbox 体系自动处理（Hitbox.damage → Hurtbox.hit_taken）
    # 这里只处理额外效果
    for child in get_children():
        if child.has_method("on_hit"):
            child.on_hit(target, self)  # 传入 Projectile 自身，组件可访问 damage/direction
    # 生成命中特效
    EffectsManager.spawn_hit_sparks(global_position)
    # 默认命中即销毁，除非有 PierceComponent 或 BounceOnHitComponent 阻止
    if _should_destroy:
        request_destroy()
    elif not _has_lifecycle_component():
        request_destroy()

func _has_lifecycle_component() -> bool:
    # 检查是否有管理生命周期的组件（通过 duck typing 而非类型检查）
    for child in get_children():
        if child.get("manages_lifecycle"):
            return true
    return false
    # PierceComponent 和 BounceOnHitComponent 需声明 var manages_lifecycle: bool = true

func reset_for_pool() -> void:
    _should_destroy = false
    for child in get_children():
        if child.has_method("reset"):
            child.reset()
    _cleanup_sprite()

func request_destroy() -> void:
    SceneFactory.release_projectile.call_deferred(self)
```

### arrow.tscn
```
Projectile (Node2D, script: projectile.gd)
├── Hitbox (Area2D, layer=4, mask=128)
│   └── CollisionShape2D (CircleShape2D, r=2)
├── LinearMovementComponent
├── TrailComponent
└── KnockbackOnHitComponent (force=40)
```

### shuriken.tscn
```
Projectile (Node2D, script: projectile.gd)
├── Hitbox (Area2D, layer=4, mask=128)
│   └── CollisionShape2D (CircleShape2D, r=3)
├── LinearMovementComponent
├── TrailComponent
├── RotationComponent
└── BounceOnHitComponent (range=150, max_bounces=1)
```

### pea_bullet.tscn
```
Projectile (Node2D, script: projectile.gd)
├── Hitbox (Area2D, layer=4, mask=128)
│   └── CollisionShape2D (CircleShape2D, r=2)
└── LinearMovementComponent
```

### ice_bullet.tscn
```
Projectile (Node2D, script: projectile.gd)
├── Hitbox (Area2D, layer=4, mask=128)
│   └── CollisionShape2D (CircleShape2D, r=2)
├── LinearMovementComponent
└── SlowOnHitComponent (ratio=0.3, duration=1.5)
```
注意：ice_flower 的 per_level 减速由塔在创建投射物前覆写 SlowOnHitComponent 的参数，或在 ProjectileData 里保留 slow 字段由塔注入。

### 对象池兼容
- 对象池按 .tscn 场景分 key，与现有机制一致
- `reset_for_pool()` 遍历子组件调用 `reset()`，每个组件只重置自己的状态
- `setup()` 遍历子组件调用 `on_projectile_setup()`，每个组件读取 Projectile 上的数据初始化
- release 仍用 `call_deferred` 避免物理回调冲突

## 移除清单

| 移除 | 替代 |
|------|------|
| `AttackerComponent` (attacker_component.gd) | `RangedAttackComponent` + `MeleeAttackComponent` |
| `TowerShooter` (tower_shooter.gd) | tower.gd + 组件组合 |
| `TowerGenerator` (tower_generator.gd) | tower.gd + GeneratorComponent |
| `ShurikenWeapon` (shuriken_weapon.gd) | 通用 Weapon 流程 + 相同组件 |
| `ShurikenProjectile` (shuriken_projectile.gd) | shuriken.tscn 预配 BounceOnHit + Rotation 组件 |
| `ProjectileBase` (projectile_base.gd) | `Projectile` (精简基座) |
| `WeaponManager.match` 工厂 | 统一创建流程，无子类 |
| `ProjectileData.slow_ratio/knockback_force/pierce` 等 | 各命中效果组件 @export |
| `WeaponData.attack_mode` 枚举 | 由挂载的攻击组件类型决定 |
| `TowerData` 中互斥字段 | 拆为 AttackConfigData / GeneratorConfigData |

## 关键数据流

### 武器开火（远程）
```
WeaponManager.tick(delta)
  → 每个 WeaponPivot:
    → 有目标? Pivot.look_at(target) : Pivot 匀速旋转
    → RangedAttackComponent.tick(delta)
      → 冷却递减
      → 冷却到期?
        → TargetFinderComponent.get_target()
        → 有目标?
          → damage = get_final_damage()
          → proj = SceneFactory.create_projectile(data, damage, FirePoint.global_position, direction)
          → emit projectile_spawned(proj)
          → WeaponManager 收到信号 → 添加到 _projectile_container（WeaponManager 初始化时缓存的场景节点引用）
          → 若 weapon_data.hide_sprite_on_fire → 隐藏精灵，定时恢复
          → emit attack_executed
          → AudioManager.play(sfx_id)
```

### 武器攻击（近战）
```
WeaponManager.tick(delta)
  → WeaponPivot:
    → MeleeAttackComponent.tick(delta)
      → 冷却到期 + 有目标
        → 创建临时 Area2D (hit_radius)
        → Tween: Pivot 旋转 + Offset 前刺
        → area_entered → 对命中目标施加伤害
        → Tween 结束 → 销毁 hitbox
        → emit attack_executed
```

### 投射物命中
```
Hitbox 碰撞 Hurtbox (Area2D signal)
  → Hurtbox.hit_taken.emit(damage, knockback_dir) → Enemy 扣血（伤害由 Hitbox/Hurtbox 体系自动处理）
  → Projectile.on_hit(target)
    → 遍历子节点 on_hit 组件:
      → KnockbackOnHitComponent.on_hit() → knockback_handler.apply()
      → SlowOnHitComponent.on_hit() → slow_handler.apply_timed_slow()
      → BounceOnHitComponent.on_hit() → 找下一目标(group scan)，改方向
      → PierceComponent.on_hit() → 计数，exhausted → projectile._should_destroy = true
    → EffectsManager.spawn_hit_sparks(position)
    → 若 _should_destroy 或无生命周期组件(Pierce/Bounce) → request_destroy()
```

### 塔攻击
```
Tower._process(delta):
  if _attack_component:
      _attack_component.tick(delta)

RangedAttackComponent.tick(delta):
  → 冷却到期 + TargetFinderComponent.get_target()
  → 创建投射物 → on_projectile_created 回调（ice_flower 覆写 slow 参数）
  → emit projectile_spawned → Tower._on_projectile_spawned() 添加到场景树
  → emit attack_executed → Tower._on_attack_executed() → play_attack_animation()
```

### 向日葵生成
```
GeneratorComponent._on_timer_timeout():
  → generated.emit(amount, global_position)
  → Tower 收到信号 → play_attack_animation()
  → main.gd 监听 EventBus.coins_generated → 创建金币
```

## SceneFactory 变更

### create_projectile (简化)
```gdscript
func create_projectile(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2) -> Projectile:
    var key: String = _get_projectile_pool_key(p_data)
    var proj: Projectile = _pool_acquire(key)
    proj.setup(p_data, damage, from, direction)
    return proj
```
移除 `extra_pierce` 参数（由 PierceComponent 自带配置）。

### create_tower (不变)
```gdscript
func create_tower(type: String, level: int = 1) -> Node2D:
    var tower = _tower_scenes[type].instantiate()
    tower.tower_type = type
    tower.current_level = level
    if GameConfig.towers.has(type):
        tower.data = GameConfig.towers[type]
    return tower
```
塔场景已预配好组件，SceneFactory 无需知道塔类型。

## ice_flower per_level 减速处理

ice_flower 的减速随等级变化（0.3/0.4/0.5），但 SlowOnHitComponent 的默认参数写在 ice_bullet.tscn 场景中。

**解决方案**：在 TowerData 中保留 per_level 减速配置，Tower 在 `set_level()` 或 `_ready()` 时构建 overrides，RangedAttackComponent 在创建投射物后应用：

```gdscript
# TowerData 中保留（仅 ice_flower 使用）
@export var slow_ratio_per_level: PackedFloat32Array   # [0.3, 0.4, 0.5]
@export var slow_duration_per_level: PackedFloat32Array # [1.5, 2.0, 2.5]
```

```gdscript
# Tower._ready() 中构建 overrides
if data.slow_ratio_per_level.size() > 0 and _attack_component:
    var idx: int = current_level - 1
    _attack_component.on_projectile_created = func(proj: Projectile) -> void:
        var slow_comp = proj.get_node_or_null("SlowOnHitComponent")
        if slow_comp:
            slow_comp.slow_ratio = data.slow_ratio_per_level[idx]
            slow_comp.slow_duration = data.slow_duration_per_level[idx]
```

RangedAttackComponent 在创建投射物后调用 `on_projectile_created` 回调（若不为 null）。这样覆写逻辑在 Tower 侧，不污染通用攻击组件。

## .tres 资源文件迁移

Resource 类重构后，现有 .tres 文件需要重建：

### 需要迁移的文件
- `resources/weapons/bow.tres` — 拆出 `AttackConfigData` 子资源，添加 `pivot_offset`、`hide_sprite_on_fire` 等新字段
- `resources/weapons/shuriken.tres` — 同上，`hide_sprite_on_fire = true`
- `resources/weapons/sword.tres` — 同上，添加 `melee_config` 引用
- `resources/towers/pea_shooter.tres` — 拆出 `AttackConfigData` 子资源，移除 `generate_*` 字段
- `resources/towers/ice_flower.tres` — 同上，保留 `slow_ratio/duration_per_level`
- `resources/towers/sunflower.tres` — 拆出 `GeneratorConfigData` 子资源，移除攻击相关字段
- `resources/projectiles/arrow.tres` — 移除 `knockback_force`、`slow_ratio` 等字段（由场景组件配置）
- `resources/projectiles/shuriken.tres` — 同上
- `resources/projectiles/pea_bullet.tres` — 同上
- `resources/projectiles/ice_bullet.tres` — 同上

### 迁移方式
`AttackConfigData` 和 `GeneratorConfigData` 可作为 sub-resource 内嵌在父 .tres 中（Godot 支持嵌套 Resource），无需创建独立文件。迁移时先修改 Resource 类定义，然后重建 .tres 文件内容。

## 测试策略

### 单元测试（新增）
- `test_target_finder_component.gd` — 测试各策略（最近/最低血量/随机）
- `test_ranged_attack_component.gd` — 测试冷却、开火、multiplier
- `test_melee_attack_component.gd` — 测试冷却、hitbox 创建、伤害
- `test_generator_component.gd` — 测试定时生成
- `test_projectile_on_hit.gd` — 测试各命中效果组件（slow/knockback/bounce/pierce）
- `test_projectile_reset.gd` — 测试对象池重置

### 集成测试（修改现有）
- 修改 `test_weapon.gd` — 验证新 Pivot+Offset 结构
- 修改 `test_weapon_manager.gd` — 验证 add/remove/refresh
- 修改 `test_tower.gd` — 验证组件自动初始化

### 回归测试
- 现有 InventoryManager 测试应无需修改（接口不变）
- 现有合成系统测试应无需修改

## 兼容性

### 不变的接口
- `SceneFactory.create_tower(type, level)` — 签名不变
- `SceneFactory.create_projectile()` — 移除 extra_pierce 参数
- `SceneFactory.release_projectile()` — 不变
- `InventoryManager` 接口完全不变
- `EventBus` 信号不变
- `DragManager` 接口不变（仍通过 deploy_id 管理）

### 需要适配的调用方
- `main.gd` — 若直接引用 TowerShooter/TowerGenerator 类型需改为 Tower
- `weapon_manager.gd` — 重写，但对外 API 不变
- 被动系统 (`player.gd`) — multiplier 注入方式从 attacker 改为 RangedAttack/MeleeAttack
