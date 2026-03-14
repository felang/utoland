# 武器模板重新设计

## 概述

重新设计 WeaponData Resource 模板，新增描述/图标/稀有度字段，并使用 `@export_group` 整理字段分组。

## 新增字段

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `description` | String | `""` | 武器描述文字（升级弹窗展示） |
| `icon_path` | String | `""` | 武器图标路径（本期仅添加字段，暂不在 UI 中使用，为后续收集界面预留） |
| `rarity` | int | `0` | 稀有度：0=普通(common), 1=稀有(rare), 2=史诗(epic) |

## 字段分组

使用 Godot 4 的 `@export_group` 在编辑器 Inspector 中按类型折叠显示。完整字段列表：

### 基础信息
| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `id` | String | `""` | 武器唯一标识 |
| `display_name` | String | `""` | 中文显示名 |
| `description` | String | `""` | 武器描述文字（新增） |
| `icon_path` | String | `""` | 武器图标路径（新增，本期仅数据） |
| `rarity` | int | `0` | 稀有度等级（新增） |
| `weapon_type` | String | `""` | 武器类分发类型（bullet/boomerang/laser/shotgun/minigun/ice_gun/rocket/lightning/blade/flamethrower） |
| `projectile_type` | String | `"bullet"` | 投射物类型（bullet/boomerang/laser/rocket/chain/flame/melee） |

### 等级系统
| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `max_level` | int | `5` | 最大等级 |
| `damage_per_level` | PackedFloat32Array | `[]` | 每级伤害 |
| `fire_rate_per_level` | PackedFloat32Array | `[]` | 每级射速（秒/发） |
| `weapon_range_per_level` | PackedFloat32Array | `[]` | 每级射程 |
| `milestones` | Dictionary | `{}` | 里程碑效果 |

### 通用属性

> 注：`bullet_speed` 原属"子弹专有"分组，但实际被子弹和火箭共用，故重新归入通用属性。

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `knockback_force` | float | `40.0` | 击退力度 |
| `bullet_speed` | float | `300.0` | 弹速（子弹/火箭共用） |

### 子弹专有
| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `bullet_count` | int | `1` | 弹丸数量（霰弹枪使用） |

### 回旋镖专有
| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `boomerang_speed` | float | `175.0` | 回旋镖速度 |
| `outbound_distance` | float | `100.0` | 飞出距离 |
| `return_speed_mult` | float | `1.3` | 返回速度倍率 |
| `boomerang_max_lifetime` | float | `5.0` | 最大存活时间 |

### 激光专有
| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `beam_range` | float | `200.0` | 光束射程 |
| `beam_width` | float | `2.0` | 光束宽度 |
| `beam_duration` | float | `0.08` | 光束持续时间 |

### 火箭专有
| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `explosion_radius_per_level` | PackedFloat32Array | `[]` | 每级爆炸半径 |

### 火焰专有
| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `flame_cone_angle` | float | `45.0` | 火焰锥角度 |

### 闪电专有
| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `chain_count` | int | `3` | 链式弹跳次数 |
| `chain_decay` | float | `0.7` | 弹跳伤害衰减 |
| `chain_range` | float | `150.0` | 弹跳范围 |

### 冰冻专有
| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `slow_on_hit` | float | `0.0` | 命中减速百分比（0-1） |
| `slow_duration` | float | `2.0` | 减速持续时间 |

> 注：blade（刀刃）仅使用基础信息 + 等级系统 + 通用属性中的字段，无需专有分组。

## 稀有度系统

### Enums 常量

在 `enums.gd` 中新增 `WeaponRarity` 常量类：

```gdscript
class WeaponRarity:
    const COMMON = 0    # 普通，升级弹窗权重 1.0
    const RARE = 1      # 稀有，升级弹窗权重 0.6
    const EPIC = 2      # 史诗，升级弹窗权重 0.3
```

### 权重映射与集成

`upgrade_generator.gd` 中新增稀有度到权重的映射常量：

```gdscript
const RARITY_WEIGHTS: Dictionary = {
    Enums.WeaponRarity.COMMON: 1.0,
    Enums.WeaponRarity.RARE: 0.6,
    Enums.WeaponRarity.EPIC: 0.3,
}
```

**具体集成点：** 在 `_build_pool()` 方法中（第 52、58 行），武器条目的 `"_weight"` 值从当前硬编码的 `1.0` 改为 `RARITY_WEIGHTS.get(wd.rarity, 1.0)`：

```gdscript
# 武器池（_build_pool 中）
if current_level == 0:
    pool.append({
        "type": "weapon", "id": weapon_id,
        "target_level": 1, "is_new": true, "current_level": 0,
        "_weight": RARITY_WEIGHTS.get(wd.rarity, 1.0)
    })
elif current_level < wd.max_level:
    pool.append({
        "type": "weapon", "id": weapon_id,
        "target_level": current_level + 1, "is_new": false,
        "current_level": current_level,
        "_weight": RARITY_WEIGHTS.get(wd.rarity, 1.0)
    })
```

**现有乘数保持不变：** `_apply_weights()` 中的 1.5x 武器/塔平衡乘数和 1.2x 新物品加成照常叠加在 rarity 权重之上。塔的权重仍为固定 `1.0`（塔稀有度不在本期范围内）。

## 升级卡片展示更新

`upgrade_card_builder.gd` 中武器卡片新增 description 展示：

- 在武器名称下方、属性数值上方添加一行 `description` 文字（灰色小字，`UIConstants.FONT_SIZE_SMALL`）
- 如果 `description` 为空则不显示
- 根据 rarity 调整卡片类型边框颜色：
  - COMMON (0): 保持当前蓝色 `#4fc3f7`
  - RARE (1): 紫色 `#ab47bc`
  - EPIC (2): 橙色 `#ffa726`

## 影响范围

### 需要修改的文件
1. `scripts/resources/weapon_data.gd` — 新增 description/icon_path/rarity 字段，添加 @export_group 分组
2. `resources/weapons/*.tres`（10 个文件）— 添加新字段值，为每把武器设定 rarity 和 description
3. `scripts/core/enums.gd` — 新增 `WeaponRarity` 常量类
4. `scripts/systems/upgrade_generator.gd` — 在 `_build_pool()` 中用 rarity 映射权重替代固定 `1.0`
5. `scripts/ui/upgrade_card_builder.gd` — 武器卡片添加 description 文字、rarity 边框颜色

### 不需要修改的文件
- `scripts/core/game_config.gd` — 自动从 .tres 读取新字段
- `scripts/entities/weapons/weapon.gd` 及所有子类 — 不使用新增字段
- `scripts/entities/weapons/weapon_manager.gd` — 不使用新增字段
- `scripts/core/game_data.gd` — 不涉及武器模板字段
- `scripts/resources/tower_data.gd` — 塔稀有度不在本期范围内

## 10 把武器稀有度分配（建议）

| 武器 | rarity | 理由 |
|---|---|---|
| rifle | 0 (普通) | 基础武器，所有角色默认 |
| shotgun | 0 (普通) | 常见近战武器 |
| minigun | 0 (普通) | 常见连射武器 |
| boomerang | 0 (普通) | 常见远程武器 |
| ice_gun | 1 (稀有) | 带减速效果 |
| laser | 1 (稀有) | 持续伤害特殊机制 |
| blade | 1 (稀有) | 近战特殊机制 |
| rocket | 1 (稀有) | AOE 伤害 |
| lightning | 2 (史诗) | 链式弹跳高级机制 |
| flamethrower | 2 (史诗) | 持续锥形高级机制 |

> 注：以上为建议值，可在实现阶段调整。
