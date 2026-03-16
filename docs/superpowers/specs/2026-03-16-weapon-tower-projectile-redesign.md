# 武器-塔-投射物系统重构设计

## 背景

当前武器、塔和投射物系统存在以下问题：

1. **扩展性差** — 新增武器/塔类型需要修改多处代码（SceneFactory match、WeaponManager match、新子类脚本）
2. **代码重复** — 武器和塔的攻击逻辑（瞄准、冷却、发射）各自实现，逻辑相似但无法复用
3. **灵活性差** — 投射物行为（split/pierce/slow）绑定在全局 GameData，无法按武器/塔独立配置
4. **耦合严重** — 被动技能名硬编码在 weapon.gd、投射物直接读 GameData 全局状态、碰撞层为散落的魔数

## 设计目标

- 武器和塔共享攻击逻辑，通过 AttackerComponent 组件实现
- 投射物由 ProjectileData Resource 数据驱动，消除对 GameData 的直接依赖
- 近战和远程统一在 AttackerComponent 接口下
- 新增武器/塔类型主要靠配置 `.tres` 文件，最小化代码修改
- 被动加成通过 multiplier 注入，AttackerComponent 零被动知识

## 架构总览

```
AttackerComponent (Node) ← 核心新增
├─ 武器组合它 → Weapon + AttackerComponent
├─ 塔组合它   → TowerShooter + AttackerComponent
├─ 统一：目标检测(Callable注入)、冷却管理、攻击触发
├─ 远程 → 发信号，宿主创建投射物
├─ 近战 → 创建临时 HitArea，检测命中

ProjectileData (Resource) ← 核心新增
├─ 投射物全部配置：speed, lifetime, sprite, trail
├─ 命中效果：knockback, pierce, slow
├─ 引用具体投射物场景：projectile_scene

WeaponData / TowerData → 引用 ProjectileData，不再散存投射物相关字段
```

## 详细设计

### 1. AttackerComponent

新增文件：`scripts/components/attacker_component.gd`

```
AttackerComponent (Node)
├─ 配置：
│   attack_mode: AttackMode (RANGED / MELEE)
│   base_damage: float
│   attack_range: float
│   base_cooldown: float
│   projectile_data: ProjectileData  # RANGED 模式
│   melee_config: MeleeConfig        # MELEE 模式
│
├─ 外部注入：
│   target_finder: Callable  # func(range: float) -> Node2D
│   damage_multiplier: float = 1.0  # 被动/buff 加成
│   speed_multiplier: float = 1.0
│
├─ 方法：
│   init(config) — 初始化所有攻击参数
│   tick(delta) — 冷却计时 → 查找目标 → 执行攻击
│   get_final_damage() → base_damage * damage_multiplier
│   get_final_cooldown() → base_cooldown / speed_multiplier
│   update_stats(damage, range, cooldown) — 升级时更新
│
├─ 信号：
│   attack_fired(target: Node2D, projectile_data: ProjectileData)
│   melee_hit(enemies: Array[Node2D])
│   target_changed(new_target: Node2D)
```

**target_finder 机制：** AttackerComponent 不自己查找目标，由宿主注入 Callable：
- 武器：WeaponManager 注入"遍历 enemies 组，返回玩家范围内最近敌人"
- 塔：TowerShooter 注入"DetectArea.get_overlapping_bodies() 中最近敌人"

**RANGED 模式：** 冷却就绪 + 有目标 → 发射 `attack_fired` 信号，宿主监听后调 SceneFactory 创建投射物。AttackerComponent 不依赖 SceneFactory。

**MELEE 模式：** 冷却就绪 + 有目标 → 创建临时 Area2D（使用 MeleeConfig 的角度、半径），检测范围内所有敌人 Hurtbox，发射 `melee_hit` 信号。临时 Area2D 在攻击动画结束后自动销毁。

**加成系统：** 外部（WeaponManager 的被动系统、塔的 buff 系统）直接设置 `damage_multiplier` / `speed_multiplier`，AttackerComponent 在计算最终伤害/冷却时使用。不知道加成来源是什么。

### 2. ProjectileData

新增文件：`scripts/resources/projectile_data.gd`

```
ProjectileData (Resource)
├─ @export speed: float
├─ @export lifetime: float
├─ @export sprite_path: String
├─ @export projectile_scene: PackedScene
├─ @export trail_enabled: bool
├─ @export trail_config: EffectConfigData
│
├─ 命中效果（数据驱动）：
│   @export knockback_force: float = 0.0
│   @export pierce_count: int = 0
│   @export slow_ratio: float = 0.0
│   @export slow_duration: float = 0.0
```

投射物实例在 `setup()` 时从 ProjectileData 读取所有配置，不再访问 GameData。

### 3. MeleeConfig

新增文件：`scripts/resources/melee_config.gd`

```
MeleeConfig (Resource)
├─ @export thrust_distance: float = 15.0
├─ @export hit_angle: float = 90.0
├─ @export hit_radius: float = 20.0
├─ @export knockback_force: float = 50.0
```

剑等近战武器的攻击参数，由 WeaponData 引用。

### 4. ProjectileBase（投射物基类重构）

重命名 `projectile.gd` → `projectile_base.gd`

```
ProjectileBase (Node2D)
├─ data: ProjectileData
├─ Hitbox 子节点
│
├─ setup(data: ProjectileData, damage: float, from: Vector2, direction: Vector2):
│   → 从 data 读取 speed/lifetime/sprite/trail
│   → 设置 Hitbox.damage, Hitbox.knockback_force
│   → 加载并附加精灵
│   → 启动生命计时器
│
├─ _on_hit(enemy):
│   → data.slow_ratio > 0 → enemy.slow_handler.apply_timed_slow(...)
│   → data.pierce_count > 0 → hit_count += 1, 超出则销毁
│   → else → 直接销毁
│
├─ _physics_process: 直线飞行（默认行为）
```

**BulletProjectile 合并到 ProjectileBase：** 当前 BulletProjectile 的直线飞行 + 命中效果就是默认行为。trail 系统保留在 ProjectileBase 中。

**split（分裂）移出投射物：** 分裂是被动技能效果，改由被动系统在 `attack_fired` 信号链中处理，不再由投射物自己负责。

**ShurikenProjectile 保留为子类：** 覆写飞行逻辑（二段弹跳），其余（命中效果、trail）继承 ProjectileBase。

### 5. WeaponData 调整

修改文件：`scripts/resources/weapon_data.gd`

```
保留：
  damage_per_level, fire_rate_per_level, weapon_range_per_level
  sell_price_per_level, rarity

新增：
  @export attack_mode: AttackMode  # RANGED / MELEE
  @export projectile_data: ProjectileData  # 远程武器的投射物配置
  @export melee_config: MeleeConfig  # 近战武器的攻击配置
  @export sprite_path: String  # 武器浮动精灵路径

删除：
  projectile_type — 移入 ProjectileData.projectile_scene
  bullet_speed — 移入 ProjectileData.speed
  knockback_force — 移入 ProjectileData/MeleeConfig
  shuriken_speed, outbound_distance, return_speed_mult, shuriken_max_lifetime
    — 移入手里剑的 ProjectileData 或 ShurikenProjectile 自身配置
```

### 6. TowerData 调整

修改文件：`scripts/resources/tower_data.gd`

```
保留：
  hp_per_level, damage_per_level, fire_rate_per_level, attack_range_per_level
  sell_price_per_level, rarity
  generate_amount_per_level, generate_interval_per_level（向日葵用）

新增：
  @export projectile_data: ProjectileData  # 射手塔的投射物配置

删除：
  slow_ratio_per_level — 移入 ProjectileData.slow_ratio
  slow_duration_per_level — 移入 ProjectileData.slow_duration
```

注意：冰花塔的减速参数不再是 per_level 数组，而是固定在 ProjectileData 中。如果未来需要 per_level 减速，可以为每个等级创建不同的 ProjectileData，或在 TowerShooter 升级时动态修改 projectile_data 的值。当前 3 级塔的减速比例固定，不需要 per_level。

### 7. Weapon 脚本重构

修改文件：`scripts/entities/weapons/weapon.gd`

```
Weapon (Node)
├─ data: WeaponData
├─ attacker: AttackerComponent  # 动态创建的子节点
├─ _level: int
│
├─ initialize(data, level, owner_node):
│   → 创建 AttackerComponent 并 add_child
│   → attacker.init(
│       damage = data.damage_per_level[level-1],
│       range = data.weapon_range_per_level[level-1],
│       cooldown = data.fire_rate_per_level[level-1],
│       attack_mode = data.attack_mode,
│       projectile_data = data.projectile_data,
│       melee_config = data.melee_config)
│   → 连接 attacker 信号
│
├─ _on_attack_fired(target, proj_data):
│   → 调 SceneFactory.create_projectile(proj_data, damage, pos, dir)
│
├─ _on_melee_hit(enemies):
│   → 对每个敌人应用伤害和击退
```

**删除 BowWeapon 和 SwordWeapon 子类：** 通用 Weapon + WeaponData.attack_mode 即可覆盖。

**保留 ShurikenWeapon 子类：** 覆写 `_on_attack_fired` 以处理精灵隐藏/回收的特殊视觉交互。

### 8. WeaponManager 调整

修改文件：`scripts/entities/weapons/weapon_manager.gd`

```
职责收窄：
  1. 从 GameData.deployed_weapons 创建 Weapon 实例
  2. 为每个 Weapon 注入 target_finder（最近敌人查找 Callable）
  3. tick() 时调用每个 weapon.attacker.tick(delta)
  4. 管理浮动精灵视觉（轨道动画）
  5. 从 GameData.player_stats 计算被动 multiplier，注入 attacker

不再负责：
  × 攻击冷却逻辑（AttackerComponent 管理）
  × 武器类型判断（WeaponData.attack_mode 决定）
  × 被动名硬编码（统一读 player_stats multiplier）

创建逻辑简化：
  "bow" / "sword" → Weapon.new()
  "shuriken"      → ShurikenWeapon.new()
```

### 9. TowerShooter 调整

修改文件：`scripts/entities/towers/tower_shooter.gd`

```
TowerShooter (extends Tower)
├─ attacker: AttackerComponent  # 替代 ShootTimer + 手动逻辑
├─ detect_area: Area2D          # 保留
│
├─ _ready():
│   → 创建 AttackerComponent
│   → attacker.init(damage, range, cooldown, RANGED, data.projectile_data)
│   → attacker.target_finder = 基于 detect_area 的 Callable
│   → 连接 attacker.attack_fired
│
├─ _on_attack_fired(target, proj_data):
│   → SceneFactory.create_projectile(proj_data, attacker.get_final_damage(), ...)
│   → play_attack_animation()
│
├─ apply_buff → attacker.damage_multiplier / speed_multiplier
├─ _apply_level_stats → attacker.update_stats(...)
```

ShootTimer 节点删除，由 AttackerComponent 内部冷却替代。

### 10. SceneFactory 调整

修改文件：`scripts/core/scene_factory.gd`

```
删除：
  create_bullet_projectile()
  create_shuriken_projectile()

新增：
  create_projectile(data: ProjectileData, damage: float,
                    from: Vector2, direction: Vector2) -> ProjectileBase:
    var proj = data.projectile_scene.instantiate()
    proj.setup(data, damage, from, direction)
    return proj
```

### 11. CollisionLayers 常量

新增文件：`scripts/core/collision_layers.gd`

```
class_name CollisionLayers

const PLAYER = 1
const ENEMY = 2
const HITBOX = 4
const TOWER = 8
const HURTBOX = 128
```

所有脚本中的碰撞层魔数替换为此常量引用。

### 12. 被动加成改造

**现在：**
```gdscript
# weapon.gd 硬编码
if GameData.new_passive_id == "swift_combo":
    base *= owner_node.get_combo_damage_mult()
```

**重构后：**
```gdscript
# WeaponManager 统一计算并注入
func _apply_passive_to_weapons():
    var mult = GameData.player_stats.get("damage_mult", 1.0)
    for weapon in _weapons:
        weapon.attacker.damage_multiplier = mult
```

动态被动（如连击递增）通过信号更新 multiplier，武器/塔代码不需要知道被动是什么。

## 文件变更清单

| 操作 | 文件 |
|------|------|
| 新增 | `scripts/components/attacker_component.gd` |
| 新增 | `scripts/resources/projectile_data.gd` |
| 新增 | `scripts/resources/melee_config.gd` |
| 新增 | `scripts/core/collision_layers.gd` |
| 新增 | `resources/projectiles/*.tres`（arrow、pea、ice 等投射物配置） |
| 重构 | `scripts/entities/weapons/weapon.gd` — 组合 AttackerComponent |
| 重构 | `scripts/entities/weapons/weapon_manager.gd` — 简化 |
| 重构 | `scripts/entities/towers/tower_shooter.gd` — 组合 AttackerComponent |
| 重构 | `scripts/entities/projectiles/projectile.gd` → `projectile_base.gd` |
| 重构 | `scripts/entities/projectiles/bullet_projectile.gd` → 合并到 projectile_base |
| 重构 | `scripts/resources/weapon_data.gd` — 新增字段，删除散字段 |
| 重构 | `scripts/resources/tower_data.gd` — 新增 projectile_data，删除 slow 散字段 |
| 重构 | `scripts/core/scene_factory.gd` — 统一 create_projectile() |
| 删除 | `scripts/entities/weapons/bow_weapon.gd` |
| 删除 | `scripts/entities/weapons/sword_weapon.gd` |
| 保留 | `scripts/entities/weapons/shuriken_weapon.gd` — 特殊精灵交互 |
| 保留 | `scripts/entities/projectiles/shuriken_projectile.gd` — 弹跳逻辑 |
| 保留 | `scripts/entities/towers/tower.gd` — 基类微调 |
| 保留 | `scripts/entities/towers/tower_generator.gd` — 不涉及 |
| 更新 | `.tscn` 场景文件 — 碰撞层常量化 |
| 更新 | `.tres` 配置文件 — 适配新字段结构 |
| 更新 | 测试文件 — 适配新架构 |

## 数据流示例

### 弓箭武器攻击流程
```
WeaponManager.tick(delta)
→ weapon.attacker.tick(delta)
→ attacker: cooldown就绪 → target_finder.call(range) → 返回敌人
→ attacker: emit attack_fired(enemy, projectile_data)
→ weapon._on_attack_fired: SceneFactory.create_projectile(proj_data, damage, pos, dir)
→ ProjectileBase.setup(data, damage, pos, dir): 读 speed/lifetime/sprite/trail
→ 飞行 → 命中 → _on_hit: 应用 knockback/pierce/slow（从 data 读取）
```

### 冰花塔攻击流程
```
TowerShooter._process(delta)
→ attacker.tick(delta)
→ attacker: cooldown就绪 → target_finder.call(range) → detect_area 内最近敌人
→ attacker: emit attack_fired(enemy, data.projectile_data)
→ tower._on_attack_fired: SceneFactory.create_projectile(proj_data, damage, pos, dir)
→ ProjectileBase.setup: 读 speed, sprite=ice_bullet, slow_ratio=0.3, slow_duration=2.0
→ 飞行 → 命中 → _on_hit: 应用减速（data.slow_ratio > 0）
→ play_attack_animation()
```

### 剑近战攻击流程
```
WeaponManager.tick(delta)
→ weapon.attacker.tick(delta)
→ attacker: cooldown就绪 → target_finder.call(range) → 返回敌人
→ attacker: MELEE模式 → 创建临时 HitArea(MeleeConfig)
→ 检测范围内敌人 Hurtbox → emit melee_hit(enemies)
→ weapon._on_melee_hit: 对每个敌人应用伤害和击退
→ 临时 HitArea 自动销毁
```
