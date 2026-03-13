# 商店系统重构：武器选择 + 塔商店

## 概述

将商店从"道具属性商店"重构为两条独立成长线：
- **武器线**：吸血鬼幸存者式，波次结束 3 选 1 免费升级
- **塔线**：土豆兄弟式，布置阶段金币商店购买/升级

## 设计动机

原道具系统（37 个道具、24 种效果）扩充需要大量美术和数值工作。武器/塔升级系统更直观，数据集中在现有 Resource 文件中，扩展只需加等级数值。

## 武器成长线（选择驱动）

### 核心机制
- 每波结束弹出 3 个选项，玩家选 1 个，免费
- 选项从混合池随机抽取：新武器 + 已有武器的升级
- 武器最高 5 级，满级武器不再出现在选项中
- 多武器同时装备，WeaponManager 自动管理开火
- 角色自带 1 把 Lv1 初始武器

### 选项生成规则
- 池中包含：所有未拥有武器（作为"Lv1 新武器"）+ 所有已拥有且未满级武器（作为"升级到 Lv N+1"）
- 从池中随机抽 3 个（不重复）
- 若池中不足 3 个，则只显示剩余数量
- 若池为空（所有武器满级），跳过选择直接进入布置阶段

### 武器等级数据（方案 C：等级曲线 + 里程碑）

在 WeaponData 中新增字段：

```
@export var max_level: int = 5
@export var damage_per_level: Array[float]       # [10, 15, 22, 30, 40]
@export var fire_rate_per_level: Array[float]     # [0.3, 0.28, 0.25, 0.22, 0.18]
@export var milestones: Dictionary = {}           # {3: "pierce_1", 5: "multishot"}
```

- `damage_per_level[level - 1]` 获取当前等级伤害
- `milestones` 键为等级，值为效果 ID，达到对应等级时解锁质变效果
- 初期可以只做纯数值升级，milestones 留空，后续逐步补充

### 里程碑效果类型（初期可选子集）
- `pierce_N`：子弹穿透 N 个敌人
- `multishot`：一次射出 3 发（伤害按系数衰减）
- `split`：子弹命中后分裂
- `bullet_speed`：弹速提升
- 后续可按需扩展，每种效果对应武器脚本中的具体实现

## 塔成长线（经济驱动）

### 核心机制
- 布置阶段侧栏商店 Tab，3 格 + 可花金币刷新
- 选项从混合池随机抽取：新塔类型 + 已有塔的升级
- 塔最高 5 级，满级塔不再出现在商店中
- 金币用途：购买/升级塔 + 放置塔到地图 + 刷新商店
- 角色自带 1 种 Lv1 初始塔
- 升级全局生效：商店升级后所有已放置的同类型塔立即升级

### 商店生成规则
- 池中包含：所有未拥有塔（作为"Lv1 新塔"）+ 所有已拥有且未满级塔（作为"升级到 Lv N+1"）
- 从池中随机抽 3 个（不重复），各自有对应价格
- 若池中不足 3 个，剩余格子留空
- 刷新费用保持现有阶梯：按波次递增
- 首波（wave 0）：商店 Tab 不可见，仅布置 Tab

### 塔等级数据

在 TowerData 中新增字段：

```
@export var max_level: int = 5
@export var hp_per_level: Array[float]            # [100, 130, 170, 220, 280]
@export var damage_per_level: Array[float]        # [15, 22, 30, 40, 55]（射手塔）
@export var fire_rate_per_level: Array[float]     # 射手塔专用
@export var attack_range_per_level: Array[float]  # 射手塔专用
@export var slow_ratio_per_level: Array[float]    # 减速塔专用
@export var shop_price_per_level: Array[int]      # [0, 20, 35, 55, 80]（Lv1=购买价，Lv2+=升级价）
@export var milestones: Dictionary = {}
```

### 塔放置费用
- 放置塔的费用取决于塔的当前全局等级，高等级塔放置更贵
- 放置费用 = TowerData 现有 `shop_price_min/max` 按等级缩放，或改用 `place_cost_per_level: Array[int]`

## 游戏流程

```
波次战斗结束
  ↓
武器选择弹窗（3选1，免费）
  ↓（选择后或无可选时自动跳过）
布置阶段
  ├── 布置 Tab：放置/移除塔（花金币）
  └── 商店 Tab（wave > 0）：3格塔商店（买新塔/升级塔）
  ↓（点击开始战斗）
下一波战斗
```

### 首波特殊处理
- wave 0 进入布置阶段时，不弹武器选择（还没打过）
- 商店 Tab 不可见
- 玩家用初始塔和初始金币布置

## GameData 变更

### 新增字段
```gdscript
var owned_weapons: Dictionary = {}    # {weapon_id: level}  如 {"rifle": 2, "shotgun": 1}
var owned_towers: Dictionary = {}     # {tower_id: level}   如 {"shooter": 3, "slow": 1}
```

### 移除字段
所有道具效果相关字段（24+ 个）：
- pierce_count, multishot_active, lifesteal_ratio, kill_stack_*, tower_link_*
- wave_gold_bonus, wave_tower_heal_ratio, tower_regen_*
- symbiosis_*, war_machine_*, bullet_speed_mult, weapon_range_mult
- crit_chance, split_count, split_damage_mult, wave_shield_count
- damage_reduction, dodge_chance, coin_magnet_mult
- slow_aura_*, auto_dash_*, purchased_items, purchased_item_list

### 保留字段
- coins, current_wave, player_stats 等基础状态
- tower_inventory（已放置塔的位置信息，增加 level 字段）

## 移除的文件/系统

| 文件 | 说明 |
|------|------|
| `resources/items/*.tres` (37个) | 全部道具数据文件 |
| `scripts/resources/shop_item_data.gd` | ShopItemData 资源类 |
| `scripts/systems/shop_effect_applier.gd` | 道具效果应用 |
| `scripts/systems/shop_item_generator.gd` | 道具生成逻辑 |
| `scripts/systems/item_effect_manager.gd` | 被动效果管理 |
| `CharacterData.affinity_tags/discount` | 角色亲和系统 |

## 新增/重构的文件

| 文件 | 说明 |
|------|------|
| `scripts/ui/weapon_select_popup.gd` | 武器选择弹窗 UI（波次结束 3 选 1） |
| `scripts/systems/weapon_upgrade_generator.gd` | 武器选项生成逻辑 |
| `scripts/systems/tower_shop_generator.gd` | 塔商店选项生成逻辑 |
| `scripts/ui/shop_panel.gd` | 重构为纯塔商店（3格） |
| `WeaponData` 新增字段 | max_level, *_per_level, milestones |
| `TowerData` 新增字段 | max_level, *_per_level, shop_price_per_level, milestones |

## 角色差异化

移除亲和折扣系统后，角色差异通过初始武器和初始塔区分：

| 角色 | 初始武器 | 初始塔 | 其他差异 |
|------|----------|--------|----------|
| Dora | rifle | shooter | 高 HP |
| Gorg | shotgun | wall | 高防御 |
| Kaze | boomerang | slow | 高速度 |
| Merlin | laser | shooter | 高伤害 |

（具体搭配待数值设计阶段确定）

## 里程碑效果的实现策略

里程碑效果复用现有 GameData 机制：
- 武器升级达到里程碑等级时，由升级逻辑写入 GameData 对应字段（如 pierce_count）
- 只保留 milestones 实际用到的 GameData 字段，其余移除
- 初期可不实现任何 milestone，纯数值升级即可运行

## 测试策略

- 武器选项生成：验证池过滤（满级排除、不重复）
- 塔商店生成：验证池过滤、价格计算
- 武器升级：验证等级属性正确应用
- 塔升级全局生效：验证已放置塔属性同步更新
- 边界情况：所有武器满级时跳过选择、商店池为空
