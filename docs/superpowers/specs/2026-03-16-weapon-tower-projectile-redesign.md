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
│   注：cooldown 参数接收的是 WeaponData/TowerData 的 fire_rate_per_level 值。
│   这些值语义上是"攻击间隔（秒）"而非频率，即 cooldown。命名沿用 fire_rate 以保持
│   与现有 .tres 配置文件一致，AttackerComponent 内部存为 base_cooldown。
│
├─ 信号：
│   attack_fired(target: Node2D, projectile_data: ProjectileData)
│   melee_triggered(target: Node2D, melee_config: MeleeConfig)
│   target_changed(new_target: Node2D)
```

**target_finder 机制：** AttackerComponent 不自己查找目标，由宿主注入 Callable：
- 武器：WeaponManager 注入"遍历 enemies 组，返回玩家范围内最近敌人"
- 塔：TowerShooter 注入"DetectArea.get_overlapping_bodies() 中最近敌人"

**RANGED 模式：** 冷却就绪 + 有目标 → 发射 `attack_fired` 信号，宿主监听后调 SceneFactory 创建投射物。AttackerComponent 不依赖 SceneFactory。

**MELEE 模式：** 冷却就绪 + 有目标 → 发射 `melee_triggered(target, melee_config)` 信号。宿主（Weapon）监听后：
1. 创建临时 Area2D 挂在精灵上，连接 `area_entered` 信号
2. 用 Tween 播放突刺动画（精灵前进 `thrust_distance` 再收回）
3. 动画过程中 `area_entered` 检测到 Hurtbox → 收集命中敌人，发射 `Hurtbox.hit_taken`
4. 动画结束回调中 `queue_free()` 临时 Area2D

这样保留了当前 SwordWeapon 的 Tween 突刺视觉效果，同时避免了"同帧创建 Area2D 无法检测"的 Godot 物理时序问题（Area2D 存活多帧，通过 `area_entered` 信号异步检测）。AttackerComponent 只负责冷却和触发，不负责近战的碰撞检测细节。

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
│   @export base_pierce_count: int = 0   # 基础穿透次数
│   @export slow_ratio: float = 0.0
│   @export slow_duration: float = 0.0
```

投射物实例在 `setup()` 时从 ProjectileData 读取所有配置，不再访问 GameData。

**Pierce 动态加成：** `ProjectileData.base_pierce_count` 是静态基础值（写在 .tres 中）。运行时被动加成的穿透通过 `setup()` 的额外参数注入：`setup(data, damage, from, direction, extra_pierce: int = 0)`。投射物实际穿透次数 = `data.base_pierce_count + extra_pierce`。WeaponManager 在创建投射物时从 `GameData.pierce_count` 读取 extra_pierce 并传入。塔的投射物不受被动穿透影响（extra_pierce=0）。

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
├─ setup(data: ProjectileData, damage: float, from: Vector2, direction: Vector2, extra_pierce: int = 0):
│   → 从 data 读取 speed/lifetime/sprite/trail
│   → 设置 Hitbox.damage, Hitbox.knockback_force
│   → _pierce_count = data.base_pierce_count + extra_pierce
│   → 加载并附加精灵（从 data.sprite_path）
│   → 启动生命计时器
│   注：签名与当前 Projectile.setup(damage, knockback, from, dir) 不兼容，为 breaking change。
│   受影响调用者：tower_shooter.gd、bow_weapon.gd、bullet_projectile._spawn_split_bullets()（将被删除）。
│   迁移时统一更新为新签名。
│
├─ 信号：
│   hit(position: Vector2, direction: Vector2)  # 命中时发射，供外部监听（如分裂）
│
├─ _on_hit(enemy):
│   → data.slow_ratio > 0 → enemy.slow_handler.apply_timed_slow(...)
│   → emit hit(global_position, _direction)
│   → pierce_count(= data.base_pierce_count + extra_pierce) > 0 → hit_count += 1, 超出则销毁
│   → else → 直接销毁
│
├─ _physics_process: 直线飞行（默认行为）
```

**BulletProjectile 合并到 ProjectileBase：** 当前 BulletProjectile 的直线飞行 + 命中效果就是默认行为。trail 系统保留在 ProjectileBase 中。

**split（分裂）移出投射物：** 分裂是被动技能效果，不再由投射物自己读取 GameData 处理。改为：
1. WeaponManager 监听自己创建的每个投射物的 `hit` 信号（ProjectileBase 命中时新增发射 `hit(position, direction)` 信号）
2. WeaponManager 检查 `GameData.split_count > 0` 且投射物非分裂子弹（`is_split` meta）
3. 若满足条件，WeaponManager 调 `SceneFactory.create_projectile()` 生成分裂子弹，设置 `set_meta("is_split", true)`，伤害 = 原伤害 * `GameData.split_damage_mult`
4. 分裂子弹不会再次分裂（通过 `is_split` meta 判断）

这样分裂逻辑完全在 WeaponManager 中，投射物保持纯净。塔的投射物不触发分裂（塔不经过 WeaponManager）。

**ShurikenProjectile 保留为子类：** `extends ProjectileBase`（原 `extends Projectile`，需更新）。覆写飞行逻辑（二段弹跳），其余（命中效果、trail）继承 ProjectileBase。

**class_name 更名影响：** `Projectile` → `ProjectileBase`。所有 `extends Projectile` 和类型引用需更新。涉及文件：`shuriken_projectile.gd`、`scene_factory.gd`、测试文件。

**音效触发：** 攻击音效在宿主的信号处理器中播放（与当前一致）：
- Weapon._on_attack_fired / _on_melee_triggered 中调 `AudioManager.play("shoot")`
- TowerShooter._on_attack_fired 中调 `AudioManager.play("shoot")`
不放在 AttackerComponent 中（组件不依赖 AudioManager）。

**精灵附加统一到 ProjectileBase.setup()：** 当前 BowWeapon 和 TowerShooter 各自创建 Sprite2D 附加到投射物。重构后统一由 `ProjectileBase.setup()` 从 `data.sprite_path` 加载并附加精灵，调用者不再处理。

### 5. WeaponData 调整

修改文件：`scripts/resources/weapon_data.gd`

```
保留：
  damage_per_level, fire_rate_per_level, weapon_range_per_level
  sell_price_per_level
  （注：rarity 字段当前不在 WeaponData 中，在 ShopConfig 商店系统管理，不涉及本次重构）

新增：
  @export attack_mode: AttackMode  # RANGED / MELEE
  @export projectile_data: ProjectileData  # 远程武器的投射物配置
  @export melee_config: MeleeConfig  # 近战武器的攻击配置
  （icon_path 已存在，用于武器浮动精灵和商店图标，保留不变）

删除：
  projectile_type — 移入 ProjectileData.projectile_scene
  bullet_speed — 移入 ProjectileData.speed
  knockback_force — 移入 ProjectileData.knockback_force 或 MeleeConfig.knockback_force

手里剑专有字段迁移：
  shuriken_speed → 使用 ProjectileData.speed（手里剑的 ProjectileData.tres 中配置）
  shuriken_max_lifetime → 使用 ProjectileData.lifetime
  outbound_distance, return_speed_mult → 移入 ShurikenProjectile 脚本的 @export 字段
    （这些是弹跳飞行行为参数，属于 ShurikenProjectile 子类特有，不适合放在通用 ProjectileData 中）
  bounce_range → 已在 ShurikenProjectile 中（当前为 var bounce_range = 150.0），改为 @export 即可
```

### 6. TowerData 调整

修改文件：`scripts/resources/tower_data.gd`

```
保留：
  hp_per_level, damage_per_level, fire_rate_per_level, attack_range_per_level
  sell_price_per_level
  generate_amount_per_level, generate_interval_per_level（向日葵用）
  （注：rarity 字段同 WeaponData，由商店系统管理）

新增：
  @export projectile_data: ProjectileData  # 射手塔的投射物配置

保留（用于 per_level 覆写 ProjectileData，见上方冰花塔说明）：
  slow_ratio_per_level
  slow_duration_per_level
```

**冰花塔 per_level 减速处理：** 当前 ice_flower.tres 有 per_level 减速值（Lv1: 0.3/1.5s, Lv2: 0.4/2.0s, Lv3: 0.5/2.5s）。ProjectileData 的 slow_ratio/slow_duration 是固定值，无法表达 per_level。解决方案：TowerShooter 在 `_apply_level_stats()` 时，动态覆写 `projectile_data.slow_ratio` 和 `projectile_data.slow_duration`（Resource 是引用类型，需要 `duplicate()` 避免污染原始配置）。即：
```gdscript
func _apply_level_stats():
    # ... 其他 stats 更新 ...
    if data.slow_ratio_per_level.size() > 0:
        # duplicate 避免修改原始 Resource
        var proj_data = data.projectile_data.duplicate()
        proj_data.slow_ratio = data.slow_ratio_per_level[idx]
        proj_data.slow_duration = data.slow_duration_per_level[idx]
        attacker.projectile_data = proj_data
```
TowerData 保留 `slow_ratio_per_level` 和 `slow_duration_per_level` 字段（不删除），用于 per_level 覆写。

### 7. Weapon 脚本重构

修改文件：`scripts/entities/weapons/weapon.gd`

```
Weapon (Node)
├─ data: WeaponData
├─ attacker: AttackerComponent  # 动态创建的子节点
├─ _level: int
│
├─ initialize(data: WeaponData) → void:
│   → 保存 data
│   → 创建 AttackerComponent 并 add_child
│   → 连接 attacker 信号（attack_fired / melee_triggered）
│
├─ set_level(level: int) → void:
│   → _level = level
│   → attacker.update_stats(
│       damage = data.damage_per_level[level-1],
│       range = data.weapon_range_per_level[level-1],
│       cooldown = data.fire_rate_per_level[level-1])
│   → attacker.attack_mode = data.attack_mode
│   → attacker.projectile_data = data.projectile_data
│   → attacker.melee_config = data.melee_config
│
├─ _on_attack_fired(target, proj_data):
│   → 调 SceneFactory.create_projectile(proj_data, damage, pos, dir, extra_pierce)
│
├─ _on_melee_triggered(target, melee_config):
│   → 创建临时 Area2D + Tween 突刺动画（详见 AttackerComponent MELEE 模式说明）
│   → area_entered 检测到 Hurtbox → 发射 hit_taken 信号
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

创建流程（_add_weapon）：
  1. 根据 weapon_id match 创建实例：
     "bow" / "sword" → Weapon.new()
     "shuriken"      → ShurikenWeapon.new()
  2. weapon.initialize(data)  # 传入 WeaponData
  3. weapon.set_level(level)  # 配置等级参数
  4. weapon.owner_node = player  # 设置宿主引用
  5. weapon.attacker.target_finder = _find_nearest_enemy  # 注入目标查找
  6. _apply_passive_to_weapon(weapon)  # 注入被动 multiplier
  ShurikenWeapon 继承 Weapon，initialize/set_level 签名不变，仅覆写 _on_attack_fired
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
├─ apply_buff(dmg_mult, spd_mult, source_id):
│   → attacker.damage_multiplier = dmg_mult
│   → attacker.speed_multiplier = spd_mult
│
├─ _apply_level_stats():
│   → attacker.update_stats(damage, range, cooldown)  # 从 TowerData per_level 读取
│   → 基础 damage 已包含 TOWER_MULT：
│       damage = data.damage_per_level[idx] * GameData.player_stats.get(Enums.Stat.TOWER_MULT, 1.0)
│   → 冰花塔 per_level slow 覆写（见 TowerData 调整说明）
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
                    from: Vector2, direction: Vector2,
                    extra_pierce: int = 0) -> ProjectileBase:
    var proj = data.projectile_scene.instantiate()
    proj.setup(data, damage, from, direction, extra_pierce)
    return proj
```

### 11. CollisionLayers 常量

新增文件：`scripts/core/collision_layers.gd`

```gdscript
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

脚本中使用位掩码常量（`collision_layer = CollisionLayers.HITBOX`），`.tscn` 场景文件中的层配置通过编辑器设置（不需要代码修改，但确保与常量一致）。

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
| 重构 | `scripts/resources/tower_data.gd` — 新增 projectile_data，保留 slow per_level 字段（用于动态覆写） |
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
→ attacker: MELEE模式 → emit melee_triggered(target, melee_config)
→ weapon._on_melee_triggered:
  → 创建临时 Area2D(layer=HITBOX, mask=HURTBOX) 挂在精灵上
  → Tween 突刺动画：精灵前进 thrust_distance 再收回（0.1s + 0.1s）
  → 动画过程中 area_entered → Hurtbox.hit_taken.emit(damage, knockback)
  → 动画结束 → queue_free() 临时 Area2D
→ AudioManager.play("shoot")
```
