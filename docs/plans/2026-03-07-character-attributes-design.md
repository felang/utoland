# 角色属性模板设计文档

**日期**: 2026-03-07
**状态**: 已确认，待实施
**分支**: feature/placement-ux → 新建 feature/character-attributes

---

## 背景

当前 `CharacterData` 只有 7 个属性，三个角色差异感薄弱，专属机制缺失。本次重构目标：

1. 扩展属性维度（经济、防御、暴击、弹道）
2. 为每个角色加入专属被动机制
3. 为未来商店升级和角色解锁做好属性底座

---

## 方案选择

采用**方案三：属性扩展 + 被动 ID 引用**。

- `CharacterData` 扩展基础属性，新增 `passive_id: String`
- 被动逻辑在 Player 中通过 `match passive_id` 分发
- 简单、与现有架构一致，未来可平滑升级为数据驱动被动系统

---

## 一、CharacterData 属性模板

### 保留现有属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `id` | String | 角色 ID |
| `display_name` | String | 显示名称 |
| `description` | String | 描述 |
| `max_hp` | float | 最大血量 |
| `speed` | float | 基础移动速度 |
| `damage_mult` | float | 伤害倍率 |
| `attack_speed_mult` | float | 攻速倍率 |
| `move_speed_mult` | float | 移动速度倍率 |
| `hp_regen` | float | 每次回复血量 |
| `default_weapon` | String | 默认武器 ID |

### 新增属性

**A — 经济属性**

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `coin_bonus_mult` | float | 1.0 | 击杀金币倍率（1.2 = 多 20% 金币） |
| `shop_discount` | float | 0.0 | 商店折扣（0.1 = 打九折） |

**C — 防御属性**

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `damage_reduction` | float | 0.0 | 固定伤害减免比例（0.2 = 减免 20%，上限 0.75） |
| `invincible_duration_mult` | float | 1.0 | 受击无敌时间倍率 |

**D — 暴击系统**

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `crit_chance` | float | 0.0 | 暴击率（0.0～1.0） |
| `crit_damage_mult` | float | 1.5 | 暴击伤害倍率 |

**E — 弹道属性**

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `weapon_range_mult` | float | 1.0 | 武器射程倍率 |
| `projectile_speed_mult` | float | 1.0 | 投射物速度倍率 |
| `projectile_size_mult` | float | 1.0 | 弹体碰撞体大小倍率 |

**被动系统**

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `passive_id` | String | `""` | 专属被动 ID，Player 中 match 分发 |

---

## 二、三角色具体配置

### 战士 (Warrior) — 「铁壁」

**定位**：前线抗压，稳定输出，容错率高

| 属性 | 数值 |
|------|------|
| `max_hp` | 150 |
| `damage_reduction` | 0.15 |
| `invincible_duration_mult` | 1.3 |
| `damage_mult` | 1.2 |
| `move_speed_mult` | 0.9 |
| `passive_id` | `"warrior_retaliation"` |

**专属被动 `warrior_retaliation`（条件触发）**
> 每次受到伤害后，1 秒内伤害减免额外 +30%（护盾叠加在 `damage_reduction` 之上）

---

### 游侠 (Ranger) — 「疾风」

**定位**：走位型输出，边跑边打，高上限高风险

| 属性 | 数值 |
|------|------|
| `max_hp` | 80 |
| `crit_chance` | 0.15 |
| `crit_damage_mult` | 2.0 |
| `weapon_range_mult` | 1.2 |
| `projectile_speed_mult` | 1.3 |
| `move_speed_mult` | 1.25 |
| `passive_id` | `"ranger_momentum"` |

**专属被动 `ranger_momentum`（纯被动，始终生效）**
> 移动时攻速 +35%，静止时无加成

---

### 坦克 (Tank) — 「末日」

**定位**：濒死爆发，以血换伤害，惊险刺激

| 属性 | 数值 |
|------|------|
| `max_hp` | 200 |
| `damage_reduction` | 0.2 |
| `hp_regen` | 2.0 |
| `damage_mult` | 0.85 |
| `move_speed_mult` | 0.75 |
| `coin_bonus_mult` | 1.15 |
| `passive_id` | `"tank_juggernaut"` |

**专属被动 `tank_juggernaut`（条件触发）**
> HP 低于 50% 时，伤害 +40%；低于 25% 时，额外再 +20%（共 +60%）

---

## 三、系统集成

### Enums.Stat 扩展

```gdscript
class Stat:
    # 现有（保留）
    const MAX_HP = "max_hp"
    const HP_MULT = "hp_mult"
    const HP_REGEN = "hp_regen"
    const DAMAGE_MULT = "damage_mult"
    const ATTACK_SPEED_MULT = "attack_speed_mult"
    const MOVE_SPEED_MULT = "move_speed_mult"
    const TOWER_MULT = "tower_mult"
    # 新增
    const CRIT_CHANCE = "crit_chance"
    const CRIT_DAMAGE_MULT = "crit_damage_mult"
    const DAMAGE_REDUCTION = "damage_reduction"
    const COIN_BONUS_MULT = "coin_bonus_mult"
    const WEAPON_RANGE_MULT = "weapon_range_mult"
    const PROJECTILE_SPEED_MULT = "projectile_speed_mult"
    const PROJECTILE_SIZE_MULT = "projectile_size_mult"
```

### 被动触发点

| 被动 ID | 触发时机 | 实现位置 |
|---------|---------|---------|
| `warrior_retaliation` | 受伤时 | `Player._on_hurtbox_hit()` |
| `ranger_momentum` | 每帧检测 velocity | `Player._physics_process()` |
| `tank_juggernaut` | 每帧检测 HP 比例 | `Player._process()` |

被动逻辑统一在 `Player._apply_passive_effect()` 私有方法中用 `match` 分发。

### 数值计算流水线

```
角色基础值（CharacterData）
    ↓ passive_id 提供的动态加成
    ↓ 商店被动升级（player_stats 叠加）
    = 最终生效数值
```

暴击计算在 Weapon 的 `fire()` 中：
```gdscript
if randf() < final_crit_chance:
    damage *= final_crit_damage_mult
```

---

## 四、暂不实施

- 塔防属性（`tower_mult` 扩展）— 等塔系统属性完善后再设计
- 角色成长/解锁系统 — 后续迭代
- 被动数据驱动化（`PassiveAbilityData` Resource）— 角色数量增加后再升级
