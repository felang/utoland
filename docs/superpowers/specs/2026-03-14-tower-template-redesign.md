# 植物塔模板重新设计

## 背景

武器模板已完成重新整理（`@export_group` 分组、新增 description/icon_path/rarity），角色模板也已重新设计。现在需要对植物塔模板做同样的整理，保持一致性。

## 设计目标

1. TowerData 资源类用 `@export_group` 分组，替代注释分隔
2. 新增 `description`、`icon_path`、`rarity` 字段
3. 新增独立的 `TowerRarity` 枚举（COMMON/RARE/EPIC）
4. 升级生成器使用塔稀有度权重替代硬编码 1.0
5. 升级卡片按稀有度着色 + 显示描述

## 详细设计

### 1. TowerRarity 枚举

在 `scripts/core/enums.gd` 新增：

```gdscript
class TowerRarity:
    const COMMON = 0
    const RARE = 1
    const EPIC = 2
```

独立于 `WeaponRarity`，便于未来塔和武器稀有度分别调整。

### 2. TowerData 资源类改造

文件：`scripts/resources/tower_data.gd`

**新增字段：**
- `description: String` — 功能+风味结合的描述文本
- `icon_path: String` — 图标路径（预留）
- `rarity: int` — 稀有度，对应 TowerRarity 枚举值

**分组结构（@export_group）：**

```
基础信息: id, display_name, description, icon_path, rarity
等级系统: max_level, hp/damage/fire_rate/attack_range/slow_ratio_per_level, shop_price/place_cost_per_level, milestones
玫瑰专有: burst_count, burst_interval
藤蔓专有: trap_duration_per_level, trap_cooldown
蒲公英专有: knockback_force_per_level, knockback_interval
猪笼草专有: grab_dps_per_level, digest_duration_per_level
荆棘专有: reflect_ratio_per_level
橡树专有: aura_reduction_per_level
向日葵专有: generate_amount_per_level, generate_interval_per_level
薄荷专有: buff_damage_mult_per_level, buff_speed_mult_per_level
治愈花专有: heal_amount_per_level, heal_interval_per_level
爆竹竹专有: charge_time, explosion_damage_per_level, explosion_range_per_level
```

### 3. 稀有度分配（6 COMMON / 5 RARE / 4 EPIC）

| 稀有度 | 塔 | ID |
|---|---|---|
| COMMON (0) | 射手塔 | pea_shooter |
| COMMON (0) | 树桩 | stump |
| COMMON (0) | 冰花 | ice_flower |
| COMMON (0) | 向日葵 | sunflower |
| COMMON (0) | 荆棘 | thorn |
| COMMON (0) | 蒲公英 | dandelion |
| RARE (1) | 仙人掌 | cactus |
| RARE (1) | 玫瑰 | rose |
| RARE (1) | 毒蘑菇 | mushroom |
| RARE (1) | 治愈花 | heal_flower |
| RARE (1) | 薄荷 | mint |
| EPIC (2) | 藤蔓 | vine |
| EPIC (2) | 猪笼草 | pitcher |
| EPIC (2) | 橡树 | oak |
| EPIC (2) | 爆竹竹 | bamboo |

### 4. 15 个 .tres 文件更新

每个塔的 `.tres` 文件新增：
- `description` — 功能+风味结合（一句功能说明 + 一句风味文本）
- `icon_path` — 空字符串（预留）
- `rarity` — 对应的 TowerRarity 值

**描述文本：**

| 塔 | description |
|---|---|
| 射手塔 | 稳定射击最近的敌人。虽然平凡，但从不缺席。 |
| 树桩 | 坚实的血肉屏障，不攻击但极难击倒。年轮是它唯一的武器。 |
| 冰花 | 散发寒气减速周围敌人。冬天的花朵，盛开在最不该温暖的地方。 |
| 向日葵 | 定时产出金币。它追逐的不是阳光，而是闪闪发光的一切。 |
| 荆棘 | 受击时将伤害反弹给攻击者。以牙还牙，以刺还刺。 |
| 蒲公英 | 周期性击退范围内敌人。一口气吹散所有烦恼。 |
| 仙人掌 | 瞄准血量最高的敌人精准狙击。沙漠猎手，一针见血。 |
| 玫瑰 | 三连发爆射，火力凶猛。美丽的东西往往带刺。 |
| 毒蘑菇 | 释放毒雾持续伤害范围内敌人。闻起来不太对劲。 |
| 治愈花 | 治疗血量最低的友方塔。温柔的力量，无声的守护。 |
| 薄荷 | 增强周围友方塔的攻速和伤害。清凉提神，战斗加倍。 |
| 藤蔓 | 接触敌人时将其定身。一旦缠上，就别想走了。 |
| 猪笼草 | 抓取敌人缓慢消化。Boss 太大塞不进去。 |
| 橡树 | 光环减少周围友方塔受到的伤害。千年老树，庇护万物。 |
| 爆竹竹 | 充能后自爆造成大范围伤害。生命虽短，但要轰轰烈烈。 |

### 5. 升级生成器改造

文件：`scripts/systems/upgrade_generator.gd`

新增塔稀有度权重常量，数值与武器一致：

```gdscript
const TOWER_RARITY_WEIGHTS: Dictionary = {
    Enums.TowerRarity.COMMON: 1.0,
    Enums.TowerRarity.RARE: 0.6,
    Enums.TowerRarity.EPIC: 0.3,
}
```

塔池构建时从 `td.rarity` 读取权重：

```gdscript
"_weight": TOWER_RARITY_WEIGHTS.get(td.rarity, 1.0)
```

### 6. 升级卡片改造

文件：`scripts/ui/upgrade_card_builder.gd`

- 塔边框颜色改为按稀有度着色，复用 `RARITY_COLORS`（蓝/紫/橙）
- 背景色保持绿色系（`#1a2a1a`）以区分武器
- 塔卡片新增 description 显示（与武器逻辑一致）

### 7. 测试

文件：`tests/unit/test_tower_data.gd`（新建）

测试项：
- 所有塔有合法 rarity（0-2）
- 所有塔有非空 description
- 稀有度分布：COMMON 6 / RARE 5 / EPIC 4
- TowerRarity 枚举值正确

## 不在本次范围

- icon_path 的实际图标文件（仅预留字段）
- 塔布置侧栏（placement_panel）的稀有度显示
- milestones 字段的实际使用
