# 武器与植物塔扩充设计

## 概述

将武器从 3 种扩充至 10 种，植物塔从 3 种扩充至 15 种。设计方向为**角色分工型**：每种武器/塔填充一个明确的生态位，互不重叠。

## 设计约束

- 现有系统：配置驱动（.tres）、武器/塔均 1-5 级、SceneFactory 创建、UpgradeGenerator 混合池 3 选 1
- 武器系统：WeaponManager 自动瞄准最近敌人，所有武器自动开火
- 塔主题：全部植物主题，现有 3 塔重命名
- 武器类型：不限于枪械，可包含近战等
- 投射物：部分复用现有类型，部分新增

---

## 武器设计（10 种）

### 总览

| # | ID | 名称 | 定位 | 投射物类型 | 新增/复用 |
|---|-----|------|------|-----------|----------|
| 1 | rifle | 步枪 | 单体 DPS | bullet | 已有 |
| 2 | boomerang | 回旋镖 | 单体 DPS | boomerang | 已有 |
| 3 | laser | 激光枪 | 单体 DPS（穿透） | laser | 已有 |
| 4 | shotgun | 霰弹枪 | 散射爆发 | bullet（×3~5） | 复用 bullet |
| 5 | minigun | 加特林 | 持续输出 | bullet | 复用 bullet |
| 6 | rocket | 火箭筒 | AOE 重击 | rocket（新） | 新增 |
| 7 | flamethrower | 火焰喷射 | 短距持续 AOE | flame（新） | 新增 |
| 8 | lightning | 闪电链 | 链式多目标 | chain（新） | 新增 |
| 9 | ice_gun | 冰冻枪 | 减速控制 | bullet（+减速） | 复用 bullet |
| 10 | blade | 旋刃 | 近战全向 | melee（新） | 新增 |

### 武器类分发机制

当前 WeaponManager._create_weapon() 通过 `projectile_type` 字段决定创建哪个 Weapon 子类。但 shotgun/ice_gun 与 rifle 共享 `projectile_type: "bullet"` 却需要不同的 Weapon 类。

**解决方案**: WeaponData 新增 `weapon_type: String` 字段，用于 Weapon 子类分发。`projectile_type` 保留用于描述投射物类型。WeaponManager._create_weapon() 改为按 `weapon_type` 分发：

| weapon_type | Weapon 子类 | projectile_type |
|-------------|------------|-----------------|
| bullet | BulletWeapon | bullet |
| boomerang | BoomerangWeapon | boomerang |
| laser | LaserWeapon | laser |
| shotgun | ShotgunWeapon | bullet |
| minigun | BulletWeapon | bullet |
| rocket | RocketWeapon | rocket |
| flamethrower | FlamethrowerWeapon | flame |
| lightning | LightningWeapon | chain |
| ice_gun | IceGunWeapon | bullet |
| blade | BladeWeapon | melee |

> 注：ice_gun 需要独立的 IceGunWeapon（extends BulletWeapon），在 fire() 后为投射物设置减速标记。minigun 纯数值差异可复用 BulletWeapon。

### 详细机制

#### 4. shotgun（霰弹枪）
- **机制**: 一次发射 3~5 颗子弹，呈扇形散射（±15°~25°角度）
- **定位**: 近距离高爆发，远距离命中率低
- **投射物**: 复用 BulletProjectile，ShotgunWeapon.fire() 中循环创建多颗子弹并设置不同方向
- **Weapon 脚本**: 新增 ShotgunWeapon（extends Weapon），使用 WeaponData 已有的 `bullet_count` 字段控制散射数量

#### 5. minigun（加特林）
- **机制**: 极高射速（0.05s），低单发伤害，持续稳定输出
- **定位**: DPS 稳定输出型，适合持续战斗
- **投射物**: 复用 BulletProjectile
- **Weapon 脚本**: 复用 BulletWeapon，纯数值差异（.tres 配置即可）

#### 6. rocket（火箭筒）
- **机制**: 发射慢速火箭，命中敌人或到达最大距离时爆炸，对爆炸范围内所有敌人造成伤害
- **定位**: AOE 重击，适合密集敌群
- **新增投射物**: RocketProjectile
  - 直线飞行（速度约 300）
  - 碰撞敌人或超时后触发爆炸
  - 爆炸：创建临时 Area2D（CircleShape2D），对范围内所有敌人造成伤害
  - 爆炸半径：per_level 可配置（初始 80px）
- **Weapon 脚本**: 新增 RocketWeapon（extends Weapon）
- **WeaponData 扩展**: 新增 `explosion_radius_per_level: PackedFloat32Array`

#### 7. flamethrower（火焰喷射）
- **机制**: 维持单个持续性锥形火焰，朝目标方向喷射，对锥形范围内敌人持续造成伤害
- **定位**: 短距高 DPS，适合近身肉搏流
- **新增投射物**: FlameProjectile
  - 以玩家为原点，朝目标方向创建锥形 hitbox（扇形 Area2D）
  - **持续型模式**：FlamethrowerWeapon 维持一个 FlameProjectile 实例（非每次 fire 创建新的），每帧更新方向跟随目标
  - 每个物理帧对锥形范围内敌人造成 tick 伤害（伤害 = damage_per_level × delta）
  - 射程短（100px），扇形角度约 45°
  - 无目标时隐藏火焰，有目标时显示
- **Weapon 脚本**: 新增 FlamethrowerWeapon（extends Weapon）
  - 不使用 cooldown 机制，改为每帧 tick 持续伤害
  - 维护单个 FlameProjectile 引用，`_ready()` 时创建，方向每帧更新
- **WeaponData 扩展**: 新增 `flame_cone_angle: float`

#### 8. lightning（闪电链）
- **机制**: 瞬时命中目标，然后链式弹跳到附近 2~3 个敌人，每次弹跳伤害衰减 30%
- **定位**: 多目标清场，敌人密集时价值高
- **新增投射物**: ChainProjectile
  - 瞬时命中（类似 laser，无飞行时间）
  - 命中后搜索目标附近一定范围内的其他敌人
  - 链式跳跃，每跳衰减系数可配置
  - 视觉：Line2D 连接各目标，短暂闪烁后消失
- **Weapon 脚本**: 新增 LightningWeapon（extends Weapon）
- **WeaponData 扩展**: 新增 `chain_count: int`, `chain_decay: float`, `chain_range: float`

#### 9. ice_gun（冰冻枪）
- **机制**: 发射子弹，命中后对敌人附加减速效果（通过 SlowHandler）
- **定位**: 控制型武器，伤害中等但提供持续减速
- **投射物**: 复用 BulletProjectile，增加 on_hit 回调机制
  - BulletProjectile 新增可选属性 `slow_on_hit: float` 和 `slow_duration: float`（默认 0）
  - 命中敌人时，若 `slow_on_hit > 0`，调用 `enemy.slow_handler.apply_timed_slow()`
  - IceGunWeapon 在创建 BulletProjectile 后设置这两个属性
- **Weapon 脚本**: 新增 IceGunWeapon（extends BulletWeapon），override fire() 在创建子弹后注入减速属性
- **WeaponData 扩展**: 新增 `slow_on_hit: float`（0 = 无减速），`slow_duration: float`
- **SlowHandler 扩展**: 新增 `apply_timed_slow(percent, duration)` 方法
  - 现有 SlowHandler 使用计数器模式（apply_slow/remove_slow 配对），适合区域持续效果
  - `apply_timed_slow` 使用独立机制：创建一次性 Timer，到期后自动 remove
  - 减速叠加规则：取所有活跃减速效果中的最大值（不累加），避免与冰花塔冲突
  - 即：若冰花减速 30% + 冰冻枪减速 30%，实际减速 = 30%（取最大值），非 60%

#### 10. blade（旋刃）
- **机制**: 以玩家为中心的圆形挥砍，无投射物飞行，命中范围内所有敌人
- **定位**: 近战全向，范围小但伤害高，适合冲锋流
- **新增投射物**: MeleeProjectile
  - 以玩家当前位置为中心创建 CircleShape2D hitbox
  - 瞬时存在（~0.1s），命中范围内所有敌人
  - 视觉：圆形挥砍动画/弧线效果
- **Weapon 脚本**: 新增 BladeWeapon（extends Weapon）
  - fire() 忽略目标方向参数，在玩家位置创建 MeleeProjectile
  - **目标检测**: Weapon.tick() 中 target 为 null 时不调用 fire()。blade 射程 60px 足够检测近身敌人。若附近无敌人则不攻击（符合预期：近战武器需要靠近才有效）

### 新增投射物类型汇总

| 投射物 ID | 类名 | 行为 |
|-----------|------|------|
| rocket | RocketProjectile | 直线飞行 → 碰撞后范围爆炸 |
| flame | FlameProjectile | 锥形短距持续 hitbox |
| chain | ChainProjectile | 瞬时命中 → 链式跳跃 |
| melee | MeleeProjectile | 玩家中心圆形瞬时 hitbox |

### WeaponData 扩展字段

```
# 武器类分发（新增，所有武器必填）
@export var weapon_type: String = ""  # 用于 WeaponManager 分发 Weapon 子类

# 火箭筒
@export var explosion_radius_per_level: PackedFloat32Array
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

> 注：现有 3 个武器 .tres 需补充 `weapon_type` 字段：rifle="bullet", boomerang="boomerang", laser="laser"。

### 数值参考（1 级）

| 武器 | 伤害 | 射速(s) | 射程 | 特色 |
|------|------|---------|------|------|
| rifle | 10 | 0.1 | 300 | 均衡基础 |
| boomerang | 15 | 0.8 | 200 | 高单发 |
| laser | 8 | 0.15 | 400 | 穿透远程 |
| shotgun | 6×4 | 0.6 | 180 | 近距爆发 |
| minigun | 4 | 0.05 | 250 | 极速扫射 |
| rocket | 40 | 1.5 | 350 | AOE 重击，爆炸半径 80px |
| flamethrower | 3/tick | 0.05 | 100 | 持续灼烧，锥角 45° |
| lightning | 12 | 0.8 | 300 | 链式 3 跳（×0.7 衰减） |
| ice_gun | 8 | 0.2 | 280 | 减速 30%，持续 2s |
| blade | 20 | 0.4 | 60 | 近身全向 |

---

## 植物塔设计（15 种）

### 总览

| # | ID | 名称 | 定位 | 新增/改名 |
|---|-----|------|------|----------|
| 1 | pea_shooter | 豌豆射手 | 攻击 | 改名自 shooter |
| 2 | cactus | 仙人掌 | 攻击（狙击） | 新增 |
| 3 | rose | 玫瑰 | 攻击（爆发） | 新增 |
| 4 | mushroom | 毒蘑菇 | 攻击（AOE DOT） | 新增 |
| 5 | ice_flower | 冰花 | 控制（减速） | 改名自 slow |
| 6 | vine | 藤蔓 | 控制（定身） | 新增 |
| 7 | dandelion | 蒲公英 | 控制（击退） | 新增 |
| 8 | pitcher | 猪笼草 | 控制（抓取） | 新增 |
| 9 | stump | 树桩 | 防御（肉盾） | 改名自 wall |
| 10 | thorn | 荆棘 | 防御（反伤） | 新增 |
| 11 | oak | 橡树 | 防御（超肉+光环） | 新增 |
| 12 | sunflower | 向日葵 | 辅助（产金） | 新增 |
| 13 | mint | 薄荷 | 辅助（增益光环） | 新增 |
| 14 | heal_flower | 治愈花 | 辅助（治疗塔） | 新增 |
| 15 | bamboo | 爆竹竹 | 特殊（自爆） | 新增 |

### 详细机制

#### 1. pea_shooter（豌豆射手）— 改名自 shooter
- **机制**: 不变，向最近敌人射击子弹
- **变更**: ID `shooter` → `pea_shooter`，display_name `射手塔` → `豌豆射手`
- **脚本**: 复用 TowerShooter

#### 2. cactus（仙人掌）
- **机制**: 远程狙击，高伤害慢射速，优先攻击血量最高的敌人
- **定位**: 精英/Boss 杀手
- **脚本**: 新增 TowerSniper（extends Tower）
  - DetectArea 检测范围内敌人，按 current_hp 排序选最高
  - 创建 BulletProjectile（复用），高伤害低射速
- **TowerData 特有**: 使用通用字段即可（damage/fire_rate/attack_range per_level）

#### 3. rose（玫瑰）
- **机制**: 3 连发后长冷却，短距离高爆发
- **定位**: 近身高 DPS，弥补射程短的缺陷
- **脚本**: 新增 TowerBurst（extends Tower）
  - 状态机：IDLE → BURST（连发 3 次，间隔 0.15s）→ COOLDOWN（3s）→ IDLE
  - 创建 BulletProjectile（复用）
- **TowerData 扩展**: 新增 `burst_count: int`, `burst_interval: float`

#### 4. mushroom（毒蘑菇）
- **机制**: 周期性释放孢子云，对范围内敌人持续造成毒伤害
- **定位**: AOE 持续消耗，适合路径密集处
- **脚本**: 新增 TowerAoe（extends Tower）
  - SporeArea（Area2D）检测范围内敌人
  - 每秒对区域内所有敌人造成 tick 伤害
  - 视觉：绿色半透明圈 + 粒子效果
- **TowerData 特有**: `damage_per_level` 表示每 tick 伤害，`attack_range_per_level` 表示孢子范围

#### 5. ice_flower（冰花）— 改名自 slow
- **机制**: 不变，范围减速光环
- **变更**: ID `slow` → `ice_flower`，display_name `减速塔` → `冰花`
- **脚本**: 复用 TowerSlow

#### 6. vine（藤蔓）
- **机制**: 缠绕经过的敌人，定身 2~3 秒，有冷却时间
- **定位**: 路径阻断，配合攻击塔使用
- **脚本**: 新增 TowerTrap（extends Tower）
  - TrapArea（Area2D）检测进入的敌人
  - 触发定身：设置敌人速度为 0，持续 duration 后恢复
  - 触发后进入冷却（8s），冷却中不触发
- **TowerData 扩展**: 新增 `trap_duration_per_level: PackedFloat32Array`, `trap_cooldown: float`
- **Enemy 扩展**: 需要 `apply_root(duration)` / `remove_root()` 方法（类似 slow 但完全停止）

#### 7. dandelion（蒲公英）
- **机制**: 周期性将范围内敌人推回一段距离
- **定位**: 延缓推进，配合远程塔争取时间
- **脚本**: 新增 TowerKnockback（extends Tower）
  - PushArea（Area2D）检测范围内敌人
  - 每隔 N 秒对区域内所有敌人施加击退力（远离塔方向）
  - 复用 KnockbackHandler
- **TowerData 扩展**: 新增 `knockback_force_per_level: PackedFloat32Array`, `knockback_interval: float`

#### 8. pitcher（猪笼草）
- **机制**: 吞噬单个敌人，消化期间持续造成伤害，消化完或敌人死亡后可抓取下一个
- **定位**: 单体高伤害控制，对精英怪有效
- **脚本**: 新增 TowerGrab（extends Tower）
  - 状态机：IDLE → GRAB（抓取动画）→ DIGEST（持续伤害）→ IDLE
  - 被抓敌人不可移动、不可被其他攻击命中（从场景中隐藏）
  - 消化时间和伤害 per_level 可配
  - Boss 免疫抓取（通过 `EnemyData` 新增 `is_boss: bool` 字段判断，Boss 类型 .tres 设为 true）
- **TowerData 扩展**: 新增 `grab_dps_per_level: PackedFloat32Array`, `digest_duration_per_level: PackedFloat32Array`

#### 9. stump（树桩）— 改名自 wall
- **机制**: 不变，高 HP 纯肉盾
- **变更**: ID `wall` → `stump`，display_name `墙塔` → `树桩`
- **脚本**: 复用 Tower 基类

#### 10. thorn（荆棘）
- **机制**: 敌人攻击自身时反弹一定比例伤害
- **定位**: 被动防御，放在敌人必经之路
- **脚本**: 新增 TowerThorn（extends Tower）
  - 监听 HealthComponent.damaged 信号
  - 受到伤害时，对攻击者造成 `damage * reflect_ratio` 伤害
- **攻击者追踪方案**:
  - 当前 damaged 信号签名：`damaged(amount: float, current_hp: float)`
  - 扩展为：`damaged(amount: float, current_hp: float, attacker: Node2D)`，attacker 可为 null
  - 伤害链路修改：`Hurtbox.hit_taken` 信号需传递 Hitbox 的 owner → `HealthComponent.take_damage(amount, attacker)` → `damaged.emit(amount, current_hp, attacker)`
  - 敌人接触伤害路径：enemy 碰撞 tower 时，enemy 作为 attacker 传入
  - 所有现有 damaged 信号连接需要适配新签名（增加 attacker 参数）
- **TowerData 扩展**: 新增 `reflect_ratio_per_level: PackedFloat32Array`

#### 11. oak（橡树）
- **机制**: 超高 HP + 给范围内友方塔提供减伤光环（受到伤害降低 15%~25%）
- **定位**: 塔群核心防护
- **脚本**: 新增 TowerAura（extends Tower）
  - AuraArea（Area2D）检测范围内友方塔（towers 组）
  - 对范围内塔施加减伤 buff
  - 塔离开范围时移除 buff
- **TowerData 扩展**: 新增 `aura_reduction_per_level: PackedFloat32Array`
- **HealthComponent 扩展**: 新增 `damage_reduction: float` 字段，受伤时应用

#### 12. sunflower（向日葵）
- **机制**: 每隔 N 秒在自身位置生成可拾取金币
- **定位**: 经济加速，早期投资后期收益
- **脚本**: 新增 TowerGenerator（extends Tower）
  - 定时器每 N 秒调用 SceneFactory.create_coin() 在塔附近生成金币
  - 金币数量/间隔 per_level 可配
- **TowerData 扩展**: 新增 `generate_amount_per_level: PackedFloat32Array`, `generate_interval_per_level: PackedFloat32Array`

#### 13. mint（薄荷）
- **机制**: 增益光环，提升范围内友方塔的攻击力和射速
- **定位**: 核心辅助，放在攻击塔群中间
- **脚本**: 新增 TowerBuff（extends Tower）
  - BuffArea（Area2D）检测范围内友方塔
  - 对攻击型塔施加攻击力/射速加成
  - 塔离开范围时移除加成
- **TowerData 扩展**: 新增 `buff_damage_mult_per_level: PackedFloat32Array`, `buff_speed_mult_per_level: PackedFloat32Array`
- **Tower 基类扩展**: 新增 `damage_mult: float = 1.0`, `speed_mult: float = 1.0`，攻击型塔计算伤害/射速时乘以该值

#### 14. heal_flower（治愈花）
- **机制**: 周期性治疗范围内 HP 最低的友方塔
- **定位**: 塔群续航，延长防线寿命
- **脚本**: 新增 TowerHeal（extends Tower）
  - HealArea（Area2D）检测范围内友方塔
  - 每隔 N 秒选择 HP 比例最低的塔，恢复一定 HP
- **TowerData 扩展**: 新增 `heal_amount_per_level: PackedFloat32Array`, `heal_interval_per_level: PackedFloat32Array`
- 注：`HealthComponent.heal()` 已存在，无需新增

#### 15. bamboo（爆竹竹）
- **机制**: 放置后蓄力 N 秒，然后范围爆炸造成高额 AOE 伤害，爆炸后自毁
- **定位**: 一次性高伤害清场，低放置费但需要重新放置
- **脚本**: 新增 TowerBomb（extends Tower）
  - 状态机：CHARGING（蓄力，渐变颜色提示）→ EXPLODE（范围伤害）→ queue_free()
  - 爆炸对范围内所有敌人造成伤害
  - 蓄力时间和爆炸伤害/范围 per_level 可配
- **TowerData 扩展**: 新增 `charge_time: float`, `explosion_damage_per_level: PackedFloat32Array`, `explosion_range_per_level: PackedFloat32Array`

### TowerData 扩展字段汇总

```
# 玫瑰（连发）
@export var burst_count: int = 3
@export var burst_interval: float = 0.15

# 藤蔓（定身）
@export var trap_duration_per_level: PackedFloat32Array
@export var trap_cooldown: float = 8.0

# 蒲公英（击退）
@export var knockback_force_per_level: PackedFloat32Array
@export var knockback_interval: float = 5.0

# 猪笼草（抓取）
@export var grab_dps_per_level: PackedFloat32Array
@export var digest_duration_per_level: PackedFloat32Array

# 荆棘（反伤）
@export var reflect_ratio_per_level: PackedFloat32Array

# 橡树（减伤光环）
@export var aura_reduction_per_level: PackedFloat32Array

# 向日葵（产金）
@export var generate_amount_per_level: PackedFloat32Array
@export var generate_interval_per_level: PackedFloat32Array

# 薄荷（增益光环）
@export var buff_damage_mult_per_level: PackedFloat32Array
@export var buff_speed_mult_per_level: PackedFloat32Array

# 治愈花（治疗）
@export var heal_amount_per_level: PackedFloat32Array
@export var heal_interval_per_level: PackedFloat32Array

# 爆竹竹（自爆）
@export var charge_time: float = 15.0
@export var explosion_damage_per_level: PackedFloat32Array
@export var explosion_range_per_level: PackedFloat32Array
```

### 共享组件扩展

#### HealthComponent
- 新增 `damage_reduction: float = 0.0`（橡树光环用），`take_damage()` 中应用 `amount *= (1.0 - damage_reduction)`
- `heal(amount)` 方法已存在，无需新增
- damaged 信号扩展：`damaged(amount, current_hp)` → `damaged(amount, current_hp, attacker: Node2D)`（荆棘反伤用）
- `take_damage()` 签名扩展：`take_damage(amount: float, attacker: Node2D = null)`

#### Tower 基类
- 新增 `damage_mult: float = 1.0`（薄荷增益用）
- 新增 `speed_mult: float = 1.0`（薄荷增益用）

#### Enemy
- 新增 `apply_root(duration: float)` / `remove_root()` 方法（藤蔓定身用）
- 新增 `is_rooted: bool` 标志

### 数值参考（1 级）

| 塔 | HP | 伤害 | 射速/间隔 | 范围 | 放置费 | 特色 |
|----|-----|------|----------|------|--------|------|
| pea_shooter | 80 | 15 | 1.0s | 300 | 15 | 均衡射手 |
| cactus | 60 | 35 | 2.5s | 450 | 20 | 远程重击，优先高HP |
| rose | 70 | 10×3 | 3.0s(含连发) | 150 | 18 | 近距 3 连发 |
| mushroom | 90 | 5/tick | 持续 | 180 | 22 | AOE 毒圈 |
| ice_flower | 70 | 0 | — | 200 | 12 | 减速 30% |
| vine | 100 | 0 | 8s 冷却 | 120 | 16 | 定身 2.5s |
| dandelion | 80 | 0 | 5s | 200 | 14 | 击退 100px |
| pitcher | 120 | 8/s 消化 | — | 100 | 25 | 吞噬单体 |
| stump | 300 | 0 | — | 0 | 10 | 纯肉盾 |
| thorn | 150 | 反伤 25% | 被动 | 0 | 18 | 接触反伤 |
| oak | 400 | 0 | — | 150 | 28 | 超肉 + 减伤 15% |
| sunflower | 50 | 0 | 10s | 0 | 30 | 产出 5 金币 |
| mint | 60 | 0 | — | 180 | 25 | 攻击 +15% |
| heal_flower | 60 | 0 | 3s | 200 | 22 | 治疗塔 20HP |
| bamboo | 100 | 150(爆炸) | 15s 蓄力 | 250 | 8 | 自爆一次性 |

---

## 系统变更汇总

### SceneFactory 注册策略

塔场景数量从 3 → 15，继续使用显式字典注册（preload）。原因：preload 在编译时加载，运行时无 IO 开销，且 15 个条目仍可维护。

```gdscript
# _tower_scenes 字典扩展为 15 项
var _tower_scenes: Dictionary = {
    Enums.TowerId.PEA_SHOOTER: preload("res://scenes/entities/towers/tower_pea_shooter.tscn"),
    Enums.TowerId.CACTUS: preload("res://scenes/entities/towers/tower_cactus.tscn"),
    # ... 共 15 项
}
```

投射物新增 4 个专用工厂方法：
- `create_rocket_projectile() -> RocketProjectile`
- `create_flame_projectile() -> FlameProjectile`
- `create_chain_projectile() -> ChainProjectile`
- `create_melee_projectile() -> MeleeProjectile`

### 需要修改的现有文件

| 文件 | 变更 |
|------|------|
| `scripts/core/enums.gd` | WeaponId 新增 7 个常量，TowerId 改名 3 个 + 新增 12 个，ProjectileId 新增 4 个 |
| `scripts/resources/weapon_data.gd` | 新增 weapon_type, explosion_radius_per_level, flame_cone_angle, chain_count/decay/range, slow_on_hit/duration |
| `scripts/resources/tower_data.gd` | 新增多个 per_level 数组和配置字段 |
| `scripts/resources/enemy_data.gd` | 新增 `is_boss: bool`（猪笼草免疫判断） |
| `scripts/core/scene_factory.gd` | _tower_scenes 15 项 + 4 个新投射物工厂方法 |
| `scripts/entities/weapons/weapon_manager.gd` | _create_weapon() 改为按 `weapon_type` 分发，新增 7 种映射 |
| `scripts/components/health_component.gd` | 新增 damage_reduction, take_damage 增加 attacker 参数, damaged 信号增加 attacker |
| `scripts/components/slow_handler.gd` | 新增 apply_timed_slow()，减速叠加改为取最大值 |
| `scripts/entities/towers/tower.gd` | 新增 damage_mult, speed_mult |
| `scripts/entities/enemies/enemy.gd` | 新增 apply_root/remove_root, is_rooted |
| `scripts/entities/projectiles/bullet_projectile.gd` | 新增 slow_on_hit/slow_duration 属性，命中时检查并应用减速 |
| `scripts/core/game_config.gd` | SPRITES.towers 字典 key 改名 |

### 需要新增的文件

#### 武器脚本（6 个新脚本，minigun 复用 BulletWeapon）
- `scripts/entities/weapons/shotgun_weapon.gd` (extends Weapon)
- `scripts/entities/weapons/rocket_weapon.gd` (extends Weapon)
- `scripts/entities/weapons/flamethrower_weapon.gd` (extends Weapon)
- `scripts/entities/weapons/lightning_weapon.gd` (extends Weapon)
- `scripts/entities/weapons/ice_gun_weapon.gd` (extends BulletWeapon)
- `scripts/entities/weapons/blade_weapon.gd` (extends Weapon)

#### 投射物脚本 + 场景（4 组）
- `scripts/entities/projectiles/rocket_projectile.gd` + `scenes/entities/projectiles/rocket_projectile.tscn`
- `scripts/entities/projectiles/flame_projectile.gd` + `scenes/entities/projectiles/flame_projectile.tscn`
- `scripts/entities/projectiles/chain_projectile.gd` + `scenes/entities/projectiles/chain_projectile.tscn`
- `scripts/entities/projectiles/melee_projectile.gd` + `scenes/entities/projectiles/melee_projectile.tscn`

#### 塔脚本 + 场景（12 组，3 个改名复用）
- `scripts/entities/towers/tower_sniper.gd` + `scenes/entities/towers/tower_cactus.tscn`
- `scripts/entities/towers/tower_burst.gd` + `scenes/entities/towers/tower_rose.tscn`
- `scripts/entities/towers/tower_aoe.gd` + `scenes/entities/towers/tower_mushroom.tscn`
- `scripts/entities/towers/tower_trap.gd` + `scenes/entities/towers/tower_vine.tscn`
- `scripts/entities/towers/tower_knockback.gd` + `scenes/entities/towers/tower_dandelion.tscn`
- `scripts/entities/towers/tower_grab.gd` + `scenes/entities/towers/tower_pitcher.tscn`
- `scripts/entities/towers/tower_thorn.gd` + `scenes/entities/towers/tower_thorn.tscn`
- `scripts/entities/towers/tower_aura.gd` + `scenes/entities/towers/tower_oak.tscn`
- `scripts/entities/towers/tower_generator.gd` + `scenes/entities/towers/tower_sunflower.tscn`
- `scripts/entities/towers/tower_buff.gd` + `scenes/entities/towers/tower_mint.tscn`
- `scripts/entities/towers/tower_heal.gd` + `scenes/entities/towers/tower_heal_flower.tscn`
- `scripts/entities/towers/tower_bomb.gd` + `scenes/entities/towers/tower_bamboo.tscn`

#### 资源文件（.tres）
- `resources/weapons/` — 7 个新武器 .tres
- `resources/towers/` — 12 个新塔 .tres + 3 个改名

### ID 改名迁移

| 旧 ID | 新 ID |
|--------|--------|
| shooter | pea_shooter |
| slow | ice_flower |
| wall | stump |

#### 完整影响清单

**枚举常量**:
- `scripts/core/enums.gd` — TowerId.SHOOTER → PEA_SHOOTER, WALL → STUMP, SLOW → ICE_FLOWER

**Resource 文件**（重命名 + 内部 id 字段更新）:
- `resources/towers/shooter.tres` → `pea_shooter.tres`
- `resources/towers/slow.tres` → `ice_flower.tres`
- `resources/towers/wall.tres` → `stump.tres`

**场景文件**（重命名）:
- `scenes/entities/towers/tower_shooter.tscn` → `tower_pea_shooter.tscn`
- `scenes/entities/towers/tower_slow.tscn` → `tower_ice_flower.tscn`
- `scenes/entities/towers/tower_wall.tscn` → `tower_stump.tscn`

**脚本硬编码 ID**:
- `scripts/entities/towers/tower_shooter.gd:12` — `tower_type = Enums.TowerId.SHOOTER`
- `scripts/entities/towers/tower_slow.gd:10` — `tower_type = Enums.TowerId.SLOW`
- `scripts/entities/towers/tower.gd:6` — 默认值 `Enums.TowerId.WALL`

**SceneFactory**:
- `scripts/core/scene_factory.gd` — _tower_scenes 字典 key 更新

**GameConfig**:
- `scripts/core/game_config.gd` — SPRITES.towers 字典 key 更新

**角色配置**（5 个 .tres）:
- `resources/characters/dora.tres` — default_tower: "shooter" → "pea_shooter"
- `resources/characters/gorg.tres` — default_tower: "wall" → "stump"
- `resources/characters/kaze.tres` — default_tower: "slow" → "ice_flower"
- `resources/characters/nemo.tres` — default_tower: "shooter" → "pea_shooter"
- `resources/characters/merlin.tres` — default_tower: "shooter" → "pea_shooter"

**测试文件**:
- `tests/unit/test_resource_loading.gd` — SHOOTER/WALL/SLOW 引用
- `tests/unit/test_scene_factory.gd` — SHOOTER/WALL/SLOW 引用
- `tests/unit/test_placement_panel.gd` — "shooter"/"wall"/"slow" 字符串
- `tests/unit/test_placement_grid_rules.gd` — "shooter"/"wall"/"slow" 字符串
- `tests/unit/test_entity_scene_dimensions.gd` — SHOOTER/WALL/SLOW 引用
- `tests/unit/test_event_bus.gd` — SHOOTER/WALL 引用
- `tests/unit/test_tower_level.gd` — "shooter"/"wall"/"slow" 引用
- `tests/unit/test_upgrade_generator.gd` — "shooter"/"wall"/"slow" 引用
- `tests/integration/test_combat_flow.gd` — SHOOTER/WALL 引用
- `tests/integration/test_tower_placement.gd` — SHOOTER/WALL/SLOW 引用

**Godot UID**: 场景文件重命名后 .uid 引用可能需要更新（Godot 编辑器打开后自动处理）

### 新塔 Area2D 碰撞层分配

新塔的功能 Area2D（DetectArea, SlowArea, SporeArea 等）统一使用：
- collision_layer = 0（不被其他系统检测）
- collision_mask = 2（检测 Enemy body）

光环类塔（oak, mint, heal_flower）的 AuraArea/BuffArea/HealArea：
- collision_layer = 0
- collision_mask = 8（检测 Tower body）

---

## 升级系统兼容性

UpgradeGenerator 无需修改核心逻辑——它已从 `GameConfig.weapons` 和 `GameConfig.towers` 动态构建池。新增的武器/塔只要有正确的 .tres 和 id，会自动进入升级池。

唯一需要关注的是：15 塔 + 10 武器 = 25 种选项，池子较大。当前加权算法（新物品 ×1.2，少数类型 ×1.5）可能需要微调以确保升级体验。但这属于数值调优，不影响系统架构。
