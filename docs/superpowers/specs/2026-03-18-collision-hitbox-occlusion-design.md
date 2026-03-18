# 碰撞/Hitbox/遮挡系统规范化设计

> 日期: 2026-03-18
> 状态: 已批准

## 背景

当前项目的碰撞层使用纯数字硬编码（无命名）、Hitbox/Hurtbox 尺寸缺乏差异化设计（玩家和敌人相同大小）、塔的受伤机制游离于 Hitbox/Hurtbox 体系外、且所有游戏实体没有深度排序（z_index 全默认为 0）。本次改进旨在系统性规范化这三个方面。

## 目标

1. **碰撞层规范化**：重新定义 8 层碰撞层并在 project.godot 中命名
2. **Hitbox/Hurtbox 尺寸调优**：玩家 Hurtbox 缩小、敌人 Hurtbox 增大，营造"对玩家有利"的手感
3. **碰撞形状统一**：移动实体（Player/Enemy）的 CharacterBody2D 碰撞形状从 Rect 改为 Circle
4. **塔 Hurtbox 统一**：塔加入 Hitbox/Hurtbox 伤害体系
5. **渲染深度分层**：引入 Y-Sort + z_index 分层，解决实体间遮挡问题

## 一、碰撞层定义

在 `project.godot` 中命名 2D Physics 层：

| 层 | 名称 | 用途 |
|---|---|---|
| 1 | Player | 玩家 CharacterBody2D |
| 2 | Enemy | 敌人 CharacterBody2D |
| 3 | Tower | 塔 StaticBody2D |
| 4 | Pickup | Coin / ExpOrb（Area2D） |
| 5 | PlayerAttack | 玩家侧攻击 Hitbox（投射物 + 近战） |
| 6 | EnemyAttack | 敌人侧攻击 Hitbox（接触伤害） |
| 7 | DefenderHurt | 被敌人攻击的目标 Hurtbox（玩家 + 塔） |
| 8 | EnemyHurt | 被玩家攻击的目标 Hurtbox（敌人） |

### 碰撞矩阵

```
PlayerAttack(5) → EnemyHurt(8)    玩家攻击命中敌人
EnemyAttack(6) → DefenderHurt(7)  敌人接触伤害玩家和塔
Pickup(4)      → Player(1)        拾取检测
Enemy(2)       → Tower(3)         敌人被塔阻挡（物理碰撞）
Player(1)      → Tower(3)         玩家被塔阻挡（物理碰撞）
```

### 各实体 layer/mask 配置

| 实体节点 | collision_layer | collision_mask |
|---|---|---|
| Player CharacterBody2D | 1 (Player) | 3 (Tower) |
| Player Hurtbox (Area2D) | 7 (DefenderHurt) | 6 (EnemyAttack) |
| Enemy CharacterBody2D | 2 (Enemy) | 3 (Tower) |
| Enemy Hitbox (Area2D) | 6 (EnemyAttack) | 7 (DefenderHurt) |
| Enemy Hurtbox (Area2D) | 8 (EnemyHurt) | 5 (PlayerAttack) |
| Boss — 同 Enemy | 同上 | 同上 |
| Tower StaticBody2D | 3 (Tower) | 1+2 (Player+Enemy) |
| Tower Hurtbox (Area2D, 新增) | 7 (DefenderHurt) | 6 (EnemyAttack) |
| 投射物 Hitbox (Area2D) | 5 (PlayerAttack) | 8 (EnemyHurt) |
| 近战动态 Hitbox (Area2D) | 5 (PlayerAttack) | 8 (EnemyHurt) |
| Coin / ExpOrb (Area2D) | 4 (Pickup) | 1 (Player) |
| TargetFinderComponent (Area2D) | 0 (无) | 2 (Enemy) |

注意：
- 敌人之间不互相碰撞（同在层2，但 mask 不含层2）
- Player CharacterBody2D 的 mask 只含 Tower，不含 Enemy（避免敌人推开玩家）
- Enemy CharacterBody2D 的 mask 只含 Tower（敌人被塔阻挡，但不被其他敌人或玩家阻挡）

## 二、碰撞形状规范

### 身体碰撞（CharacterBody2D / StaticBody2D）

| 实体 | 当前形状 | 新形状 | 理由 |
|---|---|---|---|
| Player | Rect 32×32 | **Circle r=14** | 圆形在俯视角下方向无关，移动更顺滑 |
| Enemy (normal/fast/tank) | Rect 32×32 | **Circle r=14** | 同上，且避免矩形"卡角" |
| Boss | Rect 48×48 | **Circle r=22** | 同比缩放 |
| Tower | Rect 32×32 | **Rect 32×32（不变）** | 塔是静态方形建筑，矩形符合占位 |

### Hitbox / Hurtbox（Area2D）

| 碰撞区 | 当前 | 新尺寸 | 设计理由 |
|---|---|---|---|
| Player Hurtbox | Circle r=13 | **Circle r=8** | 约精灵 50%，允许"擦弹"体验，大幅降低被命中率 |
| Enemy Hitbox（接触伤害） | Circle r=13 | **Circle r=10** | 缩小配合玩家 Hurtbox 缩小，接触距离 18px |
| Enemy Hurtbox | Circle r=13 | **Circle r=15** | 大于精灵，投射物更容易命中 |
| Boss Hitbox | Circle r=20 | **Circle r=16** | 同比调整 |
| Boss Hurtbox | Circle r=20 | **Circle r=24** | 大体型更好打 |
| Tower Hurtbox（新增） | 无 | **Circle r=16** | 塔占 32×32，Circle r=16 略大于内切圆 |
| 投射物 Hitbox (arrow/pea) | Circle r=4 | **Circle r=6** | 增大命中判定 |
| 投射物 Hitbox (shuriken) | Circle r=6 | **Circle r=8** | 手里剑视觉更大，判定匹配 |
| 近战动态 Hitbox | melee_config.hit_radius | **不变** | 由 MeleeConfig 配置驱动 |
| Coin / ExpOrb | Circle r=3 | **不变** | 拾取靠吸引逻辑，判定大小合适 |

### 设计原则

- **玩家 Hurtbox 小于精灵**：给玩家躲避空间，提升手感
- **敌人 Hurtbox 大于精灵**：玩家攻击更容易命中，增加爽感
- **圆形优先**：所有 Hitbox/Hurtbox 统一用 CircleShape2D，移动实体的 body 也用 Circle
- **静态实体用 Rect**：塔等不移动的方形建筑保持 RectangleShape2D

## 三、渲染深度分层

### Z-Index 层级

```
z_index -1 : TileMap 地面/装饰（已有）
z_index  0 : 拾取物（Coin、ExpOrb）
z_index  1 : 实体层（Player、Enemy、Tower）— 开启 y_sort
z_index  2 : 投射物（Arrow、Shuriken、PeaBullet、IceBullet）
z_index  3 : 特效（伤害数字、击中火花、死亡爆炸）
```

### Y-Sort 实现方案

1. **main 场景**中创建 `EntityLayer` 节点（Node2D），设置：
   - `y_sort_enabled = true`
   - `z_index = 1`

2. **Player、所有 Enemy、所有 Tower** 作为 `EntityLayer` 的子节点

3. 各实体的 **y_sort_origin** 设置到脚底（精灵下边缘）：
   - Player/Enemy（32×32 精灵）：y_sort_origin 约 +16（精灵中心到脚底）
   - Boss（48×48 或 更大）：按精灵高度比例设置
   - Tower（32×32）：y_sort_origin 约 +16

4. **投射物**不放入 EntityLayer，挂在 main 下独立容器，z_index=2

5. **Coin/ExpOrb** 不放入 EntityLayer，z_index=0（地面层）

6. **特效**（EffectsManager 生成的节点）z_index=3

### 对 SceneFactory 的影响

SceneFactory 创建实体后，需要将实体添加到正确的父容器：
- `create_enemy()` / `create_tower()` → 添加到 EntityLayer
- `create_projectile()` → 添加到 ProjectileLayer（或 main 根节点，z_index=2）
- `create_coin()` / `create_exp_orb()` → 添加到 main 根节点（z_index=0）

这可能需要 SceneFactory 持有各容器的引用，或由调用方指定父节点。

## 四、塔 Hurtbox 统一

### 变更内容

1. 所有塔 .tscn（pea_shooter、ice_flower、sunflower）添加 Hurtbox 子节点：
   - 类型：Area2D（使用 Hurtbox 组件脚本）
   - collision_layer = 7（DefenderHurt）
   - collision_mask = 6（EnemyAttack）
   - CollisionShape2D: CircleShape2D r=16

2. tower.gd 的 `_ready()` 中检测 Hurtbox 并连接 `hit_taken` 信号

3. enemy.gd 中移除直接调用塔 `health.take_damage()` 的逻辑（`_attack_tower()` 方法），改为通过 Hitbox→Hurtbox 碰撞触发

### 信号签名适配

当前 `Hurtbox.hit_taken` 信号签名为 `(damage: float, knockback: Vector2)`，而 `HealthComponent.take_damage()` 期望 `(amount: float, attacker: Node2D = null)`。需要在 tower.gd 中添加包装方法：

```gdscript
func _on_hurtbox_hit_taken(damage: float, _knockback: Vector2) -> void:
    health.take_damage(damage)
```

### 重复伤害机制

**关键设计点**：当前敌人攻击塔通过 `_attack_tower()` + `attack_timer`（1秒间隔）实现持续伤害。Area2D 的 `area_entered` 仅在首次重叠时触发一次，不会持续触发。

解决方案：敌人 Hitbox 保持持续伤害能力。在 Hurtbox 组件中增加 **重复伤害模式**：
- Hurtbox 新增 `@export var repeat_damage: bool = false`
- Hurtbox 新增 `@export var repeat_interval: float = 1.0`
- 当 `repeat_damage = true` 时，Hurtbox 在 `area_entered` 后启动定时器，每 `repeat_interval` 秒对仍在重叠范围内的 Hitbox 重新触发 `hit_taken`
- 在 `area_exited` 时清除该 Hitbox 的定时
- **玩家 Hurtbox**：`repeat_damage = true, repeat_interval = 1.0`（与当前行为一致）
- **塔 Hurtbox**：`repeat_damage = true, repeat_interval = 1.0`
- **敌人 Hurtbox**：`repeat_damage = false`（投射物命中即消失，不需要重复）

### 敌人攻击塔的流程（改后）

```
Enemy Hitbox (layer 6, EnemyAttack)
  ↓ Area2D overlap (area_entered)
Tower Hurtbox (layer 7, DefenderHurt, mask 6, repeat_damage=true)
  ↓ hit_taken signal (首次 + 每 1.0 秒重复)
tower._on_hurtbox_hit_taken(damage, knockback)
  ↓
Tower HealthComponent.take_damage(damage)
```

与敌人攻击玩家走完全相同的管线（玩家 Hurtbox 同样 repeat_damage=true）。

## 五、受影响的文件清单

### 配置文件
- `project.godot` — 添加碰撞层命名

### 场景文件（碰撞层 + 形状修改）
- `scenes/entities/player.tscn` — body Circle r=14, Hurtbox layer/mask/size, repeat_damage=true
- `scenes/entities/enemies/enemy_normal.tscn` — body Circle r=14, Hitbox/Hurtbox layer/mask/size
- `scenes/entities/enemies/enemy_fast.tscn` — 同上
- `scenes/entities/enemies/enemy_tank.tscn` — 同上
- `scenes/entities/enemies/boss_brute.tscn` — body Circle r=22, Hitbox/Hurtbox layer/mask/size
- `scenes/entities/enemies/boss_summoner.tscn` — 同上
- `scenes/entities/enemies/boss_guardian.tscn` — 同上
- `scenes/entities/towers/tower_pea_shooter.tscn` — 添加 Hurtbox, layer/mask, repeat_damage=true
- `scenes/entities/towers/tower_ice_flower.tscn` — 同上
- `scenes/entities/towers/tower_sunflower.tscn` — 同上
- `scenes/entities/projectiles/arrow.tscn` — Hitbox layer/mask/size
- `scenes/entities/projectiles/shuriken.tscn` — 同上
- `scenes/entities/projectiles/pea_bullet.tscn` — 同上
- `scenes/entities/projectiles/ice_bullet.tscn` — 同上
- `scenes/entities/projectiles/bullet_projectile.tscn` — Hitbox layer/mask/size（未追踪文件）
- `scenes/entities/projectiles/shuriken_projectile.tscn` — 同上（未追踪文件）
- `scenes/entities/coin.tscn` — layer/mask
- `scenes/entities/exp_orb.tscn` — layer/mask
- `scenes/levels/main.tscn` — 添加 EntityLayer (y_sort) 和 ProjectileLayer 容器

### 脚本文件
- `scripts/components/hurtbox.gd` — 添加 repeat_damage/repeat_interval 功能
- `scripts/components/melee_attack_component.gd` — 动态 Hitbox 的 layer 从 4 改为 16（PlayerAttack 层5 = bitmask 16），mask 保持 128（EnemyHurt 层8 = bitmask 128）
- `scripts/components/target_finder_component.gd` — mask 确认为层2(Enemy)，武器和塔共用
- `scripts/entities/tower.gd` — 添加 Hurtbox 信号连接 + `_on_hurtbox_hit_taken()` 包装方法
- `scripts/entities/enemy.gd` — 移除 `_attack_tower()` 逻辑及相关定时器。注：boss_base.gd 继承 enemy.gd，改动自动传播到所有 Boss
- `scripts/systems/enemy_spawner.gd` — 敌人 add_child 目标改为 EntityLayer
- `scripts/systems/drag_manager.gd` — 塔放置 add_child 目标改为 EntityLayer
- `scripts/core/scene_factory.gd` — 持有 EntityLayer/ProjectileLayer/PickupLayer 容器引用，提供 `init_containers(entity_layer, projectile_layer, pickup_layer)` 方法，由 main.gd 在 `_ready()` 时调用。创建实体后自动 add_child 到对应容器
- `scripts/systems/effects_manager.gd` — 特效节点 z_index=3（检查与现有 EffectConfigData z_index 字段的关系）
- `scripts/ui/main.gd` — 创建 EntityLayer/ProjectileLayer 容器并初始化 SceneFactory

## 六、Y-Sort 技术细节

Godot 4.4+ 提供 `CanvasItem.y_sort_origin` 属性（int 类型，像素偏移），无需手动偏移精灵位置。项目使用 Godot 4.6，可直接使用此属性。

各实体 y_sort_origin 值（从 Node2D 原点到脚底的 Y 偏移）：
- Player/Enemy（32×32 精灵）：`y_sort_origin = 16`
- Boss（48×48 精灵，scale 2×）：`y_sort_origin = 24`
- Tower（32×32 精灵）：`y_sort_origin = 16`

## 七、add_child 调用点完整清单

以下所有调用点需要改为添加到正确的容器：

| 调用位置 | 当前目标 | 新目标 | 说明 |
|---|---|---|---|
| `enemy_spawner.gd` 生成敌人/Boss | `get_parent()` (main) | EntityLayer | 敌人实体 |
| `enemy.gd` `_drop_exp_orbs()` | `get_parent()` (main) | PickupLayer | 经验球 |
| `enemy.gd` `_drop_coins()` | `get_parent()` (main) | PickupLayer | 金币 |
| `tower.gd` `_on_projectile_spawned()` | `get_parent()` (main) | ProjectileLayer | 塔投射物 |
| `drag_manager.gd` 塔放置 | `_tower_container` | EntityLayer | 新塔 |
| `drag_manager.gd` 预览节点 | `_tower_container.get_parent()` | EntityLayer | 拖拽预览 |
| `effects_manager.gd` 特效生成 | `tree.current_scene` | 保持不变（z_index=3） | 特效不参与 y_sort |
| `weapon_manager.gd` 投射物 | 需确认 | ProjectileLayer | 武器投射物 |

推荐方案：SceneFactory 提供 `init_containers()` 方法持有容器引用，各系统通过 SceneFactory 获取正确容器，而非依赖 `get_parent()`。

## 八、风险与注意事项

1. **碰撞层迁移**：所有 .tscn 文件的 collision_layer/collision_mask 值都需要修改，必须全部改完后整体测试，不能只改一半
2. **add_child 目标迁移**：至少 8 个调用点需要修改（见第七节），遗漏任何一个都会导致实体出现在错误的渲染层
3. **对象池兼容**：SceneFactory 的对象池 release 时节点从树中移除、re-add 时需添加到正确的容器。池化 acquire 流程需要包含 re-parenting 逻辑
4. **Hurtbox 信号适配**：`hit_taken(damage, knockback)` 与 `take_damage(amount, attacker)` 签名不同，tower.gd 需要包装方法
5. **重复伤害机制**：Hurtbox 新增 repeat_damage 模式，需确保与现有玩家受伤逻辑兼容（当前玩家可能已有独立的受伤计时器，需避免双重触发）
6. **Boss 继承链**：boss_base.gd 继承 enemy.gd，`_attack_tower()` 移除后自动传播到所有 Boss，需确认 Boss 没有覆写此方法
7. **碰撞尺寸需实际调试**：文档中的数值为初始推荐值，上线前需要通过实际游玩微调
