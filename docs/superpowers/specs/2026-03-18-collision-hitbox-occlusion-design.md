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

2. tower.gd 的 `_ready()` 中检测 Hurtbox 并连接 `hit_taken` 信号到 HealthComponent

3. enemy.gd 中移除直接调用塔 `health.take_damage()` 的逻辑，改为通过 Hitbox→Hurtbox 碰撞自动触发

### 敌人攻击塔的流程（改后）

```
Enemy Hitbox (layer 6, EnemyAttack)
  ↓ Area2D overlap
Tower Hurtbox (layer 7, DefenderHurt, mask 6)
  ↓ hit_taken signal
Tower HealthComponent.take_damage()
```

与敌人攻击玩家走完全相同的管线。

## 五、受影响的文件清单

### 配置文件
- `project.godot` — 添加碰撞层命名

### 场景文件（碰撞层 + 形状修改）
- `scenes/entities/player.tscn` — body Circle r=14, Hurtbox layer/mask/size
- `scenes/entities/enemies/enemy_normal.tscn` — body Circle r=14, Hitbox/Hurtbox layer/mask/size
- `scenes/entities/enemies/enemy_fast.tscn` — 同上
- `scenes/entities/enemies/enemy_tank.tscn` — 同上
- `scenes/entities/enemies/boss_brute.tscn` — body Circle r=22, Hitbox/Hurtbox layer/mask/size
- `scenes/entities/enemies/boss_summoner.tscn` — 同上
- `scenes/entities/enemies/boss_guardian.tscn` — 同上
- `scenes/entities/towers/tower_pea_shooter.tscn` — 添加 Hurtbox, layer/mask
- `scenes/entities/towers/tower_ice_flower.tscn` — 同上
- `scenes/entities/towers/tower_sunflower.tscn` — 同上
- `scenes/entities/projectiles/arrow.tscn` — Hitbox layer/mask/size
- `scenes/entities/projectiles/shuriken.tscn` — 同上
- `scenes/entities/projectiles/pea_bullet.tscn` — 同上
- `scenes/entities/projectiles/ice_bullet.tscn` — 同上
- `scenes/entities/coin.tscn` — layer/mask
- `scenes/entities/exp_orb.tscn` — layer/mask
- `scenes/levels/main.tscn` — 添加 EntityLayer (y_sort) 和 ProjectileLayer 容器

### 脚本文件
- `scripts/components/melee_attack_component.gd` — 动态 Hitbox 的 layer/mask 改为新值
- `scripts/components/target_finder_component.gd` — mask 确认为层2(Enemy)
- `scripts/entities/tower.gd` — 添加 Hurtbox 信号连接
- `scripts/entities/enemy.gd` — 移除直接调用塔 take_damage 的逻辑
- `scripts/core/scene_factory.gd` — 可能需要调整实体添加到的父容器
- `scripts/systems/effects_manager.gd` — 特效节点 z_index=3

## 六、风险与注意事项

1. **碰撞层迁移**：所有 .tscn 文件的 collision_layer/collision_mask 值都需要修改，必须全部改完后整体测试，不能只改一半
2. **Y-Sort 父节点变更**：Enemy/Tower 改为 EntityLayer 子节点后，EnemySpawner 和 DragManager（塔放置）需要把实体添加到 EntityLayer 而非 main 根节点
3. **对象池兼容**：SceneFactory 的对象池 release 时节点从树中移除、re-add 时需添加到正确的容器
4. **Hurtbox 组件复用**：塔的 Hurtbox 使用与玩家相同的 Hurtbox 组件脚本，信号接口一致
5. **碰撞尺寸需实际调试**：文档中的数值为初始推荐值，上线前需要通过实际游玩微调
